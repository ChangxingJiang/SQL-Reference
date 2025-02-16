SELECT a.person_name
FROM Queue a, Queue b
WHERE a.turn >= b.turn
GROUP BY a.person_id HAVING SUM(b.weight) <= 1000
ORDER BY a.turn DESC
LIMIT 1;

SELECT a.person_name
FROM (
	SELECT person_name, @pre := @pre + weight AS weight
	FROM Queue, (SELECT @pre := 0) tmp
	ORDER BY turn
) a
WHERE a.weight <= 1000
ORDER BY a.weight DESC
LIMIT 1;
