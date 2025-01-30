目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

在 MySQL 中，`optimize_cond` 函数用于优化 `WHERE` 子句、`HAVING` 子句中的过滤条件，或 `JOIN` 子句中的关联条件。该函数的原型如下：

```C++
// sql/sql_optimizer.cc
bool optimize_cond(THD *thd, Item **cond, COND_EQUAL **cond_equal,
                   mem_root_deque<Table_ref *> *join_list,
                   Item::cond_result *cond_value)
```

在该函数中，递归地分析条件 <u>谓词</u> `cond` 以及关联条件 `join_list`，将转化的 <u>多重等式谓词</u> 合并到 `cond_equal` 中。如果 <u>谓词</u> `cond` 恒为真则将 `cond_value` 置为 `COND_TRUE`，恒为假则置为 `COND_FALSE`，否则置为 `COND_OK`。其中将 <u>等式谓词</u> 合并为 <u>多重等式谓词</u> 的主要目标如下：

- 构造多重等式谓词：将嵌套的多层 <u>等式谓词</u> 转化为 <u>多重等式谓词</u>，<u>多重等式谓词</u> 的概念以及转化为 <u>多重等式谓词</u> 的原因详见 [096 - 优化器：多重等式谓词（MEP）](https://zhuanlan.zhihu.com/p/10584216150)；
- 常量传播：在转化的过程中，尽可能推广常量，例如已知 `x = 42 AND x = y`，则通过多重等式谓词 `=(x, y, 42)` 将常量推广到 `y = 42`；
- 移除恒等式：移除始终为假或始终为真的条件。

当优化 `WHERE` 子句和 `JOIN` 子句中的关联条件，即存在 `WHERE` 子句或存在 `JOIN` 子句时，将 `WHERE` 子句 `where_cond` 作为 `cond`，将 `JOIN` 子句的关联条件 `query_block->m_table_nest` 作为 `join_list` 调用：

```C++
// sql/sql_optimizer.cc（简化）
if (where_cond || query_block->outer_join) {
  optimize_cond(thd, &where_cond, &cond_equal, &query_block->m_table_nest,
                &query_block->cond_value);
}
```

当优化 `HAVING` 子句时，将 `HAVING` 子句 `having_cond` 作为 `cond` 并将 `join_list` 置为 `nullptr` 调用：

```C++
// sql/sql_optimizer.cc（简化）
if (having_cond) {
  optimize_cond(thd, &having_cond, &cond_equal, nullptr,
                &query_block->having_value));
}
```

#### 构造多重等式谓词

`optimize_cond` 函数在优化 `WHERE` 子句和 `JOIN` 子句中的关联条件时，调用 `build_equal_items` 函数尝试将 `WHERE` 子句和 `JOIN` 子句关联条件中的 <u>等式谓词</u> 转化为 <u>多重等式谓词</u>（MEP），并在转化过程中，将常量添加到 <u>多重等式谓词</u> 中。在优化 `HAVING` 子句时不执行这个逻辑。

```C++
// sql/sql_optimizer.cc（简化）
if (join_list) {
  build_equal_items(thd, *cond, cond, nullptr, true, join_list, cond_equal);
}
```

在 `build_equal_items` 函数中，主要逻辑如下：

- 如果 `WHERE` 子句不为空，则调用 `build_equal_items_for_cond` 函数将子句中的条件表达式中的 <u>等式谓词</u> 转化为 <u>多重等式谓词</u>，其中的逻辑详见 [098 - 优化器：将多层等式谓词转换为多重等式谓词](https://zhuanlan.zhihu.com/p/20647806424)，并将生成的 <u>多重等式谓词</u> 的列表存入 `cond_equal` 变量中；
- 如果从 `WHERE` 子句中生成了 <u>多重等式谓词</u>，则需要再处理 `JOIN` 子句中的关联条件时继承它；
- 如果 `JOIN` 子句存在，则递归地调用自身，尝试将 `JOIN` 子句中的 <u>等式谓词</u> 转化为 <u>多重等式谓词</u>。

```C++
// sql/sql_optimizer.cc（简化）
bool build_equal_items(THD *thd, Item *cond, Item **retcond,
                       COND_EQUAL *inherited, bool do_inherit,
                       mem_root_deque<Table_ref *> *join_list,
                       COND_EQUAL **cond_equal_ref) {
  COND_EQUAL *cond_equal = nullptr;
  if (cond) {
    build_equal_items_for_cond(thd, cond, &cond, inherited, do_inherit);
    cond_equal = cond->cond_equal;  // 简化示意
  }
  if (cond_equal) {
    cond_equal->upper_levels = inherited;
    inherited = cond_equal;
  }
  *cond_equal_ref = cond_equal;
  if (join_list) {
    for (Table_ref *table : *join_list) {
      if (table->join_cond_optim()) {
        mem_root_deque<Table_ref *> *nested_join_list =
            table->nested_join ? &table->nested_join->m_tables : nullptr;
        Item *join_cond;
        build_equal_items(thd, table->join_cond_optim(), &join_cond,
                              inherited, do_inherit, nested_join_list,
                              &table->cond_equal);
      }
    }
  }
  *retcond = cond;
  return false;
}
```

#### 常量传播

`optimize_cond` 函数调用 `propagate_cond_constants` 函数，将可以使用常量替换的 <u>等式谓词</u> 替换为常量。例如已知 `a = 3 AND a = b`，则将 `a = b` 替换为 `b = 3`。

```C++
// sql/sql_optimizer.cc（简化）
if (*cond) {
  if (propagate_cond_constants(thd, nullptr, *cond, *cond)) return true;
}
```

在 `propagate_cond_constants` 函数中，通过递归实现查询表达式中的常量传播。

- 对于 `AND` 关键字或 `OR` 关键字连接的表达式，通过调用自身递归地处理被连接的每个表达式，并将结果存储到 `save` 中

```C++
// sql/sql_optimizer.cc（简化）
while ((item = li++)) {
  propagate_cond_constants(thd, &save, and_level ? cond : item, item);
}
```

- 如果是 `AND` 关键字连接的每个单独的表达式，还需要额外替换生成结果中的常量

```C++
// sql/sql_optimizer.cc
if (and_level) {
  I_List_iterator<COND_CMP> cond_itr(save);
  COND_CMP *cond_cmp;
  while ((cond_cmp = cond_itr++)) {
    Item **args = cond_cmp->cmp_func->arguments();
    if (!args[0]->const_item() &&
        change_cond_ref_to_const(thd, &save, cond_cmp->and_level,
                                 cond_cmp->and_level, args[0], args[1]))
      return true;
  }
}
```

- 对于单独的表达式，如果是等式，且只有等式一边的值为常量，且等式两边的类型相同，则调用 `resolve_const_item` 函数将其中的常量转化为最简单的常量类型，然后将调用 `change_cond_ref_to_const` 函数将不是常量的替换为常量

```C++
// sql/sql_optimizer.cc（简化）
if (cond->type() == Item::FUNC_ITEM &&
    (func->functype() == Item_func::EQ_FUNC ||
     func->functype() == Item_func::EQUAL_FUNC)) {
  Item **args = func->arguments();
  const bool left_const = args[0]->const_item();
  const bool right_const = args[1]->const_item();
  if (!(left_const && right_const) &&
      args[0]->result_type() == args[1]->result_type()) {
    if (right_const) {
      Item *item = args[1];
      resolve_const_item(thd, &item, args[0])
      change_cond_ref_to_const(thd, save_list, and_father, and_father, args[0], args[1]);
    } else if (left_const) {
      Item *item = args[0];
      resolve_const_item(thd, &item, args[1])
      change_cond_ref_to_const(thd, save_list, and_father, and_father, args[1], args[0]);
    }
  }
}
```

#### 移除恒等式

`optimize_cond` 函数调用 `remove_eq_conds` 函数，移除条件表达式 `cond` 中恒为真或恒为假的条件，将剔除后的结果通过第 3 个参数返回，并将 `cond` 的值推断结果通过 `cond_value` 返回，如果恒为真则将 `cond_value` 置为 `COND_TRUE`，恒为假则置为 `COND_FALSE`，否则置为 `COND_OK`。

```C++
// sql/sql_optimizer.cc（简化）
if (*cond) {
  if (remove_eq_conds(thd, *cond, cond, cond_value)) return true;
}
```
