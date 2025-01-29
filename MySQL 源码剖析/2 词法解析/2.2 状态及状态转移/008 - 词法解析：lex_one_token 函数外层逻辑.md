目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置：（版本 = MySQL 8.0.37）：

- [router/src/routing/src/sql_lexer.cc](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/sql_lexer.cc)
- [router/src/routing/src/sql_lexer_input_stream.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/sql_lexer_input_stream.h)

---

**Step 1**｜在 `lex_one_token()` 函数中，首先从 `THD` 中获取了 `Lex_input_stream` 类型指针 `lip`，该类型用于存储此法解析状态。

```C++
Lex_input_stream *lip = &thd->m_parser_state->m_lip;
```

**Step 2**｜然后调用 ` lip->start_token()`：

```C++
lip->start_token();
```

`start_token()` 方法中用于将流中当前位置作为一个新的 token 的开始位置，具体执行逻辑如下：

```C++
  /** Mark the stream position as the start of a new token. */
  void start_token() {
    m_tok_start = m_ptr;
    m_tok_end = m_ptr;

    m_cpp_tok_start = m_cpp_ptr;
    m_cpp_tok_end = m_cpp_ptr;
  }
```

将原始输入流、预处理输入流中当前 token 的开始、结束位置的指针均设置为当前指针。

其中涉及的几个成员均为私有成员，具体地：

```C++
  /** Pointer to the current position in the raw input stream. */
  char *m_ptr;

  /** Starting position of the last token parsed, in the raw buffer. */
  const char *m_tok_start;

  /** Ending position of the previous token parsed, in the raw buffer. */
  const char *m_tok_end;
```

- `m_ptr` 为 `char *` 类型指针，指向原始输入流中的当前位置
- `m_tok_start` 为 `const char *` 类型指针，指向原始输入流中上一个 token 的开始位置
- `m_tok_end` 为 `const char *` 类型指针，指向原始输入流中上一个 token 的结束位置

```C++
  /** Pointer to the current position in the pre-processed input stream. */
  char *m_cpp_ptr;

  /**
    Starting position of the last token parsed,
    in the pre-processed buffer.
  */
  const char *m_cpp_tok_start;

  /**
    Ending position of the previous token parsed,
    in the pre-processed buffer.
  */
  const char *m_cpp_tok_end;
```

- `m_cpp_ptr` 为 `char *` 类型指针，指向预处理输入流中的当前位置
- `m_cpp_tok_start` 为 `const char *` 类型指针，指向预处理输入流中上一个 token 的开始位置
- `m_cpp_tok_end` 为 `const char *` 类型指针，指向预处理输入流中上一个 token 的结束位置

**Step 3**｜从 `lip` 中获取当前状态 `next_state`，并将 `next_state` 先重置为 `MY_LEX_START`：

```C++
  state = lip->next_state;
  lip->next_state = MY_LEX_START;
```

**Step 4**｜启动一个无限循环，在其中根据当前状态执行逻辑，若当前 token 匹配完成则直接 `return`。

```C++
  for (;;) {
    switch (state) {
      ......
  }
}
```











