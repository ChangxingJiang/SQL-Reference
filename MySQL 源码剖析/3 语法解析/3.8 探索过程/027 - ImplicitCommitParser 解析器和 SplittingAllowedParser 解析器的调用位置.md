目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[router/src/routing/src/classic_query_forwarder.cc](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/classic_query_forwarder.cc)

前置文档：

- [MySQL 源码｜23 - 句法解析：ImplicitCommitParser 的解析方法](https://zhuanlan.zhihu.com/p/714762241)
- [MySQL 源码｜24 - 句法解析：SplittingAllowedParser 解析器](https://zhuanlan.zhihu.com/p/714762393)

---

#### `ImplicitCommitParser` 解析器

`ImplicitCommitParser` 在 `is_implicitly_committed()` 函数中被调用。该函数接收 2 个参数，分别为词法分析结果的 token遍历器 `lexer` 和事务状态 `trx_state`。根据 `ImplicitCommitParser` 解析器的逻辑，这个函数返回 SQL 需要隐式提交则返回 true，否则返回 false。

```C++
stdx::expected<bool, std::string> is_implicitly_committed(
    SqlLexer &&lexer,
    std::optional<classic_protocol::session_track::TransactionState>
        trx_state) {
  return ImplicitCommitParser(lexer.begin(), lexer.end()).parse(trx_state);
}
```

函数 `is_implicitly_committed` 在 `QueryForwarder::command()` 的如下位置被调用：

- 调用 `connection()->trx_state()` 判断当前是否在事务中，如果不在则将 stage 更新为 `Stage::ClassifyQuery`
- 如果在事务中，则调用 `is_implicitly_committed()` 函数判断是否需要隐式提交：
  - 如果 `is_implicitly_committed()` 函数遭遇异常，则调用 `harness_assert_this_should_not_execute()`
  - 如果需要隐式提交，则判断当前连接是否已经打开（`!server_conn.is_open()`）：
    - 如果连接已经打开，则调用并 `trace_connect_and_explicit_commit()` 并将当前阶段置为 `Stage::ExplicitCommitConnect`
    - 如果连接已经打开，则将当前阶段置为 `Stage::ExplicitCommit`

  - 如果不需要隐式提交，则将当前阶段置为 `Stage::ClassifyQuery`


```C++
    if (!connection()->trx_state()) {
      // no trx state, no trx.
      stage(Stage::ClassifyQuery);
    } else {
      auto is_implictly_committed_res = is_implicitly_committed(
          sql_parser_state_.lexer(), connection()->trx_state());
      if (!is_implictly_committed_res) {
        // it fails if trx-state() is not set, but it has been set.
        harness_assert_this_should_not_execute();
      } else if (*is_implictly_committed_res) {
        auto &server_conn = connection()->server_conn();
        if (!server_conn.is_open()) {
          trace_event_connect_and_explicit_commit_ =
              trace_connect_and_explicit_commit(trace_event_command_);
          stage(Stage::ExplicitCommitConnect);
        } else {
          stage(Stage::ExplicitCommit);
        }
      } else {
        // not implicitly committed.
        stage(Stage::ClassifyQuery);
      }
    }
```

#### `SplittingAllowedParser` 解析器

`SplittingAllowedParser` 在 `splitting_allowed()` 函数中被调用。该函数接收 1 个参数，为词法分析结果的 token遍历器 `lexer`。根据 `SplittingAllowedParser` 解析器的逻辑，这个函数返回 `Allowed` 状态。

```C++
stdx::expected<SplittingAllowedParser::Allowed, std::string> splitting_allowed(
    SqlLexer &&lexer) {
  return SplittingAllowedParser(lexer.begin(), lexer.end()).parse();
}
```

函数 `splitting_allowed()` 在 `QueryForwarder::command()` 的如下分支中被调用，推测是当前 `access_mode` 仍为自动，还没有被指定：

```C++
if (connection()->context().access_mode() == routing::AccessMode::kAuto) {
    ...
}
```

具体地，调用逻辑如下：

```C++
const auto allowed_res = splitting_allowed(sql_parser_state_.lexer());
```

如果遇到了预期外的问题，则构造报错信息并将当前阶段置为 `Stage::Done`，返回 `Result::SendToClient`。

```C++
      if (!allowed_res) {
        auto send_res = ClassicFrame::send_msg<
            classic_protocol::borrowed::message::server::Error>(
            src_conn, {ER_ROUTER_NOT_ALLOWED_WITH_CONNECTION_SHARING,
                       allowed_res.error(), "HY000"});
        if (!send_res) return send_client_failed(send_res.error());

        discard_current_msg(src_conn);

        stage(Stage::Done);
        return Result::SendToClient;
      }
```

否则，`switch` 处理 `splitting_allowed()` 函数返回的各个枚举值。

- 如果返回 `Allowed::Always` 则不执行任何操作

```C++
        case SplittingAllowedParser::Allowed::Always:
          break;
```

- 如果返回 `Allowed::Never`，则构造报错信息并将当前阶段置为 `Stage::Done`，返回 `Result::SendToClient`。

```C++
        case SplittingAllowedParser::Allowed::Never: {
          auto send_res = ClassicFrame::send_msg<
              classic_protocol::borrowed::message::server::Error>(
              src_conn,
              {ER_ROUTER_NOT_ALLOWED_WITH_CONNECTION_SHARING,
               "Statement not allowed if access_mode is 'auto'", "HY000"});
          if (!send_res) return send_client_failed(send_res.error());

          discard_current_msg(src_conn);

          stage(Stage::Done);
          return Result::SendToClient;
        }
```

- 如果返回其他枚举值，如果当前不在事务中，则构造报错信息并将当前阶段置为 `Stage::Done`，返回 `Result::SendToClient`；否则不做任何操作。

> 如果当前事务状态的类型为 `_`，即说明不在事务中，不需要提交，直接返回 false。详见 [MySQL 源码 - 23｜句法解析：ImplicitCommitParser 的解析方法](https://dataartist.blog.csdn.net/article/details/140768667) 的 Step 2，来源于注释描述。

```C++
        case SplittingAllowedParser::Allowed::OnlyReadOnly:
        case SplittingAllowedParser::Allowed::OnlyReadWrite:
        case SplittingAllowedParser::Allowed::InTransaction:
          if (!connection()->trx_state() ||
              connection()->trx_state()->trx_type() == '_') {
            auto send_res = ClassicFrame::send_msg<
                classic_protocol::borrowed::message::server::Error>(
                src_conn,
                {ER_ROUTER_NOT_ALLOWED_WITH_CONNECTION_SHARING,
                 "Statement not allowed outside a transaction if access_mode "
                 "is 'auto'",
                 "HY000"});
            if (!send_res) return send_client_failed(send_res.error());

            discard_current_msg(src_conn);

            stage(Stage::Done);
            return Result::SendToClient;
          }
          break;
```
