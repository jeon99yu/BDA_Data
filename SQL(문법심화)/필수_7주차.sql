-- 필수과제는 event_id, user_id 도 추가하여 funnel을 만들고, 수치가 왜 다른지를 이해하기!
-- 쿼리로 결과가 나오면 되고, 왜 수치가 다른지! 

WITH session_events AS (
  /* 세션별로 최초/각 단계 시간 계산 */
  SELECT
    session_id,
    ANY_VALUE(user_id) AS user_id,
    MIN(event_time) AS session_start_ts,
    MIN(CASE WHEN event_name = 'app_open'   THEN event_time END) AS t_open,
    MIN(CASE WHEN event_name = 'view_item'  THEN event_time END) AS t_view,
    MIN(CASE WHEN event_name = 'add_to_cart' THEN event_time END) AS t_cart,
    MIN(CASE WHEN event_name = 'purchase'   THEN event_time END) AS t_pay
  FROM shop_events
  GROUP BY session_id
),
session_flags AS (
  /* 세션 단위 valid 여부 플래그 */
  SELECT
    session_id,
    user_id,
    DATE(session_start_ts) AS session_date,
    (t_open IS NOT NULL) AS has_open,
    (t_view IS NOT NULL
     AND t_open IS NOT NULL
     AND t_view >= t_open) AS valid_view,
    (t_cart IS NOT NULL
     AND t_view IS NOT NULL
     AND t_open IS NOT NULL
     AND t_view >= t_open
     AND t_cart >= t_view) AS valid_cart,
    (t_pay IS NOT NULL
     AND t_cart IS NOT NULL
     AND t_view IS NOT NULL
     AND t_open IS NOT NULL
     AND t_view >= t_open
     AND t_cart >= t_view
     AND t_pay  >= t_cart) AS valid_pay
  FROM session_events
),


--   2-1. 세션 기준 퍼널

session_funnel AS (
  SELECT
    session_date,
    COUNT(*)            AS session_total,
    SUM(has_open)       AS s_open,
    SUM(valid_view)     AS s_view,
    SUM(valid_cart)     AS s_cart,
    SUM(valid_pay)      AS s_pay
  FROM session_flags
  GROUP BY session_date
),


 --  2-2. 유저 기준 퍼널
  -- - 한 유저가 하루에 여러 세션 있어도
  --   "그 날 그 유저가 해당 단계까지 한 번이라도 도달했는가?"

user_flags AS (
  SELECT
    session_date,
    user_id,
    MAX(has_open)   AS has_open,
    MAX(valid_view) AS valid_view,
    MAX(valid_cart) AS valid_cart,
    MAX(valid_pay)  AS valid_pay
  FROM session_flags
  GROUP BY session_date, user_id
),
user_funnel AS (
  SELECT
    session_date,
    COUNT(DISTINCT user_id)      AS user_total,
    SUM(has_open)                AS u_open,
    SUM(valid_view)              AS u_view,
    SUM(valid_cart)              AS u_cart,
    SUM(valid_pay)               AS u_pay
  FROM user_flags
  GROUP BY session_date
),


  -- 2-3. 이벤트(event_id) 기준 퍼널
  -- - 각 단계별 이벤트 건수(= event_id 개수) 집계
  -- - 세션 유효성과 상관없이, 순수 이벤트 건수 기준

event_funnel AS (
  SELECT
    DATE(event_time) AS event_date,
    COUNT(DISTINCT CASE WHEN event_name = 'app_open'   THEN event_id END) AS e_open,
    COUNT(DISTINCT CASE WHEN event_name = 'view_item'  THEN event_id END) AS e_view,
    COUNT(DISTINCT CASE WHEN event_name = 'add_to_cart' THEN event_id END) AS e_cart,
    COUNT(DISTINCT CASE WHEN event_name = 'purchase'   THEN event_id END) AS e_pay
  FROM shop_events
  GROUP BY DATE(event_time)
)


 --  최종 출력:
 --  - 세션 기준 / 유저 기준 / 이벤트 기준 퍼널을 한 번에 비교

SELECT
  sf.session_date,
  -- 세션 기준
  sf.session_total,
  sf.s_open, sf.s_view, sf.s_cart, sf.s_pay,
  ROUND(sf.s_view / NULLIF(sf.s_open, 0) * 100, 2) AS sess_open_to_view_pct,
  ROUND(sf.s_cart / NULLIF(sf.s_view, 0) * 100, 2) AS sess_view_to_cart_pct,
  ROUND(sf.s_pay  / NULLIF(sf.s_cart, 0) * 100, 2) AS sess_cart_to_pay_pct,
  ROUND(sf.s_pay  / NULLIF(sf.s_open, 0) * 100, 2) AS sess_open_to_pay_pct,

  -- 유저 기준
  uf.user_total,
  uf.u_open, uf.u_view, uf.u_cart, uf.u_pay,
  ROUND(uf.u_view / NULLIF(uf.u_open, 0) * 100, 2) AS user_open_to_view_pct,
  ROUND(uf.u_cart / NULLIF(uf.u_view, 0) * 100, 2) AS user_view_to_cart_pct,
  ROUND(uf.u_pay  / NULLIF(uf.u_cart, 0) * 100, 2) AS user_cart_to_pay_pct,
  ROUND(uf.u_pay  / NULLIF(uf.u_open, 0) * 100, 2) AS user_open_to_pay_pct,

  -- 이벤트 기준 (건수만 비교, 비율은 필요에 따라 직접 계산)
  ef.e_open, ef.e_view, ef.e_cart, ef.e_pay

FROM session_funnel AS sf
LEFT JOIN user_funnel   AS uf ON uf.session_date = sf.session_date
LEFT JOIN event_funnel  AS ef ON ef.event_date   = sf.session_date
ORDER BY sf.session_date;


-- event_id: 가장 큼, 시간 순서나 유효성 무시, 중복 이벤트 모두 카운트 (순수 활동량)
-- session_id: 중간정도, 시간 순서를 따짐 (유효성), 유저의 중복 세션은 각각 카운트
-- user_id: 가장 작음, 일별 유저 고유값만 카운트, 여러 세션도 1명으로 처리