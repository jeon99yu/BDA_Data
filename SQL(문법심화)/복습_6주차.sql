/*
================================================================================
 GA4 스타일 이벤트 로그 테이블 생성 및 샘플 데이터 삽입
================================================================================
 목적: 쇼핑 앱의 사용자 행동 이벤트를 JSON 형식으로 저장하고 분석
 주요 이벤트: app_open → view_item → add_to_cart → purchase
 특징: JSON 컬럼 + 생성 컬럼(Generated Column) + 인덱스 최적화
================================================================================
*/

-- (필요 시) 작업할 DB 명시
-- USE classicmodels;

-- ============================================================================
-- 0) 기존 테이블 제거 (초기화)
-- ============================================================================
DROP TABLE IF EXISTS shop_events;

-- ============================================================================
-- 1) 테이블 생성
-- ============================================================================
CREATE TABLE shop_events (
  -- 기본 컬럼들
  event_id     BIGINT AUTO_INCREMENT PRIMARY KEY,  -- 이벤트 고유 ID (자동 증가)
  user_id      INT NOT NULL,                       -- 사용자 ID (50명)
  session_id   VARCHAR(16) NOT NULL,               -- 세션 ID (16진수 8자리)
  event_name   VARCHAR(32) NOT NULL,               -- 이벤트 이름 (app_open, view_item 등)
  event_time   DATETIME(3) NOT NULL,               -- 이벤트 발생 시간 (밀리초 단위)
  event_properties JSON NOT NULL,                  -- 이벤트 상세 정보 (JSON 형식)
  
  /*
   * 생성 컬럼 (Generated Column)
   * - JSON 내부의 자주 사용하는 값을 실제 컬럼으로 추출하여 저장
   * - STORED: 디스크에 물리적으로 저장 (조회 성능 향상)
   * - JSON_UNQUOTE: JSON 문자열에서 따옴표 제거
   * - JSON_EXTRACT: JSON 경로($.경로)로 값 추출
   */
  device  VARCHAR(16)
    GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(event_properties, '$.device'))) STORED,
    -- device 값 추출 예: "ios", "android", "web"
    
  country VARCHAR(2)
    GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(event_properties, '$.geo.country'))) STORED,
    -- country 값 추출 예: "KR", "US", "JP"
  
  /*
   * 인덱스 생성
   * - 자주 검색/필터링하는 컬럼에 인덱스를 걸어 조회 성능 최적화
   */
  INDEX ix_event_time (event_time),    -- 시간대별 조회 최적화
  INDEX ix_event_name (event_name),    -- 이벤트 타입별 집계 최적화
  INDEX ix_device (device),            -- 디바이스별 필터링 최적화
  INDEX ix_country (country),          -- 국가별 분석 최적화
  
  /*
   * 제약 조건
   * - JSON_VALID: event_properties가 올바른 JSON 형식인지 검증
   */
  CHECK (JSON_VALID(event_properties))
) ENGINE=InnoDB;  -- InnoDB: 트랜잭션 지원, 외래키 제약 가능

-- ============================================================================
-- 2) 샘플 데이터 삽입 (CTE를 활용한 대량 데이터 생성)
-- ============================================================================
/*
 * CTE (Common Table Expression): WITH 절을 사용한 임시 결과 집합
 * 장점: 복잡한 쿼리를 단계별로 나눠서 가독성 향상
 */
INSERT INTO shop_events (user_id, session_id, event_name, event_time, event_properties)
WITH RECURSIVE

-- ---------------------------------------------------------------------------
-- 2.1 세션 번호 생성기 (1부터 380까지)
-- ---------------------------------------------------------------------------
/*
 * RECURSIVE: 재귀 쿼리로 연속된 숫자 생성
 * 1에서 시작해서 380까지 1씩 증가하는 숫자 시퀀스 생성
 */
seq(n) AS (
  SELECT 1                              -- 시작값: 1
  UNION ALL
  SELECT n+1 FROM seq WHERE n < 380     -- 380까지 반복
),

-- ---------------------------------------------------------------------------
-- 2.2 세션별 기본 특성 생성 (사용자, 디바이스, 위치, 시간 등)
-- ---------------------------------------------------------------------------
/*
 * 각 세션(n)마다 고유한 특성 부여
 * - 사용자 ID, 세션 ID, 디바이스, 국가, 시간 등
 * - 퍼널 분석을 위한 확률: 90% view → 60% cart → 40% purchase
 */
