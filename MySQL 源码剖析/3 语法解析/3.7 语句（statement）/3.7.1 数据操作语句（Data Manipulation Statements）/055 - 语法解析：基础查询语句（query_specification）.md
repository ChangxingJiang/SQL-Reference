目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

前置文档：

- [MySQL 源码｜68 - 语法解析(V2)：LOCKING 子句（锁定读取）](https://zhuanlan.zhihu.com/p/719010523)｜V20240909
- [MySQL 源码｜39 - 语法解析(V2)：ORDER BY 子句](https://zhuanlan.zhihu.com/p/714781112)｜V20240814｜V20240912（第 2 版）
- [MySQL 源码｜40 - 语法解析(V2)：GROUP BY 子句](https://zhuanlan.zhihu.com/p/714781362)｜V20240814｜V20240912（第 2 版）
- [MySQL 源码｜54 - 语法解析(V2)：WINDOW 子句](https://zhuanlan.zhihu.com/p/716014095)｜V20240822｜V20240912（第 2 版）
- [MySQL 源码｜74 - 语法解析(V2)：JSON_TABLE 函数](https://zhuanlan.zhihu.com/p/720046825)｜V20240913
- [MySQL 源码｜75 - 语法解析(V2)：索引提示子句（USE、FORCE、IGNORE）](https://zhuanlan.zhihu.com/p/720054242)｜V20240913
- [MySQL 源码｜52 - 语法解析(V2)：FROM 子句和 JOIN 子句](https://zhuanlan.zhihu.com/p/715841708)｜V20240822｜V20240914（第 2 版）
- [MySQL 源码｜53 - 语法解析(V2)：INTO 子句](https://zhuanlan.zhihu.com/p/715903798)｜V20240822｜V20240915（第 2 版）
- [MySQL 源码｜56 - 语法解析(V2)：WITH 子句](https://zhuanlan.zhihu.com/p/716036308)｜V20240823｜V20240915（第 2 版）
- [MySQL 源码｜77 - 语法解析(V2)：WHERE、HAVING 和 QUALIFY 子句](https://zhuanlan.zhihu.com/p/720281792)｜V20240915

---

在此之前，我们已经梳理了基础查询语句中涉及的 `INTO` 子句、`FROM` 子句、`JOIN` 子句、索引指示子句（`USE`、`FORCE` 或 `IGNORE` 关键字引导）、`WHERE` 子句、`GROUP BY` 子句、`HAVING` 子句、`QUALIFY` 子句、`WINDOW` 子句和 `ORDER BY` 子句，下面我们来梳理解析基础查询语句的 `query_specification` 语义组。其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析 - 032 - 基础查询语句](C:\blog\graph\MySQL源码剖析\语法解析 - 032 - 基础查询语句.png)

#### 语义组：`query_specification`

`query_specification` 语义组用于解析基础查询语句。在这个语义组中不包含 `ORDER BY` 子句和 `LIMIT` 子句，是因为 MySQL 的查询树结构中，`ORDER BY` 子句和 `LIMIT` 子句的逻辑保存在 `Query_block` 之中，而这个语义组解析的是 `Query_expression`。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- 标准语法：

```
SELECT
    [ALL | DISTINCT | DISTINCTROW ]
    [HIGH_PRIORITY]
    [STRAIGHT_JOIN]
    [SQL_SMALL_RESULT] [SQL_BIG_RESULT] [SQL_BUFFER_RESULT]
    [SQL_NO_CACHE] [SQL_CALC_FOUND_ROWS]
    select_expr [, select_expr] ...
    [into_option]
    [FROM table_references
      [PARTITION partition_list]]
    [WHERE where_condition]
    [GROUP BY {col_name | expr | position}, ... [WITH ROLLUP]]
    [HAVING where_condition]
    [WINDOW window_name AS (window_spec)
        [, window_name AS (window_spec)] ...]
```

- 返回值类型：`PT_query_primary` 对象（`query_primary`），其中 `PT_query_primary` 为 `PT_query_expression_body` 的子类
- 使用场景：`query_primary` 语义组
- Bison 语法如下（两种备选规则的差异在于是否包含 `INTO` 子句）：

```C++
query_specification:
          SELECT_SYM
          select_options
          select_item_list
          into_clause
          opt_from_clause
          opt_where_clause
          opt_group_clause
          opt_having_clause
          opt_window_clause
          opt_qualify_clause
          {
            $$= NEW_PTN PT_query_specification(
                                      @$,
                                      $1,  // SELECT_SYM
                                      $2,  // select_options
                                      $3,  // select_item_list
                                      $4,  // into_clause
                                      $5,  // from
                                      $6,  // where
                                      $7,  // group
                                      $8,  // having
                                      $9,  // windows
                                      $10, // qualify
                                      @5.raw.is_empty()); // implicit FROM
          }
        | SELECT_SYM
          select_options
          select_item_list
          opt_from_clause
          opt_where_clause
          opt_group_clause
          opt_having_clause
          opt_window_clause
          opt_qualify_clause
          {
            $$= NEW_PTN PT_query_specification(
                                      @$,
                                      $1,  // SELECT_SYM
                                      $2,  // select_options
                                      $3,  // select_item_list
                                      nullptr,// no INTO clause
                                      $4,  // from
                                      $5,  // where
                                      $6,  // group
                                      $7,  // having
                                      $8,  // windows
                                      $9,  // qualify
                                      @4.raw.is_empty()); // implicit FROM
          }
        ;
```

> `select_options` 语义组用于解析可选的查询选项，详见下文；
>
> `select_item_list` 语义组用于解析查询字段的列表，详见下文；
>
> `into_clause` 语义组用于解析 `INTO` 子句，详见 [MySQL 源码｜53 - 语法解析(V2)：INTO 子句](https://zhuanlan.zhihu.com/p/715903798)；
>
> `opt_from_clause` 语义组用于解析可选的 `FROM` 子句，其中包含 `JOIN` 子句，详见 [MySQL 源码｜52 - 语法解析(V2)：FROM 子句和 JOIN 子句](https://zhuanlan.zhihu.com/p/715841708)；
>
> `opt_where_clause` 语义组用于解析可选的 `WHERE` 子句，详见 [MySQL 源码｜77 - 语法解析(V2)：WHERE、HAVING 和 QUALIFY 子句](https://zhuanlan.zhihu.com/p/720281792)；
>
> `opt_group_clause` 语义组用于解析可选的 `GROUP BY` 子句，详见 [MySQL 源码｜40 - 语法解析(V2)：GROUP BY 子句](https://zhuanlan.zhihu.com/p/714781362)；
>
> `opt_having_clause` 语义组用于解析可选的 `HAVING` 子句，详见 [MySQL 源码｜77 - 语法解析(V2)：WHERE、HAVING 和 QUALIFY 子句](https://zhuanlan.zhihu.com/p/720281792)；
>
> `opt_window_clause` 语义组用于解析 `WINDOW` 子句，指定有名称的窗口以便在查询表达式的其他位置复用，详见 [MySQL 源码｜54 - 语法解析(V2)：WINDOW 子句](https://zhuanlan.zhihu.com/p/716014095)；
>
> `opt_qualify_clause` 语义组用于解析可选的 `QUALIFY` 子句，详见 [MySQL 源码｜77 - 语法解析(V2)：WHERE、HAVING 和 QUALIFY 子句](https://zhuanlan.zhihu.com/p/720281792)。

#### 语义组：`select_options`

`select_options` 语义组用于解析可选的、任意数量、空格分隔的查询选项。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- 标准语法：

```
    [ALL | DISTINCT | DISTINCTROW ]
    [HIGH_PRIORITY]
    [STRAIGHT_JOIN]
    [SQL_SMALL_RESULT] [SQL_BIG_RESULT] [SQL_BUFFER_RESULT]
    [SQL_NO_CACHE] [SQL_CALC_FOUND_ROWS]
```

- 返回值类型：`Query_options` 结构体（`select_options`），其中包含状态压缩 `query_spec_options` 属性。
- Bison 语法如下：

```C++
select_options:
          %empty
          {
            $$.query_spec_options= 0;
          }
        | select_option_list
        ;
```

#### 语义组：`select_option_list`

`select_option_list` 语义组用于解析大于等于 1 个、空格分隔的查询选项。

- 返回值类型：`Query_options` 结构体（`select_options`）
- Bison 语法如下：

```C++
select_option_list:
          select_option_list select_option
          {
            if ($$.merge($1, $2))
              MYSQL_YYABORT;
          }
        | select_option
        ;
```

#### 语义组：`select_option`

`select_option` 语义组用于解析一个查询选项。

- 返回值类型：`Query_options` 结构体（`select_options`）
- Bison 语法如下：

```C++
select_option:
          query_spec_option
          {
            $$.query_spec_options= $1;
          }
        | SQL_NO_CACHE_SYM
          {
            push_deprecated_warn_no_replacement(YYTHD, "SQL_NO_CACHE");
            /* Ignored since MySQL 8.0. */
            $$.query_spec_options= 0;
          }
        ;
```

#### 语义组：`query_spec_option`

`query_spec_option` 语义组用于解析除 `SQL_NO_CACHE` 之外的其他查询选项。

- 返回值类型：`unsigned long long int` 类型（`ulonglong_number`）
- Bison 语法如下：

```C++
query_spec_option:
          STRAIGHT_JOIN       { $$= SELECT_STRAIGHT_JOIN; }
        | HIGH_PRIORITY       { $$= SELECT_HIGH_PRIORITY; }
        | DISTINCT            { $$= SELECT_DISTINCT; }
        | SQL_SMALL_RESULT    { $$= SELECT_SMALL_RESULT; }
        | SQL_BIG_RESULT      { $$= SELECT_BIG_RESULT; }
        | SQL_BUFFER_RESULT   { $$= OPTION_BUFFER_RESULT; }
        | SQL_CALC_FOUND_ROWS {
            push_warning(YYTHD, Sql_condition::SL_WARNING,
                         ER_WARN_DEPRECATED_SYNTAX,
                         ER_THD(YYTHD, ER_WARN_DEPRECATED_SQL_CALC_FOUND_ROWS));
            $$= OPTION_FOUND_ROWS;
          }
        | ALL                 { $$= SELECT_ALL; }
        ;
```

#### 语义组：`select_item_list`

`select_item_list` 语义组用于解析逗号分隔、任意数量的查询字段或通配符 `*`。

- 返回值类型：`PT_item_list` 对象（`item_list2`）
- Bison 语法如下：

```C++
select_item_list:
          select_item_list ',' select_item
          {
            if ($1 == nullptr || $1->push_back($3))
              MYSQL_YYABORT;
            $$= $1;
            $$->m_pos = @$;
          }
        | select_item
          {
            $$= NEW_PTN PT_select_item_list(@$);
            if ($$ == nullptr || $$->push_back($1))
              MYSQL_YYABORT;
          }
        | '*'
          {
            Item *item = NEW_PTN Item_asterisk(@$, nullptr, nullptr);
            $$ = NEW_PTN PT_select_item_list(@$);
            if ($$ == nullptr || item == nullptr || $$->push_back(item))
              MYSQL_YYABORT;
          }
        ;
```

#### 语义组：`select_item`

`select_item` 语义组用于解析单个查询字段。

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类
- Bison 语法如下：

```C++
select_item:
          table_wild { $$= $1; }
        | expr select_alias
          {
            $$= NEW_PTN PTI_expr_with_alias(@$, $1, @1.cpp, to_lex_cstring($2));
          }
        ;
```

> `table_wild` 语义组用于解析 `ident.*` 或 `ident.ident.*`，详见下文；
>
> `expr` 语义组用于解析最高级的一般表达式，详见 [MySQL 源码｜72 - 语法解析(V2)：一般表达式（expr）](https://zhuanlan.zhihu.com/p/719447959)；
>
> `select_alias` 语义组用于解析可选的 `AS` 关键字引导（可省略）别名子句，详见 [MySQL 源码｜45 - 语法解析(V2)：通用函数](https://zhuanlan.zhihu.com/p/715159997)。

- `table_wild` 规则用于匹配 `ident.*` 或 `ident.ident.*` 的通配符名称
- `expr` 规则用于匹配一般表达式
- `select_alias` 规则用于匹配 `AS` 子句指定别名

#### 语义组：`table_wild` 规则

`table_wild` 语义组用于解析 `ident.*` 或 `ident.ident.*`。

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类
- Bison 语法如下：

```C++
table_wild:
          ident '.' '*'
          {
            $$ = NEW_PTN Item_asterisk(@$, nullptr, $1.str);
          }
        | ident '.' ident '.' '*'
          {
            if (check_and_convert_db_name(&$1, false) != Ident_name_check::OK)
              MYSQL_YYABORT;
            auto schema_name = YYCLIENT_NO_SCHEMA ? nullptr : $1.str;
            $$ = NEW_PTN Item_asterisk(@$, schema_name, $3.str);
          }
        ;
```

> `ident` 语义组用于解析标识符或任意未保留关键字，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)。
