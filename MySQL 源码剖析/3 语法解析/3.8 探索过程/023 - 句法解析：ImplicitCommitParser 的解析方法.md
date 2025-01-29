目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[router/src/routing/src/implicit_commit_parser.cc](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/implicit_commit_parser.cc)

前置文档：[MySQL 源码｜22 - SQLParser 类及其子类](https://zhuanlan.zhihu.com/p/714760682)

---

`ImplicitCommitParser` 解析方法的函数原型如下：

```C++
stdx::expected<bool, std::string> ImplicitCommitParser::parse(
    std::optional<classic_protocol::session_track::TransactionState>
        trx_state)
```

在函数成员 `parse` 中，实现了通过解析 SQL 语句中的 token，判断是否需要在事务中隐式提交的逻辑。如果需要隐式提交，则返回 true，否则返回 false。函数接收一个参数，为当前事务的状态 `trx_state`。

解析函数的执行逻辑如下：

**Step 1**｜如果当前事务状态 `trx_state` 为假值，则抛出异常信息的文本。

```C++
  if (!trx_state) return stdx::unexpected("Expected trx-state to be set.");
```

**Step 2**｜如果当前事务状态的类型为 `_`，即说明不在事务中，不需要提交，直接返回 false。

```C++
  // no transaction, nothing to commit.
  if (trx_state->trx_type() == '_') return false;
```

**Step 3**｜逐个解析 SQL 语句开头的 token，枚举了 SQL 语句开头的各种关键字组合，并根据关键字组合返回布尔值。具体地：

- 当以 `ALTER` 开头时，若下一个 token 为 `EVENT`、`FUNCTION`、`PROCEDURE`、`SERVER`、`TABLE`、`TABLESPACE`、`VIEW` 或 `USER` 返回 true，否则返回 false

```C++
  if (accept(ALTER)) {
    if (accept(EVENT_SYM) ||       //
        accept(FUNCTION_SYM) ||    //
        accept(PROCEDURE_SYM) ||   //
        accept(SERVER_SYM) ||      //
        accept(TABLE_SYM) ||       //
        accept(TABLESPACE_SYM) ||  //
        accept(VIEW_SYM) ||        //
        accept(USER) ||            //
        false) {
      return true;
    }

    return false;
  }
```

- 当以 `CREATE` 或 `DROP` 开头时，若下一个 token 为 `DATEBASE`、`EVENT`、`FUNCTION`、`INDEX`、`PROCEDURE`、`ROLE`、`SERVER`、`SPATIAL`、`TABLE`、`TABLESPACE`、`TRIGGER`、`VIEW`、`USER` 则返回 true，否则返回 false

```C++
  if (accept(CREATE) || accept(DROP)) {
    if (accept(DATABASE) ||        //
        accept(EVENT_SYM) ||       //
        accept(FUNCTION_SYM) ||    //
        accept(INDEX_SYM) ||       //
        accept(PROCEDURE_SYM) ||   //
        accept(ROLE_SYM) ||        //
        accept(SERVER_SYM) ||      //
        accept(SPATIAL_SYM) ||     //
        accept(TABLE_SYM) ||       //
        accept(TABLESPACE_SYM) ||  //
        accept(TRIGGER_SYM) ||     //
        accept(VIEW_SYM) ||        //
        accept(USER) ||            //
        false) {
      return true;
    }

    return false;
  }
```

- 若以 `GRANT`、`REVOKE`、`TRUNCATE` 开头，则直接返回 true

```C++
  if (accept(GRANT) || accept(REVOKE) || accept(TRUNCATE_SYM)) {
    return true;
  }
```

- 当以 `RENAME` 开头时，若下一个 token 为 `USER` 或 `TABLE` 则返回 true，否则返回 false

```C++
  if (accept(RENAME)) {
    if (accept(USER) || accept(TABLE_SYM)) {
      return true;
    }
    return false;
  }
```

- 当以 `INSTALL` 或 `UNINSTALL` 开头时，若下一个 token 为 `PLUGIN` 则返回 true，否则返回 false

```C++
  if (accept(INSTALL_SYM) || accept(UNINSTALL_SYM)) {
    if (accept(PLUGIN_SYM)) {
      return true;
    }
    return false;
  }
```

- 当以 `SET` 开头时，若下一个 token 为 `PASSWORD` 则返回 true，否则返回 false

```C++
  if (accept(SET_SYM)) {
    if (accept(PASSWORD)) {
      return true;
    }
    return false;
  }
```

- 当以 `BEGIN` 开头时，直接返回 true

```C++
  if (accept(BEGIN_SYM)) {
    return true;
  }
```

- 当以 `START` 开头时，若下一个 token 为 `TRANSACTION`、`REPLICA` 或 `SLAVE` 则返回 true，否则返回 false

```C++
  if (accept(START_SYM)) {
    if (accept(TRANSACTION_SYM) || accept(REPLICA_SYM) || accept(SLAVE)) {
      return true;
    }
    return false;
  }
```

- 当以 `STOP` 开头时，若下一个 token为 `REPLICA` 或 `SLAVE` 则返回 true，否则返回 false

```C++
  if (accept(STOP_SYM)) {
    if (accept(REPLICA_SYM) || accept(SLAVE)) {
      return true;
    }
    return false;
  }
```

- 当以 `CHANGE` 开头时，若下一个 token 为 `MASTER` 或 `REPLICATION` 则返回 true，否则返回 false

```C++
  if (accept(CHANGE)) {
    if (accept(MASTER_SYM) || accept(REPLICATION)) {
      return true;
    }
    return false;
  }
```

- 当以 `LOCK` 开头时，若下一个 token 为 `TABLES` 则返回 true，否则返回 false

```C++
  if (accept(LOCK_SYM)) {
    if (accept(TABLES)) {
      return true;
    }

    return false;
  }
```

- 当以 `UNLOCK` 开头时，若下一个 token 为 `TABLES` 且当前事务中有表正在被锁表时，返回 true，否则返回 false

```C++
  if (accept(UNLOCK_SYM)) {
    if (accept(TABLES)) {
      // UNLOCK TABLES only commits if there is a table locked and a transaction
      // open.
      return trx_state->locked_tables() != '_';
    }

    return false;
  }
```

- 当以 `ANALYZE` 开头时，若下一个 token 为 `TABLE`，则返回 true，否则返回 false

```C++
  if (accept(ANALYZE_SYM)) {
    if (accept(TABLE_SYM)) {
      return true;
    }

    return false;
  }
```

- 当以 `CACHE` 开头时，若下一个 token 为 `INDEX`，则返回 true，否则返回 false

```C++
  if (accept(CACHE_SYM)) {
    if (accept(INDEX_SYM)) {
      return true;
    }

    return false;
  }
```

- 当以 `CHECK`、`OPTIMIZE` 或 `REPAIR` 开头时，若下一个 token 为 `TABLE`，则返回 true，否则返回 false

```C++
  if (accept(CHECK_SYM) || accept(OPTIMIZE) || accept(REPAIR)) {
    if (accept(TABLE_SYM)) {
      return true;
    }

    return false;
  }
```

- 当以 `FLUSH` 开头时，直接返回 true

```C++
  if (accept(FLUSH_SYM)) {
    return true;
  }
```

- 当以 `LOAD` 开头时，若之后 3 个 token 依次为 `INDEX INTO CACHE` 时返回 true，否则返回 false

```C++
  // LOAD INDEX INTO CACHE
  if (accept(LOAD)) {
    return (accept(INDEX_SYM) && accept(INTO) && accept(CACHE_SYM));
  }
```

- 当以 `RESET` 开头时，若下一个 token 为 `PERSIST` 则返回 true，否则返回 false

```C++
  // RESET, except RESET PERSIST
  if (accept(RESET_SYM)) {
    if (accept(PERSIST_SYM)) {
      return false;
    }

    return true;
  }
```

- 除以上场景外，例如 `SELECT` 开头的 DQL 语句以及 `UPDATE`、`DELETE` 等开头的 DML 语句均返回 false

```C++
  return false;
```

