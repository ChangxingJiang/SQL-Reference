目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

下面梳理用于解析 `WHERE` 子句、`HAVING` 子句和 `QUALIFY` 子句，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析 - 031 - WHERE、HAVING 和 QUALIFY 子句](C:\blog\graph\MySQL源码剖析\语法解析 - 031 - WHERE、HAVING 和 QUALIFY 子句.png)

#### 语义组：`opt_where_clause`

`opt_where_clause` 语义组用于解析可选的 `WHERE` 子句。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- 标准语法：`[WHERE where_condition]`
- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类
- 使用场景：`SHOW KEYS` 语句（`show_keys_stmt` 语义组）、`DELETE` 语句（`delete_stmt` 语义组）、`HANDLER` 语句（`handler_stmt` 语义组）、`UPDATE` 语句（`update_stmt` 语义组），查询表达式（`query_specification` 语义组）
- Bison 语法如下：

```C++
opt_where_clause:
          %empty { $$ = nullptr; }
        | where_clause
        ;
```

#### 语义组：`where_clause`

`where_clause` 语义组用于解析 `WHERE` 子句。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- 标准语法：`WHERE where_condition`
- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类
- Bison 语法如下：

```C++
where_clause:
          WHERE expr    { $$ = NEW_PTN PTI_where(@2, $2); }
        ;
```

> `expr` 语义组用于解析最高级的一般表达式，详见 [MySQL 源码｜72 - 语法解析(V2)：一般表达式（expr）](https://zhuanlan.zhihu.com/p/719447959)。

#### 语义组：`opt_wild_or_where`

`opt_wild_or_where` 语义组用于解析 `LIKE` 表达式或 `WHERE` 子句。

- 返回值类型：`wild_or_where` 结构体

```C++
  struct {
    LEX_STRING wild;
    Item *where;
  } wild_or_where;
```

- Bison 语法如下：

```C++
opt_wild_or_where:
          %empty                        { $$ = {}; }
        | LIKE TEXT_STRING_literal      { $$ = { $2, {} }; }
        | where_clause                  { $$ = { {}, $1 }; }
        ;
```

> `TEXT_STRING_literal` 语义组用于解析作为普通字面值使用的单引号 / 双引号字符串，详见 [MySQL 源码｜65 - 语法解析(V2)：字符串字面值](https://zhuanlan.zhihu.com/p/717934287)。

#### 语义组：`opt_having_clause`

`opt_having_clause` 语义组用于解析可选的 `HAVING` 子句。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- 标准语法 `[HAVING where_condition]`，Bison 语法如下：
- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类
- Bison 语法如下：

```C++
opt_having_clause:
          %empty { $$= nullptr; }
        | HAVING expr
          {
            $$= new PTI_having(@$, $2);
          }
        ;
```

#### 语义组：`opt_qualify_clause`

`opt_qualify_clause` 语义组用于解析可选的 `QUALIFY` 子句。`QUALIFY` 子句根据用户指定的搜索条件，筛选先前计算的窗口函数的结果。

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类
- Bison 语法如下：

```C++
opt_qualify_clause:
           %empty { $$= nullptr; }
        | QUALIFY_SYM expr
          {
            $$= new PTI_qualify(@$, $2);
          }
        ;
```

