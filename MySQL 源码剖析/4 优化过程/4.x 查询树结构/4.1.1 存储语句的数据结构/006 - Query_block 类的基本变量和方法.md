目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：

- [sql/sql_lex.h](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_lex.h)
- [sql/sql_lex.cc](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_lex.cc)

---

在 `Query_block` 类中，除实现了父类的纯虚函数以及与 `Query_term` 和 `Query_expression` 之间的指针外，还实现了如下功能：

- `m_base_options` 选项和 `m_active_options` 选项：存储包括 `DISTINCT` 在内的各种选项信息
- `FROM` 子句中查询的表的链表
- 指向子查询的指针
- 包括 `WHERE` 子句、`HAVING` 子句及窗口函数的条件子句在内的条件子句信息
- `GROUP BY` 子句信息
- `ORDER BY` 子句信息
- `LIMIT` 子句信息

#### 构造方法

```C++
Query_block::Query_block(MEM_ROOT *mem_root, Item *where, Item *having)
    : fields(mem_root),
      ftfunc_list(&ftfunc_list_alloc),
      sj_nests(mem_root),
      first_context(&context),
      m_table_nest(mem_root),
      m_current_table_nest(&m_table_nest),
      m_where_cond(where),
      m_having_cond(having) {}
```

#### 继承关系

