目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

---

在基础查询表达式中，使用了 `opt_window_clause` 语义组。下面我们来梳理 WINDOW 子句的逻辑，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析-023-WINDOW 子句](C:\blog\graph\MySQL源码剖析\语法解析-023-WINDOW 子句.png)

#### 语义组：`opt_window_clause`

`opt_window_clause` 语义组用于解析 WINDOW 子句，指定有名称的窗口以便在查询表达式的其他位置复用。

- 官方文档：[MySQL 参考手册 - 14.20.4 Named Windows](https://dev.mysql.com/doc/refman/8.0/en/window-functions-named-windows.html)
- 标准语法：`[WINDOW window_name AS (window_spec) [, window_name AS (window_spec)] ...]`
- 返回值类型：`PT_window_list` 对象（`windows`）
- 使用场景：基础查询表达式（`query_specification`）
- Bison 语法如下：

```C++
opt_window_clause:
          %empty
          {
            $$= nullptr;
          }
        | WINDOW_SYM window_definition_list
          {
            $$= $2;
          }
        ;
```

#### 语义组：`window_definition_list`

`window_definition_list` 语义组用于解析 WINDOW 子句中的任意数量、逗号分隔的窗口表达式的列表。

- 官方文档：[MySQL 参考手册 - 14.20.4 Named Windows](https://dev.mysql.com/doc/refman/8.0/en/window-functions-named-windows.html)
- 标准语法：`window_name AS (window_spec) [, window_name AS (window_spec)] ...`
- 返回值类型：`PT_window_list` 对象（`windows`）
- Bison 语法如下：

```C++
window_definition_list:
          window_definition
          {
            $$= NEW_PTN PT_window_list(@$);
            if ($$ == nullptr || $$->push_back($1))
              MYSQL_YYABORT; // OOM
          }
        | window_definition_list ',' window_definition
          {
            if ($1->push_back($3))
              MYSQL_YYABORT; // OOM
            $$= $1;
            $$->m_pos = @$;
          }
        ;
```

#### 语义组：`window_definition`

`window_definition` 语义组用于解析 WINDOW 子句中的一个窗口表达式。

- 官方文档：[MySQL 参考手册 - 14.20.4 Named Windows](https://dev.mysql.com/doc/refman/8.0/en/window-functions-named-windows.html)
- 标准语法：`window_name AS (window_spec)`
- 返回值类型：`PT_window` 对象（`window`）
- Bison 语法如下：

```C++
window_definition:
          window_name AS window_spec
          {
            $$= $3;
            if ($$ == nullptr)
              MYSQL_YYABORT; // OOM
            $$->m_pos = @$;
            $$->set_name($1);
          }
        ;
```

> `window_name` 语义组用于解析在 `WINDOW` 子句中定义的窗口名称，详见 [MySQL 源码｜38 - 语法解析：窗口函数](https://zhuanlan.zhihu.com/p/714780506)；
>
> `window_spec` 语义组用于解析窗口函数子句的标准语法 `(window_spec)`，详见 [MySQL 源码｜38 - 语法解析：窗口函数](https://zhuanlan.zhihu.com/p/714780506)。