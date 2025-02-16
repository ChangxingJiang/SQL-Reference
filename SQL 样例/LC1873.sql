SELECT
    employee_id,
    IF(employee_id % 2 = 1 AND name NOT REGEXP '^M', salary, 0) AS bonus
FROM
    employees
ORDER BY
    employee_id;
