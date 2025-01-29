目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[router/src/routing/src/classic_query_forwarder.cc](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/classic_query_forwarder.cc)

前置文档：

- [MySQL 源码｜27 - ImplicitCommitParser 解析器和 SplittingAllowedParser 解析器的调用位置](https://zhuanlan.zhihu.com/p/714762963)
- [MySQL 源码｜28 - StartTransactionParser 解析器和 ShowWarningsParser 解析器的调用位置](https://zhuanlan.zhihu.com/p/714763124)

---

除 `StartTransactionParser` 解析器外，其他 3 个解析器均在 `QueryForwarder::command()` 函数中被直接或间接地调用，现在我们来看 `QueryForwarder::command()` 的逻辑。`QueryForwarder::command()` 的原型如下，不接受参数，返回预期值为 `Processor::Result` 类型，非预期值为字符串的 `stdx::expected` 类型返回值。

```C++
stdx::expected<Processor::Result, std::error_code> QueryForwarder::command() {
```

**Step 1**｜检查当前连接是否开启共享，如果没有开启，则调用 `tr.trace(Tracer::Event().stage("query::command")`，并将当前阶段状态置为 `Stage::PrepareBackend`，并返回 `Result::Again`。

```C++
if (!connection()->connection_sharing_possible()) {
  if (auto &tr = tracer()) {
    tr.trace(Tracer::Event().stage("query::command"));
  }
  stage(Stage::PrepareBackend);
  return Result::Again;
} 
```

**Step 2**｜调用 `ClassicFrame::recv_msg` 获取当前消息，存储到 `msg_res`。当获取失败时，则生成提示信息并返回。

```C++
auto msg_res = ClassicFrame::recv_msg<
    classic_protocol::borrowed::message::client::Query>(src_conn);
if (!msg_res) {
  // all codec-errors should result in a Malformed Packet error..
  if (msg_res.error().category() !=
      make_error_code(classic_protocol::codec_errc::not_enough_input)
          .category()) {
    return recv_client_failed(msg_res.error());
  }

  discard_current_msg(src_conn);

  auto send_msg =
      ClassicFrame::send_msg<classic_protocol::message::server::Error>(
          src_conn,
          {ER_MALFORMED_PACKET, "Malformed communication packet", "HY000"});
  if (!send_msg) send_client_failed(send_msg.error());

  stage(Stage::Done);

  return Result::SendToClient;
}
```

**Step 3**｜如果连接中的 `tracer()` 不为空，则使用 `msg_res` 中的信息构造文本并更新 `tracer` 中的事件。

```C++
if (auto &tr = tracer()) {
  std::ostringstream oss;

  for (const auto &param : msg_res->values()) {
    oss << "\n";
    oss << "- " << param.name << ": ";

    if (!param.value) {
      oss << "NULL";
    } else if (auto param_str = param_to_string(param)) {
      oss << param_str.value();
    }
  }

  tr.trace(Tracer::Event().stage(
      "query::command: " +
      std::string(msg_res->statement().substr(0, 1024)) + oss.str()));
}
```

**Step 4**｜初始化 `SqlParserState` 类，在 `statement()` 成员函数中初始化了 `Parser_state` 类。

```C++
// init the parser-statement once.
sql_parser_state_.statement(msg_res->statement());
```

**Step 5**｜检查 SQL 语句中是否包含多个表达式。如果 SQL 语句中包含多个表达式，且没有开启 `connection-sharing`，则构造返回信息并将当前阶段状态置为 `Stage::Done`，并返回 `Result::SendToClient`。

```C++
if (src_protocol.shared_capabilities().test(
        classic_protocol::capabilities::pos::multi_statements) &&
    contains_multiple_statements(sql_parser_state_.lexer())) {
  auto send_res = ClassicFrame::send_msg<
      classic_protocol::message::server::Error>(
      src_conn,
      {ER_ROUTER_NOT_ALLOWED_WITH_CONNECTION_SHARING,
       "Multi-Statements are forbidden if connection-sharing is enabled.",
       "HY000"});
  if (!send_res) return send_client_failed(send_res.error());

  discard_current_msg(src_conn);

  stage(Stage::Done);
  return Result::SendToClient;
}
```

**Step 6**｜调用 `InterceptedStatementsParser` 解析器的逻辑，如果当前语句为 `SHOW WARNING` 类语句，则返回执行信息。其主要逻辑结构如下：

```C++
stdx::expected<std::variant<std::monostate, ShowWarningCount, ShowWarnings,
                            CommandRouterSet>,
               std::string>
intercept_diagnostics_area_queries(SqlLexer &&lexer) {
  return InterceptedStatementsParser(lexer.begin(), lexer.end()).parse();
}

const auto intercept_res =
        intercept_diagnostics_area_queries(sql_parser_state_.lexer());
    if (intercept_res) {
      if (std::holds_alternative<std::monostate>(*intercept_res)) {
        // no match
      } else if (std::holds_alternative<ShowWarnings>(*intercept_res)) {
        ......
      } else if (std::holds_alternative<ShowWarningCount>(*intercept_res)) {
        ......
      } else if (std::holds_alternative<CommandRouterSet>(*intercept_res)) {
        ......
      }
    } else {
        ......
    }
```

具体逻辑详见：[MySQL 源码｜28 - StartTransactionParser 解析器和 ShowWarningsParser 解析器的调用位置](https://zhuanlan.zhihu.com/p/714763124)

**Step 7**｜如果当前连接上下文的 `connection()->context().access_mode()` 为 `routing::AccessMode::kAuto`，则调用 `SplittingAllowedParser` 解析器，返回 `Allowed` 状态并进行处理。

```C++
if (connection()->context().access_mode() == routing::AccessMode::kAuto) {
  const auto allowed_res = splitting_allowed(sql_parser_state_.lexer());
  if (!allowed_res) {
    ......
    stage(Stage::Done);
    return Result::SendToClient;
  }

  switch (*allowed_res) {
    case SplittingAllowedParser::Allowed::Always:
      break;
    case SplittingAllowedParser::Allowed::Never: {
      ......
      stage(Stage::Done);
      return Result::SendToClient;
    }
    case SplittingAllowedParser::Allowed::OnlyReadOnly:
    case SplittingAllowedParser::Allowed::OnlyReadWrite:
    case SplittingAllowedParser::Allowed::InTransaction:
      if (!connection()->trx_state() ||
          connection()->trx_state()->trx_type() == '_') {
        ......
        stage(Stage::Done);
        return Result::SendToClient;
      }
      break;
  }
}
```

具体逻辑详见：[MySQL 源码｜27 - ImplicitCommitParser 解析器和 SplittingAllowedParser 解析器的调用位置](https://zhuanlan.zhihu.com/p/714762963)

**Step 8**｜如果当前连接的 `connection()->trx_state()` 为假值，则将当前阶段状态置为 `Stage::ClassifyQuery`，并返回 `Result::Again`；否则，根据 `ImplicitCommitParser` 解析器的逻辑，根据返回的 SQL 需要隐式提交，调整阶段状态并返回。

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

    return Result::Again;
  }
```

具体逻辑详见：[MySQL 源码｜27 - ImplicitCommitParser 解析器和 SplittingAllowedParser 解析器的调用位置](https://zhuanlan.zhihu.com/p/714762963)
