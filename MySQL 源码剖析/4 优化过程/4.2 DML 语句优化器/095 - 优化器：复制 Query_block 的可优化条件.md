目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

涉及内容：

- 数据成员：[sql/sql_lex.cc](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_lex.cc) > `Query_block::get_optimizable_conditions`
- 静态函数：[sql/sql_lex.cc](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_lex.cc) > `get_optimizable_join_conditions`

在优化器主函数 `JOIN::optimize()` 中，调用了 `Query_block::get_optimizable_conditions` 函数，并将结果写入 `JOIN::where_cond` 和 `JOIN::having_cond` 参数中指向的对象，函数调用逻辑如下：

```C++
// sql/sql_optimizer.cc > optimize(bool)
if (query_block->get_optimizable_conditions(thd, &where_cond, &having_cond))
  return true;
```

`Query_block::get_optimizable_conditions()` 函数用于生成 `WHERE`、`HAVING`、`ON` 条件的一次性副本，并将它们存储到 `Table_ref::m_join_cond_optim` 中。其中，只有 `AND` 或 `OR`  Item 是可以被这样处理的。如果是在常规执行（conventional execution）中，则不会创建副本，而是不会复制并返回永久性的子句（permanent clause）。

`Query_block::get_optimizable_conditions()` 函数的参数如下：

- `thd`（`THD *`）：线程对象（thread handle）
- `new_where`（`Item *`）：复制的 `WHERE` 子句
- `new_having`（`Item *`）：复制的 `HAVING` 子句

`Query_block::get_optimizable_conditions()` 函数的逻辑如下：

**Step 1**｜如果 `WHERE` 子句不为空（`m_where_cond`）且不是常规执行语句（`!thd->stmt_arena->is_regular()`），则调用 `m_where_cond` 的 `copy_andor_structure(thd)` 函数复制 `WHERE` 子句到 `new_where` 指针。

```C++
// sql/sql_lex.cc > Query_block::get_optimizable_conditions(THD *, Item **, Item **)
if (m_where_cond && !thd->stmt_arena->is_regular()) {
  *new_where = m_where_cond->copy_andor_structure(thd);
  if (!*new_where) return true;
} else
  *new_where = m_where_cond;
```

**Step 2**｜如果 `new_having` 指针不为空，且 `HAVING` 子句不为空（`m_having_cond`），且不是常规执行语句（`!thd->stmt_arena->is_regular()`），则调用 `m_having_cond` 的 `copy_andor_structure(thd)` 函数复制 `HAVING` 子句到 `new_having` 指针。

```C++
// sql/sql_lex.cc > Query_block::get_optimizable_conditions(THD *, Item **, Item **)
if (new_having) {
  if (m_having_cond && !thd->stmt_arena->is_regular()) {
    *new_having = m_having_cond->copy_andor_structure(thd);
    if (!*new_having) return true;
  } else
    *new_having = m_having_cond;
}
```

**Step 3**｜调用 `get_optimizable_join_conditions` 以复制 `ON` 条件，并将复制后的 `ON` 条件更新到 `m_table_nest` 中。

```C++
// sql/sql_lex.cc > Query_block::get_optimizable_conditions(THD *, Item **, Item **)
return get_optimizable_join_conditions(thd, m_table_nest);
```

**Step 4**｜在 `get_optimizable_join_conditions` 函数中，递归地遍历 `join_list` 中关联表的关联条件，对于每个关联条件 `table`：先调用 `Table_ref::join_cond()` 方法获取其关联条件（`m_join_cond_ref` 属性）`jc`，如果关联条件不为空且不是常规执行语句（`!thd->stmt_arena->is_regular()`），则调用 `jc` 的 `copy_andor_structure(thd)` 函数复制关联条件，并将复制的关联条件通过调用 `Table_ref::set_join_cond_optim` 函数重新赋值给 `table` 的 `m_join_cond_optim` 属性。

```C++
// sql/sql_lex.cc > get_optimizable_join_conditions(THD *, mem_root_deque<Table_ref*> &)
static bool get_optimizable_join_conditions(
    THD *thd, mem_root_deque<Table_ref *> &join_list) {
  for (Table_ref *table : join_list) {
    NESTED_JOIN *const nested_join = table->nested_join;
    if (nested_join &&
        get_optimizable_join_conditions(thd, nested_join->m_tables))
      return true;
    Item *const jc = table->join_cond();
    if (jc && !thd->stmt_arena->is_regular()) {
      table->set_join_cond_optim(jc->copy_andor_structure(thd));
      if (!table->join_cond_optim()) return true;
    } else
      table->set_join_cond_optim(jc);
  }
  return false;
}
```











