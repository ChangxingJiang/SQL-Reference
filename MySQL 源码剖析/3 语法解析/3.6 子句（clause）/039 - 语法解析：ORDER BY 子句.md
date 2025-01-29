目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

在 [MySQL 源码｜37 - 语法解析(V2)：聚集函数](https://zhuanlan.zhihu.com/p/714780278) 中，`GROUP_CONCAT()` 函数使用了 `gorder_list` 语义组；在 [MySQL 源码｜38 - 语法解析(V2)：窗口函数](https://zhuanlan.zhihu.com/p/714780506) 中，窗口子句使用了 `order_list` 语义组；在基础查询表达式、UPDATE 表达式和 DELETE 表达式中，使用了 `opt_order_clause` 语义组。下面我们来梳理 ORDER BY 子句的逻辑，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析-021-ORDER BY 子句](C:\blog\graph\MySQL源码剖析\语法解析-021-ORDER BY 子句.png)

#### 语义组：`opt_order_clause`

`opt_order_clause` 语义组用于解析可选的 ORDER BY 子句。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.4/en/select.html)
- 标准语法：`[ORDER BY {col_name | expr | position} [ASC | DESC], ...]`
- 返回值类型：`PT_order` 对象（`order`）
- 使用场景：基础查询表达式（`query_expression` 语义组）、UPDATE 表达式（`update_stmt` 语义组）和 DELETE 表达式（`delete_stmt` 语义组）
- Bison 语法如下：

```C++
opt_order_clause:
          %empty { $$= nullptr; }
        | order_clause
        ;
```

#### 语义组：`order_clause`

`order_clause` 语义组用于解析 ORDER BY 子句。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.4/en/select.html)
- 标准语法：`ORDER BY {col_name | expr | position} [ASC | DESC], ...`
- 返回值类型：`PT_order` 对象（`order`）
- Bison 语法如下：

```C++
order_clause:
          ORDER_SYM BY order_list
          {
            $$= NEW_PTN PT_order(@$, $3);
          }
        ;
```

#### 语义组：`order_list`

`order_list` 语义组用于解析 ORDER BY 子句中任意数量、逗号分隔的排序字段的列表。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.4/en/select.html)
- 标准语法：`{col_name | expr | position} [ASC | DESC], ...`
- 返回值类型：`PT_order_list` 对象（`order_list`）
- Bison 语法如下：

```C++
order_list:
          order_list ',' order_expr
          {
            $1->push_back($3);
            $$= $1;
            $$->m_pos = @$;
          }
        | order_expr
          {
            $$= NEW_PTN PT_order_list(@$);
            if ($$ == nullptr)
              MYSQL_YYABORT;
            $$->push_back($1);
          }
        ;
```

#### 语义组：`order_expr`

`order_expr` 语义组用于解析 ORDER BY 子句中的一个排序字段。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.4/en/select.html)
- 标准语法：`{col_name | expr | position} [ASC | DESC]`
- 返回值类型：`PT_order_expr` 对象（`order_expr`）
- Bison 语法如下：

```C++
order_expr:
          expr opt_ordering_direction
          {
            $$= NEW_PTN PT_order_expr(@$, $1, $2);
          }
        ;
```

> `expr` 语义组用于解析最高级的一般表达式，即在布尔表达式（`bool_pri`）的基础上使用逻辑运算符（与、或、非、异或）以及 `IS`、`IS NOT` 进行计算的表达式，详见 [MySQL 源码｜72 - 语法解析(V2)：一般表达式（expr）](https://zhuanlan.zhihu.com/p/719447959)。

#### 语义组：`opt_ordering_direction`

`opt_ordering_direction` 语义组用于解析 ORDER BY 子句中可选的 `ASC` 关键字或 `DESC` 关键字。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.4/en/select.html)
- 标准语法：`[ASC | DESC]`
- 返回值类型：`enum_order` 枚举值（`order_direction`），其中包括 `ORDER_NOT_RELEVANT`、`ORDER_ASC` 和 `ORDER_DESC` 这 3 个枚举值
- Bison 语法如下：

```C++
opt_ordering_direction:
          %empty { $$= ORDER_NOT_RELEVANT; }
        | ordering_direction
        ;
```

#### 语义组：`ordering_direction`

`ordering_direction` 语义组用于解析 ORDER BY 子句中的 `ASC` 关键字或 `DESC` 关键字。

- 标准语法：`{ASC | DESC}`
- 返回值类型：`enum_order` 枚举值（`order_direction`）
- Bison 语法如下：

```C++
ordering_direction:
          ASC         { $$= ORDER_ASC; }
        | DESC        { $$= ORDER_DESC; }
        ;
```

#### 语义组：`gorder_list`

`gorder_list` 语义组用于解析 `GROUP_CONCAT()` 函数中的 ORDER BY 子句中的任意数量、逗号分隔的排序字段列表。

- 官方文档：[MySQL 8.0 参考手册：14.19.1 Aggregate Function Descriptions](https://dev.mysql.com/doc/refman/8.0/en/aggregate-functions.html#function_json-arrayagg)
- 标准语法：`{unsigned_integer | col_name | expr} [ASC | DESC] [,col_name ...]`
- 返回值类型：`PT_order_list` 对象（`order_list`）
- Bison 语法如下：

```C++
gorder_list:
          gorder_list ',' order_expr
          {
            $1->push_back($3);
            $$= $1;
            // This will override earlier list, until
            // we get the whole location.
            $$->m_pos = @$;
          }
        | order_expr
          {
            $$= NEW_PTN PT_gorder_list(@$);
            if ($$ == nullptr)
              MYSQL_YYABORT;
            $$->push_back($1);
          }
        ;
```

