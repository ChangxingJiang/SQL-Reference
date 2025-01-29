目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

前置文档：

- [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)
- [MySQL 源码｜43 - 语法解析(V2)：关键字函数](https://zhuanlan.zhihu.com/p/714784157)
- [MySQL 源码｜44 - 语法解析(V2)：非关键字函数](https://zhuanlan.zhihu.com/p/715092510)
- [MySQL 源码｜45 - 语法解析(V2)：通用函数](https://zhuanlan.zhihu.com/p/715159997)
- [MySQL 源码｜46 - 语法解析(V2)：为避免语法冲突专门处理的函数](https://zhuanlan.zhihu.com/p/715204070)
- [MySQL 源码｜48 - 语法解析(V2)：通用字面值](https://zhuanlan.zhihu.com/p/715612312)
- [MySQL 源码｜66 - 语法解析(V2)：预编译表达式的参数值](https://zhuanlan.zhihu.com/p/718323872)
- [MySQL 源码｜38 - 语法解析(V2)：窗口函数](https://zhuanlan.zhihu.com/p/714780506)
- [MySQL 源码｜47 - 语法解析(V2)：子查询](https://zhuanlan.zhihu.com/p/715426420)
- [MySQL 源码｜37 - 语法解析(V2)：聚集函数](https://zhuanlan.zhihu.com/p/714780278)

---

在此之前，我们已经梳理了字面值、标识符以及基础语法元素，下面我们来梳理解析基础表达式的 `simple_expr` 语义组，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析-016-简单表达式（simple_expr）](C:\blog\graph\MySQL源码剖析\语法解析-016-简单表达式（simple_expr）.png)

#### 语义组：`simple_expr`

- 官方文档：[MySQL 参考手册 - 11.5 Expressions](https://dev.mysql.com/doc/refman/8.4/en/expressions.html)
- 标准语法：

```
simple_expr:
    literal
  | identifier
  | function_call
  | simple_expr COLLATE collation_name
  | param_marker
  | variable
  | simple_expr || simple_expr
  | + simple_expr
  | - simple_expr
  | ~ simple_expr
  | ! simple_expr
  | BINARY simple_expr
  | (expr [, expr] ...)
  | ROW (expr, expr [, expr] ...)
  | (subquery)
  | EXISTS (subquery)
  | {identifier expr}
  | match_expr
  | case_expr
  | interval_expr
```

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类。
- 使用场景：上一级表达式（`predicate` 语义组）
- 备选规则和 Bison 语法：

| 备选规则                                                     | 规则含义                                                     |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| `simple_ident`                                               | 解析 `ident`、`ident.ident` 或 `ident.ident.ident`，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314) |
| `function_call_keyword`                                      | 解析使用 SQL 2003 规范中关键字作为函数名的函数，详见 [MySQL 源码｜43 - 语法解析(V2)：关键字函数](https://zhuanlan.zhihu.com/p/714784157) |
| `function_call_nonkeyword`                                   | 解析非关键字函数，详见 [MySQL 源码｜44 - 语法解析(V2)：非关键字函数](https://zhuanlan.zhihu.com/p/715092510) |
| `function_call_generic`                                      | 解析除关键字函数、非关键字函数、以及需为避免语法冲突专门处理的函数以外的其他通用函数，详见 [MySQL 源码｜45 - 语法解析(V2)：通用函数](https://zhuanlan.zhihu.com/p/715159997) |
| `function_call_conflict`                                     | 解析避免语法冲突专门处理的函数，详见 [MySQL 源码｜46 - 语法解析(V2)：为避免语法冲突专门处理的函数](https://zhuanlan.zhihu.com/p/715204070) |
| `simple_expr COLLATE_SYM ident_or_text`                      | 通过 `COLLATE` 子句覆盖比较操作中的默认排序规则              |
| `literal_or_null`                                            | 解析通用字面值或空值字面值，详见 [MySQL 源码｜48 - 语法解析(V2)：通用字面值](https://zhuanlan.zhihu.com/p/715612312) |
| `param_marker`                                               | 解析预编译语句中的占位符，详见 [MySQL 源码｜66 - 语法解析(V2)：预编译表达式的参数值](https://zhuanlan.zhihu.com/p/718323872) |
| `rvalue_system_or_user_variable`                             | 解析系统变量或用户变量                                       |
| `in_expression_user_variable_assignment`                     | 解析用户变量赋值语句                                         |
| `set_function_specification`                                 | 解析聚集函数                                                 |
| `window_func_call`                                           | 解析窗口函数，详见 [MySQL 源码｜38 - 语法解析(V2)：窗口函数](https://zhuanlan.zhihu.com/p/714780506) |
| `'+' simple_expr`                                            | 解析使用了 `+` 前缀一元表达式的基础表达式                    |
| `'-' simple_expr`                                            | 解析使用了 `-` 前缀一元表达式的基础表达式                    |
| `'~' simple_expr`                                            | 解析使用了 `~` 前缀一元表达式的基础表达式                    |
| `not2 simple_expr`                                           | 解析使用了 `!` 前缀一元表达式（或 SQL_MODE 为 `MODE_HIGH_NOT_PRECEDENCE` 时的 `NOT` 关键字）的基础表达式 |
| `row_subquery`                                               | 解析单行子查询，详见 [MySQL 源码｜47 - 语法解析(V2)：子查询](https://zhuanlan.zhihu.com/p/715426420) |
| `'(' expr ')'`                                               | 解析使用括号嵌套的一般表达式（最高级表达式）                 |
| `ROW_SYM '(' expr ',' expr_list ')'`                         | 解析 `ROW` 关键字引导的值列表                                |
| `EXISTS table_subquery`                                      | 解析 `EXISTS` 关键字引导的多行子查询，详见 [MySQL 源码｜47 - 语法解析(V2)：子查询](https://zhuanlan.zhihu.com/p/715426420) |
| `'{' ident expr '}'`                                         | 解析用于匹配 ODBC 日期的表达式                               |
| `MATCH ident_list_arg AGAINST '(' bit_expr fulltext_options ')'` | 用于解析 `FULLTEXT` 索引的全文搜索子句                       |
| `BINARY_SYM simple_expr`                                     | 用于解析 `BINARY` 关键字引导的子句，详见 [MySQL 源码｜49 - 语法解析(V2)：CAST、CONVERT 函数和 BINARY 关键字](https://zhuanlan.zhihu.com/p/715701073) |
| `CAST_SYM '(' expr AS cast_type opt_array_cast ')'`          | 用于解析 `CAST` 函数，详见 [MySQL 源码｜49 - 语法解析(V2)：CAST、CONVERT 函数和 BINARY 关键字](https://zhuanlan.zhihu.com/p/715701073) |
| `CAST_SYM '(' expr AT_SYM LOCAL_SYM AS cast_type opt_array_cast ')'` | 用于解析 `CAST` 函数，详见 [MySQL 源码｜49 - 语法解析(V2)：CAST、CONVERT 函数和 BINARY 关键字](https://zhuanlan.zhihu.com/p/715701073) |
| `CAST_SYM '(' expr AT_SYM TIME_SYM ZONE_SYM opt_interval TEXT_STRING_literal AS DATETIME_SYM type_datetime_precision ')'` | 用于解析 `CAST` 函数，详见 [MySQL 源码｜49 - 语法解析(V2)：CAST、CONVERT 函数和 BINARY 关键字](https://zhuanlan.zhihu.com/p/715701073) |
| `CASE_SYM opt_expr when_list opt_else END`                   | 用于解析 `CASE` 子句                                         |
| `CONVERT_SYM '(' expr ',' cast_type ')'`                     | 用于解析 `CONVERT` 函数，详见 [MySQL 源码｜49 - 语法解析(V2)：CAST、CONVERT 函数和 BINARY 关键字](https://zhuanlan.zhihu.com/p/715701073) |
| `CONVERT_SYM '(' expr USING charset_name ')'`                | 用于解析 `CONVERT` 函数，详见 [MySQL 源码｜49 - 语法解析(V2)：CAST、CONVERT 函数和 BINARY 关键字](https://zhuanlan.zhihu.com/p/715701073) |
| `DEFAULT_SYM '(' simple_ident ')'`                           | 用于解析 `DEFAULT` 函数                                      |
| `VALUES '(' simple_ident_nospvar ')'`                        | 用于解析 `VALUES` 函数                                       |
| `INTERVAL_SYM expr interval '+' expr %prec INTERVAL_SYM`     | 用于解析 `INTERVAL` 关键字引导的时间长度                     |
| `simple_ident JSON_SEPARATOR_SYM TEXT_STRING_literal`        | 用于解析 Json 格式数据提取语句                               |
| `simple_ident JSON_UNQUOTED_SEPARATOR_SYM TEXT_STRING_literal` | 用于解析 Json 格式数据提取语句                               |

```C++
simple_expr:
          simple_ident
        | function_call_keyword
        | function_call_nonkeyword
        | function_call_generic
        | function_call_conflict
        | simple_expr COLLATE_SYM ident_or_text %prec NEG
          {
            warn_on_deprecated_user_defined_collation(YYTHD, $3);
            $$= NEW_PTN Item_func_set_collation(@$, $1, $3);
          }
        | literal_or_null
        | param_marker { $$= $1; }
        | rvalue_system_or_user_variable
        | in_expression_user_variable_assignment
        | set_function_specification
        | window_func_call
        | simple_expr OR_OR_SYM simple_expr
          {
            $$= NEW_PTN Item_func_concat(@$, $1, $3);
          }
        | '+' simple_expr %prec NEG
          {
            $$= $2; // TODO: do we really want to ignore unary '+' before any kind of literals?
            if ($$ != nullptr) $$->m_pos = @$;
          }
        | '-' simple_expr %prec NEG
          {
            $$= NEW_PTN Item_func_neg(@$, $2);
          }
        | '~' simple_expr %prec NEG
          {
            $$= NEW_PTN Item_func_bit_neg(@$, $2);
          }
        | not2 simple_expr %prec NEG
          {
            $$= NEW_PTN PTI_truth_transform(@$, $2, Item::BOOL_NEGATED);
          }
        | row_subquery
          {
            $$= NEW_PTN PTI_singlerow_subselect(@$, $1);
          }
        | '(' expr ')'
          {
            $$= $2;
            if ($$ != nullptr) $$->m_pos = @$;
          }
        | '(' expr ',' expr_list ')'
          {
            $$= NEW_PTN Item_row(@$, $2, $4->value);
          }
        | ROW_SYM '(' expr ',' expr_list ')'
          {
            $$= NEW_PTN Item_row(@$, $3, $5->value);
          }
        | EXISTS table_subquery
          {
            $$= NEW_PTN PTI_exists_subselect(@$, $2);
          }
        | '{' ident expr '}'
          {
            $$= NEW_PTN PTI_odbc_date(@$, $2, $3);
          }
        | MATCH ident_list_arg AGAINST '(' bit_expr fulltext_options ')'
          {
            $$= NEW_PTN Item_func_match(@$, $2, $5, $6);
          }
        | BINARY_SYM simple_expr %prec NEG
          {
            push_deprecated_warn(YYTHD, "BINARY expr", "CAST");
            $$= create_func_cast(YYTHD, @$, $2, ITEM_CAST_CHAR, &my_charset_bin);
            if ($$ == nullptr)
              MYSQL_YYABORT;
          }
        | CAST_SYM '(' expr AS cast_type opt_array_cast ')'
          {
            $$= create_func_cast(YYTHD, @$, $3, $5, $6);
            if ($$ == nullptr)
              MYSQL_YYABORT;
          }
        | CAST_SYM '(' expr AT_SYM LOCAL_SYM AS cast_type opt_array_cast ')'
          {
            my_error(ER_NOT_SUPPORTED_YET, MYF(0), "AT LOCAL");
          }
        | CAST_SYM '(' expr AT_SYM TIME_SYM ZONE_SYM opt_interval
          TEXT_STRING_literal AS DATETIME_SYM type_datetime_precision ')'
          {
            Cast_type cast_type{ITEM_CAST_DATETIME, nullptr, nullptr, $11};
            auto datetime_factor =
                NEW_PTN Item_func_at_time_zone(@3, $3, $8.str, $7);
            $$ = create_func_cast(YYTHD, @$, datetime_factor, cast_type, false);
            if ($$ == nullptr)
              MYSQL_YYABORT;
          }
        | CASE_SYM opt_expr when_list opt_else END
          {
            $$= NEW_PTN Item_func_case(@$, $3, $2, $4 );
          }
        | CONVERT_SYM '(' expr ',' cast_type ')'
          {
            $$= create_func_cast(YYTHD, @$, $3, $5, false);
            if ($$ == nullptr)
              MYSQL_YYABORT;
          }
        | CONVERT_SYM '(' expr USING charset_name ')'
          {
            $$= NEW_PTN Item_func_conv_charset(@$, $3,$5);
          }
        | DEFAULT_SYM '(' simple_ident ')'
          {
            $$= NEW_PTN Item_default_value(@$, $3);
          }
        | VALUES '(' simple_ident_nospvar ')'
          {
            $$= NEW_PTN Item_insert_value(@$, $3);
          }
        | INTERVAL_SYM expr interval '+' expr %prec INTERVAL_SYM
          /* we cannot put interval before - */
          {
            $$= NEW_PTN Item_date_add_interval(@$, $5, $2, $3, 0);
          }
        | simple_ident JSON_SEPARATOR_SYM TEXT_STRING_literal
          {
            Item_string *path=
              NEW_PTN Item_string(@3, $3.str, $3.length,
                                  YYTHD->variables.collation_connection);
            $$= NEW_PTN Item_func_json_extract(YYTHD, @$, $1, path);
          }
         | simple_ident JSON_UNQUOTED_SEPARATOR_SYM TEXT_STRING_literal
          {
            Item_string *path=
              NEW_PTN Item_string(@3, $3.str, $3.length,
                                  YYTHD->variables.collation_connection);
            Item *extr= NEW_PTN Item_func_json_extract(YYTHD, @$, $1, path);
            $$= NEW_PTN Item_func_json_unquote(@$, extr);
          }
        ;
```

> `JSON_SEPARATOR_SYM` 终结符用于解析 `->` 符号；
>
> `JSON_UNQUOTED_SEPARATOR_SYM` 终结符用于解析 `->>` 符号。
>
> `opt_expr` 语义组用于解析可选的一般表达式（`expr` 语义组）。

#### 语义组：`rvalue_system_or_user_variable`

`rvalue_system_or_user_variable` 语义组用于解析系统变量（`@@` 开头）和用户变量（`@` 开头）。

- 官方文档：[MySQL 参考手册 - 7.1.9 Using System Variables](https://dev.mysql.com/doc/refman/8.4/en/using-system-variables.html)；[MySQL 参考手册 - 11.4 User-Defined Variables](https://dev.mysql.com/doc/refman/8.4/en/user-variables.html)
- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类。
- 备选规则和 Bison 语法：

| 备选规则                                                     | 规则含义     |
| ------------------------------------------------------------ | ------------ |
| `'@' ident_or_text`                                          | 解析用户变量 |
| `'@' '@' opt_rvalue_system_variable_type rvalue_system_variable` | 解析系统变量 |

```C++
rvalue_system_or_user_variable:
          '@' ident_or_text
          {
            $$ = NEW_PTN PTI_user_variable(@$, $2);
          }
        | '@' '@' opt_rvalue_system_variable_type rvalue_system_variable
          {
            $$ = NEW_PTN PTI_get_system_variable(@$, $3,
                                                 @4, $4.prefix, $4.name);
          }
        ;
```

#### 语义组：`opt_rvalue_system_variable_type`

`opt_rvalue_system_variable_type` 语义组用于解析 `GLOBAL` 关键字、`LOCAL` 关键字或 `SESSION` 关键字。

- 返回值类型：`enum_var_type` 枚举值（`var_type`），包含 `OPT_DEFAULT`、`OPT_SESSION`、`OPT_GLOBAL`、`OPT_PERSIST` 和 `OPT_PERSIST_ONLY`
- Bison 语法如下：

```C++
opt_rvalue_system_variable_type:
          %empty          { $$=OPT_DEFAULT; }
        | GLOBAL_SYM '.'  { $$=OPT_GLOBAL; }
        | LOCAL_SYM '.'   { $$=OPT_SESSION; }
        | SESSION_SYM '.' { $$=OPT_SESSION; }
        ;
```

#### 语义组：`rvalue_system_variable`

`rvalue_system_variable` 语义组用于解析 `ident_or_text` 或 `ident_or_text.ident`。

- 返回值类型：`LEX_STRING` 结构体（`lexer.lex_str`）
- Bison 语法如下：

```C++
rvalue_system_variable:
          ident_or_text
          {
            $$ = Bipartite_name{{}, to_lex_cstring($1)};
          }
        | ident_or_text '.' ident
          {
            // disallow "SELECT @@global.global.variable"
            if (check_reserved_words($1.str)) {
              YYTHD->syntax_error_at(@1);
              MYSQL_YYABORT;
            }
            $$ = Bipartite_name{to_lex_cstring($1), to_lex_cstring($3)};
          }
        ;
```

> `ident_or_text` 语义组解析标识符、任意未保留关键字、单引号 / 双引号字符串或用户自定义变量；
>
> `ident` 语义组解析标识符或任意未保留关键字。

#### 语义组：`in_expression_user_variable_assignment`

`in_expression_user_variable_assignment` 语义组用于解析用户自定义变量的赋值语句。

- 官方文档：[MySQL 参考手册 - 11.4 User-Defined Variables](https://dev.mysql.com/doc/refman/8.4/en/user-variables.html)
- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类。
- Bison 语法如下：

```C++
in_expression_user_variable_assignment:
          '@' ident_or_text SET_VAR expr
          {
            push_warning(YYTHD, Sql_condition::SL_WARNING,
                         ER_WARN_DEPRECATED_SYNTAX,
                         ER_THD(YYTHD, ER_WARN_DEPRECATED_USER_SET_EXPR));
            $$ = NEW_PTN PTI_variable_aux_set_var(@$, $2, $4);
          }
        ;
```

> `SET_VAR` 终结符解析 `:=` 符号。

#### 语义组：`not2`

`not2` 语义组用于解析 `!` 运算符或 SQL_MODE 开启了 `HIGH_NOT_PRECEDENCE` 时 `NOT` 关键字。

- 官方文档：[MySQL 参考手册 - 7.1.11 Server SQL Modes（HIGH_NOT_PRECEDENCE）](https://dev.mysql.com/doc/refman/8.4/en/sql-mode.html#sqlmode_high_not_precedence)
- 返回值类型：没有返回值
- Bison 语法如下：

```C++
not2:
          '!' { push_deprecated_warn(YYTHD, "!", "NOT"); }
        | NOT2_SYM
        ;
```

#### 语义组：`ident_list_arg`

`ident_list_arg` 语义组用于解析包含外层括号或不包含外层括号的标识符的、逗号分隔的、任意数量的标识符。

- 返回值类型：`PT_item_list` 对象（`item_list2`）
- 使用场景：`MATCH` 语句
- Bison 语法如下：

```C++
ident_list_arg:
          ident_list          { $$= $1; }
        | '(' ident_list ')'  { $$= $2; }
        ;
```

> 语义组`ident_list` 用于解析使用逗号分隔的任意数量标识符，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)。

#### 语义组：`fulltext_options`

`fulltext_options` 语义组用于解析全文搜索的配置信息。

- 官方文档：[MySQL 参考手册 - 14.9.1 Natural Language Full-Text Searches](https://dev.mysql.com/doc/refman/8.4/en/fulltext-natural-language.html)；[MySQL 参考手册 - 14.9.2 Boolean Full-Text Searches](https://dev.mysql.com/doc/refman/8.4/en/fulltext-boolean.html)；[MySQL 参考手册 - 14.9.3 Full-Text Searches with Query Expansion](https://dev.mysql.com/doc/refman/8.4/en/fulltext-query-expansion.html)
- 返回值类型：`int` 类型（`num`）
- Bison 语法如下：

```C++
fulltext_options:
          opt_natural_language_mode opt_query_expansion
          { $$= $1 | $2; }
        | IN_SYM BOOLEAN_SYM MODE_SYM
          {
            $$= FT_BOOL;
            DBUG_EXECUTE_IF("simulate_bug18831513",
                            {
                              THD *thd= YYTHD;
                              if (thd->sp_runtime_ctx)
                                YYTHD->syntax_error();
                            });
          }
        ;
```

> `opt_natural_language_mode` 语义组用于解析可选的 `IN NATURAL LANGUAGE MODE`；
>
> `opt_query_expansion` 语义组用于解析可选的 `WITH QUERY EXPANSION`。

#### 语义组：`opt_natural_language_mode`

`opt_natural_language_mode` 语义组用于解析可选的 `IN NATURAL LANGUAGE MODE`。

- 返回值类型：`int` 类型（`num`）
- Bison 语法如下：

```C++
opt_natural_language_mode:
          %empty { $$= FT_NL; }
        | IN_SYM NATURAL LANGUAGE_SYM MODE_SYM  { $$= FT_NL; }
        ;
```

#### 语义组：`opt_query_expansion`

`opt_query_expansion` 语义组用于解析可选的 `WITH QUERY EXPANSION`。

- 返回值类型：`int` 类型（`num`）
- Bison 语法如下：

```C++
opt_query_expansion:
          %empty { $$= 0;         }
        | WITH QUERY_SYM EXPANSION_SYM          { $$= FT_EXPAND; }
        ;
```

#### 语义组：`when_list`

`when_list` 语义组用于解析 `CASE` 子句中任意数量的 `WHEN {expr} THEN {expr}` 子句。

- 官方文档：[MySQL 参考手册 - 15.6.5.1 CASE Statement](https://dev.mysql.com/doc/refman/8.4/en/case.html)
- 返回值类型：`mem_root_deque<Item *>`（`item_list`）
- Bison 语法如下：

```C++
when_list:
          WHEN_SYM expr THEN_SYM expr
          {
            $$= new (YYMEM_ROOT) mem_root_deque<Item *>(YYMEM_ROOT);
            if ($$ == nullptr)
              MYSQL_YYABORT;
            $$->push_back($2);
            $$->push_back($4);
          }
        | when_list WHEN_SYM expr THEN_SYM expr
          {
            $1->push_back($3);
            $1->push_back($5);
            $$= $1;
          }
        ;
```

#### 语义组：`opt_else`

`opt_else` 语义组用于解析可选的 `ELSE {expr}` 子句。

- 官方文档：[MySQL 参考手册 - 15.6.5.1 CASE Statement](https://dev.mysql.com/doc/refman/8.4/en/case.html)
- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类。
- Bison 语法如下：

```C++
opt_else:
          %empty       { $$= nullptr; }
        | ELSE expr    { $$= $2; }
        ;
```

#### 语义组：`set_function_specification`

`set_function_specification` 语义组用于解析聚集函数和 `GROUPING` 函数超聚合结果。

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类。
- Bison 语法如下：

```C++
set_function_specification:
          sum_expr
        | grouping_operation
        ;
```

> `sum_expr` 语义组用于解析既是窗口函数，又是聚集函数的函数，详见 [MySQL 源码｜37 - 语法解析(V2)：聚集函数](https://zhuanlan.zhihu.com/p/714780278)。

#### 语义组：`grouping_operation`

`grouping_operation` 语义组用于解析 `GROUPING()` 函数超聚合结果。

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类。
- Bison 语法如下：

```C++
grouping_operation:
          GROUPING_SYM '(' expr_list ')'
          {
            $$= NEW_PTN Item_func_grouping(@$, $3);
          }
        ;
```

