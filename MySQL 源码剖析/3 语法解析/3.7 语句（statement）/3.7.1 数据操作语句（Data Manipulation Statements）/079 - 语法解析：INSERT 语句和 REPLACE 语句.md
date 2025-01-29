目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

下面我们梳理用于解析 `INSERT` 语句的 `insert_stmt` 语义组和 `REPLACE` 语句的 `replace_stmt` 语义组。其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析 - 038 - INSERT 语句和 REPLACE 语句](C:\blog\graph\MySQL源码剖析\语法解析 - 038 - INSERT 语句和 REPLACE 语句.png)

### `INSERT` 语句

#### 语义组：`insert_stmt`

`insert_stmt` 语义组用于解析 `INSERT` 语句。

- 官方文档：[MySQL 参考手册 - 15.2.7 INSERT Statement](https://dev.mysql.com/doc/refman/8.4/en/insert.html)
- 标准语法：

```C++
INSERT [LOW_PRIORITY | DELAYED | HIGH_PRIORITY] [IGNORE]
    [INTO] tbl_name
    [PARTITION (partition_name [, partition_name] ...)]
    [(col_name [, col_name] ...)]
    { {VALUES | VALUE} (value_list) [, (value_list)] ... }
    [AS row_alias[(col_alias [, col_alias] ...)]]
    [ON DUPLICATE KEY UPDATE assignment_list]

INSERT [LOW_PRIORITY | DELAYED | HIGH_PRIORITY] [IGNORE]
    [INTO] tbl_name
    [PARTITION (partition_name [, partition_name] ...)]
    SET assignment_list
    [AS row_alias[(col_alias [, col_alias] ...)]]
    [ON DUPLICATE KEY UPDATE assignment_list]

INSERT [LOW_PRIORITY | HIGH_PRIORITY] [IGNORE]
    [INTO] tbl_name
    [PARTITION (partition_name [, partition_name] ...)]
    [(col_name [, col_name] ...)]
    { SELECT ... 
      | TABLE table_name 
      | VALUES row_constructor_list
    }
    [ON DUPLICATE KEY UPDATE assignment_list]

value:
    {expr | DEFAULT}

value_list:
    value [, value] ...

row_constructor_list:
    ROW(value_list)[, ROW(value_list)][, ...]

assignment:
    col_name = 
          value
        | [row_alias.]col_name
        | [tbl_name.]col_name
        | [row_alias.]col_alias

assignment_list:
    assignment [, assignment] ...
```

- 返回值类型：`Parse_tree_root` 对象（`top_level_node`），用于存储最顶层节点，即语句层级节点
- Bison 语法如下：

```C++
/*
** Insert : add new data to table
*/

insert_stmt:
          INSERT_SYM                   /* #1 */
          insert_lock_option           /* #2 */
          opt_ignore                   /* #3 */
          opt_INTO                     /* #4 */
          table_ident                  /* #5 */
          opt_use_partition            /* #6 */
          insert_from_constructor      /* #7 */
          opt_values_reference         /* #8 */
          opt_insert_update_list       /* #9 */
          {
            DBUG_EXECUTE_IF("bug29614521_simulate_oom",
                             DBUG_SET("+d,simulate_out_of_memory"););
            $$= NEW_PTN PT_insert(@$, false, $1, $2, $3, $5, $6,
                                  $7.column_list, $7.row_value_list,
                                  nullptr,
                                  $8.table_alias, $8.column_list,
                                  $9.column_list, $9.value_list);
            DBUG_EXECUTE_IF("bug29614521_simulate_oom",
                            DBUG_SET("-d,bug29614521_simulate_oom"););
          }
        | INSERT_SYM                   /* #1 */
          insert_lock_option           /* #2 */
          opt_ignore                   /* #3 */
          opt_INTO                     /* #4 */
          table_ident                  /* #5 */
          opt_use_partition            /* #6 */
          SET_SYM                      /* #7 */
          update_list                  /* #8 */
          opt_values_reference         /* #9 */
          opt_insert_update_list       /* #10 */
          {
            PT_insert_values_list *one_row= NEW_PTN PT_insert_values_list(@$, YYMEM_ROOT);
            if (one_row == nullptr || one_row->push_back(&$8.value_list->value))
              MYSQL_YYABORT; // OOM
            $$= NEW_PTN PT_insert(@$, false, $1, $2, $3, $5, $6,
                                  $8.column_list, one_row,
                                  nullptr,
                                  $9.table_alias, $9.column_list,
                                  $10.column_list, $10.value_list);
          }
        | INSERT_SYM                   /* #1 */
          insert_lock_option           /* #2 */
          opt_ignore                   /* #3 */
          opt_INTO                     /* #4 */
          table_ident                  /* #5 */
          opt_use_partition            /* #6 */
          insert_query_expression      /* #7 */
          opt_insert_update_list       /* #8 */
          {
            $$= NEW_PTN PT_insert(@$, false, $1, $2, $3, $5, $6,
                                  $7.column_list, nullptr,
                                  $7.insert_query_expression,
                                  NULL_CSTR, nullptr,
                                  $8.column_list, $8.value_list);
          }
        ;
```

> `insert_lock_option` 语义组用于解析 `LOW_PRIORITY`、`DELAYED` 或 `HIGH_PRIORITY` 关键字，详见下文；
>
> `opt_ignore` 语义组用于解析可选的 `IGNORE` 关键字，详见 [MySQL 源码｜57 - 语法解析(V2)：UPDATE 表达式和 DELETE 表达式](https://zhuanlan.zhihu.com/p/716038847)；
>
> `opt_INTO` 语义组用于解析可选的 `INTO` 关键字，详见下文；
>
> `table_ident` 语义组用于解析 `ident` 或 `ident.ident`，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)；
>
> `opt_use_partition` 语义组用于解析可选的 `PARTITION` 子句，详见 [MySQL 源码｜76 - 语法解析(V2)：表语句（table_reference）](https://zhuanlan.zhihu.com/p/720247259)；
>
> `insert_from_constructor` 语义组用于解析 `INSERT` 语句和 `REPLACE` 语句中的字段列表和值列表，详见下文；
>
> `opt_values_reference` 语义组用于解析 `INSERT` 语句中可选的 `AS` 子句，详见下文；
>
> `opt_insert_update_list` 语义组用于解析 `INSERT` 语句中的 `ON DUPLCIATE KEY UPDATE` 子句，详见下文；
>
> `update_list` 语义组用于解析任意数量、逗号分隔的赋值语句，详见 [MySQL 源码｜57 - 语法解析(V2)：UPDATE 表达式和 DELETE 表达式](https://zhuanlan.zhihu.com/p/716038847)；
>
> `insert_query_expression` 语义组

#### 语义组：`insert_lock_option`

`insert_lock_option` 语义组用于解析 `LOW_PRIORITY`、`DELAYED` 或 `HIGH_PRIORITY` 关键字。

- 返回值类型：`thr_lock_type` 枚举值（`lock_type`）
- Bison 语法如下：

```C++
insert_lock_option:
          %empty { $$= TL_WRITE_CONCURRENT_DEFAULT; }
        | LOW_PRIORITY  { $$= TL_WRITE_LOW_PRIORITY; }
        | DELAYED_SYM
        {
          $$= TL_WRITE_CONCURRENT_DEFAULT;

          push_warning_printf(YYTHD, Sql_condition::SL_WARNING,
                              ER_WARN_LEGACY_SYNTAX_CONVERTED,
                              ER_THD(YYTHD, ER_WARN_LEGACY_SYNTAX_CONVERTED),
                              "INSERT DELAYED", "INSERT");
        }
        | HIGH_PRIORITY { $$= TL_WRITE; }
        ;
```

#### 语义组：`opt_INTO`

`opt_INTO` 语义组用于解析可选的 `INTO` 关键字。

- 返回值类型：没有返回值
- Bison 语法如下：

```C++
opt_INTO:
          %empty
        | INTO
        ;
```

#### 语义组：`insert_from_constructor`

`insert_from_constructor` 语义组用于解析 `INSERT` 语句和 `REPLACE` 语句中的字段列表和值列表。

- 官方文档：[MySQL 参考手册 - 15.2.7 INSERT Statement](https://dev.mysql.com/doc/refman/8.4/en/insert.html)
- 标准语法：`[(col_name [, col_name] ...)] { {VALUES | VALUE} (value_list) [, (value_list)] ... }`
- 返回值类型：`column_row_value_list_pair` 结构体，包含 `PT_item_list` 类型的 `column_list` 成员和 `PT_insert_values_list` 类型的 `row_value_list` 成员
- Bison 语法如下：

```C++
insert_from_constructor:
          insert_values
          {
            // No position because there is no column list.
            $$.column_list= NEW_PTN PT_item_list(POS());
            $$.row_value_list= $1;
          }
        | '(' ')' insert_values
          {
            $$.column_list= NEW_PTN PT_item_list(POS()); // No position.
            $$.row_value_list= $3;
          }
        | '(' insert_columns ')' insert_values
          {
            $$.column_list= $2;
            $$.row_value_list= $4;
          }
        ;
```

> `insert_columns` 语义组用于解析大于等于 1 个、逗号分隔的 `INSERT` 语句中要插入的字段名，详见下文；
>
> `insert_values` 语义组用于解析 `INSERT` 语句或 `REPLACE` 语句中，使用 `VALUE` 关键字或 `VALUES` 关键字引导的，要插入的大于等于一行的值的列表，详见下文。

#### 语义组：`insert_columns`

`insert_columns` 语义组用于解析大于等于 1 个、逗号分隔的 `INSERT` 语句中要插入的字段名。

- 返回值类型：`PT_item_list` 类型（`item_list2`）
- Bison 语法如下：

```C++
insert_columns:
          insert_columns ',' insert_column
          {
            if ($$->push_back($3))
              MYSQL_YYABORT;
            $$= $1;
            $$->m_pos = @$;
          }
        | insert_column
          {
            $$= NEW_PTN PT_item_list(@$);
            if ($$ == nullptr || $$->push_back($1))
              MYSQL_YYABORT;
          }
        ;
```

#### 语义组：`insert_column`

`insert_column` 语义组用于解析 `INSERT` 语句中要插入的字段名。

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类
- Bison 语法如下：

```C++
insert_column:
          simple_ident_nospvar
        ;
```

> `simple_ident_nospvar` 语义组用于解析 `ident`、`ident.ident` 或 `ident.ident.ident`（`ident` 返回 `PTI_simple_ident_nospvar_ident` 类型），详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)

#### 语义组：`insert_values`

`insert_values` 语义组用于解析 `INSERT` 语句或 `REPLACE` 语句中，使用 `VALUE` 关键字或 `VALUES` 关键字引导的，要插入的大于等于一行的值的列表。

- 返回值类型：`PT_insert_values_list` 对象（`values_list`）
- Bison 语法如下：

```C++
insert_values:
          value_or_values values_list
          {
            $$= $2;
          }
        ;
```

> `value_or_values` 语义组用于解析 `VALUE` 关键字或 `VALUES` 关键字，详见下文；
>
> `values_list` 语义组用于解析 `INSERT` 语句或 `REPLACE` 语句中的要插入的大于等于一行的值，即任意数量、逗号分隔的行的值的列表，详见下文。

#### 语义组：`value_or_values`

`value_or_values` 语义组用于解析 `VALUE` 关键字或 `VALUES` 关键字。

- 返回值类型：没有返回值
- Bison 语法如下：

```C++
value_or_values:
          VALUE_SYM
        | VALUES
        ;
```

#### 语义组：`values_list`

`values_list` 语义组用于解析 `INSERT` 语句或 `REPLACE` 语句中的要插入的大于等于一行的值，即任意数量、逗号分隔的行的值的列表。

- 返回值类型：`PT_insert_values_list` 对象（`values_list`）
- Bison 语法如下：

```C++
values_list:
          values_list ','  row_value
          {
            if ($$->push_back(&$3->value))
              MYSQL_YYABORT;
            $$->m_pos = @$;
          }
        | row_value
          {
            $$= NEW_PTN PT_insert_values_list(@$, YYMEM_ROOT);
            if ($$ == nullptr || $$->push_back(&$1->value))
              MYSQL_YYABORT;
          }
        ;
```

#### 语义组：`row_value`

`row_value` 语义组用于解析 `INSERT` 语句或 `REPLACE` 语句中的要插入的一行中的值，即用小括号框柱的任意数量、逗号分隔的列的值的列表。

- 返回值类型：`PT_item_list` 类型（`item_list2`）
- Bison 语法如下：

```C++
row_value:
          '(' opt_values ')' { $$= $2; }
        ;
```

> `opt_values` 语义组用于解析可选的值列表，详见 [MySQL 源码｜58 - 语法解析(V2)：SELECT 表达式](https://zhuanlan.zhihu.com/p/716212004)。

#### 语义组：`opt_values_reference`

`opt_values_reference` 语义组用于解析 `INSERT` 语句中可选的 `AS` 子句。

- 返回值类型：`insert_update_values_reference` 结构体，其中包含 `LEX_CSTRING` 类型的 `table_alias` 成员和 `Create_col_name_list` 类型的 `column_list` 成员
- Bison 语法如下：

```C++
opt_values_reference:
          %empty
          {
            $$.table_alias = NULL_CSTR;
            $$.column_list = nullptr;
          }
        | AS ident opt_derived_column_list
          {
            $$.table_alias = to_lex_cstring($2);
            /* The column list object is short-lived, requiring duplication. */
            void *column_list_raw_mem= YYTHD->memdup(&($3), sizeof($3));
            if (!column_list_raw_mem)
              MYSQL_YYABORT; // OOM
            $$.column_list =
              static_cast<Create_col_name_list *>(column_list_raw_mem);
          }
        ;
```

> `ident` 语义组用于解析标识符或任意未保留关键字，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)；
>
> `opt_derived_column_list` 语义组用于解析被小括号框柱的、任意数量、逗号分隔的列表（标识符）的列表，详见 [MySQL 源码｜76 - 语法解析(V2)：表语句（table_reference）](https://zhuanlan.zhihu.com/p/720247259)。

#### 语义组：`opt_insert_update_list`

`opt_insert_update_list` 语义组用于解析 `INSERT` 语句中的 `ON DUPLCIATE KEY UPDATE` 子句。

- 返回值类型：`column_value_list_pair` 结构体（`column_value_list_pair`），包含 `PT_item_list` 类型的成员 `column_list` 和 `value_list`
- Bison 语法如下：

```C++
opt_insert_update_list:
          %empty
          {
            $$.value_list= nullptr;
            $$.column_list= nullptr;
          }
        | ON_SYM DUPLICATE_SYM KEY_SYM UPDATE_SYM update_list
          {
            $$= $5;
          }
        ;
```

#### 语义组：`insert_query_expression`

`insert_query_expression` 语义组用于解析 `INSERT` 语句中的字段列表和生成数据的 `SELECT` 查询语句。

- 返回值类型：`column_value_list_pair` 结构体，包含 `PT_item_list` 类型的成员 `column_list` 和 `PT_query_expression_body` 类型的成员 `insert_query_expression`
- Bison 语法如下：

```C++
insert_query_expression:
          query_expression_with_opt_locking_clauses
          {
            $$.column_list= NEW_PTN PT_item_list(POS()); // No column list.
            $$.insert_query_expression= $1;
          }
        | '(' ')' query_expression_with_opt_locking_clauses
          {
            $$.column_list= NEW_PTN PT_item_list(POS()); // No column list.
            $$.insert_query_expression= $3;
          }
        | '(' insert_columns ')' query_expression_with_opt_locking_clauses
          {
            $$.column_list= $2;
            $$.insert_query_expression= $4;
          }
        ;
```

> `query_expression_with_opt_locking_clauses` 语义组用于解析可选是否包含设置读取锁定子句、不包含 `INTO` 子句的 `SELECT` 查询语句，详见 [MySQL 源码｜58 - 语法解析(V2)：SELECT 表达式](https://zhuanlan.zhihu.com/p/716212004)。

### `REPLACE` 语句

#### 语义组：`replace_stmt`

`replace_stmt` 语义组用于解析 `REPLACE` 语句。

- 官方文档：[MySQL 参考手册 - 15.2.12 REPLACE Statement](https://dev.mysql.com/doc/refman/8.4/en/replace.html)
- 标准语法：

```
REPLACE [LOW_PRIORITY | DELAYED]
    [INTO] tbl_name
    [PARTITION (partition_name [, partition_name] ...)]
    [(col_name [, col_name] ...)]
    { {VALUES | VALUE} (value_list) [, (value_list)] ...
      |
      VALUES row_constructor_list
    }

REPLACE [LOW_PRIORITY | DELAYED]
    [INTO] tbl_name
    [PARTITION (partition_name [, partition_name] ...)]
    SET assignment_list

REPLACE [LOW_PRIORITY | DELAYED]
    [INTO] tbl_name
    [PARTITION (partition_name [, partition_name] ...)]
    [(col_name [, col_name] ...)]
    {SELECT ... | TABLE table_name}

value:
    {expr | DEFAULT}

value_list:
    value [, value] ...

row_constructor_list:
    ROW(value_list)[, ROW(value_list)][, ...]

assignment:
    col_name = value

assignment_list:
    assignment [, assignment] ...
```

- 返回值类型：`Parse_tree_root` 对象（`top_level_node`），用于存储最顶层节点，即语句层级节点
- Bison 语法如下：

```C++
replace_stmt:
          REPLACE_SYM                   /* #1 */
          replace_lock_option           /* #2 */
          opt_INTO                      /* #3 */
          table_ident                   /* #4 */
          opt_use_partition             /* #5 */
          insert_from_constructor       /* #6 */
          {
            $$= NEW_PTN PT_insert(@$, true, $1, $2, false, $4, $5,
                                  $6.column_list, $6.row_value_list,
                                  nullptr,
                                  NULL_CSTR, nullptr,
                                  nullptr, nullptr);
          }
        | REPLACE_SYM                   /* #1 */
          replace_lock_option           /* #2 */
          opt_INTO                      /* #3 */
          table_ident                   /* #4 */
          opt_use_partition             /* #5 */
          SET_SYM                       /* #6 */
          update_list                   /* #7 */
          {
            PT_insert_values_list *one_row= NEW_PTN PT_insert_values_list(@$, YYMEM_ROOT);
            if (one_row == nullptr || one_row->push_back(&$7.value_list->value))
              MYSQL_YYABORT; // OOM
            $$= NEW_PTN PT_insert(@$, true, $1, $2, false, $4, $5,
                                  $7.column_list, one_row,
                                  nullptr,
                                  NULL_CSTR, nullptr,
                                  nullptr, nullptr);
          }
        | REPLACE_SYM                   /* #1 */
          replace_lock_option           /* #2 */
          opt_INTO                      /* #3 */
          table_ident                   /* #4 */
          opt_use_partition             /* #5 */
          insert_query_expression       /* #6 */
          {
            $$= NEW_PTN PT_insert(@$, true, $1, $2, false, $4, $5,
                                  $6.column_list, nullptr,
                                  $6.insert_query_expression,
                                  NULL_CSTR, nullptr,
                                  nullptr, nullptr);
          }
        ;
```

> `replace_lock_option` 语义组
>
> `opt_INTO` 语义组用于解析可选的 `INTO` 关键字，详见上文；
>
> `table_ident` 语义组用于解析 `ident` 或 `ident.ident`，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)；
>
> `opt_use_partition` 语义组用于解析可选的 `PARTITION` 子句，详见 [MySQL 源码｜76 - 语法解析(V2)：表语句（table_reference）](https://zhuanlan.zhihu.com/p/720247259)；
>
> `insert_from_constructor` 语义组用于解析 `INSERT` 语句和 `REPLACE` 语句中的字段列表和值列表，详见上文；
>
> `update_list` 语义组用于解析任意数量、逗号分隔的赋值语句，详见 [MySQL 源码｜57 - 语法解析(V2)：UPDATE 表达式和 DELETE 表达式](https://zhuanlan.zhihu.com/p/716038847)；
>
> `insert_query_expression` 语义组用于解析 `INSERT` 语句中的字段列表和生成数据的 `SELECT` 查询语句，详见上文。

#### 语义组：`replace_lock_option`

`replace_lock_option` 语义组用于解析可选的 `LOW_PRIORITY` 关键字或 `DELAYED` 关键字。

```C++
replace_lock_option:
          opt_low_priority { $$= $1; }
        | DELAYED_SYM
        {
          $$= TL_WRITE_DEFAULT;

          push_warning_printf(YYTHD, Sql_condition::SL_WARNING,
                              ER_WARN_LEGACY_SYNTAX_CONVERTED,
                              ER_THD(YYTHD, ER_WARN_LEGACY_SYNTAX_CONVERTED),
                              "REPLACE DELAYED", "REPLACE");
        }
        ;
```

> `opt_low_priority` 语义组用于解析可选的 `LOW_PRIORITY` 关键字，详见 [MySQL 源码｜57 - 语法解析(V2)：UPDATE 表达式和 DELETE 表达式](https://zhuanlan.zhihu.com/p/716038847)。