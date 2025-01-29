目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：

- [router/src/routing/src/sql_lexer.cc](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/sql_lexer.cc)
- [router/src/routing/src/sql_lexer_input_stream.h](https://github.com/mysql/mysql-server/blob/trunk/router/src/routing/src/sql_lexer_input_stream.h)

---

## 数据成员

#### 私有数据成员

| 私有数据成员名称           | 私有数据成员类型 | 私有数据成员含义                                             |
| -------------------------- | ---------------- | ------------------------------------------------------------ |
| `m_ptr`                    | `char *`         | Pointer to the current position in the raw input stream.<br />指向原始输入流中的当前位置 |
| `m_tok_start`              | `const char *`   | Starting position of the last token parsed, in the raw buffer.<br />指向原始输入流中上一个 token 的开始位置 |
| `m_tok_end`                | `const char *`   | Ending position of the previous token parsed, inthe raw buffer.<br />指向原始输入流中上一个 token 的结束位置 |
| `m_end_of_query`           | `const char *`   | End of query text in the input stream, in the raw buffer.<br />指向原始输入流中当前 query text 的结束位置 |
| `m_buf`                    | `const char *`   | Begining of the query text in the input stream, in the raw buffer.<br />指向原始输入流中当前 query text 的开始位置 |
| `m_buf_length`             | `size_t`         | Length of the raw buffer.<br />原始输入流的长度              |
| `m_echo`                   | `bool`           | Echo the parsed stream to the pre-processed buffer.          |
| `m_echo_saved`             | `bool`           | Echo the parsed stream to the pre-processed buffer.          |
| `m_cpp_buf`                | `char *`         | Pre-processed buffer.<br />预处理输入流                      |
| `m_cpp_ptr`                | `char *`         | Pointer to the current position in the pre-processed input stream.<br />指向预处理输入流中的当前位置 |
| `m_cpp_tok_start`          | `const char *`   | Starting position of the last token parsed, in the pre-processed buffer.<br />指向预处理输入流中上一个 token 的开始位置 |
| `m_cpp_tok_end`            | `const char *`   | Ending position of the previous token parsed, in the pre-processed buffer.<br />指向预处理输入流中上一个 token 的结束位置 |
| `m_body_utf8`              | `char *`         | UTF8-body buffer created during parseing.<br />在解析过程中生成的 UTF-8 格式流 |
| `m_body_utf8_ptr`          | `char *`         | Pointer to the current position in the UTF8-body buffer.<br />指向 UTF-8 格式流中的当前位置 |
| `m_cpp_utf8_processed_ptr` | `const char *`   | Position in the pre-processed buffer. The query from m_cpp_buf to m_cpp_utf_processed_ptr is convered to UTF8-body. |

### 公有数据成员

| 公有数据成员名称         | 公有数据成员类型       | 公有数据成员含义                                             |
| ------------------------ | ---------------------- | ------------------------------------------------------------ |
| `m_thd`                  | `THD *`                | Current thread.<br />当前线程                                |
| `yylineno`               | `uint`                 | Current line number.<br />当前行号                           |
| `yytoken`                | `uint`                 | Length of the last token parsed.<br />上一个解析的 token 的长度 |
| `yylval`                 | `LKexer_yystype *`     | Interface with bison, value of the last token parsed.<br />Bison 的接口，上一个解析的 token 的值 |
| `lookahead_token`        | `int`                  | LALR(2) resolution, look ahead token. Value fo the next token to return, if any, or -1, if no token was parsed in advance. Node: 0 is a legal token, and represents YYEOF. |
| `lookahead_yylval`       | `Lexer_yystype *`      | LALR(2) resolution, value of the look ahead token.           |
| `skip_digest`            | `bool`                 | Skip adding of the current token's digest since it is already added. |
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

