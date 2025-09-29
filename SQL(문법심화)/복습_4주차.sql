-- 1. 정규 표현식
-- ^: 문자열의 시작 | ex) ^S: S로 시작
-- $: 문자열의 끝 | ex) 0$: 0으로 끝
-- .: 아무 문자 1개 | ex) S.0: S와 0 사이에 아무 문자 1개
-- *: 앞 문자가 0회 이상 반복 | ex) a*b: b, ab, aab, ...
-- +: 앞 문자가 1회 이상 반복 | ex) a+b: ab, aab, aaab, ...
-- ?: 앞 문자가 0회 또는 1회 | ex) a?b: b, ab
-- []: 괄호 안의 문자 중 하나 | ex) [abc]: a, b, c
-- [^ ]: 괄호 안의 문자를 제외 | ex) [^0-9]: 숫자가 아닌 문자
-- {n}: 앞 패턴이 n회 반복 | ex) [0-9]{2}: 숫자 2개

-- 정규표현식 응용: addressLine1 컬럼에서 [숫자2개 + ,]조합으로 시작하는 데이터만 추출
SELECT 
    addressLine1
FROM
    customers
WHERE
    addressLine1 REGEXP '^[0-9]{2},'; 

-- 참고사항
-- products 테이블 buyPrice: 공급업체에서 사들인 원가
-- products 테이블 MSRP: 소비자 권장 가격
-- orderdetails 테이블 priceEach(개당 실제 판매 가격) * quantityOrdered(제품 수량): 해당 판매 건의 총 수익(매출)

-- 2. KPI 계산 공식
-- 마진율: 총이익을 총매출로 나눈 비율
-- SUM(quantityOrdered * (priceEach - buyPrice)) / SUM(quantityOrdered * priceEach)
-- 권장가 대비 할인율: 총할인액을 총권장가 함계로 나눈 비율
-- SUM(quantityOrdered * (MSRP - priceEach)) / SUM(quantityOrdered * MSRP)
-- 손익 플래그: 총이익이 0보다 작은이 확인하는 플래그
-- SUM(quantityOrdered * (priceEach - buyPrice)) < 0 THEN 1 ELSE 0

--3. KPI 쿼리
-- 3.1 Porsche 차량 월별 마진 계산: 총 이익과 마진율을 계산
select p.productCode, p.productName,
	date_format(o.orderDate, '%Y-%m') as YM,
	sum(od.quantityOrdered * (od.priceEach - p.buyPrice)) / sum(od.quantityOrdered * od.priceEach) as marginRate
from products as p
join orderdetails as od using(productCode)
join orders as o using(orderNumber)
where p.productName LIKE '%Porsche%' and o.status not in ('Cancelled')
group by YM, p.productCode, p.productName;

-- 3.2 Prosche 차량 월별 권장가 대비 실제 판매가 할인율 계산: MSRP 대비 할인율 계산
select p.productCode, p.productName,
	date_format(o.orderDate, '%Y-%m') as YM,
	sum(od.quantityOrdered * (p.MSRP - od.priceEach)) / sum(od.quantityOrdered * p.MSRP) as discount_vs_msrp
from products as p
join orderdetails as od using(productCode)
join orders as o using(orderNumber)
group by YM, p.productCode, p.productName;

-- 3.3 Prosche 차량 월별 마진의 손실 여부?: 손익 플래그를 통해 손해를 보고 판매한 경우가 있는지를 판단
select p.productCode, p.productName,
	date_format(o.orderDate, '%Y-%m') as YM,
	sum(od.quantityOrdered * (od.priceEach - p.buyPrice)) as total_gross_profit,
case 
	when sum(od.quantityOrdered * (od.priceEach - p.buyPrice)) < 0 then 1 else 0 end as is_negative
from products as p
join orderdetails as od using(productCode)
join orders as o using(orderNumber)
where p.productName LIKE '%Porsche%' and o.status not in ('Cancelled')
group by YM, p.productCode, p.productName;

-- 3.4 임직원 별로의 가격에 대한 손실 여부 판단: 수업에서는 다루지 않음

-- 4. 3번 내용을 한 테이블로 합치기
with Prosche_Sales_by_month as (
	select p.productCode, p.productName,
	date_format(o.orderDate, '%Y-%m') as YM,
	sum(od.quantityOrdered * (od.priceEach - p.buyPrice)) as total_gross_profit, -- 총이익
    sum(od.quantityOrdered * od.priceEach) as total_sales, -- 총매출
    sum(od.quantityOrdered * p.MSRP) as total_MSRP_value, -- 소비자 권장가 총 합계
    sum(od.quantityOrdered * (p.MSRP - od.priceEach)) as total_discount_value -- 총 할인액
from products as p
join orderdetails as od using(productCode)
join orders as o using(orderNumber)
where p.productName LIKE '%Porsche%' and o.status not in ('Cancelled')
group by YM, p.productCode, p.productName)
select YM, productCode, productName,

-- 마진율(총이익을 총매출로 나눈 비율) 계산
-- SUM(quantityOrdered * (priceEach - buyPrice)) / SUM(quantityOrdered * priceEach)
case
	when total_sales = 0 then null
    else round((total_gross_profit / total_sales) * 100, 2)
end as margin_pct, 

-- 권장가 대비 할인율(총할인액을 총권장가 함계로 나눈 비율)
-- SUM(quantityOrdered * (MSRP - priceEach)) / SUM(quantityOrdered * MSRP)
case
	when total_MSRP_value = 0 then null
    else round((total_discount_value / total_MSRP_value) * 100, 2) 
end as discount_vs_msrp,

-- 손익 플래그(총이익이 0보다 작은이 확인하는 플래그)
-- SUM(quantityOrdered * (priceEach - buyPrice)) < 0 THEN 1 ELSE 0
case 
	when total_gross_profit < 0 then 1 else 0
end as is_negative
from Prosche_Sales_by_month;

select * from customers;