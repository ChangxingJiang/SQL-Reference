目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_select.cc](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_select.cc)

---

根据 [MySQL 源码｜87 - SELECT 语句解析后的执行过程](https://zhuanlan.zhihu.com/p/721410833)，我们知道在 MySQL 中，DML 的执行逻辑入口为 `Sql_cmd_dml::execute(THD *thd)` 函数，该函数在 [sql/sql_select.h](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_select.h) 中被定义，在 [sql/sql_select.cc](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_select.cc) 中被实现。

#### `Sql_cmd_dml::execute()` 函数

在 `Sql_cmd_dml::execute()` 函数中，对 SQL 语句执行如下逻辑流程（在之前已被解析完成）：

- 预锁定（prelocking）
- 准备（preparation）：如果是预编译语句则跳过
- 添加表锁（locking of table）
- 优化（optimization）
- 执行（execution）或解释（explain）
- 清理（cleanup）

`Sql_cmd_dml::execute()` 函数被用于处理如下类型的 SQL：`SELECT`、`INSERT ... SELECT`、`INSERT ... VALUES`、`REPALCE ... SELECT`、`REPLACE ... VALUES`、`UPDATE`、`DELETE`、`DO`。

因为这些 DML 语句几乎是 MySQL 中最核心的语句，所以我们梳理这个函数的主要逻辑，以了解 MySQL 执行 DML 语句的具体过程。

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute(THD *thd)

lex = thd->lex;

Query_expression *const unit = lex->unit;

bool statement_timer_armed = false;
bool error_handler_active = false;

Ignore_error_handler ignore_handler;
Strict_error_handler strict_handler;
```

如果当前语句需要设置超时时间的计时器，则设置它：

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute(THD *thd)

// If a timer is applicable to statement, then set it.
if (is_timer_applicable_to_statement(thd))
  statement_timer_armed = set_statement_timer(thd);
```

> `is_timer_applicable_to_statement()` 函数用于检查最大语句时间是否适用于该语句，这要求该语句必须满足如下要求：
>
> - 是 `SELECT` 语句
> - 计时器支持且已经初始化
> - 该语句不是由子线程（slave thread）发出的
> - 该语句尚未设置计时器
> - 设置了超时时间
> - `SELECT` 语句不是来自任何存储程序（stored program）

> `set_statement_timer()` 函数用于设置当前语句的超时时间。

如果当前语句需要更新数据，根据 SQL 语句生成 `IGNORE` 模式和严格模式的错误处理器。

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute(THD *thd)

if (is_data_change_stmt()) {
  // Push ignore / strict error handler
  if (lex->is_ignore()) {
    thd->push_internal_handler(&ignore_handler);
    error_handler_active = true;
    /*
      UPDATE IGNORE can be unsafe. We therefore use row based
      logging if mixed or row based logging is available.
      TODO: Check if the order of the output of the select statement is
      deterministic. Waiting for BUG#42415
    */
    if (lex->sql_command == SQLCOM_UPDATE)
      lex->set_stmt_unsafe(LEX::BINLOG_STMT_UNSAFE_UPDATE_IGNORE);
  } else if (thd->is_strict_mode()) {
    thd->push_internal_handler(&strict_handler);
    error_handler_active = true;
  }
}
```

> `is_data_change_stmt()` 函数返回当前语句是否会更新数据，除 `SELECT` 语句返回 `false` 外，其他语句均返回 `true`。
>
> `is_ignore()` 函数返回当前语句是否包含 `IGNORE` 的逻辑。

##### 第 1 阶段和第 2 阶段：预锁定（prelocking）和准备（preparation）

如果当前语句还没有准备，则调用 `prepare()` 函数来编译，如果语句已经准备，则执行如下逻辑：

- 调用 `open_tables_for_query()` 函数打开表并展开视图，完成预锁定（prelocking）；
- 根据 MySQL 配置，设置是否需要使用超图优化器（hypergraph optimizer）；
- 如果需要使用超图优化器（hypergraph optimizer）但当前 `LEX` 中没有使用超图优化器，则调用 `ask_to_reprepare()` 函数以重新准备；
- 调用 `restore_cmd_properties()` 函数以恢复此查询块及其所有底层查询表达式的预编译语句属性；
- 调用 `check_privileges()` 函数预编译的 SELECT 语句执行授权检查；
- 如果 `m_lazy_result` 为 true，即需要在下一次执行时准备结果，则调用 `result->prepare` 来准备结果。

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute(THD *thd)

if (!is_prepared()) {
  if (prepare(thd)) goto err;
} else {
  cleanup(thd);
  if (open_tables_for_query(thd, lex->query_tables, 0)) goto err;

  // Use the hypergraph optimizer for the SELECT statement, if enabled.
  const bool need_hypergraph_optimizer =
      thd->optimizer_switch_flag(OPTIMIZER_SWITCH_HYPERGRAPH_OPTIMIZER);

  if (need_hypergraph_optimizer != lex->using_hypergraph_optimizer() &&
      ask_to_reprepare(thd)) {
    goto err;
  }

  // Bind table and field information
  if (restore_cmd_properties(thd)) goto err;
  if (check_privileges(thd)) goto err;

  if (m_lazy_result) {
    const Prepared_stmt_arena_holder ps_arena_holder(thd);

    if (result->prepare(thd, *unit->get_unit_column_types(), unit)) goto err;
    m_lazy_result = false;
  }
}
```

> `restore_cmd_properties()` 函数：恢复此查询块及其所有底层查询表达式的预编译语句属性，将保存在 Table_ref 对象中的属性恢复到相应的 TABLE 中，恢复 ORDER BY 和 GROUP BY 子句以及窗口定义，使它们准备好进行优化。
> `check_privileges()` 函数：对预编译的 SELECT 语句执行授权检查。

调用 `validate_use_secondary_engine()` 函数以验证是否需要使用次级存储引擎（secondary storage engine）并检查是否满足使用条件：

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute(THD *thd)
if (validate_use_secondary_engine(lex)) goto err;
```

调用 `set_exec_started()` 函数，标记当前语句已经开始运行：

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute(THD *thd)
lex->set_exec_started();
```

调用 `clear_current_query_costs()` 函数以清空当前的请求消耗记录变量：

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute(THD *thd)
thd->clear_current_query_costs();
```

##### 第 3 阶段：添加表锁（locking of table）

如果不能保证不会返回结果，则需要调用 `lock_tables()` 函数以添加表锁。添加表锁是在准备阶段之后，优化阶段之前进行的。这样可以更好地实现分区裁剪，并避免锁定未使用的分区。因此，在这种情况下，准备阶段只需要依赖于所使用表的元数据，而不需要依赖这些表中的实际数据。

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute(THD *thd)
if (!is_empty_query()) {
  if (lock_tables(thd, lex->query_tables, lex->table_count, 0)) goto err;
}
```

调用 `execute_inner(thd)` 函数执行语句：

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute(THD *thd)

// Perform statement-specific execution
if (execute_inner(thd)) goto err;
```

##### 第 4 阶段：优化（optimization）

在 `execute_inner()` 函数中，首先调用 `Query_expression::optimize()` 函数进行优化，当 `Query_expression::optimize()` 函数出现异常时，`execute_inner()` 函数直接返回 `true`：

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute_inner(THD *thd)

Query_expression *unit = lex->unit;

if (unit->optimize(thd, /*materialize_destination=*/nullptr,
                 /*create_iterators=*/true, /*finalize_access_paths=*/true))
  return true;
```

继续调用 `accumulate_statement_cost()` 函数计算当前表达式的消耗，并在该函数中将消耗计算结果存储到 `lex->thd->m_current_query_cost` 中：

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute_inner(THD *thd)

// Calculate the current statement cost.
accumulate_statement_cost(lex);
```

如果需要，则调用 `optimize_secondary_engine()` 函数进行次级引擎优化：

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute_inner(THD *thd)

// Perform secondary engine optimizations, if needed.
if (optimize_secondary_engine(thd)) return true;
```

##### 第 5 阶段：执行（execution）或解释（explain）

将当前语句状态标记为已执行完成：

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute_inner(THD *thd)

lex->set_exec_completed();
```

当语句为解释语句时，调用 `explain_query()` 函数执行解释逻辑；当语句不是解释语句时，调用 `Query_expression::execute(THD *thd)` 执行语句逻辑，在执行结束后，判断本次查询成本是否高于次级引擎的阈值，若高于则调用 `notify_plugins_after_select` 钩子。

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute_inner(THD *thd)

if (lex->is_explain()) {
  for (Table_ref *ref = lex->query_tables; ref != nullptr;
       ref = ref->next_global) {
    if (ref->table != nullptr && ref->table->file != nullptr) {
      handlerton *hton = ref->table->file->ht;
      if (hton->external_engine_explain_check != nullptr) {
        if (hton->external_engine_explain_check(thd)) return true;
      }
    }
  }

  if (explain_query(thd, thd, unit)) return true; /* purecov: inspected */
} else {
  if (unit->execute(thd)) return true;

  /* Only call the plugin hook if the query cost is higher than the secondary
   * engine threshold. This prevents calling plugin_foreach for short queries,
   * reducing the overhead. */
  if (thd->m_current_query_cost >
      thd->variables.secondary_engine_cost_threshold) {
    notify_plugins_after_select(thd, lex->m_sql_cmd);
  }
}
```

`execute_inner()` 函数的逻辑到此结束。

##### 第 6 阶段：清理（cleanup）

统计被转移到次级引擎的语句数量：

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute(THD *thd)

// Count the number of statements offloaded to a secondary storage engine.
if (using_secondary_storage_engine() && lex->unit->is_executed()) {
  ++thd->status_var.secondary_engine_execution_count;
  global_aggregated_stats.get_shard(thd->thread_id())
      .secondary_engine_execution_count++;
}
```

剔除忽略、严格错误处理器：

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute(THD *thd)

// Pop ignore / strict error handler
if (error_handler_active) thd->pop_internal_handler();
```

执行清理逻辑：

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute(THD *thd)

// Do partial cleanup (preserve plans for EXPLAIN).
lex->cleanup(false);
lex->clear_values_map();
lex->set_secondary_engine_execution_context(nullptr);
```

清理语句的执行结果：

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute(THD *thd)

// Perform statement-specific cleanup for Query_result
if (result != nullptr) result->cleanup();
```

调用 `save_current_query_costs()` 函数，存储当前语句消耗：

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute(THD *thd)
thd->save_current_query_costs();
```

调用 `update_previous_found_rows()` 函数，更新上一个语句（即当前语句）的影响行数：

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute(THD *thd)
thd->update_previous_found_rows();
```

如果初始化了语句的计时器，则调用 `reset_statement_timer` 函数重置它：

```C++
// 源码位置：sql/sql_select.cc > Sql_cmd_dml::execute(THD *thd)
if (statement_timer_armed && thd->timer) reset_statement_timer(thd);
```

#### `Sql_cmd_dml::prepare()` 函数

梳理 `Sql_cmd_dml::prepare()` 函数的主要逻辑，以了解 MySQL 执行 DML 语句的准备阶段。

```C++
bool error_handler_active = false;

Ignore_error_handler ignore_handler;
Strict_error_handler strict_handler;

// @todo: Move this to constructor?
lex = thd->lex;

// Parser may have assigned a specific query result handler
result = lex->result;
```

如果当前语句需要更新数据且为预编译语句时，根据 SQL 语句生成 `IGNORE` 模式和严格模式的内部错误处理器：

```C++
if (is_data_change_stmt() && needs_explicit_preparation()) {
  // Push ignore / strict error handler
  if (lex->is_ignore()) {
    thd->push_internal_handler(&ignore_handler);
    error_handler_active = true;
  } else if (thd->is_strict_mode()) {
    thd->push_internal_handler(&strict_handler);
    error_handler_active = true;
  }
}
```

调用 `precheck()` 函数进行粗略的语句特定权限检查（statement-specific privilege check）：

```C++
if (precheck(thd)) goto err;
```

##### 第 1 阶段：预锁定（prelocking）

打开表并展开视图（view）。在查询准备阶段（并不是执行的一部分），仅获取元数据 S 锁而不是 SW 锁，以便与并发的表写锁（LOCK TABLES WRITE）以及全局读锁（global read lock）兼容。这里即对应 DML 执行的六个阶段中的 "预锁定（prelocking）"。如果出现异常则生成错误信息并清理（cleanup）：

```C++
if (open_tables_for_query(
        thd, lex->query_tables,
        needs_explicit_preparation() ? MYSQL_OPEN_FORCE_SHARED_MDL : 0)) {
  if (thd->is_error())  // @todo - dictionary code should be fixed
    goto err;
  if (error_handler_active) thd->pop_internal_handler();
  lex->cleanup(false);
  return true;
}
```

> `open_tables_for_query()` 函数为查询或语句打开参数 `tables`（即 `lex->query_tables`）中的所有表；这个函数适用于不需要从表中读取任何数据的准备阶段。如果出现异常则返回 `true`。

##### 第 2 阶段：准备（preparation）

根据 MySQL 配置，设置是否需要使用超图优化器（hypergraph optimizer）：

```C++
lex->set_using_hypergraph_optimizer(
    thd->optimizer_switch_flag(OPTIMIZER_SWITCH_HYPERGRAPH_OPTIMIZER));
```

如果只能使用超图优化器，且没有开启超图优化器，则抛出异常：

```C++
if (thd->lex->validate_use_in_old_optimizer()) {
  return true;
}
```

如果存在变量，则调用 `resolve_var_assignments()` 函数解析变量，如果解析失败则抛出异常。

```C++
if (lex->set_var_list.elements && resolve_var_assignments(thd, lex))
  goto err; /* purecov: inspected */
```

执行准备阶段的主逻辑：

- 调用 `prepare_inner()` 函数，根据是否是 `EXPLAIN` 以及 SQL 模式确定初始化 `result` 数据成员；
- 如果是预编译的语句，且 `result` 不为空，则需要清空 `result` 数据成员；
- 如果不是一个常规语句，则调用 `save_cmd_properties()` 函数保存查询表达式及其底层查询块的预编译语句属性；
- 如果是一个预编译语句，则调用 `set_secondary_engine_execution_context()` 函数；
- 调用 `set_prepared()` 函数，将当前语句标记为已准备。

```C++
  {
    const Prepare_error_tracker tracker(thd);
    const Prepared_stmt_arena_holder ps_arena_holder(thd);
    const Enable_derived_merge_guard derived_merge_guard(
        thd, is_show_cmd_using_system_view(thd));

    if (prepare_inner(thd)) goto err;
    if (needs_explicit_preparation() && result != nullptr) {
      result->cleanup();
    }
    if (!is_regular()) {
      if (save_cmd_properties(thd)) goto err;
    }
    if (needs_explicit_preparation()) {
      lex->set_secondary_engine_execution_context(nullptr);
    }
    set_prepared();
  }
```

> `is_regular()` 函数：如果是一个常规语句，即不是预编译语句也不是存储过程，则返回 true；
>
> `save_cmd_properties()` 函数：保存查询表达式及其底层查询块的预编译语句属性；
>
> `needs_explicit_preparation()` 函数：如果是一个可预编译的语句，即通过 PREPARE 语句准备并通过 EXECUTE 语句执行的查询，则为 true。对于直接执行的常规语句（不可预编译的语句），返回 false。如果语句是存储过程的一部分，也返回 false。

如果刚才添加了内部错误处理器，则丢弃它：

```C++
// Pop ignore / strict error handler
if (error_handler_active) thd->pop_internal_handler();
```
