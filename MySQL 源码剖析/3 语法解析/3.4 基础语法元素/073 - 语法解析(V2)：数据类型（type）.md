目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

下面梳理用于解析 MySQL 数据类型的 `type` 语义组，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析-024-数据类型](C:\blog\graph\MySQL源码剖析\语法解析-024-数据类型.png)

#### 语义组：`type`

`type` 语义组用于解析 MySQL 中的数据类型。

- 官方文档：[MySQL 参考手册 - Chapter 13 Data Types](https://dev.mysql.com/doc/refman/8.4/en/data-types.html)
- 返回值类型：`PT_type` 对象（`type`）
- 备选规则和 Bison 语法如下：

| 备选规则                                                   | 规则含义                                                     |
| ---------------------------------------------------------- | ------------------------------------------------------------ |
| `int_type opt_field_length field_options`                  | 解析 `INT`、`TINYINT`、`SMALLINT`、`MEDIUMINT`、`BIGINT` 类型 |
| `real_type opt_precision field_options`                    | 解析 `REAL`、`DOUBLE` 或 `DOUBLE PRECISION` 类型             |
| `numeric_type float_options field_options`                 | 解析  `FLOAT`、`DECIMAL`、`NUMERIC` 或 `FIXED` 类型          |
| `BIT_SYM`                                                  | 解析 `BIT` 类型                                              |
| `BIT_SYM field_length`                                     | 解析指定长度的 `BIT` 类型                                    |
| `BOOL_SYM`                                                 | 解析 `BOOL` 类型                                             |
| `BOOLEAN_SYM`                                              | 解析 `BOOLEAN` 类型                                          |
| `CHAR_SYM field_length opt_charset_with_opt_binary`        | 解析指定长度的 `CHAR` 类型                                   |
| `CHAR_SYM opt_charset_with_opt_binary`                     | 解析 `CHAR` 类型                                             |
| `nchar field_length opt_bin_mod`                           | 解析指定长度的 `NCHAR` 或 `NATIONAL CHAR` 类型               |
| `nchar opt_bin_mod`                                        | 解析 `NCHAR` 或 `NATIONAL CHAR` 类型                         |
| `BINARY_SYM field_length`                                  | 解析指定长度的 `BINARY` 类型                                 |
| `BINARY_SYM`                                               | 解析 `BINARY` 类型                                           |
| `varchar field_length opt_charset_with_opt_binary`         | 解析 `CHAR VARYING` 或 `VARCHAR` 类型                        |
| `nvarchar field_length opt_bin_mod`                        | 解析 `NATIONAL VARCHAR`、`NVARCHAR`、`NCHAR VARCHAR`、`NATIONAL CHAR VARYING` 或`NCHAR VARYING` 类型 |
| `VARBINARY_SYM field_length`                               | 解析 `VARBINARY` 类型                                        |
| `YEAR_SYM opt_field_length field_options`                  | 解析 `YEAR` 类型                                             |
| `DATE_SYM`                                                 | 解析 `DATE` 类型                                             |
| `TIME_SYM type_datetime_precision`                         | 解析 `TIME` 类型                                             |
| `TIMESTAMP_SYM type_datetime_precision`                    | 解析 `TIMESTAMP` 类型                                        |
| `DATETIME_SYM type_datetime_precision`                     | 解析 `DATETIME` 类型                                         |
| `TINYBLOB_SYM`                                             | 解析 `TINYBLOB` 类型                                         |
| `BLOB_SYM opt_field_length`                                | 解析 `BLOB` 类型                                             |
| `spatial_type`                                             | 解析 `GEOMETRY`、`GEOMETRYCOLLECTION`、`POINT`、`MULTIPOINT`、`LINESTRING`、`MULTILINESTRING`、`POLYGON` 或 `MULTIPOLYGON` 类型 |
| `MEDIUMBLOB_SYM`                                           | 解析 `MEDIUMBLOB` 类型                                       |
| `LONGBLOB_SYM`                                             | 解析 `LONGBLOB` 类型                                         |
| `LONG_SYM VARBINARY_SYM`                                   | 解析 `LONG VARBINARY` 类型                                   |
| `LONG_SYM varchar opt_charset_with_opt_binary`             | 解析 `LONG CHAR VARYING` 或 `LONG VARCHAR` 类型              |
| `TINYTEXT_SYN opt_charset_with_opt_binary`                 | 解析 `TINYTEXT` 类型                                         |
| `TEXT_SYM opt_field_length opt_charset_with_opt_binary`    | 解析 `TEXT` 类型                                             |
| `MEDIUMTEXT_SYM opt_charset_with_opt_binary`               | 解析 `MEDIUMTEXT` 类型                                       |
| `LONGTEXT_SYM opt_charset_with_opt_binary`                 | 解析 `LONGTEXT` 类型                                         |
| `ENUM_SYM '(' string_list ')' opt_charset_with_opt_binary` | 解析 `ENUM` 类型                                             |
| `SET_SYM '(' string_list ')' opt_charset_with_opt_binary`  | 解析 `SET` 类型                                              |
| `LONG_SYM opt_charset_with_opt_binary`                     | 解析 `LONG` 类型                                             |
| `SERIAL_SYM`                                               | 解析 `SERIAL` 类型                                           |
| `JSON_SYM`                                                 | 解析 `JSON` 类型                                             |

```C++
type:
          int_type opt_field_length field_options
          {
            $$= NEW_PTN PT_numeric_type(@$, YYTHD, $1, $2, $3);
          }
        | real_type opt_precision field_options
          {
            $$= NEW_PTN PT_numeric_type(@$, YYTHD, $1, $2.length, $2.dec, $3);
          }
        | numeric_type float_options field_options
          {
            $$= NEW_PTN PT_numeric_type(@$, YYTHD, $1, $2.length, $2.dec, $3);
          }
        | BIT_SYM %prec KEYWORD_USED_AS_KEYWORD
          {
            $$= NEW_PTN PT_bit_type(@$);
          }
        | BIT_SYM field_length
          {
            $$= NEW_PTN PT_bit_type(@$, $2);
          }
        | BOOL_SYM
          {
            $$= NEW_PTN PT_boolean_type(@$);
          }
        | BOOLEAN_SYM
          {
            $$= NEW_PTN PT_boolean_type(@$);
          }
        | CHAR_SYM field_length opt_charset_with_opt_binary
          {
            $$= NEW_PTN PT_char_type(@$, Char_type::CHAR, $2, $3.charset,
                                     $3.force_binary);
          }
        | CHAR_SYM opt_charset_with_opt_binary
          {
            $$= NEW_PTN PT_char_type(@$, Char_type::CHAR, $2.charset,
                                     $2.force_binary);
          }
        | nchar field_length opt_bin_mod
          {
            const CHARSET_INFO *cs= $3 ?
              get_bin_collation(national_charset_info) : national_charset_info;
            if (cs == nullptr)
              MYSQL_YYABORT;
            $$= NEW_PTN PT_char_type(@$, Char_type::CHAR, $2, cs);
            warn_about_deprecated_national(YYTHD);
          }
        | nchar opt_bin_mod
          {
            const CHARSET_INFO *cs= $2 ?
              get_bin_collation(national_charset_info) : national_charset_info;
            if (cs == nullptr)
              MYSQL_YYABORT;
            $$= NEW_PTN PT_char_type(@$, Char_type::CHAR, cs);
            warn_about_deprecated_national(YYTHD);
          }
        | BINARY_SYM field_length
          {
            $$= NEW_PTN PT_char_type(@$, Char_type::CHAR, $2, &my_charset_bin);
          }
        | BINARY_SYM
          {
            $$= NEW_PTN PT_char_type(@$, Char_type::CHAR, &my_charset_bin);
          }
        | varchar field_length opt_charset_with_opt_binary
          {
            $$= NEW_PTN PT_char_type(@$, Char_type::VARCHAR, $2, $3.charset,
                                     $3.force_binary);
          }
        | nvarchar field_length opt_bin_mod
          {
            const CHARSET_INFO *cs= $3 ?
              get_bin_collation(national_charset_info) : national_charset_info;
            if (cs == nullptr)
              MYSQL_YYABORT;
            $$= NEW_PTN PT_char_type(@$, Char_type::VARCHAR, $2, cs);
            warn_about_deprecated_national(YYTHD);
          }
        | VARBINARY_SYM field_length
          {
            $$= NEW_PTN PT_char_type(@$, Char_type::VARCHAR, $2, &my_charset_bin);
          }
        | YEAR_SYM opt_field_length field_options
          {
            if ($2)
            {
              errno= 0;
              ulong length= strtoul($2, nullptr, 10);
              if (errno != 0 || length != 4)
              {
                /* Only support length is 4 */
                my_error(ER_INVALID_YEAR_COLUMN_LENGTH, MYF(0), "YEAR");
                MYSQL_YYABORT;
              }
              push_deprecated_warn(YYTHD, "YEAR(4)", "YEAR");
            }
            if ($3 == UNSIGNED_FLAG)
            {
              push_warning(YYTHD, Sql_condition::SL_WARNING,
                           ER_WARN_DEPRECATED_SYNTAX_NO_REPLACEMENT,
                           ER_THD(YYTHD, ER_WARN_DEPRECATED_YEAR_UNSIGNED));
            }
            // We can ignore field length and UNSIGNED/ZEROFILL attributes here.
            $$= NEW_PTN PT_year_type(@$);
          }
        | DATE_SYM
          {
            $$= NEW_PTN PT_date_type(@$);
          }
        | TIME_SYM type_datetime_precision
          {
            $$= NEW_PTN PT_time_type(@$, Time_type::TIME, $2);
          }
        | TIMESTAMP_SYM type_datetime_precision
          {
            $$= NEW_PTN PT_timestamp_type(@$, $2);
          }
        | DATETIME_SYM type_datetime_precision
          {
            $$= NEW_PTN PT_time_type(@$, Time_type::DATETIME, $2);
          }
        | TINYBLOB_SYM
          {
            $$= NEW_PTN PT_blob_type(@$, Blob_type::TINY, &my_charset_bin);
          }
        | BLOB_SYM opt_field_length
          {
            $$= NEW_PTN PT_blob_type(@$, $2);
          }
        | spatial_type
        | MEDIUMBLOB_SYM
          {
            $$= NEW_PTN PT_blob_type(@$, Blob_type::MEDIUM, &my_charset_bin);
          }
        | LONGBLOB_SYM
          {
            $$= NEW_PTN PT_blob_type(@$, Blob_type::LONG, &my_charset_bin);
          }
        | LONG_SYM VARBINARY_SYM
          {
            $$= NEW_PTN PT_blob_type(@$, Blob_type::MEDIUM, &my_charset_bin);
          }
        | LONG_SYM varchar opt_charset_with_opt_binary
          {
            $$= NEW_PTN PT_blob_type(@$, Blob_type::MEDIUM, $3.charset,
                                     $3.force_binary);
          }
        | TINYTEXT_SYN opt_charset_with_opt_binary
          {
            $$= NEW_PTN PT_blob_type(@$, Blob_type::TINY, $2.charset,
                                     $2.force_binary);
          }
        | TEXT_SYM opt_field_length opt_charset_with_opt_binary
          {
            $$= NEW_PTN PT_char_type(@$, Char_type::TEXT, $2, $3.charset,
                                     $3.force_binary);
          }
        | MEDIUMTEXT_SYM opt_charset_with_opt_binary
          {
            $$= NEW_PTN PT_blob_type(@$, Blob_type::MEDIUM, $2.charset,
                                     $2.force_binary);
          }
        | LONGTEXT_SYM opt_charset_with_opt_binary
          {
            $$= NEW_PTN PT_blob_type(@$, Blob_type::LONG, $2.charset,
                                     $2.force_binary);
          }
        | ENUM_SYM '(' string_list ')' opt_charset_with_opt_binary
          {
            $$= NEW_PTN PT_enum_type(@$, $3, $5.charset, $5.force_binary);
          }
        | SET_SYM '(' string_list ')' opt_charset_with_opt_binary
          {
            $$= NEW_PTN PT_set_type(@$, $3, $5.charset, $5.force_binary);
          }
        | LONG_SYM opt_charset_with_opt_binary
          {
            $$= NEW_PTN PT_blob_type(@$, Blob_type::MEDIUM, $2.charset,
                                     $2.force_binary);
          }
        | SERIAL_SYM
          {
            $$= NEW_PTN PT_serial_type(@$);
          }
        | JSON_SYM
          {
            $$= NEW_PTN PT_json_type(@$);
          }
        ;
```

> `int_type` 语义组用于解析 `INT`、`TINYINT`、`SMALLINT`、`MEDIUMINT` 或 `BIGINT` 关键字，详见下文；
>
> `opt_field_length` 语义组用于解析可选的字符型字段的最大长度，详见下文；
>
> `field_options` 语义组用于解析可选的、任意数量、空格分隔的 `SIGNED`、`UNISIGNED` 或 `ZEROFILL` 关键字，详见下文；
>
> `real_type` 语义组用于解析 `REAL`、`DOUBLE` 或 `DOUBLE PRECISION`，详见下文；
>
> `opt_precision` 语义组用于解析可选的浮点数参数（包括长度和小数位数），详见下文；
>
> `numeric_type` 语义组用于解析 `FLOAT`、`DECIMAL`、`NUMERIC` 或 `FIXED` 关键字，详见下文；
>
> `float_options` 语义组用于解析可选的小数精度，详见下文；
>
> `opt_charset_with_opt_binary` 语义组用于解析可选的编码类型，详见下文；
>
> `nchar` 语义组用于解析 `NCHAR` 或 `NATIONAL CHAR`，详见下文；
>
> `opt_bin_mod` 语义组用于解析可选的 `BINARY` 关键字，详见下文；
>
> `varchar` 语义组用于解析 `CHAR VARYING` 关键字或 `VARCHAR` 关键字，详见下文；
>
> `nvarchar` 语义组用于解析 `NATIONAL VARCHAR`、`NVARCHAR`、`NCHAR VARCHAR`、`NATIONAL CHAR VARYING` 或`NCHAR VARYING` 关键字，详见下文；
>
> `type_datetime_precision` 语义组用于解析可选时间精度参数括号，详见下文；
>
> `spatial_type` 语义组用于解析 `GEOMETRY`、`GEOMETRYCOLLECTION`、`POINT`、`MULTIPOINT`、`LINESTRING`、`MULTILINESTRING`、`POLYGON` 或 `MULTIPOLYGON` 类型关键字，详见下文；
>
> `string_list` 语义组用于解析任意数量、逗号分隔的单引号 / 双引号字符串、十六进制数或二进制数，详见 [MySQL 源码｜65 - 语法解析(V2)：字符串字面值](https://zhuanlan.zhihu.com/p/717934287)。

#### 语义组：`int_type`

`int_type` 语义组用于解析 `INT`、`TINYINT`、`SMALLINT`、`MEDIUMINT` 或 `BIGINT` 关键字。

- 官方文档：[MySQL 参考手册 - 13.1 Numeric Data Types](https://dev.mysql.com/doc/refman/8.4/en/numeric-types.html)
- 返回值类型：`Int_type` 枚举类（`int_type`），包括 `INT`、`TINYINT`、`SMALLINT`、`MEDIUMINT` 和 `BIGINT` 这 5 个枚举值
- Bison 语法如下：

```C++
int_type:
          INT_SYM       { $$=Int_type::INT; }
        | TINYINT_SYM   { $$=Int_type::TINYINT; }
        | SMALLINT_SYM  { $$=Int_type::SMALLINT; }
        | MEDIUMINT_SYM { $$=Int_type::MEDIUMINT; }
        | BIGINT_SYM    { $$=Int_type::BIGINT; }
        ;
```

#### 语义组：`opt_field_length`

`opt_field_length` 语义组用于解析可选的字符型字段的最大长度。

- 返回值类型：`const char`（`c_str`）
- 使用场景：`BINARY` 类型、`CHAR` 类型和 `NCHAR` 类型
- Bison 语法如下：

```C++
opt_field_length:
          %empty { $$= nullptr; /* use default length */ }
        | field_length
        ;
```

> `field_length` 语义组用于解析解析字符型字段的最大长度，详见下文。

#### 语义组：`field_length`

`field_length` 语义组用于解析字符型字段的最大长度。

- 返回值类型：`const char`（`c_str`）
- Bison 语法如下：

```C++
field_length:
          '(' LONG_NUM ')'      { $$= $2.str; }
        | '(' ULONGLONG_NUM ')' { $$= $2.str; }
        | '(' DECIMAL_NUM ')'   { $$= $2.str; }
        | '(' NUM ')'           { $$= $2.str; };
```

> 语义组 `LONG_NUM` 解析长整型（-9223372036854775808 到 9223372036854775807，且不在 `NUM` 的范围中）；
>
> 语义组 `ULONGLONG_NUM` 解析无符号整型（9223372036854775807 到 18446744073709551615）；
>
> 语义组 `DECIMAL_NUM` 解析十进制整数（小于 -9223372036854775808 或大于 18446744073709551615），或包含 `.` 而不包含 e 或 E 的十进制小数；
>
> 语义组 `NUM` 解析整型（-2147483648 到 2147483647）。

#### 语义组：`field_options`

`field_options` 语义组用于解析可选的、任意数量、空格分隔的 `SIGNED`、`UNISIGNED` 或 `ZEROFILL` 关键字。

- 返回值类型：`unsigned long` 类型（`field_option`）
- Bison 语法如下：

```C++
field_options:
          %empty { $$ = 0; }
        | field_opt_list
        ;
```

#### 语义组：`field_opt_list`

`field_options` 语义组用于解析任意数量、空格分隔的 `SIGNED`、`UNISIGNED` 或 `ZEROFILL` 关键字。

- 返回值类型：`unsigned long` 类型（`field_option`）
- Bison 语法如下：

```C++
field_opt_list:
          field_opt_list field_option
          {
            $$ = $1 | $2;
          }
        | field_option
        ;
```

#### 语义组：`field_option`

`field_option` 语义组用于解析 `SIGNED`、`UNISIGNED` 或 `ZEROFILL` 关键字。

- 返回值类型：`unsigned long` 类型（`field_option`）
- Bison 语法如下：

```C++
field_option:
          SIGNED_SYM   { $$ = 0; } // TODO: remove undocumented ignored syntax
        | UNSIGNED_SYM { $$ = UNSIGNED_FLAG; }
        | ZEROFILL_SYM {
            $$ = ZEROFILL_FLAG;
            push_warning(YYTHD, Sql_condition::SL_WARNING,
                         ER_WARN_DEPRECATED_SYNTAX_NO_REPLACEMENT,
                         ER_THD(YYTHD, ER_WARN_DEPRECATED_ZEROFILL));
          }
        ;
```

#### 语义组：`real_type`

`real_type` 语义组用于解析 `REAL`、`DOUBLE` 或 `DOUBLE PRECISION`。

- 返回值类型：`Numeric_type` 枚举值（`numeric_type`）
- 备选规则和 Bison 语法如下：

| 备选规则                   | 备选规则含义                                                 |
| -------------------------- | ------------------------------------------------------------ |
| `REAL_SYM`                 | 解析标准语法 `REAL`（如果开启 `REAL_AS_FLOAT` 模式则为 `FLOAT` 类型，否则为 `DOUBLE` 类型） |
| `DOUBLE_SYM opt_PRECISION` | 解析标准语法 `DOUBLE [PRECISION]`（`DOUBLE` 类型）           |

```C++
real_type:
          REAL_SYM
          {
            $$= YYTHD->variables.sql_mode & MODE_REAL_AS_FLOAT ?
              Numeric_type::FLOAT : Numeric_type::DOUBLE;
          }
        | DOUBLE_SYM opt_PRECISION
          { $$= Numeric_type::DOUBLE; }
        ;
```

#### 语义组：`opt_PRECISION`

`opt_PRECISION` 语义组用于解析可选的 `PRECISION` 关键字。

- 返回值类型：没有返回值
- Bison 语法如下：

```C++
opt_PRECISION:
          %empty
        | PRECISION
        ;
```

#### 语义组：`opt_precision`

`opt_precision` 语义组用于解析可选的浮点数参数（包括长度和小数位数）。

- 返回值类型：`precision` 结构体，其中包含长度和小数位
- Bison 语法如下：

```C++
opt_precision:
          %empty
          {
            $$.length= nullptr;
            $$.dec = nullptr;
          }
        | precision
        ;
```

#### 语义组：`precision`

`precision` 语义组用于解析指定了长度和小数位数的小数精度。

- 返回值类型：`precision` 结构体，其中包含长度和小数位
- Bison 语法如下：

```C++
precision:
          '(' NUM ',' NUM ')'
          {
            $$.length= $2.str;
            $$.dec= $4.str;
          }
        ;
```

#### 语义组：`numeric_type`

`numeric_type` 语义组用于解析 `FLOAT`、`DECIMAL`、`NUMERIC` 或 `FIXED` 关键字。

- 返回值类型：`Numeric_type` 枚举值（`numeric_type`），包含 `DECIMAL`、`FLOAT` 和 `DOUBLE` 这 3 个枚举值
- Bison 语法如下：

```C++
numeric_type:
          FLOAT_SYM   { $$= Numeric_type::FLOAT; }
        | DECIMAL_SYM { $$= Numeric_type::DECIMAL; }
        | NUMERIC_SYM { $$= Numeric_type::DECIMAL; }
        | FIXED_SYM   { $$= Numeric_type::DECIMAL; }
        ;
```

#### 语义组：`float_options`

`float_options` 语义组用于解析可选的小数精度。

- 返回值类型：`precision` 结构体，其中包含长度和小数位

```C++
  struct {
    const char *length;
    const char *dec;
  } precision;
```

- Bison 语法如下：

```C++
float_options:
          %empty
          {
            $$.length= nullptr;
            $$.dec= nullptr;
          }
        | field_length
          {
            $$.length= $1;
            $$.dec= nullptr;
          }
        | precision
        ;
```

> `field_length` 语义组用于解析字符型字段的最大长度，详见上文；
>
> `precision` 语义组用于解析指定了长度和小数位数的小数精度，详见上文。

#### 语义组：`opt_charset_with_opt_binary`

`opt_charset_with_opt_binary` 语义组用于解析可选的编码类型。

- 官方文档：[MySQL 参考手册 - 14.10 Cast Functions and Operators](https://dev.mysql.com/doc/refman/8.4/en/cast-functions.html#cast-character-set-conversions)
- 返回值类型：`charset_with_opt_binary` 结构体

```C++
struct {
    const CHARSET_INFO *charset;
    bool force_binary;
  } charset_with_opt_binary;
```

- 使用场景：`CHAR` 类型、`varchar` 类型、`LONG VARCHAR` 类型、`TINYTEXT` 类型、`TEXT` 类型、`MEDIUMTEXT` 类型、`LONGTEXT` 类型、`ENUM` 类型、`SET` 类型、`LONG` 类型
- 备选方案和 Bison 语法如下：

| 备选规则                                          | 备选规则含义                                                 |
| ------------------------------------------------- | ------------------------------------------------------------ |
| `%empty`                                          | 不解析                                                       |
| `ASCII_SYM`（来自 `ascii` 语义组）                | 解析标准语法 `ASCII`（等价于 `CHAR SET latin1`）             |
| `BINARY_SYM ASCII_SYM`（来自 `ascii` 语义组）     | 解析标准语法 `BINARY ASCII`（等价于 `CHAR SET latin1 BINARY`） |
| `ASCII_SYM BINARY_SYM`（来自 `ascii` 语义组）     | 解析标准语法 `ASCII BINARY`（等价于 `CHAR SET latin1 BINARY`） |
| `UNICODE_SYM`（来自 `unicode` 语义组）            | 解析标准语法 `UNICODE`（等价于 `CHAR SET uc2`）              |
| `UNICODE_SYM BINARY_SYM`（来自 `unicode` 语义组） | 解析标准语法 `BINARY UNICODE`（等价于 `CHAR SET uc2 BINARY`） |
| `BINARY_SYM UNICODE_SYM`（来自 `unicode` 语义组） | 解析标准语法 `BINARY UNICODE`（等价于 `CHAR SET uc2 BINARY`） |
| `BYTE_SYM`                                        | 解析标准语法 `BYTE`                                          |
| `character_set charset_name opt_bin_mod`          | 解析标准语法 `{CHAR SET | CHARSET} charset_name [BINARY]`（使用名称选择字符集） |
| `BINARY_SYM`                                      | 解析标准语法 `BINARY`                                        |
| `BINARY_SYM character_set charset_name`           | 解析标准语法 `BINARY {CHAR SET | CHARSET} charset_name`（使用名称选择字符集） |

```C++
opt_charset_with_opt_binary:
          %empty
          {
            $$.charset= nullptr;
            $$.force_binary= false;
          }
        | ascii
          {
            $$.charset= $1;
            $$.force_binary= false;
          }
        | unicode
          {
            $$.charset= $1;
            $$.force_binary= false;
          }
        | BYTE_SYM
          {
            $$.charset= &my_charset_bin;
            $$.force_binary= false;
          }
        | character_set charset_name opt_bin_mod
          {
            $$.charset= $3 ? get_bin_collation($2) : $2;
            if ($$.charset == nullptr)
              MYSQL_YYABORT;
            $$.force_binary= false;
          }
        | BINARY_SYM
          {
            warn_about_deprecated_binary(YYTHD);
            $$.charset= nullptr;
            $$.force_binary= true;
          }
        | BINARY_SYM character_set charset_name
          {
            warn_about_deprecated_binary(YYTHD);
            $$.charset= get_bin_collation($3);
            if ($$.charset == nullptr)
              MYSQL_YYABORT;
            $$.force_binary= false;
          }
        ;
```

> `charset_name` 语义组用于解析字符集名称，详见 [MySQL 源码｜43 - 语法解析(V2)：关键字函数](https://zhuanlan.zhihu.com/p/714784157)。

#### 语义组：`ascii`

`ascii` 语义组用于解析 `ASCII` 字符集名称。

- 返回值类型：`const CHARSET_INFO` 结构体（`lexer.charset`）
- 备选规则和 Bison 语法：

| 备选规则               | 备选规则含义                                                 |
| ---------------------- | ------------------------------------------------------------ |
| `ASCII_SYM`            | 解析标准语法 `ASCII`（等价于 `CHAR SET latin1`）             |
| `BINARY_SYM ASCII_SYM` | 解析标准语法 `BINARY ASCII`（等价于 `CHAR SET latin1 BINARY`） |
| `ASCII_SYM BINARY_SYM` | 解析标准语法 `ASCII BINARY`（等价于 `CHAR SET latin1 BINARY`） |

```C++
ascii:
          ASCII_SYM        {
          push_deprecated_warn(YYTHD, "ASCII", "CHARACTER SET charset_name");
          $$= &my_charset_latin1;
        }
        | BINARY_SYM ASCII_SYM {
            warn_about_deprecated_binary(YYTHD);
            push_deprecated_warn(YYTHD, "ASCII", "CHARACTER SET charset_name");
            $$= &my_charset_latin1_bin;
        }
        | ASCII_SYM BINARY_SYM {
            push_deprecated_warn(YYTHD, "ASCII", "CHARACTER SET charset_name");
            warn_about_deprecated_binary(YYTHD);
            $$= &my_charset_latin1_bin;
        }
        ;
```

#### 语义组：`unicode`

`ascii` 语义组用于解析 `Unicode` 字符集名称。

- 返回值类型：`const CHARSET_INFO` 结构体（`lexer.charset`）
- 备选规则和 Bison 语法：

| 备选规则                 | 备选规则含义                                                 |
| ------------------------ | ------------------------------------------------------------ |
| `UNICODE_SYM`            | 解析标准语法 `UNICODE`（等价于 `CHAR SET uc2`）              |
| `UNICODE_SYM BINARY_SYM` | 解析标准语法 `BINARY UNICODE`（等价于 `CHAR SET uc2 BINARY`） |
| `BINARY_SYM UNICODE_SYM` | 解析标准语法 `BINARY UNICODE`（等价于 `CHAR SET uc2 BINARY`） |

```C++
unicode:
          UNICODE_SYM
          {
            push_deprecated_warn(YYTHD, "UNICODE", "CHARACTER SET charset_name");
            if (!($$= get_charset_by_csname("ucs2", MY_CS_PRIMARY,MYF(0))))
            {
              my_error(ER_UNKNOWN_CHARACTER_SET, MYF(0), "ucs2");
              MYSQL_YYABORT;
            }
          }
        | UNICODE_SYM BINARY_SYM
          {
            push_deprecated_warn(YYTHD, "UNICODE", "CHARACTER SET charset_name");
            warn_about_deprecated_binary(YYTHD);
            if (!($$= mysqld_collation_get_by_name("ucs2_bin")))
              MYSQL_YYABORT;
          }
        | BINARY_SYM UNICODE_SYM
          {
            warn_about_deprecated_binary(YYTHD);
            push_deprecated_warn(YYTHD, "UNICODE", "CHARACTER SET charset_name");
            if (!($$= mysqld_collation_get_by_name("ucs2_bin")))
              my_error(ER_UNKNOWN_COLLATION, MYF(0), "ucs2_bin");
          }
        ;
```

#### 语义组：`character_set`

`character_set` 语义组用于解析 `CHAR SET` 或 `CHARSET`。

- 返回值类型：没有返回值
- Bison 语法如下：

```C++
character_set:
          CHAR_SYM SET_SYM
        | CHARSET
        ;
```

#### 语义组：`opt_bin_mod`

`opt_bin_mod` 语义组用于解析可选的 `BINARY` 关键字。

- 返回值类型：`bool` 类型（`is_not_empty`）
- Bison 语法如下：

```C++
opt_bin_mod:
          %empty { $$= false; }
        | BINARY_SYM {
            warn_about_deprecated_binary(YYTHD);
            $$= true;
          }
        ;
```

#### 语义组：`nchar`

`nchar` 语义组用于解析 `NCHAR` 或 `NATIONAL CHAR`。

- 返回值类型：没有返回值。
- Bison 语法如下：

```C++
nchar:
          NCHAR_SYM {}
        | NATIONAL_SYM CHAR_SYM {}
        ;
```

#### 语义组：`varchar`

`varchar` 语义组用于解析 `CHAR VARYING` 或 `VARCHAR` 关键字。

- 返回值类型：没有返回值。
- Bison 语法如下：

```C++
varchar:
          CHAR_SYM VARYING {}
        | VARCHAR_SYM {}
        ;
```

#### 语义组：`nvarchar`

`nvarchar` 语义组用于解析 `NATIONAL VARCHAR`、`NVARCHAR`、`NCHAR VARCHAR`、`NATIONAL CHAR VARYING` 或`NCHAR VARYING` 关键字。

- 返回值类型：没有返回值。
- Bison 语法如下：

```C++
nvarchar:
          NATIONAL_SYM VARCHAR_SYM {}
        | NVARCHAR_SYM {}
        | NCHAR_SYM VARCHAR_SYM {}
        | NATIONAL_SYM CHAR_SYM VARYING {}
        | NCHAR_SYM VARYING {}
        ;
```

#### 语义组：`type_datetime_precision`

`type_datetime_precision` 语义组用于解析可选时间精度参数括号。

- 返回值类型：`const char`（`c_str`）
- Bison 语法如下：

```C++
type_datetime_precision:
          %empty { $$= nullptr; }
        | '(' NUM ')'                { $$= $2.str; }
        ;
```

#### 语义组：`spatial_type`

`spatial_type` 语义组用于解析 `GEOMETRY`、`GEOMETRYCOLLECTION`、`POINT`、`MULTIPOINT`、`LINESTRING`、`MULTILINESTRING`、`POLYGON` 或 `MULTIPOLYGON` 类型关键字。

- 返回值类型：`PT_type` 对象（`type`）
- Bison 语法如下：

```C++
spatial_type:
          GEOMETRY_SYM
          { $$= NEW_PTN PT_spacial_type(@$, Field::GEOM_GEOMETRY); }
        | GEOMETRYCOLLECTION_SYM
          { $$= NEW_PTN PT_spacial_type(@$, Field::GEOM_GEOMETRYCOLLECTION); }
        | POINT_SYM
          { $$= NEW_PTN PT_spacial_type(@$, Field::GEOM_POINT); }
        | MULTIPOINT_SYM
          { $$= NEW_PTN PT_spacial_type(@$, Field::GEOM_MULTIPOINT); }
        | LINESTRING_SYM
          { $$= NEW_PTN PT_spacial_type(@$, Field::GEOM_LINESTRING); }
        | MULTILINESTRING_SYM
          { $$= NEW_PTN PT_spacial_type(@$, Field::GEOM_MULTILINESTRING); }
        | POLYGON_SYM
          { $$= NEW_PTN PT_spacial_type(@$, Field::GEOM_POLYGON); }
        | MULTIPOLYGON_SYM
          { $$= NEW_PTN PT_spacial_type(@$, Field::GEOM_MULTIPOLYGON); }
        ;
```
