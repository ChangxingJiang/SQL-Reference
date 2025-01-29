目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

下面我们梳理用于解析 `LOAD` 语句的 `load_stmt` 语义组，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析 - 039 - LOAD 语句](C:\blog\graph\MySQL源码剖析\语法解析 - 039 - LOAD 语句.png)

#### 语义组：`load_stmt`

`load_stmt` 语义组用于解析 `LOAD` 语句。`LOAD` 语句用于高性能地从文本文件中读取行并写到到表中，根据是否指定了 `LOCAL` 修饰符，可以宣誓从服务器读取还是从客户端读取文件。

- 官方文档：[MySQL 参考手册 - 15.2.9 LOAD DATA Statement](https://dev.mysql.com/doc/refman/8.4/en/load-data.html)；[MySQL 参考手册 - 15.2.10 LOAD XML Statement](https://dev.mysql.com/doc/refman/8.4/en/load-xml.html)
- 标准语法：

```
LOAD DATA
    [LOW_PRIORITY | CONCURRENT] [LOCAL]
    INFILE 'file_name'
    [REPLACE | IGNORE]
    INTO TABLE tbl_name
    [PARTITION (partition_name [, partition_name] ...)]
    [CHARACTER SET charset_name]
    [{FIELDS | COLUMNS}
        [TERMINATED BY 'string']
        [[OPTIONALLY] ENCLOSED BY 'char']
        [ESCAPED BY 'char']
    ]
    [LINES
        [STARTING BY 'string']
        [TERMINATED BY 'string']
    ]
    [IGNORE number {LINES | ROWS}]
    [(col_name_or_user_var
        [, col_name_or_user_var] ...)]
    [SET col_name={expr | DEFAULT}
        [, col_name={expr | DEFAULT}] ...]
```

- 返回值类型：`Parse_tree_root` 对象（`top_level_node`），用于存储最顶层节点，即语句层级节点
- Bison 语法如下：

```C++
/* import, export of files */

load_stmt:
          LOAD                          /*  1 */
          data_or_xml                   /*  2 */
          load_data_lock                /*  3 */
          opt_from_keyword              /*  4 */
          opt_local                     /*  5 */
          load_source_type              /*  6 */
          TEXT_STRING_filesystem        /*  7 */
          opt_source_count              /*  8 */
          opt_source_order              /*  9 */
          opt_duplicate                 /* 10 */
          INTO                          /* 11 */
          TABLE_SYM                     /* 12 */
          table_ident                   /* 13 */
          opt_use_partition             /* 14 */
          opt_load_data_charset         /* 15 */
          opt_xml_rows_identified_by    /* 16 */
          opt_field_term                /* 17 */
          opt_line_term                 /* 18 */
          opt_ignore_lines              /* 19 */
          opt_field_or_var_spec         /* 20 */
          opt_load_data_set_spec        /* 21 */
          opt_load_parallel             /* 22 */
          opt_load_memory               /* 23 */
          opt_load_algorithm            /* 24 */
          {
            $$= NEW_PTN PT_load_table(@$, $2,  // data_or_xml
                                      $3,  // load_data_lock
                                      $5,  // opt_local
                                      $6,  // source type
                                      $7,  // TEXT_STRING_filesystem
                                      $8,  // opt_source_count
                                      $9,  // opt_source_order
                                      $10, // opt_duplicate
                                      $13, // table_ident
                                      $14, // opt_use_partition
                                      $15, // opt_load_data_charset
                                      $16, // opt_xml_rows_identified_by
                                      $17, // opt_field_term
                                      $18, // opt_line_term
                                      $19, // opt_ignore_lines
                                      $20, // opt_field_or_var_spec
                                      $21.set_var_list,// opt_load_data_set_spec
                                      $21.set_expr_list,
                                      $21.set_expr_str_list,
                                      $22,  // opt_load_parallel
                                      $23,  // opt_load_memory
                                      $24); // opt_load_algorithm
          }
        ;
```

> `data_or_xml` 语义组用于解析 `DATA` 关键字或 `XML` 关键字，详见下文；
>
> `load_data_lock` 语义组用于解析可选的 `CONCURRENT` 关键字或 `LOW_PRIORITY` 关键字，详见下文；
>
> `opt_from_keyword` 语义组用于解析可选的 `FROM` 关键字，详见下文；
>
> `opt_local` 语义组用于解析可选的 `LOCAL` 关键字，用于控制从服务器读取文件还是从客户端读取文件，详见下文；
>
> `load_source_type` 语义组用于选择输入文件所在位置的类型，详见下文；
>
> `TEXT_STRING_filesystem` 语义组用于解析作为文件系统路径的单引号 / 双引号字符串，详见 [MySQL 源码｜65 - 语法解析(V2)：字符串字面值](https://zhuanlan.zhihu.com/p/717934287)；
>
> `opt_source_count` 语义组用于解析读取文件的数量，详见下文；
>
> `opt_source_order` 语义组用于解析可选的 `IN PRIMARY KEY ORDER`，详见下文；
>
> `opt_duplicate` 语义组用于解析对重复值的处理方法，具体解析可选的 `REPLACE` 关键字或 `IGNORE` 关键字，详见下文；
>
> `table_ident` 语义组用于解析 `ident` 或 `ident.ident`，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)；
>
> `opt_use_partition` 语义组用于解析可选的 `PARTITION` 子句，详见 [MySQL 源码｜76 - 语法解析(V2)：表语句（table_reference）](https://zhuanlan.zhihu.com/p/720247259)；
>
> `opt_load_data_charset` 语义组用于解析可选的指定字符集子句，详见 [MySQL 源码｜53 - 语法解析(V2)：INTO 子句](https://zhuanlan.zhihu.com/p/715903798)；
>
> `opt_xml_rows_identified_by` 语义组用于解析 XML 文件的行分隔符，具体解析可选的 `ROWS IDENTIFIED BY text_string`，详见下文；
>
> `opt_field_term` 语义组用于解析写出到文件的列配置信息，包括 `TERMINATED BY`、`OPTIONALLY ENCLOSED BY`、`ENCLOSED BY`、`ESCAPED BY`，详见 [MySQL 源码｜53 - 语法解析(V2)：INTO 子句](https://zhuanlan.zhihu.com/p/715903798)；
>
> `opt_line_term` 语义组用于解析写出到文件的行配置信息，包括 `TERMINATED BY`、`STARTING BY`，详见 [MySQL 源码｜53 - 语法解析(V2)：INTO 子句](https://zhuanlan.zhihu.com/p/715903798)；
>
> `opt_ignore_lines` 语义组用于解析跳过文件开头的行数，具体解析可选的 `IGNORE NUM [LINES | ROWS]`，详见下文；
>
> `opt_field_or_var_spec` 语义组用于解析可选的列名或用户变量的列表，通过使用用户变量和 `SET` 子句，可以在将结果分配给列之前，对它们的值进行预处理转换，详见下文；
>
> `opt_load_data_set_spec` 语义组用于解析 `LOAD` 语句中可选的 `SET` 子句，通过 `SET` 子句，可以在将结果分配给列之前，对它们的值进行预处理转换，详见下文；
>
> `opt_load_parallel` 语义组用于解析 `LOAD` 语句的并发数设置，即解析可选的 `PARALLEL = NUM`，详见下文；
>
> `opt_load_memory` 语义组用于解析 `LOAD` 语句的读取内存，即解析可选的 `MEMORY = size_number`，详见下文；
>
> `opt_load_algorithm` 语义组用于解析 `LOAD` 语句使用的读取算法，即解析可选的 `ALGORITHM = BULK`，详见下文。

#### 语义组：`data_or_xml`

`data_or_xml` 语义组用于解析 `DATA` 关键字或 `XML` 关键字。

- 返回值类型：枚举类型 `filetype`，包括 `FILETYPE_CSV` 和 `FILETYPE_XML` 两个成员。
- Bison 语法如下：

```C++
data_or_xml:
          DATA_SYM{ $$= FILETYPE_CSV; }
        | XML_SYM { $$= FILETYPE_XML; }
        ;
```

#### 语义组：`load_data_lock`

`load_data_lock` 语义组用于解析可选的 `CONCURRENT` 关键字或 `LOW_PRIORITY` 关键字。

- 返回值类型：`thr_lock_type` 枚举值（`lock_type`）
- Bison 语法如下：

```C++
load_data_lock:
          %empty      { $$= TL_WRITE_DEFAULT; }
        | CONCURRENT  { $$= TL_WRITE_CONCURRENT_INSERT; }
        | LOW_PRIORITY { $$= TL_WRITE_LOW_PRIORITY; }
        ;
```

#### 语义组：`opt_from_keyword`

`opt_from_keyword` 语义组用于解析可选的 `FROM` 关键字。

- 返回值类型：没有返回值
- Bison 语法如下：

```C++
opt_from_keyword:
          %empty      {}
        | FROM        {}
        ;
```

#### 语义组：`opt_local`

`opt_local` 语义组用于解析可选的 `LOCAL` 关键字，用于控制从服务器读取文件还是从客户端读取文件。

- 返回值类型：`bool` 类型（`is_not_empty`）
- Bison 语法如下：

```C++
opt_local:
          %empty      { $$= false; }
        | LOCAL_SYM   { $$= true; }
        ;
```

#### 语义组：`load_source_type`

`load_source_type` 语义组用于解析输入文件所在位置的类型。

- 返回值类型：`enum_source_type` 枚举类型，包含 `LOAD_SOURCE_FILE`、`LOAD_SOURCE_URL` 和 `LOAD_SOURCE_S3` 这 3 个枚举值
- Bison 语法如下：

```C++
load_source_type:
          INFILE_SYM { $$ = LOAD_SOURCE_FILE; }
        | URL_SYM    { $$ = LOAD_SOURCE_URL; }
        | S3_SYM     { $$ = LOAD_SOURCE_S3; }
        ;
```

#### 语义组：`opt_source_count`

`opt_source_count` 语义组用于解析读取文件的数量。

- 返回值类型：`unsigned long` 类型
- Bison 语法如下：

```C++
opt_source_count:
          %empty { $$= 0; }
        | COUNT_SYM NUM { $$= atol($2.str); }
        | IDENT_sys NUM
          {
            // COUNT can be key word or identifier based on SQL mode
            if (my_strcasecmp(system_charset_info, $1.str, "count") != 0) {
              YYTHD->syntax_error_at(@1, "COUNT expected");
              YYABORT;
            }
            $$= atol($2.str);
          }
        ;
```

> `IDENT_sys` 语义组用于解析没有引号的标识符名称（包含或不包含多字节字符），详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)。

#### 语义组：`opt_source_order`

`opt_source_order` 语义组用于解析可选的 `IN PRIMARY KEY ORDER`。

- 返回值类型：`bool` 类型（`is_not_empty`）
- Bison 语法如下：

```C++
opt_source_order:
          %empty { $$= false; }
        | IN_SYM PRIMARY_SYM KEY_SYM ORDER_SYM { $$= true; }
        ;
```

#### 语义组：`opt_duplicate`

`opt_duplicate` 语义组用于解析对重复值的处理方法，具体解析可选的 `REPLACE` 关键字或 `IGNORE` 关键字。

- 返回值类型：`On_duplicate` 枚举类型，包括 `ERROR`、`REPLACE_DUP` 和 `IGNORE_DUP` 这 3 个成员
- Bison 语法如下：

```C++
opt_duplicate:
          %empty { $$= On_duplicate::ERROR; }
        | duplicate
        ;
```

#### 语义组：`duplicate`

`duplicate` 语义组用于解析对重复值的处理方法，具体解析 `REPLACE` 关键字或 `IGNORE` 关键字。

- 返回值类型：`On_duplicate` 枚举类型，包括 `ERROR`、`REPLACE_DUP` 和 `IGNORE_DUP` 这 3 个成员
- Bison 语法如下：

```C++
duplicate:
          REPLACE_SYM { $$= On_duplicate::REPLACE_DUP; }
        | IGNORE_SYM  { $$= On_duplicate::IGNORE_DUP; }
        ;
```

#### 语义组：`opt_xml_rows_identified_by`

`opt_xml_rows_identified_by` 语义组用于解析 XML 文件的行分隔符，具体解析可选的 `ROWS IDENTIFIED BY text_string`。

- 返回值类型：`String` 对象，其中包含字符串指针、字符串长度、字符串字符集等属性
- Bison 语法如下：

```C++
opt_xml_rows_identified_by:
          %empty { $$= nullptr; }
        | ROWS_SYM IDENTIFIED_SYM BY text_string { $$= $4; }
        ;
```

> `text_string` 语义组用于解析单引号 / 双引号字符串、十六进制数或二进制数，详见 [MySQL 源码｜65 - 语法解析(V2)：字符串字面值](https://zhuanlan.zhihu.com/p/717934287)。

#### 语义组：`opt_ignore_lines`

`opt_ignore_lines` 语义组用于解析跳过文件开头的行数，具体解析可选的 `IGNORE NUM [LINES | ROWS]`。

- 返回值类型：`unsigned long` 类型
- Bison 语法如下：

```sql
opt_ignore_lines:
          %empty { $$= 0; }
        | IGNORE_SYM NUM lines_or_rows  { $$= atol($2.str); }
        ;
```

#### 语义组：`lines_or_rows`

`lines_or_rows` 语义组用于解析 `LINES` 关键字或 `ROWS` 关键字。

- 返回值类型：没有返回值
- Bison 语法如下：

```C++
lines_or_rows:
          LINES
        | ROWS_SYM
        ;
```

#### 语义组：`opt_field_or_var_spec`

`opt_field_or_var_spec` 语义组用于解析可选的列名或用户变量的列表。通过使用用户变量和 `SET` 子句，可以在将结果分配给列之前，对它们的值进行预处理转换。

- 返回值类型：`PT_item_list` 类型（`item_list2`）
- Bison 语法如下：

```C++
opt_field_or_var_spec:
          %empty                 { $$= nullptr; }
        | '(' fields_or_vars ')' { $$= $2; }
        | '(' ')'                { $$= nullptr; }
        ;
```

#### 语义组：`fields_or_vars`

`fields_or_vars` 语义组用于解析大于等于 1 个、逗号分隔的列名或用户变量。

- 返回值类型：`PT_item_list` 类型（`item_list2`）
- Bison 语法如下：

```C++
fields_or_vars:
          fields_or_vars ',' field_or_var
          {
            $$= $1;
            if ($$->push_back($3))
              MYSQL_YYABORT; // OOM
            $$->m_pos = @$;
          }
        | field_or_var
          {
            $$= NEW_PTN PT_item_list(@$);
            if ($$ == nullptr || $$->push_back($1))
              MYSQL_YYABORT; // OOM
          }
        ;
```

#### 语义组：`field_or_var`

`field_or_var` 语义组用于解析一个列名或用户变量。

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类
- Bison 语法如下：

```C++
field_or_var:
          simple_ident_nospvar
        | '@' ident_or_text
          {
            $$= NEW_PTN Item_user_var_as_out_param(@$, $2);
          }
        ;
```

> `simple_ident_nospvar` 语义组用于解析 `ident`、`ident.ident` 或 `ident.ident.ident`，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)；
>
> `ident_or_text` 语义组用于解析标识符、任意未保留关键字、单引号 / 双引号字符串或用户自定义变量，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)。

#### 语义组：`opt_load_data_set_spec`

`opt_load_data_set_spec` 语义组用于解析 `LOAD` 语句中可选的 `SET` 子句，通过 `SET` 子句，可以在将结果分配给列之前，对它们的值进行预处理转换。

- 返回值类型：`load_set_list` 结构体，其中包含 `PT_item_list` 类型的 `set_var_list` 成员和 `set_expr_list` 成员，以及 `List<String>` 类型的 `set_expr_str_list` 成员
- Bison 语法如下：

```C++
opt_load_data_set_spec:
          %empty { $$= {nullptr, nullptr, nullptr}; }
        | SET_SYM load_data_set_list { $$= $2; }
        ;
```

#### 语义组：`load_data_set_list`

`load_data_set_list` 语义组用于解析 `LOAD` 语句的 `SET` 子句中的大于等于 1 个、逗号分隔的赋值语句。

- 返回值类型：`load_set_list` 结构体
- Bison 语法如下：

```C++
load_data_set_list:
          load_data_set_list ',' load_data_set_elem
          {
            $$= $1;
            if ($$.set_var_list->push_back($3.set_var) ||
                $$.set_expr_list->push_back($3.set_expr) ||
                $$.set_expr_str_list->push_back($3.set_expr_str))
              MYSQL_YYABORT; // OOM
          }
        | load_data_set_elem
          {
            $$.set_var_list= NEW_PTN PT_item_list(@$);
            if ($$.set_var_list == nullptr ||
                $$.set_var_list->push_back($1.set_var))
              MYSQL_YYABORT; // OOM

            $$.set_expr_list= NEW_PTN PT_item_list(@$);
            if ($$.set_expr_list == nullptr ||
                $$.set_expr_list->push_back($1.set_expr))
              MYSQL_YYABORT; // OOM

            $$.set_expr_str_list= NEW_PTN List<String>;
            if ($$.set_expr_str_list == nullptr ||
                $$.set_expr_str_list->push_back($1.set_expr_str))
              MYSQL_YYABORT; // OOM
          }
        ;
```

#### 语义组：`load_data_set_elem`

`load_data_set_elem` 语义组用于解析 `LOAD` 语句的 `SET` 子句中的一个赋值语句。

- 返回值类型：`load_set_element` 结构体，包含 `Item` 类型的 `set_var` 成员和 `set_expr` 成员，以及 `String` 类型的 `set_expr_str` 成员
- Bison 语法如下：

```C++
load_data_set_elem:
          simple_ident_nospvar equal expr_or_default
          {
            size_t length= @3.cpp.end - @2.cpp.start;

            if ($3 == nullptr)
              MYSQL_YYABORT; // OOM
            $3->item_name.copy(@2.cpp.start, length, YYTHD->charset());

            $$.set_var= $1;
            $$.set_expr= $3;
            $$.set_expr_str= NEW_PTN String(@2.cpp.start,
                                            length,
                                            YYTHD->charset());
            if ($$.set_expr_str == nullptr)
              MYSQL_YYABORT; // OOM
          }
        ;
```

> `simple_ident_nospvar` 语义组用于解析 `ident`、`ident.ident` 或 `ident.ident.ident`，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)；
>
> `equal` 语义组用于解析 `=`（`EQUAL`）或 `SET_VAR` 关键字（`SET_VAR`），详见 [MySQL 源码｜57 - 语法解析(V2)：UPDATE 表达式和 DELETE 表达式](https://zhuanlan.zhihu.com/p/716038847)；
>
> `expr_or_default` 语义组用于解析一般表达式或 `DEFAULT` 关键字，详见 [MySQL 源码｜58 - 语法解析(V2)：SELECT 表达式](https://zhuanlan.zhihu.com/p/716212004)。

#### 语义组：`opt_load_parallel`

`opt_load_parallel` 语义组用于解析 `LOAD` 语句的并发数设置，即解析可选的 `PARALLEL = NUM`。

- 返回值类型：`unsigned long` 类型
- Bison 语法如下：

```C++
opt_load_parallel:
          %empty              { $$ = 0; }
        | PARALLEL_SYM EQ NUM { $$= atol($3.str); }
        ;
```

#### 语义组：`opt_load_memory`

`opt_load_memory` 语义组用于解析 `LOAD` 语句的读取内存，即解析可选的 `MEMORY = size_number`。

- 返回值类型：`unsigned long long int` 类型（`ulonglong_number`）
- Bison 语法如下：

```C++
opt_load_memory:
          %empty                    { $$ = 0; }
        | MEMORY_SYM EQ size_number { $$ = $3; }
        ;
```

#### 语义组：`opt_load_algorithm`

`opt_load_algorithm` 语义组用于解析 `LOAD` 语句使用的读取算法，即解析可选的 `ALGORITHM = BULK`。

- 返回值类型：`bool` 类型（`is_not_empty`）
- Bison 语法如下：

```C++
opt_load_algorithm:
          %empty                    { $$ = false; }
        | ALGORITHM_SYM EQ BULK_SYM { $$ = true; }
        ;
```



