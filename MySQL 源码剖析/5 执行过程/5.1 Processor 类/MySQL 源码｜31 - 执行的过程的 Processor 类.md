目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：

- [router/src/routing/src/processor.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/processor.h)
- [router/src/routing/src/processor.cc](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/processor.cc)

前置文档：[MySQL 源码｜30 - 执行的过程的抽象基类 BasicProcessor](https://zhuanlan.zhihu.com/p/714778229)

---

`Processor` 类继承自抽象基类 `BasicProcessor`，并引用了 `BasicProcessor` 类的构造函数。`Processor` 类在 [router/src/routing/src/processor.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/processor.h) 中被定义，其中补充了一些工具函数。

```C++
/**
 * a processor base class with helper functions.
 */
class Processor : public BasicProcessor {
 public:
  using BasicProcessor::BasicProcessor;
```

其中定义了一系列 protected 函数。

#### 6 个用于发送失败信息的函数

定义了 6 个用于发送失败信息并构造 `process()` 函数返回值的工具函数。

- `Processor::send_server_failed`：调用连接对象的 `send_server_failed()` 成员函数提供错误码，并返回错误码作为失败值。
- `Processor::recv_server_failed`：如果错误码为 `TlsErrc::kWantRead` 则返回 `Result::RecvFromServer`，否则调用连接对象的 `recv_server_failed()` 成员函数提供接收错误码，并返回错误码作为失败值。
- `Processor::send_client_failed`：调用连接对象的 `send_client_failed()`  成员函数提供错误码，并返回错误码作为失败值。
- `Processor::recv_client_failed`：如果错误码为 `TlsErrc::kWantRead` 则返回 `Result::RecvFromClient`，否则调用连接对象的 `recv_client_failed()` 成员函数提供错误码，并返回错误码作为失败值。
- `Processor::server_socket_failed`：调用连接对象的 `server_socket_failed()` 成员函数提供错误码，并返回错误码作为失败值。
- `Processor::client_socket_failed`：调用连接对象的 `client_socket_failed()` 成员函数提供错误码，并返回错误码作为失败值。

```C++
stdx::expected<Processor::Result, std::error_code>
Processor::send_server_failed(std::error_code ec) {
  connection()->send_server_failed(ec, false);
  return stdx::make_unexpected(ec);
}

stdx::expected<Processor::Result, std::error_code>
Processor::recv_server_failed(std::error_code ec) {
  if (ec == TlsErrc::kWantRead) return Result::RecvFromServer;
  connection()->recv_server_failed(ec, false);
  return stdx::make_unexpected(ec);
}

stdx::expected<Processor::Result, std::error_code>
Processor::send_client_failed(std::error_code ec) {
  connection()->send_client_failed(ec, false);
  return stdx::make_unexpected(ec);
}

stdx::expected<Processor::Result, std::error_code>
Processor::recv_client_failed(std::error_code ec) {
  if (ec == TlsErrc::kWantRead) return Result::RecvFromClient;
  connection()->recv_client_failed(ec, false);
  return stdx::make_unexpected(ec);
}

stdx::expected<Processor::Result, std::error_code>
Processor::server_socket_failed(std::error_code ec) {
  connection()->server_socket_failed(ec, false);
  return stdx::make_unexpected(ec);
}

stdx::expected<Processor::Result, std::error_code>
Processor::client_socket_failed(std::error_code ec) {
  connection()->client_socket_failed(ec, false);
  return stdx::make_unexpected(ec);
}
```

#### `Processor::discard_current_msg`：丢弃当前信息

接收参数 `src_channel` 和 `src_protocol`，不断调用 `src_protocol->current_frame().reset();` 成员函数移除重置 current frame 和当前信息，直至所有信息都被重置完成。

```C++
/**
 * discard to current message.
 *
 * @pre ensure_full_frame() must true.
 */
stdx::expected<void, std::error_code> Processor::discard_current_msg(
    Channel *src_channel, ClassicProtocolState *src_protocol) {
  auto &recv_buf = src_channel->recv_plain_view();

  do {
    auto &opt_current_frame = src_protocol->current_frame();
    if (!opt_current_frame) return {};

    auto current_frame = *opt_current_frame;

    if (recv_buf.size() < current_frame.frame_size_) {
      // received message is incomplete.
      return stdx::make_unexpected(make_error_code(std::errc::bad_message));
    }
    if (current_frame.forwarded_frame_size_ != 0) {
      // partially forwarded already.
      return stdx::make_unexpected(
          make_error_code(std::errc::invalid_argument));
    }

    src_channel->consume_plain(current_frame.frame_size_);

    auto msg_has_more_frames = current_frame.frame_size_ == (0xffffff + 4);

    // unset current frame and also current-msg
    src_protocol->current_frame().reset();

    if (!msg_has_more_frames) break;

    auto hdr_res = ClassicFrame::ensure_frame_header(src_channel, src_protocol);
    if (!hdr_res) {
      return stdx::make_unexpected(hdr_res.error());
    }
  } while (true);

  src_protocol->current_msg_type().reset();

  return {};
}
```

#### `Processor::log_fatal_error_code`：在日志中打印错误信息和错误码

接收报错信息 `msg` 和报错码 `std::error_code` 作为参数，并打印到日志中。

```C++
/**
 * log a message with error-code as error.
 */
void Processor::log_fatal_error_code(const char *msg, std::error_code ec) {
  log_error("%s: %s (%s:%d)", msg, ec.message().c_str(), ec.category().name(),
            ec.value());
}
```

#### 与 trace 相关的成员函数

定义了如下与当前连接的 Tracer 相关的成员函数：

- `Processor::trace`：获取当前连接的 Tracer
- `Processor::trace_span`：开始一个 span
- `Processor::trace_span_end`：结束一个 span 并设置状态码
- `Processor::trace_command`：开始一个 command span
- `Processor::trace_connect_and_forward_command`：开始一个 connect-and-forward span
- `Processor::trace_connect`：开始一个 connect span
- `Processor::trace_set_connection_attributes`：开始一个 connect span 并设置连接属性
- `Processor::trace_forward_command`：开始一个 forward span
- `Processor::trace_command_end`：结束一个 command span 并设置状态码

```C++
void Processor::trace(Tracer::Event event) {
  return connection()->trace(std::move(event));
}

Tracer &Processor::tracer() { return connection()->tracer(); }

TraceEvent *Processor::trace_span(TraceEvent *parent_span,
                                  const std::string_view &prefix) {
  if (parent_span == nullptr) return nullptr;

  return std::addressof(parent_span->events.emplace_back(std::string(prefix)));
}

void Processor::trace_span_end(TraceEvent *event,
                               TraceEvent::StatusCode status_code) {
  if (event == nullptr) return;

  event->status_code = status_code;
  event->end_time = std::chrono::steady_clock::now();
}

TraceEvent *Processor::trace_command(const std::string_view &prefix) {
  if (!connection()->events().active()) return nullptr;

  auto *parent_span = std::addressof(connection()->events());

  if (parent_span == nullptr) return nullptr;

  return std::addressof(
      parent_span->events().emplace_back(std::string(prefix)));
}

TraceEvent *Processor::trace_connect_and_forward_command(
    TraceEvent *parent_span) {
  auto *ev = trace_span(parent_span, "mysql/connect_and_forward");
  if (ev == nullptr) return nullptr;

  trace_set_connection_attributes(ev);

  return ev;
}

TraceEvent *Processor::trace_connect(TraceEvent *parent_span) {
  return trace_span(parent_span, "mysql/connect");
}

void Processor::trace_set_connection_attributes(TraceEvent *ev) {
  auto &server_conn = connection()->socket_splicer()->server_conn();
  ev->attrs.emplace_back("mysql.remote.is_connected", server_conn.is_open());

  if (server_conn.is_open()) {
    ev->attrs.emplace_back("mysql.remote.endpoint",
                           connection()->get_destination_id());
    ev->attrs.emplace_back("mysql.remote.connection_id",
                           static_cast<int64_t>(connection()
                                                    ->server_protocol()
                                                    ->server_greeting()
                                                    ->connection_id()));
    ev->attrs.emplace_back("db.name",
                           connection()->server_protocol()->schema());
  }
}

TraceEvent *Processor::trace_forward_command(TraceEvent *parent_span) {
  return trace_span(parent_span, "mysql/forward");
}

void Processor::trace_command_end(TraceEvent *event,
                                  TraceEvent::StatusCode status_code) {
  if (event == nullptr) return;

  const auto allowed_after = connection()->connection_sharing_allowed();

  event->end_time = std::chrono::steady_clock::now();
  auto &attrs = event->attrs;

  attrs.emplace_back("mysql.sharing_blocked", !allowed_after);

  if (!allowed_after) {
    // stringify why sharing is blocked.

    attrs.emplace_back("mysql.sharing_blocked_by",
                       connection()->connection_sharing_blocked_by());
  }

  trace_span_end(event, status_code);
}
```









