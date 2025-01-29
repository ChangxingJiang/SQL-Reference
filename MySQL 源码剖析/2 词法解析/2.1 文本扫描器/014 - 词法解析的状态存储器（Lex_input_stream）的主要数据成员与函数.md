目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：

- [router/src/routing/src/sql_lexer.cc](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/sql_lexer.cc)
- [router/src/routing/src/sql_lexer_input_stream.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/sql_lexer_input_stream.h)

---

### 处理 token 层级指针的函数

#### `start_token()`：将当前位置作为一个新的 token 的开始位置

将当前位置指定为一个新的 token 的开始位置。具体地：

- 将指向原始输入流中当前 token 开始位置的指针（`t_tok_start`）改为指向原始数据流中当前位置（`m_ptr`）
- 将指向原始输入流中当前 token 结束位置的指针（`m_tok_end`）改为指向原始数据流中当前位置（`m_ptr`）
- 将指向预处理输入流中当前 token 开始位置的指针（`m_cpp_tok_start`）改为指向预处理输入流中的当前位置（`m_cpp_ptr`）
- 将指向预处理输入流中当前 token 结束位置的指针（`m_cpp_tok_end`）改为指向预处理输入流中的当前位置（`m_cpp_ptr`）

```C++
  /** Mark the stream position as the start of a new token. */
  void start_token() {
    m_tok_start = m_ptr;
    m_tok_end = m_ptr;

    m_cpp_tok_start = m_cpp_ptr;
    m_cpp_tok_end = m_cpp_ptr;
  }
```

#### `restart_token()`：调整当前 token 的开始位置

调整当前 token 的开始位置，用于处理开头的空白字符的情况。具体地：

- 将指向原始输入流中当前 token 开始位置的指针（`t_tok_start`）改为指向原始数据流中当前位置（`m_ptr`）
- 将指向预处理输入流中当前 token 开始位置的指针（`m_cpp_tok_start`）改为指向预处理输入流中的当前位置（`m_cpp_ptr`）

```C++
  /**
    Adjust the starting position of the current token.
    This is used to compensate for starting whitespace.
  */
  void restart_token() {
    m_tok_start = m_ptr;
    m_cpp_tok_start = m_cpp_ptr;
  }

```

### 处理当前字符层级指针的函数

#### `yyPeek()`：返回当前字符，但并不移动指针

根据指向原始数据流中当前位置的指针（`m_ptr`），并返回该指针指向的字符。

```C++
  /**
    Look at the next character to parse, but do not accept it.
  */
  unsigned char yyPeek() const {
    assert(m_ptr <= m_end_of_query);
    return m_ptr[0];
  }
```

#### `yyPeekn(int n)`：获取当前字符之后的第 n 个字符，但不移动指针

根据指向原始数据流中当前位置的指针（`m_ptr`），获取该指针指向字符后的第 n 个字符。

```C++
  /**
    Look ahead at some character to parse.
    @param n offset of the character to look up
  */
  unsigned char yyPeekn(int n) const {
    assert(m_ptr + n <= m_end_of_query);
    return m_ptr[n];
  }
```

#### `yyGetLast()`：返回上一个字符，且不移动指针

根据指向原始数据流中当前位置的指针（`m_ptr`），获取该指针指向字符的前 1 个字符。

```C++
  /**
    Get the last character accepted.
    @return the last character accepted.
  */
  unsigned char yyGetLast() const { return m_ptr[-1]; }
```

#### `yyGet()`：返回当前字符，并将指针向后移动 1 个字符

根据指向原始数据流中当前位置的指针（`m_ptr`）获取该指针当前指向的字符用于返回，然后将该指针向后移动 1 个字符。

如果需要将处理后的数据流回显到预处理数据流中（`m_echo` 为 True），则将该字符回显到指向预处理输入流中的当前位置的指针（`m_cpp_ptr`），然后将该指针向后移动 1 个字符。

