select customers.name as 'Customers'
from customers
where customers.id not in
(
    select customerid from orders
);

SELECT name AS 'Customers'
FROM Customers
LEFT JOIN Orders ON Customers.Id = Orders.CustomerId
WHERE Orders.CustomerId IS NULL;
