select * from orders;

-- 월 별로 비교 분석
-- 2003-01 / 2003-02 / 2002-03 ... 2003-12
SELECT 
	DATE_FORMAT(orderDate, '%Y-%m') as ym,
    CASE
		WHEN DATEDIFF(shippedDate, orderDate) <= 0 THEN 'D'
		WHEN DATEDIFF(shippedDate, orderDate) <= 1 THEN 'D+1'
		WHEN DATEDIFF(shippedDate, orderDate) <= 2 THEN 'D+2'
		WHEN DATEDIFF(shippedDate, orderDate) <= 3 THEN 'D+3'
		WHEN DATEDIFF(shippedDate, orderDate) <= 4 THEN 'D+4'
		WHEN DATEDIFF(shippedDate, orderDate) <= 5 THEN 'D+5'
		WHEN DATEDIFF(shippedDate, orderDate) <= 6 THEN 'D+6'
		WHEN DATEDIFF(shippedDate, orderDate) <= 7 THEN 'D+7'
		ELSE 'D_OVER'
	END as delay_bucket,
    COUNT(*) as cnt
FROM orders
GROUP BY ym, delay_bucket
ORDER BY ym, delay_bucket;
select * from orders;

-- 월별로 집계가 필요하다.
-- date_format(order_date, '%Y-%m') as ym

-- 날짜에 대한 delay 계산
-- datediff(shippedDate, orderdate) as delay_days


-- 지금까지의 위 테이블이 우리에게 던져주는 값은
-- ym       delay_days
-- 2003-02     1

-- delay_days 를 0 D, 1이면 D+1 .. D+7
-- case when datediff(ship, order) <=0 then 'D'

-- 내가 원하는 테이블 구조는 여기까지 왔어!
-- ym      / delay_buket
-- 2003-03      D

-- 그런데 내가 원하는 인스턴스 값이 x
-- 2003-03 D 몇 개?
-- 2003-05      D+1

-- ym X D 버킷 
-- count 하자!
-- count()
-- group by ym, delay_bucket

-- 내가 원하는 테이블 구조
-- ym     dealy_bucket cnt
-- 2003-01    D+1       10
-- 2003-01    D+2       5
-- 2003-02    D+1       7

-- 피벗 한다.
-- sum(case when)


-- ym 행열전환(pivot)
select 
	delay_bucket,
    sum(case when ym ='2003-01' then cnt else 0 end) as '2003-01', -- sum(case when) -> 특정 월만 피벗
    sum(case when ym ='2003-02' then cnt else 0 end) as '2003-02',
    sum(case when ym ='2003-03' then cnt else 0 end) as '2003-03',
    sum(case when ym ='2003-04' then cnt else 0 end) as '2003-04',
    sum(case when ym ='2003-05' then cnt else 0 end) as '2003-05',
    sum(case when ym ='2003-06' then cnt else 0 end) as '2003-06',
    sum(case when ym ='2003-07' then cnt else 0 end) as '2003-07',
    sum(case when ym ='2003-08' then cnt else 0 end) as '2003-08',
    sum(case when ym ='2003-09' then cnt else 0 end) as '2003-09',
    sum(case when ym ='2003-10' then cnt else 0 end) as '2003-10',
    sum(case when ym ='2003-11' then cnt else 0 end) as '2003-11',
    sum(case when ym ='2003-12' then cnt else 0 end) as '2003-12'
from(select 
		date_format(orderDate, '%Y-%m') as ym, -- 날짜함수 date_format 연-월
		case
			when datediff(shippedDate, orderDate) <=0 then'D' -- datediff 배송 지연의 값을 넣음
			when datediff(shippedDate, orderDate) =1 then'D+1'
			when datediff(shippedDate, orderDate) =2 then'D+2'
			when datediff(shippedDate, orderDate) =3 then'D+3'
			when datediff(shippedDate, orderDate) =4 then'D+4'
			when datediff(shippedDate, orderDate) =5 then'D+5'
			when datediff(shippedDate, orderDate) =6 then'D+6'
			when datediff(shippedDate, orderDate) =7 then'D+7'
			else 'D++'
		end as delay_bucket,
		count(*) as cnt
	from orders
    where shippedDate is not null
	group by ym, delay_bucket -- group by cnt 카운팅 
    ) as t
    group by delay_bucket
    order by delay_bucket;


-- <문자열 함수>
select * from orders;

-- REPLACE('원본 문자열', '찾을 문자', '바꿀 문자')
select replace(replace(replace(customerName,' ', ''),',',''),'+','') 
from customers;

-- SUBSTRING('문자열', '시작위치', '추출할 개수')
select substring(orderDate, 1,7) 
from orders;

-- CONCAT(문자열1, 문자열2, [문자열3, ...]): 여러 문자열을 하나로 결합
select concat_ws('/', contactFirstName, contactLastName) 
from customers;