```C++
  /**
    Get a character, and advance in the stream.
    @return the next character to parse.
  */
  unsigned char yyGet() {
    assert(m_ptr <= m_end_of_query);
    char c = *m_ptr++;
    if (m_echo) *m_cpp_ptr++ = c;
    return c;
  }
```

#### `yySkip()`：将指针向后移动 1 个字符

如果需要将处理后的数据流回显到预处理数据流中（`m_echo` 为 True），则将指向预处理输入流中的当前位置的指针（`m_cpp_ptr`）改为指向原始数据流中当前位置（`m_ptr`），并将这两个指针都向后移动 1 个字符。

否则将指向原始数据流中当前位置的指针（`m_ptr`）向后移动 1 个字符。

```C++
  /**
    Accept a character, by advancing the input stream.
  */
  void yySkip() {
    assert(m_ptr <= m_end_of_query);
    if (m_echo)
      *m_cpp_ptr++ = *m_ptr++;
    else
      m_ptr++;
  }
```

#### `yySkipn(int n)`：将指针向后移动 n 个字符

如果需要将处理后的数据流回显到预处理数据流中（`m_echo` 为 True），则将原始数据流中的 n 字符复制到预处理数据流中，并将这两个指针都向后移动 n 个字符。

否则只将指向原始数据流中当前位置的指针（`m_ptr`）向后移动 n 个字符。

```C++
  /**
    Accept multiple characters at once.
    @param n the number of characters to accept.
  */
  void yySkipn(int n) {
    assert(m_ptr + n <= m_end_of_query);
    if (m_echo) {
      memcpy(m_cpp_ptr, m_ptr, n);
      m_cpp_ptr += n;
    }
    m_ptr += n;
  }
```

#### `skip_binary(int n)`：将指针向后移动 n 个字符

逻辑与 `yySkipn(int n)` 一致。

如果需要将处理后的数据流回显到预处理数据流中（`m_echo` 为 True），则将原始数据流中的 n 字符复制到预处理数据流中，并将这两个指针都向后移动 n 个字符。

否则只将指向原始数据流中当前位置的指针（`m_ptr`）向后移动 n 个字符。

```C++
  void skip_binary(int n) {
    assert(m_ptr + n <= m_end_of_query);
    if (m_echo) {
      memcpy(m_cpp_ptr, m_ptr, n);
      m_cpp_ptr += n;
    }
    m_ptr += n;
  }
```

#### `yyLength()`：返回当前 token 在原始数据流中的长度

根据指向原始数据流中当前位置的指针（`m_ptr`）和指向原始输入流中当前 token 开始位置的指针（`m_tok_start`），计算当前 token 在原始数据流中的长度。

```C++
  /** Get the length of the current token, in the raw buffer. */
  uint yyLength() const {
    /*
      The assumption is that the lexical analyser is always 1 character ahead,
      which the -1 account for.
    */
    assert(m_ptr > m_tok_start);
    return (uint)((m_ptr - m_tok_start) - 1);
  }
```

#### `yyUnget()`：将指针向前移动 1 个字符

将指针向前移动 1 个字符，取消上一次 `yyGet()` 或 `yySkip()` 的影响。具体地：

- 将指向原始数据流中当前位置的指针（`m_ptr`）向前移动 1 个字符。
- 如果需要将处理后的数据流回显到预处理数据流中（`m_echo` 为 True），则将指向预处理输入流（开始位置）的指针（`m_cpp_buf`）向前移动 1 个字符。

```C++
  /**
    Cancel the effect of the last yyGet() or yySkip().
    Note that the echo mode should not change between calls to yyGet / yySkip
    and yyUnget. The caller is responsible for ensuring that.
  */
  void yyUnget() {
    m_ptr--;
    if (m_echo) m_cpp_ptr--;
  }
```

#### `yyUnput(char ch)`：将指针向前移动 1 个字符，并将新位置置为字符 ch

