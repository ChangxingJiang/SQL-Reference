目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

下面我们梳理 `FROM` 子句和 `JOIN` 子句，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析 - 028 - FROM 子句](C:\blog\graph\MySQL源码剖析\语法解析 - 028 - FROM 子句.png)

#### 语义组：`opt_from_clause`

`opt_from_clause` 语义组用于解析可选的 `FROM` 子句，其中包含 `JOIN` 子句。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- 标准语法：`[FROM table_references [PARTITION partition_list]]`
- 返回值类型：`Mem_root_array_YY<PT_table_reference *>`（`table_reference_list`）
- 使用场景：查询语句（`query_specification` 语义组）
- Bison 语法如下：

```C++
opt_from_clause:
          %empty %prec EMPTY_FROM_CLAUSE { $$.init(YYMEM_ROOT); }
        | from_clause
        ;
```

#### 语义组：`from_clause`

`from_clause` 语义组用于解析 `FROM` 子句，其中包含 `JOIN` 子句。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- 返回值类型：`Mem_root_array_YY<PT_table_reference *>`（`table_reference_list`）
- Bison 语法如下：

```C++
from_clause:
          FROM from_tables { $$= $2; }
        ;
```

#### 语义组：`from_tables`

`from_tables` 语义组用于解析 `DUAL` 关键字表示的虚拟表或其他各种类型的表引用、派生表等。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- 返回值类型：`Mem_root_array_YY<PT_table_reference *>`（`table_reference_list`）
- Bison 语法如下：

```C++
from_tables:
          DUAL_SYM { $$.init(YYMEM_ROOT); }
        | table_reference_list
        ;
```

> `table_reference_list` 语义组用于解析任意数量、逗号分隔的各种类型的表，详见 [MySQL 源码｜76 - 语法解析(V2)：表语句（table_reference）](https://zhuanlan.zhihu.com/p/720247259)。
