目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/query_term.h](https://github.com/mysql/mysql-server/blob/trunk/sql/query_term.h)

---

`Query_term` 类是查询树结构中的节点，通过 `Query_term` 节点间的嵌套关系，构成了查询树结构。

#### `Query_block`、`Query_expression` 与 `Query_term`

`Query_block` 类继承自 `Query_term` 类。

当 `Query_block` 作为叶子节点时，它既是查询规则（query specification），也是查询的表构造器（table constructors of the query）。此时，它自己处理 `ORDER BY` 和 `LIMIT`，因此它的 `query_block()` 方法返回一个指向它自身的指针。

当 `Query_block` 作为非叶子节点时，它是一种实现 `ORDER BY` 和 `LIMIT` 的方式，每个非叶子节点都有其对应的 `Query_block` 来保存 `ORDER BY` 和 `LIMIT` 信息，这个 `Query_block` 可以通过 `Query_term::query_block()` 方法访问。

```C++
class Query_term_set_op : public Query_term {
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

作为叶子节点的 `Query_block` 之间，会通过 `next` 指针相互连接形成单向链表，作为 `Query_expression` 类的 `slave` 中的子节点的链表。

#### 查询树嵌套关系

查看如下官方样例：

```sql
(
    (SELECT * FROM t1 
     UNION 
     SELECT * FROM t2 
     UNION ALL 
     SELECT * FROM t3
     ORDER BY a 
     LIMIT 5
    )
    INTERSECT
    (
        (
            (SELECT * FROM t3 
             ORDER BY a 
             LIMIT 4)
        ) 
        EXCEPT 
        SELECT * FROM t4
    )
    ORDER BY a 
    LIMIT 4
) 
ORDER BY -a 
LIMIT 3;
```

解析后得到如下结构：

![MySQL源码-Query_term类.drawio](C:\blog\graph\MySQL源码-Query_term类.drawio.png)

- `Query_expression` 的 `m_query_term` 成员指向查询树的根节点
- `Query_block` 和 `Query_term` 节点间使用 `m_children` 成员实现嵌套

#### `Query_term` 的继承关系

`Query_term` 查询树节点有五种节点类型：

- `QT_QUERY_BLOCK`：叶子节点
- `QT_UNARY`：一元节点，例如为其他节点添加了 `ORDER BY` 或 `LIMIT` 语法
- `QT_INTERSECT`：n 元集合操作节点，交集节点
- `QT_UNION`：n 元集合操作节点，并集节点
- `QT_EXCEPT`：n 元集合操作节点，差集节点

```C++
enum Query_term_type {
  QT_QUERY_BLOCK,
  QT_UNARY,
  QT_INTERSECT,
  QT_EXCEPT,
  QT_UNION
};
```

其中，`Query_term_unary`、`Query_term_union`、`Query_term_intersect`、`Query_term_except` 均为基类 `Query_term_set_op` 的子类，而 `Query_term_set_op` 类继承自 `Query_term`。这 4 个类都包含一个 `m_children` 成员，同时也包含一个指向 `Query_block` 的指针，用于处理其 `order_by` 和 `limit` 子句。这些类并不通过 `next` 指针连接成链表。