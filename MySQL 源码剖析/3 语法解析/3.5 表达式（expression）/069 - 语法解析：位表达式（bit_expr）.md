目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

前置文档：

- [MySQL 源码｜50 - 语法解析(V2)：简单表达式（simple_expr）](https://zhuanlan.zhihu.com/p/715703857)

---

在梳理了简单表达式 `simple_expr` 语义组后，我们继续梳理比 `simple_expr` 高级一层的 `bit_expr` 语义组，其中涉及的 symbol 及 symbol 之间的关系如下（图中绿色节点为字符串字面值涉及节点、蓝色节点为其他语义组、灰色节点为其他终结符）：

![语法解析-017-位表达式（bit_expr）](C:\blog\graph\MySQL源码剖析\语法解析-017-位表达式（bit_expr）.png)

#### 语义组：`bit_expr`

`bit_expr` 语义组用于解析 “位表达式”，即在简单表达式（`simple_expr`）的基础上使用各种数值类二元运算符进行计算的表达式。其备选规则包含两类，分别是 `simple_expr` 语义组解析结果，已经 `bit_expr` 语义组与其他语义组（或其本身）进行二元计算的结果。

- 官方文档：[MySQL 参考手册 - 11.5 Expressions](https://dev.mysql.com/doc/refman/8.4/en/expressions.html)；[MySQL 参考手册 - 14.4 Operators](https://dev.mysql.com/doc/refman/8.4/en/non-typed-operators.html)
- 标准语法：

```
bit_expr:
    bit_expr | bit_expr
  | bit_expr & bit_expr
  | bit_expr << bit_expr
  | bit_expr >> bit_expr
  | bit_expr + bit_expr
  | bit_expr - bit_expr
  | bit_expr * bit_expr
  | bit_expr / bit_expr
  | bit_expr DIV bit_expr
  | bit_expr MOD bit_expr
  | bit_expr % bit_expr
  | bit_expr ^ bit_expr
  | bit_expr + interval_expr
  | bit_expr - interval_expr
  | simple_expr
```

- 返回值类型：`Item` 类（`item`），用于表示查询任何类型表达式的基类。
- 使用场景：解析入口 `start_entry` 语义组；上一级表达式（`predicate` 语义组）等
- 备选规则和 Bison 语法：

| 备选规则                                  | 规则含义                                                     |
| ----------------------------------------- | ------------------------------------------------------------ |
| `bit_expr '|' bit_expr`                   | 按位或运算（Bitwise OR）                                     |
| `bit_expr '&' bit_expr`                   | 按位与运算（Bitwise AND）                                    |
| `bit_expr SHIFT_LEFT bit_expr`            | 左移位运算（Left shift），其中 `SHIFT_LEFT` 终结符解析 `<<` 符号 |
| `bit_expr SHIFT_RIGHT bit_expr`           | 右移位运算（Right shift），其中 `SHIFT_RIGHT` 终结符解析 `>>` 符号 |
| `bit_expr '+' bit_expr`                   | 加法运算（Addition operator）                                |
| `bit_expr '-' bit_expr`                   | 减法运算（Minus operator）                                   |
| `bit_expr '+' INTERVAL_SYM expr interval` | 加法运算（Addition operator），与时间间隔字面值求和          |
| `bit_expr '-' INTERVAL_SYM expr interval` | 减法运算（Minus operator），与时间间隔字面值求差             |
| `bit_expr '*' bit_expr`                   | 乘法运算（Multiplication operator）                          |
| `bit_expr '/' bit_expr`                   | 除法运算（Division operator）                                |
| `bit_expr '%' bit_expr`                   | 取模运算（Modulo operator）                                  |
| `bit_expr DIV_SYM bit_expr`               | 整数除法运算（Integer division）                             |
| `bit_expr MOD_SYM bit_expr`               | 取模运算（Modulo operator）                                  |
| `bit_expr '^' bit_expr`                   | 按位异或运算（Bitwise XOR）                                  |
| `simple_expr`                             | 简单表达式：递归的出口                                       |

```C++
bit_expr:
          bit_expr '|' bit_expr %prec '|'
          {
            $$= NEW_PTN Item_func_bit_or(@$, $1, $3);
          }
        | bit_expr '&' bit_expr %prec '&'
          {
            $$= NEW_PTN Item_func_bit_and(@$, $1, $3);
          }
        | bit_expr SHIFT_LEFT bit_expr %prec SHIFT_LEFT
          {
            $$= NEW_PTN Item_func_shift_left(@$, $1, $3);
          }
        | bit_expr SHIFT_RIGHT bit_expr %prec SHIFT_RIGHT
          {
            $$= NEW_PTN Item_func_shift_right(@$, $1, $3);
          }
        | bit_expr '+' bit_expr %prec '+'
          {
            $$= NEW_PTN Item_func_plus(@$, $1, $3);
          }
        | bit_expr '-' bit_expr %prec '-'
          {
            $$= NEW_PTN Item_func_minus(@$, $1, $3);
          }
        | bit_expr '+' INTERVAL_SYM expr interval %prec '+'
          {
            $$= NEW_PTN Item_date_add_interval(@$, $1, $4, $5, 0);
          }
        | bit_expr '-' INTERVAL_SYM expr interval %prec '-'
          {
            $$= NEW_PTN Item_date_add_interval(@$, $1, $4, $5, 1);
          }
        | bit_expr '*' bit_expr %prec '*'
          {
            $$= NEW_PTN Item_func_mul(@$, $1, $3);
          }
        | bit_expr '/' bit_expr %prec '/'
          {
            $$= NEW_PTN Item_func_div(@$, $1,$3);
          }
        | bit_expr '%' bit_expr %prec '%'
          {
            $$= NEW_PTN Item_func_mod(@$, $1,$3);
          }
        | bit_expr DIV_SYM bit_expr %prec DIV_SYM
          {
            $$= NEW_PTN Item_func_div_int(@$, $1,$3);
          }
        | bit_expr MOD_SYM bit_expr %prec MOD_SYM
          {
            $$= NEW_PTN Item_func_mod(@$, $1, $3);
          }
        | bit_expr '^' bit_expr
          {
            $$= NEW_PTN Item_func_bit_xor(@$, $1, $3);
          }
        | simple_expr %prec SET_VAR
        ;
```

> `simple_expr` 语义组用于解析简单表达式；
>
> `interval` 语义组用于解析表示时间间隔的所有关键字；
>
> `expr` 语义组解析一般表达式。
