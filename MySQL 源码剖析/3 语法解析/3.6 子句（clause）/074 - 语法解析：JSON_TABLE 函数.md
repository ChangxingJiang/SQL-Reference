目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

下面梳理用于解析 `JSON_TABLE` 函数（使用 Json 数据构造表）的 `table_function` 语义组，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析 - 025 - JSON_TABLE 函数](C:\blog\graph\MySQL源码剖析\语法解析 - 025 - JSON_TABLE 函数.png)

#### 语义组：`table_function`

`table_function` 语义组用于解析 `JSON_TABLE` 函数，`JSON_TABLE` 函数可以将 JSON 数据转化为结构化数据。

- 官方文档：[MySQL 参考手册 - 14.17.6 JSON Table Functions](https://dev.mysql.com/doc/refman/8.0/en/json-table-functions.html)
- 标准语法：

```
JSON_TABLE(
    expr,
    path COLUMNS (column_list)
)   [AS] alias

column_list:
    column[, column][, ...]

column:
    name FOR ORDINALITY
    |  name type PATH string path [on_empty] [on_error]
    |  name type EXISTS PATH string path
    |  NESTED [PATH] path COLUMNS (column_list)

on_empty:
    {NULL | DEFAULT json_string | ERROR} ON EMPTY

on_error:
    {NULL | DEFAULT json_string | ERROR} ON ERROR
```

- 返回值类型：`PT_table_reference` 对象（`table_reference`）
- 使用场景：表语句（`table_factor`）
- Bison 语法如下：

```C++
table_function:
          JSON_TABLE_SYM '(' expr ',' text_literal columns_clause ')'
          opt_table_alias
          {
            // Alias isn't optional, follow derived's behavior
            if ($8 == NULL_CSTR)
            {
              my_message(ER_TF_MUST_HAVE_ALIAS,
                         ER_THD(YYTHD, ER_TF_MUST_HAVE_ALIAS), MYF(0));
              MYSQL_YYABORT;
            }

            $$= NEW_PTN PT_table_factor_function(@$, $3, $5, $6, to_lex_string($8));
          }
        ;
```

> `expr` 语义组用于解析最高级的一般表达式，详见 [MySQL 源码｜72 - 语法解析(V2)：一般表达式（expr）](https://zhuanlan.zhihu.com/p/719447959)；
>
> `text_literal` 语义组用于解析任意数量、空格分隔的单引号 / 双引号字符串、Unicode 字符串、指定字符集的字符串，详见 [MySQL 源码｜65 - 语法解析(V2)：字符串字面值](https://zhuanlan.zhihu.com/p/717934287)；
>
> `columns_clause` 语义组用于解析 `COLUMNS` 关键字引导的字段列表，详见下文；
>
> `opt_table_alias` 语义组用于解析 `AS` 关键字（可省略）引导的表别名，详见下文。

#### 语义组：`columns_clause`

`columns_clause` 语义组用于解析 `COLUMNS` 关键字引导的 JSON 表字段列表。

- 官方文档：[MySQL 参考手册 - 14.17.6 JSON Table Functions](https://dev.mysql.com/doc/refman/8.0/en/json-table-functions.html)
- 标准语法：`COLUMNS (column_list)`
- 返回值类型：`Mem_root_array<PT_json_table_column *>`（`jtc_list`）
- Bison 语法如下：

```C++
columns_clause:
          COLUMNS '(' columns_list ')'
          {
            $$= $3;
          }
        ;
```

#### 语义组：`columns_list`

`columns_list` 语义组用于解析任意数量、逗号分隔的 JSON 表字段列表。

- 官方文档：[MySQL 参考手册 - 14.17.6 JSON Table Functions](https://dev.mysql.com/doc/refman/8.0/en/json-table-functions.html)
- 标准语法：`column[, column][, ...]`
- 返回值类型：`Mem_root_array<PT_json_table_column *>`（`jtc_list`）
- Bison 语法如下：

```C++
columns_list:
          jt_column
          {
            $$= NEW_PTN Mem_root_array<PT_json_table_column *>(YYMEM_ROOT);
            if ($$ == nullptr || $$->push_back($1))
              MYSQL_YYABORT; // OOM
          }
        | columns_list ',' jt_column
          {
            $$= $1;
            if ($$->push_back($3))
              MYSQL_YYABORT; // OOM
          }
        ;
```

#### 语义组：`jt_column`

`jt_column` 语义组用于解析 JSON 表字段。

- 官方文档：[MySQL 参考手册 - 14.17.6 JSON Table Functions](https://dev.mysql.com/doc/refman/8.0/en/json-table-functions.html)
- 标准语法：

```
name FOR ORDINALITY
|  name type PATH string path [on_empty] [on_error]
|  name type EXISTS PATH string path
|  NESTED [PATH] path COLUMNS (column_list)

on_empty:
    {NULL | DEFAULT json_string | ERROR} ON EMPTY

on_error:
    {NULL | DEFAULT json_string | ERROR} ON ERROR
```

- 返回值类型：`PT_json_table_column` 对象（`jt_column`）
- Bison 语法如下：

```C++
jt_column:
          ident FOR_SYM ORDINALITY_SYM
          {
            $$= NEW_PTN PT_json_table_column_for_ordinality(@$, $1);
          }
        | ident type opt_collate jt_column_type PATH_SYM text_literal
          opt_on_empty_or_error_json_table
          {
            auto column = make_unique_destroy_only<Json_table_column>(
                YYMEM_ROOT, $4, $6, $7.error.type, $7.error.default_string,
                $7.empty.type, $7.empty.default_string);
            if (column == nullptr) MYSQL_YYABORT;  // OOM
            $$ = NEW_PTN PT_json_table_column_with_path(@$, std::move(column), $1,
                                                        $2, $3);
          }
        | NESTED_SYM PATH_SYM text_literal columns_clause
          {
            $$= NEW_PTN PT_json_table_column_with_nested_path(@$, $3, $4);
          }
        ;
```

> `ident` 语义组用于解析标识符或任意未保留关键字，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)；
>
> `type` 语义组用于解析 MySQL 中的数据类型，详见 [MySQL 源码｜73 - 语法解析(V2)：数据类型（type）](https://zhuanlan.zhihu.com/p/719867311)；
>
> `opt_collate` 语义组用于解析可选的 `COLLATE` 关键字引导的排序规则，详见下文；
>
> `jt_column_type` 语义组用于解析 `JSON_TABLE` 函数中可选的 `EXISTS` 关键字，详见下文；
>
> `text_literal` 语义组用于解析任意数量、空格分隔的单引号 / 双引号字符串、Unicode 字符串、指定字符集的字符串，详见 [MySQL 源码｜65 - 语法解析(V2)：字符串字面值](https://zhuanlan.zhihu.com/p/717934287)；
>
> `opt_on_empty_or_error_json_table` 语义组用于依次解析可选的 `ON EMPTY` 子句和可选的 `ON ERROR` 子句，详见下文。

#### 语义组：`opt_collate`

`opt_collate` 语义组用于解析可选的 `COLLATE` 关键字引导的排序规则。

- 返回值类型：`CHARSET_INFO` 结构体（`lexer.charset`）
- Bison 语法如下：

```C++
opt_collate:
          %empty { $$ = nullptr; }
        | COLLATE_SYM collation_name { $$ = $2; }
        ;
```

#### 语义组：`collation_name`

`collation_name` 语义组用于解析排序规则名称。

- 返回值类型：`CHARSET_INFO` 结构体（`lexer.charset`）
- Bison 语法如下：

```C++
collation_name:
          ident_or_text
          {
            if (!($$= mysqld_collation_get_by_name($1.str)))
              MYSQL_YYABORT;
            YYLIP->warn_on_deprecated_collation($$);
          }
        | BINARY_SYM { $$= &my_charset_bin; }
        ;
```

#### 语义组：`jt_column_type`

`jt_column_type` 语义组用于解析 `JSON_TABLE` 函数中可选的 `EXISTS` 关键字。

- 返回值类型：`enum_jt_column` 枚举值（`jt_column_type`），其中包含 `JTC_ORDINALITY`、`JTC_PATH`、`JTC_EXISTS` 和 `JTC_NESTED_PATH` 这 4 个枚举值。
- Bison 语法如下：

```C++
jt_column_type:
          %empty
          {
            $$= enum_jt_column::JTC_PATH;
          }
        | EXISTS
          {
            $$= enum_jt_column::JTC_EXISTS;
          }
        ;
```

#### 语义组：`opt_on_empty_or_error_json_table`

`opt_on_empty_or_error_json_table` 语义组用于依次解析可选的 `ON EMPTY` 子句和可选的 `ON ERROR` 子句（当 `ON_ERROR` 在 `ON EMPTY` 之前时会抛出警告）。

- 返回值类型：`json_on_error_or_empty` 结构体

```C++
  struct {
    Json_on_response error;
    Json_on_response empty;
  } json_on_error_or_empty;
```

- Bison 语法如下：

```C++
// JSON_TABLE extends the syntax by allowing ON ERROR to come before ON EMPTY.
opt_on_empty_or_error_json_table:
          opt_on_empty_or_error { $$ = $1; }
        | on_error on_empty
          {
            push_warning(
              YYTHD, Sql_condition::SL_WARNING, ER_WARN_DEPRECATED_SYNTAX,
              ER_THD(YYTHD, ER_WARN_DEPRECATED_JSON_TABLE_ON_ERROR_ON_EMPTY));
            $$.error = $1;
            $$.empty = $2;
          }
        ;
```

> `opt_on_empty_or_error` 语义组用于解析标准语法 `[on_empty] [on_error]`，详见 [MySQL 源码｜43 - 语法解析(V2)：关键字函数](https://zhuanlan.zhihu.com/p/714784157)。

#### 语义组：`opt_table_alias`

`opt_table_alias` 语义组用于解析可选的、`AS` 关键字引导的别名子句。

- 返回值类型：`MYSQL_LEX_STRING` 结构体（`lex_cstr`）
- Bison 语法如下：

```C++
opt_table_alias:
          %empty { $$ = NULL_CSTR; }
        | opt_as ident { $$ = to_lex_cstring($2); }
        ;
```

#### 语义组：`opt_as`

`opt_as` 语义组用于解析可选的 `AS` 关键字。

- 返回值类型：没有返回值。
- Bison 语法如下：

```C++
opt_as:
          %empty
        | AS
        ;
```

