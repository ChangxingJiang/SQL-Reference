SELECT user_id, name, mail
FROM Users
-- 请注意，我们还转义了`@`字符，因为它在某些正则表达式中具有特殊意义
WHERE mail REGEXP '^[a-zA-Z][a-zA-Z0-9_.-]*\\@leetcode\\.com$';
