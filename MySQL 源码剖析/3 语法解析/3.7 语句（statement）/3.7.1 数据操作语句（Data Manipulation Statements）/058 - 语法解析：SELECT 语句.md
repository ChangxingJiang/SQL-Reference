目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

前置文档：

- [MySQL 源码｜55 - 语法解析(V2)：基础查询语句（query_specification）](https://zhuanlan.zhihu.com/p/716034780)
- [MySQL 源码｜68 - 语法解析(V2)：LOCKING 子句（锁定读取）](https://zhuanlan.zhihu.com/p/719010523)
- [MySQL 源码｜53 - 语法解析(V2)：INTO 子句](https://zhuanlan.zhihu.com/p/715903798)

---

下面我们梳理用于解析 `SELECT` 语句的 `select_stmt` 语义组，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析 - 034 - SELECT 语句](C:\blog\graph\MySQL源码剖析\语法解析 - 034 - SELECT 语句.png)

#### 语义组：`select_stmt`

`select_stmt` 语义组用于解析可选添加设置读取锁定子句、可选添加 `INTO` 子句的 `SELECT` 语句。

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
    [ORDER BY {col_name | expr | position}
      [ASC | DESC], ... [WITH ROLLUP]]
    [LIMIT {[offset,] row_count | row_count OFFSET offset}]
    [into_option]
    [FOR {UPDATE | SHARE}
        [OF tbl_name [, tbl_name] ...]
        [NOWAIT | SKIP LOCKED]
      | LOCK IN SHARE MODE]
    [into_option]

into_option: {
    INTO OUTFILE 'file_name'
        [CHARACTER SET charset_name]
        export_options
  | INTO DUMPFILE 'file_name'
  | INTO var_name [, var_name] ...
}
```

- 返回值类型：`Parse_tree_root` 对象（`top_level_node`），用于存储最顶层节点，即语句层级节点
- Bison 语法如下：

```C++
select_stmt:
          query_expression
          {
            $$ = NEW_PTN PT_select_stmt(@$, $1);
          }
        | query_expression locking_clause_list
          {
            $$ = NEW_PTN PT_select_stmt(@$, NEW_PTN PT_locking(@$, $1, $2),
                                        nullptr, true);
          }
        | select_stmt_with_into
        ;
```

> `query_expression` 用于解析不包含设置读取锁定子句的 `SELECT` 查询语句，其中有包含和不包含 `WITH` 子句两种备选规则，详见下文；
>
> `locking_clause_list` 语义组用于解析空格分隔、任意数量的设置读取锁定的 Locking 子句，详见 [MySQL 源码｜68 - 语法解析(V2)：LOCKING 子句（锁定读取）](https://zhuanlan.zhihu.com/p/719010523)；
>
> `select_stmt_with_into` 语义组用于解析在嵌套任意层小括号的、末尾包含 `INTO` 子句的 `SELECT` 查询语句，主要用于兼容 `INTO` 子句和设置读取锁定子句的各种先后顺序，详见下文。

#### 语义组：`query_expression`

`query_expression` 用于解析不包含设置读取锁定子句、不包含 `INTO` 子句的 `SELECT` 语句，其中有包含和不包含 `WITH` 子句两种备选规则。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- 返回值类型：`PT_query_expression` 对象（`query_expression`）
- Bison 语法如下：

```C++
query_expression:
          query_expression_body
          opt_order_clause
          opt_limit_clause
          {
            $$ = NEW_PTN PT_query_expression(@$, $1.body, $2, $3);
          }
        | with_clause
          query_expression_body
          opt_order_clause
          opt_limit_clause
          {
            $$= NEW_PTN PT_query_expression(@$, $1, $2.body, $3, $4);
          }
        ;
```

> `query_expression_body` 语义组用于解析除 `WITH` 子句、设置读取锁定子句、`ORDER BY` 子句和 `LIMIT` 子句外的 `SELECT` 查询语句，详见下文；
>
> `opt_order_clause` 语义组用于解析可选的 ORDER BY 子句，详见 [MySQL 源码｜39 - 语法解析(V2)：ORDER BY 子句](https://zhuanlan.zhihu.com/p/714781112)；
>
> `opt_limit_clause` 语义组用于解析可选的 `LIMIT` 子句，详见 [MySQL 源码｜78 - 语法解析(V2)：LIMIT 子句](https://zhuanlan.zhihu.com/p/720293254)；
>
> `with_clause` 语义组用于解析 `WITH` 子句，详见 [MySQL 源码｜56 - 语法解析(V2)：WITH 子句](https://zhuanlan.zhihu.com/p/716036308)。

#### 语义组：`select_stmt_with_into`

`select_stmt_with_into` 语义组用于解析嵌套任意层小括号的、包含 `INTO` 子句的 `SELECT` 查询语句，主要用于兼容 `INTO` 子句和设置读取锁定子句的各种先后顺序。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- 返回值类型：`Parse_tree_root` 对象（`top_level_node`），用于存储最顶层节点，即语句层级节点
- Bison 语法如下：

```C++
select_stmt_with_into:
          '(' select_stmt_with_into ')'
          {
            $$ = $2;
            if ($$ != nullptr) $$->m_pos = @$;
          }
        | query_expression into_clause
          {
            $$ = NEW_PTN PT_select_stmt(@$, $1, $2);
          }
        | query_expression into_clause locking_clause_list
          {
            $$ = NEW_PTN PT_select_stmt(@$, NEW_PTN PT_locking(@$, $1, $3), $2, true);
          }
        | query_expression locking_clause_list into_clause
          {
            $$ = NEW_PTN PT_select_stmt(@$, NEW_PTN PT_locking(@$, $1, $2), $3);
          }
        ;
```

> `into_clause` 语义组用于解析 `INTO` 子句，详见 [MySQL 源码｜53 - 语法解析(V2)：INTO 子句](https://zhuanlan.zhihu.com/p/715903798)；
>
> `locking_clause_list` 语义组用于解析空格分隔、任意数量的设置读取锁定的 Locking 子句，详见 [MySQL 源码｜68 - 语法解析(V2)：LOCKING 子句（锁定读取）](https://zhuanlan.zhihu.com/p/719010523)。

#### 语义组：`query_expression_with_opt_locking_clauses`

`query_expression_with_opt_locking_clauses` 语义组用于解析可选是否包含设置读取锁定子句、不包含 `INTO` 子句的 `SELECT` 查询语句。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- 返回值类型：`PT_query_expression_body` 对象（`query_expression_body`）
- Bison 语法如下：

```C++
query_expression_with_opt_locking_clauses:
          query_expression                      { $$ = $1; }
        | query_expression locking_clause_list
          {
            $$ = NEW_PTN PT_locking(@$, $1, $2);
          }
        ;
```

#### 语义组：`query_expression_parens`

`query_expression_parens` 语义组用于解析嵌套大于等于一层小括号的、可选是否包含设置读取锁定子句、不包含 `INTO` 子句的 `SELECT` 子句。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- 返回值类型：`PT_query_expression_body` 对象（`query_expression_body`）
- Bison 语法如下：

```C++
query_expression_parens:
          '(' query_expression_parens ')'
          { $$ = $2;
            if ($$ != nullptr) $$->m_pos = @$;
          }
        | '(' query_expression_with_opt_locking_clauses')'
          { $$ = $2;
            if ($$ != nullptr) $$->m_pos = @$;
          }
        ;
```

#### 语义组：`query_expression_body`

`query_expression_body` 语义组用于解析不包含 `WITH` 子句、设置读取锁定子句、`INTO` 子句、`ORDER BY` 子句和 `LIMIT` 子句的 `SELECT` 语句，或被括号框柱的不包含 `INTO` 子句的 `SELECT` 子句，允许使用 `UNION`、`EXCEPT` 和 `INTERSECT` 联结的多个表。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- 返回值类型：`PT_query_expression_body` 对象（`query_expression_body`）
- 备选规则与 Bison 语法如下：

| 备选规则                                                     | 规则含义                                                     |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| `query_primary`                                              | 基础查询语句、使用值列表构造的单个表语句或 `TABLE` 关键字引导的表引用 |
| `query_expression_parens`                                    | 嵌套大于等于一层小括号的、可选是否包含设置读取锁定子句、不包含 `INTO` 子句的 `SELECT` 子句 |
| `query_expression_body UNION_SYM union_option query_expression_body` | 使用 `UNION` 关键字联结的两个表                              |
| `query_expression_body EXCEPT_SYM union_option query_expression_body` | 使用 `EXCEPT` 关键字联结的两个表                             |
| `query_expression_body INTERSECT_SYM union_option query_expression_body` | 使用 `INTERSECT` 关键字联结的两个表                          |

```C++
query_expression_body:
          query_primary
          {
            $$ = {$1, false};
          }
        | query_expression_parens %prec SUBQUERY_AS_EXPR
          {
            $$ = {$1, true};
          }
        | query_expression_body UNION_SYM union_option query_expression_body
          {
            $$ = {NEW_PTN PT_union(@$, $1.body, $3, $4.body, $4.is_parenthesized),
                  false};
          }
        | query_expression_body EXCEPT_SYM union_option query_expression_body
          {
            $$ = {NEW_PTN PT_except(@$, $1.body, $3, $4.body, $4.is_parenthesized),
                  false};
          }
        | query_expression_body INTERSECT_SYM union_option query_expression_body
          {
            $$ = {NEW_PTN PT_intersect(@$, $1.body, $3, $4.body, $4.is_parenthesized),
                  false};
          }
        ;
```

> `query_primary` 语义组用于解析基础查询语句、使用值列表构造的单个表语句或 `TABLE` 关键字引导的表引用，详见下文；
>
> `union_option` 规则：用于匹配可选的 `DISTINCT` 关键字或 `ALL` 关键字，详见下文。

#### 语义组：`query_primary`

`query_primary` 语义组用于解析基础查询语句、使用值列表构造的单个表语句或 `TABLE` 关键字引导的表引用。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- 返回值类型：`PT_query_primary` 对象（`query_primary`），其中 `PT_query_primary` 为 `PT_query_expression_body` 的子类
- Bison 语法如下：

```C++
query_primary:
          query_specification
          {
            // Bison doesn't get polymorphism.
            $$= $1;
          }
        | table_value_constructor
          {
            $$= NEW_PTN PT_table_value_constructor(@$, $1);
          }
        | explicit_table
          {
            // Pass empty position because asterisk is not user-supplied.
            auto item_list= NEW_PTN PT_select_item_list(POS());
            auto asterisk= NEW_PTN Item_asterisk(POS(), nullptr, nullptr);
            if (item_list == nullptr || asterisk == nullptr ||
                item_list->push_back(asterisk))
              MYSQL_YYABORT;
            $$= NEW_PTN PT_explicit_table(@$, {}, item_list, $1);
          }
        ;
```

> `query_specification` 语义组用于解析基础查询语句，详见 [MySQL 源码｜55 - 语法解析(V2)：基础查询语句（query_specification）](https://zhuanlan.zhihu.com/p/716034780)；
>
> `table_value_constructor` 语义组用于解析使用 `VALUE` 关键字引导的值列表构造的表语句，详见下文；
>
> `explicit_table` 语义组用于解析使用 `TABLE` 关键字引导的指定表名的表语句，详见下文。

#### 语义组：`table_value_constructor`

`table_value_constructor` 语义组用于解析使用 `VALUE` 关键字引导的值列表构造的表语句。

- 返回值类型：`PT_insert_values_list` 对象（`values_list`）
- Bison 语法如下：

```C++
table_value_constructor:
          VALUES values_row_list
          {
            $$= $2;
          }
        ;
```

#### 语义组：`values_row_list`

`values_row_list` 语义组用于解析任意数量、逗号分隔的 `ROW (values)` 表达式。

- 返回值类型：`PT_insert_values_list` 对象（`values_list`）
- Bison 语法如下：

```C++
values_row_list:
          values_row_list ',' row_value_explicit
          {
            if ($$->push_back(&$3->value))
              MYSQL_YYABORT;
            $$->m_pos = @$;
          }
        | row_value_explicit
          {
            $$= NEW_PTN PT_insert_values_list(@$, YYMEM_ROOT);
            if ($$ == nullptr || $$->push_back(&$1->value))
              MYSQL_YYABORT;
          }
        ;
```

#### 语义组：`row_value_explicit`

`row_value_explicit` 语义组用于解析单个 `ROW(values)` 表达式。

- 返回值类型：`PT_item_list` 类型（`item_list2`）
- Bison 语法如下：

```C++
row_value_explicit:
          ROW_SYM '(' opt_values ')' { $$= $3; }
        ;
```

#### 语义组：`opt_values`

`opt_values` 语义组用于解析可选的值列表。

- 返回值类型：`PT_item_list` 类型（`item_list2`）
- Bison 语法如下：

```C++
opt_values:
          %empty
          {
            $$= NEW_PTN PT_item_list(POS());
            if ($$ == nullptr)
              MYSQL_YYABORT;
          }
        | values
        ;
```

#### 语义组：`values`

`values` 语义组用于解析大于等于一个、逗号分隔的值。

- 返回值类型：`PT_item_list` 类型（`item_list2`）
- Bison 语法如下：

```C++
values:
          values ','  expr_or_default
          {
            if ($1->push_back($3))
              MYSQL_YYABORT;
            $$= $1;
            $$->m_pos = @$;
          }
        | expr_or_default
          {
            $$= NEW_PTN PT_item_list(@$);
            if ($$ == nullptr || $$->push_back($1))
              MYSQL_YYABORT;
          }
        ;
```

#### 语义组：`expr_or_default`

`expr_or_default` 语义组用于解析一般表达式或 `DEFAULT` 关键字。

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类
- Bison 语法如下：

```C++
expr_or_default:
          expr
        | DEFAULT_SYM
          {
            $$= NEW_PTN Item_default_value(@$);
          }
        ;
```

> `expr` 语义组用于解析最高级的一般表达式，即在布尔表达式（`bool_pri`）的基础上使用逻辑运算符（与、或、非、异或）以及 `IS`、`IS NOT` 进行计算的表达式，详见 [MySQL 源码｜72 - 语法解析(V2)：一般表达式（expr）](https://zhuanlan.zhihu.com/p/719447959)。

#### 语义组：`explicit_table`

`explicit_table` 语义组用于解析使用 `TABLE` 关键字引导的指定表名的表语句。

- 返回值类型：`Mem_root_array_YY<PT_table_reference *>`（`table_reference_list`）
- Bison 语法如下：

```C++
explicit_table:
          TABLE_SYM table_ident
          {
            $$.init(YYMEM_ROOT);
            auto table= NEW_PTN
                PT_table_factor_table_ident(@$, $2, nullptr, NULL_CSTR, nullptr);
            if ($$.push_back(table))
              MYSQL_YYABORT; // OOM
          }
        ;
```

> `table_ident` 语义组用于解析 `ident` 或 `ident.ident`，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)

#### 语义组：`union_option`

`union_option` 语义组用于解析可选的 `DISTINCT` 关键字或 `ALL` 关键字。

- 返回值类型：`int` 类型（`num`）
- Bison 语法如下：

```C++
union_option:
          %empty    { $$=1; }
        | DISTINCT  { $$=1; }
        | ALL       { $$=0; }
        ;
```

