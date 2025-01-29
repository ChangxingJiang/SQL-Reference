目录文档：[MySQL 源码｜源码剖析文档目录](https://zhuanlan.zhihu.com/p/714761054)

源码位置（版本 = MySQL 8.0.37）：[sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy)；[sql/lexer_yystype.h](https://github.com/mysql/mysql-server/blob/trunk/sql/lexer_yystype.h)；[sql/parser_yystype.h](https://github.com/mysql/mysql-server/blob/trunk/sql/parser_yystype.h)

前置文档：

- [MySQL 源码｜33 - 语法解析：bison 基础语法规则](https://zhuanlan.zhihu.com/p/714779214)

> 在梳理 MySQL 语法解析逻辑时，与其在梳理每个语义组时候再查找该语义组的返回值，不如在梳理之前就先统一整理所有语义组的返回值类型。

---

#### `Lexer_yystype` 联合体

在 [sql/lexer_yystype.h](https://github.com/mysql/mysql-server/blob/trunk/sql/lexer_yystype.h) 文件中，定义了联合体 `Lexer_yystype`，其中不同类型的成员将在 [sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy) 文件中作为不同语义组的返回值使用。联合体源码如下：

```C++
union Lexer_yystype {
  LEX_STRING lex_str;
  LEX_SYMBOL keyword;
  const CHARSET_INFO *charset;
  PT_hint_list *optimizer_hints;
  LEX_CSTRING hint_string;
};
```

#### `MY_SQL_PARSER_STYPE` 联合体

在 [sql/parser_yystype.h](https://github.com/mysql/mysql-server/blob/trunk/sql/parser_yystype.h) 文件中，定义了联合体 `MY_SQL_PARSER_STYPE`，其中不同类型的成员将在 [sql/sql_yacc.yy](https://github.com/mysql/mysql-server/blob/trunk/sql/sql_yacc.yy) 文件中作为不同语义组的返回值使用，而 `Lexer_yystype` 联合体则是 `MY_SQL_PARSER_STYPE` 联合体中 `lexer` 成员的类型。

例如：

- Bison 语法 `%type <num> opt_start_transaction_option_list` 定义了语义组 `opt_start_transaction_option_list` 的返回值类型为 `MY_SQL_PARSER_STYPE` 联合体中成员 `num` 的类型 `int`。
- Bison 语法 `%type <lexer.lex_str> IDENT` 定义了语义组 `IDENT` 的返回值类型为 `Lexer_yystype` 联合体 `lex_str` 成员的类型 `LEX_STRING`

联合体源码如下：

```C++
union MY_SQL_PARSER_STYPE {
  Lexer_yystype lexer;  // terminal values from the lexical scanner
  /*
    Hint parser section (sql_hints.yy)
  */
  opt_hints_enum hint_type;
  PT_hint *hint;
  PT_hint_list *hint_list;
  Hint_param_index_list hint_param_index_list;
  Hint_param_table hint_param_table;
  Hint_param_table_list hint_param_table_list;

  /*
    Main parser section (sql_yacc.yy)
  */
  int num;
  ulong ulong_num;
  ulonglong ulonglong_number;
  LEX_CSTRING lex_cstr;
  LEX_STRING *lex_str_ptr;
  Table_ident *table;
  char *simple_string;
  Item *item;
  Item_num *item_num;
  mem_root_deque<Item *> *item_list;
  List<String> *string_list;
  String *string;
  Mem_root_array<Table_ident *> *table_list;
  udf_func *udf;
  LEX_USER *lex_user;
  List<LEX_USER> *user_list;
  LEX_MFA *lex_mfa;
  struct {
    LEX_MFA *mfa2, *mfa3;
  } lex_mfas;
  sys_var_with_base variable;
  enum_var_type var_type;
  keytype key_type;
  ha_key_alg key_alg;
  enum row_type row_type;
  ha_rkey_function ha_rkey_mode;
  enum_ha_read_modes ha_read_mode;
  enum_tx_isolation tx_isolation;
  const char *c_str;
  struct {
    const CHARSET_INFO *charset;
    bool force_binary;
  } charset_with_opt_binary;
  struct {
    const char *length;
    const char *dec;
  } precision;
  Cast_type cast_type;
  thr_lock_type lock_type;
  interval_type interval, interval_time_st;
  enum_mysql_timestamp_type date_time_type;
  Query_block *query_block;
  chooser_compare_func_creator boolfunc2creator;
  sp_condition_value *spcondvalue;
  struct {
    int vars, conds, hndlrs, curs;
  } spblock;
  sp_name *spname;
  LEX *lex;
  sp_head *sphead;
  index_hint_type index_hint;
  enum_filetype filetype;
  enum_source_type source_type;
  fk_option m_fk_option;
  enum_yes_no_unknown m_yes_no_unk;
  enum_condition_item_name da_condition_item_name;
  Diagnostics_information::Which_area diag_area;
  Diagnostics_information *diag_info;
  Statement_information_item *stmt_info_item;
  Statement_information_item::Name stmt_info_item_name;
  List<Statement_information_item> *stmt_info_list;
  Condition_information_item *cond_info_item;
  Condition_information_item::Name cond_info_item_name;
  List<Condition_information_item> *cond_info_list;
  bool is_not_empty;
  Set_signal_information *signal_item_list;
  enum_trigger_order_type trigger_action_order_type;
  struct {
    enum_trigger_order_type ordering_clause;
    LEX_CSTRING anchor_trigger_name;
  } trg_characteristics;
  Index_hint *key_usage_element;
  List<Index_hint> *key_usage_list;
  PT_subselect *subselect;
  PT_item_list *item_list2;
  PT_order_expr *order_expr;
  PT_order_list *order_list;
  Limit_options limit_options;
  Query_options select_options;
  PT_limit_clause *limit_clause;
  Parse_tree_node *node;
  enum olap_type olap_type;
  PT_group *group;
  PT_window_list *windows;
  PT_window *window;
  PT_frame *window_frame;
  enum_window_frame_unit frame_units;
  PT_borders *frame_extent;
  PT_border *bound;
  PT_exclusion *frame_exclusion;
  enum_null_treatment null_treatment;
  enum_from_first_last from_first_last;
  Item_string *item_string;
  PT_order *order;
  PT_table_reference *table_reference;
  PT_joined_table *join_table;
  PT_joined_table_type join_type;
  PT_set_scoped_system_variable *option_value_following_option_type;
  PT_option_value_no_option_type *option_value_no_option_type;
  PT_option_value_list_head *option_value_list;
  PT_start_option_value_list *start_option_value_list;
  PT_transaction_access_mode *transaction_access_mode;
  PT_isolation_level *isolation_level;
  PT_transaction_characteristics *transaction_characteristics;
  PT_start_option_value_list_following_option_type
      *start_option_value_list_following_option_type;
  PT_set *set;
  Line_separators line_separators;
  Field_separators field_separators;
  PT_into_destination *into_destination;
  PT_select_var *select_var_ident;
  PT_select_var_list *select_var_list;
  Mem_root_array_YY<PT_table_reference *> table_reference_list;
  Item_param *param_marker;
  PTI_text_literal *text_literal;
  PT_query_expression *query_expression;
  PT_derived_table *derived_table;
  PT_query_expression_body *query_expression_body;
  struct {
    PT_query_expression_body *body;
    bool is_parenthesized;
  } query_expression_body_opt_parens;
  PT_query_primary *query_primary;
  PT_subquery *subquery;
  PT_key_part_specification *key_part;

  XID *xid;
  xa_option_words xa_option_type;
  struct {
    Item *column;
    Item *value;
  } column_value_pair;
  struct {
    PT_item_list *column_list;
    PT_item_list *value_list;
  } column_value_list_pair;
  struct {
    PT_item_list *column_list;
    PT_insert_values_list *row_value_list;
  } column_row_value_list_pair;
  struct {
    PT_item_list *column_list;
    PT_query_expression_body *insert_query_expression;
  } insert_query_expression;
  struct {
    Item *offset;
    Item *default_value;
  } lead_lag_info;
  PT_insert_values_list *values_list;
  Parse_tree_root *top_level_node;
  Table_ident *table_ident;
  Mem_root_array_YY<Table_ident *> table_ident_list;
  delete_option_enum opt_delete_option;
  PT_alter_instance *alter_instance_cmd;
  PT_create_index_stmt *create_index_stmt;
  PT_table_constraint_def *table_constraint_def;
  List<PT_key_part_specification> *index_column_list;
  struct {
    LEX_STRING name;
    PT_base_index_option *type;
  } index_name_and_type;
  PT_base_index_option *index_option;
  Mem_root_array_YY<PT_base_index_option *> index_options;
  Mem_root_array_YY<LEX_STRING> lex_str_list;
  bool visibility;
  PT_with_clause *with_clause;
  PT_with_list *with_list;
  PT_common_table_expr *common_table_expr;
  Create_col_name_list simple_ident_list;
  PT_partition_option *partition_option;
  Mem_root_array<PT_partition_option *> *partition_option_list;
  PT_subpartition *sub_part_definition;
  Mem_root_array<PT_subpartition *> *sub_part_list;
  PT_part_value_item *part_value_item;
  Mem_root_array<PT_part_value_item *> *part_value_item_list;
  PT_part_value_item_list_paren *part_value_item_list_paren;
  Mem_root_array<PT_part_value_item_list_paren *> *part_value_list;
  PT_part_values *part_values;
  struct {
    partition_type type;
    PT_part_values *values;
  } opt_part_values;
  PT_part_definition *part_definition;
  Mem_root_array<PT_part_definition *> *part_def_list;
  List<char> *name_list;  // TODO: merge with string_list
  enum_key_algorithm opt_key_algo;
  PT_sub_partition *opt_sub_part;
  PT_part_type_def *part_type_def;
  PT_partition *partition_clause;
  PT_add_partition *add_partition_rule;
  struct {
    decltype(HA_CHECK_OPT::flags) flags;
    decltype(HA_CHECK_OPT::sql_flags) sql_flags;
  } mi_type;
  enum_drop_mode opt_restrict;
  Ternary_option ternary_option;
  PT_create_table_option *create_table_option;
  Mem_root_array<PT_create_table_option *> *create_table_options;
  Mem_root_array<PT_ddl_table_option *> *space_separated_alter_table_opts;
  On_duplicate on_duplicate;
  PT_column_attr_base *col_attr;
  column_format_type column_format;
  ha_storage_media storage_media;
  Mem_root_array<PT_column_attr_base *> *col_attr_list;
  Virtual_or_stored virtual_or_stored;
  ulong field_option;  // 0 or combinations of UNSIGNED_FLAG and ZEROFILL_FLAG
  Int_type int_type;
  PT_type *type;
  Numeric_type numeric_type;
  struct {
    const char *expr_start;
    Item *expr;
  } sp_default;
  PT_field_def_base *field_def;
  struct {
    fk_option fk_update_opt;
    fk_option fk_delete_opt;
  } fk_options;
  fk_match_opt opt_match_clause;
  List<Key_part_spec> *reference_list;
  struct {
    Table_ident *table_name;
    List<Key_part_spec> *reference_list;
    fk_match_opt fk_match_option;
    fk_option fk_update_opt;
    fk_option fk_delete_opt;
  } fk_references;
  PT_column_def *column_def;
  PT_table_element *table_element;
  Mem_root_array<PT_table_element *> *table_element_list;
  struct {
    Mem_root_array<PT_create_table_option *> *opt_create_table_options;
    PT_partition *opt_partitioning;
    On_duplicate on_duplicate;
    PT_query_expression_body *opt_query_expression;
  } create_table_tail;
  Lock_strength lock_strength;
  Locked_row_action locked_row_action;
  PT_locking_clause *locking_clause;
  PT_locking_clause_list *locking_clause_list;
  Mem_root_array<PT_json_table_column *> *jtc_list;
  // ON EMPTY/ON ERROR response for JSON_TABLE and JSON_VALUE.
  struct Json_on_response {
    Json_on_response_type type;
    Item *default_string;
  } json_on_response;
  struct {
    Json_on_response error;
    Json_on_response empty;
  } json_on_error_or_empty;
  PT_json_table_column *jt_column;
  enum_jt_column jt_column_type;
  struct {
    LEX_STRING wild;
    Item *where;
  } wild_or_where;
  Show_cmd_type show_cmd_type;
  struct Histogram_param {
    int num_buckets;
    LEX_STRING data;
  } histogram_param;
  struct {
    Sql_cmd_analyze_table::Histogram_command command;
    List<String> *columns;
    Histogram_param *param;
  } histogram;
  Acl_type acl_type;
  Mem_root_array<LEX_CSTRING> *lex_cstring_list;
  PT_role_or_privilege *role_or_privilege;
  Mem_root_array<PT_role_or_privilege *> *role_or_privilege_list;
  enum_order order_direction;
  Alter_info::enum_with_validation with_validation;
  PT_alter_table_action *alter_table_action;
  PT_alter_table_standalone_action *alter_table_standalone_action;
  Alter_info::enum_alter_table_algorithm alter_table_algorithm;
  Alter_info::enum_alter_table_lock alter_table_lock;
  struct Algo_and_lock {
    Enum_parser<Alter_info::enum_alter_table_algorithm,
                Alter_info::ALTER_TABLE_ALGORITHM_DEFAULT>
        algo;
    Enum_parser<Alter_info::enum_alter_table_lock,
                Alter_info::ALTER_TABLE_LOCK_DEFAULT>
        lock;
    void init() {
      algo.init();
      lock.init();
    }
  } opt_index_lock_and_algorithm;
  struct Algo_and_lock_and_validation {
    Enum_parser<Alter_info::enum_alter_table_algorithm,
                Alter_info::ALTER_TABLE_ALGORITHM_DEFAULT>
        algo;
    Enum_parser<Alter_info::enum_alter_table_lock,
                Alter_info::ALTER_TABLE_LOCK_DEFAULT>
        lock;
    Enum_parser<Alter_info::enum_with_validation,
                Alter_info::ALTER_VALIDATION_DEFAULT>
        validation;
    void init() {
      algo.init();
      lock.init();
      validation.init();
    }
    void merge(const Algo_and_lock_and_validation &x) {
      algo.merge(x.algo);
      lock.merge(x.lock);
      validation.merge(x.validation);
    }
  } algo_and_lock_and_validation;
  struct {
    Algo_and_lock_and_validation flags;
    Mem_root_array<PT_ddl_table_option *> *actions;
  } alter_list;
  struct {
    Algo_and_lock_and_validation flags;
    PT_alter_table_standalone_action *action;
  } standalone_alter_table_action;
  PT_assign_to_keycache *assign_to_keycache;
  Mem_root_array<PT_assign_to_keycache *> *keycache_list;
  PT_adm_partition *adm_partition;
  PT_preload_keys *preload_keys;
  Mem_root_array<PT_preload_keys *> *preload_list;
  PT_alter_tablespace_option_base *ts_option;
  Mem_root_array<PT_alter_tablespace_option_base *> *ts_options;
  struct {
    resourcegroups::platform::cpu_id_t start;
    resourcegroups::platform::cpu_id_t end;
  } vcpu_range_type;
  Mem_root_array<resourcegroups::Range> *resource_group_vcpu_list_type;
  Value_or_default<int> resource_group_priority_type;
  Value_or_default<bool> resource_group_state_type;
  bool resource_group_flag_type;
  resourcegroups::Type resource_group_type;
  Mem_root_array<ulonglong> *thread_id_list_type;
  Explain_format_type explain_format_type;
  struct {
    Explain_format_type explain_format_type;
    bool is_analyze;
    bool is_explicit;
    LEX_STRING explain_into_variable_name;
  } explain_options_type;
  struct {
    Item *set_var;
    Item *set_expr;
    String *set_expr_str;
  } load_set_element;
  struct {
    PT_item_list *set_var_list;
    PT_item_list *set_expr_list;
    List<String> *set_expr_str_list;
  } load_set_list;
  ts_alter_tablespace_type alter_tablespace_type;
  Sql_cmd_srs_attributes *sql_cmd_srs_attributes;
  struct {
    LEX_CSTRING table_alias;
    Create_col_name_list *column_list;
  } insert_update_values_reference;
  my_thread_id query_id;
  Bipartite_name bipartite_name;
  Set_operator query_operator;
  PT_install_component_set_element *install_component_set_element;
  List<PT_install_component_set_element> *install_component_set_list;
  struct {
    Parse_tree_root *statement;
    LEX_CSTRING schema_name_for_explain;
  } explainable_stmt;
};
```

后续在介绍每个语义组时，会逐个梳理返回值的类型。