将指针向前移动 1 个字符，取消上一次 `yyGet()` 或 `yySkip()` 的影响，并将新位置置为字符 ch。具体地：

- 将指向原始数据流中当前位置的指针（`m_ptr`）向前移动 1 个字符，并将新位置置为字符 ch。
- 如果需要将处理后的数据流回显到预处理数据流中（`m_echo` 为 True），则将指向预处理输入流（开始位置）的指针（`m_cpp_buf`）向前移动 1 个字符。

```C++
  /**
    Puts a character back into the stream, canceling
    the effect of the last yyGet() or yySkip().
    Note that the echo mode should not change between calls
    to unput, get, or skip from the stream.
  */
  char *yyUnput(char ch) {
    *--m_ptr = ch;
    if (m_echo) m_cpp_ptr--;
    return m_ptr;
  }
```

#### `cpp_inject(char ch)`：在预处理输入流中当前位置置为添加一个字符 ch

将预处理输入流中的当前位置（`m_cpp_ptr`）置为字符 ch，并将指针向后移动 1 个字符。

```C++
  /**
    Inject a character into the pre-processed stream.

    Note, this function is used to inject a space instead of multi-character
    C-comment. Thus there is no boundary checks here (basically, we replace
    N-chars by 1-char here).
  */
  char *cpp_inject(char ch) {
    *m_cpp_ptr = ch;
    return ++m_cpp_ptr;
  }
```

### 初始化函数

#### `init()`：初始化 `Lex_input_stream` 实例

- 初始化数据成员 `query_charset`（当前线程的字符集）和 `m_thd`（当前线程）
- 为 `m_cpp_buf`（预处理输入流）申请内存空间
- 调用 `reset()` 方法初始化除 `m_cpp_buf` 外的其他所有数据成员

```C++
/**
  Perform initialization of Lex_input_stream instance.

  Basically, a buffer for a pre-processed query. This buffer should be large
  enough to keep a multi-statement query. The allocation is done once in
  Lex_input_stream::init() in order to prevent memory pollution when
  the server is processing large multi-statement queries.
*/

bool Lex_input_stream::init(THD *thd, const char *buff, size_t length) {
  DBUG_EXECUTE_IF("bug42064_simulate_oom",
                  DBUG_SET("+d,simulate_out_of_memory"););

  query_charset = thd->charset();

  m_cpp_buf = (char *)thd->alloc(length + 1);

  DBUG_EXECUTE_IF("bug42064_simulate_oom",
                  DBUG_SET("-d,bug42064_simulate_oom"););

  if (m_cpp_buf == nullptr) return true;

  m_thd = thd;
  reset(buff, length);

  return false;
}
```

#### `reset()`：为下一个 SQL 语句准备 `Lex_input_stream` 实例状态

准备 `Lex_input_stream` 实例状态，以备处理下一个 SQL 语句。在处理多个语句的查询时，会在处理每两个语句之间调用的这个函数。这个函数会重置 `Lex_input_stream` 实例中除 `m_cpp_buf`（预处理数据流）之外的所有数据成员的状态。

