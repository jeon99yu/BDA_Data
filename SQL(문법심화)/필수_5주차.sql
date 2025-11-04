-- 과제: 상위 20% 고객의 고객들에 대한 매출순위, 고객의 넘버링, 고객의 revenu, 이 고객들의 세그먼트(20%, 80% 기준으로 나눠서 각 유지별로 20%, 80%)

USE classicmodels;

WITH customer_sales AS (
    SELECT
        c.customerNumber,
        c.customerName,
        SUM(od.quantityOrdered * od.priceEach) AS revenue
    FROM customers c
    INNER JOIN orders o
        ON c.customerNumber = o.customerNumber
    INNER JOIN orderdetails od
        ON o.orderNumber = od.orderNumber
    WHERE o.status IN ('Shipped', 'Resolved')
    GROUP BY c.customerNumber, c.customerName
),
segmented_customers AS (
    SELECT
        customerNumber,
        customerName,
        ROUND(revenue, 2) AS revenue,
        PERCENT_RANK() OVER(ORDER BY revenue DESC) AS percent_rank,
        RANK() OVER(ORDER BY revenue DESC) AS revenue_rank
    FROM customer_sales
)
SELECT
    revenue_rank,
    customerNumber,
    customerName,
    revenue,
    CASE WHEN percent_rank <= 0.2 THEN 'Top 20%' ELSE 'Bottom 80%' END AS segment
FROM segmented_customers
ORDER BY revenue DESC;
