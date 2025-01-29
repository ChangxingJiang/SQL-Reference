目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)

- 前置文档：[MySQL 源码｜32 - 探索过程记录（SQL 结构 > 词法解析 > 语法解析）](https://zhuanlan.zhihu.com/p/714778990)

> 根据之前的探索，我们已经了解到 MySQL 的语法解析逻辑就存在于 `sql_yacc.yy` 文件中，使用 bison 规则实现。因此，在开始梳理这段逻辑前，我们首先来了解 bison 的基础语法规则。

------

### 基本概念

Bison 是一个通用的解析器生成器（parser generator），将无上下文文法（context-free grammar）这转化为使用 LALR(1)、LELR(1) 或标准 LR(1) 解析器表的确定性 LR 或广义 LR（GLR）解析器，通过解析器可以将输入的文本解析为一棵语法分析树。因此，Bison 可以被用于开发各种语言解析器。

Bison 使用无上下文文法来描述被解析语言的结构。具体地，我们需要将构造一个或多个语法组（syntactic grouping）并提供构成这些语法组的规则。例如，在 C 语言中，表达式（expression）是一个语法组，它的构造规则（rule）可能是 “一个表达式可以由一个符号和另一个表达式组成”，另一个规则可能是 “一个表达式可以是一个整数”。这些规则可以是递归的，但必须至少有一条规则能够跳出递归。

呈现此类规则的最常见形式系统是巴科斯 - 诺尔范式（Backus-Naur Form，BNF），该范式是为了指定 Algol 60 语言而开发的。任何以 BNF 表示的文法都是无上下文文法。Bison 的输入本质上是机器可读的 BNF。

> 来源：[Bison 官方文档 - 1.1 Languages and Context-Free Grammars](https://www.gnu.org/software/bison/manual/bison.html#Language-and-Grammar)

#### 终结符和非终结符

在 Bison 的文法（formal grammar）中包含终结符（terminal symbol）和非终结符（nonterminal symbol）两种。

非终结符通过使用小写字母命名，例如 `expr`、`stmt` 等。

终结符也成为标记类型（token kind），通常使用大写字母命名，例如 `INTEGER`、`IDENTIFIER` 等。终结符也可以使用字符字面值表示，例如 `'('`、`')'` 等，通常当标记只是一个字符时这样标记。

> 来源：[Bison 官方文档 - 1.2 From Formal Rules to Bison Input](https://www.gnu.org/software/bison/manual/bison.html#Grammar-in-Bison)

#### 语义值（semantic values）

Bison 语法的每个标记（token）都包含标记种类（token kind）和语义值（semantic value）。标记种类作为标识符（identifier），指定了标记在语法中可以出现的位置以及它应该如何与其他标记分组；而语义值包含了标记在语法角色之外的意义，它可能表示整数的实际数值、标识符的文本名称或与标记解释相关的任何其他信息，类似 `','` 这样的纯标点符号标记通常不需要语义值。

在标记时，仅使用标记种类而不考虑语义值。例如，如果一条规则引用了终结符 “整数常量”，那么它意味着在该上下文中，任何整数常量在语法上都是允许的。例如若 “x+4” 是语法正确的，那么“x+1”或 “x+3989” 同样语法正确。

在解析时，则会根据确切的语义值进行具体地处理。

> 来源：[Bison 官方文档 - 1.3 Semantic Values](https://www.gnu.org/software/bison/manual/bison.html#Semantic-Values)

#### 语义动作（semantic actions）

在 Bison 语法中，一个语法规则可以包含一个由 C 语句组成的动作（action）。每当解析器识别到该语法规则时，就会执行这个动作。

通常，这个动作是根据各个组成部分的语义值来计算整个结构的语义值。

> 来源：[Bison 官方文档 - 1.4 Semantic Actions](https://www.gnu.org/software/bison/manual/bison.html#Semantic-Actions)

### 基本语法

#### 语义组（syntactic grouping）的语法

以如下语义组 `input` 为例：

```bison
input:
  %empty
| input line
;
```

- 在语义组名称之后，添加 `:` 与备选规则分隔
- 在备选逻辑结束之后，添加 `;` 标记逻辑已结束
- 使用 `|` 符号分隔每一个备选规则。

> 来源：[Bison 官方文档 - 2.1.2.1 Explanation of `input`](https://www.gnu.org/software/bison/manual/bison.html#Rpcalc-Input)

如果允许匹配一个空的输入字符串，则添加空的备选方案；通常来说，将空的备选方案放在第一个位置，并使用（可选的）`%empty` 指令或 `/* empty */` 注释。

> 来源：[Bison 官方文档 - 3.3.2 Empty Rules](https://www.gnu.org/software/bison/manual/bison.html#Empty-Rules)

#### 语义动作（semantic actions）的语法

在 Bison 语法中，执行语义动作的 C 代码需嵌套在 `{}` 之中。

以如下语义组 `exp` 为例：

```bison
exp:
  NUM
| exp exp '+'   { $$ = $1 + $2;      }
| exp exp '-'   { $$ = $1 - $2;      }
| exp exp '*'   { $$ = $1 * $2;      }
| exp exp '/'   { $$ = $1 / $2;      }
| exp exp '^'   { $$ = pow ($1, $2); }  /* Exponentiation */
| exp 'n'       { $$ = -$1;          }  /* Unary minus   */
;
```

在每个语义动作中，`$$` 符号代表当前语义组需要构造的语义值（返回值）；而当前规则各个组成部分的语义值（参数值）可以使用 `$n` 来引用，`$n` 表示规则中的第 n 个组成部分的语义值，例如 `$1` 就表示规则中的第 1 个组成部分的语义值。通常来说，大部分规则的语义动作就是为 `$$` 赋值。

> 来源：[Bison 官方文档 - 2.1.2 Grammar Rules for `rpcalc`](https://www.gnu.org/software/bison/manual/bison.html#Rpcalc-Rules)

当没有显式地指定语义动作时，使用会使用隐式的默认语义动作 `{ $$ = $1; }`，即将规则中第 1 个组成部分的语义值作为当前语义组的语义值返回。

> 来源：[Bison 官方文档 - 2.1.2.3 Explanation of `exp`](https://www.gnu.org/software/bison/manual/bison.html#Rpcalc-Exp)

`@n` 符号表示规则中的第 n 个组成部分的位置（location），`@$` 符号表示整个语义组的位置。

> 来源：[Bison 官方文档 - 3.5.2 Actions and Locations](https://www.gnu.org/software/bison/manual/bison.html#Actions-and-Locations)

### 语义标记

##### `%start` 标记【官方文档：[3.7.10 The Start-Symbol](https://www.gnu.org/software/bison/manual/bison.html#Start-Decl)】

```bison
%start symbol
```

`%start` 记号用于声明规则的开始位置。 

##### `%type` 标记【官方文档：[3.7.4 Nonterminal Symbols](https://www.gnu.org/software/bison/manual/bison.html#Type-Decl)】

```bison
%type <type> nonterminal...
```

`%type` 记号用于声明一个规则 `nonterminal` 的值类型。如果多个规则具有相同的值类型，可以在同一个 `%type` 中给出任意数量的规则名称，并使用空格来分隔这些符号名称。

##### `%token` 标记【官方文档：[3.7.2 Token Kind Names](https://www.gnu.org/software/bison/manual/bison.html#Token-Decl)】

```bison
%token name
```

`%token` 标记用于声明一个不指定优先级和结合顺序的标记名称，Bison 会在解析器中定义这个名称，在配置时就可以使用名称来代替标记类型的代码。可以通过在标记名称后之后添加一个非负的十进制或十六进制整数，来显式地指定标记类型的数字代码：

```bison
%token NUM 300
%token XNUM 0x12d // a GNU extension
```

##### 操作符优先级【官方文档：[3.7.3 Operator Precedence](https://www.gnu.org/software/bison/manual/bison.html#Precedence-Decl)】

当出现 `x op y op z` 的情况时，需要确定符号 `op` 的结合顺序，是 `(x op y) op z` 还是 `x op (y op z)`。此时，可以使用  `%left`、`%right`、`%nonassoc` 或 `%precedence` 记号来替代 `%token` 记号，从而指定操作符的结合顺序。指定结合顺序的语法样例如下：

```bison
%left symbols...
%left <type> symbols...
```

- 当 `op` 为 `%left` 时，`x op y op z` 的计算顺序为 `(x op y) op z`
- 当 `op` 为 `%right` 时，`x op y op z` 的计算顺序为 `x op (y op z)`
- 当 `op` 为 `%nonassoc` 时，`x op y op z` 将视为语法错误
- 当 `op` 为 `%precedence` 时，仅指定符号优先级，而并不指定记号的结合顺序【在 MySQL 源码中没有用到】

##### `%parse-param` 标记【官方文档：[4.1 The Parser Function](https://www.gnu.org/software/bison/manual/bison.html#Parser-Function)】

```bison
%parse-param {int *nastiness} {int *randomness}
```

可以使用 `%parse-param` 标记为 `yyparse` 函数定义额外的参数。

##### `%lex-param` 标记【官方文档：[4.3.6 Calling Conventions for Pure Parsers](https://www.gnu.org/software/bison/manual/bison.html#Pure-Calling)】

```bison
%lex-param   {scanner_mode *mode}
```

可以使用 `%lex-param` 标记为 `yylex` 函数定义额外的参数。

##### `%define api.pure` 标记【官方文档：[3.7.11 A Pure (Reentrant) Parser](https://www.gnu.org/software/bison/manual/bison.html#Pure-Decl)】

```bison
%define api.pure
```

使用 `%define api.pure` 标记，可以定义一个纯粹的（可重入）的解析器，即允许同一个线程多次运行它。这会使 `yylval` 和 `yylloc` 成为 `yyparse` 函数的本地变量。

##### `%define api.prefix` 标记【官方文档：[3.7.14 %define Summary](https://www.gnu.org/software/bison/manual/bison.html#index-_0025define-api_002eprefix)】

```bison
%define api.prefix {prefix}
```

使用 `%define api.prefix {prefix}` 标记，可以重命名生成的标识符。

##### `%expect` 标记【官方文档：[3.7.9 Suppressing Conflict Warnings](https://www.gnu.org/software/bison/manual/bison.html#Expect-Decl)】

```bison
%expect n
```

使用 `%expect n` 标记，表示如果 shift/reduce 冲突的数量与 `n` 不同，或者存在任何 reduce/reduce 的冲突，则报告错误。

##### `%prec` 标记【官方文档：[5.4 Context-Dependent Precedence](https://www.gnu.org/software/bison/manual/bison.html#Contextual-Precedence)】

```bison
%prec terminal-symbol
```

`%prec` 标记写在规则逻辑之后。通过使用 `%prec` 标记，可以调整 terminal-symbol 在特定规则中的优先级，从而覆盖掉以常规优先级为当前规则推导的优先级顺序。