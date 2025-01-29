目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

下面梳理用于解析 `LIMIT` 子句，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析 - 033 - LIMIT 子句](C:\blog\graph\MySQL源码剖析\语法解析 - 033 - LIMIT 子句.png)

#### 语义组：`opt_limit_clause`

`opt_limit_clause` 语义组用于解析可选的 `LIMIT` 子句。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- 标准语法：`[LIMIT {[offset,] row_count | row_count OFFSET offset}]`
- 返回值类型：`PT_limit_clause` 对象（`limit_clause`）
- Bison 语法如下：

```C++
opt_limit_clause:
          %empty { $$= nullptr; }
        | limit_clause
        ;
```

#### 语义组：`limit_clause`

`limit_clause` 语义组用于解析 `LIMIT` 子句。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- 返回值类型：`PT_limit_clause` 对象（`limit_clause`）
- Bison 语法如下：

```C++
limit_clause:
          LIMIT limit_options
          {
            $$= NEW_PTN PT_limit_clause(@$, $2);
          }
        ;
```

#### 语义组：`limit_options`

`limit_options` 语义组用于解析 `LIMIT` 子句中限定行数和偏移量的三种不同形式。

- 官方文档：[MySQL 参考手册 - 15.2.13 SELECT Statement](https://dev.mysql.com/doc/refman/8.0/en/select.html)
- 返回值类型：`Limit_options` 结构体（`limit_options`），其中包括限制行数（`limit`）和偏移量（`opt_offset`）这 2 个属性
- Bison 语法如下：

```C++
limit_options:
          limit_option
          {
            $$.limit= $1;
            $$.opt_offset= nullptr;
            $$.is_offset_first= false;
          }
        | limit_option ',' limit_option
          {
            $$.limit= $3;
            $$.opt_offset= $1;
            $$.is_offset_first= true;
          }
        | limit_option OFFSET_SYM limit_option
          {
            $$.limit= $1;
            $$.opt_offset= $3;
            $$.is_offset_first= false;
          }
        ;
```

#### 语义组：`limit_option`

`limit_option` 语义组用于解析 `LIMIT` 子句中的限制行数值或偏移量值。

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类
- Bison 语法如下：

```C++
limit_option:
          ident
          {
            $$= NEW_PTN PTI_limit_option_ident(@$, to_lex_cstring($1));
          }
        | param_marker
          {
            $$= NEW_PTN PTI_limit_option_param_marker(@$, $1);
          }
        | ULONGLONG_NUM
          {
            $$= NEW_PTN Item_uint(@$, $1.str, $1.length);
          }
        | LONG_NUM
          {
            $$= NEW_PTN Item_uint(@$, $1.str, $1.length);
          }
        | NUM
          {
            $$= NEW_PTN Item_uint(@$, $1.str, $1.length);
          }
        ;
```

> `ident` 语义组用于解析标识符或任意未保留关键字，详见 [MySQL 源码｜41 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)；
>
> `param_marker` 语义组用于解析预编译语句中的占位符，详见 [MySQL 源码｜66 - 语法解析(V2)：预编译表达式的参数值](https://zhuanlan.zhihu.com/p/718323872)。

#### 语义组：`opt_simple_limit`

`opt_simple_limit` 语义组用于解析仅允许设置限制行数，不允许设置偏移量的 `LIMIT` 子句。

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类
- 使用场景：`UPDATE` 语句（`update_stmt`）、`DELETE` 语句（`delete_stmt`）
- Bison 语法如下：

```C++
opt_simple_limit:
          %empty { $$= nullptr; }
        | LIMIT limit_option { $$= $2; }
        ;
```

