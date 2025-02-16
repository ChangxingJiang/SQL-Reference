select ids as id, cnt as num
from
(
select ids, count(*) as cnt
   from
   (
        select requester_id as ids from RequestAccepted
        union all
        select accepter_id from RequestAccepted
    ) as tbl1
   group by ids
   ) as tbl2
order by cnt desc
limit 1
;
