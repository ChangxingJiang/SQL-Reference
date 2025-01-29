目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

前置文档：

- [MySQL 源码｜65 - 语法解析(V2)：字符串字面值](https://zhuanlan.zhihu.com/p/717934287)

---

在基础表达式语义组 `simple_expr` 中，直接规定了类型转换函数 `CAST`、`CONVERT` 和关键字 `BINARY` 引导的类型转换语法的备选规则，这 3 个函数官方文档和标准语法详见 [MySQL 参考手册 - 14.10 Cast Functions and Operators](https://dev.mysql.com/doc/refman/8.4/en/cast-functions.html)。在梳理 `simple_expr` 语义组之前，我们先来梳理这 3 个函数，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析-015-CAST、CONVERT 函数和 BINARY 关键字-2](C:\blog\graph\MySQL源码剖析\语法解析-015-CAST、CONVERT 函数和 BINARY 关键字-2.png)

#### `simple_expr` 规则（部分）

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类。

与 `CAST` 函数、`CONVERT` 函数和 `BINARY` 关键字引导的类型转换语法相关的备选规则如下：

##### `BINARY` 关键字

`BINARY` 关键字用于将字符串转为二进制字符串。

官方文档：[MySQL 参考手册 - 14.10 Cast Functions and Operators](https://dev.mysql.com/doc/refman/8.4/en/cast-functions.html)

| 备选规则                 | 备选规则含义                   |
| ------------------------ | ------------------------------ |
| `BINARY_SYM simple_expr` | 用于解析标准语法 `BINARY expr` |

```C++
        | BINARY_SYM simple_expr %prec NEG
          {
            push_deprecated_warn(YYTHD, "BINARY expr", "CAST");
            $$= create_func_cast(YYTHD, @$, $2, ITEM_CAST_CHAR, &my_charset_bin);
            if ($$ == nullptr)
              MYSQL_YYABORT;
          }
```

##### `CAST` 函数

`CAST` 函数用于将一个值转换为一个确定的类型。

官方文档：[MySQL 参考手册 - 14.10 Cast Functions and Operators](https://dev.mysql.com/doc/refman/8.4/en/cast-functions.html)

| 备选规则                                                     | 备选规则含义                                                 |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| `CAST_SYM '(' expr AS cast_type opt_array_cast ')'`          | 用于解析标准语法 `CAST(expr AS type [ARRAY])`                |
| `CAST_SYM '(' expr AT_SYM LOCAL_SYM AS cast_type opt_array_cast ')'` | 用于解析标准语法  `CAST(expr AT LOCAT AS type [ARRAY])`      |
| `CAST_SYM '(' expr AT_SYM TIME_SYM ZONE_SYM opt_interval TEXT_STRING_literal AS DATETIME_SYM type_datetime_precision ')'` | 用于解析标准语法 `CAST(timestamp_value AT TIME ZONE timezone_specifier AS DATETIME[(precision)])` |

```C++
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
```

> 语义组 `TEXT_STRING_literal` 用于解析作为普通字面值使用的单引号 / 双引号字符串，详见 [MySQL 源码｜65 - 语法解析(V2)：字符串字面值](https://zhuanlan.zhihu.com/p/717934287)。

##### `CONVERT` 函数

`CONVERT` 函数用于将一个值转换为一个确定的类型。

官方文档：[MySQL 参考手册 - 14.10 Cast Functions and Operators](https://dev.mysql.com/doc/refman/8.4/en/cast-functions.html)

| 备选规则                                      | 备选规则含义                                             |
| --------------------------------------------- | -------------------------------------------------------- |
| `CONVERT_SYM '(' expr ',' cast_type ')'`      | 用于解析标准语法 `CONVERT(expr,type)`                    |
| `CONVERT_SYM '(' expr USING charset_name ')'` | 用于解析标准语法  `CONVERT(expr USING transcoding_name)` |

```C++
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
```

#### 语义组：`cast_type`

`cast_type` 语义组用于解析 `CAST` 函数指定的转换后的目标类型。

- 官方文档：[MySQL 参考手册 - 14.10 Cast Functions and Operators](https://dev.mysql.com/doc/refman/8.4/en/cast-functions.html)
- 返回值类型：`Cast_type` 结构体（`cast_type`）
- 备选规则和 Bison 语法：

| 备选规则                                                | 备选规则含义                                                 |
| ------------------------------------------------------- | ------------------------------------------------------------ |
| `BINARY_SYM opt_field_length`                           | 解析标准语法 `BINARY[(N)]`（长度不超过 N 的 `VARBINARY` 类型） |
| `CHAR_SYM opt_field_length opt_charset_with_opt_binary` | 解析标准语法 `CHAR[(N)] [charset_info]`（长度不超过 N 的 `VARCHAR` 类型） |
| `nchar opt_field_length`                                | 解析标准语法 `NCHAR[(N)]`（长度不超过 N 的国际字符集 `VARCHAR` 类型） |
| `SIGNED_SYM`                                            | 解析标准语法 `SIGNED`（有符号的 `BIGINT` 类型）              |
| `SIGNED_SYM INT_SYM`                                    | 解析标准语法 `SIGNED INT`（有符号的 `BIGINT` 类型）          |
| `UNSIGNED_SYM`                                          | 解析标准语法 `UNSIGNED`（无符号的 `BIGINT` 类型）            |
| `UNSIGNED_SYM INT_SYM`                                  | 解析标准语法 `UNSIGNED INT`（无符号的 `BIGINT` 类型）        |
| `DATE_SYM`                                              | 解析标准语法 `DATE`（`DATE` 类型）                           |
| `YEAR_SYM`                                              | 解析标准语法 `YEAR`（`YEAR` 类型）                           |
| `TIME_SYM type_datetime_precision`                      | 解析标准语法 `TIME[(M)]`（以 M 为秒的小数位精度的 `TIME` 类型） |
| `DATETIME_SYM type_datetime_precision`                  | 解析标准语法 `DATETIME[(M)]`（以 M 为秒的小数位精度的 `DATETIME` 类型） |
| `DECIMAL_SYM float_options`                             | 解析标准语法 `DECIMAL[(M[,D])]`（保留 M 位精度和 D 位小数的 `DECIMAL` 类型） |
| `JSON_SYM`                                              | 解析标准语法 `JSON`（`JSON` 类型）                           |
| `REAL_SYM`（来自 `real_type` 语义组）                   | 解析标准语法 `REAL`（如果开启 `REAL_AS_FLOAT` 模式则为 `FLOAT` 类型，否则为 `DOUBLE` 类型） |
| `DOUBLE_SYM opt_PRECISION`（来自 `real_type` 语义组）   | 解析标准语法 `DOUBLE [PRECISION]`（`DOUBLE` 类型）           |
| `FLOAT_SYM standard_float_options`                      | 解析标准语法 `FLOAT[(p)]`（如果没有指定 p 或 0 <= p <= 24，则为 `FLOAT` 类型；如果 25 <= p <= 53，则为 `DOUBLE` 类型；否则抛出异常） |
| `POINT_SYM`                                             | （`Point` 类型）                                             |
| `LINESTRING_SYM`                                        | （`LineString` 类型）                                        |
| `POLYGON_SYM`                                           | （`Polygon` 类型）                                           |
| `MULTIPOINT_SYM`                                        | （`MultiPoint` 类型）                                        |
| `MULTILINESTRING_SYM`                                   | （`MultiLineString` 类型）                                   |
| `MULTIPOLYGON_SYM`                                      | （`MultiPolygon` 类型）                                      |
| `GEOMETRYCOLLECTION_SYM`                                | （`GeometryCollection` 类型）                                |

```C++
cast_type:
          BINARY_SYM opt_field_length
          {
            $$.target= ITEM_CAST_CHAR;
            $$.charset= &my_charset_bin;
            $$.length= $2;
            $$.dec= nullptr;
          }
        | CHAR_SYM opt_field_length opt_charset_with_opt_binary
          {
            $$.target= ITEM_CAST_CHAR;
            $$.length= $2;
            $$.dec= nullptr;
            if ($3.force_binary)
            {
              // Bugfix: before this patch we ignored [undocumented]
              // collation modifier in the CAST(expr, CHAR(...) BINARY) syntax.
              // To restore old behavior just remove this "if ($3...)" branch.

              $$.charset= get_bin_collation($3.charset ? $3.charset :
                  YYTHD->variables.collation_connection);
              if ($$.charset == nullptr)
                MYSQL_YYABORT;
            }
            else
              $$.charset= $3.charset;
          }
        | nchar opt_field_length
          {
            $$.target= ITEM_CAST_CHAR;
            $$.charset= national_charset_info;
            $$.length= $2;
            $$.dec= nullptr;
            warn_about_deprecated_national(YYTHD);
          }
        | SIGNED_SYM
          {
            $$.target= ITEM_CAST_SIGNED_INT;
            $$.charset= nullptr;
            $$.length= nullptr;
            $$.dec= nullptr;
          }
        | SIGNED_SYM INT_SYM
          {
            $$.target= ITEM_CAST_SIGNED_INT;
            $$.charset= nullptr;
            $$.length= nullptr;
            $$.dec= nullptr;
          }
        | UNSIGNED_SYM
          {
            $$.target= ITEM_CAST_UNSIGNED_INT;
            $$.charset= nullptr;
            $$.length= nullptr;
            $$.dec= nullptr;
          }
        | UNSIGNED_SYM INT_SYM
          {
            $$.target= ITEM_CAST_UNSIGNED_INT;
            $$.charset= nullptr;
            $$.length= nullptr;
            $$.dec= nullptr;
          }
        | DATE_SYM
          {
            $$.target= ITEM_CAST_DATE;
            $$.charset= nullptr;
            $$.length= nullptr;
            $$.dec= nullptr;
          }
        | YEAR_SYM
          {
            $$.target= ITEM_CAST_YEAR;
            $$.charset= nullptr;
            $$.length= nullptr;
            $$.dec= nullptr;
          }
        | TIME_SYM type_datetime_precision
          {
            $$.target= ITEM_CAST_TIME;
            $$.charset= nullptr;
            $$.length= nullptr;
            $$.dec= $2;
          }
        | DATETIME_SYM type_datetime_precision
          {
            $$.target= ITEM_CAST_DATETIME;
            $$.charset= nullptr;
            $$.length= nullptr;
            $$.dec= $2;
          }
        | DECIMAL_SYM float_options
          {
            $$.target=ITEM_CAST_DECIMAL;
            $$.charset= nullptr;
            $$.length= $2.length;
            $$.dec= $2.dec;
          }
        | JSON_SYM
          {
            $$.target=ITEM_CAST_JSON;
            $$.charset= nullptr;
            $$.length= nullptr;
            $$.dec= nullptr;
          }
        | real_type
          {
            $$.target = ($1 == Numeric_type::DOUBLE) ?
              ITEM_CAST_DOUBLE : ITEM_CAST_FLOAT;
            $$.charset = nullptr;
            $$.length = nullptr;
            $$.dec = nullptr;
          }
        | FLOAT_SYM standard_float_options
          {
            $$.target = ITEM_CAST_FLOAT;
            $$.charset = nullptr;
            $$.length = $2.length;
            $$.dec = nullptr;
          }
        | POINT_SYM
          {
            $$.target = ITEM_CAST_POINT;
            $$.charset = nullptr;
            $$.length = nullptr;
            $$.dec = nullptr;
          }
        | LINESTRING_SYM
          {
            $$.target = ITEM_CAST_LINESTRING;
            $$.charset = nullptr;
            $$.length = nullptr;
            $$.dec = nullptr;
          }
        | POLYGON_SYM
          {
            $$.target = ITEM_CAST_POLYGON;
            $$.charset = nullptr;
            $$.length = nullptr;
            $$.dec = nullptr;
          }
        | MULTIPOINT_SYM
          {
            $$.target = ITEM_CAST_MULTIPOINT;
            $$.charset = nullptr;
            $$.length = nullptr;
            $$.dec = nullptr;
          }
        | MULTILINESTRING_SYM
          {
            $$.target = ITEM_CAST_MULTILINESTRING;
            $$.charset = nullptr;
            $$.length = nullptr;
            $$.dec = nullptr;
          }
        | MULTIPOLYGON_SYM
          {
            $$.target = ITEM_CAST_MULTIPOLYGON;
            $$.charset = nullptr;
            $$.length = nullptr;
            $$.dec = nullptr;
          }
        | GEOMETRYCOLLECTION_SYM
          {
            $$.target = ITEM_CAST_GEOMETRYCOLLECTION;
            $$.charset = nullptr;
            $$.length = nullptr;
            $$.dec = nullptr;
          }
        ;
```

> `opt_field_length` 语义组用于解析可选的字符型字段的最大长度，详见 [MySQL 源码｜73 - 语法解析(V2)：数据类型（type）](https://zhuanlan.zhihu.com/p/719867311)；
>
> `opt_charset_with_opt_binary` 语义组用于解析可选的编码类型，详见 [MySQL 源码｜73 - 语法解析(V2)：数据类型（type）](https://zhuanlan.zhihu.com/p/719867311)；
>
> `type_datetime_precision` 语义组用于解析可选时间精度参数括号，详见 [MySQL 源码｜73 - 语法解析(V2)：数据类型（type）](https://zhuanlan.zhihu.com/p/719867311)；
>
> `float_options` 语义组用于解析可选的小数精度，详见 [MySQL 源码｜73 - 语法解析(V2)：数据类型（type）](https://zhuanlan.zhihu.com/p/719867311)；
>
> `opt_PRECISION` 语义组用于解析可选的 `PRECISION` 关键字，详见 [MySQL 源码｜73 - 语法解析(V2)：数据类型（type）](https://zhuanlan.zhihu.com/p/719867311)；
>
> `standard_float_options` 语义组用于解析可选的浮点数精度，详见下文。

#### 语义组：`opt_array_cast`

`opt_array_cast` 语义组用于解析可选的 `ARRAY` 关键字。

- 返回值类型：`int` 类型（`num`）
- Bison 语法如下：

```C++
opt_array_cast:
          %empty { $$= false; }
        | ARRAY_SYM { $$= true; }
        ;
```

#### 语义组：`opt_interval`

`opt_interval` 语义组用于解析可选的 `INTERVAL` 关键字。

- 返回值类型：`bool` 类型（`is_not_empty`）
- Bison 语法如下：

```C++
opt_interval:
          %empty        { $$ = false; }
        | INTERVAL_SYM  { $$ = true; }
        ;
```

#### 语义组：`standard_float_options`

`standard_float_options` 语义组用于解析可选的浮点数精度。

- 返回值类型：`precision` 结构体，其中包含长度和小数位
- Bison 语法如下：

```C++
standard_float_options:
          %empty
          {
            $$.length = nullptr;
            $$.dec = nullptr;
          }
        | field_length
          {
            $$.length = $1;
            $$.dec = nullptr;
          }
        ;
```

