目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_lex.cc](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_lex.cc)

---

#### `my_sql_parser_lex` 函数

根据 [MySQL 源码｜82 - 词法解析和语法解析的入口逻辑](https://zhuanlan.zhihu.com/p/720494111)，我们知道 MySQL 词法解析的入口函数是 [sql/sql_lex.cc](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_lex.cc) 中定义的 `my_sql_parser_lex()` 函数。这个函数的注释如下：

```C++
/**
  yylex() function implementation for the main parser

  @param [out] yacc_yylval   semantic value of the token being parsed (yylval)
  @param [out] yylloc        "location" of the token being parsed (yylloc)
  @param thd                 THD

  @return                    token number

  @note
  my_sql_parser_lex remember the following states from the
  following my_sql_parser_lex():

  - MY_LEX_END			Found end of query
*/
```

其中说明了 `my_sql_parser_lex()` 函数作为修改了前缀的 `yylex()` 函数，是为 Bison 主解析器实现的词法分析器，其 3 个参数的含义如下：

- `yacc_yylval`：被解析的 Token 的语义值（编码）
- `yylloc`：被解析的 Token 的 “位置”
- `thd`：线程上下文

该函数的返回值为 Token 的类型，即 Bison 语法解析器的终结符的编码。

该函数的源码如下：

```C++
int my_sql_parser_lex(MY_SQL_PARSER_STYPE *yacc_yylval, POS *yylloc, THD *thd) {
  auto *yylval = reinterpret_cast<Lexer_yystype *>(yacc_yylval);
  Lex_input_stream *lip = &thd->m_parser_state->m_lip;
  int token;

  if (thd->is_error()) {
    if (thd->get_parser_da()->has_sql_condition(ER_CAPACITY_EXCEEDED))
      return ABORT_SYM;
  }

  if (lip->lookahead_token >= 0) {
    /*
      The next token was already parsed in advance,
      return it.
    */
    token = lip->lookahead_token;
    lip->lookahead_token = -1;
    *yylval = *(lip->lookahead_yylval);
    yylloc->cpp.start = lip->get_cpp_tok_start();
    yylloc->cpp.end = lip->get_cpp_ptr();
    yylloc->raw.start = lip->get_tok_start();
    yylloc->raw.end = lip->get_ptr();
    lip->lookahead_yylval = nullptr;
    lip->add_digest_token(token, yylval);
    return token;
  }

  token = lex_one_token(yylval, thd);
  yylloc->cpp.start = lip->get_cpp_tok_start();
  yylloc->raw.start = lip->get_tok_start();

  switch (token) {
    case WITH:
      /*
        Parsing 'WITH' 'ROLLUP' requires 2 look ups,
        which makes the grammar LALR(2).
        Replace by a single 'WITH_ROLLUP' token,
        to transform the grammar into a LALR(1) grammar,
        which sql_yacc.yy can process.
      */
      token = lex_one_token(yylval, thd);
      switch (token) {
        case ROLLUP_SYM:
          yylloc->cpp.end = lip->get_cpp_ptr();
          yylloc->raw.end = lip->get_ptr();
          lip->add_digest_token(WITH_ROLLUP_SYM, yylval);
          return WITH_ROLLUP_SYM;
        default:
          /*
            Save the token following 'WITH'
          */
          lip->lookahead_yylval = lip->yylval;
          lip->yylval = nullptr;
          lip->lookahead_token = token;
          yylloc->cpp.end = lip->get_cpp_ptr();
          yylloc->raw.end = lip->get_ptr();
          lip->add_digest_token(WITH, yylval);
          return WITH;
      }
      break;
  }

  yylloc->cpp.end = lip->get_cpp_ptr();
  yylloc->raw.end = lip->get_ptr();
  if (!lip->skip_digest) lip->add_digest_token(token, yylval);
  lip->skip_digest = false;
  return token;
}
```

这个函数作为词法解析的入口，连接了词法解析与语法解析的逻辑，理解其具体逻辑对后续理解词法解析、语法解析至关重要。因此，具体梳理其逻辑如下：

**Step 1**｜使用了 `reinterpret_cast` 来将一个指向 `MY_SQL_PARSER_STYPE` 联合体的指针 `yacc_yylval` 转换成指向 `Lexer_yystype` 联合体的指针，并将其赋值给变量 `yylval`。这是因为词法解析仅生成联合体 `Lexer_yystype` 中的类型，而 `MY_SQL_PARSER_STYPE` 联合体中的类型则是由语法解析生成。

```C++
auto *yylval = reinterpret_cast<Lexer_yystype *>(yacc_yylval);
```

**Step 2**｜读取当前线程上下文中的词法输入流（状态存储器），逻辑详见 [MySQL 源码｜13 - 词法解析的状态存储器（Lex_input_stream）的主要数据成员与函数](https://zhuanlan.zhihu.com/p/714758654)。

```C++
Lex_input_stream *lip = &thd->m_parser_state->m_lip;
```

**Step 3**｜初始化返回值 `token`，表示 Token 的类型

```C++
int token;
```

**Step 4**｜如果当前线程上下文中已经出现报错，且 `ER_CAPACITY_EXCEEDED` 出现在条件列表中（默认存在），在返回 `ABORT_SYM` 类型。这个类型在 Bison 语法中并没有使用，出现后应该会触发语法解析报错并退出。

```C++
if (thd->is_error()) {
  if (thd->get_parser_da()->has_sql_condition(ER_CAPACITY_EXCEEDED))
    return ABORT_SYM;
}
```

**Step 5**｜如果下一个 Token 已经被提前解析（`WITH` 和 `ROLLUP` 需要提前解析 Token）并存储在 `lip->lookahead_token` 中，则返回已提前解析的 Token，其中 Token 的类型来自 `lip->lookahead_token`，Token 的语义值来自 `lip->lookahead_yylval`，并将 `lip->lookahead_token` 和 `lip->lookahead_yylval` 置为空。

```C++
if (lip->lookahead_token >= 0) {
  /*
    The next token was already parsed in advance,
    return it.
  */
  token = lip->lookahead_token;
  lip->lookahead_token = -1;
  *yylval = *(lip->lookahead_yylval);
  yylloc->cpp.start = lip->get_cpp_tok_start();
  yylloc->cpp.end = lip->get_cpp_ptr();
  yylloc->raw.start = lip->get_tok_start();
  yylloc->raw.end = lip->get_ptr();
  lip->lookahead_yylval = nullptr;
  lip->add_digest_token(token, yylval);
  return token;
}
```

> `lip->get_cpp_tok_start()`：获取指向预处理输入流中当前 token 开始位置的指针；
>
> `lip->get_cpp_ptr()`：获取指向预处理输入流中的当前位置（即结束位置）的指针；
>
> `lip->get_tok_start()`：获取指向原始输入流中当前 token 开始位置的指针；
>
> `lip->get_ptr()`：获取指向原始输入流中的当前位置（即结束位置）的指针；
>
> `lip->add_digest_token()`：用于根据当前 Token 类型和字面值，存储已解析的 Token。

**Step 6**｜调用 `lex_one_token` 函数解析一个 Token，该函数会解析下一个 Token，将 Token 的语义值和开始、结束位置存储到 `lip` 中，并返回 Token 的类型。`lex_one_token` 函数即 MySQL 词法解析的主逻辑，详见 [MySQL 源码｜8 - 词法解析：lex_one_token 函数外层逻辑](https://zhuanlan.zhihu.com/p/714756661)。

```C++
token = lex_one_token(yylval, thd);
```

**Step 7**｜将当前 Token 在原始输入流和预处理输入流中的开始位置添加到 `yylloc` 中。

```C++
yylloc->cpp.start = lip->get_cpp_tok_start();
yylloc->raw.start = lip->get_tok_start();
```

**Step 8**｜特别处理 `WITH` 关键字的解析逻辑。如果当前 Token 类型为 `WITH`（即当前 Token 是 `WITH` 关键字），则再解析下一个 Token，并根据该 Token 做出如下处理：

- 如果下一个 Token是 `ROLLUP` 关键字，则将 `WITH ROLLUP` 视为一个 Token，将 `ROLLUP` 的结束位置添加到 `yylloc` 中，返回 `WITH_ROLLUP_SYM` 作为 Token 类型；
- 如果下一个 Token 不是 `ROLLUP` 关键字，则将 `WITH` 关键字之后的 Token 类型和字面值存储到 `lip->lookahead_token` 和 `lip->lookahead_yylval`职中，并将 `WITH` 关键字之后的 Token 的结束位置添加到 `yylloc` 中，返回 `WITH` 作为 Token 类型。

```C++
switch (token) {
  case WITH:
    /*
      Parsing 'WITH' 'ROLLUP' requires 2 look ups,
      which makes the grammar LALR(2).
      Replace by a single 'WITH_ROLLUP' token,
      to transform the grammar into a LALR(1) grammar,
      which sql_yacc.yy can process.
    */
    token = lex_one_token(yylval, thd);
    switch (token) {
      case ROLLUP_SYM:
        yylloc->cpp.end = lip->get_cpp_ptr();
        yylloc->raw.end = lip->get_ptr();
        lip->add_digest_token(WITH_ROLLUP_SYM, yylval);
        return WITH_ROLLUP_SYM;
      default:
        /*
          Save the token following 'WITH'
        */
        lip->lookahead_yylval = lip->yylval;
        lip->yylval = nullptr;
        lip->lookahead_token = token;
        yylloc->cpp.end = lip->get_cpp_ptr();
        yylloc->raw.end = lip->get_ptr();
        lip->add_digest_token(WITH, yylval);
        return WITH;
    }
    break;
}
```

**Step 9**｜如果当前 Token 不是 `WITH` 关键字，则将当前 Token 的结束位置添加到 `yylloc` 中。

```C++
yylloc->cpp.end = lip->get_cpp_ptr();
yylloc->raw.end = lip->get_ptr();
```

**Step 10**｜如果需要则根据当前 Token 类型和字面值，存储已解析的 Token。

```C++
if (!lip->skip_digest) lip->add_digest_token(token, yylval);
lip->skip_digest = false;
```

**Step 11**｜返回当前 Token 类型。

```C++
return token;
```

概括来说，`my_sql_parser_lex()` 函数的逻辑，就是将词法解析主函数 `lex_one_token` 封装了一层，实现了对于 `WITH ROLLUP` 的合并逻辑，并为 `yylval` 和 `yylloc` 完成赋值。