base AS (
  SELECT
      n AS session_no,  -- 세션 번호
      
      /* 사용자 ID 생성: 100~149 (총 50명) */
      (100 + (n % 50)) AS user_id,
      
      /* 세션 ID: 16진수 8자리 (예: 00000001, 00000002...) */
      LPAD(CONV(n, 10, 16), 8, '0') AS session_id,
      
      /*
       * 전환 퍼널 확률 설정
       * - has_view: 90% (380개 중 약 342개)
       * - has_cart: 60% (380개 중 약 228개)
       * - has_purchase: 40% (380개 중 약 152개)
       * 
       * 계산 방식: (n * 소수) % 100 < 확률
       * - 소수를 곱해서 분산시킴 (패턴 방지)
       */
      ((n*37) % 100) < 90 AS has_view,        -- 90% 확률로 상품 조회
      ((n*73) % 100) < 60 AS has_cart,        -- 60% 확률로 장바구니 담기
      ((n*97) % 100) < 40 AS has_purchase,    -- 40% 확률로 구매

      /*
       * 이벤트 기준 시간 생성
       * - 기준: 2025-10-01 09:00:00
       * - 5일간(5*24*60분) 랜덤하게 분산
       * - 추가로 초 단위(0~44초) 랜덤 추가
       */
      CAST('2025-10-01 09:00:00' AS DATETIME)
        + INTERVAL FLOOR(((n*17) % (5*24*60))) MINUTE  -- 0~7199분 (5일)
        + INTERVAL ((n*29) % 45) SECOND                -- 0~44초
        AS base_time,

      /*
       * 디바이스 타입 (3가지를 순환)
       * - n % 3 = 0: iOS
       * - n % 3 = 1: Android
       * - n % 3 = 2: Web
       */
      CASE n % 3
        WHEN 0 THEN 'ios'
        WHEN 1 THEN 'android'
        ELSE 'web'
      END AS device,

      /*
       * 앱 버전 (예: 1.0.0, 1.1.1, 1.2.2...)
       * - 메이저.마이너.패치 형식
       */
      CONCAT('1.', (n % 4), '.', (n % 10)) AS app_ver,

      /*
       * 국가 코드 (KR 50%, US 25%, JP 25%)
       * - n % 4 = 0 or 1: KR (한국)
       * - n % 4 = 2: US (미국)
       * - n % 4 = 3: JP (일본)
       */
      CASE n % 4
        WHEN 0 THEN 'KR' 
        WHEN 1 THEN 'KR' 
        WHEN 2 THEN 'US' 
        ELSE 'JP'
      END AS country,

      /* 도시 */
      CASE n % 4
        WHEN 0 THEN 'Seoul' 
        WHEN 1 THEN 'Busan' 
        WHEN 2 THEN 'LA' 
        ELSE 'Tokyo'
      END AS city
  FROM seq
),

-- ---------------------------------------------------------------------------
-- 2.3 상품 카탈로그 (5개 상품)
-- ---------------------------------------------------------------------------
/*
 * 테스트용 상품 목록
 * - SKU: 상품 코드
 * - price: 상품 가격
 */
products AS (
  SELECT 'A100' AS sku,  9.90 AS price UNION ALL   -- 저가 상품
  SELECT 'A200',        14.50 UNION ALL
  SELECT 'B100',         5.25 UNION ALL             -- 최저가 상품
  SELECT 'C300',        29.00 UNION ALL             -- 중가 상품
  SELECT 'D400',        49.00                       -- 고가 상품
),

-- ---------------------------------------------------------------------------
-- 2.4 세션별 대표 상품 선택 (view, cart용)
-- ---------------------------------------------------------------------------
/*
 * 각 세션마다 1개의 대표 상품 할당
 * - 5개 상품을 순환하며 선택 (session_no % 5)
 */
pick_item AS (
  SELECT
    b.session_no,
    CASE (b.session_no % 5)
      WHEN 0 THEN 'A100' 
      WHEN 1 THEN 'A200' 
      WHEN 2 THEN 'B100' 
      WHEN 3 THEN 'C300' 
      ELSE 'D400'
    END AS sku1  -- 대표 상품 1개
  FROM base b
),

-- ---------------------------------------------------------------------------
-- 2.5 구매 이벤트용 추가 상품 (복수 구매 시뮬레이션)
-- ---------------------------------------------------------------------------
/*
 * purchase 이벤트에서는 여러 상품을 함께 구매 가능
 * - has_item2: 50% 확률로 2번째 상품 추가
 * - has_item3: 25% 확률로 3번째 상품 추가
 * 결과: 최대 3개 상품까지 한 번에 구매 가능
 */
