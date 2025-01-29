目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_lex.h](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_lex.h)

---

`Query_block` 类表示查询块（query block），其中包含必选的 **一个** 关键字 `SELECT` 和表列表，以及可选的 `WHERE` 子句、`GROUP BY` 子句等。

`Query_expression` 类表示查询表达式（query expression），其中包含由多个 `UNION`、`INTERSECT`、`EXCEPT` 等集合操作合并的一个或多个查询块。

#### 连接方式

##### 同级节点使用链表连接

在 `Query_block` 中包含的 `Query_expression`，以及 `Query_expression` 中包含的 `Query_block` 均使用嵌入式链表（intrusive double-linked list）的形式的存储。

- `Query_block` 中的 `Query_expression` 链表为双端链表。在 `Query_expression` 中，包含指向后一个节点的指针 `next` 和指向前一个节点的指针 `prev`，这两个指针均指向 `Query_expression` 类对象。
- `Query_expression` 中的 `Query_block` 链表为单向链表。在 `Query_block` 中，包含指向后一个节点的指针 `next`。
- 全局的 `Query_block` 也构成一个双端链表。在 `Query_block` 中，包含指向全局下一个节点的指针 `link_next` 和指向全局前一个节点的 `link_prev`。这与将 B+ 树的叶子节点构成双端链表的结构是类似的。

##### 上下级节点直接使用树连接

`Query_expression` 类的上下级均为 `Query_block` 类，`Query_block` 类的上下级节点均为 `Query_expression` 类。具体地，`Query_expression` 和 `Query_block` 类中包含指向上级节点的指针 `master` 和指向下级节点链表的第 1 个元素的 `slave` 指针。其中，对于最上层的 `Query_expression`，其 `master` 指针为 `NULL`。

```c++
class Query_expression {
  Query_expression *next;
  Query_expression **prev;

  Query_block *master;
  Query_block *slave;
```

```c++
class Query_block : public Query_term {
  Query_block *next{nullptr};

  Query_expression *master{nullptr};
  Query_expression *slave{nullptr};

  Query_block *link_next{nullptr};
  Query_block **link_prev{nullptr};
```

##### 能够发生连接的场景

1. `Query_expression` 中包含 `Query_block` 子元素：正常语句即会包含。
2. `Query_block` 中包含 `Query_expression` 子元素：存在子查询。
3. 存在并列的 `Query_block`：使用 `UNION`、`INTERSECT`、`EXCEPT` 等集合操作合并了多个查询块。
4. 存在并列的 `Query_expression`：存在多个子查询。

#### 样例说明

查看如下官方样例：

```sql
select *
 from table1
 where table1.field IN (select * from table1_1_1 union
                        select * from table1_1_2)
 union
select *
 from table2
 where table2.field=(select (select f1 from table2_1_1_1_1
                               where table2_1_1_1_1.f2=table2_1_1.f3)
                       from table2_1_1
                       where table2_1_1.f1=table2.f2)
 union
select * from table3;
```

解析后会得到：

![MySQL源码-Query_term类.drawio](C:\blog\graph\MySQL源码-Query_term类.drawio.png)

> **提示**：这里的源码注释有点问题，其中有 Select 1.2.1 节点但 SQL 语句中没有。