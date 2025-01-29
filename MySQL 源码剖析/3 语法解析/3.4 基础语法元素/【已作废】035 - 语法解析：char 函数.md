目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：

- [sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)
- [sql/item_strfunc.h](https://github.com/mysql/mysql-server/blob/trunk/sql/item_strfunc.h)

前置文档：

- [MySQL 源码｜33 - 语法解析：bison 基础语法规则](https://zhuanlan.zhihu.com/p/714779214)
- [MySQL 源码｜34 - 语法解析：所有 token 的名称与含义列表](https://zhuanlan.zhihu.com/p/714779441)

---

在 `function_call_keyword` 规则中，定义了 `char` 函数的规则：

```bison
          CHAR_SYM '(' expr_list ')'
          {
            $$= NEW_PTN Item_func_char(@$, $3);
          }
        | CHAR_SYM '(' expr_list USING charset_name ')'
          {
            $$= NEW_PTN Item_func_char(@$, $3, $5);
          }
```

其中：`CHAR_SYM` 即 `CHAR` 关键字，`expr_list` 是表达式的列表，`USING` 即 `USING` 关键字；生成 `Item_func_char` 类对象。

因此，`char` 函数的原型如下：

```
char (expr [, expr] [USING charset_name])
```

在实现上，`Item_func_char` 类继承自 `Item_str_func` 类，具体实现逻辑如下：

```C++
class Item_func_char final : public Item_str_func {
 public:
  Item_func_char(const POS &pos, PT_item_list *list)
      : Item_str_func(pos, list) {
    collation.set(&my_charset_bin);
  }
  Item_func_char(const POS &pos, PT_item_list *list, const CHARSET_INFO *cs)
      : Item_str_func(pos, list) {
    collation.set(cs);
  }
  String *val_str(String *) override;
  bool resolve_type(THD *thd) override {
    if (param_type_is_default(thd, 0, -1, MYSQL_TYPE_LONGLONG)) return true;
    set_data_type_string(arg_count * 4U);
    return false;
  }
  const char *func_name() const override { return "char"; }
  void add_json_info(Json_object *obj) override {
    Item_str_func::add_json_info(obj);
    obj->add_alias("charset",
                   create_dom_ptr<Json_string>(collation.collation->csname));
  }
};
```

---

Python 的 SQL 解析器实现 char 函数的抽象语法树节点如下：

```python
@dataclasses.dataclass(slots=True, frozen=True, eq=True)
class ASTFuncChar(ASTFunctionExpressionBase):
    """【MySQL】CHAR 函数

    原型：
    CHAR(expr_list)
    CHAR(expr_list USING charset_name)
    """

    expr_list: Tuple[ASTExpressionBase, ...] = dataclasses.field(kw_only=True)  # 参数值的列表
    charset_name: Optional[str] = dataclasses.field(kw_only=True)  # 字符集

    def source(self, sql_type: SQLType = SQLType.DEFAULT) -> str:
        """返回语法节点的 SQL 源码"""
        expr_list_str = ", ".join(expr.source(sql_type) for expr in self.expr_list)
        if self.charset_name is not None:
            return f"char({expr_list_str} USING {self.charset_name})"
        return f"char({expr_list_str})"
```

抽象语法树节点解析逻辑如下：

```python
# 获取函数参数部分的迭代器
parenthesis_scanner = scanner.pop_as_children_scanner()

# 解析表达式列表
expr_list: List[GeneralExpression] = []
if not parenthesis_scanner.is_finish:
    expr_list.append(cls._parse_logical_or_level_expression(parenthesis_scanner, sql_type))
while parenthesis_scanner.search_and_move_one_type_str(","):
    expr_list.append(cls._parse_logical_or_level_expression(parenthesis_scanner, sql_type))

# 解析字符集名称
charset_name: Optional[str] = None
if parenthesis_scanner.search_and_move_one_type_str("USING"):
    charset_name = parenthesis_scanner.pop_as_source()

# 关闭迭代器，确保其中元素已迭代完成
parenthesis_scanner.close()

return node.ASTFuncChar(
    name=node.ASTFunctionNameExpression(function_name="char"),
    expr_list=tuple(expr_list),
    charset_name=charset_name
)
```

Python 的 SQL 解析器项目地址：[水杉解析器](https://github.com/ChangxingJiang/metasequoia-sql)





