目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[/sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

前置文档：

- [MySQL 源码｜33 - 语法解析：bison 基础语法规则](https://zhuanlan.zhihu.com/p/714779214)

---

如果需要在同一个事务中查询数据并插入或更新相关数据，那么普通的 `SELECT` 语句提供的保护是不够的。其他事务可能会更新或删除 `SELECT` 查到的行。此时，就可以使用 InnoDB 支持的两种类型的锁定读取，来提供额外的安全性，语法逻辑详见 [MySQL 参考手册 - 17.7.2.4 Locking Reads](https://dev.mysql.com/doc/refman/8.4/en/innodb-locking-reads.html)。两种类型的锁定读取用法大概如下：

- `SELECT ... FOR SHARE`（同 `SELECT ... LOCK IN SHARE MODE` 语法，保留此语法以实现向前兼容）：对所读取的任何行设置共享模式锁。其他 session 可以读取这些行，但无法在当前事务提交之前修改它们。如果这些行中的任何一行被另一个尚未提交的事务更改了，那么当前查询将会等待那个事务结束，然后使用最新的值。
- `SELECT ... FOR UPDATE`：对于搜索遇到的索引记录（index records），锁定这些行及其相关的索引条目，就像对这些行发出了 `UPDATE` 语句一样。其他事务将被阻止更新这些行，执行 `SELECT ... FOR SHARE`，或者在某些事务隔离级别下读取这些数据。

MySQL 的语法解析使用 `locking_clause` 语义组来解析 `LOCKING` 子句。其中涉及语义组和语义组之间的关系如下图所示（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析-013-锁定读取的Locking子句](C:\blog\graph\MySQL源码剖析\语法解析-013-锁定读取的Locking子句.png)

#### 语义组：`locking_clause`

`locking_clause` 语义组用于解析设置读取锁定的 Locking 子句。

- 官方文档：[MySQL 参考手册 - 17.7.2.4 Locking Reads](https://dev.mysql.com/doc/refman/8.4/en/innodb-locking-reads.html)
- 返回值类型：`PT_locking_clause` 对象（`locking_clause`）
- 使用场景：`locking_clause_list` 语义组
- 备选规则和 Bison 语法：

| 备选规则                                                     | 返回值类型                           | 规则含义                                                     |
| ------------------------------------------------------------ | ------------------------------------ | ------------------------------------------------------------ |
| `FOR_SYM lock_strength opt_locked_row_action`                | `PT_query_block_locking_clause` 对象 | 用于解析标准语法 `FOR {UPDATE | SHARE} [SKIP LOCKED | NOWAIT]` |
| `FOR_SYM lock_strength table_locking_list opt_locked_row_action` | `PT_table_locking_clause` 对象       | 用于解析标准语法 `FOR {UPDATE | SHARE} OF table[, table] [SKIP LOCKED|NOWAIT]` |
| `LOCK_SYM IN_SYM SHARE_SYM MODE_SYM`                         | `PT_query_block_locking_clause` 对象 | 用于解析标准语法 `LOCK IN SHARE MODE`                        |

```C++
locking_clause:
          FOR_SYM lock_strength opt_locked_row_action
          {
            $$= NEW_PTN PT_query_block_locking_clause(@$, $2, $3);
          }
        | FOR_SYM lock_strength table_locking_list opt_locked_row_action
          {
            $$= NEW_PTN PT_table_locking_clause(@$, $2, $3, $4);
          }
        | LOCK_SYM IN_SYM SHARE_SYM MODE_SYM
          {
            $$= NEW_PTN PT_query_block_locking_clause(@$, Lock_strength::SHARE);
          }
        ;
```

#### 语义组：`locking_clause_list`

`locking_clause` 语义组用于解析空格分隔、任意数量的设置读取锁定的 Locking 子句。

- 官方文档：[MySQL 参考手册 - 17.7.2.4 Locking Reads](https://dev.mysql.com/doc/refman/8.4/en/innodb-locking-reads.html)
- 标准语法：`FOR SHARE` 或 `FOR UPDATE` 或 `LOCK IN SHARE MODE`
- 返回值类型：`PT_locking_clause` 对象（`locking_clause_list`）
- 使用场景：`SELECT` 表达式（`select_stmt` 语义组和 `select_stmt_with_into` 语义组）和子查询（`query_expression_with_opt_locking_clauses` 语义组）
- Bison 语法如下：

```C++
locking_clause_list:
          locking_clause_list locking_clause
          {
            $$= $1;
            if ($$->push_back($2))
              MYSQL_YYABORT; // OOM
          }
        | locking_clause
          {
            $$= NEW_PTN PT_locking_clause_list(@$, YYTHD->mem_root);
            if ($$ == nullptr || $$->push_back($1))
              MYSQL_YYABORT; // OOM
          }
        ;
```

#### 语义组：`lock_strength`

`lock_strength` 语义组用于解析 `UPDATE` 关键字或 `SHARE` 关键字。

- 官方文档：[MySQL 参考手册 - 17.7.2.4 Locking Reads](https://dev.mysql.com/doc/refman/8.4/en/innodb-locking-reads.html)
- 标准语法：`{UPDATE | SHARE}`
- 返回值类型：`Lock_strength` 枚举值（`lock_strength`），有 `UPDATE` 和 `SHARE` 两个枚举值
- Bison 语法如下：

```C++
lock_strength:
          UPDATE_SYM { $$= Lock_strength::UPDATE; }
        | SHARE_SYM  { $$= Lock_strength::SHARE; }
        ;
```

#### 语义组：`opt_locked_row_action`

`opt_locked_row_action` 语义组用于解析可选的 `SKIP LOCKED` 或 `NOWAIT`。

- 官方文档：[MySQL 参考手册 - 17.7.2.4 Locking Reads](https://dev.mysql.com/doc/refman/8.4/en/innodb-locking-reads.html)
- 标准语法：`[SKIP LOCKED | NOWAIT]`
- 返回值类型：`Locked_row_action` 枚举值（`locked_row_action`），有 `DEFAULT`、`WAIT`、`NOWAIT` 和 `SKIP` 四个枚举值
- Bison 语法如下：

```C++
opt_locked_row_action:
          %empty { $$= Locked_row_action::WAIT; }
        | locked_row_action
        ;
```

#### 语义组：`locked_row_action`

`locked_row_action` 语义组用于解析 `SKIP LOCKED` 或 `NOWAIT`。

- 官方文档：[MySQL 参考手册 - 17.7.2.4 Locking Reads](https://dev.mysql.com/doc/refman/8.4/en/innodb-locking-reads.html)
- 标准语法：`{SKIP LOCKED | NOWAIT}`
- 返回值类型：`Locked_row_action` 枚举值（`locked_row_action`），有 `DEFAULT`、`WAIT`、`NOWAIT` 和 `SKIP` 四个枚举值
- Bison 语法如下：

```C++
locked_row_action:
          SKIP_SYM LOCKED_SYM { $$= Locked_row_action::SKIP; }
        | NOWAIT_SYM { $$= Locked_row_action::NOWAIT; }
        ;
```

#### 语义组：`table_locking_list`

`table_locking_list` 语义组用于解析指定添加行锁的表，即 `OF` 引导的表名列表。

- 返回值类型：`Mem_root_array_YY<Table_ident *>`（`table_ident_list`）
- Bison语法如下：

```C++
table_locking_list:
          OF_SYM table_alias_ref_list { $$= $2; }
        ;
```

#### 语义组：`table_alias_ref_list`

`table_alias_ref_list` 语义组用于解析逗号分隔、任意数量的表名（`table_ident_opt_wild` 语义组）。

- 返回值类型：`Mem_root_array_YY<Table_ident *>`（`table_ident_list`）
- Bison语法如下：

```C++
table_alias_ref_list:
          table_ident_opt_wild
          {
            $$.init(YYMEM_ROOT);
            if ($$.push_back($1))
              MYSQL_YYABORT; // OOM
          }
        | table_alias_ref_list ',' table_ident_opt_wild
          {
            $$= $1;
            if ($$.push_back($3))
              MYSQL_YYABORT; // OOM
          }
        ;
```

#### 语义组：`table_ident_opt_wild`

`table_ident_opt_wild` 用于解析 `ident[.*]` 或 `ident.ident[.*]` 格式的表名。

- 返回值类型：`Table_ident` 对象（`table_ident`）
- 备选规则和 Bison语法如下：

| 备选规则                   | 备选规则含义                   |
| -------------------------- | ------------------------------ |
| `ident opt_wild`           | 解析标准语法 `ident[.*]`       |
| `ident '.' ident opt_wild` | 解析标准语法 `ident.ident[.*]` |

```C++
table_ident_opt_wild:
          ident opt_wild
          {
            $$= NEW_PTN Table_ident(to_lex_cstring($1));
            if ($$ == nullptr)
              MYSQL_YYABORT;
          }
        | ident '.' ident opt_wild
          {
            $$= NEW_PTN Table_ident(YYTHD->get_protocol(),
                                    to_lex_cstring($1),
                                    to_lex_cstring($3), 0);
            if ($$ == nullptr)
              MYSQL_YYABORT;
          }
        ;
```

#### 语义组：`opt_wild`

`opt_wild` 语义组用于解析可选的 `.*`。

- 返回值类型：没有返回值
- Bison 语法如下：

```C++
opt_wild:
          %empty
        | '.' '*'
        ;
```