pick_more AS (
  SELECT
    b.session_no,
    (((b.session_no*11) % 100) < 50) AS has_item2,  -- 50% 확률
    (((b.session_no*19) % 100) < 25) AS has_item3,  -- 25% 확률
    
    /* 2번째, 3번째 상품은 1번째와 다른 상품 선택 */
    CASE ((b.session_no+1) % 5)
      WHEN 0 THEN 'A100' WHEN 1 THEN 'A200' WHEN 2 THEN 'B100' 
      WHEN 3 THEN 'C300' ELSE 'D400'
    END AS sku2,
    
    CASE ((b.session_no+2) % 5)
      WHEN 0 THEN 'A100' WHEN 1 THEN 'A200' WHEN 2 THEN 'B100' 
      WHEN 3 THEN 'C300' ELSE 'D400'
    END AS sku3
  FROM base b
),
-- ---------------------------------------------------------------------------
-- 2.6 이벤트 생성 (전환 퍼널: app_open → view → cart → purchase)
-- ---------------------------------------------------------------------------
/*
 * 4가지 이벤트 타입을 UNION ALL로 결합
 * 시간 순서: base_time → +5초 → +15초 → +45초
 */
events AS (
  
  /* ========================================================================
   * (1) app_open : 앱 실행 이벤트
   * ========================================================================
   * - 모든 세션에서 발생 (380개 전부)
   * - 사용자가 앱을 켰을 때의 첫 이벤트
   * - 디바이스, 앱 버전, 위치 정보만 포함
   */
  SELECT
    b.user_id,
    b.session_id,
    'app_open' AS event_name,
    b.base_time AS event_time,  -- 세션 시작 시간
    JSON_OBJECT(
      'device', b.device,       -- 디바이스: ios/android/web
      'app_ver', b.app_ver,     -- 앱 버전: 1.x.x
      'geo', JSON_OBJECT(       -- 지리 정보 (중첩 JSON)
        'country', b.country,   -- 국가 코드
        'city', b.city          -- 도시명
      )
    ) AS event_properties
  FROM base b

  UNION ALL

  /* ========================================================================
   * (2) view_item : 상품 조회 이벤트
   * ========================================================================
   * - 90%의 세션에서 발생 (약 342개)
   * - app_open 후 5초 뒤 발생
   * - 조회한 상품 정보(SKU, 수량, 가격) 포함
   */
  SELECT
    b.user_id,
    b.session_id,
    'view_item' AS event_name,
    b.base_time + INTERVAL 5 SECOND AS event_time,  -- +5초 후
    JSON_OBJECT(
      'device', b.device,
      'app_ver', b.app_ver,
      'geo', JSON_OBJECT('country', b.country, 'city', b.city),
      'item', JSON_OBJECT(      -- 조회한 상품 정보
        'sku',   pi.sku1,       -- 상품 코드
        'qty',   1,             -- 조회 수량 (항상 1)
        'price', (SELECT p.price FROM products p WHERE p.sku = pi.sku1)
      )
    ) AS event_properties
  FROM base b
  JOIN pick_item pi ON pi.session_no = b.session_no
  WHERE b.has_view  -- 90%만 해당

  UNION ALL

  /* ========================================================================
   * (3) add_to_cart : 장바구니 담기 이벤트
   * ========================================================================
   * - 60%의 세션에서 발생 (약 228개)
   * - view_item이 있었던 세션만 가능
   * - app_open 후 15초 뒤 발생
   * - 담은 수량이 1~3개로 랜덤 (session_no % 3 + 1)
   */
  SELECT
    b.user_id,
    b.session_id,
    'add_to_cart' AS event_name,
    b.base_time + INTERVAL 15 SECOND AS event_time,  -- +15초 후
    JSON_OBJECT(
      'device', b.device,
      'app_ver', b.app_ver,
      'geo', JSON_OBJECT('country', b.country, 'city', b.city),
      'item', JSON_OBJECT(
        'sku',   pi.sku1,
        'qty',   1 + (b.session_no % 3),  -- 1~3개 (1+0, 1+1, 1+2)
        'price', (SELECT p.price FROM products p WHERE p.sku = pi.sku1)
      )
    ) AS event_properties
  FROM base b
  JOIN pick_item pi ON pi.session_no = b.session_no
  WHERE b.has_view AND b.has_cart  -- view도 있고 cart도 있는 경우만

  UNION ALL

  /* ========================================================================
   * (4) purchase : 구매 완료 이벤트
   * ========================================================================
   * - 40%의 세션에서 발생 (약 152개)
   * - add_to_cart가 있었던 세션만 가능
   * - app_open 후 45초 뒤 발생
   * - 여러 상품 동시 구매 가능 (1~3개)
   * 
   * items 배열 구조:
   * - 기본 상품(sku1) 1개: 100% 포함
   * - 추가 상품(sku2) 1개: 50% 확률로 포함
   * - 추가 상품(sku3) 1개: 25% 확률로 포함
   * 
   * JSON_MERGE_PRESERVE: 여러 JSON 배열을 하나로 합침 (중복 키 유지)
   */
  SELECT
    b.user_id,
    b.session_id,
    'purchase' AS event_name,
    b.base_time + INTERVAL 45 SECOND AS event_time,  -- +45초 후
    JSON_OBJECT(
      'device', b.device,
      'app_ver', b.app_ver,
      'geo', JSON_OBJECT('country', b.country, 'city', b.city),
      'items',  -- 구매 상품 배열 (1~3개)
        JSON_MERGE_PRESERVE(
          -- 기본 상품 (항상 포함)
          JSON_ARRAY(
            JSON_OBJECT(
              'sku',   pi.sku1,
              'qty',   1 + ((b.session_no*3) % 2),  -- 1~2개
              'price', (SELECT p.price FROM products p WHERE p.sku = pi.sku1)
            )
          ),
          -- 추가 상품 2 (50% 확률)
          IF(pm.has_item2,
             JSON_ARRAY(
               JSON_OBJECT(
                 'sku',   pm.sku2,
                 'qty',   1 + ((b.session_no*5) % 2),  -- 1~2개
                 'price', (SELECT p.price FROM products p WHERE p.sku = pm.sku2)
               )
             ),
             JSON_ARRAY()  -- 없으면 빈 배열
          ),
          -- 추가 상품 3 (25% 확률)
          IF(pm.has_item3,
             JSON_ARRAY(
               JSON_OBJECT(
                 'sku',   pm.sku3,
                 'qty',   1 + ((b.session_no*7) % 2),  -- 1~2개
                 'price', (SELECT p.price FROM products p WHERE p.sku = pm.sku3)
               )
             ),
             JSON_ARRAY()  -- 없으면 빈 배열
          )
        )
    ) AS event_properties
  FROM base b
  JOIN pick_item pi ON pi.session_no = b.session_no
  JOIN pick_more pm ON pm.session_no = b.session_no
  WHERE b.has_view AND b.has_cart AND b.has_purchase  -- 모든 단계를 거친 경우만
)

