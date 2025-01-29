目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

下面我们梳理 `USE`、`IGNORE` 和 `FORCE` 这 3 个索引指示子句，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析 - 026 - 索引提示子句](C:\blog\graph\MySQL源码剖析\语法解析 - 026 - 索引提示子句.png)

#### 语义组：`opt_key_definition`

`opt_key_definition` 语义组用于解析可选、任意数量、空格分隔的 `USE`、`IGNORE` 和 `FORCE` 这 3 个索引指示子句。

- 官方文档：[MySQL 参考手册 - 10.9.4 Index Hints](https://dev.mysql.com/doc/refman/8.0/en/index-hints.html)
- 标准语法：

```
[index_hint_list]

index_hint_list:
    index_hint [index_hint] ...

index_hint:
    USE {INDEX|KEY}
      [FOR {JOIN|ORDER BY|GROUP BY}] ([index_list])
  | {IGNORE|FORCE} {INDEX|KEY}
      [FOR {JOIN|ORDER BY|GROUP BY}] (index_list)

index_list:
    index_name [, index_name] ...
```

- 返回值类型：`List<Index_hint>`（`key_usage_list`）
- 使用场景：使用名称读取的表之后（`simple_table` 语义组）
- Bison 语法如下：

```C++
opt_key_definition:
          opt_index_hints_list
        ;
```

#### 语义组：`opt_index_hints_list`

`opt_index_hints_list` 语义组用于解析可选、任意数量、空格分隔的 `USE`、`IGNORE` 和 `FORCE` 这 3 个索引指示子句。

- 官方文档：[MySQL 参考手册 - 10.9.4 Index Hints](https://dev.mysql.com/doc/refman/8.0/en/index-hints.html)
- 返回值类型：`List<Index_hint>`（`key_usage_list`）
- Bison 语法如下：

```C++
opt_index_hints_list:
          %empty { $$= nullptr; }
        | index_hints_list
        ;
```

#### 语义组：`index_hints_list`

`index_hints_list` 语义组用于解析任意数量、空格分隔的 `USE`、`IGNORE` 和 `FORCE` 这 3 个索引指示子句。

- 官方文档：[MySQL 参考手册 - 10.9.4 Index Hints](https://dev.mysql.com/doc/refman/8.0/en/index-hints.html)
- 返回值类型：`List<Index_hint>`（`key_usage_list`）
- Bison 语法如下：

```C++
index_hints_list:
          index_hint_definition
        | index_hints_list index_hint_definition
          {
            $2->concat($1);
            $$= $2;
          }
        ;
```

#### 语义组：`index_hint_definition`

`index_hint_definition` 语义组用于解析 `USE`、`IGNORE` 和 `FORCE` 这 3 个索引指示子句。

- 官方文档：[MySQL 参考手册 - 10.9.4 Index Hints](https://dev.mysql.com/doc/refman/8.0/en/index-hints.html)
- 标准语法：

```
index_hint:
    USE {INDEX|KEY}
      [FOR {JOIN|ORDER BY|GROUP BY}] ([index_list])
  | {IGNORE|FORCE} {INDEX|KEY}
      [FOR {JOIN|ORDER BY|GROUP BY}] (index_list)

index_list:
    index_name [, index_name] ...
```

- 返回值类型：`List<Index_hint>`（`key_usage_list`）
- 备选规则 Bison 语法如下：

| 备选规则                                                     | 规则含义                                                     |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| `index_hint_type key_or_index index_hint_clause '(' key_usage_list ')'` | 解析标准语法 `{IGNORE|FORCE} {INDEX|KEY} [FOR {JOIN|ORDER BY|GROUP BY}] (index_list)` |
| `USE_SYM key_or_index index_hint_clause '(' opt_key_usage_list ')'` | 解析标准语法 `USE {INDEX|KEY} [FOR {JOIN|ORDER BY|GROUP BY}] ([index_list])` |

```C++
index_hint_definition:
          index_hint_type key_or_index index_hint_clause
          '(' key_usage_list ')'
          {
            init_index_hints($5, $1, $3);
            $$= $5;
          }
        | USE_SYM key_or_index index_hint_clause
          '(' opt_key_usage_list ')'
          {
            init_index_hints($5, INDEX_HINT_USE, $3);
            $$= $5;
          }
       ;
```

> `index_hint_type` 语义组用于解析 `FORCE` 关键字或 `IGNORE` 关键字，详见下文；
>
> `key_or_index` 语义组用于解析 `KEY` 关键字或 `INDEX` 关键字，详见下文；
>
> `index_hint_clause` 语义组用于解析可选的 `FOR JOIN`、`FOR ORDER BY` 或 `FOR GROUP BY`，详见下文；
>
> `key_usage_list` 语义组用于解析任意数量、逗号分隔的索引名称列表，详见下文；
>
> `opt_key_usage_list` 语义组用于解析可选、任意数量、逗号分隔的索引名称列表，详见下文。

- 依次匹配 `index_hint_type` 规则匹配结果、`key_or_index` 规则匹配结果和 `index_hint_clause` 规则匹配结果
  - `index_hint_type` 规则用于匹配 `FORCE` 关键字或 `IGNORE` 关键字
  - `key_or_index` 规则用于匹配 `KEY` 关键字或 `INDEX` 关键字
  - `index_hint_clause` 规则用于匹配可选的 `FOR JOIN`、`FOR ORDER BY` 或 `FOR GROUP BY`
- 依次匹配 `USE` 关键字、`key_or_index` 规则匹配结果和 `index_hint_clause` 规则匹配结果

#### 语义组：`index_hint_type`

`index_hint_type` 语义组用于解析 `FORCE` 关键字或 `IGNORE` 关键字。

- 返回值类型：`index_hint_type` 枚举值（`index_hint`），包括 `INDEX_HINT_IGNORE`、`INDEX_HINT_USE` 和 `INDEX_HINT_FORCE` 这 3 个枚举值
- Bison 语法如下：

```C++
index_hint_type:
          FORCE_SYM  { $$= INDEX_HINT_FORCE; }
        | IGNORE_SYM { $$= INDEX_HINT_IGNORE; }
        ;
```

#### 语义组：`key_or_index`

`key_or_index` 语义组用于解析 `KEY` 关键字或 `INDEX` 关键字。

- 返回值类型：没有返回值
- Bison 语法如下：

```C++
key_or_index:
          KEY_SYM {}
        | INDEX_SYM {}
        ;
```

#### 语义组：`index_hint_clause`

`index_hint_clause` 语义组用于解析可选的 `FOR JOIN`、`FOR ORDER BY` 或 `FOR GROUP BY`。

- 返回值类型：`int` 类型（`num`），宏 `INDEX_HINT_MASK_JOIN` 为 1，宏 `INDEX_HINT_MASK_ORDER` 为 2（`1 << 1`），宏 `INDEX_HINT_MASK_ORDER` 为 4（`1 << 2`）
- Bison 语法如下：

```C++
index_hint_clause:
          %empty
          {
            $$= old_mode ?  INDEX_HINT_MASK_JOIN : INDEX_HINT_MASK_ALL;
          }
        | FOR_SYM JOIN_SYM      { $$= INDEX_HINT_MASK_JOIN;  }
        | FOR_SYM ORDER_SYM BY  { $$= INDEX_HINT_MASK_ORDER; }
        | FOR_SYM GROUP_SYM BY  { $$= INDEX_HINT_MASK_GROUP; }
        ;
```

#### 语义组：`opt_key_usage_list`

`opt_key_usage_list` 语义组用于解析可选、任意数量、逗号分隔的索引名称列表。

- 返回值类型：`List<Index_hint>`（`key_usage_list`）
- Bison 语法如下：

```C++
opt_key_usage_list:
          %empty
          {
            $$= NEW_PTN List<Index_hint>;
            Index_hint *hint= NEW_PTN Index_hint(nullptr, 0);
            if ($$ == nullptr || hint == nullptr || $$->push_front(hint))
              MYSQL_YYABORT;
          }
        | key_usage_list
        ;
```

#### 语义组：`key_usage_list`

`key_usage_list` 语义组用于解析任意数量、逗号分隔的索引名称列表。

- 返回值类型：`List<Index_hint>`（`key_usage_list`）
- Bison 语法如下：

```C++
key_usage_list:
          key_usage_element
          {
            $$= NEW_PTN List<Index_hint>;
            if ($$ == nullptr || $$->push_front($1))
              MYSQL_YYABORT;
          }
        | key_usage_list ',' key_usage_element
          {
            if ($$->push_front($3))
              MYSQL_YYABORT;
          }
        ;
```

#### 语义组：`key_usage_element`

`key_usage_element` 语义组用于解析非主键索引名称或表示主键的 `PRIMARY` 关键字。

- 返回值类型：`Index_hint` 类（`key_usage_element`）
- Bison 语法如下：

```C++
key_usage_element:
          ident
          {
            $$= NEW_PTN Index_hint($1.str, $1.length);
            if ($$ == nullptr)
              MYSQL_YYABORT;
          }
        | PRIMARY_SYM
          {
            $$= NEW_PTN Index_hint(STRING_WITH_LEN("PRIMARY"));
            if ($$ == nullptr)
              MYSQL_YYABORT;
          }
        ;
```

> `ident` 语义组用于解析标识符或任意未保留关键字，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)。
