目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

下面我们梳理用于解析 `SHOW` 语句，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符，其中未展示其他使用 `opt_channel` 语义组的语义组）：

![语法解析 - 043 - SHOW 语句（BINLOG 和主从同步）](C:\blog\graph\MySQL源码剖析\语法解析 - 043 - SHOW 语句（BINLOG 和主从同步）.png)

#### 语义组：`show_binary_log_status_stmt`

`SHOW BINARY LOG STATUS` 语句用于读取服务器上 BINLOG 的状态信息。

- 官方文档：[MySQL 参考手册 - 15.7.7.1 SHOW BINARY LOG STATUS Statement](https://dev.mysql.com/doc/refman/8.4/en/show-binary-log-status.html)
- 标准语法：`SHOW BINARY LOG STATUS`
- 返回值类型：`Parse_tree_root` 对象（`top_level_node`），用于存储最顶层节点，即语句层级节点
- Bison 语法如下：

```C++
show_binary_log_status_stmt:
          SHOW BINARY_SYM LOG_SYM STATUS_SYM
          {
            $$ = NEW_PTN PT_show_binary_log_status(@$);
          }
        ;
```

#### 语义组：`show_binary_logs_stmt`

`SHOW BINARY LOGS` 语句用于列出了服务器上的 BIGLOG 文件。

- 官方文档：[MySQL 参考手册 - 15.7.7.2 SHOW BINARY LOGS Statement](https://dev.mysql.com/doc/refman/8.4/en/show-binary-logs.html)
- 标准语法：`SHOW BINARY LOGS`
- 返回值类型：`Parse_tree_root` 对象（`top_level_node`），用于存储最顶层节点，即语句层级节点
- Bison 语法如下：

```C++
show_binary_logs_stmt:
          SHOW master_or_binary LOGS_SYM
          {
            if (Lex->is_replication_deprecated_syntax_used())
            {
              push_deprecated_warn(YYTHD, "SHOW MASTER LOGS", "SHOW BINARY LOGS");
            }
            $$ = NEW_PTN PT_show_binlogs(@$);
          }
        ;
```

> `master_or_binary` 语义组用于解析 `MASTER` 关键字或 `BINARY` 关键字，详见下文。

#### 语义组：`master_or_binary`

`master_or_binary` 语义组用于解析 `MASTER` 关键字或 `BINARY` 关键字。

- 返回值类型：没有返回值
- Bison 语法如下：

```C++
master_or_binary:
          MASTER_SYM
          {
            Lex->set_replication_deprecated_syntax_used();
          }
        | BINARY_SYM
        ;
```

#### 语义组：`show_binlog_events_stmt`

`SHOW BINLOG EVENTS` 语句用于列出 BINLOG 日志中的事件，如果不指定 `log_name`，则展示第 1 个 BINLOG 日志文件。

- 官方文档：[MySQL 参考手册 - 15.7.7.3 SHOW BINLOG EVENTS Statement](https://dev.mysql.com/doc/refman/8.4/en/show-binlog-events.html)
- 标准语法：

```
SHOW BINLOG EVENTS
   [IN 'log_name']
   [FROM pos]
   [LIMIT [offset,] row_count]
```

- 返回值类型：`Parse_tree_root` 对象（`top_level_node`），用于存储最顶层节点，即语句层级节点
- Bison 语法如下：

```C++
show_binlog_events_stmt:
          SHOW BINLOG_SYM EVENTS_SYM opt_binlog_in binlog_from opt_limit_clause
          {
            $$ = NEW_PTN PT_show_binlog_events(@$, $4, $6);
          }
        ;
```

> `opt_binlog_in` 语义组用于解析可选的指定 BINLOG 文件的 `IN` 子句，详见下文；
>
> `binlog_from` 语义组用于解析可选的 BINLOG 文件中的位置，详见下文；
>
> `opt_limit_clause` 语义组用于解析可选的 `LIMIT` 子句，详见 [MySQL 源码｜78 - 语法解析(V2)：LIMIT 子句](https://zhuanlan.zhihu.com/p/720293254)。

#### 语义组：`opt_binlog_in`

`opt_binlog_in` 语义组用于解析可选的指定 BINLOG 文件的 `IN` 子句。

- 官方文档：[MySQL 参考手册 - 15.7.7.3 SHOW BINLOG EVENTS Statement](https://dev.mysql.com/doc/refman/8.4/en/show-binlog-events.html)
- 标准语法：`[IN 'log_name']`
- 返回值类型：`MYSQL_LEX_STRING` 对象，其中包含字符串指针和字符串长度
- Bison 语法如下：

```C++
opt_binlog_in:
          %empty                 { $$ = {}; }
        | IN_SYM TEXT_STRING_sys { $$ = $2; }
        ;
```

> `TEXT_STRING_sys` 语义组用于解析表示各种名称的单引号 / 双引号字符串，详见 [MySQL 源码｜65 - 语法解析(V2)：字符串字面值](https://zhuanlan.zhihu.com/p/717934287)。

#### 语义组：`binlog_from`

`binlog_from` 语义组用于解析可选的 BINLOG 文件中的位置。

- 官方文档：[MySQL 参考手册 - 15.7.7.3 SHOW BINLOG EVENTS Statement](https://dev.mysql.com/doc/refman/8.4/en/show-binlog-events.html)
- 标准语法：`[FROM pos]`
- 返回值类型：没有返回值
- Bison 语法如下：

```C++
binlog_from:
          %empty { Lex->mi.pos = 4; /* skip magic number */ }
        | FROM ulonglong_num { Lex->mi.pos = $2; }
        ;
```

> `ulonglong_num` 语义组用于解析十进制整数或小数，返回 unsigned long long int 类型，详见 [MySQL 源码｜67 - 语法解析(V2)：数值字面值](https://zhuanlan.zhihu.com/p/718508554)。

#### 语义组：`show_relaylog_events_stmt`

`SHOW RELAYLOG EVENTS` 语句用于列出中继日志中的事件，如果不指定 `log_name`，则展示第 1 个中继日志文件。MySQL 的中继日志用于主从同步，从实例的中继日志文件记录了从主实例接收到的事件，而 `SHOW RELAYLOG EVENTS` 语句用于查看这些事件。

- 官方文档：[MySQL 参考手册 - 15.7.7.34 SHOW RELAYLOG EVENTS Statement](https://dev.mysql.com/doc/refman/8.4/en/show-relaylog-events.html)
- 标准语法：

```
SHOW RELAYLOG EVENTS
    [IN 'log_name']
    [FROM pos]
    [LIMIT [offset,] row_count]
    [channel_option]

channel_option:
    FOR CHANNEL channel
```

- 返回值类型：`Parse_tree_root` 对象（`top_level_node`），用于存储最顶层节点，即语句层级节点
- Bison 语法如下：

```C++
show_relaylog_events_stmt:
          SHOW RELAYLOG_SYM EVENTS_SYM opt_binlog_in binlog_from opt_limit_clause
          opt_channel
          {
            $$ = NEW_PTN PT_show_relaylog_events(@$, $4, $6, $7);
          }
        ;
```

> `opt_binlog_in` 语义组用于解析可选的指定 BINLOG 文件的 `IN` 子句，详见上文；
>
> `binlog_from` 语义组用于解析可选的 BINLOG 文件中的位置，详见上文；
>
> `opt_limit_clause` 语义组用于解析可选的 `LIMIT` 子句，详见 [MySQL 源码｜78 - 语法解析(V2)：LIMIT 子句](https://zhuanlan.zhihu.com/p/720293254)；
>
> `opt_channel` 语义组用于解析可选的指定复制通道的 `FOR CHANNEL` 子句，如果指定复制通道或不存在额外的通道，则应用于默认通道，详见下文。

#### 语义组：`opt_channel`

`opt_channel` 语义组用于解析可选的指定复制通道的 `FOR CHANNEL` 子句，如果指定复制通道或不存在额外的通道，则应用于默认通道。

- 官方文档：[MySQL 参考手册 - 15.7.7.34 SHOW RELAYLOG EVENTS Statement](https://dev.mysql.com/doc/refman/8.4/en/show-relaylog-events.html)
- 标准语法：`FOR CHANNEL channel`
- 返回值类型：`MYSQL_LEX_CSTRING` 结构体，包含字符串的 const 指针和字符串长度
- Bison 语法如下：

```C++
opt_channel:
          %empty { $$ = {}; }
        | FOR_SYM CHANNEL_SYM TEXT_STRING_sys_nonewline
          { $$ = to_lex_cstring($3); }
        ;
```

> `TEXT_STRING_sys_nonewline` 语义组用于解析不包含换行符、表示各种名称的单引号 / 双引号字符串，详见 [MySQL 源码｜65 - 语法解析(V2)：字符串字面值](https://zhuanlan.zhihu.com/p/717934287)。

#### 语义组：`show_replica_status_stmt`

`SHOW REPLICA STATUS` 语句用于查看从实例上复制线程的关键参数的状态信息。

- 官方文档：[MySQL 参考手册 - 15.7.7.35 SHOW REPLICA STATUS Statement](https://dev.mysql.com/doc/refman/8.4/en/show-replica-status.html)
- 标准语法：`SHOW REPLICA STATUS [FOR CHANNEL channel]`
- 返回值类型：`Parse_tree_root` 对象（`top_level_node`），用于存储最顶层节点，即语句层级节点
- Bison 语法如下：

```C++
show_replica_status_stmt:
          SHOW replica STATUS_SYM opt_channel
          {
            if (Lex->is_replication_deprecated_syntax_used())
              push_deprecated_warn(YYTHD, "SHOW SLAVE STATUS", "SHOW REPLICA STATUS");
            $$ = NEW_PTN PT_show_replica_status(@$, $4);
          }
        ;
```

> `replica` 语义组用于解析 `SLAVE` 关键字或 `REPLICA` 关键字，详见下文；
>
> `opt_channel` 语义组用于解析可选的指定复制通道的 `FOR CHANNEL` 子句，如果指定复制通道或不存在额外的通道，则应用于默认通道，详见上文。

#### 语义组：`replica`

`replica` 语义组用于解析 `SLAVE` 关键字或 `REPLICA` 关键字。

- 返回值类型：没有返回值
- Bison 语法如下：

```C++
replica:
        SLAVE { Lex->set_replication_deprecated_syntax_used(); }
      | REPLICA_SYM
      ;
```

#### 语义组：`show_replicas_stmt`

`show_replicas_stmt` 语义组用于解析 `SHOW SLAVE HOSTS` 语句和 `SHOW REPLICAS` 语句，这两个语句均用于展示主实例上已经注册的所有副本（从实例）的列表。

- 官方文档：[MySQL 参考手册 - 15.7.7.36 SHOW REPLICAS Statement](https://dev.mysql.com/doc/refman/8.4/en/show-replicas.html)
- 标准语法：`SHOW REPLICAS`
- 返回值类型：`Parse_tree_root` 对象（`top_level_node`），用于存储最顶层节点，即语句层级节点
- Bison 语法如下：

```C++
show_replicas_stmt:
          SHOW SLAVE HOSTS_SYM
          {
            Lex->set_replication_deprecated_syntax_used();
            push_deprecated_warn(YYTHD, "SHOW SLAVE HOSTS", "SHOW REPLICAS");

            $$ = NEW_PTN PT_show_replicas(@$);
          }
        | SHOW REPLICAS_SYM
          {
            $$ = NEW_PTN PT_show_replicas(@$);
          }
        ;
```
