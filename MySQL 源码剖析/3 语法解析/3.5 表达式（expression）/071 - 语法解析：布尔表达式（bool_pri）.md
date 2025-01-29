目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

前置文档：

- [MySQL 源码｜50 - 语法解析(V2)：简单表达式（simple_expr）](https://zhuanlan.zhihu.com/p/715703857)
- [MySQL 源码｜69 - 语法解析(V2)：位表达式（bit_expr）](https://zhuanlan.zhihu.com/p/719439177)
- [MySQL 源码｜70 - 语法解析(V2)：谓语表达式（predicate）](https://zhuanlan.zhihu.com/p/719441615)
- [MySQL 源码｜47 - 语法解析(V2)：子查询](https://zhuanlan.zhihu.com/p/715426420)

---

在梳理了简单表达式 `simple_expr` 语义组、位表达式 `bit_expr` 和谓语表达式 `predicate` 后，我们继续梳理比 `predicate` 高级一层的 `bool_pri` 语义组，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析-019-布尔表达式（bool_pri）](C:\blog\graph\MySQL源码剖析\语法解析-019-布尔表达式（bool_pri）.png)

#### 语义组：`bool_pri`

`bool_pri` 语义组用于解析布尔表达式，即在谓语表达式（`predicate`）的基础上使用比较运算符进行计算的表达式。`bool_pri` 语义组的备选规则包含两类，分别是 `predicate` 语义组的解析结果，以及 `bool_pri` 语义组与其他语义组（或其本身）进行比较计算的结果。

- 官方文档：[MySQL 参考手册 - 11.5 Expressions](https://dev.mysql.com/doc/refman/8.4/en/expressions.html)；[MySQL 参考手册 - 14.4 Operators](https://dev.mysql.com/doc/refman/8.4/en/non-typed-operators.html)
- 标准语法：

```
boolean_primary:
    boolean_primary IS [NOT] NULL
  | boolean_primary <=> predicate
  | boolean_primary comparison_operator predicate
  | boolean_primary comparison_operator {ALL | ANY} (subquery)
  | predicate

comparison_operator: = | >= | > | <= | < | <> | !=
```

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类。
- 使用场景：上一级表达式（`expr` 语义组）
- 备选规则和 Bison 语法：

| 备选规则                                     | 规则含义                                                     |
| -------------------------------------------- | ------------------------------------------------------------ |
| `bool_pri IS NULL_SYM`                       | 检查布尔表达式的值是否为空值（NULL value test）              |
| `bool_pri IS not NULL_SYM`                   | 检查布尔表达式的值是否不是空值（NOT NULL value test）        |
| `bool_pri comp_op predicate`                 | 比较运算符（`comp_op` 语义组）计算                           |
| `bool_pri comp_op all_or_any table_subquery` | 比较运算符（`comp_op` 语义组）计算，与多行子查询的结果进行比较 |
| `predicate`                                  | 谓语表达式：递归出口                                         |

```C++
bool_pri:
          bool_pri IS NULL_SYM %prec IS
          {
            $$= NEW_PTN Item_func_isnull(@$, $1);
          }
        | bool_pri IS not NULL_SYM %prec IS
          {
            $$= NEW_PTN Item_func_isnotnull(@$, $1);
          }
        | bool_pri comp_op predicate
          {
            $$= NEW_PTN PTI_comp_op(@$, $1, $2, $3);
          }
        | bool_pri comp_op all_or_any table_subquery %prec EQ
          {
            if ($2 == &comp_equal_creator)
              YYTHD->syntax_error_at(@2);
            $$= NEW_PTN PTI_comp_op_all(@$, $1, $2, $3, $4);
          }
        | predicate %prec SET_VAR
        ;
```

> `comp_op` 语义组用于解析比较运算符，详见下文；
>
> `not` 语义组用于解析 `NOT` 关键字，无论 SQL_MODE 开启 `HIGH_NOT_PRECEDENCE` 模式，详见 [MySQL 源码｜70 - 语法解析(V2)：谓语表达式（predicate）](https://zhuanlan.zhihu.com/p/719441615)；
>
> `all_or_any` 语义组用于解析 `ALL` 关键字或 `ANY` 关键字，详见下文；
>
> `table_subquery` 语义组用于解析多行子查询，详见 [MySQL 源码｜47 - 语法解析(V2)：子查询](https://zhuanlan.zhihu.com/p/715426420)。

#### 语义组：`comp_op`

`comp_op` 语义组用于解析比较运算符。具体匹配 `=`（`EQ` 终结符）、`<=>`（`EQUAL_SYM` 终结符）、`>=`（`GE` 终结符）、`>`（`GT_SYM` 终结符）、`<=`（`LE` 终结符）、`<`（`LT` 终结符）、`!=` 或 `<>`（`NE` 终结符）。

- 返回值类型：`Comp_creator` 对象（`boolfunc2creator`）
- Bison 语法如下：

```C++
comp_op:
          EQ     { $$ = &comp_eq_creator; }
        | EQUAL_SYM { $$ = &comp_equal_creator; }
        | GE     { $$ = &comp_ge_creator; }
        | GT_SYM { $$ = &comp_gt_creator; }
        | LE     { $$ = &comp_le_creator; }
        | LT     { $$ = &comp_lt_creator; }
        | NE     { $$ = &comp_ne_creator; }
        ;
```

#### 语义组：`all_or_any`

`all_or_any` 语义组用于解析 `ALL` 关键字或 `ANY` 关键字。

- 返回值类型：`int` 类型（`num`）
- Bison 语法如下：

```C++
all_or_any:
          ALL     { $$ = 1; }
        | ANY_SYM { $$ = 0; }
        ;
```
