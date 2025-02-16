SELECT
  S.score,
  DENSE_RANK() OVER (
    ORDER BY
      S.score DESC
  ) AS 'rank'
FROM
  Scores S;

SELECT
  S1.score,
  (
    SELECT
      COUNT(DISTINCT S2.score)
    FROM
      Scores S2
    WHERE
      S2.score >= S1.score
  ) AS 'rank'
FROM
  Scores S1
ORDER BY
  S1.score DESC;

SELECT
  S.id AS S_ID,
  S.score AS S_Score,
  T.id AS T_ID,
  T.score AS T_Score
FROM
  Scores S
  INNER JOIN Scores T ON S.score <= T.score
ORDER BY
  S.id,
  T.score;