`Query_block` 继承自 `Query_term`，时查询树中代表叶子节点的特殊类型。`Query_term` 和 `Query_block` 之间的关系详见 [MySQL 源码｜查询树与 Query_term 节点](https://dataartist.blog.csdn.net/article/details/139429470)。

```C++
class Query_block : public Query_term
```

实现了父类如下纯虚函数：

```C++
  Query_block(MEM_ROOT *mem_root, Item *where, Item *having);
  Query_term_type term_type() const override { return QT_QUERY_BLOCK; }
  const char *operator_string() const override { return "query_block"; }
  Query_block *query_block() const override {
    return const_cast<Query_block *>(this);
  }
```

#### 与 `Query_term` 和 `Query_expression` 之间的指针

`Query_block` 类中包含用于与 `Query_expression` 及其他 `Query_block` 连接的指针。逻辑详见 [MySQL 源码｜Query_block 和 Query_expression 的连接关系](https://dataartist.blog.csdn.net/article/details/139401884)。

```C++
 public:
  Query_block *next{nullptr};
  Query_block *next_query_block() const { return next; }

  Query_expression *master{nullptr};
  Query_expression *master_query_expression() const { return master; }
  Query_expression *slave{nullptr};
  Query_expression *first_inner_query_expression() const { return slave; }

  Query_block *link_next{nullptr};
  Query_block *next_select_in_list() const { return link_next; }
  Query_block **link_prev{nullptr};

  /// @return the query block this query expression belongs to as subquery
  Query_block *outer_query_block() const { return master; }

  /// @return the first query block inside this query expression
  Query_block *first_query_block() const { return slave; }

  /// @return the next query expression within same query block (next subquery)
  Query_expression *next_query_expression() const { return next; }
```

#### `m_base_options` 选项和 `m_active_options` 选项

- `m_base_options`：基础选项。在解析过程中配置的选项，在解析完成后不再进行修改。
- `m_active_options`：可变选项。来自基础选项（在解析过程中添加）及会话变量 `option_bits` 的值；因为 `option_bits` 会发生变化，所以每次执行语句时都会刷新。

```C++
  ulonglong m_base_options{0};
  ulonglong m_active_options{0};
```

其类型 `ulonglong` 是 `unsigned long long int` 的类型别名，详见 [MySQL 源码｜附录 1：类型别名](https://dataartist.blog.csdn.net/article/details/139574694)。

定义了设置、添加、移除 `m_base_options` 选项的函数，在修改时会同步更新 `m_active_options`。这 3 个函数的主要逻辑如下：

```C++
  void set_base_options(ulonglong options_arg) {
    m_base_options = options_arg;
    m_active_options = options_arg;
  }

  void add_base_options(ulonglong options) {
    m_base_options |= options;
    m_active_options |= options;
  }

  void remove_base_options(ulonglong options) {
    m_base_options &= ~options;
    m_active_options &= ~options;
  }
```

定义了根据 `m_base_options` 选项生成 `m_active_options` 的函数：

```C++
void Query_block::make_active_options(ulonglong added_options,
                                      ulonglong removed_options) {
  m_active_options =
      (m_base_options | added_options | parent_lex->statement_options() |
       parent_lex->thd->variables.option_bits) &
      ~removed_options;
}
```

定义了设置、读取 `m_active_options` 的函数：

```C++
  /// Adjust the active option set
  void add_active_options(ulonglong options) { m_active_options |= options; }

  /// @return the active query options
  ulonglong active_options() const { return m_active_options; }
```

`DISTINCT` 关键字的信息就存储在 `active_options` 选项中，该选项为一个状态压缩后的二进制数，在判断是否包含某个元素时直接使用按位与即可：

```C++
 public:
  bool is_distinct() const { return active_options() & SELECT_DISTINCT; }
```

#### `FROM` 子句的元素

`FROM` 子句中查询的表列表存储在 `m_table_list` 之中，可以使用  `Table_ref::next_local` 方法来遍历它：

```C++
 public:
  bool has_tables() const { return m_table_list.elements != 0; }
  Table_ref *get_table_list() const { return m_table_list.first; }

  SQL_I_List<Table_ref> m_table_list{};
```

#### 子查询信息

直接指向子查询的指针：

```C++
  /// Points to subquery if this query expression is used in one, otherwise NULL
  Item_subselect *item;
```

#### 条件子句的元素（`WHERE`、`HAVING` 及窗口函数的条件）

存储 `WHERE` 子句的数据成员及相关函数：

```C++
 public:
  Item *where_cond() const { return m_where_cond; }
  Item **where_cond_ref() { return &m_where_cond; }
  void set_where_cond(Item *cond) { m_where_cond = cond; }

 private:
  Item *m_where_cond;
```

存储 `HAVING` 子句的数据成员及相关函数：

```C++
 public:
  Item *having_cond() const { return m_having_cond; }
  Item **having_cond_ref() { return &m_having_cond; }
  void set_having_cond(Item *cond) { m_having_cond = cond; }

 private:
  Item *m_having_cond;
```

存储窗口函数中的条件子句的数据成员及相关函数：

```C++
 public:
  Item *qualify_cond() const { return m_qualify_cond; }
  Item **qualify_cond_ref() { return &m_qualify_cond; }
  void set_qualify_cond(Item *cond) { m_qualify_cond = cond; }

 private:
  Item *m_qualify_cond{nullptr};
```

#### `GROUP BY` 子句信息

`GROUP BY` 子句中的条件存储在 `group_list` 数据成员之中：

```C++
 public:
  bool is_explicitly_grouped() const { return group_list.elements != 0; }

  bool is_implicitly_grouped() const {
    return m_agg_func_used && group_list.elements == 0;
  }
  
  bool is_grouped() const { return group_list.elements > 0 || m_agg_func_used; }

  ORDER *find_in_group_list(Item *item, int *rollup_level) const;
  int group_list_size() const;

  SQL_I_List<ORDER> group_list{};
  Group_list_ptrs *group_list_ptrs{nullptr};
```

#### `ORDER BY` 子句信息

`ORDER BY` 子句中的排序逻辑存储在 `order_list` 数据成员中：

```C++
 public:
  bool is_ordered() const { return order_list.elements > 0; }

  inline void init_order() {
    assert(order_list.elements == 0);
    order_list.elements = 0;
    order_list.first = nullptr;
    order_list.next = &order_list.first;
  }

  SQL_I_List<ORDER> order_list{};
  Group_list_ptrs *order_list_ptrs{nullptr};
```

#### `LIMIT` 子句信息

`ORDER BY` 子句中的信息存储在如下数据成员中：

```C++
 public:
  /// @return true if this query block has a LIMIT clause
  bool has_limit() const { return select_limit != nullptr; }

  /// LIMIT clause, NULL if no limit is given
  Item *select_limit{nullptr};

  /**
    If true, use select_limit to limit number of rows selected.
    Applicable when no explicit limit is supplied, and only for the
    outermost query block of a SELECT statement.
  */
  bool m_use_select_limit{false};
```

#### `WITH` 子句信息

`WITH` 子句的指针存储在如下数据成员中：

```C++
 public:
  /**
    The WITH clause which is the first part of this query expression. NULL if
    none.
  */
  PT_with_clause *m_with_clause;
```

#### 查询结果

此外，在 `Query_block` 类中，还存储了一些查询过程中及查询结果的信息，包括：

```C++
  void set_query_result(Query_result *result) { m_query_result = result; }
  Query_result *query_result() const { return m_query_result; }
  bool change_query_result(THD *thd, Query_result_interceptor *new_result,
                           Query_result_interceptor *old_result);

  /// @return the query result object in use for this query expression
  Query_result *query_result() const { return m_query_result; }
```













