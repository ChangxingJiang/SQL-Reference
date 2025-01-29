目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：

- [sql/sql_lex.h](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_lex.h)
- [sql/sql_lex.cc](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_lex.cc)

---

`Query_expression` 类表示查询表达式（query expression），其中包含由多个 `UNION`、`INTERSECT`、`EXCEPT` 等集合操作合并的一个或多个查询块。

#### 连接关系

`Query_expression` 类的上下级均为 `Query_block` 类，`Query_block` 类的上下级节点均为 `Query_expression` 类。在 `Query_expression` 中，包含指向上级节点的指针 `master` 和指向下级节点链表的第 1 个元素的 `slave` 指针。其中，对于最上层的 `Query_expression`，其 `master` 指针为 `NULL`。

```C++
class Query_expression {
  /**
    The query block wherein this query expression is contained,
    NULL if the query block is the outer-most one.
  */
  Query_block *master;
  /// The first query block in this query expression.
  Query_block *slave;

  /// @return the query block this query expression belongs to as subquery
  Query_block *outer_query_block() const { return master; }

  /// @return the first query block inside this query expression
  Query_block *first_query_block() const { return slave; }
  
  ......
}
```

`Query_expression` 类的同一层均为 `Query_expression` 类，使用嵌入式双端队列存储的结构。在 `Query_expression` 中，包含指向双端队列下一个节点的指针 `next` 和指向前一个节点的指针 `prev`。

```c++
class Query_expression {
  ......
  
  /**
    Intrusive double-linked list of all query expressions
    immediately contained within the same query block.
  */
  Query_expression *next;
  Query_expression **prev;

  /// @return the next query expression within same query block (next subquery)
  Query_expression *next_query_expression() const { return next; }
  
  ......
}
```

以上连接关系的逻辑详见 [MySQL 源码｜Query_block 和 Query_expression 的连接关系](https://dataartist.blog.csdn.net/article/details/139401884)。

#### 查询树结构关系

`Query_expression` 类作为查询树的根节点，其指针 `m_query_term` 指向查询树中下一层的 `Query_term` 节点。查询树的结构关系详见 [MySQL 源码｜查询树与 Query_term 节点](https://dataartist.blog.csdn.net/article/details/139429470)。

```C++
class Query_expression {
  ......
  
  Query_term *m_query_term{nullptr};
  /// Getter for m_query_term, q.v.
  Query_term *query_term() const { return m_query_term; }
  /// Setter for m_query_term, q.v.
  void set_query_term(Query_term *qt) { m_query_term = qt; }
  
  ......
}
```

#### 解析、执行过程

在 `Query_expression` 类中，还包含一系列标记解析、执行过程的数据成员。其中包括的主要数据成员包括：

-  `enum_parsing_context` 类型的`explain_marker`：用于存储解析状态
- 布尔值 `prepared`：标记 `Query_expression` 中的 `Query_block` 是否均已准备完成
- 布尔值 `optimized`：标记 `Query_expression` 中的 `Query_block` 是否均已优化完成
- 布尔值 `excuted`：标记 `Query_expression` 是否已经执行完成
- `Query_result` 类型的 `m_query_result`：用于存储当前 `Query_expression` 的结果

```C++
class Query_expression {
  ......
  
  enum_parsing_context explain_marker;
    
  bool prepared;   ///< All query blocks in query expression are prepared
  bool optimized;  ///< All query blocks in query expression are optimized
  bool executed;   ///< Query expression has been executed
    
  Query_result *m_query_result;
  
  ......
}
```

此外，还有一些执行时用到的参数，包括执行时 LIMIT 子句用到的计数器、指向子查询的指针、指向 WITH 语句的指针等。

#### 重要方法

##### `prepare()`：准备查询表达式

准备 `Query_expression` 中的所有 `Query_block`，包括 `fake_query_block`。对于递归查询表达式，会创建一个事实临时表。其中包括如下参数：

- `thd`：线程处理器
- `sel_result`：用于接收单元输出的结果对象
- `insert_field_list`：如果是 `INSERT`，则是指向字段列表的指针，否则为 `null`
- `added_options`：将被添加到 `Query_block` 中的选项
- `removed_options`：当前查询不支持的选项

这个方法的逻辑在 `sql/sql_union.cc` 文件中。

##### `optimize()`：创建迭代器

##### `finalize()`：完成 `Query_block` 逻辑

将所有未完成的 `Query_block` 完成，从而允许创建迭代器。

##### `execute()`：执行方法

##### `destroy()`：清理方法
