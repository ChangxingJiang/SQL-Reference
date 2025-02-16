SELECT
    class
FROM
    (SELECT
        class, COUNT(student) AS num
    FROM
        courses
    GROUP BY class) AS temp_table
WHERE
    num >= 5
;

SELECT
    class
FROM
    courses
GROUP BY class
HAVING COUNT(student) >= 5
;
