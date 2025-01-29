目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：

- [router/src/routing/src/sql_parser.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/sql_parser.h)
- [router/src/routing/src/implicit_commit_parser.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/implicit_commit_parser.h)
- [router/src/routing/src/show_warnings_parser.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/show_warnings_parser.h)
- [router/src/routing/src/sql_splitting_allowed.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/sql_splitting_allowed.h)
- [router/src/routing/src/start_transaction_parser.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/start_transaction_parser.h)

---

根据词法解析器，可知句法解析器一定要依托 `SqlLexer::iterator` 迭代器，全局搜索引入 `SqlLexer::iterator`，除了 `sql_lexer.cc` 外，有如下位置使用：

- `\router\src\routing\src\classic_query_forwarder.cc`：除 `DEBUG_DUMP_TOKEN` 外，仅在 `contains_multiple_statements` 函数中使用
- `\router\src\routing\src\classic_query_sender.cc`：逻辑均在 `DEBUG_DUMP_TOKEN` 中
- `\router\src\routing\src\sql_parser.h`：使用于 `SqlParser` 类的成员中

其中，直观推断 `SQLParser` 类更接近语法解析的概率更高。

### `SQLParser` 类

> 源码位置：[router/src/routing/src/sql_parser.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/sql_parser.h)

`SQLParser` 类包含如下 3 个成员变量：

- `SqlLexer::iterator` 类型的 `cur_`：指向当前 token 的迭代器
- `SqlLexer::iterator` 类型的 `end_`：指向末尾 token 的迭代器
- `std::string` 类型的 `error_`：异常信息的字符串

```C++
 protected:
  SqlLexer::iterator cur_;
  SqlLexer::iterator end_;

  std::string error_{};
```

`SQLParser` 的构造函数接收两个参数，根据名称推断这两个迭代器分别指向待解析 token 列表的开头和结尾，用于初始化成员变量 `cur_` 和 `end_`。

```C++
class SqlParser {
 public:
  SqlParser(SqlLexer::iterator first, SqlLexer::iterator last)
      : cur_{first}, end_{last} {}
```

#### `TokenText` 子类

在 `SQLParser` 中定义了子类 `TokenText`：

```C++
  class TokenText {
   public:
    TokenText() = default;
    TokenText(SqlLexer::TokenId id, std::string_view txt)
        : id_{id}, txt_{txt} {}

    operator bool() const { return !txt_.empty(); }

    [[nodiscard]] std::string_view text() const { return txt_; }
    [[nodiscard]] SqlLexer::TokenId id() const { return id_; }

   private:
    SqlLexer::TokenId id_{};
    std::string_view txt_{};
  };
```

其中包含以下 2 个成员变量：

- `SQLLexer::TokenId` 类型，即整型的成员变量 `_id`，存储 token 类型即 `lex_one_token()` 函数返回值
- `std::string_view` 类型的成员变量 `txt_`，存储 token 的字符串

在构造函数中接收了参数 `id` 和 `txt` 分别用于初始化 `_id` 和 `txt_`。

提供了 3 个成员函数：

- `operator bool() const`：是一个类型转换运算符，它允许 `TokenText` 对象可以被隐式地转换为布尔值，并返回 `txt_` 是否为空。
- `[[nodiscard]] std::string_view text() const`：用于获取 `txt_` 成员变量，且返回值不应被忽略。
- `[[nodiscard]] SqlLexer::TokenId id() const`：用于获取 `id_` 成员变量，且返回值不应被忽略。

#### 成员函数

- `TokenText token() const`：获取当前 `cur_` 迭代器指向的 token，并构造为 `tokenText` 对象返回。

```C++
 public:
  TokenText token() const { return {cur_->id, cur_->text}; }
```

- `bool has_error() const`：返回当前解析器是否已出现报错信息。

```C++
protected:
 bool has_error() const { return !error_.empty(); }
```

- `TokenText accept(int sym)`：如果当前解析器没有出现报错信息，且当前 `cur_` 指向的 token 的 `id` 为 `sym`，则使用当前 `cur_` 指向的 token 构造 `TokenText` 对象返回，并将 `cur_` 迭代器向后移动 1 次。否则，返回空 `TokenText` 对象，且不移动 `cur_` 迭代器的位置。

