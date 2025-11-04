use classicmodels;

-- 1) WHERE: 집계(GROUP BY) 이전에 행을 필터링
-- 2) GROUP BY: 특정 기준으로 행을 그룹화하여 집계 단위로 만듦
-- 3) HAVING: 집계(GROUP BY) 이후 결과에 대한 조건 필터링

-- 고객별 주문 건수가 1건 초과인 고객만 조회
SELECT
    customerNumber,
    COUNT(*) AS order_count
FROM orders
GROUP BY customerNumber
HAVING COUNT(*) > 1;

-- 고객 테이블에서 customerNumber의 중복 여부 확인 (중복 없음)
SELECT
    customerNumber,
    COUNT(*) AS duplicate_count
FROM customers
GROUP BY customerNumber
HAVING COUNT(*) > 1;  -- 1보다 크면 중복 존재

-- 조건별 집계 패턴 (CASE WHEN 활용)
SELECT
    customerNumber,
    SUM(CASE WHEN status = 'Shipped' THEN 1 ELSE 0 END) AS shipped_count,
    SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_count
FROM orders
GROUP BY customerNumber;

-- 주문별 매출액 집계 (CTE 활용)
-- 주문 상세 -> 주문 -> 일자별 매출 집계
WITH
line_revenue AS (     -- 1단계: 주문 상세별 금액 계산
    SELECT 
        od.orderNumber,
        (od.priceEach * od.quantityOrdered) AS line_revenue
    FROM orderdetails AS od
),
order_revenue AS (     -- 2단계: 주문 단위로 매출 합산 및 주문일 추가
    SELECT
        o.orderDate AS order_date,
        SUM(lr.line_revenue) AS total_revenue
    FROM orders AS o
    INNER JOIN line_revenue AS lr
        ON o.orderNumber = lr.orderNumber
    GROUP BY o.orderDate
)
-- 3단계: 최종 결과 조회
SELECT 
    order_date,
    total_revenue
FROM order_revenue
ORDER BY order_date;

-- 최근 90일 일별 매출 + 7일 이동합계
WITH
daily_revenue AS (
    SELECT
        DATE(o.orderDate) AS date,
        SUM(od.quantityOrdered * od.priceEach) AS daily_revenue
    FROM orders AS o
    INNER JOIN orderdetails AS od
        ON o.orderNumber = od.orderNumber
    WHERE o.status IN ('Shipped', 'Resolved')
      AND o.orderDate >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    GROUP BY DATE(o.orderDate)
)
SELECT
    date,
    daily_revenue,
    SUM(daily_revenue) OVER (
        ORDER BY date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS rolling_7day_sum
FROM daily_revenue
ORDER BY date;
