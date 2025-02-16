select Name
from (
  select Manager.Name as Name, count(Report.Id) as cnt
  from
  Employee as Manager join Employee as Report
  on Manager.Id = Report.ManagerId
  group by Manager.Id
) as ReportCount
where cnt >= 5;

select Manager.Name as Name
from
Employee as Manager join Employee as Report
on Manager.Id = Report.ManagerId
group by Manager.Id
having count(Report.Id) >= 5;

select Employee.Name as Name
from (
  select ManagerId as Id
  from Employee
  group by ManagerId
  having count(Id) >= 5
) as Manager join Employee
on Manager.Id = Employee.Id;
