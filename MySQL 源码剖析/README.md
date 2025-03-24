# MySQL 源码剖析

## 1 MySQL 解析逻辑概述

- [083 - SQL 语句的执行过程](https://zhuanlan.zhihu.com/p/720779596)
- [082 - 词法解析和语法解析的入口逻辑](https://zhuanlan.zhihu.com/p/720494111)
- [087 - SELECT 语句解析后的执行过程](https://zhuanlan.zhihu.com/p/721410833)

## 2 词法解析

- [086 - 词法解析(V2)：词法解析入口逻辑（my_sql_parser_lex）](https://zhuanlan.zhihu.com/p/721399771)

### 2.1 文本扫描器

- [013 - 词法解析的状态存储器（Lex_input_stream）的主要数据成员与函数](https://zhuanlan.zhihu.com/p/714758654)
- [014 - 词法解析中的 CHARSET_INFO 结构体及衍生函数](https://zhuanlan.zhihu.com/p/714758816)
- [【已作废】012 - 词法解析：Lex_input_stream（状态存储器）的数据成员](https://zhuanlan.zhihu.com/p/714758343)

### 2.2 状态及状态转移

第 1 版：

- [008 - 词法解析：lex_one_token 函数外层逻辑](https://zhuanlan.zhihu.com/p/714756661)
- [009 - 词法解析：自动机状态转移矩阵](https://zhuanlan.zhihu.com/p/714757250)
- [010 - 词法解析：状态及状态转移规则（1）](https://zhuanlan.zhihu.com/p/714757384)
- [011 - 词法解析：状态及状态转移规则（2）](https://zhuanlan.zhihu.com/p/714758126)
- [015 - 词法解析：状态及状态转移规则（3）](https://zhuanlan.zhihu.com/p/714759195)
- [016 - 词法解析：状态及状态转移规则（4）](https://zhuanlan.zhihu.com/p/714759527)
- [017 - 词法解析：状态及状态转移规则（5）](https://zhuanlan.zhihu.com/p/714759836)
- [018 - 词法解析：状态及状态转移规则（6）](https://zhuanlan.zhihu.com/p/714759996)
- [019 - 词法解析：状态及状态转移规则（7）](https://zhuanlan.zhihu.com/p/714760147)
- [021 - 词法解析：状态转移逻辑梳理](https://zhuanlan.zhihu.com/p/714760407)

第 2 版：

- [MySQL 源码｜105 - 词法解析：状态转移逻辑（运算符）](https://zhuanlan.zhihu.com/p/32478841292)
- [MySQL 源码｜106 - 词法解析：状态转移逻辑（标识符）](https://zhuanlan.zhihu.com/p/32479435171)
- [MySQL 源码｜107 - 词法解析：状态转移逻辑（字面值）](https://zhuanlan.zhihu.com/p/32479758473)
- [MySQL 源码｜108 - 词法解析：状态转移逻辑（其他符号）](https://zhuanlan.zhihu.com/p/32479980351)

### 2.3 调用方法

- [020 - 词法解析：词法解析器调用方法](https://zhuanlan.zhihu.com/p/714760257)

### 2.4 终结符

2.4.1：[103 - 非关键字类型的终结符](https://zhuanlan.zhihu.com/p/26114007689)

2.4.2：[104 - 关键字类型的终结符](https://zhuanlan.zhihu.com/p/26372027719)

## 3 语法解析

- [085 - 语法解析(V2)：语法解析入口逻辑](https://zhuanlan.zhihu.com/p/720995765)

### 3.1 Bison 及使用方法

- [033 - 语法解析：bison 基础语法规则](https://zhuanlan.zhihu.com/p/714779214)
- [062 - 词法解析：调用词法解析器的逻辑](https://zhuanlan.zhihu.com/p/716898493)

### 3.2 终结符与非终结符

- [060 - 保留字和函数名的存储和解析逻辑](https://zhuanlan.zhihu.com/p/716485597)
- [061 - 语法解析(V2)：MySQL 语法解析指定的返回值类型的联合体](https://zhuanlan.zhihu.com/p/716691811)
- [034 - 语法解析：所有 token 的名称与含义列表](https://zhuanlan.zhihu.com/p/714779441)
- [063 - 语法解析(V2)：附录 - 各语义组和终结符的返回值类型](https://zhuanlan.zhihu.com/p/717627004)

### 3.3 字面值与标识符

- [059 - 语法解析(V2)：时间间隔字面值 & 时间字面值](https://zhuanlan.zhihu.com/p/716312316)
- [065 - 语法解析(V2)：字符串字面值](https://zhuanlan.zhihu.com/p/717934287)
- [064 - 语法解析(V2)：非保留关键字](https://zhuanlan.zhihu.com/p/717740054)
- [041 - 语法解析(V2)：标识符 IDENT](https://zhuanlan.zhihu.com/p/714782314)
- [066 - 语法解析(V2)：预编译表达式的参数值](https://zhuanlan.zhihu.com/p/718323872)
- [067 - 语法解析(V2)：数值字面值](https://zhuanlan.zhihu.com/p/718508554)
- [048 - 语法解析(V2)：通用字面值](https://zhuanlan.zhihu.com/p/715612312)
- [【已作废】042 - 语法解析：数值、时间型字面值](https://zhuanlan.zhihu.com/p/714782942)

### 3.4 基础语法元素

- [038 - 语法解析(V2)：窗口函数](https://zhuanlan.zhihu.com/p/714780506)
- [037 - 语法解析(V2)：聚集函数](https://zhuanlan.zhihu.com/p/714780278)
- [043 - 语法解析(V2)：关键字函数](https://zhuanlan.zhihu.com/p/714784157)
- [044 - 语法解析(V2)：非关键字函数](https://zhuanlan.zhihu.com/p/715092510)
- [045 - 语法解析(V2)：通用函数](https://zhuanlan.zhihu.com/p/715159997)
- [046 - 语法解析(V2)：为避免语法冲突专门处理的函数](https://zhuanlan.zhihu.com/p/715204070)
- [047 - 语法解析(V2)：子查询](https://zhuanlan.zhihu.com/p/715426420)
- [073 - 语法解析(V2)：数据类型（type）](https://zhuanlan.zhihu.com/p/719867311)
- [049 - 语法解析(V2)：CAST、CONVERT 函数和 BINARY 关键字](https://zhuanlan.zhihu.com/p/715701073)
- [【已作废】035 - 语法解析：char 函数](https://zhuanlan.zhihu.com/p/714779978)
- [【已作废】036 - 语法解析：current_user 函数与 user 函数](https://zhuanlan.zhihu.com/p/714780124)

### 3.5 表达式（expression）

- [050 - 语法解析：简单表达式（simple_expr）](https://zhuanlan.zhihu.com/p/715703857)
- [069 - 语法解析：位表达式（bit_expr）](https://zhuanlan.zhihu.com/p/719439177)
- [070 - 语法解析：谓语表达式（predicate）](https://zhuanlan.zhihu.com/p/719441615)
- [071 - 语法解析：布尔表达式（bool_pri）](https://zhuanlan.zhihu.com/p/719443599)
- [072 - 语法解析：一般表达式（expr）](https://zhuanlan.zhihu.com/p/719447959)
- [【已作废】051 - 语法解析：高级表达式](https://zhuanlan.zhihu.com/p/715813664)

### 3.6 子句（clause）

- [068 - 语法解析：LOCKING 子句（锁定读取）](https://zhuanlan.zhihu.com/p/719010523)
- [039 - 语法解析：ORDER BY 子句](https://zhuanlan.zhihu.com/p/714781112)
- [040 - 语法解析：GROUP BY 子句](https://zhuanlan.zhihu.com/p/714781362)
- [054 - 语法解析：WINDOW 子句](https://zhuanlan.zhihu.com/p/716014095)
- [074 - 语法解析：JSON_TABLE 函数](https://zhuanlan.zhihu.com/p/720046825)
- [075 - 语法解析：索引提示子句（USE、FORCE、IGNORE）](https://zhuanlan.zhihu.com/p/720054242)
- [076 - 语法解析：表语句（table_reference）](https://zhuanlan.zhihu.com/p/720247259)
- [052 - 语法解析：FROM 子句和 JOIN 子句](https://zhuanlan.zhihu.com/p/715841708)
- [053 - 语法解析：INTO 子句](https://zhuanlan.zhihu.com/p/715903798)
- [056 - 语法解析：WITH 子句](https://zhuanlan.zhihu.com/p/716036308)
- [077 - 语法解析：WHERE、HAVING 和 QUALIFY 子句](https://zhuanlan.zhihu.com/p/720281792)
- [078 - 语法解析：LIMIT 子句](https://zhuanlan.zhihu.com/p/720293254)
- [084 - 语法解析：DDL 的 PARTITION BY 子句｜V20240919](https://zhuanlan.zhihu.com/p/720809560)

### 3.7 语句（statement）

#### 3.7.1 数据操作语句（Data Manipulation Statements）

- [055 - 语法解析：基础查询语句（query_specification）](https://zhuanlan.zhihu.com/p/716034780)
- [058 - 语法解析：SELECT 语句](https://zhuanlan.zhihu.com/p/716212004)
- [057 - 语法解析：UPDATE 语句和 DELETE 语句](https://zhuanlan.zhihu.com/p/716038847)
- [079 - 语法解析：INSERT 语句和 REPLACE 语句](https://zhuanlan.zhihu.com/p/720326790)
- [080 - 语法解析：LOAD 语句](https://zhuanlan.zhihu.com/p/720346705)

#### 3.7.2. SHOW 表达式

- [089 - 语法解析：SHOW 语句 Part1 - BINLOG 及主从同步](https://zhuanlan.zhihu.com/p/875262374)

#### 3.7.3 工具语句（Utility Statements）

- [081 - 语法解析：EXPLAIN 语句和 DESC 语句](https://zhuanlan.zhihu.com/p/720358851)

### 3.8 探索过程

- [022 - SQLParser 类及其子类](https://zhuanlan.zhihu.com/p/714760682)
- [023 - 句法解析：ImplicitCommitParser 的解析方法](https://zhuanlan.zhihu.com/p/714762241)
- [024 - 句法解析：SplittingAllowedParser 解析器](https://zhuanlan.zhihu.com/p/714762393)
- [025 - 句法解析：StartTransactionParser 解析器](https://zhuanlan.zhihu.com/p/714762533)
- [026 - 句法解析：ShowWarningsParser 解析器](https://zhuanlan.zhihu.com/p/714762658)
- [027 - ImplicitCommitParser 解析器和 SplittingAllowedParser 解析器的调用位置](https://zhuanlan.zhihu.com/p/714762963)
- [028 - StartTransactionParser 解析器和 ShowWarningsParser 解析器的调用位置](https://zhuanlan.zhihu.com/p/714763124)
- [029 - 解析过程的 command 函数逻辑](https://zhuanlan.zhihu.com/p/714777998)

## 4 优化过程

### 4.1 条件表达式的优化

[100 - 优化器：条件表达式的优化](https://zhuanlan.zhihu.com/p/20730157613)

- [096 - 优化器：多重等式谓词（MEP）](https://zhuanlan.zhihu.com/p/10584216150)
- [097 - 优化器：将单个等式谓词转换为多重等式谓词](https://zhuanlan.zhihu.com/p/11267690125)
- [098 - 优化器：将多层等式谓词转换为多重等式谓词](https://zhuanlan.zhihu.com/p/20647806424)
- [099 - 优化器：优化 WHERE、HAVING 和 JOIN 子句中的条件表达式](https://zhuanlan.zhihu.com/p/20708387581)

### 4.2 分区裁剪

[101 - 优化器：分区裁剪](https://zhuanlan.zhihu.com/p/20759745269)

### 4.x 查询树结构

#### 4.x.1 存储语句的数据结构

- [001 - Query_block 和 Query_expression 的连接关系](https://zhuanlan.zhihu.com/p/714579718)
- [002 - 查询树与 Query_term 节点](https://zhuanlan.zhihu.com/p/714580521)
- [004 - Query_expression 类的基本变量和方法](https://zhuanlan.zhihu.com/p/714755220)
- [005 - Query_term 及其子类](https://zhuanlan.zhihu.com/p/714755677)
- [006 - Query_block 类的基本变量和方法](https://zhuanlan.zhihu.com/p/714756005)

#### 4.x.2 语句执行的核心结构体

- [007 - LEX 结构体](https://zhuanlan.zhihu.com/p/714756273)

### 4.x 其他优化逻辑

- [088 - DML 优化器：DML 语句的执行过程](https://zhuanlan.zhihu.com/p/857293533)
- [090 - 优化器：优化器的主要调用结构](https://zhuanlan.zhihu.com/p/899320354)
- [091 - 优化器：JOIN 类的 optimize() 函数](https://zhuanlan.zhihu.com/p/920988228)
- [092 - 优化器：不使用超图优化器的主要逻辑](https://zhuanlan.zhihu.com/p/1282593654)
- [093 - 优化器：使用超图优化器的主要逻辑](https://zhuanlan.zhihu.com/p/1470761493)
- [094 - 优化器：临时表配置对象及字段类型统计](https://zhuanlan.zhihu.com/p/2075555413)
- [095 - 优化器：复制 Query_block 的可优化条件](https://zhuanlan.zhihu.com/p/5019644616)

## 5 执行过程

### 5.1 Processor 类

- [030 - 执行的过程的抽象基类 BasicProcessor](https://zhuanlan.zhihu.com/p/714778229)
- [031 - 执行的过程的 Processor 类](https://zhuanlan.zhihu.com/p/714778369)

## 6 附录

### 6.1 查询表

[6.1.1 源码涉及类型别名](https://zhuanlan.zhihu.com/p/714580623)

### 6.2 探索过程记录

[6.2.1 探索过程记录（SQL 结构 词法解析 语法解析）](https://zhuanlan.zhihu.com/p/714778990)