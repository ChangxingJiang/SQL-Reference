目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

在 [MySQL 源码｜38 - 语法解析(V2)：窗口函数](https://zhuanlan.zhihu.com/p/714780506) 中，窗口子句使用了 `group_list` 语义组；在基础查询表达式中，使用了 `opt_group_clause` 语义组。下面我们来梳理 GROUP BY 子句的逻辑，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析-022-GROUP BY 子句](C:\blog\graph\MySQL源码剖析\语法解析-022-GROUP BY 子句.png)

#### 语义组：`opt_group_clause`

`opt_group_clause` 语义组用于解析可选的 GROUP BY 子句。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.4/en/select.html)
- 标准语法：`[GROUP BY {col_name | expr | position}, ... [WITH_ROLLUP]]`
- 返回值类型：`PT_group` 对象（`group`）
- 使用场景：基础查询表达式（`query_specification` 语义组）
- 备选规则和 Bison 语法：

| 备选规则                                     | 规则含义                                                     |
| -------------------------------------------- | ------------------------------------------------------------ |
| `%empty`                                     | 解析不到 `GROUP BY` 子句                                     |
| `GROUP_SYM BY group_list olap_opt`           | 解析普通的 GROUP BY 子句                                     |
| `GROUP_SYM BY ROLLUP_SYM '(' group_list ')'` | 解析 `ROLLUP` 的 GROUP BY 子句；逐级生成分组，如果上一级为空则不会生成下一级的分组 |
| `GROUP_SYM BY CUBE_SYM '(' group_list ')'`   | 解析 `CUBE` 的 GROUP BY 子句；生成所有分组，不考虑上一级是否为空 |

```C++
opt_group_clause:
          %empty { $$= nullptr; }
        | GROUP_SYM BY group_list olap_opt
          {
            $$= NEW_PTN PT_group(@$, $3, $4);
          }
        | GROUP_SYM BY ROLLUP_SYM '(' group_list ')'
          {
            $$= NEW_PTN PT_group(@$, $5, ROLLUP_TYPE);
          }
        | GROUP_SYM BY CUBE_SYM '(' group_list ')'
          {
            $$= NEW_PTN PT_group(@$, $5, CUBE_TYPE);
          }
        ;
```

#### 语义组：`olap_opt`

`olap_opt` 语义组用于解析可选的 `WITH_ROLLUP` 关键字。

- 标准语法：`[WITH_ROLLUP]`
- 返回值类型：`olap_type` 枚举值（`olap_type`），有 `UNSPECIFIED_OLAP_TYPE`、`ROLLUP_TYPE` 和 `CUBE_TYPE` 这 3 个枚举值
- Bison 语法如下：

```C++
olap_opt:
          %empty { $$= UNSPECIFIED_OLAP_TYPE; }
        | WITH_ROLLUP_SYM { $$= ROLLUP_TYPE; }
            /*
              'WITH ROLLUP' is needed for backward compatibility,
              and cause LALR(2) conflicts.
              This syntax is not standard.
              MySQL syntax: GROUP BY col1, col2, col3 WITH ROLLUP
              SQL-2003: GROUP BY ... ROLLUP(col1, col2, col3)
            */
        ;
```

#### 语义组：`group_list`

`group_list` 语义组用于解析 GROUP BY 子句中任意数量、逗号分隔的分组字段的列表。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.4/en/select.html)
- 标准语法：`GROUP BY {col_name | expr | position}, ... `
- 返回值类型：`PT_order_list` 对象（`order_list`）
- Bison 语法如下：

```C++
group_list:
          group_list ',' grouping_expr
          {
            $1->push_back($3);
            $$= $1;
            $$->m_pos = @$;
          }
        | grouping_expr
          {
            $$= NEW_PTN PT_order_list(@$);
            if ($$ == nullptr)
              MYSQL_YYABORT;
            $$->push_back($1);
          }
        ;
```

#### 语义组：`grouping_expr`

`grouping_expr` 语义组用于解析 GROUP BY 子句中的一个分组字段。

- 标准语法：`{col_name | expr | position}`
- 返回值类型：`PT_order_expr` 对象（`order_expr`）
- Bison 语法如下：

```C++
grouping_expr:
          expr
          {
            $$= NEW_PTN PT_order_expr(@$, $1, ORDER_NOT_RELEVANT);
          }
        ;
```

> `expr` 语义组用于解析最高级的一般表达式，即在布尔表达式（`bool_pri`）的基础上使用逻辑运算符（与、或、非、异或）以及 `IS`、`IS NOT` 进行计算的表达式，详见 [MySQL 源码｜72 - 语法解析(V2)：一般表达式（expr）](https://zhuanlan.zhihu.com/p/719447959)。