/*
 * 최종 SELECT: events CTE의 결과를 실제 테이블에 삽입
 * - ORDER BY: 시간순, 세션순, 이벤트명순 정렬
 * - LIMIT 1000: 최대 1000개 레코드만 삽입 (테스트용)
 */
SELECT user_id, session_id, event_name, event_time, event_properties
FROM events
ORDER BY event_time, session_id, event_name
LIMIT 1000;

-- ============================================================================
-- 3) 데이터 확인 쿼리들
-- ============================================================================

/* 3.1 삽입된 총 레코드 수 확인 */
SELECT COUNT(*) AS inserted_rows FROM shop_events;
-- 결과 예상: 약 1000개 (LIMIT 1000 적용됨)

/* 3.2 이벤트 타입별 집계 */
SELECT 
    event_name,           -- 이벤트 이름
    COUNT(*) AS cnt       -- 각 이벤트 발생 횟수
FROM shop_events
GROUP BY event_name
ORDER BY cnt DESC;
/*
 * 예상 결과:
 * - app_open: 380개 (100%)
 * - view_item: ~342개 (90%)
 * - add_to_cart: ~228개 (60%)
 * - purchase: ~152개 (40%)
 */

/* 3.3 생성 컬럼 포함 샘플 데이터 조회 */
SELECT 
    event_id,      -- 이벤트 ID
    user_id,       -- 사용자 ID
    session_id,    -- 세션 ID
    event_name,    -- 이벤트 이름
    event_time,    -- 발생 시간
    device,        -- 디바이스 (생성 컬럼)
    country        -- 국가 (생성 컬럼)
FROM shop_events
ORDER BY event_time  -- 시간순 정렬
LIMIT 5;

/* 3.4 다른 테이블 조회 (테스트) */
SELECT * FROM customers;


-- ============================================================================
-- 4) JSON 데이터 추출 연습
-- ============================================================================
/*
 * JSON 컬럼에서 특정 값을 추출하는 방법 학습
 * GA4(Google Analytics 4) 스타일의 이벤트 로그 분석
 */

/* ----- 전체 데이터 조회 ----- */
SELECT * FROM shop_events;


/* ============================================================================
 * 4.1 JSON 기본 추출
 * ============================================================================
 * event_properties 컬럼은 JSON 타입으로 다양한 정보를 포함
 */
