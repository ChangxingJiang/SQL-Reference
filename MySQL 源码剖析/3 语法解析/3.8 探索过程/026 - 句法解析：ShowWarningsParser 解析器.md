目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[router/src/routing/src/show_warnings_parser.cc](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/show_warnings_parser.cc)

前置文档：[MySQL 源码｜22 - SQLParser 类及其子类](https://zhuanlan.zhihu.com/p/714760682)

---

### `ShowWarningsParser` 解析器

`ShowWarningsParser` 解析方法的函数原型如下：

```C++
stdx::expected<std::variant<std::monostate, ShowWarningCount, ShowWarnings>,
               std::string>
ShowWarningsParser::parse()
```

这个函数的返回值为将 `std::variant<std::monostate, ShowWarningCount, ShowWarnings>` 作为预期值的 `stdx::expected` 类型。

解析函数逻辑如下：

- 若第 1 个 token 为 `SHOW`：

  - 若第 2 个 token 为 `WARNINGS`：
    - 此时若下一个 token 为 `LIMIT` 则尝试解析 `limit` 子句（详见下面 "LIMIT 子句解析"），若 SQL 已结束，则返回 `{std::in_place,ShowWarnings{ShowWarnings::Verbosity::Warning, limit_res->row_count, limit_res->offset}}`，否则返回 `{}`
    - 若下一个 token 不是 `LIMIT`，且 SQL 已结束则返回 `{std::in_place, ShowWarnings{ShowWarnings::Verbosity::Warning}}`，否则返回 `{}`

  - 若第 2 个 token 为 `ERRORS`：逻辑与第 2 个 `token` 为 `WARNINGS` 类似，只是将 `ShowWarnings` 的第 1 个参数替换为 `ShowWarningCount::Verbosity::Error`
  - 若第 2 - 5 个 token 依次为 `COUNT`、`(`、`*`、`)`：
    - 若下一个 token 为 `WARNINGS`：若此时 SQL 已结束，则返回 `return {std::in_place, ShowWarningCount{ShowWarningCount::Verbosity::Warning, ShowWarningCount::Scope::Session}};`；否则返回 `{}`
    - 若下一个 token 为 `ERRORS`：若此时 SQL 已结束，则返回 `return {std::in_place, ShowWarningCount{ShowWarningCount::Verbosity::Error, ShowWarningCount::Scope::Session}};`；否则返回 `{}`
    - 否则，返回 `{}`

```C++
  if (accept(SHOW)) {
    if (accept(WARNINGS)) {
      stdx::expected<Limit, std::string> limit_res;

      if (accept(LIMIT)) {  // optional limit
        limit_res = limit();
      }

      if (accept(END_OF_INPUT)) {
        if (limit_res) {
          return {std::in_place,
                  ShowWarnings{ShowWarnings::Verbosity::Warning,
                               limit_res->row_count, limit_res->offset}};
        }

        return {std::in_place, ShowWarnings{ShowWarnings::Verbosity::Warning}};
      }

      // unexpected input after SHOW WARNINGS [LIMIT ...]
      return {};
    } else if (accept(ERRORS)) {
      stdx::expected<Limit, std::string> limit_res;

      if (accept(LIMIT)) {
        limit_res = limit();
      }

      if (accept(END_OF_INPUT)) {
        if (limit_res) {
          return {std::in_place,
                  ShowWarnings{ShowWarningCount::Verbosity::Error,
                               limit_res->row_count, limit_res->offset}};
        }

        return {std::in_place,
                ShowWarnings{ShowWarningCount::Verbosity::Error}};
      }

      // unexpected input after SHOW ERRORS [LIMIT ...]
      return {};
    } else if (accept(COUNT_SYM) && accept('(') && accept('*') && accept(')')) {
      if (accept(WARNINGS)) {
        if (accept(END_OF_INPUT)) {
          return {std::in_place,
                  ShowWarningCount{ShowWarningCount::Verbosity::Warning,
                                   ShowWarningCount::Scope::Session}};
        }

        // unexpected input after SHOW COUNT(*) WARNINGS
        return {};
      } else if (accept(ERRORS)) {
        if (accept(END_OF_INPUT)) {
          return {std::in_place,
                  ShowWarningCount{ShowWarningCount::Verbosity::Error,
                                   ShowWarningCount::Scope::Session}};
        }

        // unexpected input after SHOW COUNT(*) ERRORS
        return {};
      }

      // unexpected input after SHOW COUNT(*), expected WARNINGS|ERRORS.
      return {};
    } else {
      // unexpected input after SHOW, expected WARNINGS|ERRORS|COUNT
      return {};
    }
  }
```

- 若第 1 个 token 为 `SELECT`：
  - 若第 2 - 3 个 token 均为 `@`：
    - 若第 4 - 5 个 token 依次为 `SESSION` 和 `.`
      - 若第 6 个 token 为 `warning_count`，且 SQL 已结束，则返回 `{std::in_place, ShowWarningCount(ShowWarnings::Verbosity::Warning, ShowWarningCount::Scope::Session)}`
      - 若第 6 个 token 为 `error_count`，且 SQL 已结束，则返回 `{std::in_place, ShowWarningCount(ShowWarnings::Verbosity::Error, ShowWarningCount::Scope::Session)}`
      - 否则，返回预期之外的字符串
    - 若第 4 - 5 个 token 依次为 `LOCAL` 和 `.`
      - 若第 6 个 token 为 `warning_count`，且 SQL 已结束，则返回 `{std::in_place, ShowWarningCount(ShowWarnings::Verbosity::Warning, ShowWarningCount::Scope::Local)}`
      - 若第 6 个 token 为 `error_count`，且 SQL 已结束，则返回 `{std::in_place, ShowWarningCount(ShowWarnings::Verbosity::Error, ShowWarningCount::Scope::Local)}`
      - 否则，返回预期之外的字符串
    - 若第 4 个 token 不是 `warning_count`且 SQL 已结束，则返回 `{std::in_place, ShowWarningCount(ShowWarnings::Verbosity::Warning, ShowWarningCount::Scope::None)}`
    - 若第 4 个 token 为 `error_count`，且 SQL 已结束，则返回 `{std::in_place, ShowWarningCount(ShowWarnings::Verbosity::Error, ShowWarningCount::Scope::None)}`
  - 否则返回 `{}`

```C++
  else if (accept(SELECT_SYM)) {
    // match
    //
    // SELECT @@((LOCAL|SESSION).)?warning_count|error_count;
    //
    if (accept('@')) {
      if (accept('@')) {
        if (accept(SESSION_SYM)) {
          if (accept('.')) {
            auto ident_res = warning_count_ident();
            if (ident_res && accept(END_OF_INPUT)) {
              return ret_type{
                  std::in_place,
                  ShowWarningCount(*ident_res,
                                   ShowWarningCount::Scope::Session)};
            }
          }
        } else if (accept(LOCAL_SYM)) {
          if (accept('.')) {
            auto ident_res = warning_count_ident();
            if (ident_res && accept(END_OF_INPUT)) {
              return ret_type{
                  std::in_place,
                  ShowWarningCount(*ident_res, ShowWarningCount::Scope::Local)};
            }
          }
        } else {
          auto ident_res = warning_count_ident();
          if (ident_res && accept(END_OF_INPUT)) {
            return ret_type{
                std::in_place,
                ShowWarningCount(*ident_res, ShowWarningCount::Scope::None)};
          }
        }
      }
    }
  }
```

- 若第 1 个 token 不是 `SHOW` 或 `SELECT`，则返回 `{}`

#### `LIMIT` 子句解析

在 `ShowWarningsParser` 解析器中，用到了 `LIMIT` 子句的解析逻辑，具体如下：

```C++
stdx::expected<Limit, std::string> ShowWarningsParser::limit() {
  if (auto num1_tkn = expect(NUM)) {
    auto num1 = sv_to_num(num1_tkn.text());  // offset_or_row_count
    if (accept(',')) {
      if (auto num2_tkn = expect(NUM)) {
        auto num2 = sv_to_num(num2_tkn.text());  // row_count

        return Limit{num2, num1};
      }
    } else {
      return Limit{num1, 0};
    }
  }

  return stdx::make_unexpected(error_);
}
```

首先，`num1_tkn = expect(NUM)` 尝试匹配一个整型的字面值，然后 `num1 = sv_to_num(num1_tkn.text())` 将这个字面值解析并存入 `num1` 变量。

接着，尝试匹配 `,`，如果能够匹配则说明是 `LIMIT 1, 3` 的形式，再尝试匹配一个整型的字面值，然后将这个字面值解析并存入 `num2` 变量。

如果能够匹配到 `,` 则说明 `num1` 是 OFFSET，`num2` 是 LIMIT，返回 `Limit{num2, num1}`。否则，说明 `num1` 是 LIMIT，OFFSET 为 0，返回 `Limit{num1, 0}`。

这个函数的返回值类型为 `Limit`，定义在 `show_warnings_parser.h` 中：

```C++
struct Limit {
  uint64_t row_count{std::numeric_limits<uint64_t>::max()};
  uint64_t offset{};
};
```