```C++
/**
  Prepare Lex_input_stream instance state for use for handling next SQL
  statement.

  It should be called between two statements in a multi-statement query.
  The operation resets the input stream to the beginning-of-parse state,
  but does not reallocate m_cpp_buf.
*/

void Lex_input_stream::reset(const char *buffer, size_t length) {
  yylineno = 1;
  yytoklen = 0;
  yylval = nullptr;
  lookahead_token = grammar_selector_token;
  static Lexer_yystype dummy_yylval;
  lookahead_yylval = &dummy_yylval;
  skip_digest = false;
  /*
    Lex_input_stream modifies the query string in one special case (sic!).
    yyUnput() modifises the string when patching version comments.
    This is done to prevent newer slaves from executing a different
    statement than older masters.

    For now, cast away const here. This means that e.g. SHOW PROCESSLIST
    can see partially patched query strings. It would be better if we
    could replicate the query string as is and have the slave take the
    master version into account.
  */
  m_ptr = const_cast<char *>(buffer);
  m_tok_start = nullptr;
  m_tok_end = nullptr;
  m_end_of_query = buffer + length;
  m_buf = buffer;
  m_buf_length = length;
  m_echo = true;
  m_cpp_tok_start = nullptr;
  m_cpp_tok_end = nullptr;
  m_body_utf8 = nullptr;
  m_cpp_utf8_processed_ptr = nullptr;
  next_state = MY_LEX_START;
  found_semicolon = nullptr;
  ignore_space = m_thd->variables.sql_mode & MODE_IGNORE_SPACE;
  stmt_prepare_mode = false;
  multi_statements = true;
  in_comment = NO_COMMENT;
  m_underscore_cs = nullptr;
  m_cpp_ptr = m_cpp_buf;
}
```

### UTF-8 格式流相关函数

#### `body_utf8_start(...)`：开始生成语句的 UTF-8 格式

调用这个函数后，词法分析器将在 `m_body_utf8`（在解析过程中生成的 UTF-8 格式流）中生成从 `begin_pt` 开始的语句的 UTF-8 的格式。具体地：

- 计算 UTF-8 格式的长度。
- 根据 UTF-8 格式的长度，初始化 `m_body_utf8`（在解析过程中生成的 UTF-8 格式流），并将 `m_body_utf8_ptr`（指向 UTF-8 格式流中的当前位置的指针）指向 UTF-8 格式流的开始位置。
- 将 `m_cpp_utf8_processed_ptr`（指向已写入到 UTF-8 格式流对应的预处理数据流的位置的指针）指向 `begin_ptr` 指针指向的预处理流位置。

```C++
/**
  The operation is called from the parser in order to
  1) designate the intention to have utf8 body;
  1) Indicate to the lexer that we will need a utf8 representation of this
     statement;
  2) Determine the beginning of the body.

  @param thd        Thread context.
  @param begin_ptr  Pointer to the start of the body in the pre-processed
                    buffer.
*/

void Lex_input_stream::body_utf8_start(THD *thd, const char *begin_ptr) {
  assert(begin_ptr);
  assert(m_cpp_buf <= begin_ptr && begin_ptr <= m_cpp_buf + m_buf_length);

  size_t body_utf8_length =
      (m_buf_length / thd->variables.character_set_client->mbminlen) *
      my_charset_utf8mb4_bin.mbmaxlen;

  m_body_utf8 = (char *)thd->alloc(body_utf8_length + 1);
  m_body_utf8_ptr = m_body_utf8;
  *m_body_utf8_ptr = 0;

  m_cpp_utf8_processed_ptr = begin_ptr;
}
```

#### `body_utf8_append(...)`：将预处理数据流复制到 UTF-8 格式数据流中

- 计算从 `m_cpp_utf8_processed_ptr`（指向已写入到 UTF-8 格式流对应的预处理数据流的位置的指针）到需要复制到的预处理工作流中的指针 `ptr` 之间的长度。
- 将预处理数据流中的数据复制到 UTF-8 格式数据流中
- 更新 `m_body_utf8_ptr`（指向 UTF-8 格式流中的当前位置的指针）到复制结束的位置
- 更新 `m_cpp_utf8_processed_ptr`（指向已写入到 UTF-8 格式流对应的预处理数据流的位置的指针）到 `end_ptr` 指针指向的位置

