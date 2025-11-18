-- SELECT
--   user_id,
--   JSON_UNQUOTE(JSON_EXTRACT(event_properties, '$.device')) AS device
-- FROM shop_events
-- WHERE JSON_UNQUOTE(JSON_EXTRACT(event_properties, '$.device')) = 'ios';


-- 로그 전체 확인
select * from shop_events;


-- ==============================
-- 세션 단위 퍼널 집계 CTE
-- app_open → view_item → add_to_cart → purchase
-- 시간 순서까지 검증하여 퍼널 유효성 체크
-- ==============================

with session_events as (
    select
        session_id,
        any_value(user_id) as user_id,                         -- 세션 안 user_id(정상이라면 1개)
        min(event_time) as session_start_ts,                   -- 세션 시작 시각(최초 이벤트)
        
        -- 각 이벤트의 최초 발생 시각
        min(case when event_name = 'app_open' then event_time end)      as t_open,
        min(case when event_name = 'view_item' then event_time end)     as t_view,
        min(case when event_name = 'add_to_cart' then event_time end)   as t_cart,
        min(case when event_name = 'purchase' then event_time end)      as t_pay
    from shop_events
    group by session_id                                        -- 세션마다 1행 생성
),

session_flags as (
    select
        session_id,
        user_id,
        date(session_start_ts) as session_date,                 -- 일 단위 퍼널 분석용
        
        -- app_open이 한 번이라도 있으면 1
        (t_open is not null) as has_open,
        
        -- view_item이 존재하며 app_open 이후에 발생하면 유효한 view 단계 통과
        (t_view is not null
         and t_open is not null
         and t_view >= t_open) as valid_view,
        
        -- add_to_cart가 존재하며 app_open → view_item 순서가 모두 맞아야 유효 cart
        (t_cart is not null
         and t_view is not null
         and t_view >= t_open
         and t_cart >= t_view) as valid_cart,
        
        -- purchase가 존재하며 모든 이전 단계가 올바른 시간 순서를 가질 때 유효한 pay
        (t_pay is not null
         and t_cart is not null
         and t_view is not null
         and t_view >= t_open
         and t_cart >= t_view
         and t_pay >= t_cart) as valid_pay
    from session_events
),

agg as (
    select
        session_date,                          -- 해당 날짜의 세션
        count(*) as session_total,             -- 전체 세션 수
        sum(has_open) as s_open,               -- open 단계 통과 세션
        sum(valid_view) as s_view,             -- view 단계 통과 세션
        sum(valid_cart) as s_cart,             -- cart 단계 통과 세션
        sum(valid_pay) as s_pay                -- pay 단계 통과 세션
    from session_flags
    group by session_date
)

-- 최종 퍼널 요약 + 전환율 계산
select
    session_date,
    session_total,
    s_open, s_view, s_cart, s_pay,
    
    -- open 대비 view 전환율
    round(s_view / nullif(s_open,0) * 100, 2) as open_to_view_pct,
    
    -- view 대비 cart 전환율
    round(s_cart / nullif(s_view,0) * 100, 2) as view_to_cart_pct,
    
    -- cart 대비 pay 전환율
    round(s_pay / nullif(s_cart,0) * 100, 2) as cart_to_pay_pct,
    
    -- open 대비 pay 최종 전환율
    round(s_pay / nullif(s_open,0) * 100, 2) as open_to_pay_pct
from agg
order by session_date;


-- =========================================
-- 데이터 무결성 점검(기본 통계)
-- =========================================
select
    count(*) total_rows,                     -- 전체 행 수
    count(distinct event_id) as dist_event_id,      -- event_id 고유 개수
    count(distinct user_id) as dist_user_id,        -- user_id 고유 개수
    count(distinct session_id) as dist_session_id   -- session_id 고유 개수
from shop_events;


-- 특정 유저 점검용
select * from shop_events
where user_id = '108';


-- =========================================
-- 복합 무결성 진단 CTE (데이터 품질 검증용)
-- =========================================

WITH sums AS (
    SELECT
        COUNT(*) AS total_rows,                        -- 전체 row 수
        COUNT(DISTINCT event_id) AS distinct_event_ids, -- 고유 event_id 개수
        COUNT(DISTINCT user_id) AS distinct_user_ids,   -- 고유 user_id 개수
        COUNT(DISTINCT session_id) AS distinct_session_ids -- 고유 session_id 개수
    FROM shop_events
),

dup_event AS (  -- event_id 중복 여부(전역 유니크 키인지 확인)
    SELECT COUNT(*) AS duplicate_event_id_rows
    FROM (
        SELECT event_id
        FROM shop_events
        GROUP BY event_id
        HAVING COUNT(*) > 1                 -- 동일 event_id가 여러 번 등장
    ) d
),

cross_session_user AS (  -- 하나의 세션에 서로 다른 user_id가 섞인 비정상 케이스
    SELECT COUNT(*) AS sessions_cross_users
    FROM (
        SELECT session_id
        FROM shop_events
        GROUP BY session_id
        HAVING COUNT(DISTINCT user_id) > 1  -- 한 세션에 user_id가 여러 개
    ) x
),

identical_rows AS (  -- 로그가 그대로 중복 적재된 경우(완전 동일행)
    SELECT COUNT(*) AS fully_identical_row_groups
    FROM (
        SELECT user_id, session_id, event_name, event_time
        FROM shop_events
        GROUP BY user_id, session_id, event_name, event_time
        HAVING COUNT(*) > 1                 -- 완전 동일한 이벤트가 여러 번 존재
    ) t
)

-- 최종 무결성 리포트 한 줄로 출력
SELECT
    s.total_rows,
    s.distinct_event_ids,
    s.distinct_user_ids,
    s.distinct_session_ids,
    de.duplicate_event_id_rows,
    csu.sessions_cross_users,
    ir.fully_identical_row_groups
FROM sums AS s
JOIN dup_event AS de ON 1 = 1
JOIN cross_session_user AS csu ON 1 = 1
JOIN identical_rows AS ir ON 1 = 1;