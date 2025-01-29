目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：

- [include/mysql/strings/m_ctype.h](https://github.com/mysql/mysql-server/blob/trunk/include/mysql/strings/m_ctype.h)
- [strings/CHARSET_INFO.txt](https://github.com/mysql/mysql-server/blob/trunk/strings/CHARSET_INFO.txt)

---

`CHARSET_INFO` 结构体是一个包含了用于字符集处理、校对规则的数据结构。对于不同的数据集，MySQL 会加载不同的 `CHARSET_INFO` 实例：

```C++
extern MYSQL_STRINGS_EXPORT CHARSET_INFO my_charset_bin;
extern MYSQL_STRINGS_EXPORT CHARSET_INFO my_charset_latin1;
extern MYSQL_STRINGS_EXPORT CHARSET_INFO my_charset_filename;
extern MYSQL_STRINGS_EXPORT CHARSET_INFO my_charset_utf8mb4_0900_ai_ci;
extern MYSQL_STRINGS_EXPORT CHARSET_INFO my_charset_utf8mb4_0900_bin;

extern MYSQL_STRINGS_EXPORT CHARSET_INFO my_charset_latin1_bin;
extern MYSQL_STRINGS_EXPORT CHARSET_INFO my_charset_utf32_unicode_ci;
extern MYSQL_STRINGS_EXPORT CHARSET_INFO my_charset_utf8mb3_general_ci;
extern MYSQL_STRINGS_EXPORT CHARSET_INFO my_charset_utf8mb3_tolower_ci;
extern MYSQL_STRINGS_EXPORT CHARSET_INFO my_charset_utf8mb3_unicode_ci;
extern MYSQL_STRINGS_EXPORT CHARSET_INFO my_charset_utf8mb3_bin;
extern MYSQL_STRINGS_EXPORT CHARSET_INFO my_charset_utf8mb4_bin;
extern MYSQL_STRINGS_EXPORT CHARSET_INFO my_charset_utf8mb4_general_ci;
```

`CHARSET_INFO` 结构体在 [include/mysql/strings/m_ctype.h](https://github.com/mysql/mysql-server/blob/trunk/include/mysql/strings/m_ctype.h) 中被定义，但是其中的数据成员都在 [strings/CHARSET_INFO.txt](https://github.com/mysql/mysql-server/blob/trunk/strings/CHARSET_INFO.txt) 中被说明，而不是被直接实现。

```C++
/* See strings/CHARSET_INFO.txt about information on this structure  */
struct CHARSET_INFO {
  unsigned number;
  unsigned primary_number;
  unsigned binary_number;
  unsigned state;
  const char *csname;
  const char *m_coll_name;
  const char *comment;
  const char *tailoring;
  struct Coll_param *coll_param;
  const uint8_t *ctype;
  const uint8_t *to_lower;
  const uint8_t *to_upper;
  const uint8_t *sort_order;
  struct MY_UCA_INFO *uca; /* This can be changed in apply_one_rule() */
  const uint16_t *tab_to_uni;
  const MY_UNI_IDX *tab_from_uni;
  const MY_UNICASE_INFO *caseinfo;
  const struct lex_state_maps_st *state_maps; /* parser internal data */
  const uint8_t *ident_map;                   /* parser internal data */
  unsigned strxfrm_multiply;
  uint8_t caseup_multiply;
  uint8_t casedn_multiply;
  unsigned mbminlen;
  unsigned mbmaxlen;
  unsigned mbmaxlenlen;
  my_wc_t min_sort_char;
  my_wc_t max_sort_char; /* For LIKE optimization */
  uint8_t pad_char;
  bool escape_with_backslash_is_dangerous;
  uint8_t levels_for_compare;

  MY_CHARSET_HANDLER *cset;
  MY_COLLATION_HANDLER *coll;

  /**
    If this collation is PAD_SPACE, it collates as if all inputs were
    padded with a given number of spaces at the end (see the "num_codepoints"
    flag to strnxfrm). NO_PAD simply compares unextended strings.

    Note that this is fundamentally about the behavior of coll->strnxfrm.
  */
  enum Pad_attribute pad_attribute;
};
```

### 重要数据成员

#### `ident_map`：判断字符是否为 SQL 字符

```C++
uint8_t ident_map[256];
```

```txt
Parser maps
-----------
state_map[]
ident_map[]

These maps are used to quickly identify whether a character is an
identifier part, a digit, a special character, or a part of another
SQL language lexical item.

Probably can be combined with ctype array in the future.
But for some reasons these two arrays are used in the parser,
while a separate ctype[] array is used in the other part of the
code, like fulltext, etc.
```

这个数组用于快速判断一个字符是否为标识符、数字、特殊字符的一部分，还是 SQL 语句的其他组成部分。可以用来判断当前 token 是否已经结束。

#### `ctype`：记录每个字符的类型

```C++
  const uint8_t *ctype;
```

```txt
  ctype      - pointer to array[257] of "type of characters"
               bit mask for each character, e.g., whether a 
               character is a digit, letter, separator, etc.

               Monty 2004-10-21:
                 If you look at the macros, we use ctype[(char)+1].
                 ctype[0] is traditionally in most ctype libraries
                 reserved for EOF (-1). The idea is that you can use
                 the result from fgetc() directly with ctype[]. As
                 we have to be compatible with external ctype[] versions,
                 it's better to do it the same way as they do...
```

`ctype` 数据成员中记录了每个数据从字符的类型，该类型使用存储在二进制数中的每个位表示，具体地：

```C++
static constexpr uint8_t MY_CHAR_U   =   01; /* Upper case */
static constexpr uint8_t MY_CHAR_L   =   02; /* Lower case */
static constexpr uint8_t MY_CHAR_NMR =   04; /* Numeral (digit) */
static constexpr uint8_t MY_CHAR_SPC =  010; /* Spacing character */
static constexpr uint8_t MY_CHAR_PNT =  020; /* Punctuation */
static constexpr uint8_t MY_CHAR_CTR =  040; /* Control character */
static constexpr uint8_t MY_CHAR_B   = 0100; /* Blank */
static constexpr uint8_t MY_CHAR_X   = 0200; /* heXadecimal digit */
```

### 字符类型判断和转换函数

#### `my_isascii(char ch)`：判断 `ch` 是否为 ASCII 字符

```C++
inline bool my_isascii(char ch) { return (ch & ~0177) == 0; }
```

#### `my_toupper(const CHARSET_INFO *cs, char ch)`：将字符 `ch` 转换为大写格式

通过调用 `CHARSET_INFO` 结构体的 `to_upper` 数据成员，实现将英文小写转换为英文大写。

```C++
inline char my_toupper(const CHARSET_INFO *cs, char ch) {
  return static_cast<char>(cs->to_upper[static_cast<uint8_t>(ch)]);
}
```

#### `my_tolower(const CHARSET_INFO *cs, char ch)`：将字符 `ch` 转换为小写格式

通过调用 `CHARSET_INFO` 结构体的 `to_lower` 数据成员，实现将英文大写转换为英文小写。

```C++
inline char my_tolower(const CHARSET_INFO *cs, char ch) {
  return static_cast<char>(cs->to_lower[static_cast<uint8_t>(ch)]);
}
```

#### `my_isalpha(const CHARSET_INFO *cs, char ch)`：判断字符 `ch` 是否为英文字母

通过调用 `CHARSET_INFO` 结构体的 `ctype` 数据成员，判断 `ch` 是否为英文小写字母或英文大写字母。

```C++
inline bool my_isalpha(const CHARSET_INFO *cs, char ch) {
  return ((cs->ctype + 1)[static_cast<uint8_t>(ch)] &
          (MY_CHAR_U | MY_CHAR_L)) != 0;
}
```

#### `my_isupper(const CHARSET_INFO *cs, char c)`：判断字符 `ch` 是否为大写英文字母

通过调用 `CHARSET_INFO` 结构体的 `ctype` 数据成员，判断 `ch` 是否为大写英文字母。

```C++
inline bool my_isupper(const CHARSET_INFO *cs, char ch) {
  return ((cs->ctype + 1)[static_cast<uint8_t>(ch)] & MY_CHAR_U) != 0;
}
```

#### `my_islower(const CHARSET_INFO *cs, char ch)`：判断字符 `ch` 是否为小写英文字母

通过调用 `CHARSET_INFO` 结构体的 `ctype` 数据成员，判断 `ch` 是否为小写英文字母。

```C++
inline bool my_islower(const CHARSET_INFO *cs, char ch) {
  return ((cs->ctype + 1)[static_cast<uint8_t>(ch)] & MY_CHAR_L) != 0;
}
```

#### `my_isdigit(const CHARSET_INFO *cs, char ch)`：判断字符 `ch` 是否为数字

通过调用 `CHARSET_INFO` 结构体的 `ctype` 数据成员，判断 `ch` 是否为数字。

```C++
inline bool my_isdigit(const CHARSET_INFO *cs, char ch) {
  return ((cs->ctype + 1)[static_cast<uint8_t>(ch)] & MY_CHAR_NMR) != 0;
}
```

#### `my_isxdigit(const CHARSET_INFO *cs, char ch)`：判断 `ch` 是否为十六进制数

通过调用 `CHARSET_INFO` 结构体的 `ctype` 数据成员，判断 `ch` 是否为十六进制数字（`[0-9A-Fa-f]`）。

```C++
inline bool my_isxdigit(const CHARSET_INFO *cs, char ch) {
  return ((cs->ctype + 1)[static_cast<uint8_t>(ch)] & MY_CHAR_X) != 0;
}
```

#### `my_isalnum(const CHARSET_INFO *cs, char ch)`：判断字符 `ch` 是否为英文字母或数字

通过调用 `CHARSET_INFO` 结构体的 `ctype` 数据成员，判断 `ch` 是否为英文字母或数字。

```C++
inline bool my_isalnum(const CHARSET_INFO *cs, char ch) {
  return ((cs->ctype + 1)[static_cast<uint8_t>(ch)] &
          (MY_CHAR_U | MY_CHAR_L | MY_CHAR_NMR)) != 0;
}
```

#### `my_isspace(const CHARSET_INFO *cs, char ch)`：判断字符 `ch` 是否为空白字符

通过调用 `CHARSET_INFO` 结构体的 `ctype` 数据成员，判断 `ch` 是否为空白字符。

```C++
inline bool my_isspace(const CHARSET_INFO *cs, char ch) {
  return ((cs->ctype + 1)[static_cast<uint8_t>(ch)] & MY_CHAR_SPC) != 0;
}
```

#### `my_ispunct(const CHARSET_INFO *cs, char ch)`：判断字符 `ch` 是否为标点符号

通过调用 `CHARSET_INFO` 结构体的 `ctype` 数据成员，判断 `ch` 是否为标点符号字符。

```C++
inline bool my_ispunct(const CHARSET_INFO *cs, char ch) {
  return ((cs->ctype + 1)[static_cast<uint8_t>(ch)] & MY_CHAR_PNT) != 0;
}
```

#### `my_isgraph(const CHARSET_INFO *cs, char ch)`：判断字符 `ch` 是否为英文字母、数字或标点符号

通过调用 `CHARSET_INFO` 结构体的 `ctype` 数据成员，判断 `ch` 是否为英文字母、数字或标点符号。

```C++
inline bool my_isgraph(const CHARSET_INFO *cs, char ch) {
  return ((cs->ctype + 1)[static_cast<uint8_t>(ch)] &
          (MY_CHAR_PNT | MY_CHAR_U | MY_CHAR_L | MY_CHAR_NMR)) != 0;
}
```

#### `my_iscntrl(const CHARSET_INFO *cs, char ch)`：判断字符 `ch` 是否为控制字符

通过调用 `CHARSET_INFO` 结构体的 `ctype` 数据成员，判断 `ch` 是否为控制字符。

```C++
inline bool my_iscntrl(const CHARSET_INFO *cs, char ch) {
  return ((cs->ctype + 1)[static_cast<uint8_t>(ch)] & MY_CHAR_CTR) != 0;
}
```

#### `my_isvar(const CHARSET_INFO *cs, char ch)`：判断字符 `ch` 是否为标识符名称中的字符

通过调用 `CHARSET_INFO` 结构体的 `ctype` 数据成员，判断 `ch` 是否为标识符中的字符（英文字母、数字或下划线）。

```C++
inline bool my_isvar(const CHARSET_INFO *cs, char ch) {
  return my_isalnum(cs, ch) || (ch == '_');
}
```

#### `my_isvar_start(const CHARSET_INFO *cs, char ch)`：判断字符 `ch` 是否为标识符名称的开始字符

通过调用 `CHARSET_INFO` 结构体的 `ctype` 数据成员，判断 `ch` 是否为标识符的开始字符（英文字母或下划线）。

```C++
inline bool my_isvar_start(const CHARSET_INFO *cs, char ch) {
  return my_isalpha(cs, ch) || (ch == '_');
}
```

### `CHARSET_INFO` 成员函数的接口

#### `my_strnxfrm(...)`：生成排序键

Makes a sort key suitable for memcmp() corresponding to the given string.

生成一个与给定字符串相对应的、适合用于 `memcmp()` 函数的排序键。

```C++
inline size_t my_strnxfrm(const CHARSET_INFO *cs, uint8_t *dst, size_t dstlen,
                          const uint8_t *src, size_t srclen) {
  return cs->coll->strnxfrm(cs, dst, dstlen, dstlen, src, srclen, 0);
}
```

#### `my_strnncoll(...)`：使用给定规则集比较两个字符串

Compares two strings according to the given collation.

使用给定的规则集比较两个字符串。

```C++
inline int my_strnncoll(const CHARSET_INFO *cs, const uint8_t *a,
                        size_t a_length, const uint8_t *b, size_t b_length) {
  return cs->coll->strnncoll(cs, a, a_length, b, b_length, false);
}
```

#### `my_like_range(...)`：为优化器创建 LIKE range

Creates a LIKE range, for optimizer.

```C++
inline bool my_like_range(const CHARSET_INFO *cs, const char *s,
                          size_t s_length, char w_prefix, char w_one,
                          char w_many, size_t res_length, char *min_str,
                          char *max_str, size_t *min_len, size_t *max_len) {
  return cs->coll->like_range(cs, s, s_length, w_prefix, w_one, w_many,
                              res_length, min_str, max_str, min_len, max_len);
}
```

#### `my_wildcmp(...)`：执行通配符比较

Wildcard comparison, for LIKE.

执行 LIKE 用于使用的通配符比较逻辑。

```C++
inline int my_wildcmp(const CHARSET_INFO *cs, const char *str,
                      const char *str_end, const char *wildstr,
                      const char *wildend, int escape, int w_one, int w_many) {
  return cs->coll->wildcmp(cs, str, str_end, wildstr, wildend, escape, w_one,
                           w_many);
}
```

#### `my_strcasecmp(...)`：比较两个以 ASCIII 编码 0 为截止符号的字符串

0-terminated string comparison.

比较两个以 ASCIII 编码 0 为截止符号的字符串。

```C++
inline int my_strcasecmp(const CHARSET_INFO *cs, const char *s1,
                         const char *s2) {
  return cs->coll->strcasecmp(cs, s1, s2);
}
```

#### `my_charpos(...)`：计算指定字符串的偏移位置

calculates the offset of the given position in the string. Used in SQL functions LEFT(), RIGHT(), SUBSTRING(), INSERT().

执行 `LEFT()`、`RIGHT()`、`SUBSTRING()` 和 `INSERT()` 函数使用的计算字符串偏移位置的逻辑。

```C++
inline size_t my_charpos(const CHARSET_INFO *cs, const char *beg,
                         const char *end, size_t pos) {
  return cs->cset->charpos(cs, beg, end, pos);
}

inline size_t my_charpos(const CHARSET_INFO *cs, const unsigned char *beg,
                         const unsigned char *end, size_t pos) {
  return cs->cset->charpos(cs, pointer_cast<const char *>(beg),
                           pointer_cast<const char *>(end), pos);
}
```

#### `use_mb(...)`：获取当前字符集是否有多字节字符

`ismbchar` 函数是用于检查提供的字符串是否是一个多字节字符序列的逻辑，如果该函数为 `nullptr` 则说明该字符集不支持多字节字符。

```C++
inline bool use_mb(const CHARSET_INFO *cs) {
  return cs->cset->ismbchar != nullptr;
}
```

#### `my_ismbchar(...)`：判断当前字符串是否是多字节序列

Detects whether the given string is a multi-byte sequence.

检测在指针 `str` 到指针 `strend` 之间的字符串是否为多字节序列。

```C++
inline unsigned my_ismbchar(const CHARSET_INFO *cs, const char *str,
                            const char *strend) {
  return cs->cset->ismbchar(cs, str, strend);
}

inline unsigned my_ismbchar(const CHARSET_INFO *cs, const uint8_t *str,
                            const uint8_t *strend) {
  return cs->cset->ismbchar(cs, pointer_cast<const char *>(str),
                            pointer_cast<const char *>(strend));
}
```

#### `my_mbcharlen(...)`：获取以给定字符开头的多字节序列长度

Returns length of multi-byte sequence starting with the given character.

返回以提供字符 `first_byte` 开始的多字节序列的长度。

```C++
inline unsigned my_mbcharlen(const CHARSET_INFO *cs, unsigned first_byte) {
  return cs->cset->mbcharlen(cs, first_byte);
}
```

#### `my_mbcharlen_2(...)`：获取以两个引导字节开始的 GB18030 字符的长度

返回以字符 `first_byte` 和 `second_byte` 引导的 GB18030 字符的长度。

```C++
/**
  Get the length of gb18030 code by the given two leading bytes

  @param[in] cs charset_info
  @param[in] first_byte first byte of gb18030 code
  @param[in] second_byte second byte of gb18030 code
  @return    the length of gb18030 code starting with given two bytes,
             the length would be 2 or 4 for valid gb18030 code,
             or 0 for invalid gb18030 code
*/
inline unsigned my_mbcharlen_2(const CHARSET_INFO *cs, uint8_t first_byte,
                               uint8_t second_byte) {
  return cs->cset->mbcharlen(cs,
                             ((first_byte & 0xFF) << 8) + (second_byte & 0xFF));
}
```

#### `my_mbmaxlenlen(...)`：返回当前字符集用于确定多字节字符长度的最大字节数

Maximum leading bytes of a sequence to determine the length of the multi-byte sequence length.

返回当前字符集用于确定多字节字符长度的最大字节数。如果是 GB18030 编码为返回 2，其他编码返回 1。

```C++
/**
  Get the maximum length of leading bytes needed to determine the length of a
  multi-byte gb18030 code

  @param[in] cs charset_info
  @return    number of leading bytes we need, would be 2 for gb18030
             and 1 for all other charsets
*/
inline unsigned my_mbmaxlenlen(const CHARSET_INFO *cs) {
  return cs->mbmaxlenlen;
}
```

#### `my_ismb1st(...)`：返回当前字节是否可能是多字节字符的引导字节

判断对于当前字符集来说，字节 `leading_byte` 是否可能是多字节序列的引导字节。对于 GB18030 字符集来说，需要 2 个字符才能判断多字节序列的长度，因此我们无法通过一个字节就判断它是否为一个多字节序列。

```C++
/**
  Judge if the given byte is a possible leading byte for a charset.
  For gb18030 whose mbmaxlenlen is 2, we can't determine the length of
  a multi-byte character by looking at the first byte only

  @param[in] cs charset_info
  @param[in] leading_byte possible leading byte
  @return    true if it is, otherwise false
*/
inline bool my_ismb1st(const CHARSET_INFO *cs, unsigned leading_byte) {
  return my_mbcharlen(cs, leading_byte) > 1 ||
         (my_mbmaxlenlen(cs) == 2 && my_mbcharlen(cs, leading_byte) == 0);
}
```

#### `my_caseup_str(...)`：将字符串转换为英文大写格式

Converts the given 0-terminated string to uppercase.

将以 ASCIII 编码 0 为截止符号的字符串转换为英文大写格式。

```C++
inline size_t my_caseup_str(const CHARSET_INFO *cs, char *str) {
  return cs->cset->caseup_str(cs, str);
}
```

#### `my_casedn_str(...)`：将字符串转换为英文小写格式

Converts the given 0-terminated string to lowercase.

将以 ASCIII 编码 0 为截止符号的字符串转换为英文大写格式。

```C++
inline size_t my_casedn_str(const CHARSET_INFO *cs, char *str) {
  return cs->cset->casedn_str(cs, str);
}
```

#### `my_strntol(...)`：将以 `str` 指针开始，长度为 `length` 的字符串转换为 long 类型整数

```C++
inline long my_strntol(const CHARSET_INFO *cs, const char *str, size_t length,
                       int base, const char **end, int *err) {
  return cs->cset->strntol(cs, str, length, base, end, err);
}
```

#### `my_strntoul(...)`：将以 `str` 指针开始，长度为 `length` 的字符串转换为无符号 long 类型整数

```C++
inline unsigned long my_strntoul(const CHARSET_INFO *cs, const char *str,
                                 size_t length, int base, const char **end,
                                 int *err) {
  return cs->cset->strntoul(cs, str, length, base, end, err);
}
```

#### `my_strntoll(...)`：将以 `str` 指针开始，长度为 `length` 的字符串转换为 `int64_t` 类型整数

```C++
inline int64_t my_strntoll(const CHARSET_INFO *cs, const char *str,
                           size_t length, int base, const char **end,
                           int *err) {
  return cs->cset->strntoll(cs, str, length, base, end, err);
}
```

#### `my_strntoull(...)`：将以 `str` 指针开始，长度为 `length` 的字符串转换为无符号的 `uint64_t` 类型整数

```C++
inline uint64_t my_strntoull(const CHARSET_INFO *cs, const char *str,
                             size_t length, int base, const char **end,
                             int *err) {
  return cs->cset->strntoull(cs, str, length, base, end, err);
}
```

#### `my_strntod(...)`：将以 `str` 指针开始，长度为 `length` 的字符串转换为 `double` 类型浮点数

```C++
inline double my_strntod(const CHARSET_INFO *cs, const char *str, size_t length,
                         const char **end, int *err) {
  return cs->cset->strntod(cs, str, length, end, err);
}
```