```C++
/**
  @brief The operation appends unprocessed part of pre-processed buffer till
  the given pointer (ptr) and sets m_cpp_utf8_processed_ptr to end_ptr.

  The idea is that some tokens in the pre-processed buffer (like character
  set introducers) should be skipped.

  Example:
    CPP buffer: SELECT 'str1', _latin1 'str2';
    m_cpp_utf8_processed_ptr -- points at the "SELECT ...";
    In order to skip "_latin1", the following call should be made:
      body_utf8_append(<pointer to "_latin1 ...">, <pointer to " 'str2'...">)

  @param ptr      Pointer in the pre-processed buffer, which specifies the
                  end of the chunk, which should be appended to the utf8
                  body.
  @param end_ptr  Pointer in the pre-processed buffer, to which
                  m_cpp_utf8_processed_ptr will be set in the end of the
                  operation.
*/

void Lex_input_stream::body_utf8_append(const char *ptr, const char *end_ptr) {
  assert(m_cpp_buf <= ptr && ptr <= m_cpp_buf + m_buf_length);
  assert(m_cpp_buf <= end_ptr && end_ptr <= m_cpp_buf + m_buf_length);

  if (!m_body_utf8) return;

  if (m_cpp_utf8_processed_ptr >= ptr) return;

  size_t bytes_to_copy = ptr - m_cpp_utf8_processed_ptr;

  memcpy(m_body_utf8_ptr, m_cpp_utf8_processed_ptr, bytes_to_copy);
  m_body_utf8_ptr += bytes_to_copy;
  *m_body_utf8_ptr = 0;

  m_cpp_utf8_processed_ptr = end_ptr;
}
```

在不需要额外指定 `m_cpp_utf8_processed_ptr`（指向已写入到 UTF-8 格式流对应的预处理数据流的位置的指针）时，直接提供需要复制到的结束位置的指针 `ptr` 即可。

```C++
/**
  The operation appends unprocessed part of the pre-processed buffer till
  the given pointer (ptr) and sets m_cpp_utf8_processed_ptr to ptr.

  @param ptr  Pointer in the pre-processed buffer, which specifies the end
              of the chunk, which should be appended to the utf8 body.
*/

void Lex_input_stream::body_utf8_append(const char *ptr) {
  body_utf8_append(ptr, ptr);
}
```

#### `body_utf8_append_literal(...)`：将特殊字符转化为 UTF-8 格式并添加到 UTF-8 格式数据流中

```C++
/**
  The operation converts the specified text literal to the utf8 and appends
  the result to the utf8-body.

  @param thd      Thread context.
  @param txt      Text literal.
  @param txt_cs   Character set of the text literal.
  @param end_ptr  Pointer in the pre-processed buffer, to which
                  m_cpp_utf8_processed_ptr will be set in the end of the
                  operation.
*/

void Lex_input_stream::body_utf8_append_literal(THD *thd, const LEX_STRING *txt,
                                                const CHARSET_INFO *txt_cs,
                                                const char *end_ptr) {
  if (!m_cpp_utf8_processed_ptr) return;

  LEX_STRING utf_txt{nullptr, 0};

  if (!my_charset_same(txt_cs, &my_charset_utf8mb4_general_ci)) {
    thd->convert_string(&utf_txt, &my_charset_utf8mb4_general_ci, txt->str,
                        txt->length, txt_cs);
  } else {
    utf_txt.str = txt->str;
    utf_txt.length = txt->length;
  }

  MY_COMPILER_DIAGNOSTIC_PUSH();
  // GCC 10.2.0 solaris
  MY_COMPILER_GCC_DIAGNOSTIC_IGNORE("-Wmaybe-uninitialized");

  /* NOTE: utf_txt.length is in bytes, not in symbols. */
  memcpy(m_body_utf8_ptr, utf_txt.str, utf_txt.length);
  m_body_utf8_ptr += utf_txt.length;
  *m_body_utf8_ptr = 0;
  MY_COMPILER_DIAGNOSTIC_POP();

  m_cpp_utf8_processed_ptr = end_ptr;
}
```

### 私有数据成员获取方法

- `get_buf()`：获取指向原始输入流的查询文本（query text）的开始位置的指针（`m_buf`）。
- `get_cpp_buf()`：获取指向预处理输入流（开始位置）的指针（`m_cpp_buf`）。
- `get_end_of_query()`：获取指向原始输入流的查询文本（query text）的结束位置的指针（`m_end_of_query`）。

