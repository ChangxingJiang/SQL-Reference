目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/optimizer.cc](https://github.com/mysql/mysql-server/blob/trunk/sql/optimizer.cc)

---

MySQL 在 `Query_expression::optimize`、`Query_block::optimize`、`Query_expression::optimize_set_operand` 之间互相调用以解决查询树种 `Query_block`、`Query_expression` 相互嵌套的场景，但是最终，都调用了 `JOIN::optimize` 函数以进行实际的优化，详见 [MySQL 源码｜90 - 优化器：优化器的主要调用结构](https://zhuanlan.zhihu.com/p/899320354)。下面我们来梳理 `JOIN::optimize()` 函数中的执行逻辑。

`JOIN::optimize()` 函数用于将一个 `Query_block` 优化为一个查询计划（query execution plan, QEP）。`JOIN::optimize()` 函数是进入查询优化阶段的入口，在这个阶段中，会引用逻辑（等价）查询重写（logical (equivalent) query rewrites），基于成本的连接优化（cost-based join optimization）以及基于规则的访问路径选择（rule-based access path selection）来实现优化。一旦找到最优执行计划，则成员函数就会创建 / 初始化所有查询执行所需的结构。主要的优化阶段包括：

- [1] 逻辑转换（logical transformations）：
  - [1.1] 将外连接转换为内连接（outer to inner joins transformation）
  - [1.2] 等值 / 常量传播（equality / constant propagation）
  - [1.3] 分区裁剪（partition pruning）
  - [1.4] 在隐式分组（implicit grouping）的情况下对 `COUNT(*)`、`MIN()`、`MAX()` 进行常量转换
  - [1.5] `ORDER BY` 优化
- [2] 基于成本的表顺序（table order）以及访问路径选择优化（access path selection），详见 `JOIN::make_join_plan()` 函数
- [3] 连接后优化（Post-join order optimization）
  - [3.1] 根据 `WHERE` 子句和 `JOIN` 条件选择最优的表条件
  - [3.2] 注入外连接保护条件（Inject outer-join guarding conditions）
  - [3.3] 在确定表条件后调整数据访问方法（djust data access methods）（多次执行）
  - [3.4] 优化 `ORDER BY` 或 `DISTINCT`
- [4] 代码生成
  - [4.1] 设置数据访问函数
  - [4.2] 尝试优化掉 `sorting` 或 `distinct`
  - [4.3] 配置临时表使用，用于分组（grouping）和 / 或排序（sorting）

`JOIN::optimize()` 函数原型如下：

```C++
// 源码位置：sql/sql_optimizer.cc > optimize(bool)
bool JOIN::optimize(bool finalize_access_paths)
```

在 `JOIN::optimize()` 函数中，是否使用超图优化器的逻辑差异很大。因此，我们分开梳理是否使用超图优化器的两种场景。

是否开启超图优化器的标记在 `LEX` 对象中，可以通过 `LEX::using_hypergraph_optimizer()` 函数来获取当前是否开启超图优化器：

```C++
// 源码位置：sql/sql_lex.h > LEX
bool using_hypergraph_optimizer() const {
  return m_using_hypergraph_optimizer;
}
```
