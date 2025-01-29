目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

下面我们梳理用于解析 `EXPLAIN` 语句和 `DESC` 语句，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析 - 040 - EXPLAIN 语句](C:\blog\graph\MySQL源码剖析\语法解析 - 040 - EXPLAIN 语句.png)

#### 语义组：`describe_stmt`

`describe_stmt` 语义组用于解析 `DESCRIBE` 描述表语句（可以使用 `EXPLAIN`、`DESCRIBE` 或 `DESC` 中任意一个关键字引导）。

- 官方文档：[MySQL 参考手册 - 15.8.2 EXPLAIN Statement](https://dev.mysql.com/doc/refman/8.4/en/explain.html)
- 标准语法：

```C++
{EXPLAIN | DESCRIBE | DESC}
    tbl_name [col_name | wild]
```

- 返回值类型：`Parse_tree_root` 对象（`top_level_node`），用于存储最顶层节点，即语句层级节点
- Bison 语法如下：

```C++
describe_stmt:
          describe_command table_ident opt_describe_column
          {
            $$= NEW_PTN PT_show_fields(@$, Show_cmd_type::STANDARD, $2, $3);
          }
        ;
```

> `describe_command` 语义组用于解析 `DESCRIBE`、`EXPLAIN` 和 `DESC` 关键字，详见下文；
>
> `table_ident` 语义组用于解析 `ident` 或 `ident.ident`，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)；
>
> `opt_describe_column` 语义组用于解析需要描述的字段名或通配符，详见下文。

#### 语义组：`describe_command`

`describe_command` 语义组用于解析 `DESCRIBE`、`EXPLAIN` 和 `DESC` 关键字。

- 标准语法：`{EXPLAIN | DESCRIBE | DESC}`
- 返回值类型：没有返回值
- Bison 语法如下：

```C++
describe_command:
          DESC
        | DESCRIBE
        ;
```

