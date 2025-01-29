目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：

- [sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)
- [sql/item_strfunc.h](https://github.com/mysql/mysql-server/blob/trunk/sql/item_strfunc.h)

前置文档：

- [MySQL 源码｜33 - 语法解析：bison 基础语法规则](https://zhuanlan.zhihu.com/p/714779214)
- [MySQL 源码｜34 - 语法解析：所有 token 的名称与含义列表](https://zhuanlan.zhihu.com/p/714779441)

---

#### `current_user` 函数

在 `function_call_keyword` 规则中，定义了 `current_user` 函数的规则：

```bison
CURRENT_USER optional_braces
{
$$= NEW_PTN Item_func_current_user(@$);
}
```

其中 `optional_braces` 为可选的 `()` 规则，因此 `CURRENT_USER` 函数支持 `CURRENT_USER()` 与 `CURRENT_USER` 两种形式。语法如下：

```
CURRENT_USER[()]
```

Python 的 SQL 解析器实现 `current_user()` 函数的抽象语法树节点如下：

```python
@dataclasses.dataclass(slots=True, frozen=True, eq=True)
class ASTFuncCurrentUser(ASTFunctionExpressionBase):
    """【MySQL】CURRENT_USER 函数

    原型：
    CURRENT_USER()
    CURRENT_USER
    """

    def source(self, sql_type: SQLType = SQLType.DEFAULT) -> str:
        """返回语法节点的 SQL 源码"""
        return "CURRENT_USER()"
```

抽象语法树节点解析逻辑如下：

```python
if scanner.search_one_type_mark(AMTMark.PARENTHESIS):
    parenthesis_scanner = scanner.pop_as_children_scanner()
    parenthesis_scanner.close()

return node.ASTFuncCurrentUser(
    name=node.ASTFunctionNameExpression(function_name="current_user"),
)
```

Python 的 SQL 解析器项目地址：[水杉解析器](https://github.com/ChangxingJiang/metasequoia-sql)

#### `user` 函数

在 `function_call_keyword` 规则中，定义了 `user` 函数的规则：

```bison
USER '(' ')'
{
$$= NEW_PTN Item_func_user(@$);
}
```

对应语法如下：

```
USER()
```

Python 的 SQL 解析器实现 `current_user()` 函数的抽象语法树节点如下：

```python
@dataclasses.dataclass(slots=True, frozen=True, eq=True)
class ASTFuncUser(ASTFunctionExpressionBase):
    """【MySQL】USER 函数

    原型：
    USER()
    """

    def source(self, sql_type: SQLType = SQLType.DEFAULT) -> str:
        """返回语法节点的 SQL 源码"""
        return "USER()"
```

抽象语法树节点解析逻辑如下：

```python
parenthesis_scanner = scanner.pop_as_children_scanner()
parenthesis_scanner.close()
return node.ASTFuncUser(
    name=node.ASTFunctionNameExpression(function_name="user"),
)
```

Python 的 SQL 解析器项目地址：[水杉解析器](https://github.com/ChangxingJiang/metasequoia-sql)

