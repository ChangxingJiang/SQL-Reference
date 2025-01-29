目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[router/src/routing/src/sql_splitting_allowed.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/sql_splitting_allowed.h)

前置文档：[MySQL 源码｜22 - SQLParser 类及其子类](https://zhuanlan.zhihu.com/p/714760682)

---

在 `SplittingAllowedParser` 中，定义了一个枚举类，枚举类中有 5 个枚举值，疑似是这些任务的执行权限，我们可以通过梳理这 5 个枚举值的使用场景来具体确定它们的含义。

```C++
  enum class Allowed {
    Always,
    InTransaction,
    OnlyReadWrite,
    OnlyReadOnly,
    Never,
  };
```

解析函数 `parse()` 的原型如下：

```C++
stdx::expected<SplittingAllowedParser::Allowed, std::string>
SplittingAllowedParser::parse()
```

其中通过使用分支结构逐个 token 调用 `accept` 枚举关键字，枚举了 SQL 语句开头的各种关键字组合，并根据关键字组合返回枚举值。例如 `accept(SHOW)` 函数可以判断下一个 token 是否为 `SHOW` 关键字，如果是则返回 True 并将迭代器向后一个移动 token，否则返回 False 且不移动迭代器中的位置。

如果某个语法不存在，则会返回 `Allowed::Never`，这些不存在的语法在具体梳理时不再列出。

涉及的 MySQL 官方文档如下：

- [MySQL :: MySQL 8.4 Reference Manual :: 15.1 Data Definition Statements](https://dev.mysql.com/doc/refman/8.4/en/sql-data-definition-statements.html)
- [MySQL :: MySQL 8.4 Reference Manual :: 15.7.1 Account Management Statements](https://dev.mysql.com/doc/refman/8.4/en/account-management-statements.html)
- [MySQL :: MySQL 8.4 Reference Manual :: 15.7.7 SHOW Statements](https://dev.mysql.com/doc/refman/en/show.html)

#### `SHOW` 开头的表达式

```C++
  if (accept(SHOW)) {
    // https://dev.mysql.com/doc/refman/en/show.html
    //
    if (                          // BINARY: below
                                  // BINLOG: below
        accept(CHAR_SYM) ||       // CHARACTER
        accept(CHARSET) ||        //
        accept(COLLATION_SYM) ||  //
        accept(COLUMNS) ||        //
        accept(CREATE) ||         //
        accept(DATABASES) ||      //
                                  // ENGINE: below
        accept(ENGINES_SYM) ||    //
        accept(ERRORS) ||         //
        accept(EVENTS_SYM) ||     //
        accept(FUNCTION_SYM) ||   //
        accept(GRANTS) ||         //
        accept(INDEX_SYM) ||      //
                                  // MASTER STATUS: below
                                  // OPEN TABLES: below
        accept(PLUGINS_SYM) ||    //
        accept(PRIVILEGES) ||     //
        accept(PROCEDURE_SYM) ||  //
                                  // PROCESSLIST: below
                                  // PROFILE: below
                                  // PROFILES: below
                                  // RELAYLOG: below
                                  // REPLICA: below
                                  // REPLICAS: below
                                  // SLAVE: below
        accept(STATUS_SYM) ||     //
        accept(TABLE_SYM) ||      //
        accept(TABLES) ||         //
        accept(TRIGGERS_SYM) ||   //
        accept(VARIABLES) ||      //
        accept(WARNINGS)) {
      return Allowed::Always;
    }

    // per instance commands
    if (accept(ENGINE_SYM) ||       //
        accept(OPEN_SYM) ||         // OPEN TABLES
        accept(PLUGINS_SYM) ||      //
        accept(PROCESSLIST_SYM) ||  //
        accept(PROFILES_SYM) ||     //
        accept(PROFILE_SYM)) {
      return Allowed::InTransaction;
    }

    if (accept(GLOBAL_SYM)) {
      if (accept(VARIABLES)) {
        return Allowed::Always;
      }
      if (accept(STATUS_SYM)) {
        return Allowed::InTransaction;
      }

      return Allowed::Never;
    }

    // Write-only
    if (accept(BINARY_SYM) ||  //
        accept(MASTER_SYM) ||  //
        accept(REPLICAS_SYM)) {
      return Allowed::OnlyReadWrite;
    }

    // Read-only
    if (accept(BINLOG_SYM) ||    //
        accept(RELAYLOG_SYM) ||  //
        accept(REPLICA_SYM)      //
    ) {
      return Allowed::OnlyReadOnly;
    }

    if (accept(SLAVE)) {
      if (accept(STATUS_SYM)) {
        return Allowed::OnlyReadOnly;
      }

      if (accept(HOSTS_SYM)) {
        return Allowed::OnlyReadWrite;
      }

      return Allowed::Never;
    }

    // SHOW [EXTENDED] [FULL] COLUMNS|FIELDS

    if (accept(EXTENDED_SYM)) {
      accept(FULL);

      if (accept(COLUMNS)) {  // FIELDS and COLUMNS both resolve to COLUMNS
        return Allowed::Always;
      }

      return Allowed::Never;
    } else if (accept(FULL)) {
      if (accept(COLUMNS) || accept(TABLES)) {
        return Allowed::Always;
      } else if (accept(PROCESSLIST_SYM)) {
        return Allowed::InTransaction;
      }

      return Allowed::Never;
    }

    // SHOW [STORAGE] ENGINES
    if (accept(STORAGE_SYM)) {
      if (accept(ENGINES_SYM)) {
        return Allowed::Always;
      }

      return Allowed::Never;
    }

    if (accept(SESSION_SYM)) {
      if (accept(STATUS_SYM) || accept(VARIABLES)) {
        return Allowed::Always;
      }
    }

    return Allowed::Never;
  }
```

| 表达式                                                       | 返回值                                                       |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| `SHOW BINARY LOG STATUS`                                     | `Allowed::OnlyReadWrite`【Write-only】                       |
| `SHOW BINARY LOGS`                                           | `Allowed::OnlyReadWrite`【Write-only】                       |
| `SHOW BINLOG EVENTS`                                         | `Allowed::OnlyReadOnly`【Read-only】                         |
| `SHOW CHARACTER SET`                                         | `Allowed::Always`                                            |
| `SHOW COLLATION`                                             | `Allowed::Always`                                            |
| `SHOW [FULL] COLUMNS`                                        | `Allowed::Always`                                            |
| `SHOW CREATE DATABASE/EVENT/FUNCTION/PROCEDURE/TABLE/USER/VIEW` | `Allowed::Always`                                            |
| `SHOW DATABASES`                                             | `Allowed::Always`                                            |
| `SHOW ENGINE`                                                | `Allowed::InTransaction`                                     |
| `SHOW [STORAGE] ENGINES`                                     | `Allowed::Always`                                            |
| `SHOW ERRORS`                                                | `Allowed::Always`                                            |
| `SHOW EVENTS`                                                | `Allowed::Always`                                            |
| `SHOW EXTENDED FULL COLUMNS`（不在 8.4 版本 MySQL 手册中）   | `Allowed::Always`                                            |
| `SHOW FUNCTION CODE/STATUS`                                  | `Allowed::Always`                                            |
| `SHOW GRANTS`                                                | `Allowed::Always`                                            |
| `SHOW INDEX`                                                 | `Allowed::Always`                                            |
| `SHOW MASTER`（不在 8.4 版本 MySQL 手册中）                  | `Allowed::OnlyReadWrite`【Write-only】                       |
| `SHOW OPEN TABLES`                                           | `Allowed::InTransaction`                                     |
| `SHOW PLUGINS`                                               | `Allowed::Always`                                            |
| `SHOW PRIVILEGES`                                            | `Allowed::Always`                                            |
| `SHOW PROCEDURE CODE/STATUS`                                 | `Allowed::Always`                                            |
| `SHOW [FULL] PROCESSLIST`                                    | `Allowed::InTransaction`                                     |
| `SHOW PROFILE`                                               | `Allowed::InTransaction`                                     |
| `SHOW PROFILES`                                              | `Allowed::InTransaction`                                     |
| `SHOW RELAYLOG EVENTS`                                       | `Allowed::OnlyReadOnly`【Read-only】                         |
| `SHOW REPLICA STATUS`                                        | `Allowed::OnlyReadOnly`【Read-only】                         |
| `SHOW REPLICAS`                                              | `Allowed::OnlyReadWrite`【Write-only】                       |
| `SHOW SLAVE HOSTS`（不在 8.4 版本 MySQL 手册中）             | `Allowed::OnlyReadWrite`                                     |
| `SHOW [GLOBAL|SESSION|SLAVE] STATUS`（`SLAVE` 关键字不在 8.4 版本的 MySQL 手册中） | `Allowed::Always`（添加 GLOBAL 关键字时返回 `Allowed::InTransaction`，添加 `SLAVE` 关键字时返回 `Allowed::OnlyReadOnly`） |
| `SHOW TABLE STATUS`                                          | `Allowed::Always`                                            |
| `SHOW [FULL] TABLES`                                         | `Allowed::Always`                                            |
| `SHOW TRIGGERS`                                              | `Allowed::Always`                                            |
| `SHOW [GLOBAL|SESSION] VARIABLES`                            | `Allowed::Always`                                            |
| `SHOW WARNINGS`                                              | `Allowed::Always`                                            |

#### `CREATE` / `ALTER` 开头的表达式

```C++
  else if (accept(CREATE) || accept(ALTER)) {
    if (accept(DATABASE) ||        //
        accept(EVENT_SYM) ||       //
        accept(FUNCTION_SYM) ||    //
        accept(INDEX_SYM) ||       //
                                   // INSTANCE
        accept(PROCEDURE_SYM) ||   //
                                   // SERVER
        accept(SPATIAL_SYM) ||     //
        accept(TABLE_SYM) ||       //
        accept(TABLESPACE_SYM) ||  //
        accept(TRIGGER_SYM) ||     //
        accept(VIEW_SYM) ||        //
        accept(USER) ||            //
        accept(ROLE_SYM)           //
    ) {
      return Allowed::Always;
    }

    if (accept(AGGREGATE_SYM)) {
      // CREATE AGGREGATE FUNCTION
      if (accept(FUNCTION_SYM)) {
        return Allowed::Always;
      }

      return Allowed::Never;
    }

    if (accept(ALGORITHM_SYM)) {
      // CREATE ALGORITHM = ... VIEW
      return Allowed::Always;
    }

    if (accept(DEFINER_SYM)) {
      // CREATE DEFINER = ... PROCEDURE|FUNCTION|EVENT|VIEW
      return Allowed::Always;
    }

    if (accept(OR_SYM)) {
      // CREATE OR REPLACE ... VIEW|SPATIAL REFERENCE SYSTEM
      if (accept(REPLACE_SYM)) {
        return Allowed::Always;
      }

      return Allowed::Never;
    }

    if (accept(SQL_SYM)) {
      // CREATE SQL SECURITY ... VIEW
      return Allowed::Always;
    }

    if (accept(TEMPORARY)) {
      // CREATE TEMPORARY TABLE
      if (accept(TABLE_SYM)) {
        return Allowed::Always;
      }

      return Allowed::Never;
    }

    if (accept(UNDO_SYM)) {
      // CREATE UNDO TABLESPACE
      if (accept(TABLESPACE_SYM)) {
        return Allowed::Always;
      }

      return Allowed::Never;
    }

    if (accept(UNIQUE_SYM) || accept(FULLTEXT_SYM) || accept(SPATIAL_SYM)) {
      // CREATE UNIQUE|FULLTEXT|SPATIAL INDEX
      if (accept(INDEX_SYM)) {
        return Allowed::Always;
      }
      return Allowed::Never;
    }

    // SERVER
    // INSTANCE
    // LOGFILE GROUP

    return Allowed::Never;
  }
```

| 表达式                                                       | 返回值            |
| ------------------------------------------------------------ | ----------------- |
| `ALTER DATABASE`                                             | `Allowed::Always` |
| `ALTER EVENT`                                                | `Allowed::Always` |
| `ALTER [AGGREGATE] FUNCTION`                                 | `Allowed::Always` |
| `ALTER INSTANCE`                                             | `Allowed::Never`  |
| `ALTER LOGFILE GROUP`                                        | `Allowed::Never`  |
| `ALTER PROCEDURE`                                            | `Allowed::Always` |
| `ALTER SERVER`                                               | `Allowed::Never`  |
| `ALTER TABLE`                                                | `Allowed::Always` |
| `ALTER TABLESPACE`                                           | `Allowed::Always` |
| `ALTER [ALGORITHM={UNDEFINED|MERGE|TEMPTABLE}][DEFINER][SQL SECURITY] VIEW` | `Allowed::Always` |
| `ALTER USER`                                                 | `Allowed::Always` |
| `CREATE DATABASE`                                            | `Allowed::Always` |
| `CREATE EVENT`                                               | `Allowed::Always` |
| `CREATE [AGGREGATE] FUNCTION`                                | `Allowed::Always` |
| `CREATE [UNIQUE|FULLTEXT|SPATIAL] INDEX`                     | `Allowed::Always` |
| `CREATE LOGFILE GROUP`                                       | `Allowed::Never`  |
| `CREATE PROCEDURE`                                           | `Allowed::Always` |
| `CREATE SERVER`                                              | `Allowed::Never`  |
| `CREATE SPATIAL REFERENCE SYSTEM`                            | `Allowed::Always` |
| `CREATE [TEMPORARY] TABLE`                                   | `Allowed::Always` |
| `CREATE [UNDO] TABLESPACE`                                   | `Allowed::Always` |
| `CREATE TRIGGER`                                             | `Allowed::Always` |
| `CREATE [ALGORITHM={UNDEFINED|MERGE|TEMPLATE}][DEFINER][SQL SECURITY][SQL SECURITY] VIEW` | `Allowed::Always` |
| `CREATE OR REPLACE ...`                                      | `Allowed::Always` |
| `CREATE ROLE`                                                | `Allowed::Always` |
| `CREATE USER`                                                | `Allowed::Always` |

#### `DROP` 开头的表达式

```C++
  else if (accept(DROP)) {
    if (accept(DATABASE) ||        //
        accept(EVENT_SYM) ||       //
        accept(FUNCTION_SYM) ||    //
        accept(INDEX_SYM) ||       //
                                   // INSTANCE
        accept(PROCEDURE_SYM) ||   //
                                   // SERVER
        accept(SPATIAL_SYM) ||     //
                                   // TEMPORARY: below
        accept(TABLE_SYM) ||       //
        accept(TABLESPACE_SYM) ||  //
        accept(TRIGGER_SYM) ||     //
        accept(VIEW_SYM) ||        //
        accept(USER) ||            //
        accept(ROLE_SYM)           //
    ) {
      return Allowed::Always;
    }

    if (accept(TEMPORARY)) {
      // CREATE TEMPORARY TABLE
      if (accept(TABLE_SYM)) {
        return Allowed::Always;
      }

      return Allowed::Never;
    }

    // - SERVER
    // - INSTANCE

    return Allowed::Never;
  }
```

| 表达式                          | 返回值            |
| ------------------------------- | ----------------- |
| `DROP DATABASE`                 | `Allowed::Always` |
| `DROP EVENT`                    | `Allowed::Always` |
| `DROP FUNCTION`                 | `Allowed::Always` |
| `DROP INDEX`                    | `Allowed::Always` |
| `DROP LOGFILE GROUP`            | `Allowed::Never`  |
| `DROP PRODUCEDURE`              | `Allowed::Always` |
| `DROP SERVER`                   | `Allowed::Never`  |
| `DROP SPATIAL REFERENCE SYSTEM` | `Allowed::Always` |
| `DROP [TEMPORARY] TABLE`        | `Allowed::Always` |
| `DROP TABLESPACE`               | `Allowed::Always` |
| `DROP TRIGGER`                  | `Allowed::Always` |
| `DROP VIEW`                     | `Allowed::Always` |
| `DROP ROLE`                     | `Allowed::Always` |
| `DROP USER`                     | `Allowed::Always` |

#### 各类根据开头就可以判断返回 `Allowed::Always` 的表达式

```C++
  else if (                // read-only statements
      accept(SELECT_SYM) ||  //
      accept(WITH) ||        //
      accept(TABLE_SYM) ||   //
      accept(DO_SYM) ||      //
      accept(VALUES) ||      //
      accept(USE_SYM) ||     //
      accept(DESC) ||        //
      accept(DESCRIBE) ||    //
      accept(HELP_SYM) ||

      // DML
      accept(CALL_SYM) ||     //
      accept(INSERT_SYM) ||   //
      accept(UPDATE_SYM) ||   //
      accept(DELETE_SYM) ||   //
      accept(REPLACE_SYM) ||  //
      accept(TRUNCATE_SYM) ||

      // User management
      accept(GRANT) ||   //
      accept(REVOKE) ||  //

      // transaction and locking
      accept(BEGIN_SYM) ||      //
      accept(COMMIT_SYM) ||     //
      accept(RELEASE_SYM) ||    //
      accept(ROLLBACK_SYM) ||   //
      accept(SAVEPOINT_SYM) ||  //
                                // START is below.
      accept(XA_SYM) ||         //

      // import
      accept(IMPORT)) {
    return Allowed::Always;
  }
```

| 表达式               | 返回值            |
| -------------------- | ----------------- |
| `SELECT`（只读）     | `Allowed::Always` |
| `WITH`（只读）       | `Allowed::Always` |
| `TABLE`（只读）      | `Allowed::Always` |
| `DO`（只读）         | `Allowed::Always` |
| `VALUES`（只读）     | `Allowed::Always` |
| `USE`（只读）        | `Allowed::Always` |
| `DESC`（只读）       | `Allowed::Always` |
| `DESCRIBE`（只读）   | `Allowed::Always` |
| `HELP`（只读）       | `Allowed::Always` |
| `CALL`（DML）        | `Allowed::Always` |
| `INSERT`（DML）      | `Allowed::Always` |
| `UPDATE`（DML）      | `Allowed::Always` |
| `DELETE`（DML）      | `Allowed::Always` |
| `REPLACE`（DML）     | `Allowed::Always` |
| `TRUNCATE`（DML）    | `Allowed::Always` |
| `GRANT`（用户管理）  | `Allowed::Always` |
| `REVOKE`（用户管理） | `Allowed::Always` |
| `BEGIN`（事务）      | `Allowed::Always` |
| `COMMIT`（事务）     | `Allowed::Always` |
| `RELEASE`（事务）    | `Allowed::Always` |
| `ROLLBACK`（事务）   | `Allowed::Always` |
| `SAVEPOINT`（事务）  | `Allowed::Always` |
| `XA`（事务）         | `Allowed::Always` |
| `IMPORT`             | `Allowed::Always` |

#### 其他开头的表达式

- 当以 `FLUSH` 开头时：
  - 若下一个 token 为 `NO_WRITE_TO_BINLOG` 或 `LOCAL`，则返回 `Allowed::Never`
  - 若下一个 token 为 `TABLES`，则遍历后续 token；若其中包含 `WITH` 和 `FOR` 则返回 `Allowed::Never`，否则返回 `Allowed::Always`
  - 若下一个 token 不是 `NO_WRITE_TO_BINLOG`、`LOCAL` 或 `TABLES`，则继续遍历后续 token；若 `,` 之后为 `LOGS` 则返回 `Allowed::Never`，否则返回 `Allowed::Always`

```C++
  else if (accept(FLUSH_SYM)) {
    // FLUSH flush_option [, flush option]
    //
    // Not replicated:
    //
    // - if LOCAL or NO_WRITE_TO_BINLOG is specified
    // - LOGS
    // - TABLES ... FOR EXPORT
    // - TABLES WITH READ LOCK

    if (accept(NO_WRITE_TO_BINLOG) || accept(LOCAL_SYM)) {
      return Allowed::Never;
    }

    if (accept(TABLES)) {
      while (auto tkn = accept_if_not(END_OF_INPUT)) {
        // FOR EXPORT
        // WITH READ LOCK
        if (tkn.id() == WITH || tkn.id() == FOR_SYM) return Allowed::Never;
      }

      return Allowed::Always;
    }

    TokenText last_tkn;

    // check for LOGS (after FLUSH ... or after ',')
    while (auto tkn = accept_if_not(END_OF_INPUT)) {
      if (tkn.id() == LOGS_SYM) {
        if (last_tkn.id() == ',' || last_tkn.id() == 0) {
          return Allowed::Never;
        }
      }

      last_tkn = tkn;
    }

    return Allowed::Always;
  }
```

- 当以 `LOCK` 和 `UNLOCK` 开头时，直接返回 `Allowed::Never`

```C++
  else if (accept(LOCK_SYM) || accept(UNLOCK_SYM)) {
    // per instance, not replicated.
    return Allowed::Never;
  }
```

- 当以 `LOAD` 开头时，若下一个 token 为 `XML` 或 `DATA` 则返回 `Allowed::Always`，否则返回 `Allowed::Never`

```C++
  else if (accept(LOAD)) {
    if (accept(XML_SYM) || accept(DATA_SYM)) {
      return Allowed::Always;
    }

    return Allowed::Never;
  }
```

- 当以 `RENAME` 开头时，若下一个 token 为 `USER` 或 `TABLE`，则返回 `Allowed::Always`，否则返回 `Allowed::Never`

```C++
  else if (accept(RENAME)) {
    if (accept(USER) || accept(TABLE_SYM)) {
      return Allowed::Always;
    }

    return Allowed::Never;
  }
```

- 当以 `SET` 开头时：
  - 若下一个 token 为 `PASSWORD`、`TRANSACTION`、`DEFAULT`、`NAMES`、`CHAR`，则返回 `Allowed::Always`
  - 若下一个 token 为 `RESOURCE`，则返回 `Allowed::Never`
  - 若下一个 token 不是 `PASSWORD`、`TRANSACTION`、`DEFAULT`、`NAMES`、`CHAR` 或 `RESOURCE`，则继续遍历后续 token；若在未出现 `,` 或 `,` 后未出现 `SET` 和 `EQ` 的情况下，遇到  `GLOBAL`、`PERSIST_ONLY` 或 `PERSIST`，则返回 `Allowed::Never`
  - 否则返回 `Allowed::Always`

```C++
  else if (accept(SET_SYM)) {
    // exclude:
    // - SET RESOURCE GROUP: not replicated
    // - SET GLOBAL
    // - SET PERSIST
    if (accept(PASSWORD) ||         // SET PASSWORD = ...
        accept(TRANSACTION_SYM) ||  // SET TRANSACTION READ ONLY
        accept(DEFAULT_SYM) ||      // SET DEFAULT ROLE
        accept(NAMES_SYM) ||        // SET NAMES
        accept(CHAR_SYM)            // SET CHARACTER SET
    ) {
      return Allowed::Always;
    }

    if (accept(RESOURCE_SYM)) {
      return Allowed::Never;
    }

    // forbid SET GLOBAL, but allow SET foo = @@GLOBAL.foo;
    bool is_lhs{true};

    while (auto tkn = accept_if_not(END_OF_INPUT)) {
      if (tkn.id() == SET_VAR || tkn.id() == EQ) {
        // after := or = is the right-hand-side
        is_lhs = false;
      } else if (tkn.id() == ',') {
        // after , back to left-hand-side
        is_lhs = true;
      }

      if (is_lhs && (tkn.id() == GLOBAL_SYM || tkn.id() == PERSIST_ONLY_SYM ||
                     tkn.id() == PERSIST_SYM)) {
        return Allowed::Never;
      }
    }

    return Allowed::Always;
  }
```

- 当以 `START` 开头时，若下一个 token 为 `TRANSACTION` 则返回 `Allowed::Always`，否则返回 `Allowed::Never`

```C++
  else if (accept(START_SYM)) {
    // exclude GROUP_REPLICATION|REPLICAS
    if (accept(TRANSACTION_SYM)) {
      return Allowed::Always;
    }
    return Allowed::Never;
  }
```

- 当以 `CHECKSUM` 或 `CHECK` 开头时，若下一个 token 为 `TABLE` 则返回 `Allowed::Always`，否则返回 `Allowed::Never`

```C++
  else if (accept(CHECKSUM_SYM) || accept(CHECK_SYM)) {
    if (accept(TABLE_SYM)) {
      return Allowed::Always;
    }
    return Allowed::Never;
  }
```

- 当以 `ANALYZE`、`OPTIMIZE` 或 `REPAIR` 开头时，若下一个 token 为 `TABLE`，则返回 `Allowed::Always`，否则返回 `Allowed::Never`

```C++
  else if (accept(ANALYZE_SYM) || accept(OPTIMIZE) || accept(REPAIR)) {
    if (accept(NO_WRITE_TO_BINLOG) || accept(LOCAL_SYM)) {
      // ignore LOCAL and NO_WRITE_TO_BINLOG
    }

    if (accept(TABLE_SYM)) {
      return Allowed::Always;
    }
    return Allowed::Never;
  }
```

- 当以 `(` 开头时，直接返回 `Allowed::Always`

```C++
  else if (accept('(')) {
    return Allowed::Always;
  }
```

- 当以 `BINLOG` 开头时，直接返回 `Allowed::Always`

```C++
  else if (accept(BINLOG_SYM)) {
    return Allowed::Always;
  }
```

- 否则，返回 `Allowed::Never`

```C++
  return Allowed::Never;
```

