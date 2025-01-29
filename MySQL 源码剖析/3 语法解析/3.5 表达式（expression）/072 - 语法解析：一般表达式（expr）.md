目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

前置文档：

- [MySQL 源码｜50 - 语法解析(V2)：简单表达式（simple_expr）](https://zhuanlan.zhihu.com/p/715703857)
- [MySQL 源码｜69 - 语法解析(V2)：位表达式（bit_expr）](https://zhuanlan.zhihu.com/p/719439177)
- [MySQL 源码｜70 - 语法解析(V2)：谓语表达式（predicate）](https://zhuanlan.zhihu.com/p/719441615)
- [MySQL 源码｜71 - 语法解析(V2)：布尔表达式（bool_pri）](https://zhuanlan.zhihu.com/p/719443599)

---

在梳理了简单表达式 `simple_expr` 语义组、位表达式 `bit_expr`、谓语表达式 `predicate` 和布尔表达式 `bool_pri` 后，我们继续梳理最高级的一般表达式 `expr` 语义组，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符；因为使用 `expr` 语义组的场景较多，所以不展示使用 `expr` 语义组的节点）：

![语法解析-020-一般表达式（expr）](C:\blog\graph\MySQL源码剖析\语法解析-020-一般表达式（expr）.png)

#### 语义组：`expr`

`expr` 语义组用于解析最高级的一般表达式，即在布尔表达式（`bool_pri`）的基础上使用逻辑运算符（与、或、非、异或）以及 `IS`、`IS NOT` 进行计算的表达式。`expr` 语义组的备选规则包含两类，分别是 `bool_pri` 语义组的解析结果，以及 `expr` 语义组与其他语义组（或其本身）进行比较计算的结果。

- 官方文档：[MySQL 参考手册 - 11.5 Expressions](https://dev.mysql.com/doc/refman/8.4/en/expressions.html)；[MySQL 参考手册 - 14.4 Operators](https://dev.mysql.com/doc/refman/8.4/en/non-typed-operators.html)
- 标准语法：

```
expr:
    expr OR expr
  | expr || expr
  | expr XOR expr
  | expr AND expr
  | expr && expr
  | NOT expr
  | ! expr
  | boolean_primary IS [NOT] {TRUE | FALSE | UNKNOWN}
  | boolean_primary
```

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类。
- 使用场景：各种需要使用表达式的场景
- 备选规则和 Bison 语法：

| 备选规则                      | 规则含义                 |
| ----------------------------- | ------------------------ |
| `expr or expr`                | 逻辑或运算               |
| `expr XOR expr`               | 逻辑异或运算             |
| `expr and expr`               | 逻辑与运算               |
| `NOT_SYM expr`                | 逻辑非运算               |
| `bool_pri IS TRUE_SYM`        | 布尔表达式是否是真值     |
| `bool_pri IS not TRUE_SYM`    | 布尔表达式是否不是真值   |
| `bool_pri IS FALSE_SYM`       | 布尔表达式是否是假值     |
| `bool_pri IS not FALSE_SYM`   | 布尔表达式是否不是假值   |
| `bool_pri IS UNKNOWN_SYM`     | 布尔表达式是否是未知值   |
| `bool_pri IS not UNKNOWN_SYM` | 布尔表达式是否不是未知值 |
| `bool_pri`                    | 布尔表达式               |

```C++
/* all possible expressions */
expr:
          expr or expr %prec OR_SYM
          {
            $$= flatten_associative_operator<Item_cond_or,
                                             Item_func::COND_OR_FUNC>(
                                                 YYMEM_ROOT, @$, $1, $3);
            if ($$ != nullptr) $$->m_pos = @$;
          }
        | expr XOR expr %prec XOR
          {
            /* XOR is a proprietary extension */
            $$ = NEW_PTN Item_func_xor(@$, $1, $3);
          }
        | expr and expr %prec AND_SYM
          {
            $$= flatten_associative_operator<Item_cond_and,
                                             Item_func::COND_AND_FUNC>(
                                                 YYMEM_ROOT, @$, $1, $3);
            if ($$ != nullptr) $$->m_pos = @$;
          }
        | NOT_SYM expr %prec NOT_SYM
          {
            $$= NEW_PTN PTI_truth_transform(@$, $2, Item::BOOL_NEGATED);
          }
        | bool_pri IS TRUE_SYM %prec IS
          {
            $$= NEW_PTN PTI_truth_transform(@$, $1, Item::BOOL_IS_TRUE);
          }
        | bool_pri IS not TRUE_SYM %prec IS
          {
            $$= NEW_PTN PTI_truth_transform(@$, $1, Item::BOOL_NOT_TRUE);
          }
        | bool_pri IS FALSE_SYM %prec IS
          {
            $$= NEW_PTN PTI_truth_transform(@$, $1, Item::BOOL_IS_FALSE);
          }
        | bool_pri IS not FALSE_SYM %prec IS
          {
            $$= NEW_PTN PTI_truth_transform(@$, $1, Item::BOOL_NOT_FALSE);
          }
        | bool_pri IS UNKNOWN_SYM %prec IS
          {
            $$= NEW_PTN Item_func_isnull(@$, $1);
          }
        | bool_pri IS not UNKNOWN_SYM %prec IS
          {
            $$= NEW_PTN Item_func_isnotnull(@$, $1);
          }
        | bool_pri %prec SET_VAR
        ;
```

> `or` 语义组用于解析 `OR` 关键字（`OR_SYM` 终结符）或 SQL_MODE 开启了 `PIPES_AS_CONCAT` 模式的 `||` 符号（`OR2_SYM` 终结符），详见下文；
>
> `and` 语义组用于解析 `AND` 关键字（`AND_SYM` 终结符）或 `&&` 符号（`AND_AND_SYM` 终结符），详见下文；
>
> `not` 语义组用于解析 `NOT` 关键字，无论 SQL_MODE 开启 `HIGH_NOT_PRECEDENCE` 模式，详见 [MySQL 源码｜70 - 语法解析(V2)：谓语表达式（predicate）](https://zhuanlan.zhihu.com/p/719441615)。

#### 语义组：`or`

`or` 语义组用于解析 `OR` 关键字（`OR_SYM` 终结符）或 SQL_MODE 开启了 `PIPES_AS_CONCAT` 模式的 `||` 符号（`OR2_SYM` 终结符）。

- 返回值类型：没有返回值
- Bison 语法如下：

```C++
or:
          OR_SYM
       | OR2_SYM
       ;
```

#### 语义组：`and`

`and` 语义组用于解析 `AND` 关键字（`AND_SYM` 终结符）或 `&&` 符号（`AND_AND_SYM` 终结符）。

- 返回值类型：没有返回值
- Bison 语法如下：

```C++
and:
          AND_SYM
       | AND_AND_SYM
         {
           push_deprecated_warn(YYTHD, "&&", "AND");
         }
       ;
```

#### 语义组：`expr_list`

`expr_list` 语义组用于解析逗号分隔、任意数量一般表达式（`expr` 语义组）。

- 返回值类型：`PT_item_list` 对象（`item_list2`）
- Bison 语法如下：

```C++
expr_list:
          expr
          {
            $$= NEW_PTN PT_item_list(@$);
            if ($$ == nullptr || $$->push_back($1))
              MYSQL_YYABORT;
          }
        | expr_list ',' expr
          {
            if ($1 == nullptr || $1->push_back($3))
              MYSQL_YYABORT;
            $$= $1;
            // This will override location of earlier list, until we get the
            // whole location.
            $$->m_pos = @$;
          }
        ;
```

#### 语义组：`opt_expr_list`

`opt_expr_list` 语义组用于解析可选的逗号分隔、任意数量的一般表达式（`expr` 语义组）。

- 返回值类型：`PT_item_list` 对象（`item_list2`）
- Bison 语法如下：

```C++
opt_expr_list:
          %empty { $$= nullptr; }
        | expr_list
        ;
```

#### 语义组：`opt_expr`

`opt_expr` 规则用于解析可选的一般表达式（`expr` 语义组）。

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类
- Bison 语法如下：

```C++
opt_expr:
          %empty         { $$= nullptr; }
        | expr           { $$= $1; }
        ;
```

