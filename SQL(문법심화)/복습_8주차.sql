USE classicmodels;

select * from customers;

-- 1. SQL 분석함수
-- lag/lead : 앞/뒤 행의 데이터를 참조해오는 함수
	--- -> 하루 전 날짜와 오늘 날짜의 데이터를 비교할 수 있음 
	--- -> 전 날, 전 달 대비 매출 비교
-- CUME_DIST : 그룹 내의 누적 분포 , 0<값<=1
-- PERCENT_RANK : index 기준으로 그룹내 상대 순위, 0~1
-- FIRST_VALUE / LAST_VALUE : 정렬된 데이터에서 첫번째/마지막 행의 값을 반환
	--- last_value 함수는 윈도우 함수를 사용하지 않으면 정확한 결과를 얻을 수 없다.



-- 1-1. LAG, LEAD 실습 
- (using 날짜 & 매출 데이터가 있는 payments table)
-- 오늘 매출과 전날 매출이 있으면 
-- -> 오늘 매출이 올랐는지, 떨어졌는지
-- -> 며칠 뒤에 매출이 갑자기 튀거나, 확 오르는 상황이 있는지? 

select * from payments;

-- (1) 날짜 별로 group by : CTE
with daily_apy as (
	select
		date(paymentDate) as py_date,
		sum(amount) as amount
	from payments
	group by date(paymentDate)
)
-- (2) 어제(lag), 오늘, 내일(lead)의 amount 값을 반환
select
	py_date,
    lag(amount,1) over (order by py_date) as prev_amount, - LAG: py_date 기준 정렬로 + 1행 이전의 amount 값 반환
    amount,
    lead(amount,1) over (order by py_date) as next_amount - LEAD: py_date 기준 정렬로 + 1행 뒤의 amount 값 반환
from daily_apy;



-- 1-2. PERCENT_RANK 실습
-- 고객 등급을 나눌거다. 우리의 고객은 상위 몇 %인가?
-- -> 매출 기반으로 매출에 가장 기여한 고객을 단순하게 Vip, vvip, 태깅 
-- => 10% vvip, 30% vip 나머지는 일반 

-- (1) 고객 별로 group by : CTE
with cust_pay as (
	select
		customerNumber as customer_id,
		sum(amount) as amount
	from payments
	group by customerNumber
)
-- (2) 고객(customer_id) 각각의 상대적 순위(percent_rank, 0~1) 반환
select
	customer_id,
    amount,
    percent_rank() over (order by amount desc) as pr_rank - PERCENT_RANK: 자체적으로 amount 내림차순으로 정렬 + 각 행의 순위 반환
    -- 0 => 상위 0% (1등)
    -- 1 => 상위 100% (꼴등)
from cust_pay
order by amount desc;

-- 1-3. percent_rank vs cume_dist
	-- percent_rank : 순위 인덱스 기준으로 본다. 
	-- ex. 정렬한 뒤 몇 번째 인덱스냐? -> 값의 크기 차이는 크게 중요하지 않고, 정렬했을 때 "몇 번째"인지만 본다.
	-- cume_dist : 값 기준으로 본다 
    -- ex. 이 값보다 크거나 같은 값이 전체에서 몇 %냐? -> 값 자체의 크기가 중요하다.


-- 1-4. CUME_DIST 실습
-- 고객별로 결제 금액이 전체 고객중 어느 누적 구간에 위치되는가? == cume_dist

with cust_pay as (
	select
		customerNumber as customer_id,
		sum(amount) as amount
	from payments
	group by customerNumber
)
select
	customer_id,
    amount,
    - 0 < 값 <= 1
    cume_dist() over (order by amount desc) as cum_dist_value
from cust_pay
order by amount desc;


-- 순위 함수 
-- COS, SIN, TNA, ATAN
-- ROW_NUMBER : 정렬된 테이블의 모든 행에 '유일한 값'으로 순위를 부여함 (동점 반영한 처리 X)
	-- order by, partition by 와 달라
-- RANK : 동점이면 같은 순위를 부여한다.
	-- ex. 1 1 3 3 5 6 
-- DENSE_RANK : 동점이면 같은 순위를 부여한다.
	-- ex. 1 1 2 2 3 4
-- NTILE : 그룹 순위를 부여한다. 일단 테이블을 그룹으로 나누고 -> 그 그룹 내에서 순위를 매긴다.
	-- partition by 와 많이 쓰인다.
