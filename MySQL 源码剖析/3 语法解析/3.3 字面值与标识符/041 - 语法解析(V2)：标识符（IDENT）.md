目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[/sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

前置文档：

- [MySQL 源码｜21 - 词法解析：状态转移逻辑梳理](https://zhuanlan.zhihu.com/p/714760407)
- [MySQL 源码｜33 - 语法解析：bison 基础语法规则](https://zhuanlan.zhihu.com/p/714779214)
- [MySQL 源码｜64 - 词法解析(V2)：非保留关键字](https://zhuanlan.zhihu.com/p/717740054)

---

根据 [MySQL 源码｜21 - 词法解析：状态转移逻辑梳理](https://zhuanlan.zhihu.com/p/714760407) 中梳理的 MySQL 词法解析逻辑，终结符 `IDENT` 和终结符 `IDENT_QUOTED` 用于表示没有引号且可以作为标识符的标识符名称。下面我们通过使用了这两个终结符的语义组出发，梳理字符串字面值。

终结符设计的标记如下，其中绿色节点为本节梳理的语义组，蓝色节点为相关语义组（仅包含本节梳理节点使用的语义组，不包含使用本节梳理节点的语义组），灰色节点为相关终结符。

![语法解析-003-标识符](C:\blog\graph\MySQL源码剖析\语法解析-003-标识符.png)

#### 语义组：`IDENT_sys`（标识符基础元素）

语义组 `IDENT_sys` 用于解析没有引号、且可以作为标识符的标识符名称，根据 [MySQL 源码｜21 - 词法解析：状态转移逻辑梳理](https://zhuanlan.zhihu.com/p/714760407) 中梳理的 MySQL 词法解析逻辑，当名称中不包含多字节字符时为终结符 `IDENT`，包含多字节字符时为终结符 `IDENT_QUOTED`。

- 官方文档：[MySQL 参考手册 - 11.2 Schema Object Names](https://dev.mysql.com/doc/refman/8.4/en/identifiers.html)
- 返回值类型：`LEX_STRING` 结构体（`lexer.lex_str`），字符串。
- 使用场景：字段名、参数名、UDF 函数名和其他任意标识符
- 备选规则和 Bison 语法：

| 备选规则       | 备选规则含义                 |
| -------------- | ---------------------------- |
| `IDENT`        | 解析不包含多字节字符的标识符 |
| `IDENT_QUOTED` | 解析包含多字节字符的标识符   |

```C++
IDENT_sys:
          IDENT { $$= $1; }
        | IDENT_QUOTED
          {
            THD *thd= YYTHD;

            if (thd->charset_is_system_charset)
            {
              const CHARSET_INFO *cs= system_charset_info;
              int dummy_error;
              size_t wlen= cs->cset->well_formed_len(cs, $1.str,
                                                     $1.str+$1.length,
                                                     $1.length, &dummy_error);
              if (wlen < $1.length)
              {
                ErrConvString err($1.str, $1.length, &my_charset_bin);
                my_error(ER_INVALID_CHARACTER_STRING, MYF(0),
                         cs->csname, err.ptr());
                MYSQL_YYABORT;
              }
              $$= $1;
            }
            else
            {
              if (thd->convert_string(&$$, system_charset_info,
                                  $1.str, $1.length, thd->charset()))
                MYSQL_YYABORT;
            }
          }
        ;
```

#### 语义组：`ident`、`role_ident`、`label_ident` 和 `lvalue_ident`

语义组 `ident`、`role_ident`、`label_ident` 和 `lvalue_ident` 均用于解析没有引号、且可以作为标识符的标识符名称。这 4 个语义组均包含两个备选方案，分别是非关键字（`IDENT_sys` 语义组）和允许使用的未保留关键字；它们的语义行为也都是相同的。这 4 个语义组的区别在于，其中允许使用的未保留关键字各不相同，详见 [MySQL 源码｜64 - 词法解析(V2)：非保留关键字](https://zhuanlan.zhihu.com/p/717740054)。每个语义组中使用的未保留关键字语义组及使用场景如下：

| 语义组名称     | 语义组名称       | 语义组使用场景                                               |
| -------------- | ---------------- | ------------------------------------------------------------ |
| `ident`        | `ident_keyword`  | 解析标识符和任何未保留关键字                                 |
| `role_ident`   | `role_keyword`   | 解析标识符和可以用作 role 名称的未保留关键字                 |
| `label_ident`  | `label_keyword`  | 解析标识符和可以用作 SP 标签名称的未保留关键字               |
| `lvalue_ident` | `lvalue_keyword` | 解析标识符和可以用作 `SET` 赋值语句左侧的变量名或变量前缀的未保留关键字 |

- 官方文档：[MySQL 参考手册 - 11.2 Schema Object Names](https://dev.mysql.com/doc/refman/8.4/en/identifiers.html)
- 返回值类型：`LEX_STRING` 结构体（`lexer.lex_str`），字符串。
- Bison 语法：

```C++
ident:
          IDENT_sys    { $$=$1; }
        | ident_keyword
          {
            THD *thd= YYTHD;
            $$.str= thd->strmake($1.str, $1.length);
            if ($$.str == nullptr)
              MYSQL_YYABORT;
            $$.length= $1.length;
          }
        ;
```

```C++
role_ident:
          IDENT_sys
        | role_keyword
          {
            $$.str= YYTHD->strmake($1.str, $1.length);
            if ($$.str == nullptr)
              MYSQL_YYABORT;
            $$.length= $1.length;
          }
        ;
```

```C++
label_ident:
          IDENT_sys    { $$=to_lex_cstring($1); }
        | label_keyword
          {
            THD *thd= YYTHD;
            $$.str= thd->strmake($1.str, $1.length);
            if ($$.str == nullptr)
              MYSQL_YYABORT;
            $$.length= $1.length;
          }
        ;
```

```C++
lvalue_ident:
          IDENT_sys
        | lvalue_keyword
          {
            $$.str= YYTHD->strmake($1.str, $1.length);
            if ($$.str == nullptr)
              MYSQL_YYABORT;
            $$.length= $1.length;
          }
        ;
```

#### 语义组：`opt_ident`

`opt_ident` 语义组解析可选的标识符或任意未保留关键字，如果没有解析到 `ident` 则返回空值。

- 返回值类型：`LEX_STRING` 结构体（`lexer.lex_str`），字符串，可能为空值。
- Bison 语法：

```C++
opt_ident:
          %empty { $$= NULL_STR; }
        | ident
        ;
```

#### 语义组：`ident_or_empty`

`ident_or_empty` 语义组解析可选的 `ident`，如果没有解析到仍然返回 `LEX_STRING` 结构体，但其中指向字符串的指针为空指针，字符串长度为 0。

- 返回值类型：`LEX_STRING` 结构体（`lexer.lex_str`），字符串，可能为空值。
- Bison 语法：

```C++
ident_or_empty:
          %empty { $$.str= nullptr; $$.length= 0; }
        | ident { $$= $1; }
        ;
```

#### 语义组：`table_ident`

`table_ident` 语义组用于解析 `ident` 或 `ident.ident`。

- 返回值类型：`Table_ident` 类（`table`），其中包含数据库名和表名。
- Bison 语法：

```C++
table_ident:
          ident
          {
            $$= NEW_PTN Table_ident(to_lex_cstring($1));
            if ($$ == nullptr)
              MYSQL_YYABORT;
          }
        | ident '.' ident
          {
            auto schema_name = YYCLIENT_NO_SCHEMA ? LEX_CSTRING{}
                                                  : to_lex_cstring($1.str);
            $$= NEW_PTN Table_ident(schema_name, to_lex_cstring($3));
            if ($$ == nullptr)
              MYSQL_YYABORT;
          }
        ;
```

#### 语义组：`simple_ident_q`

`simple_ident_q` 语义组用于解析 `ident.ident` 或 `ident.ident.ident`。

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类。
- 使用场景：用于通用标识符语义组（`simple_ident` 语义组）
- 备选规则和 Bison 语法：

| 备选规则                    | 备选规则含义             | 返回值类型              |
| --------------------------- | ------------------------ | ----------------------- |
| `ident '.' ident`           | 解析 `ident.ident`       | `PTI_simple_ident_q_2d` |
| `ident '.' ident '.' ident` | 解析 `ident.ident.ident` | `PTI_simple_ident_q_3d` |

```C++
simple_ident_q:
          ident '.' ident
          {
            $$= NEW_PTN PTI_simple_ident_q_2d(@$, $1.str, $3.str);
          }
        | ident '.' ident '.' ident
          {
            if (check_and_convert_db_name(&$1, false) != Ident_name_check::OK)
              MYSQL_YYABORT;
            $$= NEW_PTN PTI_simple_ident_q_3d(@$, $1.str, $3.str, $5.str);
          }
        ;
```

#### 语义组：`simple_ident`

`simple_ident` 语义组用于解析 `ident`、`ident.ident` 或 `ident.ident.ident`。

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类。
- 备选规则和 Bison 语法：

| 备选规则                                               | 备选规则含义             | 返回值类型               |
| ------------------------------------------------------ | ------------------------ | ------------------------ |
| `ident`                                                | 解析 `ident`             | `PTI_simple_ident_ident` |
| `ident '.' ident`（`simple_ident_q` 语义组）           | 解析 `ident.ident`       | `PTI_simple_ident_q_2d`  |
| `ident '.' ident '.' ident`（`simple_ident_q` 语义组） | 解析 `ident.ident.ident` | `PTI_simple_ident_q_3d`  |

```C++
simple_ident:
          ident
          {
            $$= NEW_PTN PTI_simple_ident_ident(@$, to_lex_cstring($1));
          }
        | simple_ident_q
        ;
```

#### 语义组：`simple_ident_nospvar`

`simple_ident_nospvar` 语义组用于解析 `ident`、`ident.ident` 或 `ident.ident.ident`，并将 `ident` 的类型转换为 `PTI_simple_ident_nospvar_ident`。

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类。
- 备选规则和 Bison 语法：

| 备选规则                                               | 备选规则含义             | 返回值类型                       |
| ------------------------------------------------------ | ------------------------ | -------------------------------- |
| `ident`                                                | 解析 `ident`             | `PTI_simple_ident_nospvar_ident` |
| `ident '.' ident`（`simple_ident_q` 语义组）           | 解析 `ident.ident`       | `PTI_simple_ident_q_2d`          |
| `ident '.' ident '.' ident`（`simple_ident_q` 语义组） | 解析 `ident.ident.ident` | `PTI_simple_ident_q_3d`          |

```C++
simple_ident_nospvar:
          ident
          {
            $$= NEW_PTN PTI_simple_ident_nospvar_ident(@$, $1);
          }
        | simple_ident_q
        ;
```

#### 语义组：`simple_ident_list`

`simple_ident_list` 语义组用于解析逗号分隔、任意数量的 `ident`，并将返回值构造为 `Mem_root_array_YY<LEX_CSTRING>` 类型。

- 返回值类型：`Mem_root_array_YY<LEX_CSTRING>`（`simple_ident_list`）。
- 使用场景：`opt_derived_column_list` 语义组
- Bison 语法：

```C++
simple_ident_list:
          ident
          {
            $$.init(YYTHD->mem_root);
            if ($$.push_back(to_lex_cstring($1)))
              MYSQL_YYABORT; /* purecov: inspected */
          }
        | simple_ident_list ',' ident
          {
            $$= $1;
            if ($$.push_back(to_lex_cstring($3)))
              MYSQL_YYABORT;  /* purecov: inspected */
          }
        ;
```

#### 语义组：`ident_string_list`

`ident_string_list` 语义组用于解析逗号分隔、任意数量的 `ident`，并将返回值构造器 `List<String>` 类型。

- 返回值类型：`List<String>`（`string_list`）。
- 使用场景：`DROP PARTITION` 子句、`REORGANIZE PARTITION` 子句等
- Bison 语法：

```C++
ident_string_list:
          ident
          {
            $$= NEW_PTN List<String>;
            String *s= NEW_PTN String(const_cast<const char *>($1.str),
                                               $1.length,
                                               system_charset_info);
            if ($$ == nullptr || s == nullptr || $$->push_back(s))
              MYSQL_YYABORT;
          }
        | ident_string_list ',' ident
          {
            String *s= NEW_PTN String(const_cast<const char *>($3.str),
                                               $3.length,
                                               system_charset_info);
            if (s == nullptr || $1->push_back(s))
              MYSQL_YYABORT;
            $$= $1;
          }
        ;
```

#### 语义组：`ident_or_text` 和 `role_ident_or_text`

`ident_or_text` 语义组和 `role_ident_or_text` 语义组均用于解析标识符、字符串和用户自定义变量，区别在于 `ident_or_text` 语义组解析所有非保留关键字，`role_ident_or_text` 仅解析可以用作 role 名称的非保留关键字。

- 官方文档：[MySQL 参考手册 - 11.2 Schema Object Names](https://dev.mysql.com/doc/refman/8.4/en/identifiers.html)；[MySQL 参考手册 - 11.4 User-Defined Variables](https://dev.mysql.com/doc/refman/8.4/en/user-variables.html)
- 返回值类型：`LEX_STRING` 结构体（`lexer.lex_str`），字符串。
- 备选规则和 Bison 语法：

| 备选规则                | 备选规则含义                               | 返回值类型   |
| ----------------------- | ------------------------------------------ | ------------ |
| `ident` 或 `role_ident` | 解析标识符；解析可以作为 role 名称的标识符 | `LEX_STRING` |
| `TEXT_STRING_sys`       | 解析单引号 / 双引号字符串                  | `LEX_STRING` |
| `LEX_HOSTNAME`          | 解析 `@` 开头的用户自定义变量              | `LEX_STRING` |

```C++
ident_or_text:
          ident           { $$=$1;}
        | TEXT_STRING_sys { $$=$1;}
        | LEX_HOSTNAME { $$=$1;}
        ;
```

```C++
role_ident_or_text:
          role_ident
        | TEXT_STRING_sys
        | LEX_HOSTNAME
        ;
```

#### 语义组：`user_ident_or_text` 和 `role`

`user_ident_or_text` 语义组解析 `ident_or_text` 或 `ident_or_text@ident_or_text`，`role` 语义组解析 `role_ident_or_text` 或 `role_ident_or_text@ident_or_text`。

- 返回值类型：`LEX_USER` 结构体（`lex_user`），其中包含了与用户及其相关的认证详情。
- `user_ident_or_text` 使用场景：`user` 语义组、`user_list` 语义组
- `role` 使用场景：`role_list` 语义组
- Bison 语法：

```C++
user_ident_or_text:
          ident_or_text
          {
            if (!($$= LEX_USER::alloc(YYTHD, &$1, nullptr)))
              MYSQL_YYABORT;
          }
        | ident_or_text '@' ident_or_text
          {
            if (!($$= LEX_USER::alloc(YYTHD, &$1, &$3)))
              MYSQL_YYABORT;
          }
        ;
```

#### 语义组：`role_list`

`role_list` 语义组解析任意数量、逗号分隔的 `role` 语义组解析结果。

- 返回值类型：`List<LEX_USER>`（`user_list`）
- 使用场景：`SET ROLE` 子句、`WITH ROLE` 子句等
- Bison 语法：

```C++
role_list:
          role
          {
            $$= new (YYMEM_ROOT) List<LEX_USER>;
            if ($$ == nullptr || $$->push_back($1))
              MYSQL_YYABORT;
          }
        | role_list ',' role
          {
            $$= $1;
            if ($$->push_back($3))
              MYSQL_YYABORT;
          }
        ;
```

#### 语义组：`schema`（数据库名称）

语义组 `schema` 用于解析数据库名称，在解析到 `ident` 语义组结果后，后检查是否满足为数据库名称。

- 返回值类型：`LEX_STRING` 结构体（`lexer.lex_str`），字符串。
- Bison 语法：

```C++
schema:
          ident
          {
            $$ = $1;
            if (check_and_convert_db_name(&$$, false) != Ident_name_check::OK)
              MYSQL_YYABORT;
          }
        ;
```

#### 语义组：`ident_list`

`ident_list` 语义组用于解析使用逗号分隔的任意数量标识符。

- 返回值类型：`PT_item_list` 对象（`ident_list`）
- Bison 语法如下：

```C++
ident_list:
          simple_ident
          {
            $$= NEW_PTN PT_item_list(@$);
            if ($$ == nullptr || $$->push_back($1))
              MYSQL_YYABORT;
          }
        | ident_list ',' simple_ident
          {
            if ($1 == nullptr || $1->push_back($3))
              MYSQL_YYABORT;
            $$= $1;
            $$->m_pos = @$;
          }
        ;
```
