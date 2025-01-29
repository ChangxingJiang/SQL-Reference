目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：

- [sql/query_term.h](https://github.com/mysql/mysql-server/blob/trunk/sql/query_term.h)
- [sql/sql_lex.h](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_lex.h)

---

![MySQL源码-Query_term继承关系.drawio](C:\blog\graph\MySQL源码-Query_term继承关系.drawio.png)

#### `Query_term` 类

`Query_term` 类中，主要包含指向父节点的指针和指向结果集的指针。其中的主要数据成员包括：

| 成员名称               | 成员类型                  | 成员用途                          |
| ---------------------- | ------------------------- | --------------------------------- |
| `m_parent`             | `Query_term_set_op*`      | 指向父节点的指针                  |
| `m_setop_query_result` | `Query_result*`           | 指向结果集的指针                  |
| `m_owning_operand`     | `bool`                    | 标记结果集是否在当前节点的指针    |
| `m_result_table`       | `Table_ref*`              | 指向 n 元集合操作临时结果表的指针 |
| `m_fields`             | `mem_root_deque<Item *>*` | 指向流式处理非实体化结果集的指针  |

##### 指向父节点的指针

`Query_term` 包含一个指向其父节点（`Query_term_set_op` 类型）的指针 `m_parent`，如果当前 `Query_term` 为根节点，则该指针为 `nullptr`。

```C++
 protected:
  /**
    Back pointer to the node whose child we are, or nullptr (root term).
  */
  Query_term_set_op *m_parent{nullptr};

 public:
  /// Getter for m_parent, q.v.
  Query_term_set_op *parent() const { return m_parent; }
```

##### 指向结果集的指针

`Query_term` 中还包含一个指向节点查询结果（`Query_result` 类型）的指针 `m_setop_query_result`。

对于 n 元集合操作来说，多个 `Query_item` 的查询结果是共享的；此时，由第一个节点的指针 `m_setop_query_result` 来持有该查询结果，并将布尔类型成员 `m_owning_operand` 置为 `true`；而其他节点的指针 `m_setop_query_result` 为 `nullpt` 为空，`m_owning_operand` 为 `false`。

除了顶层以外，这个指针通常指向 `Query_result_union` 类型。

```C++
 protected:
  /**
    The query result for this term. Shared between n-ary set operands, the first
    one holds it, cf. owning_operand. Except at top level, this is always a
    Query_result_union.
  */
  Query_result *m_setop_query_result{nullptr};
  /**
    The operand of a n-ary set operation (that owns the common query result) has
    this set to true. It is always the first one.
  */
  bool m_owning_operand{false};

 public:
  /// Setter for m_setop_query_result, q.v.
  void set_setop_query_result(Query_result *rs) { m_setop_query_result = rs; }
  /// Getter for m_setop_query_result, q.v.
  Query_result *setop_query_result() { return m_setop_query_result; }
  /// Getter for m_setop_query_result, q.v. Use only if we can down cast.
  Query_result_union *setop_query_result_union() {
    return down_cast<Query_result_union *>(m_setop_query_result);
  }
  /// Cleanup m_setop_query_result, q.v.
  void cleanup_query_result(bool full);

  /// Setter for m_owning_operand, q.v.
  void set_owning_operand() { m_owning_operand = true; }
  /// Getter for m_owning_operand, q.v.
  bool owning_operand() { return m_owning_operand; }
```

##### 指向 n 元集合操作的临时结果表的指针

`Query_term` 中包含一个指向 n 元集合操作的临时结果表（`Table_ref` 类型）的指针 `m_result_table`。

```C++
 protected:
  /**
     Result temporary table for the set operation, if applicable
   */
  Table_ref *m_result_table{nullptr};

 public:
  /// Setter for m_result_table, q.v.
  void set_result_table(Table_ref *tl) { m_result_table = tl; }
  /// Getter for m_result_table, q.v.
  Table_ref &result_table() { return *m_result_table; }
```

##### 指向流式处理非实体化结果集的指针

`Query_term` 中包含一个指向流式处理非实体化结果集（`mem_root_deque<Item *>` 类型）的指针 `m_fields`。

```C++
 protected:
  /**
    Used only when streaming, i.e. not materialized result set
  */
  mem_root_deque<Item *> *m_fields{nullptr};

 public:
  // Setter for m_fields, q.v.
  void set_fields(mem_root_deque<Item *> *fields) { m_fields = fields; }
  // Getter for m_fields, q.v.
  mem_root_deque<Item *> *fields() { return m_fields; }
```

> **流式处理**：指在大量数据时，数据不是一次性加载到内存中，而是分批次或连续地处理。
>
> **实体化的结果集**：将查询结果完全加载到内存中，形成一个可以在内存中直接操作的数据集。

##### 重要纯虚函数

在 `Query_term` 中，还定义了如下 2 个重要的纯虚函数，用于标记当前派生类的类型和名称。

```C++
/**
  Get the node tree type.
  @returns the tree node type
*/
virtual Query_term_type term_type() const = 0;
/**
  Get the node type description.
  @returns descriptive string for each node type.
*/
virtual const char *operator_string() const = 0;
```

其中，`term_type()` 函数返回一个 `Query_term_type` 类型的枚举类，该枚举类中包含元素如下：

```C++
enum Query_term_type {
  QT_QUERY_BLOCK,
  QT_UNARY,
  QT_INTERSECT,
  QT_EXCEPT,
  QT_UNION
};
```

#### `Query_term_set_op` 类

`Query_term_set_op` 类是非叶子节点的基类，其中包含指向对应 `Query_block` 的指针和指向子节点的指针。其中的主要数据成员包括：

##### 指向保存 `ORDER BY` 和 `LIMIT` 信息的 `Query_block` 的指针

每个非叶子节点都有其对应的 `Query_block` 来保存 `ORDER BY` 和 `LIMIT` 信息，该节点的指针存储在 `m_block` 成员中。

```C++
  Query_block *m_block{nullptr};

 public:
  /// Getter for m_block, q.v.
  Query_block *query_block() const override { return m_block; }

  /// Setter for m_block, q.v.
  bool set_block(Query_block *b) {
    assert(!m_block);
    if (b == nullptr) return true;

    m_block = b;
    return false;
  }
```

##### 指向查询树子节点的指针

每个非叶子节点都包含指向其中使用 n 元集合操作合并的多个子节点，子节点的指针存储在 `m_children` 成员中。

```C++
 public:
  /// Tree structure. Cardinality is one for unary, two or more for UNION,
  /// EXCEPT, INTERSECT
  mem_root_deque<Query_term *> m_children;

  size_t child_count() const override { return m_children.size(); }
  void destroy_tree() override {
    m_parent = nullptr;
    for (Query_term *child : m_children) {
      child->destroy_tree();
    }
    m_children.clear();
  }
```

#### 4 个具体 n 元操作类

`Query_term_union`、`Query_term_intersect`、`Query_term_except` 和 `Query_term_unary` 直接继承了 `Query_term_set_op`，仅实现了构造函数和 2 个标记子类信息的纯虚函数。

```C++
/// Node type for n-ary UNION
class Query_term_union : public Query_term_set_op {
 public:
  /**
    Constructor.
    @param mem_root      the mem_root to use for allocation
   */
  Query_term_union(MEM_ROOT *mem_root) : Query_term_set_op(mem_root) {}
  Query_term_type term_type() const override { return QT_UNION; }
  const char *operator_string() const override { return "union"; }
  void debugPrint(int level, std::ostringstream &buf) const override;
};

/// Node type for n-ary INTERSECT
class Query_term_intersect : public Query_term_set_op {
 public:
  /**
    Constructor.
    @param mem_root      the mem_root to use for allocation
  */
  Query_term_intersect(MEM_ROOT *mem_root) : Query_term_set_op(mem_root) {}
  Query_term_type term_type() const override { return QT_INTERSECT; }
  const char *operator_string() const override { return "intersect"; }
  void debugPrint(int level, std::ostringstream &buf) const override;
};

/// Node type for n-ary EXCEPT
class Query_term_except : public Query_term_set_op {
 public:
  /**
    Constructor.
    @param mem_root      the mem_root to use for allocation
  */
  Query_term_except(MEM_ROOT *mem_root) : Query_term_set_op(mem_root) {}
  Query_term_type term_type() const override { return QT_EXCEPT; }
  const char *operator_string() const override { return "except"; }
  void debugPrint(int level, std::ostringstream &buf) const override;
};

class Query_term_unary : public Query_term_set_op {
 public:
  /**
    Constructor.
    @param mem_root      the mem_root to use for allocation
    @param t             the child term
   */
  Query_term_unary(MEM_ROOT *mem_root, Query_term *t)
      : Query_term_set_op(mem_root) {
    m_last_distinct = 0;
    m_children.push_back(t);
  }
  Query_term_type term_type() const override { return QT_UNARY; }
  const char *operator_string() const override { return "result"; }
  void debugPrint(int level, std::ostringstream &buf) const override;
};
```

#### `Query_block` 类

`Query_block` 是查询树叶子节点类型，其中也实现了构造函数和 2 个标记子类信息纯虚函数。此外，其 `query_block()` 方法指向自身。

```C++
class Query_block : public Query_term {
 public:
  /**
    @note the group_by and order_by lists below will probably be added to the
          constructor when the parser is converted into a true bottom-up design.

          //SQL_I_LIST<ORDER> *group_by, SQL_I_LIST<ORDER> order_by
  */
  Query_block(MEM_ROOT *mem_root, Item *where, Item *having);
  Query_term_type term_type() const override { return QT_QUERY_BLOCK; }
  const char *operator_string() const override { return "query_block"; }
  Query_block *query_block() const override {
    return const_cast<Query_block *>(this);
  }
```



