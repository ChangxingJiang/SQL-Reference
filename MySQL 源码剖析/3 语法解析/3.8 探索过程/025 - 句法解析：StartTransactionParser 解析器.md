目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[router/src/routing/src/start_transaction_parser.cc](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/start_transaction_parser.cc)

前置文档：[MySQL 源码｜22 - SQLParser 类及其子类](https://zhuanlan.zhihu.com/p/714760682)

---

### `StartTransactionParser` 解析器

`StartTransactionParser` 解析器主要解析 `START TRANSACTION` 语句、`BEGIN WORK` 语句和 `BEGIN` 语句。、

`StartTransactionParser` 解析方法的函数原型如下：

```C++
stdx::expected<std::variant<std::monostate, StartTransaction>, std::string>
StartTransactionParser::parse()
```

这个函数的返回值为将 `std::variant<std::monostate, StartTransaction>` 作为预期值的 `stdx::expected` 类型。

#### 以 `START TRANSACTION` 开头

当 SQL 以 `START` 开头时，若下一个 token 不是 `TRANSACTION`，则返回预期值为空空结果 `{}`。

若 SQL 以 `START TRANSACTION` 开头，则执行如下逻辑：

**Step 1**｜尝试解析 `WITH CONSISTENT SNAPSHOT`、`READ ONLY` 或 `READ WRITE`，如果匹配不到则返回不满足预期的字符串。

```C++
stdx::expected<std::variant<std::monostate, StartTransaction::AccessMode, bool>,
               std::string>
StartTransactionParser::transaction_characteristics() {
  if (accept(WITH)) {
    if (accept(CONSISTENT_SYM)) {
      if (accept(SNAPSHOT_SYM)) {
        return true;
      }
      return stdx::make_unexpected(
          "after WITH CONSISTENT only SNAPSHOT is allowed.");
    }
    return stdx::make_unexpected("after WITH only CONSISTENT is allowed.");
  }

  if (accept(READ_SYM)) {
    if (accept(ONLY_SYM)) {
      return StartTransaction::AccessMode::ReadOnly;
    }
    if (accept(WRITE_SYM)) {
      return StartTransaction::AccessMode::ReadWrite;
    }
    return stdx::make_unexpected("after READ only ONLY|WRITE are allowed.");
  }

  return {};
}
```

**Step 2**｜不断解析每个逗号之间的 token，直至无法匹配跳出循环或匹配结果异常返回不满足预期的字符串。

```C++
      do {
        auto trx_characteristics_res = transaction_characteristics();
        if (!trx_characteristics_res) {
          return stdx::make_unexpected(
              "You have an error in your SQL syntax; " +
              trx_characteristics_res.error());
        }

        auto trx_characteristics = *trx_characteristics_res;

        if (std::holds_alternative<std::monostate>(trx_characteristics)) {
          // no match.
          break;
        }

        if (std::holds_alternative<bool>(trx_characteristics)) {
          with_consistent_snapshot = true;
        }

        if (std::holds_alternative<StartTransaction::AccessMode>(
                trx_characteristics)) {
          if (access_mode) {
            return stdx::make_unexpected(
                "You have an error in your SQL syntax; START TRANSACTION only "
                "allows one access mode");
          }

          access_mode =
              std::get<StartTransaction::AccessMode>(trx_characteristics);
        }

        if (!accept(',')) break;
      } while (true);
```

**Step 3**｜如果在匹配完成后，SQL 语句已经结束，则返回预期值为 `{std::in_place, StartTransaction{access_mode, with_consistent_snapshot}}` 的结果，否则返回不满足预期的字符串。

```C++
      if (accept(END_OF_INPUT)) {
        return {std::in_place,
                StartTransaction{access_mode, with_consistent_snapshot}};
      }

      return stdx::make_unexpected(
          "You have an error in your SQL syntax; unexpected input near " +
          to_string(token()));
```

#### 以 `BEGIN` 开头

当 SQL 以 `BEGIN` 开头时：

- 若下一个 token 为 `WORK`，且 `WORK` 之后 SQL 已经结束，则返回 `{std::in_place, StartTransaction{}}`
- 若下一个 token 为 `WORK`，但 `WORK` 之后 SQL 没有结束，则返回不满足预期的字符串
- 若 `BEGIN` 之后 SQL 已经结束，则返回 `{std::in_place, StartTransaction{}}`
- 否则返回不满足预期的字符串

#### 其他 token 开头

当 SQL 不以 `START` 或 `BEGIN` 开头时，返回预期值为空结果 `{}`。
