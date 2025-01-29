目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

下面我们梳理 `WITH` 子句，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析 - 030 - WITH 子句](C:\blog\graph\MySQL源码剖析\语法解析 - 030 - WITH 子句.png)

#### 语义组：`opt_with_clause`

`opt_with_clause` 语义组用于解析可选的 `WITH` 子句。

- 官方文档：[MySQL 参考手册 - 15.2.20 WITH (Common Table Expressions)](https://dev.mysql.com/doc/refman/8.0/en/with.html)
- 返回值类型：`PT_with_clause` 对象（`with_clause`）
- 使用场景：`UPDATE` 表达式（`update_stmt` 语义组）、`DELETE` 表达式（`delete_stmt` 表达式）；`SELECT` 表达式直接使用了 `with_clause` 语义组
- Bison 语法如下：

```C++
opt_with_clause:
          %empty { $$= nullptr; }
        | with_clause { $$= $1; }
        ;
```

#### 语义组：`with_clause`

`with_clause` 语义组用于解析 `WITH` 子句。

- 官方文档：[MySQL 参考手册 - 15.2.20 WITH (Common Table Expressions)](https://dev.mysql.com/doc/refman/8.0/en/with.html)
- 标准语法：

```
with_clause:
    WITH [RECURSIVE]
        cte_name [(col_name [, col_name] ...)] AS (subquery)
        [, cte_name [(col_name [, col_name] ...)] AS (subquery)] ...
```

- 返回值类型：`PT_with_clause` 对象（`with_clause`）
- 使用场景：`opt_with_clause` 语义组，查询表达式（`query_expression` 语义组）
- Bison 语法如下：

```C++
with_clause:
          WITH with_list
          {
            $$= NEW_PTN PT_with_clause(@$, $2, false);
          }
        | WITH RECURSIVE_SYM with_list
          {
            $$= NEW_PTN PT_with_clause(@$, $3, true);
          }
        ;
```

#### 语义组：`with_list`

`with_list` 语义组用于解析任意数量、逗号分隔的 `WITH` 子句中的临时表的列表。

- 官方文档：[MySQL 参考手册 - 15.2.20 WITH (Common Table Expressions)](https://dev.mysql.com/doc/refman/8.0/en/with.html)
- 返回值类型：`PT_with_list` 对象（`with_list`）
- Bison 语法如下：

```C++
with_list:
          with_list ',' common_table_expr
          {
            if ($1->push_back($3))
              MYSQL_YYABORT;
            $$->m_pos = @$;
          }
        | common_table_expr
          {
            $$= NEW_PTN PT_with_list(@$, YYTHD->mem_root);
            if ($$ == nullptr || $$->push_back($1))
              MYSQL_YYABORT;    /* purecov: inspected */
          }
        ;
```

#### 语义组：`common_table_expr`

`common_table_expr` 语义组用于解析 `WITH` 子句中的一个临时表。

- 官方文档：[MySQL 参考手册 - 15.2.20 WITH (Common Table Expressions)](https://dev.mysql.com/doc/refman/8.0/en/with.html)
- 标准语法：`cte_name [(col_name [, col_name] ...)] AS (subquery)`
- 返回值类型：`PT_common_table_expr` 对象（`common_table_expr`）
- Bison 语法如下：

```C++
common_table_expr:
          ident opt_derived_column_list AS table_subquery
          {
            LEX_STRING subq_text;
            subq_text.length= @4.cpp.length();
            subq_text.str= YYTHD->strmake(@4.cpp.start, subq_text.length);
            if (subq_text.str == nullptr)
              MYSQL_YYABORT;   /* purecov: inspected */
            uint subq_text_offset= @4.cpp.start - YYLIP->get_cpp_buf();
            $$= NEW_PTN PT_common_table_expr(@$, $1, subq_text, subq_text_offset,
                                             $4, &$2, YYTHD->mem_root);
            if ($$ == nullptr)
              MYSQL_YYABORT;   /* purecov: inspected */
          }
        ;
```

> `ident` 语义组用于解析标识符或任意未保留关键字，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)；
>
> `opt_derived_column_list` 语义组用于解析被小括号框柱的、任意数量、逗号分隔的列表（标识符）的列表，详见 [MySQL 源码｜76 - 语法解析(V2)：表语句（table_reference）](https://zhuanlan.zhihu.com/p/720247259)；
>
> `table_subquery` 语义组用于解析多行子查询，详见 [MySQL 源码｜47 - 语法解析(V2)：子查询](https://zhuanlan.zhihu.com/p/715426420)。