```C++
  /** Get the raw query buffer. */
  const char *get_buf() const { return m_buf; }

  /** Get the pre-processed query buffer. */
  const char *get_cpp_buf() const { return m_cpp_buf; }

  /** Get the end of the raw query buffer. */
  const char *get_end_of_query() const { return m_end_of_query; }
```

- `get_tok_start()`：获取指向原始输入流中当前 token 开始位置的指针（`m_tok_start`）。
- `get_cpp_tok_start()`：获取指向预处理输入流中当前 token 开始位置的指针（`m_cpp_tok_start`）。
- `get_tok_end()`：获取指向原始输入流中当前 token 结束位置的指针（`m_tok_end`）。
- `get_cpp_tok_end()`：获取指向预处理输入流中当前 token 结束位置的指针（`m_cpp_tok_end`）。
- `get_ptr()`：获取指向原始输入流中的当前位置的指针（`m_ptr`）。
- `get_cpp_ptr()`：获取指向预处理输入流中的当前位置的指针（`m_cpp_ptr`）。

```C++
  /** Get the token start position, in the raw buffer. */
  const char *get_tok_start() const { return m_tok_start; }

  /** Get the token start position, in the pre-processed buffer. */
  const char *get_cpp_tok_start() const { return m_cpp_tok_start; }

  /** Get the token end position, in the raw buffer. */
  const char *get_tok_end() const { return m_tok_end; }

  /** Get the token end position, in the pre-processed buffer. */
  const char *get_cpp_tok_end() const { return m_cpp_tok_end; }

  /** Get the current stream pointer, in the raw buffer. */
  const char *get_ptr() const { return m_ptr; }

  /** Get the current stream pointer, in the pre-processed buffer. */
  const char *get_cpp_ptr() const { return m_cpp_ptr; }
```

### 数据成员

#### 私有数据成员

| 私有数据成员名称           | 私有数据成员类型 | 私有数据成员含义                                             |
| -------------------------- | ---------------- | ------------------------------------------------------------ |
| `m_ptr`                    | `char *`         | Pointer to the current position in the raw input stream.<br />指向原始输入流中的当前位置的指针。 |
| `m_tok_start`              | `const char *`   | Starting position of the last token parsed, in the raw buffer.<br />指向原始输入流中当前 token 开始位置的指针。 |
| `m_tok_end`                | `const char *`   | Ending position of the previous token parsed, inthe raw buffer.<br />指向原始输入流中当前 token 结束位置的指针。 |
| `m_end_of_query`           | `const char *`   | End of query text in the input stream, in the raw buffer.<br />指向原始输入流的查询文本（query text）的结束位置的指针。 |
| `m_buf`                    | `const char *`   | Begining of the query text in the input stream, in the raw buffer.<br />指向原始输入流的查询文本（query text）的开始位置的指针。 |
| `m_buf_length`             | `size_t`         | Length of the raw buffer.<br />原始输入流的长度              |
| `m_echo`                   | `bool`           | Echo the parsed stream to the pre-processed buffer.<br />是否将处理后的数据流回显到预处理数据流中。 |
| `m_echo_saved`             | `bool`           | Echo the parsed stream to the pre-processed buffer.<br />是否将处理后的数据流回显到预处理数据流中。 |
| `m_cpp_buf`                | `char *`         | Pre-processed buffer.<br />指向预处理输入流（开始位置）的指针。 |
| `m_cpp_ptr`                | `char *`         | Pointer to the current position in the pre-processed input stream.<br />指向预处理输入流中的当前位置的指针。 |
| `m_cpp_tok_start`          | `const char *`   | Starting position of the last token parsed, in the pre-processed buffer.<br />指向预处理输入流中当前 token 开始位置的指针。 |
| `m_cpp_tok_end`            | `const char *`   | Ending position of the previous token parsed, in the pre-processed buffer.<br />指向预处理输入流中当前 token 结束位置的指针。 |
| `m_body_utf8`              | `char *`         | UTF8-body buffer created during parseing.<br />在解析过程中生成的 UTF-8 格式流 |
| `m_body_utf8_ptr`          | `char *`         | Pointer to the current position in the UTF8-body buffer.<br />指向 UTF-8 格式流中的当前位置的指针。 |
| `m_cpp_utf8_processed_ptr` | `const char *`   | Position in the pre-processed buffer. The query from m_cpp_buf to m_cpp_utf_processed_ptr is convered to UTF8-body.<br />指向已写入到 UTF-8 格式流对应的预处理数据流的位置的指针。 |

