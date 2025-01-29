目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[router/src/routing/src/classic_query_forwarder.cc](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/classic_query_forwarder.cc)

前置文档：

- [MySQL 源码｜25 - 句法解析：StartTransactionParser 解析器](https://zhuanlan.zhihu.com/p/714762533)
- [MySQL 源码｜26 - 句法解析：ShowWarningsParser 解析器](https://zhuanlan.zhihu.com/p/714762658)

---

#### `StartTransactionParser` 解析器

`StartTransactionParser` 在 `start_transaction()` 函数中被调用。该函数接收 1 个参数，为词法分析结果的 token遍历器 `lexer`。根据 `StartTransactionParser` 解析器的逻辑，这个函数返回创建事务的信息。

```C++
stdx::expected<std::variant<std::monostate, StartTransaction>, std::string>
start_transaction(SqlLexer &&lexer) {
  return StartTransactionParser(lexer.begin(), lexer.end()).parse();
}
```

`start_transaction()` 函数在 `QueryForwarder::classify_query()` 函数中被调用，后续处理该方法后继续分析。

#### `ShowWarningsParser` 解析器

`ShowWarningsParser` 解析器没有被直接使用，而是被 `InterceptedStatementsParser` 类继承后使用。

```C++
class InterceptedStatementsParser : public ShowWarningsParser {
 public:
  using ShowWarningsParser::ShowWarningsParser;
```

在 `InterceptedStatementsParser` 类中，新定义了 2 个私有成员函数：

- `sv_to_num(std::string_view s)`：将 `NUM` 类型的 token 转换为数字
- `value()`：将 `TRUE_STM`、`FALSE_SYM`、整型字面值和字符串字面值解析为值

并重写了 `parse()`，在 `ShowWarningsParser::parse()` 的原有解析 `SHOW` 和 `SELECT` 开头语句的基础上，增加了对 `ROUTER` 的解析逻辑如下：

- 如果第 1 个 token 为 `ROUTER`：
  - 如果第 2 个 token 为 `SET`，第 3 个 token 为一个标识符名称，第 4 个 token 为 `=`，第 5 个 token 为一个值，且此时 SQL 语句结束，则返回 `ret_type{std::in_place, CommandRouterSet(name_tkn.text(), *val)`
  - 否则发，返回不满足预期的字符串

```C++
    else if (auto tkn = accept(IDENT)) {
      if (ieq(tkn.text(), "router")) {       // ROUTER
        if (accept(SET_SYM)) {               // SET
          if (auto name_tkn = ident()) {     // <name>
            if (accept(EQ)) {                // =
              if (auto val = value()) {      // <value>
                if (accept(END_OF_INPUT)) {  // $
                  return ret_type{std::in_place,
                                  CommandRouterSet(name_tkn.text(), *val)};
                } else {
                  return stdx::unexpected(
                      "ROUTER SET <name> = <value>. Extra data.");
                }
              } else {
                return stdx::unexpected(
                    "ROUTER SET <name> = expected <value>. " + error_);
              }
            } else {
              return stdx::unexpected("ROUTER SET <name> expects =");
            }
          } else {
            return stdx::unexpected("ROUTER SET expects <name>.");
          }
        } else {
          return stdx::unexpected("ROUTER expects SET.");
        }
      }
    }
```

#### `InterceptedStatementsParser` 解析器

`InterceptedStatementsParser` 在 `intercept_diagnostics_area_queries()` 函数中被调用。该函数接收 1 个参数，为词法分析结果的 token遍历器 `lexer`。根据 `InterceptedStatementsParser` 解析器的逻辑，这个函数返回 `SHOW WARNING` 类语句的执行信息。

```C++
stdx::expected<std::variant<std::monostate, ShowWarningCount, ShowWarnings,
                            CommandRouterSet>,
               std::string>
intercept_diagnostics_area_queries(SqlLexer &&lexer) {
  return InterceptedStatementsParser(lexer.begin(), lexer.end()).parse();
}
```

函数 `intercept_diagnostics_area_queries` 在 `QueryForwarder::command()` 的如下位置被调用，可以看到，当没有匹配成功时，继续执行后续逻辑；当匹配成功时，针对返回不同的 `ShowWarnings` 类型、`ShowWarningCount` 类型、`CommandRouterSet` 类型以及没有返回值有不同的处理方法；当匹配异常时，执行最后一个 `else` 中的处理逻辑。

```C++
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

##### `ShowWarnings` 类型和 `ShowWarningCount` 类型的处理逻辑

`ShowWarnings` 类型和 `ShowWarningCount` 类型的处理逻辑类似，区别在于构造返回值时，`ShowWarnings` 类型调用 `show_warnings` 函数，`ShowWarningCount` 类型调用 `show_warning_count` 函数。

**Step 1**｜调用 `discard_current_msg(src_conn)` 丢弃当前信息

**Step 2**｜如果 `connection()->connection_sharing_allowed()` 为真值，则构造提示值信息，并将当前状态置为 `Stage::Done`，返回 `Result::SendToClient`；否则，将当前状态置为 `Stage::SendQueued` 并返回 `Result::Again`。

```C++
      else if (std::holds_alternative<ShowWarnings>(*intercept_res)) {
        auto cmd = std::get<ShowWarnings>(*intercept_res);

        discard_current_msg(src_conn);

        if (connection()->connection_sharing_allowed()) {
          auto send_res = show_warnings(connection(), cmd.verbosity(),
                                        cmd.row_count(), cmd.offset());
          if (!send_res) return send_client_failed(send_res.error());

          stage(Stage::Done);
          return Result::SendToClient;
        } else {
          // send the message to the backend, and inject the trace if there is
          // one.
          stage(Stage::SendQueued);

          connection()->push_processor(std::make_unique<QuerySender>(
              connection(), std::string(msg_res->statement()),
              std::make_unique<ForwardedShowWarningsHandler>(connection(),
                                                             cmd.verbosity())));

          return Result::Again;
        }
      } else if (std::holds_alternative<ShowWarningCount>(*intercept_res)) {
        auto cmd = std::get<ShowWarningCount>(*intercept_res);

        discard_current_msg(src_conn);

        if (connection()->connection_sharing_allowed()) {
          auto send_res =
              show_warning_count(connection(), cmd.verbosity(), cmd.scope());
          if (!send_res) return send_client_failed(send_res.error());

          stage(Stage::Done);
          return Result::SendToClient;
        } else {
          // send the message to the backend, and increment the warning count
          // if there is a trace.
          stage(Stage::SendQueued);

          connection()->push_processor(std::make_unique<QuerySender>(
              connection(), std::string(msg_res->statement()),
              std::make_unique<ForwardedShowWarningCountHandler>(
                  connection(), cmd.verbosity())));

          return Result::Again;
        }
      }
```

##### `CommandRouterSet` 类型处理逻辑

**Step 1**｜调用 `discard_current_msg()` 丢弃当前信息

**Step 2**｜清空当前连接的告警信息和时间信息

**Step 3**｜基于 `CommandRouterSet` 类型创建执行命令

**Step 4**｜调用 `execute_command_router_set()` 函数执行命令。如果执行失败，调用 `send_client_failed` 函数；如果执行成功，将当前阶段状态置为 `Stage::Done`，并返回 `Result::SendToClient`。

```C++
      else if (std::holds_alternative<CommandRouterSet>(*intercept_res)) {
        discard_current_msg(src_conn);

        connection()->execution_context().diagnostics_area().warnings().clear();
        connection()->events().clear();

        auto cmd = std::get<CommandRouterSet>(*intercept_res);

        auto set_res = execute_command_router_set(connection(), cmd);
        if (!set_res) return send_client_failed(set_res.error());

        stage(Stage::Done);
        return Result::SendToClient;
      }
```

##### 匹配异常的处理逻辑

**Step 1**｜调用 `discard_current_msg()` 丢弃当前信息

**Step 2** ｜构造包含异常信息的返回信息

**Step 3**｜将当前阶段状态置为 `Stage::Done`，并返回 `Result::SendToClient`。

```C++
   else {
      discard_current_msg(src_conn);

      auto send_res =
          ClassicFrame::send_msg<classic_protocol::message::server::Error>(
              src_conn, {1064, intercept_res.error(), "42000"});
      if (!send_res) return send_client_failed(send_res.error());

      stage(Stage::Done);
      return Result::SendToClient;
    }
```

