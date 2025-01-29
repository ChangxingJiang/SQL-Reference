目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

前置文档：

- [MySQL 源码｜50 - 语法解析(V2)：简单表达式（simple_expr）](https://zhuanlan.zhihu.com/p/715703857)
- [MySQL 源码｜69 - 语法解析(V2)：位表达式（bit_expr）](https://zhuanlan.zhihu.com/p/719439177)

---

在梳理了简单表达式 `simple_expr` 语义组和位表达式 `bit_expr` 后，我们继续梳理比 `bit_expr` 高级一层的 `predicate` 语义组，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析-018-谓语表达式（predicate）](C:\blog\graph\MySQL源码剖析\语法解析-018-谓语表达式（predicate）.png)

#### 语义组：`predicate`

`predicate` 语义组用于解析谓语表达式，即在位表达式（`bit_expr`）的基础上使用谓语关键字进行计算的表达式。这些谓语关键字包括 `IN`、`MEMBER OF`、`BETWEEN`、`SOUNDS LIKE`、`LIKE`、`REGEXP`。`predicate` 语义组的备选规则包含两类，分别是 `bit_expr` 语义组的解析结果，以及 `bit_expr` 语义组与其他语义组（或其本身）进行谓语计算的结果。

- 官方文档：[MySQL 参考手册 - 11.5 Expressions](https://dev.mysql.com/doc/refman/8.4/en/expressions.html)；[MySQL 参考手册 - 14.4 Operators](https://dev.mysql.com/doc/refman/8.4/en/non-typed-operators.html)
- 标准语法：

```
predicate:
    bit_expr [NOT] IN (subquery)
  | bit_expr [NOT] IN (expr [, expr] ...)
  | bit_expr [NOT] BETWEEN bit_expr AND predicate
  | bit_expr SOUNDS LIKE bit_expr
  | bit_expr [NOT] LIKE simple_expr [ESCAPE simple_expr]
  | bit_expr [NOT] REGEXP bit_expr
  | bit_expr
```

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类。
- 使用场景：上一级表达式（`bool_pri` 语义组）
- 备选规则和 Bison 语法：

| 备选规则                                               | 规则含义                                                     |
| ------------------------------------------------------ | ------------------------------------------------------------ |
| `bit_expr IN_SYM table_subquery`                       | 位表达式的值是否在多行子查询中存在                           |
| `bit_expr not IN_SYM table_subquery`                   | 位表达式的值是否不在多行子查询中存在                         |
| `bit_expr IN_SYM '(' expr ')'`                         | 位表达式的值是否在单个值的列表中存在                         |
| `bit_expr IN_SYM '(' expr ',' expr_list ')'`           | 位表达式的值是否在多个值的列表中存在                         |
| `bit_expr not IN_SYM '(' expr ')'`                     | 位表达式的值是否不在单个值的列表中存在                       |
| `bit_expr not IN_SYM '(' expr ',' expr_list ')'`       | 位表达式的值是否不在多个值的列表中存在                       |
| `bit_expr MEMBER_SYM opt_of '(' simple_expr ')'`       | 如果位表达式与 `simple_expr`（Json 数组格式）中的任何元素匹配，则返回真（1），否则返回假（0） |
| `bit_expr BETWEEN_SYM bit_expr AND_SYM predicate`      | 位表达式的值是否在两个值之间                                 |
| `bit_expr not BETWEEN_SYM bit_expr AND_SYM predicate`  | 位表达式的值是否不在两个值之间                               |
| `bit_expr SOUNDS_SYM LIKE bit_expr`                    | 比较两个位表达式的声音是否相似（Compare sounds）             |
| `bit_expr LIKE simple_expr`                            | 位表达式的值是否匹配模板                                     |
| `bit_expr LIKE simple_expr ESCAPE_SYM simple_expr`     | 位表达式的值是否匹配模板，并忽略 `ESCAPE` 子句中的字符       |
| `bit_expr not LIKE simple_expr`                        | 位表达式的值是否不匹配板                                     |
| `bit_expr not LIKE simple_expr ESCAPE_SYM simple_expr` | 位表达式的值是否不匹配模板，并忽略 `ESCAPE` 子句中的字符     |
| `bit_expr REGEXP bit_expr`                             | 位表达式的值是否匹配正则表达式                               |
| `bit_expr not REGEXP bit_expr`                         | 位表达式的值是否不匹配正则表达式                             |
| `bit_expr`                                             | 没有谓语计算的位表达式                                       |

```C++
predicate:
          bit_expr IN_SYM table_subquery
          {
            $$= NEW_PTN Item_in_subselect(@$, $1, $3);
          }
        | bit_expr not IN_SYM table_subquery
          {
            Item *item= NEW_PTN Item_in_subselect(@$, $1, $4);
            $$= NEW_PTN PTI_truth_transform(@$, item, Item::BOOL_NEGATED);
          }
        | bit_expr IN_SYM '(' expr ')'
          {
            $$= NEW_PTN PTI_handle_sql2003_note184_exception(@$, $1, false, $4);
          }
        | bit_expr IN_SYM '(' expr ',' expr_list ')'
          {
            if ($6 == nullptr || $6->push_front($4) || $6->push_front($1))
              MYSQL_YYABORT;

            $$= NEW_PTN Item_func_in(@$, $6, false);
          }
        | bit_expr not IN_SYM '(' expr ')'
          {
            $$= NEW_PTN PTI_handle_sql2003_note184_exception(@$, $1, true, $5);
          }
        | bit_expr not IN_SYM '(' expr ',' expr_list ')'
          {
            if ($7 == nullptr)
              MYSQL_YYABORT;
            $7->push_front($5);
            $7->value.push_front($1);

            $$= NEW_PTN Item_func_in(@$, $7, true);
          }
        | bit_expr MEMBER_SYM opt_of '(' simple_expr ')'
          {
            $$= NEW_PTN Item_func_member_of(@$, $1, $5);
          }
        | bit_expr BETWEEN_SYM bit_expr AND_SYM predicate
          {
            $$= NEW_PTN Item_func_between(@$, $1, $3, $5, false);
          }
        | bit_expr not BETWEEN_SYM bit_expr AND_SYM predicate
          {
            $$= NEW_PTN Item_func_between(@$, $1, $4, $6, true);
          }
        | bit_expr SOUNDS_SYM LIKE bit_expr
          {
            Item *item1= NEW_PTN Item_func_soundex(@$, $1);
            Item *item4= NEW_PTN Item_func_soundex(@$, $4);
            if ((item1 == nullptr) || (item4 == nullptr))
              MYSQL_YYABORT;
            $$= NEW_PTN Item_func_eq(@$, item1, item4);
          }
        | bit_expr LIKE simple_expr
          {
            $$ = NEW_PTN Item_func_like(@$, $1, $3);
          }
        | bit_expr LIKE simple_expr ESCAPE_SYM simple_expr %prec LIKE
          {
            $$ = NEW_PTN Item_func_like(@$, $1, $3, $5);
          }
        | bit_expr not LIKE simple_expr
          {
            auto item = NEW_PTN Item_func_like(@$, $1, $4);
            $$ = NEW_PTN Item_func_not(@$, item);
          }
        | bit_expr not LIKE simple_expr ESCAPE_SYM simple_expr %prec LIKE
          {
            auto item = NEW_PTN Item_func_like(@$, $1, $4, $6);
            $$ = NEW_PTN Item_func_not(@$, item);
          }
        | bit_expr REGEXP bit_expr
          {
            auto args= NEW_PTN PT_item_list(@$);
            args->push_back($1);
            args->push_back($3);

            $$= NEW_PTN Item_func_regexp_like(@1, args);
          }
        | bit_expr not REGEXP bit_expr
          {
            auto args= NEW_PTN PT_item_list(@$);
            args->push_back($1);
            args->push_back($4);
            Item *item= NEW_PTN Item_func_regexp_like(@$, args);
            $$= NEW_PTN PTI_truth_transform(@$, item, Item::BOOL_NEGATED);
          }
        | bit_expr %prec SET_VAR
        ;
```

> `table_subquery` 语义组用于解析多行子查询，详见 [MySQL 源码｜47 - 语法解析(V2)：子查询](https://zhuanlan.zhihu.com/p/715426420)；
>
> `expr` 语义组用于解析一般表达式，`expr_list` 解析任意数量、逗号分隔的一般表达式；
>
> `opt_of` 语义组解析可选的 `OF` 关键字，详见下文。

#### 语义组：`opt_of`

`opt_of` 语义组用于解析可选的 `OF` 关键字。

- 返回值类型：没有返回值
- Bison 语法如下：

```C++
opt_of:
          OF_SYM
        | %empty
        ;
```

#### 语义组：`not`

`not` 语义组用于解析 `NOT` 关键字，无论 SQL_MODE 开启 `HIGH_NOT_PRECEDENCE` 模式。

- 返回值类型：没有返回值
- Bison 语法如下：

```C++
not:
          NOT_SYM
        | NOT2_SYM
        ;
```

> `NOT_SYM` 语义组用于解析 `NOT` 关键字；
>
> `NOT2_SYM` 语义组用于解析 `NOT` 关键字（当 SQL_MODE 开启 `HIGH_NOT_PRECEDENCE` 时）。

