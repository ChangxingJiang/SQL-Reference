目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

在 FROM 子句（`from_tables` 语义组），`UPDATE` 表达式（`update_stmt`）和 `DELETE` 表达式（`delete_stmt`）中，均使用了 `table_reference_list` 语义组用于解析使用各种不同语法表示的表。下面梳理 `table_reference_list` 语义组，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析 - 027 - 表语句](C:\blog\graph\MySQL源码剖析\语法解析 - 027 - 表语句.png)

#### 语义组：`table_reference_list`

`table_reference_list` 语义组用于解析任意数量、逗号分隔的各种类型的表。

- 官方文档：[MySQL 参考手册 - 15.2.13.2 JOIN Clause](https://dev.mysql.com/doc/refman/8.4/en/join.html)
- 标准语法：

```
table_references:
    escaped_table_reference [, escaped_table_reference] ...

escaped_table_reference: {
    table_reference
  | { OJ table_reference }
}

table_reference: {
    table_factor
  | joined_table
}

table_factor: {
    tbl_name [PARTITION (partition_names)]
        [[AS] alias] [index_hint_list]
  | [LATERAL] table_subquery [AS] alias [(col_list)]
  | ( table_references )
}

joined_table: {
    table_reference {[INNER | CROSS] JOIN | STRAIGHT_JOIN} table_factor [join_specification]
  | table_reference {LEFT|RIGHT} [OUTER] JOIN table_reference join_specification
  | table_reference NATURAL [INNER | {LEFT|RIGHT} [OUTER]] JOIN table_factor
}

join_specification: {
    ON search_condition
  | USING (join_column_list)
}

join_column_list:
    column_name[, column_name] ...

index_hint_list:
    index_hint[ index_hint] ...

index_hint: {
    USE {INDEX|KEY}
      [FOR {JOIN|ORDER BY|GROUP BY}] ([index_list])
  | {IGNORE|FORCE} {INDEX|KEY}
      [FOR {JOIN|ORDER BY|GROUP BY}] (index_list)
}

index_list:
    index_name [, index_name] ...
```

- 返回值类型：`Mem_root_array_YY<PT_table_reference *>`（`table_reference_list`）
- 使用场景：FROM 子句（`from_tables` 语义组），`UPDATE` 表达式（`update_stmt`）和 `DELETE` 表达式（`delete_stmt`）
- Bison 语法如下：

```C++
table_reference_list:
          table_reference
          {
            $$.init(YYMEM_ROOT);
            if ($$.push_back($1))
              MYSQL_YYABORT; // OOM
          }
        | table_reference_list ',' table_reference
          {
            $$= $1;
            if ($$.push_back($3))
              MYSQL_YYABORT; // OOM
          }
        ;
```

#### 语义组：`table_reference`

`table_reference` 语义组用于解析各种类型的表，包括单个表、关联表以及 `{ OJ ... }` 语法的单个表、关联表。其中的备选规则 `'{' OJ_SYM esc_table_reference '}'` 为外面嵌套大括号的单个表或关联表， `{ OJ ... }` 这种语法仅为了语 ODBC 兼容而存在，其中的大括号应该为字面值形式，而不能作为元语法符号来使用。

- 官方文档：[MySQL 参考手册 - 15.2.13.2 JOIN Clause](https://dev.mysql.com/doc/refman/8.4/en/join.html)
- 标准语法：

```
escaped_table_reference: {
    table_reference
  | { OJ table_reference }
}

table_reference: {
    table_factor
  | joined_table
}
```

- 返回值类型：`PT_table_reference` 对象（`table_reference`）
- Bison 语法如下：

```C++
table_reference:
          table_factor { $$= $1; }
        | joined_table { $$= $1; }
        | '{' OJ_SYM esc_table_reference '}'
          {
            /*
              The ODBC escape syntax for Outer Join.

              All productions from table_factor and joined_table can be escaped,
              not only the '{LEFT | RIGHT} [OUTER] JOIN' syntax.
            */
            $$ = $3;
          }
        ;
```

> `table_factor` 语义组用于解析各种类型的表语句，详见下文；
>
> `esc_table_reference` 语义组用于匹配 `table_factor` 语义组结果（单个表）或 `joined_table` 语义组结果（关联表），详见下文；

#### 语义组：`esc_table_reference`

`esc_table_reference` 语义组用于解析 `table_factor` 语义组结果（单个表）或 `joined_table` 语义组结果（关联表）。

- 返回值类型：`PT_table_reference` 对象（`table_reference`）
- Bison 语法如下：

```C++
esc_table_reference:
          table_factor { $$= $1; }
        | joined_table { $$= $1; }
        ;
```

#### 语义组：`table_factor`

`table_factor` 语义组用于解析各种类型的表语句。

- 官方文档：[MySQL 参考手册 - 15.2.13.2 JOIN Clause](https://dev.mysql.com/doc/refman/8.0/en/join.html)
- 返回值类型：`PT_table_reference` 对象（`table_reference`）
- 使用场景：FROM 子句、JOIN 子句
- 备选规则和 Bison 语法如下：

| 备选规则                      | 规则含义                                         |
| ----------------------------- | ------------------------------------------------ |
| `single_table`                | 解析使用名称获取的单个表                         |
| `single_table_parens`         | 解析使用任意数量括号嵌套的、使用名称获取的单个表 |
| `derived_table`               | 解析通过子查询或 `LATERAL` 子句生成的表          |
| `joined_table_parens`         | 解析使用任意数量括号嵌套的、包含关联子句的关联表 |
| `table_reference_list_parens` | 解析使用任意数量括号嵌套的查询表或关联表         |
| `table_function`              | 解析 `JSON_TABLE` 函数生成的表                   |

```C++
table_factor:
          single_table
        | single_table_parens
        | derived_table { $$ = $1; }
        | joined_table_parens
          { $$= NEW_PTN PT_table_factor_joined_table(@$, $1); }
        | table_reference_list_parens
          { $$= NEW_PTN PT_table_reference_list_parens(@$, $1); }
        | table_function { $$ = $1; }
        ;
```

> `single_table` 语义组用于解析单个表引用，详见下文；
>
> `single_table_parens` 语义组用于解析嵌套了任意层数小括号的单个表引用，详见下文；
>
> `derived_table` 语义组用于解析子查询生成的表，以及使用 `LATERAL` 子句生成的横向派生表，详见下文；
>
> `joined_table_parens` 语义组用于解析使用任意层小括号扩住的关联表，详见下文；
>
> `table_reference_list_parens` 语义组用于解析使用任意层括号框柱的、任意数量、逗号分隔的各种类型的表，详见下文；
>
> `table_function` 语义组用于解析 `JSON_TABLE` 函数，`JSON_TABLE` 函数可以将 JSON 数据转化为结构化数据，详见 [MySQL 源码｜74 - 语法解析(V2)：JSON_TABLE 函数](https://zhuanlan.zhihu.com/p/720046825)。

#### 语义组：`single_table`

`single_table` 语义组用于解析单个表引用。

- 官方文档：[MySQL 参考手册 - 15.2.13.2 JOIN Clause](https://dev.mysql.com/doc/refman/8.0/en/join.html)
- 返回值类型：`PT_table_reference` 对象（`table_reference`）
- Bison 语法如下：

```C++
single_table:
          table_ident opt_use_partition opt_table_alias opt_key_definition
          {
            $$= NEW_PTN PT_table_factor_table_ident(@$, $1, $2, $3, $4);
          }
        ;
```

> `table_ident` 语义组用于解析 `ident` 或 `ident.ident`，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)；
>
> `opt_use_partition` 语义组用于解析可选的 `PARTITION` 子句，详见下文；
>
> `opt_table_alias` 语义组用于解析可选的、`AS` 关键字引导的别名子句，详见 [MySQL 源码｜74 - 语法解析(V2)：JSON_TABLE 函数](https://zhuanlan.zhihu.com/p/720046825)；
>
> `opt_key_definition` 语义组用于解析可选、任意数量、空格分隔的 `USE`、`IGNORE` 和 `FORCE` 这 3 个索引指示子句，详见 [MySQL 源码｜75 - 语法解析(V2)：索引提示子句（USE、FORCE、IGNORE）](https://zhuanlan.zhihu.com/p/720054242)；

#### 语义组：`opt_use_partition`

`opt_use_partition` 语义组用于解析可选的 `PARTITION` 子句。

- 返回值类型：`List<String>`（`string_list`）
- Bison 语法如下：

```C++
opt_use_partition:
          %empty { $$= nullptr; }
        | use_partition
        ;
```

#### 语义组：`use_partition`

`use_partition` 语义组用于解析 `PARTITION` 子句。一个表引用（指向一个分区表时）可以包含一个 `PARTITION` 子句，其中包括一个逗号分隔的分区、子分区或两者均包含的列表，用于仅从列出的分区或子分区中选择行，即忽略列表中不包含的任何分区或子分区的数据。`PARTITION` 子句位于表名之后，在声明别名之前。

- 官方文档：[MySQL 参考手册 - 15.2.13.2 JOIN Clause](https://dev.mysql.com/doc/refman/8.0/en/join.html)；[MySQL 参考手册 - 26.5 Partition Selection](https://dev.mysql.com/doc/refman/8.4/en/partitioning-selection.html)
- 返回值类型：`List<String>`（`string_list`）
- Bison 语法如下：

```C++
use_partition:
          PARTITION_SYM '(' using_list ')'
          {
            $$= $3;
          }
        ;
```

#### 语义组：`using_list`

`using_list` 语义组用于解析分区名称、子分区名称或字段名称的列表。

- 返回值类型：`List<String>`（`string_list`）
- Bison 语法如下：

```C++
using_list:
          ident_string_list
        ;
```

> `ident_string_list` 语义组用于解析任意数量、逗号分隔的标识符或未保留关键字（返回 `List<String>` 类型），详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)。

#### 语义组：`single_table_parens`

`single_table_parens` 语义组用于解析嵌套了任意层数小括号的单个表引用。

- 返回值类型：`PT_table_reference` 对象（`table_reference`）
- Bison 语法如下：

```C++
single_table_parens:
          '(' single_table_parens ')' { $$= $2; }
        | '(' single_table ')' { $$= $2; }
        ;
```

#### 语义组：`derived_table`

`derived_table` 语义组用于解析子查询生成的表，以及使用 `LATERAL` 子句生成的横向派生表。

- 官方文档：[MySQL 参考手册 - 15.2.15.9 Lateral Derived Tables](https://dev.mysql.com/doc/refman/8.4/en/lateral-derived-tables.html)
- 返回值类型：`PT_derived_table` 对象（`derived_table`）
- Bison 语法如下：

```C++
derived_table:
          table_subquery opt_table_alias opt_derived_column_list
          {
            /*
              The alias is actually not optional at all, but being MySQL we
              are friendly and give an informative error message instead of
              just 'syntax error'.
            */
            if ($2.str == nullptr)
              my_message(ER_DERIVED_MUST_HAVE_ALIAS,
                         ER_THD(YYTHD, ER_DERIVED_MUST_HAVE_ALIAS), MYF(0));

            $$= NEW_PTN PT_derived_table(@$, false, $1, $2, &$3);
          }
        | LATERAL_SYM table_subquery opt_table_alias opt_derived_column_list
          {
            if ($3.str == nullptr)
              my_message(ER_DERIVED_MUST_HAVE_ALIAS,
                         ER_THD(YYTHD, ER_DERIVED_MUST_HAVE_ALIAS), MYF(0));

            $$= NEW_PTN PT_derived_table(@$, true, $2, $3, &$4);
          }
        ;
```

>`table_subquery` 语义组用于解析多行子查询，详见 [MySQL 源码｜47 - 语法解析(V2)：子查询](https://zhuanlan.zhihu.com/p/715426420)；
>
>`opt_table_alias` 语义组用于解析可选的、`AS` 关键字引导的别名子句，详见 [MySQL 源码｜74 - 语法解析(V2)：JSON_TABLE 函数](https://zhuanlan.zhihu.com/p/720046825)；
>
>`opt_derived_column_list` 语义组用于解析被小括号框柱的、任意数量、逗号分隔的列表（标识符）的列表，详见下文。

#### 语义组：`opt_derived_column_list`

`opt_derived_column_list` 语义组用于解析被小括号框柱的、任意数量、逗号分隔的列表（标识符）的列表。

- 返回值类型：`Mem_root_array_YY<LEX_CSTRING>`（`simple_ident_list`）
- Bison 语法如下：

```C++
opt_derived_column_list:
          %empty
          {
            /*
              Because () isn't accepted by the rule of
              simple_ident_list, we can use an empty array to
              designates that the parenthesised list was omitted.
            */
            $$.init(YYTHD->mem_root);
          }
        | '(' simple_ident_list ')'
          {
            $$= $2;
          }
        ;
```

> `simple_ident_list` 语义组用于解析任意数量、逗号分隔的标识符或未保留关键字（返回 `Mem_root_array_YY<LEX_CSTRING>` 类型），详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)。

#### 语义组：`joined_table_parens`

`joined_table_parens` 语义组用于解析使用任意层小括号扩住的关联表。

- 返回值类型：`PT_joined_table` 对象（`join_table`）
- Bison 语法如下：

```C++
joined_table_parens:
          '(' joined_table_parens ')' { $$= $2; }
        | '(' joined_table ')' { $$= $2; }
        ;
```

#### 语义组：`joined_table`

`joined_table` 语义组用于解析关联表。

- 官方文档：[MySQL 参考手册 - 15.2.13.2 JOIN Clause](https://dev.mysql.com/doc/refman/8.4/en/join.html)
- 标准语法：

```
joined_table: {
    table_reference {[INNER | CROSS] JOIN | STRAIGHT_JOIN} table_factor [join_specification]
  | table_reference {LEFT|RIGHT} [OUTER] JOIN table_reference join_specification
  | table_reference NATURAL [INNER | {LEFT|RIGHT} [OUTER]] JOIN table_factor
}
```

- 返回值类型：`PT_joined_table` 对象（`join_table`）
- 备选规则和 Bison 语法如下：

| 备选规则                                                     | 规则含义                                          |
| ------------------------------------------------------------ | ------------------------------------------------- |
| `table_reference inner_join_type table_reference ON_SYM expr` | 使用 `ON` 子句定义关联规则的内关联                |
| `table_reference inner_join_type table_reference USING '(' using_list ')'` | 使用 `USING` 函数定义关联规则的内关联             |
| `table_reference outer_join_type table_reference ON_SYM expr` | 使用 `ON` 子句定义关联规则的外关联                |
| `table_reference outer_join_type table_reference USING '(' using_list ')'` | 使用 `USING` 函数定义关联规则的外关联             |
| `table_reference inner_join_type table_reference`            | 没有在 `JOIN` 子句中指定关联规则的内关联          |
| `table_reference natural_join_type table_factor`             | 没有在 `JOIN` 子句中指定关联规则的 `NATURAL` 关联 |

```C++
joined_table:
          table_reference inner_join_type table_reference ON_SYM expr
          {
            $$= NEW_PTN PT_joined_table_on(@$, $1, @2, $2, $3, $5);
          }
        | table_reference inner_join_type table_reference USING
          '(' using_list ')'
          {
            $$= NEW_PTN PT_joined_table_using(@$, $1, @2, $2, $3, $6);
          }
        | table_reference outer_join_type table_reference ON_SYM expr
          {
            $$= NEW_PTN PT_joined_table_on(@$, $1, @2, $2, $3, $5);
          }
        | table_reference outer_join_type table_reference USING '(' using_list ')'
          {
            $$= NEW_PTN PT_joined_table_using(@$, $1, @2, $2, $3, $6);
          }
        | table_reference inner_join_type table_reference
          %prec CONDITIONLESS_JOIN
          {
            auto this_cross_join= NEW_PTN PT_cross_join(@$, $1, @2, $2, nullptr);

            if ($3 == nullptr)
              MYSQL_YYABORT; // OOM

            $$= $3->add_cross_join(this_cross_join);
          }
        | table_reference natural_join_type table_factor
          {
            $$= NEW_PTN PT_joined_table_using(@$, $1, @2, $2, $3);
          }
        ;
```

> `inner_join_type` 语义组用于解析 `JOIN`、`INNER JOIN`、`CROSS JOIN` 或 `STRAIGHT_JOIN`，详见下文；
>
> `outer_join_type` 语义组用于解析 `LEFT JOIN`、`LEFT OUTER JOIN`、`RIGHT JOIN` 或 `RIGHT OUTER JOIN`，详见下文；
>
> `natural_join_type` 语义组用于解析 `NATURAL JOIN`、`NATURAL INNER JOIN`、`NATURAL LEFT JOIN`、`NATURAL LEFT OUTER JOIN`、`NATURAL RIGHT JOIN` 或 `NATURAL RIGHT OUTER JOIN`，详见下文；
>
> `using_list` 语义组用于解析分区名称、子分区名称或字段名称的列表，详见上文；
>
> `expr` 语义组用于解析最高级的一般表达式，详见 [MySQL 源码｜72 - 语法解析(V2)：一般表达式（expr）](https://zhuanlan.zhihu.com/p/719447959)。

#### 语义组：`inner_join_type`

`inner_join_type` 语义组用于解析 `JOIN`、`INNER JOIN`、`CROSS JOIN` 或 `STRAIGHT_JOIN`。

- 返回值类型：`PT_joined_table_type` 枚举值（`join_type`），枚举值包括 `JTT_INNER`、`JTT_STRAIGHT`、`JTT_NATURAL`、`JTT_LEFT`、`JTT_RIGHT` 这 5 个枚举值以及它们的 4 个交集 `JTT_STRAIGHT_INNER`、`JTT_NATURAL_INNER`、`JTT_NATURAL_LEFT`、`JTT_NATURAL_RIGHT`。
- Bison 语法如下：

```C++
inner_join_type:
          JOIN_SYM                         { $$= JTT_INNER; }
        | INNER_SYM JOIN_SYM               { $$= JTT_INNER; }
        | CROSS JOIN_SYM                   { $$= JTT_INNER; }
        | STRAIGHT_JOIN                    { $$= JTT_STRAIGHT_INNER; }
```

#### 语义组：`outer_join_type`

`outer_join_type` 语义组用于解析 `LEFT JOIN`、`LEFT OUTER JOIN`、`RIGHT JOIN` 或 `RIGHT OUTER JOIN`。

- 返回值类型：`PT_joined_table_type` 枚举值（`join_type`）
- Bison 语法如下：

```C++
outer_join_type:
          LEFT opt_outer JOIN_SYM          { $$= JTT_LEFT; }
        | RIGHT opt_outer JOIN_SYM         { $$= JTT_RIGHT; }
        ;
```

#### 语义组：`natural_join_type`

`natural_join_type` 语义组用于解析 `NATURAL JOIN`、`NATURAL INNER JOIN`、`NATURAL LEFT JOIN`、`NATURAL LEFT OUTER JOIN`、`NATURAL RIGHT JOIN` 或 `NATURAL RIGHT OUTER JOIN`。

- 返回值类型：`PT_joined_table_type` 枚举值（`join_type`）
- Bison 语法如下：

```C++
natural_join_type:
          NATURAL opt_inner JOIN_SYM       { $$= JTT_NATURAL_INNER; }
        | NATURAL RIGHT opt_outer JOIN_SYM { $$= JTT_NATURAL_RIGHT; }
        | NATURAL LEFT opt_outer JOIN_SYM  { $$= JTT_NATURAL_LEFT; }
        ;
```

#### 语义组：`opt_inner`

`opt_inner` 语义组用于解析可选的 `INNER` 关键字。

- 返回值类型：没有返回值
- Bison 规则如下：

```C++
opt_inner:
          %empty
        | INNER_SYM
        ;
```

#### 语义组：`opt_outer`

`opt_outer` 语义组用于解析可选的 `OUTER` 关键字。

- 返回值类型：没有返回值
- Bison 规则如下：

```C++
opt_outer:
          %empty
        | OUTER_SYM
        ;
```

#### 语义组：`table_reference_list_parens`

`table_reference_list_parens` 语义组用于解析使用任意层括号框柱的、任意数量、逗号分隔的各种类型的表。

- 返回值类型：`Mem_root_array_YY<PT_table_reference *>`（`table_reference_list`）
- Bison 语法如下：

```C++
table_reference_list_parens:
          '(' table_reference_list_parens ')' { $$= $2; }
        | '(' table_reference_list ',' table_reference ')'
          {
            $$= $2;
            if ($$.push_back($4))
              MYSQL_YYABORT; // OOM
          }
        ;
```
