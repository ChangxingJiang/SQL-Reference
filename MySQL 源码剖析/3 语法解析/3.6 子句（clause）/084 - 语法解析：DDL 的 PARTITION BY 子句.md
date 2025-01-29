目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

下面梳理用于解析 `PARTITION BY` 子句的 `partition_clause` 语义组，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析 - 041 - PARTITION BY 子句](C:\blog\graph\MySQL源码剖析\语法解析 - 041 - PARTITION BY 子句.png)

#### 语义组：`partition_clause`

`partition_clause` 语义组用于解析 `PARTITION BY` 子句。

- 官方文档：[MySQL 参考手册 - 26.1 Overview of Partitioning in MySQL](https://dev.mysql.com/doc/refman/8.4/en/partitioning-overview.html)
- 返回值类型：`PT_partition` 对象
- 使用场景：`CREATE TABLE` 语句，`ALTER TABLE` 语句
- Bison 语法如下：

```C++
partition_clause:
          PARTITION_SYM BY part_type_def opt_num_parts opt_sub_part
          opt_part_defs
          {
            $$= NEW_PTN PT_partition(@$, $3, $4, $5, @6, $6);
          }
        ;
```

> `part_type_def` 语义组用于解析 `PARTITION BY` 语句中的分区类型，详见下文；
>
> `opt_num_parts` 语义组用于解析 `PARTITION BY` 子句中可选的指定分区数量部分，即 `PARTITIONS` 关键字引导的数字，详见下文；
>
> `opt_sub_part` 语义组用于解析 `PARTITION BY` 子句中可选的指定子分区部分，即 `SUBPARTITION` 关键字引导的子句，详见下文；
>
> `opt_part_defs` 语义组用于解析 `PARTITION BY` 子句中可选的各分区设置信息的部分，在 Range Partition 分区类型和 List Partition 分区类型中需要，详见下文；

#### 语义组：`part_type_def`

`part_type_def` 语义组用于解析 `PARTITION BY` 语句中的分区类型。

- 官方文档：[MySQL 参考手册 - 26.2 Partitioning Types](https://dev.mysql.com/doc/refman/8.4/en/partitioning-types.html)
- 返回值类型：`PT_part_type_def` 对象
- 备选规则和 Bison 语法如下：

| 备选规则                               | 规则含义                                                     |
| -------------------------------------- | ------------------------------------------------------------ |
| `opt_linear KEY_SYM opt_key_algo`      | 解析 Key Partition 分区类型。使用 Key Partition 分区时，只需要提供一个或多个分区字段（可以包含非整数值），由 MySQL 服务器提供哈希函数计算哈希计算。 |
| `opt_linear HASH_SYM '(' bit_expr ')'` | 解析 Hash Partition 分区类型。使用 Hash Partition 分区时，需要提供一个能够返回整数值的表达式。 |
| `RANGE_SYM '(' bit_expr ')'`           | 解析 Range 分区类型，这种分区方式根据列值是否落在给定的范围来将行分配到各个分区。 |
| `RANGE_SYM COLUMNS '(' name_list ')'`  | 解析 Range 分区类型，这种分区方式根据列值是否落在给定的范围来将行分配到各个分区。 |
| `LIST_SYM '(' bit_expr ')'`            | 解析 List 分区类型，这种分区方式根据列值是否落在给定离散值中来将行分配到各个分区。 |
| `LIST_SYM COLUMNS '(' name_list ')'`   | 解析 List 分区类型，这种分区方式根据列值是否落在给定离散值中来将行分配到各个分区。 |

```C++
          opt_linear KEY_SYM opt_key_algo '(' opt_name_list ')'
          {
            $$= NEW_PTN PT_part_type_def_key(@$, $1, $3, $5);
          }
        | opt_linear HASH_SYM '(' bit_expr ')'
          {
            $$= NEW_PTN PT_part_type_def_hash(@$, $1, @4, $4);
          }
        | RANGE_SYM '(' bit_expr ')'
          {
            $$= NEW_PTN PT_part_type_def_range_expr(@$, @3, $3);
          }
        | RANGE_SYM COLUMNS '(' name_list ')'
          {
            $$= NEW_PTN PT_part_type_def_range_columns(@$, $4);
          }
        | LIST_SYM '(' bit_expr ')'
          {
            $$= NEW_PTN PT_part_type_def_list_expr(@$, @3, $3);
          }
        | LIST_SYM COLUMNS '(' name_list ')'
          {
            $$= NEW_PTN PT_part_type_def_list_columns(@$, $4);
          }
        ;
```

> `opt_linear` 语义组用于解析可选的 `LINEAR` 关键字，详见下文；
>
> `opt_key_algo` 语义组用于解析可选的 `PARTITION BY` 子句 Key Partition 分区的指定哈希算法子句，即可选的 `ALGORITHM = algorithm`，详见下文；
>
> `opt_name_list` 语义组用于解析可选的任意数量、逗号分隔的标识符的列表，详见下文；
>
> `bit_expr` 语义组用于解析 “位表达式”，即在简单表达式（simple_expr）的基础上使用各种数值类二元运算符进行计算的表达式，详见 [MySQL 源码｜69 - 语法解析(V2)：位表达式（bit_expr）](https://zhuanlan.zhihu.com/p/719439177)；
>
> `name_list` 语义组用于解析任意数量、逗号分隔的标识符的列表，详见下文；

#### 语义组：`opt_linear`

`opt_linear` 语义组用于解析可选的 `LINEAR` 关键字。

- 返回值类型：`bool` 类型（`is_not_empty`）
- Bison 语法如下：

```C++
opt_linear:
          %empty { $$= false; }
        | LINEAR_SYM  { $$= true; }
        ;
```

#### 语义组：`opt_key_algo`

`opt_key_algo` 语义组用于解析可选的 `PARTITION BY` 子句 Key Partition 分区的指定哈希算法子句，即可选的 `ALGORITHM = algorithm`。

- 返回值类型：`enum_key_algorithm` 枚举类型，包含 `KEY_ALGORITHM_NONE`、`KEY_ALGORITHM_51` 和 `KEY_ALGORITHM_55` 这 3 个枚举值
- Bison 语法如下：

```C++
opt_key_algo:
          %empty { $$= enum_key_algorithm::KEY_ALGORITHM_NONE; }
        | ALGORITHM_SYM EQ real_ulong_num
          {
            switch ($3) {
            case 1:
              $$= enum_key_algorithm::KEY_ALGORITHM_51;
              break;
            case 2:
              $$= enum_key_algorithm::KEY_ALGORITHM_55;
              break;
            default:
              YYTHD->syntax_error();
              MYSQL_YYABORT;
            }
          }
        ;
```

> `real_ulong_num` 语义组用于解析十进制整数和十六进制数（转换为十进制数），返回 unsigned long 类型；如果输入十进制小数或超出范围的十进制整数，则抛出异常，详见 [MySQL 源码｜67 - 语法解析(V2)：数值字面值](https://zhuanlan.zhihu.com/p/718508554)。

#### 语义组：`name_list`

`name_list` 语义组用于解析任意数量、逗号分隔的标识符的列表。

- 返回值类型：`List<char>` 类型
- Bison 语法如下：

```C++
name_list:
          ident
          {
            $$= NEW_PTN List<char>;
            if ($$ == nullptr || $$->push_back($1.str))
              MYSQL_YYABORT;
          }
        | name_list ',' ident
          {
            $$= $1;
            if ($$->push_back($3.str))
              MYSQL_YYABORT;
          }
        ;
```

> `ident` 语义组用于解析标识符或任意未保留关键字，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)。

#### 语义组：`opt_name_list`

`opt_name_list` 语义组用于解析可选的任意数量、逗号分隔的标识符的列表。

- 返回值类型：`List<char>` 类型
- Bison 语法如下：

```C++
opt_name_list:
          %empty { $$= nullptr; }
        | name_list
        ;
```

#### 语义组：`opt_num_parts`

`opt_num_parts` 语义组用于解析 `PARTITION BY` 子句中可选的指定分区数量部分，即 `PARTITIONS` 关键字引导的数字。

- 返回值类型：`unsigned long` 类型
- Bison 语法如下：

```C++
opt_num_parts:
          %empty { $$= 0; }
        | PARTITIONS_SYM real_ulong_num
          {
            if ($2 == 0)
            {
              my_error(ER_NO_PARTS_ERROR, MYF(0), "partitions");
              MYSQL_YYABORT;
            }
            $$= $2;
          }
        ;
```

> `real_ulong_num` 语义组用于解析十进制整数和十六进制数（转换为十进制数），返回 unsigned long 类型；如果输入十进制小数或超出范围的十进制整数，则抛出异常，详见 [MySQL 源码｜67 - 语法解析(V2)：数值字面值](https://zhuanlan.zhihu.com/p/718508554)。

#### 语义组：`opt_sub_part`

`opt_sub_part` 语义组用于解析 `PARTITION BY` 子句中可选的指定子分区部分，即 `SUBPARTITION` 关键字引导的子句。

- 官方文档：[MySQL 参考手册 - 26.2.6 Subpartitioning](https://dev.mysql.com/doc/refman/8.4/en/partitioning-subpartitions.html)
- 返回值类型：`PT_sub_partition` 对象
- 使用场景：Key Partition 分区类型和 Hash Partition 分区类型
- Bison 语法如下：

```C++
opt_sub_part:
          %empty { $$= nullptr; }
        | SUBPARTITION_SYM BY opt_linear HASH_SYM '(' bit_expr ')'
          opt_num_subparts
          {
            $$= NEW_PTN PT_sub_partition_by_hash(@$, $3, @6, $6, $8);
          }
        | SUBPARTITION_SYM BY opt_linear KEY_SYM opt_key_algo
          '(' name_list ')' opt_num_subparts
          {
            $$= NEW_PTN PT_sub_partition_by_key(@$, $3, $5, $7, $9);
          }
        ;
```

> `opt_linear` 语义组用于解析可选的 `LINEAR` 关键字，详见上文；
>
> `bit_expr` 语义组用于解析 “位表达式”，即在简单表达式（simple_expr）的基础上使用各种数值类二元运算符进行计算的表达式，详见 [MySQL 源码｜69 - 语法解析(V2)：位表达式（bit_expr）](https://zhuanlan.zhihu.com/p/719439177)；
>
> `opt_num_subparts` 语义组
>
> `opt_key_algo` 语义组用于解析可选的 `PARTITION BY` 子句 Key Partition 分区的指定哈希算法子句，即可选的 `ALGORITHM = algorithm`，详见上文；
>
> `name_list` 语义组用于解析任意数量、逗号分隔的标识符的列表，详见上文。

#### 语义组：`opt_num_subparts`

`opt_num_parts` 语义组用于解析 `PARTITION BY` 子句中可选的指定 **子分区数量** 部分，即 `SUBPARTITIONS` 关键字引导的数字。

- 返回值类型：`unsigned long` 类型
- Bison 语法如下：

```C++
opt_num_subparts:
          %empty { $$= 0; }
        | SUBPARTITIONS_SYM real_ulong_num
          {
            if ($2 == 0)
            {
              my_error(ER_NO_PARTS_ERROR, MYF(0), "subpartitions");
              MYSQL_YYABORT;
            }
            $$= $2;
          }
        ;
```

> `real_ulong_num` 语义组用于解析十进制整数和十六进制数（转换为十进制数），返回 unsigned long 类型；如果输入十进制小数或超出范围的十进制整数，则抛出异常，详见 [MySQL 源码｜67 - 语法解析(V2)：数值字面值](https://zhuanlan.zhihu.com/p/718508554)。

#### 语义组：`opt_part_defs`

`opt_part_defs` 语义组用于解析 `PARTITION BY` 子句中可选的各分区设置信息的部分，在 Range Partition 分区类型和 List Partition 分区类型中需要。

- 返回值类型：`Mem_root_array<PT_part_definition *>` 对象
- Bison 语法如下：

```C++
opt_part_defs:
          %empty { $$= nullptr; }
        | '(' part_def_list ')' { $$= $2; }
        ;
```

#### 语义组：`part_def_list`

`part_def_list` 语义组用于解析 `PARTITION BY` 子句中大于等于一个、逗号分隔的分区设置信息。

- 返回值类型：`Mem_root_array<PT_part_definition *>` 对象
- Bison 语法如下：

```C++
part_def_list:
          part_definition
          {
            $$= NEW_PTN Mem_root_array<PT_part_definition*>(YYMEM_ROOT);
            if ($$ == nullptr || $$->push_back($1))
              MYSQL_YYABORT; // OOM
          }
        | part_def_list ',' part_definition
          {
            $$= $1;
            if ($$->push_back($3))
              MYSQL_YYABORT; // OOM
          }
        ;
```

#### 语义组：`part_definition`

`part_def_list` 语义组用于解析 `PARTITION BY` 子句中的一个分区设置信息。

- 返回值类型：`PT_part_definition` 对象
- Bison 语法如下：

```C++
part_definition:
          PARTITION_SYM ident opt_part_values opt_part_options opt_sub_partition
          {
            $$= NEW_PTN PT_part_definition(@$, @0, $2, $3.type, $3.values, @3,
                                           $4, $5, @5);
          }
        ;
```

> `ident` 语义组用于解析标识符或任意未保留关键字，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)；
>
> `opt_part_values` 语义组用于解析 `PARTITION BY` 子句中可选的分区取值范围，详见下文；
>
> `opt_part_options` 语义组用于解析 `PARTITION BY` 子句中的可选的、任意数量、空格分隔的分区选项，详见下文；
>
> `opt_sub_partition` 语义组用于解析可选的子、括号框柱的、任意数量、逗号分隔的子定义语句，详见下文。

#### 语义组：`opt_part_values`

`opt_part_values` 语义组用于解析 `PARTITION BY` 子句中可选的单个分区的取值范围。

- 返回值类型：`opt_part_values` 结构体，其中包括 `partition_type` 类型的成员 `type` 和 `PT_part_values` 类型的成员 `value`
- Bison 语法如下：

```C++
opt_part_values:
          %empty
          {
            $$.type= partition_type::HASH;
          }
        | VALUES LESS_SYM THAN_SYM part_func_max
          {
            $$.type= partition_type::RANGE;
            $$.values= $4;
          }
        | VALUES IN_SYM part_values_in
          {
            $$.type= partition_type::LIST;
            $$.values= $3;
          }
        ;
```

> `part_func_max` 语义组用于解析 `PARTITION BY` 子句中单个分区的取值范围的最大值，详见下文；
>
> `part_values_in` 语义组用于解析 `PARTITION BY` 子句中被括号框柱的、分区内可选值的列表，详见下文；

#### 语义组：`part_func_max`

`part_func_max` 语义组用于解析 `PARTITION BY` 子句中单个分区的取值范围的最大值，可能是 `MAV_VALUE` 关键字或每个分区键的值的列表。

- 返回值类型：`PT_part_value_item_list_paren` 对象
- Bison 语法如下：

```C++
part_func_max:
          MAX_VALUE_SYM   { $$= nullptr; }
        | part_value_item_list_paren
        ;
```

#### 语义组：`part_value_item_list_paren`

`part_value_item_list_paren` 语义组用于解析 `PARTITION BY` 子句中单个分区的取值范围的一个边界值，即括号框柱的每个分区键的值的列表。

- 返回值类型：`PT_part_value_item_list_paren` 对象
- Bison 语法如下：

```C++
part_value_item_list_paren:
          '('
          {
            /*
              This empty action is required because it resolves 2 reduce/reduce
              conflicts with an anonymous row expression:

              simple_expr:
                        ...
                      | '(' expr ',' expr_list ')'
            */
          }
          part_value_item_list ')'
          {
            $$= NEW_PTN PT_part_value_item_list_paren(@$, $3, @4);
          }
        ;
```

#### 语义组：`part_value_item_list`

`part_value_item_list` 语义组用于解析 `PARTITION BY` 子句中单个分区的取值范围中，每个分区键的值的列表。

- 返回值类型：`Mem_root_array<PT_part_value_item *>` 对象
- Bison 语法如下：

```C++
part_value_item_list:
          part_value_item
          {
            $$= NEW_PTN Mem_root_array<PT_part_value_item *>(YYMEM_ROOT);
            if ($$ == nullptr || $$->push_back($1))
              MYSQL_YYABORT; // OOM
          }
        | part_value_item_list ',' part_value_item
          {
            $$= $1;
            if ($$->push_back($3))
              MYSQL_YYABORT; // OOM
          }
        ;
```

#### 语义组：`part_value_item`

`part_value_item` 语义组用于解析 `PARTITION BY` 子句中单个分区的取值范围中，单个分区键的值，可以是 `MAX_VALUE` 关键字或一个位表达式。

- 返回值类型：`PT_part_value_item` 对象
- Bison 语法如下：

```C++
part_value_item:
          MAX_VALUE_SYM { $$= NEW_PTN PT_part_value_item_max(@$); }
        | bit_expr      { $$= NEW_PTN PT_part_value_item_expr(@$, $1); }
        ;
```

> `bit_expr` 语义组用于解析 “位表达式”，即在简单表达式（simple_expr）的基础上使用各种数值类二元运算符进行计算的表达式，详见 [MySQL 源码｜69 - 语法解析(V2)：位表达式（bit_expr）](https://zhuanlan.zhihu.com/p/719439177)。

#### 语义组：`part_values_in`

`part_values_in` 语义组用于解析 `PARTITION BY` 子句中被括号框柱的、分区内可选值的列表。

- 返回值类型：`PT_part_values` 对象
- Bison 语法如下：

```C++
part_values_in:
          part_value_item_list_paren
          {
            $$= NEW_PTN PT_part_values_in_item(@$, @1, $1);
          }
        | '(' part_value_list ')'
          {
            $$= NEW_PTN PT_part_values_in_list(@$, @3, $2);
          }
        ;
```

> `part_value_item_list_paren` 语义组用于解析 `PARTITION BY` 子句中单个分区的取值范围的一个边界值，即括号框柱的每个分区键的值的列表，详见上文；
>
> `part_value_list` 语义组用于解析 `PARTITION BY` 子句中的分区内可选值的列表。

#### 语义组：`part_value_list`

`part_value_list` 语义组用于解析 `PARTITION BY` 子句中的分区内可选值的列表。

- 返回值类型：`Mem_root_array<PT_part_value_item_list_paren *>` 对象
- Bison 语法如下：

```C++
part_value_list:
          part_value_item_list_paren
          {
            $$= NEW_PTN
              Mem_root_array<PT_part_value_item_list_paren *>(YYMEM_ROOT);
            if ($$ == nullptr || $$->push_back($1))
              MYSQL_YYABORT; // OOM
          }
        | part_value_list ',' part_value_item_list_paren
          {
            $$= $1;
            if ($$->push_back($3))
              MYSQL_YYABORT; // OOM
          }
        ;
```

> `part_value_item_list_paren` 语义组用于解析 `PARTITION BY` 子句中单个分区的取值范围的一个边界值，即括号框柱的每个分区键的值的列表，详见上文。

#### 语义组：`opt_part_options`

`opt_part_options` 语义组用于解析 `PARTITION BY` 子句中的可选的、任意数量、空格分隔的分区选项。

- 返回值类型：`Mem_root_array<PT_partition_option *>` 对象
- Bison 语法如下：

```C++
opt_part_options:
         %empty { $$= nullptr; }
       | part_option_list
       ;
```

#### 语义组：`part_option_list`

`opt_part_options` 语义组用于解析 `PARTITION BY` 子句中的任意数量、空格分隔的分区选项。

- 返回值类型：`Mem_root_array<PT_partition_option *>` 对象
- Bison 语法如下：

```C++
part_option_list:
          part_option_list part_option
          {
            $$= $1;
            if ($$->push_back($2))
              MYSQL_YYABORT; // OOM
          }
        | part_option
          {
            $$= NEW_PTN Mem_root_array<PT_partition_option *>(YYMEM_ROOT);
            if ($$ == nullptr || $$->push_back($1))
              MYSQL_YYABORT; // OOM
          }
        ;
```

#### 语义组：`part_option`

`opt_part_options` 语义组用于解析 `PARTITION BY` 子句中的分区选项。

- 返回值类型：`PT_partition_option` 对象
- Bison 语法如下：

```C++
part_option:
          TABLESPACE_SYM opt_equal ident
          { $$= NEW_PTN PT_partition_tablespace(@$, $3.str); }
        | opt_storage ENGINE_SYM opt_equal ident_or_text
          { $$= NEW_PTN PT_partition_engine(@$, to_lex_cstring($4)); }
        | NODEGROUP_SYM opt_equal real_ulong_num
          { $$= NEW_PTN PT_partition_nodegroup(@$, $3); }
        | MAX_ROWS opt_equal real_ulonglong_num
          { $$= NEW_PTN PT_partition_max_rows(@$, $3); }
        | MIN_ROWS opt_equal real_ulonglong_num
          { $$= NEW_PTN PT_partition_min_rows(@$, $3); }
        | DATA_SYM DIRECTORY_SYM opt_equal TEXT_STRING_sys
          { $$= NEW_PTN PT_partition_data_directory(@$, $4.str); }
        | INDEX_SYM DIRECTORY_SYM opt_equal TEXT_STRING_sys
          { $$= NEW_PTN PT_partition_index_directory(@$, $4.str); }
        | COMMENT_SYM opt_equal TEXT_STRING_sys
          { $$= NEW_PTN PT_partition_comment(@$, $3.str); }
        ;
```

> `opt_equal` 语义组用于解析可选的 `=` 或 `SET_VAR` 关键字，详见下文；
>
> `ident` 语义组用于解析标识符或任意未保留关键字，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)，详见下文；
>
> `opt_storage` 语义组用于解析可选的 `STORAGE` 关键字，详见下文；
>
> `ident_or_text` 语义组用于解析标识符、任意未保留关键字、单引号 / 双引号字符串或用户自定义变量，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)；
>
> `real_ulong_num` 语义组用于解析十进制整数和十六进制数（转换为十进制数），返回 unsigned long 类型；如果输入十进制小数或超出范围的十进制整数，则抛出异常，详见 [MySQL 源码｜67 - 语法解析(V2)：数值字面值](https://zhuanlan.zhihu.com/p/718508554)；
>
> `real_ulonglong_num` 语义组用于解析十进制整数和十六进制数（转换为十进制数），返回 unsigned long long int 类型；如果输入十进制小数或超出范围的十进制整数，则抛出异常，详见 [MySQL 源码｜67 - 语法解析(V2)：数值字面值](https://zhuanlan.zhihu.com/p/718508554)；
>
> `TEXT_STRING_sys` 语义组用于解析表示各种名称的单引号 / 双引号字符串，详见 [MySQL 源码｜65 - 语法解析(V2)：字符串字面值](https://zhuanlan.zhihu.com/p/717934287)。

#### 语义组：`opt_equal`

`opt_equal` 语义组用于解析可选的 `=` 或 `SET_VAR` 关键字。

- 返回值类型：没有返回值
- Bison 语法如下：

```C++
opt_equal:
          %empty
        | equal
        ;
```

> `equal` 语义组用于解析 `=`（`EQUAL`）或 `SET_VAR` 关键字（`SET_VAR`），详见 [MySQL 源码｜57 - 语法解析(V2)：UPDATE 表达式和 DELETE 表达式](https://zhuanlan.zhihu.com/p/716038847)。

#### 语义组：`opt_storage`

`opt_storage` 语义组用于解析可选的 `STORAGE` 关键字。

- 返回值类型：没有返回值
- Bison 语法如下：

```C++
opt_storage:
          %empty
        | STORAGE_SYM
        ;
```

#### 语义组：`opt_sub_partition`

`opt_sub_partition` 语义组用于解析可选的、括号框柱的、任意数量、逗号分隔的子定义语句。

- 返回值类型：`Mem_root_array<PT_subpartition *>` 对象
- Bison 语法如下：

```C++
opt_sub_partition:
          %empty { $$= nullptr; }
        | '(' sub_part_list ')' { $$= $2; }
        ;
```

#### 语义组：`sub_part_list`

`sub_part_list` 语义组用于解析任意数量、逗号分隔的子定义语句。

- 返回值类型：`Mem_root_array<PT_subpartition *>` 对象
- Bison 语法如下：

```C++
sub_part_list:
          sub_part_definition
          {
            $$= NEW_PTN Mem_root_array<PT_subpartition *>(YYMEM_ROOT);
            if ($$ == nullptr || $$->push_back($1))
              MYSQL_YYABORT; // OOM
          }
        | sub_part_list ',' sub_part_definition
          {
            $$= $1;
            if ($$->push_back($3))
              MYSQL_YYABORT; // OOM
          }
        ;
```

#### 语义组：`sub_part_definition`

`sub_part_definition` 语义组用于解析单个自定义语句。

- 返回值类型：`PT_subpartition` 对象
- Bison 语法如下：

```C++
sub_part_definition:
          SUBPARTITION_SYM ident_or_text opt_part_options
          {
            $$= NEW_PTN PT_subpartition(@$, @1, $2.str, $3);
          }
        ;
```

> `ident_or_text` 语义组用于解析标识符、任意未保留关键字、单引号 / 双引号字符串或用户自定义变量，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)；
>
> `opt_part_options` 语义组用于解析 `PARTITION BY` 子句中的可选的、任意数量、空格分隔的分区选项，详见上文。