```C++
 protected:
  TokenText accept(int sym) {
    if (has_error()) return {};

    if (cur_->id == sym) {
      auto id = cur_->id;
      auto txt = cur_->text;
      ++cur_;
      return {id, txt};
    }

    return {};
  }
```

- `TokenText expect(int sym)`：如果当前解析器没有报错信息，且当前 `cur_` 指向的 token 的 `id` 为 `sym`，则使用当前 `cur_` 指向的 token 构造 `TokenText` 对象返回，并将 `cur_` 迭代器向后移动 1 次。否则，在 `error_` 数据成员中记录报错信息，并返回空 `TokenText` 对象。

```C++
 protected:
  TokenText expect(int sym) {
    if (has_error()) return {};

    if (auto txt = accept(sym)) {
      return txt;
    }

    error_ = "expected sym, got ...";

    return {};
  }
```

- `TokenText accept_if_not(int sym)`：如果当前解析器没有报错信息，且当前 `cur_` 指向的 token 的 `id` 不是 `sym`，则使用当前 `cur_` 指向的 token 构造 `TokenText` 对象返回，并将 `cur_` 迭代器向后移动 1 次。否则，返回空 `TokenText` 对象，且不移动 `cur_` 迭代器的位置。

```C++
 protected:
  TokenText accept_if_not(int sym) {
    if (has_error()) return {};

    if (cur_->id != sym) {
      auto id = cur_->id;
      auto txt = cur_->text;
      ++cur_;
      return {id, txt};
    }

    return {};
  }
```

- `TokenText ident()`：如果当前解析器没有报错信息，且当前 `cur_` 指向的 token 的 `id` 为 `IDENT`（482）或 `IDENT_QUOTED`（484），则使用当前 `cur_` 指向的 token 构造 `TokenText` 对象返回，并将 `cur_` 迭代器向后移动 1 次。否则，返回空 `TokenText` 对象，且不移动 `cur_` 迭代器的位置。

```C++
 protected:
  TokenText ident() {
    if (auto ident_tkn = accept(IDENT)) {
      return ident_tkn;
    } else if (auto ident_tkn = accept(IDENT_QUOTED)) {
      return ident_tkn;
    } else {
      return {};
    }
  }
```

#### `SQLParser` 类的子类

- `ImplicitCommitParser`：从名称推断是隐式提交的解析器，定义了 `parse` 成员函数

> 源码位置：[router/src/routing/src/implicit_commit_parser.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/implicit_commit_parser.h)

```C++
class ImplicitCommitParser : public SqlParser {
 public:
  using SqlParser::SqlParser;

  stdx::expected<bool, std::string> parse(
      std::optional<classic_protocol::session_track::TransactionState>
          trx_state);
};
```

- `ShowWarningsParser`：从名称推断是展示警告信息的解析器，定义了 `parse`、`limit` 和 `warning_count_ident` 成员函数

> 源码位置：[router/src/routing/src/show_warnings_parser.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/show_warnings_parser.h)

```C++
class ShowWarningsParser : public SqlParser {
 public:
  using SqlParser::SqlParser;

  stdx::expected<std::variant<std::monostate, ShowWarningCount, ShowWarnings>,
                 std::string>
  parse();

 protected:
  stdx::expected<Limit, std::string> limit();

  stdx::expected<ShowWarnings::Verbosity, std::string> warning_count_ident();
};
```

- `SplittingAllowedParser`：从名称推断是允许切分的解析器，定义了 `parse` 成员函数

> 源码位置：[router/src/routing/src/sql_splitting_allowed.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/sql_splitting_allowed.h)

```C++
class SplittingAllowedParser : public SqlParser {
 public:
  using SqlParser::SqlParser;

  enum class Allowed {
    Always,
    InTransaction,
    OnlyReadWrite,
    OnlyReadOnly,
    Never,
  };

  stdx::expected<Allowed, std::string> parse();
};
```

- `StartTransactionParser`：从名称推断是启动事务的解析器，定义了 `parse` 和 `transaction_characteristics` 成员函数

> 源码位置：[router/src/routing/src/start_transaction_parser.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/start_transaction_parser.h)

```C++
class StartTransactionParser : public SqlParser {
 public:
  using SqlParser::SqlParser;

  stdx::expected<std::variant<std::monostate, StartTransaction>, std::string>
  parse();

  stdx::expected<
      std::variant<std::monostate, StartTransaction::AccessMode, bool>,
      std::string>
  transaction_characteristics();
};
```