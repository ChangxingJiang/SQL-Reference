目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

下面我们梳理 `INTO` 子句，`INTO` 子句用于将查询结果存储到变量或写入到文件。其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析 - 029 - INTO 子句](C:\blog\graph\MySQL源码剖析\语法解析 - 029 - INTO 子句.png)

#### 语义组：`into_clause`

`into_clause` 语义组用于解析 `INTO` 子句。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)；[MySQL 参考手册 - 15.2.13.1 SELECT ... INTO Statement](https://dev.mysql.com/doc/refman/8.0/en/select-into.html)
- 标准语法：

```
into_option: {
    INTO OUTFILE 'file_name'
        [CHARACTER SET charset_name]
        export_options
  | INTO DUMPFILE 'file_name'
  | INTO var_name [, var_name] ...
}
```

- 返回值类型：`PT_into_destination` 对象（`into_destination`）
- 使用场景：查询表达式（`query_specification` 语义组），`SELECT` 表达式（`select_stmt_with_into`）语义组
- Bison 语法如下：

```C++
into_clause:
          INTO into_destination
          {
            $$= $2;
          }
        ;
```

#### 语义组：`into_destination`

`into_destination` 语义组用于解析 `INTO` 子句中 `INTO` 关键字之后的部分。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)；[MySQL 参考手册 - 15.2.13.1 SELECT ... INTO Statement](https://dev.mysql.com/doc/refman/8.0/en/select-into.html)
- 标准语法：

```
  OUTFILE 'file_name'
      [CHARACTER SET charset_name]
      export_options
| DUMPFILE 'file_name'
| var_name [, var_name] ...
```

- 返回值类型：`PT_into_destination` 对象（`into_destination`）
- 备选规则和 Bison 语法如下：

| 备选规则                                                     | 规则含义                                                     |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| `OUTFILE TEXT_STRING_filesystem opt_load_data_charset opt_field_term opt_line_term` | 将查询到的行写出到文件，可以指定列终止符和行终止符以生成特定的输出格式 |
| `DUMPFILE TEXT_STRING_filesystem`                            | 将单个行写入文件而不进行任何格式化                           |
| `select_var_list`                                            | 选择列值并将它们存储到变量中                                 |

```C++
into_destination:
          OUTFILE TEXT_STRING_filesystem
          opt_load_data_charset
          opt_field_term opt_line_term
          {
            $$= NEW_PTN PT_into_destination_outfile(@$, $2, $3, $4, $5);
          }
        | DUMPFILE TEXT_STRING_filesystem
          {
            $$= NEW_PTN PT_into_destination_dumpfile(@$, $2);
          }
        | select_var_list { $$= $1; }
        ;
```

> `TEXT_STRING_filesystem` 语义组用于解析作为文件系统路径的单引号 / 双引号字符串，详见 [MySQL 源码｜65 - 语法解析(V2)：字符串字面值](https://zhuanlan.zhihu.com/p/717934287)；
>
> `opt_load_data_charset` 语义组用于解析可选的指定字符集子句，详见下文；
>
> `opt_field_term` 语义组用于解析写出到文件的列配置信息，包括 `TERMINATED BY`、`OPTIONALLY ENCLOSED BY`、`ENCLOSED BY`、`ESCAPED BY`，详见下文；
>
> `opt_line_term` 语义组用于解析析出到文件的行配置信息，包括 `TERMINATED BY`、`STARTING BY`，详见下文；
>
> `select_var_list` 语义组用于解析任意数量、逗号分隔的变量的列表，详见下文。

#### 语义组：`opt_load_data_charset`

`opt_load_data_charset` 语义组用于解析可选的指定字符集子句。

- 标准语法：`[CHARACTER SET charset_name]`
- 返回值类型：`CHARSET_INFO` 结构体（`lexer.charset`）
- Bison 语法如下：

```C++
opt_load_data_charset:
          %empty { $$= nullptr; }
        | character_set charset_name { $$ = $2; }
        ;
```

> `character_set` 语义组用于解析 `CHAR SET` 或 `CHARSET`，详见 [MySQL 源码｜73 - 语法解析(V2)：数据类型（type）](https://zhuanlan.zhihu.com/p/719867311)；
>
> `charset_name` 语义组用于解析字符集名称，详见 [MySQL 源码｜43 - 语法解析(V2)：关键字函数](https://zhuanlan.zhihu.com/p/714784157)。

#### 语义组：`opt_field_term`

`opt_field_term` 语义组用于解析写出到文件的列配置信息，包括 `TERMINATED BY`、`OPTIONALLY ENCLOSED BY`、`ENCLOSED BY`、`ESCAPED BY`。

- 返回值类型：`Field_separators` 结构体（`field_separators`），其中包含字段名（`field_term`）、需转移的字符（`escaped`）、括号字符（`enclosed`），可选的括号字符（`opt_enclosed`）这 4 个属性
- Bison 语法如下：

```C++
opt_field_term:
          %empty { $$.cleanup(); }
        | COLUMNS field_term_list { $$= $2; }
        ;
```

#### 语义组：`field_term_list`

`field_term_list` 语义组用于解析空格分隔的、任意数量的 `TERMINATED BY`、`OPTIONALLY ENCLOSED BY`、`ENCLOSED BY` 或 `ESCAPED BY` 导出文件的列配置信息。

- 返回值类型：`Field_separators` 结构体（`field_separators`）
- Bison 语法如下：

```C++
field_term_list:
          field_term_list field_term
          {
            $$= $1;
            $$.merge_field_separators($2);
          }
        | field_term
        ;
```

#### 语义组：`field_term`

`field_term` 语义组用于解析 `TERMINATED BY`、`OPTIONALLY ENCLOSED BY`、`ENCLOSED BY` 或`ESCAPED BY` 导出文件的列配置信息。

- 返回值类型：`Field_separators` 结构体（`field_separators`）
- Bison 语法如下：

```C++
field_term:
          TERMINATED BY text_string
          {
            $$.cleanup();
            $$.field_term= $3;
          }
        | OPTIONALLY ENCLOSED BY text_string
          {
            $$.cleanup();
            $$.enclosed= $4;
            $$.opt_enclosed= 1;
          }
        | ENCLOSED BY text_string
          {
            $$.cleanup();
            $$.enclosed= $3;
          }
        | ESCAPED BY text_string
          {
            $$.cleanup();
            $$.escaped= $3;
          }
        ;
```

> `text_string` 语义组用于解析单引号 / 双引号字符串、十六进制数或二进制数，详见 [MySQL 源码｜65 - 语法解析(V2)：字符串字面值](https://zhuanlan.zhihu.com/p/717934287)。

#### 语义组：`opt_line_term`

`opt_line_term` 语义组用于解析写出到文件的行配置信息，包括 `TERMINATED BY`、`STARTING BY`。

- 返回值类型：`Line_separators` 结构体（`line_separators`），包括行结束符（`line_term`）和行起始符（`line_start`）这 2 个属性
- Bison 语法如下：

```C++
opt_line_term:
          %empty { $$.cleanup(); }
        | LINES line_term_list { $$= $2; }
        ;
```

#### 语义组：`line_term_list`

`line_term_list` 语义组用于解析空格分隔的、任意数量的 `TERMINATED BY` 或 `STARTING BY` 导出文件的行配置信息。

- 返回值类型：`Line_separators` 结构体（`line_separators`）
- Bison 语法如下：

```C++
line_term_list:
          line_term_list line_term
          {
            $$= $1;
            $$.merge_line_separators($2);
          }
        | line_term
        ;
```

#### 语义组：`line_term`

`line_term` 语义组用于解析 `TERMINATED BY` 或 `STARTING BY` 导出文件的行配置信息。

- 返回值类型：`Line_separators` 结构体（`line_separators`）
- Bison 语法如下：

```C++
line_term:
          TERMINATED BY text_string
          {
            $$.cleanup();
            $$.line_term= $3;
          }
        | STARTING BY text_string
          {
            $$.cleanup();
            $$.line_start= $3;
          }
        ;
```

#### 语义组：`select_var_list`

`select_var_list` 语义组用于解析任意数量、逗号分隔的变量的列表。

- 标准语法：`var_name [, var_name]`
- 返回值类型：`PT_select_var_list` 对象（`select_var_list`）
- Bison 语法如下：

```C++
select_var_list:
          select_var_list ',' select_var_ident
          {
            $$= $1;
            if ($$ == nullptr || $$->push_back($3))
              MYSQL_YYABORT;
          }
        | select_var_ident
          {
            $$= NEW_PTN PT_select_var_list(@$);
            if ($$ == nullptr || $$->push_back($1))
              MYSQL_YYABORT;
          }
        ;
```

#### 语义组：`select_var_ident`

`select_var_ident` 语义组用于解析单个变量。

- 返回值类型：`PT_select_var` 对象（`select_var_ident`）
- Bison 语法如下：

```C++
select_var_ident:
          '@' ident_or_text
          {
            $$= NEW_PTN PT_select_var(@$, $2);
          }
        | ident_or_text
          {
            $$= NEW_PTN PT_select_sp_var(@$, $1);
          }
        ;
```

> `ident_or_text` 语义组用于解析标识符、任意未保留关键字、单引号 / 双引号字符串或用户自定义变量，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)。