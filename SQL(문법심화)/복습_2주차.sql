select * from customers;

/*
CASE WHEN과 IF문은 특정 조건에 따라 다른 값을 반환할 때 유용합니다.
IF(condition, value_if_true, value_if_false) 형태로 사용됩니다.
*/

-- 고객의 신용 한도(creditLimit)에 따라 'VVIP'와 'VIP' 등급을 부여합니다.
-- 신용 한도가 50000 이상인 고객은 'VVIP'로, 그렇지 않은 고객은 'VIP'로 분류합니다.
select
    customerName,
    customerNumber,
    if(creditLimit >= 50000, 'VVIP', 'VIP') as vip_seg
from
    customers;

/*
CASE 문을 사용하여 여러 조건을 기준으로 데이터를 분류할 수 있습니다.
예를 들어, 가격대를 'High', 'Medium', 'Low' 세 가지로 나누는 경우입니다.
*/
select
    orderNumber,
    case
        when priceEach >= 100 then 'High'
        when priceEach between 30 and 99 then 'Medium'
        else 'Low'
    end as price_seg
from orderdetails;

/*
CTE(Common Table Expression)와 CASE 문을 함께 활용하면
특정 조건에 부합하는 데이터의 개수를 효율적으로 계산할 수 있습니다.
조건 충족 시 1, 아닐 시 0을 반환하게 한 뒤 합산(SUM)하면, 해당 조건의 총 개수가 됩니다.
예를 들어, 'High' 카테고리에 해당하는 주문의 총 건수를 구할 수 있습니다.
*/

-- 각 가격대('High', 'Medium', 'Low')에 해당하는 주문 상세 건수를 집계합니다.
select
    sum(case when priceEach >= 100 then 1 else 0 end) as cnt_high,
    sum(case when priceEach between 30 and 99 then 1 else 0 end) as cnt_medium,
    sum(case when priceEach < 30 then 1 else 0 end) as cnt_low
from orderdetails;

/*
-- 월별 구매자 코호트(cohort) 분석 등에 서브쿼리나 CTE를 활용할 수 있습니다.
-- 아래 쿼리는 집계 함수(SUM)와 GROUP BY를 함께 사용해야 합니다.
-- MySQL의 'only_full_group_by' SQL 모드에서는 GROUP BY 절에 명시되지 않은 컬럼을
-- SELECT 절에서 집계 함수 없이 사용하면 에러(Error Code: 1140)가 발생할 수 있습니다.
*/

-- 월별로 주문 총액을 기준으로 'High', 'Medium', 'Low' 등급의 주문 건수를 계산합니다.
-- 주문 총액이 50000 이상이면 'High', 3000에서 10000 사이면 'Medium', 3000 미만이면 'Low'로 분류합니다.
-- `orderdetails` 테이블에는 주문일 정보가 없으므로, `orders` 테이블과 조인하여 월별 데이터를 추출합니다.
select
    date_format(o.orderDate, '%Y-%m') as ym,
    sum(case when order_total >= 50000 then 1 else 0 end) as cnt_high,
    sum(case when order_total between 3000 and 10000 then 1 else 0 end) as cnt_medium,
    sum(case when order_total < 3000 then 1 else 0 end) as cnt_low
from
    orders as o
join
(
    -- 서브쿼리를 사용하여 주문 번호(orderNumber)별로 총 주문액(order_total)을 계산합니다.
    select
        orderNumber,
        sum(priceEach * quantityOrdered) as order_total
    from
        orderdetails
    group by
        orderNumber
) as oa
on oa.orderNumber = o.orderNumber
group by ym -- 연-월(ym) 기준으로 그룹화
order by ym; -- 연-월(ym) 기준으로 정렬

### 날짜 관련 함수 활용 예시

-- WITH 절을 사용하여 8월에 발생한 주문 데이터만 'od_8'이라는 임시 테이블로 정의합니다.
with od_8 as (
    select
        *,
        month(orderdate) as order_month
    from
        orders
    where
        month(orderdate) = 8
)
-- 위에서 정의한 8월 주문 데이터(od_8)를 조회합니다.
select * from od_8;

-- DATEDIFF 함수를 사용하여 날짜 간의 차이를 계산합니다.
-- 여기서는 주문일(orderDate)부터 고객이 요청한 납기일(requiredDate)까지의 기간을 계산합니다.
select
    orderNumber,
    datediff(requiredDate, orderDate) as days_due
from
    orders
-- 납기까지 3일 이상 남은 주문만 필터링합니다.
where datediff(requiredDate, orderDate) > 3;

-- DATE_ADD 함수로 특정 날짜에 일정 기간을 더한 날짜를 계산합니다.
-- 주문일(orderDate)로부터 3일 후를 예상 배송일(expectedshipment)로 지정하고, 실제 배송일(shippedDate)과 비교합니다.
select
    orderDate,
    date_add(orderDate, interval 3 day) as expectedshipment,
    shippedDate
from
    orders;