目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)；[sql/parse_tree_nodes.h](https://github.com/mysql/mysql-server/blob/trunk/sql/parse_tree_nodes.h)；[sql/parse_tree_nodes.cc](https://github.com/mysql/mysql-server/blob/trunk/sql/parse_tree_nodes.cc)；[sql/sql_select.h](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_select.h)；[sql/sql_cmd_dml.h](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_cmd_dml.h)；[sql/sql_select.cc](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_select.cc)

---

根据 [MySQL 源码｜83 - SQL 语句的执行过程](https://zhuanlan.zhihu.com/p/720779596)，我们知道 MySQL 在语法解析后的执行逻辑如下：

- 语法解析最终生成了 `Parse_tree_root` 的子类的对象，作为语句的根节点
- 调用 `Parse_tree_root::make_cmd()` 函数，根据语句的抽象语法树（AST）构造 `Sql_cmd` 对象
- 调用 `mysql_execute_command()` 函数并在其中调用 `Sql_cmd::execute()` 函数，以执行 SQL 语句

下面，我们以普通的 `SELECT` 语句为例来具体分析这个过程。

**Part 1**｜在 [sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy) 中，用于解析 `SELECT` 语句的语义组如下，其返回值为 `PT_select_stmt` 的对象。

```C++
select_stmt:
          query_expression
          {
            $$ = NEW_PTN PT_select_stmt(@$, $1);
          }
        | query_expression locking_clause_list
          {
            $$ = NEW_PTN PT_select_stmt(@$, NEW_PTN PT_locking(@$, $1, $2),
                                        nullptr, true);
          }
        | select_stmt_with_into
        ;
```

**Part 2**｜`PT_select_stmt` 类在 [sql/parse_tree_nodes.h](https://github.com/mysql/mysql-server/blob/trunk/sql/parse_tree_nodes.h) 中被定义，它是 `Parse_tree_root` 的子类，并重写了基类中的虚函数 `make_cmd` 。对于普通的 `SELECT` 语句，`PT_select_stmt` 的构造命令为 `$$ = NEW_PTN PT_select_stmt(@$, $1);`，此时调用的是第 2 个构造函数，此时其 `m_sql_command` 为 `SQLCOM_SELECT`。

```C++
class PT_select_stmt : public Parse_tree_root {
  typedef Parse_tree_root super;

 public:
  /**
    @param pos Position of this clause in the SQL statement.
    @param qe The query expression.
    @param sql_command The type of SQL command.
  */
  PT_select_stmt(const POS &pos, enum_sql_command sql_command,
                 PT_query_expression_body *qe)
      : super(pos),
        m_sql_command(sql_command),
        m_qe(qe),
        m_into(nullptr),
        m_has_trailing_locking_clauses{false} {}

  /**
    Creates a SELECT command. Only SELECT commands can have into.

    @param pos                          Position of this clause in the SQL
                                        statement.
    @param qe                           The query expression.
    @param into                         The own INTO destination.
    @param has_trailing_locking_clauses True if there are locking clauses (like
                                        `FOR UPDATE`) at the end of the
                                        statement.
  */
  explicit PT_select_stmt(const POS &pos, PT_query_expression_body *qe,
                          PT_into_destination *into = nullptr,
                          bool has_trailing_locking_clauses = false)
      : super(pos),
        m_sql_command{SQLCOM_SELECT},
        m_qe{qe},
        m_into{into},
        m_has_trailing_locking_clauses{has_trailing_locking_clauses} {}

  Sql_cmd *make_cmd(THD *thd) override;
  std::string get_printable_parse_tree(THD *thd) override;

 private:
  enum_sql_command m_sql_command;
  PT_query_expression_body *m_qe;
  PT_into_destination *m_into;
  const bool m_has_trailing_locking_clauses;
};
```

**Part 3**｜`PT_select_stmt` 类的 `make_cmnd` 成员函数在 [sql/parse_tree_nodes.cc](https://github.com/mysql/mysql-server/blob/trunk/sql/parse_tree_nodes.cc) 中被实现，在经过检查逻辑后，根据在 Bison 语法解析器中传入的 `sql_command` 的差异，构造 `Sql_cmd_select` 对象或 `Sql_cmd_do` 对象。对于普通 `SELECT` 语句，因为 `m_sql_command` 为 `SQLCOM_SELECT`，所以构造的是 `Sql_cmd_select` 对象。

```C++
Sql_cmd *PT_select_stmt::make_cmd(THD *thd) {
  Parse_context pc(thd, thd->lex->current_query_block());

  thd->lex->sql_command = m_sql_command;

  if (m_qe->contextualize(&pc)) {
    return nullptr;
  }

  const bool has_into_clause_inside_query_block = thd->lex->result != nullptr;

  if (has_into_clause_inside_query_block && m_into != nullptr) {
    my_error(ER_MULTIPLE_INTO_CLAUSES, MYF(0));
    return nullptr;
  }
  if (contextualize_safe(&pc, m_into)) {
    return nullptr;
  }

  if (pc.finalize_query_expression()) return nullptr;

  // Ensure that first query block is the current one
  assert(pc.select->select_number == 1);

  if (m_into != nullptr && m_has_trailing_locking_clauses) {
    // Example: ... INTO ... FOR UPDATE;
    push_warning(thd, ER_WARN_DEPRECATED_INNER_INTO);
  } else if (has_into_clause_inside_query_block &&
             thd->lex->unit->is_set_operation()) {
    // Example: ... UNION ... INTO ...;
    if (!m_qe->has_trailing_into_clause()) {
      // Example: ... UNION SELECT * INTO OUTFILE 'foo' FROM ...;
      push_warning(thd, ER_WARN_DEPRECATED_INNER_INTO);
    } else if (m_has_trailing_locking_clauses) {
      // Example: ... UNION SELECT ... FROM ... INTO OUTFILE 'foo' FOR UPDATE;
      push_warning(thd, ER_WARN_DEPRECATED_INNER_INTO);
    }
  }

  DBUG_EXECUTE_IF("ast", Query_term *qn =
                             pc.select->master_query_expression()->query_term();
                  std::ostringstream buf; qn->debugPrint(0, buf);
                  DBUG_PRINT("ast", ("\n%s", buf.str().c_str())););

  if (thd->lex->sql_command == SQLCOM_SELECT)
    return new (thd->mem_root) Sql_cmd_select(thd->lex->result);
  else  // (thd->lex->sql_command == SQLCOM_DO)
    return new (thd->mem_root) Sql_cmd_do(nullptr);
}
```

**Part 4**｜`Sql_cmd_select` 类在 [sql/sql_select.h](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_select.h) 中被定义，作为 `Sql_cmd_dml` 的子类，其 `execute()` 成员函数继承自 `Sql_cmd_dml` 类。

```C++
class Sql_cmd_select : public Sql_cmd_dml {
 public:
  explicit Sql_cmd_select(Query_result *result_arg) : Sql_cmd_dml() {
    result = result_arg;
  }

  enum_sql_command sql_command_code() const override { return SQLCOM_SELECT; }

  bool is_data_change_stmt() const override { return false; }

  bool accept(THD *thd, Select_lex_visitor *visitor) override;

  const MYSQL_LEX_CSTRING *eligible_secondary_storage_engine(
      THD *thd) const override;

 protected:
  bool may_use_cursor() const override { return true; }
  bool precheck(THD *thd) override;
  bool check_privileges(THD *thd) override;
  bool prepare_inner(THD *thd) override;
};
```

**Part 5**｜`Sql_cmd_dml` 类在 [sql/sql_cmd_dml.h](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_cmd_dml.h) 中被定义，`Sql_cmd` 类是 `Sql_cmd` 的子类，其中重写了基类中的虚函数 `prepare()` 和 `execute()`。

```C++
class Sql_cmd_dml : public Sql_cmd {
 public:
  /// @return true if data change statement, false if not (SELECT statement)
  virtual bool is_data_change_stmt() const { return true; }

  bool prepare(THD *thd) override;

  bool execute(THD *thd) override;
    
......
```

**Part 6**｜`Sql_cmd_dml` 类的 `execute()` 成员函数在 [sql/sql_select.cc](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_select.cc) 中被实现。



