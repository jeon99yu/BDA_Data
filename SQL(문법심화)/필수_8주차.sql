## 필수과제는 event_id, user_id 도 추가하여 funnel을 만들고, 수치가 왜 다른지를 이해하기!
## 쿼리로 결과가 나오면 되고, 왜 수치가 다른지! 

-- 1. 전체 shop_events 데이터 확인용
SELECT *
  FROM shop_events;

-- 2. 필요한 이벤트 정보만 추출 (event_id, user_id 포함)
WITH user_events AS (
  SELECT
    event_id,      -- 개별 이벤트 고유 ID
    user_id,       -- 유저 ID
    session_id,    -- 세션 ID
    event_name,    -- 이벤트명 (예: app_open, view_item 등)
    event_time     -- 이벤트 발생 시간
  FROM shop_events
),

-- 3. 세션 내 각 이벤트별 최초 발생 시점 계산
session_events AS (
  SELECT
    user_id,
    session_id,
    MIN(event_time) AS session_start_ts,     -- 세션 시작 시각
    MIN(CASE WHEN event_name = 'app_open' THEN event_time END) AS t_open,  -- 앱 오픈 최초 시각
    MIN(CASE WHEN event_name = 'view_item' THEN event_time END) AS t_view, -- 상품 조회 최초 시각
    MIN(CASE WHEN event_name = 'add_to_cart' THEN event_time END) AS t_cart, -- 장바구니 최초 시각
    MIN(CASE WHEN event_name = 'purchase' THEN event_time END) AS t_pay    -- 결제 최초 시각
  FROM user_events
  GROUP BY user_id, session_id
),

-- 4. 각 세션별 단계별 이탈 여부 플래그 생성
session_flags AS (
  SELECT
    user_id,
    session_id,
    DATE(session_start_ts) AS session_date, -- 세션 날짜
    (t_open IS NOT NULL) AS has_open, -- 앱 오픈 이벤트 발생 여부
    (t_view IS NOT NULL AND t_open IS NOT NULL AND t_view >= t_open) AS valid_view, -- 앱 오픈 후 상품 조회시 통과
    (t_cart IS NOT NULL AND t_view IS NOT NULL AND t_view >= t_open AND t_cart >= t_view) AS valid_cart, -- 상품조회, 장바구니 순서 통과
    (t_pay IS NOT NULL AND t_cart IS NOT NULL AND t_view >= t_open AND t_cart >= t_view AND t_pay >= t_cart) AS valid_pay -- 장바구니 후 결제시 통과
  FROM session_events
),

-- 5. 날짜별 각 단계별 유효 세션 수 집계
agg AS (
  SELECT
    session_date,
    COUNT(*) AS session_total,      -- 전체 세션 수
    SUM(has_open) AS s_open,        -- 앱 오픈 세션 수
    SUM(valid_view) AS s_view,      -- 상품 조회까지 도달한 세션 수
    SUM(valid_cart) AS s_cart,      -- 장바구니까지 도달한 세션 수
    SUM(valid_pay) AS s_pay         -- 결제까지 도달한 세션 수
  FROM session_flags
  GROUP BY session_date
)

-- 6. 날짜별 단계별 세션 수 및 전환율 집계 결과 출력
SELECT
  session_date,
  session_total,
  s_open,  -- 앱 오픈 세션
  s_view,  -- 상품 조회 세션
  s_cart,  -- 장바구니 세션
  s_pay,   -- 결제 세션
  ROUND(s_view / NULLIF(s_open, 0) * 100, 2) AS open_to_view_pct,   -- 오픈→조회 전환률
  ROUND(s_cart / NULLIF(s_view, 0) * 100, 2) AS view_to_cart_pct,   -- 조회→장바구니 전환률
  ROUND(s_pay / NULLIF(s_cart, 0) * 100, 2) AS cart_to_pay_pct,     -- 장바구니→결제 전환률
  ROUND(s_pay / NULLIF(s_open, 0) * 100, 2) AS open_to_pay_pct      -- 오픈→결제 전환률
FROM agg;
