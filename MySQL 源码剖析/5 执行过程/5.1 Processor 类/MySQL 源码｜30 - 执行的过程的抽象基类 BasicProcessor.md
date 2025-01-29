目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[router/src/routing/src/processor.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/processor.h)

---

抽象基类 `BasicProcessor` 在 [router/src/routing/src/processor.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/processor.h) 中被定义，具体逻辑如下：

```C++
// router/src/routing/src/processor.h
class BasicProcessor {
 public:
  enum class Result {
    Again,           // will invoke the process() of the top-most-processor
    RecvFromClient,  // wait for recv from client and invoke ...
    SendToClient,    // wait for send-to-client and invoke ...
    RecvFromServer,  // wait for recv from server and invoke ...
    RecvFromBoth,    // wait for recv from client and server and invoke ..
    SendToServer,    // wait for send-to-server and invoke ...
    SendableToServer,

    Suspend,  // wait for explicit resume
    Done,  // pop this processor and invoke the top-most-processor's process()

    Void,
  };

  BasicProcessor(MysqlRoutingClassicConnectionBase *conn) : conn_(conn) {}

  virtual ~BasicProcessor() = default;

  const MysqlRoutingClassicConnectionBase *connection() const { return conn_; }

  MysqlRoutingClassicConnectionBase *connection() { return conn_; }

  virtual stdx::expected<Result, std::error_code> process() = 0;

 private:
  MysqlRoutingClassicConnectionBase *conn_;
};
```

定义类公有的枚举类 `Result`，其中状态如下：

- `Again`：将会调用 `top-most-processor` 的 `process()` 函数（推测是启动期待队列中的进程）
- `RecvFromClient`：等待从客户端消息后唤起
- `SendToClient`：在发送到客户端后唤起
- `RecvFromServer`：等待从服务端消息后唤起
- `RecvFromBoth`：等待从客户端和服务端均收到消息后唤起
- `SendableToServer`
- `Suspend`：等待明确的 resume（推测是摘要）
- `Done`：弹出当前进程，并调用 `top-most-processor` 的 `process()` 函数（推测是启动期待队列中的进程）
- `Void`

在构造时，接收一个 `MysqlRoutingClassicConnectionBase` 类型指针的连接对象作为参数，存储私有属性 `conn_` 中，并提供了  `connection` 成员函数用于获取私有属性 `conn_` 中的连接对象。

此外，还定义了一个纯虚函数 `process()`，它的返回值类型为 `stdx::expected` 类型的，当操作成功时返回 `Result` 枚举值，失败时返回 `std::error_code` 类型的错误码。