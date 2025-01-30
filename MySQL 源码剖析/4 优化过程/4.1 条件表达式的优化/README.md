目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

Github 仓库地址：[SQL-Reference](https://github.com/ChangxingJiang/SQL-Reference)

---

条件表达式包括：

-  `WHERE` 子句中的过滤条件和 `JOIN` 子句中的关联条件（无论通过 `ON` 子句还是 `HAVING` 函数定义）
-  `HAVING` 子句中的过滤条件

在 MySQL 中，通过 `optimize_cond` 函数来执行条件表达式的优化，优化内容如下：

**优化内容 1**｜构造 <u>多重等式谓词</u>。

分别对 `WHERE` 子句中的过滤条件和 `JOIN` 子句中的关联条件，以及 `HAVING` 子句中的过滤条件进行处理，将嵌套的多层条件表达式中的 <u>谓词</u> 替换为 <u>多重等式谓词</u>，例如将 `a = b AND b = c` 转化为 `=(a, b, c)`。

<u>多重等式谓词</u> 的概念以及转化为 <u>多重等式谓词</u> 的原因详见 [096 - 优化器：多重等式谓词（MEP）](https://zhuanlan.zhihu.com/p/10584216150)，转化方法详见 [097 - 优化器：将单个等式谓词转换为多重等式谓词](https://zhuanlan.zhihu.com/p/11267690125) 和 [098 - 优化器：将多层等式谓词转换为多重等式谓词](https://zhuanlan.zhihu.com/p/20647806424)。

入口函数：`build_equal_items`

**优化内容 2**｜常量传播。

将条件表达式中等于常量的 <u>等式谓词</u> 通过 <u>多重等式谓词</u> 进行传播，将常量推广到其他字段和 <u>谓词</u>。例如，已知 `x = 42 AND x = y`，则通过多重等式谓词 `=(x, y, 42)` 将常量推广到 `y = 42`。

在传播的过程中，对常量的类型进行优化。

入口函数：`propagate_cond_constants`

**优化条件 3**｜推断并移除恒等式。

推断并移除条件表达式中的始终为假或始终为真的 <u>谓词</u>，例如 `a = a` 或 `b != b`。 

入口函数：`remove_eq_conds`

---

- [096 - 优化器：多重等式谓词（MEP）](https://zhuanlan.zhihu.com/p/10584216150)
- [097 - 优化器：将单个等式谓词转换为多重等式谓词](https://zhuanlan.zhihu.com/p/11267690125)
- [098 - 优化器：将多层等式谓词转换为多重等式谓词](https://zhuanlan.zhihu.com/p/20647806424)
- [099 - 优化器：优化 WHERE、HAVING 和 JOIN 子句中的条件表达式](https://zhuanlan.zhihu.com/p/20708387581)

---

[知乎｜100 - 优化器：条件表达式的优化]: https://zhuanlan.zhihu.com/p/20730157613