#### 公有数据成员

| 公有数据成员名称         | 公有数据成员类型       | 公有数据成员含义                                             |
| ------------------------ | ---------------------- | ------------------------------------------------------------ |
| `m_thd`                  | `THD *`                | Current thread.<br />当前线程                                |
| `yylineno`               | `uint`                 | Current line number.<br />当前行号                           |
| `yytoken`                | `uint`                 | Length of the last token parsed.<br />上一个解析的 token 的长度 |
| `yylval`                 | `LKexer_yystype *`     | Interface with bison, value of the last token parsed.<br />Bison 的接口，上一个解析的 token 的值 |
| `lookahead_token`        | `int`                  | LALR(2) resolution, look ahead token. Value fo the next token to return, if any, or -1, if no token was parsed in advance. Node: 0 is a legal token, and represents YYEOF. |
| `lookahead_yylval`       | `Lexer_yystype *`      | LALR(2) resolution, value of the look ahead token.           |
| `skip_digest`            | `bool`                 | Skip adding of the current token's digest since it is already added. |
| `query_charset`          | `const CHARSET_INFO`   | 当前线程的字符集                                             |
| `next_state`             | `enum my_lex_states`   | Current state of the lexical analyser.<br />词法分析器的当前状态 |
| `found_semicolon`        | `const char *`         | Position of ';' in the stream, to delimit multiplke queries. This delimiter is in the raw buffer.<br />原始数据流中半角分号（`;`）的位置，用于处理多语句的查询 |
| `tok_bitmap`             | `uchar`                | Token character bitmaps, to detect 7bit strings.             |
| `ignore_space`           | `bool`                 | SQL_MODE = IGNORE_SPACE                                      |
| `stmt_prepare_mode`      | `bool`                 | true if we're parsing a prepared statement: in this mode we should allow placeholders.<br />是否正在处理预处理的语句 |
| `multi_statements`       | `bool`                 | true if we should allow multi-statements.<br />是否正在处理多语句 |
| `in_comment`             | `enum_comment_state`   | State of the lexcial analyser for comment.<br />词法分析器当前的注释状态 |
| `in_comment_saved`       | `enum_comment_state`   | State of the lexcial analyser for comment.<br />词法分析器当前的注释状态 |
| `m_cpp_text_start`       | `const char *`         | Starting position of the TEXT_STRING or INDENT in the pre-processed buffer.<br />`TEXT_STRING` 或 `INDENT` 在预处理数据流中的开始位置 |
| `m_cpp_text_end`         | `const char *`         | Ending position of the TEXT_STRING or IDENT in the pre-processed buffer.<br />`TEXT_STRING` 或 `INDENT` 在预处理数据流中的结束位置 |
| `m_underscore_cs`        | `const CHARSET_INFO *` | Character set specified by the character-set-introducer.<br />字符集引导器（Character Set Introducer）指定的字符集 |
| `m_digest`               | `sql_digest_state *`   | Current statement digest instrumentation.                    |
| `grammar_selector_token` | `const int`            | The synthetic 1st token to prepend token stream with.<br />数据流中合成的第一个前置 token |
