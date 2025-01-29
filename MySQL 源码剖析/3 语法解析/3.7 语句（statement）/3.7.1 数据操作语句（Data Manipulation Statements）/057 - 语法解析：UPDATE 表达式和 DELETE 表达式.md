目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

下面我们梳理用于解析 `UPDATE` 语句的 `update_stmt` 语义组和 `DELETE` 语句的 `delete_stmt` 语义组。

### `UPDATE` 语句

`UPDATE` 语句涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析 - 035 - UPDATE 语句](C:\blog\graph\MySQL源码剖析\语法解析 - 035 - UPDATE 语句.png)

#### 语义组：`update_stmt`

`update_stmt` 语义组用于解析 `UPDATE` 语句。

- 官方文档：[MySQL 参考手册 - 15.2.17 UPDATE Statement](https://dev.mysql.com/doc/refman/8.0/en/update.html)
- 标准语法：

```
UPDATE [LOW_PRIORITY] [IGNORE] table_reference
    SET assignment_list
    [WHERE where_condition]
    [ORDER BY ...]
    [LIMIT row_count]

value:
    {expr | DEFAULT}

assignment:
    col_name = value

assignment_list:
    assignment [, assignment] ...
```

- 返回值类型：`Parse_tree_root` 对象（`top_level_node`），用于存储最顶层节点，即语句层级节点
- Bison 语法如下：

```C++
update_stmt:
          opt_with_clause
          UPDATE_SYM            /* #1 */
          opt_low_priority      /* #2 */
          opt_ignore            /* #3 */
          table_reference_list  /* #4 */
          SET_SYM               /* #5 */
          update_list           /* #6 */
          opt_where_clause      /* #7 */
          opt_order_clause      /* #8 */
          opt_simple_limit      /* #9 */
          {
            $$= NEW_PTN PT_update(@$, $1, $2, $3, $4, $5, $7.column_list, $7.value_list,
                                  $8, $9, $10);
          }
        ;
```

> `opt_with_clause` 语义组用于解析可选的 `WITH` 子句，详见 [MySQL 源码｜56 - 语法解析(V2)：WITH 子句](https://zhuanlan.zhihu.com/p/716036308)；
>
> `opt_low_priority` 语义组用于解析可选的 `LOW_PRIORITY` 关键字，详见下文；
>
> `opt_ignore` 语义组用于解析可选的 `IGNORE` 关键字，详见下文；
>
> `table_reference_list` 语义组用于解析任意数量、逗号分隔的各种类型的表，详见 [MySQL 源码｜76 - 语法解析(V2)：表语句（table_reference）](https://zhuanlan.zhihu.com/p/720247259)；
>
> `update_list` 语义组用于解析任意数量、逗号分隔的赋值语句，详见下文；
>
> `opt_where_clause` 语义组用于解析可选的 `WHERE` 子句，详见 [MySQL 源码｜77 - 语法解析(V2)：WHERE、HAVING 和 QUALIFY 子句](https://zhuanlan.zhihu.com/p/720281792)；
>
> `opt_order_clause` 语义组用于解析可选的 ORDER BY 子句，详见 [MySQL 源码｜39 - 语法解析(V2)：ORDER BY 子句](https://zhuanlan.zhihu.com/p/714781112)；
>
> `opt_simple_limit` 语义组用于解析仅允许设置限制行数，不允许设置偏移量的 `LIMIT` 子句，详见 [MySQL 源码｜78 - 语法解析(V2)：LIMIT 子句](https://zhuanlan.zhihu.com/p/720293254)。

#### 语义组：`opt_low_priority`

`opt_low_priority` 语义组用于解析可选的 `LOW_PRIORITY` 关键字。

- 返回值类型：`thr_lock_type` 枚举值（`lock_type`）
- Bison 语法如下：

```C++
opt_low_priority:
          %empty { $$= TL_WRITE_DEFAULT; }
        | LOW_PRIORITY { $$= TL_WRITE_LOW_PRIORITY; }
        ;
```

#### 语义组：`opt_ignore`

`opt_ignore` 语义组用于解析可选的 `IGNORE` 关键字。

- 返回值类型：`bool` 类型（`is_not_empty`）
- Bison 语法如下：

```C++
opt_ignore:
          %empty      { $$= false; }
        | IGNORE_SYM  { $$= true; }
        ;
```

#### 语义组：`update_list`

`update_list` 语义组用于解析任意数量、逗号分隔的赋值语句。

- 返回值类型：`column_value_list_pair` 结构体（`column_value_list_pair`），包含 `PT_item_list` 类型的成员 `column_list` 和 `value_list`
- Bison 语法如下：

```C++
update_list:
          update_list ',' update_elem
          {
            $$= $1;
            if ($$.column_list->push_back($3.column) ||
                $$.value_list->push_back($3.value))
              MYSQL_YYABORT; // OOM
          }
        | update_elem
          {
            $$.column_list= NEW_PTN PT_item_list(@$);
            $$.value_list= NEW_PTN PT_item_list(@$);
            if ($$.column_list == nullptr || $$.value_list == nullptr ||
                $$.column_list->push_back($1.column) ||
                $$.value_list->push_back($1.value))
              MYSQL_YYABORT; // OOM
          }
        ;
```

#### 语义组：`update_elem`

`update_elem` 语义组用于解析赋值语句，对应标准语法 `col_name = value`。

- 返回值类型：`column_value_pair` 结构体（`column_value_pair`），包括 `Item` 类型的 `column` 成员和 `value` 成员
- Bison 语法如下：

```C++
update_elem:
          simple_ident_nospvar equal expr_or_default
          {
            $$.column= $1;
            $$.value= $3;
          }
        ;
```

> `simple_ident_nospvar` 语义组用于解析 `ident`、`ident.ident` 或 `ident.ident.ident`，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)；
>
> `equal` 语义组用于 `=`（`EQUAL`）或 `SET_VAR` 关键字（`SET_VAR`），详见下文；
>
> `expr_or_default` 语义组用于解析一般表达式或 `DEFAULT` 关键字，详见 [MySQL 源码｜58 - 语法解析(V2)：SELECT 表达式](https://zhuanlan.zhihu.com/p/716212004)。

#### 语义组：`equal`

`equal` 语义组用于解析 `=`（`EQUAL`）或 `SET_VAR` 关键字（`SET_VAR`）。

- 返回值类型：没有返回值
- Bison 语法如下：

```C++
equal:
          EQ
        | SET_VAR
        ;
```

### `DELETE` 语句

`DELETE` 语句涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析 - 036 - DELETE 语句](C:\blog\graph\MySQL源码剖析\语法解析 - 036 - DELETE 语句.png)

#### 语义组：`delete_stmt`

`delete_stmt` 语义组用于解析 `DELETE` 语句。

- 官方文档：[MySQL 参考手册 - 15.2.2 DELETE Statement](https://dev.mysql.com/doc/refman/8.0/en/delete.html)
- 标准语法（包含如下 3 种标准语法，其中第 1 种为单表语法，后 2 种为多表语法）：

```
DELETE [LOW_PRIORITY] [QUICK] [IGNORE] FROM tbl_name [[AS] tbl_alias]
    [PARTITION (partition_name [, partition_name] ...)]
    [WHERE where_condition]
    [ORDER BY ...]
    [LIMIT row_count]
```

```
DELETE [LOW_PRIORITY] [QUICK] [IGNORE]
    tbl_name[.*] [, tbl_name[.*]] ...
    FROM table_references
    [WHERE where_condition]
```

```
DELETE [LOW_PRIORITY] [QUICK] [IGNORE]
    FROM tbl_name[.*] [, tbl_name[.*]] ...
    USING table_references
    [WHERE where_condition]
```

- 返回值类型：`Parse_tree_root` 对象（`top_level_node`），用于存储最顶层节点，即语句层级节点
- Bison 语法如下：

```C++
delete_stmt:
          opt_with_clause
          DELETE_SYM
          opt_delete_options
          FROM
          table_ident
          opt_table_alias
          opt_use_partition
          opt_where_clause
          opt_order_clause
          opt_simple_limit
          {
            $$= NEW_PTN PT_delete(@$, $1, $2, $3, $5, $6, $7, $8, $9, $10);
          }
        | opt_with_clause
          DELETE_SYM
          opt_delete_options
          table_alias_ref_list
          FROM
          table_reference_list
          opt_where_clause
          {
            $$= NEW_PTN PT_delete(@$, $1, $2, $3, $4, $6, $7);
          }
        | opt_with_clause
          DELETE_SYM
          opt_delete_options
          FROM
          table_alias_ref_list
          USING
          table_reference_list
          opt_where_clause
          {
            $$= NEW_PTN PT_delete(@$, $1, $2, $3, $5, $7, $8);
          }
        ;
```

> `opt_with_clause` 语义组用于解析可选的 `WITH` 子句，详见 [MySQL 源码｜56 - 语法解析(V2)：WITH 子句](https://zhuanlan.zhihu.com/p/716036308)；
>
> `opt_delete_options` 语义组用于解析可选的、任意数量的、逗号分隔的 `DELETE` 语句选项，详见下文；
>
> `table_ident` 语义组用于解析 `ident` 或 `ident.ident`，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)；
>
> `opt_table_alias` 语义组用于解析可选的、`AS` 关键字引导的别名子句，详见 [MySQL 源码｜74 - 语法解析(V2)：JSON_TABLE 函数](https://zhuanlan.zhihu.com/p/720046825)；
>
> `opt_use_partition` 语义组用于解析可选的 `PARTITION` 子句，详见 [MySQL 源码｜76 - 语法解析(V2)：表语句（table_reference）](https://zhuanlan.zhihu.com/p/720247259)；
>
> `opt_where_clause` 语义组用于解析可选的 `WHERE` 子句，详见 [MySQL 源码｜77 - 语法解析(V2)：WHERE、HAVING 和 QUALIFY 子句](https://zhuanlan.zhihu.com/p/720281792)；
>
> `opt_order_clause` 语义组用于解析可选的 ORDER BY 子句，详见 [MySQL 源码｜39 - 语法解析(V2)：ORDER BY 子句](https://zhuanlan.zhihu.com/p/714781112)；
>
> `opt_simple_limit` 语义组用于解析仅允许设置限制行数，不允许设置偏移量的 `LIMIT` 子句，详见 [MySQL 源码｜78 - 语法解析(V2)：LIMIT 子句](https://zhuanlan.zhihu.com/p/720293254)；
>
> `table_alias_ref_list` 语义组用于解析逗号分隔、任意数量的表名（`table_ident_opt_wild` 语义组），详见 [MySQL 源码｜68 - 语法解析(V2)：LOCKING 子句（锁定读取）](https://zhuanlan.zhihu.com/p/719010523)；
>
> `table_reference_list` 语义组用于解析任意数量、逗号分隔的各种类型的表，详见 [MySQL 源码｜76 - 语法解析(V2)：表语句（table_reference）](https://zhuanlan.zhihu.com/p/720247259)。

#### 语义组：`opt_delete_options`

`opt_delete_options` 语义组用于解析可选的、任意数量的、逗号分隔的 `DELETE` 语句选项。

- 标准语法：`[LOW_PRIORITY] [QUICK] [IGNORE]`
- 返回值类型：`int` 类型（`num`）
- Bison 语法如下：

```C++
opt_delete_options:
          %empty { $$= 0; }
        | opt_delete_option opt_delete_options { $$= $1 | $2; }
        ;
```

#### 语义组：`opt_delete_option`

`opt_delete_option` 语义组用于解析 `QUICK`、`LOW_PRIORITY` 或 `IGNORE` 关键字。

- 返回值类型：`delete_option_enum` 枚举值（`opt_delete_option`），包含 `DELETE_QUICK`、`DELETE_LOW_PRIORITY` 和 `DELETE_IGNORE` 这 3 个枚举值
- Bison 语法如下：

```C++
opt_delete_option:
          QUICK        { $$= DELETE_QUICK; }
        | LOW_PRIORITY { $$= DELETE_LOW_PRIORITY; }
        | IGNORE_SYM   { $$= DELETE_IGNORE; }
        ;
```