**需要特别注意的是，终结符 `DESCRIBE` 同时匹配 `EXPLAIN` 关键字和 `DESCRIBE` 关键字，即这两个关键字被均指向了同一个终结符 `DESCRIBE`。进行这个指向逻辑的代码位于 [sql/lex.h](https://github.com/mysql/mysql-server/blob/trunk/sql/lex.h) 文件中。**

#### 语义组：`opt_describe_column`

`opt_describe_column` 语义组用于解析需要描述的字段名或通配符。

- 返回值类型：`MYSQL_LEX_STRING` 对象，其中包含字符串指针和字符串长度
- Bison 语法如下：

```C++
opt_describe_column:
          %empty { $$= LEX_STRING{ nullptr, 0 }; }
        | text_string
          {
            if ($1 != nullptr)
              $$= $1->lex_string();
          }
        | ident
        ;
```

#### 语义组：`explain_stmt`

`explain_stmt` 语义组用于解析查看执行计划的 `EXPLAIN` 语句（可以使用 `EXPLAIN`、`DESCRIBE` 或 `DESC` 中任意一个关键字引导）。

- 官方文档：[MySQL 参考手册 - 15.8.2 EXPLAIN Statement](https://dev.mysql.com/doc/refman/8.4/en/explain.html)
- 标准语法：

```
{EXPLAIN | DESCRIBE | DESC}
    [explain_type] [INTO variable]
    {[schema_spec] explainable_stmt | FOR CONNECTION connection_id}

{EXPLAIN | DESCRIBE | DESC} ANALYZE [FORMAT = TREE] [schema_spec] select_statement

explain_type: {
    FORMAT = format_name
}

format_name: {
    TRADITIONAL
  | JSON
  | TREE
}

explainable_stmt: {
    SELECT statement
  | TABLE statement
  | DELETE statement
  | INSERT statement
  | REPLACE statement
  | UPDATE statement
}

schema_spec:
FOR {SCHEMA | DATABASE} schema_name
```

- 返回值类型：`Parse_tree_root` 对象（`top_level_node`），用于存储最顶层节点，即语句层级节点
- Bison 语法如下：

```C++
explain_stmt:
          describe_command opt_explain_options explainable_stmt
          {
            $$= NEW_PTN PT_explain(@$, $2.explain_format_type, $2.is_analyze,
                  $2.is_explicit, $3.statement,
                  $2.explain_into_variable_name.length ?
                  std::optional<std::string_view>(
                    to_string_view($2.explain_into_variable_name)) :
                  std::optional<std::string_view>(std::nullopt),
                  $3.schema_name_for_explain);
          }
        ;
```

> `describe_command` 语义组用于解析 `DESCRIBE`、`EXPLAIN` 和 `DESC` 关键字，详见下文；
>
> `opt_explain_options` 语义组用于解析 `EXPLAIN` 语句的配置项，包括是否添加 `Explain_format_type` 关键字，是否指定输出格式以及是否写出到用户变量，详见下文；
>
> `explainable_stmt` 语义组用于解析支持 `EXPLAIN` 的语句或 `FOR CONNECTION` 子句，详见下文。

#### 语义组：`opt_explain_options`

`opt_explain_options` 语义组用于解析 `EXPLAIN` 语句的配置项，包括是否添加 `Explain_format_type` 关键字，是否指定输出格式以及是否写出到用户变量。

- 官方文档：[MySQL 参考手册 - 15.8.2 EXPLAIN Statement](https://dev.mysql.com/doc/refman/8.4/en/explain.html)
- 返回值类型：`explain_options_type` 结构体，包括 `Explain_format_type` 类型的成员 `explain_format_type` 用于指定输出格式，`bool` 类型的成员 `is_analyze` 用于指定是否添加了 `ANALYZE` 关键字，`bool` 类型的成员 `is_explicit` 以及 `LEX_STRING` 类型的成员 `explain_into_variable_name` 用于指定写出到用户变量名
- Bison 语法如下：

```C++
opt_explain_options:
          ANALYZE_SYM opt_explain_format
          {
            $$ = $2;
            $$.is_analyze = true;
            $$.explain_into_variable_name = NULL_STR;
          }
        | opt_explain_format opt_explain_into
          {
            $$ = $1;
            $$.is_analyze = false;

            if ($2.length) {
              if (!$$.is_explicit) {
                MYSQL_YYABORT_ERROR(
                  ER_EXPLAIN_INTO_IMPLICIT_FORMAT_NOT_SUPPORTED, MYF(0));
              }
              if ($$.explain_format_type != Explain_format_type::JSON) {
                if ($$.explain_format_type == Explain_format_type::TREE) {
                  MYSQL_YYABORT_ERROR(ER_EXPLAIN_INTO_FORMAT_NOT_SUPPORTED,
                                      MYF(0), "TREE");
                } else {
                  MYSQL_YYABORT_ERROR(ER_EXPLAIN_INTO_FORMAT_NOT_SUPPORTED,
                                      MYF(0), "TRADITIONAL");
                }
              }
            }
            $$.explain_into_variable_name = $2;
          }
        ;
```

> `opt_explain_format` 语义组用于解析可选的 `EXPLAIN` 语句的输出格式，即解析 `[FORMAT = format_name]`，详见下文；
>
> `opt_explain_into` 语义组用于解析可选的 `EXPALIN` 语句结果写入变量，即解析 `[INTO variable]`，详见下文。

#### 语义组：`opt_explain_format`

`opt_explain_format` 语义组用于解析可选的 `EXPLAIN` 语句的输出格式，即解析 `[FORMAT = format_name]`。

- 官方文档：[MySQL 参考手册 - 15.8.2 EXPLAIN Statement](https://dev.mysql.com/doc/refman/8.4/en/explain.html)
- 标准语法：`[FORMAT = format_name]`
- 返回值类型：`explain_options_type` 结构体
- Bison 语法如下：

```C++
opt_explain_format:
          %empty
          {
            $$.is_explicit = false;
            $$.explain_format_type = YYTHD->variables.explain_format;
          }
        | FORMAT_SYM EQ ident_or_text
          {
            $$.is_explicit = true;
            if (is_identifier($3, "JSON"))
              $$.explain_format_type = Explain_format_type::JSON;
            else if (is_identifier($3, "TRADITIONAL"))
              $$.explain_format_type = Explain_format_type::TRADITIONAL;
            else if (is_identifier($3, "TREE"))
              $$.explain_format_type = Explain_format_type::TREE;
            else {
              // This includes even TRADITIONAL_STRICT. Since this value is
              // only meant for mtr infrastructure temporarily, we don't want
              // the user to explicitly use this value in EXPLAIN statements.
              // This results in having one less place to deprecate from.
              my_error(ER_UNKNOWN_EXPLAIN_FORMAT, MYF(0), $3.str);
              MYSQL_YYABORT;
            }
          }
        ;
```

> `ident_or_text` 语义组用于解析标识符、任意未保留关键字、单引号 / 双引号字符串或用户自定义变量，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)。

#### 语义组：`opt_explain_into`

`opt_explain_into` 语义组用于解析可选的 `EXPALIN` 语句结果写入变量，即解析 `[INTO variable]`。

- 官方文档：[MySQL 参考手册 - 15.8.2 EXPLAIN Statement](https://dev.mysql.com/doc/refman/8.4/en/explain.html)
- 标准语法：`[INTO variable]`
- 返回值类型：`MYSQL_LEX_STRING` 对象，其中包含字符串指针和字符串长度
- Bison 语法如下：

```C++
opt_explain_into:
          %empty
          {
            $$ = NULL_STR;
          }
        | INTO '@' ident_or_text
          {
            $$ = $3;
          }
        ;
```

> `ident_or_text` 语义组用于解析标识符、任意未保留关键字、单引号 / 双引号字符串或用户自定义变量，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)。

#### 语义组：`explainable_stmt`

`explainable_stmt` 语义组用于解析支持 `EXPLAIN` 的语句或 `FOR CONNECTION` 子句。

- 官方文档：[MySQL 参考手册 - 15.8.2 EXPLAIN Statement](https://dev.mysql.com/doc/refman/8.4/en/explain.html)；[MySQL 参考手册 - 10.8.4 Obtaining Execution Plan Information for a Named Connection](https://dev.mysql.com/doc/refman/8.4/en/explain-for-connection.html)
- 返回值类型：`explainable_stmt` 结构体，包含 `Parse_tree_root` 类型的 `statement` 成员以及 `LEX_STRING` 类型的 `schema_name_for_explain` 成员
- 备选规则和 Bison 语法如下：

| 备选规则                                | 规则含义                               |
| --------------------------------------- | -------------------------------------- |
| `opt_explain_for_schema select_stmt`    | 解释 `SELECT` 语句的执行计划           |
| `opt_explain_for_schema insert_stmt`    | 解释 `INSERT` 语句的执行计划           |
| `opt_explain_for_schema replace_stmt`   | 解释 `REPLACE` 语句的执行计划          |
| `opt_explain_for_schema update_stmt`    | 解释 `UPDATE` 语句的执行计划           |
| `opt_explain_for_schema delete_stmt`    | 解释 `DELETE` 语句的执行计划           |
| `FOR_SYM CONNECTION_SYM real_ulong_num` | 解释正在指定连接中运行的命令的执行计划 |

```C++
explainable_stmt:
          opt_explain_for_schema select_stmt
          {
            $$.statement = $2;
            $$.schema_name_for_explain = $1;
          }
        | opt_explain_for_schema insert_stmt
          {
            $$.statement = $2;
            $$.schema_name_for_explain = $1;
          }
        | opt_explain_for_schema replace_stmt
          {
            $$.statement = $2;
            $$.schema_name_for_explain = $1;
          }
        | opt_explain_for_schema update_stmt
          {
            $$.statement = $2;
            $$.schema_name_for_explain = $1;
          }
        | opt_explain_for_schema delete_stmt
          {
            $$.statement = $2;
            $$.schema_name_for_explain = $1;
          }
        | FOR_SYM CONNECTION_SYM real_ulong_num
          {
            $$.statement = NEW_PTN PT_explain_for_connection(@$, static_cast<my_thread_id>($3));
            $$.schema_name_for_explain = NULL_CSTR;
          }
        ;
```

> `opt_explain_for_schema` 语义组用于解析可选的 `FOR {DATABASE | SCHEMA} schema_name`，详见下文；
>
> `select_stmt` 语义组用于解析可选添加设置读取锁定子句、可选添加 `INTO` 子句的 `SELECT` 语句，详见 [MySQL 源码｜58 - 语法解析(V2)：SELECT 表达式](https://zhuanlan.zhihu.com/p/716212004)；
>
> `insert_stmt` 语义组用于解析 `INSERT` 语句，详见 [MySQL 源码｜79 - 语法解析(V2)：INSERT 语句和 REPLACE 语句](https://zhuanlan.zhihu.com/p/720326790)；
>
> `replace_stmt` 语义组用于解析 `REPLACE` 语句，详见 [MySQL 源码｜79 - 语法解析(V2)：INSERT 语句和 REPLACE 语句](https://zhuanlan.zhihu.com/p/720326790)；
>
> `update_stmt` 语义组用于解析 `UPDATE` 语句，详见 [MySQL 源码｜57 - 语法解析(V2)：UPDATE 表达式和 DELETE 表达式](https://zhuanlan.zhihu.com/p/716038847)；
>
> `delete_stmt` 语义组用于解析 `DELETE` 语句，详见 [MySQL 源码｜57 - 语法解析(V2)：UPDATE 表达式和 DELETE 表达式](https://zhuanlan.zhihu.com/p/716038847)；
>
> `real_ulong_num` 语义组用于解析十进制整数和十六进制数（转换为十进制数），返回 unsigned long 类型；如果输入十进制小数或超出范围的十进制整数，则抛出异常，详见 [MySQL 源码｜67 - 语法解析(V2)：数值字面值](https://zhuanlan.zhihu.com/p/718508554)。

#### 语义组：`opt_explain_for_schema`

`opt_explain_for_schema` 语义组用于解析可选的 `FOR {DATABASE | SCHEMA} schema_name`。

- 返回值类型：`MYSQL_LEX_CSTRING` 结构体，包含字符串的 const 指针和字符串长度
- Bison 语法如下：

```C++
opt_explain_for_schema:
          %empty
          {
            $$ = NULL_CSTR;
          }
        | FOR_SYM DATABASE ident_or_text
          {
            $$ = to_lex_cstring($3);
          }
        ;
```

**需要特别注意的是，终结符 `DATABASE` 同时匹配 `SCHEMA` 关键字和 `DATABASE` 关键字，即这两个关键字被均指向了同一个终结符 `DATABASE`。进行这个指向逻辑的代码位于 [sql/lex.h](https://github.com/mysql/mysql-server/blob/trunk/sql/lex.h) 文件中。**