SELECT 
    event_id,
    user_id,
    session_id,
    event_properties  -- JSON 전체 조회
FROM shop_events;


/* ============================================================================
 * 4.2 JSON_EXTRACT 함수 사용
 * ============================================================================
 * 함수: JSON_EXTRACT(json_컬럼, '$.경로')
 * 용도: JSON 내부의 특정 경로 값 추출
 * 주의: 결과에 따옴표("") 포함됨
 */
SELECT 
    user_id,
    event_id,
    event_name,
    -- 1단계 경로: $.device
    JSON_EXTRACT(event_properties, '$.device') AS device_raw,
    -- 2단계 경로: $.geo.country (중첩 JSON)
    JSON_EXTRACT(event_properties, '$.geo.country') AS country_raw
FROM shop_events;
/*
 * 결과 예시:
 * device_raw: "ios" (따옴표 포함)
 * country_raw: "KR" (따옴표 포함)
 */


/* ============================================================================
 * 4.3 화살표 연산자 (->)
 * ============================================================================
 * 문법: json_컬럼 -> '$.경로'
 * 특징: JSON_EXTRACT의 축약 표현
 */
SELECT 
    user_id,
    event_properties -> '$.device' AS device_raw  -- JSON_EXTRACT와 동일
FROM shop_events;


/* ============================================================================
 * 4.4 JSON 값 기준 필터링 (WHERE 절)
 * ============================================================================
 * 목표: iOS 유저만 추출하여 분석
 * 
 * 중요: JSON 값과 비교할 때는 JSON_UNQUOTE 필수!
 * 이유: JSON_EXTRACT는 따옴표를 포함하므로 "ios"와 비교해야 하지만
 *       JSON_UNQUOTE를 사용하면 ios로 깔끔하게 비교 가능
 */

/* ----- 전체 데이터 다시 확인 ----- */
SELECT * FROM shop_events;


/* ============================================================================
 * 4.5 JSON_UNQUOTE + JSON_EXTRACT 조합 (핵심!)
 * ============================================================================
 * 함수: JSON_UNQUOTE(JSON_EXTRACT(json_컬럼, '$.경로'))
 * 용도: JSON 값을 따옴표 없는 순수 문자열로 추출
 * 
 * 왜 두 개를 같이 써야 하나?
 * 1. JSON_EXTRACT만 쓰면: "ios" (따옴표 포함)
 * 2. JSON_UNQUOTE 추가하면: ios (따옴표 제거)
 * 3. WHERE 절에서 문자열 비교 시 필수!
 */
SELECT
    user_id,
    JSON_UNQUOTE(JSON_EXTRACT(event_properties, '$.device')) AS device
FROM shop_events
WHERE JSON_UNQUOTE(JSON_EXTRACT(event_properties, '$.device')) = 'ios';
/*
 * 결과: iOS 디바이스를 사용한 이벤트만 조회
 * 활용: 디바이스별, 국가별 사용자 행동 분석
 */


/* ============================================================================
 * 추가 학습: 생성 컬럼을 사용한 필터링 (더 효율적!)
 * ============================================================================
 * 위의 JSON_UNQUOTE + JSON_EXTRACT는 매번 계산이 필요하지만
 * 생성 컬럼(device, country)을 사용하면 인덱스 활용 가능
 */
SELECT
    user_id,
    device,
    country
FROM shop_events
WHERE device = 'ios';  -- 생성 컬럼 사용 (인덱스 활용, 빠름!)


/*
================================================================================
 핵심 요약
================================================================================

1. JSON 데이터 추출 방법:
   - JSON_EXTRACT(컬럼, '$.경로')         : 따옴표 포함
   - JSON_UNQUOTE(JSON_EXTRACT(...))     : 따옴표 제거 (비교용)
   - 컬럼 -> '$.경로'                     : JSON_EXTRACT 축약형

2. 생성 컬럼 (Generated Column):
   - 자주 쓰는 JSON 경로를 실제 컬럼으로 저장
   - STORED: 디스크에 저장 (조회 빠름)
   - INDEX: 인덱스 생성 가능 (필터링/정렬 최적화)

3. 전환 퍼널 분석:
   - app_open (100%) → view_item (90%) → add_to_cart (60%) → purchase (40%)
   - 각 단계별 이탈률 분석 가능

4. 실무 활용:
   - 디바이스별 전환율 비교 (iOS vs Android vs Web)
   - 국가별 구매 패턴 분석 (KR vs US vs JP)
   - 시간대별 사용자 활동 분석
   - 상품별 조회/구매 비율 분석
================================================================================
*/