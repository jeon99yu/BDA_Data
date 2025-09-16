select * from customers;
select * from orders;
select * from orderdetails;
select * from products;

-- SQL 기초 문법 복습
-- 국가별 고객의 수 
-- 고객별 주문 수

select * from customers;

select
	count(customerNumber),
    count(distinct customerNumber),
    count(*)
from customers
group by 
	country;
    
-- customer table
-- 만약 중복이 있는 테이블?


-- 고객별 주문 수
select 
	count(orderNumber),
    count(distinct orderNumber),
	count(*)
from 
	orders
group by 
	orderNumber;

 select * from orders;

-- 고객별로의 주문수 -> 제대로 질문에 답을 하면?

select 
	count(*),
    count(customerNumber),
    count(distinct customerNumber)
from
	orders
group by customerNumber;

-- 어떤 이유로 왜 값이 차이가 나는가!?
select * from orders
limit 5;
-- 중복 제거 customerNumber 수가 차이가 존재한다.
-- 중복된 값이 존재한다.
-- 고객이 여러 개 주문할 수 있다.

select * from orders
limit 5;


-- 검증의 주문의 수 1개 이상인 리스트 뽑는 쿼리 
select 
	customerNumber,
    count(customerNumber)
from 
	orders
group by 
	customerNumber
having count(customerNumber)> 1;
    
select * from orders
where customerNumber =124;

-- 서브쿼리를 통해서 중복이 있는 고객의 리스트만 뽑기!

-- select 
-- 	customerNumber
-- from 
-- 	orders
-- group by 
-- 	customerNumber
-- having count(customerNumber)> 1;


-- 제품별 매출(orderdetails q * p = total)
-- od productCode , product productCode
-- join 둘의 키값으로 join
-- join 왼쪽 오른쪽 기준 
-- product 코드별 
select 
	p.productCode,
    p.productName,
    sum(od.quantityOrdered * od.priceEach) as total_revenue
from 
	products as p 
join orderdetails as od on p.productCode = od.productCode
group by p.productCode, p.productName;

-- 고객별 매출 (orderdetails q * p = total)
-- 직접 진행해 보기!

-- 임직원별 -> 고객 주문 매출을 집계할 수 있음
-- 임직원들 중에서 어떤 임직원이 가장 높은 매출을 만들었는지!? 

select 
	e.employeeNumber,
    e.lastName,
    e.firstName,
    -- c.customerNumber,
    -- o.orderNumber,
    sum(od.priceEach * od.quantityOrdered)
    -- avg(od.priceEach * od.quantityOrdered)
    from 
	employees as e
join customers as c on e.employeeNumber = c.salesRepEmployeeNumber
join orders as o on o.customerNumber = c.customerNumber
join orderdetails as od on o.orderNumber = od.orderNumber
group by e.employeeNumber, e.lastName, e.firstName
order by sum(od.priceEach * od.quantityOrdered) desc ;

select * from customers;
select * from orders;
select * from orderdetails;

