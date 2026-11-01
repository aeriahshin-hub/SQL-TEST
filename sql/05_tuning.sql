-- 05. 쿼리 성능 개선
-- 대상: 주중 출근 시간 순유출 TOP 10을 원본 테이블에서 바로 집계하는 쿼리

USE ddareungi;

-- [튜닝 전] 실행계획: 인덱스를 쓰지 않도록 IGNORE INDEX 지정
-- 결과: type = ALL, key = NULL, rows = 68,859,035 x 2회 / 실행 시간 119.4초
EXPLAIN
WITH dep AS (
  SELECT start_station_id AS sid, SUM(total_cnt) AS cnt
  FROM od_usage IGNORE INDEX (idx_cover)
  WHERE agg_type = '출발시간'
    AND DAYOFWEEK(base_date) BETWEEN 2 AND 6
    AND time_slot >= '0700' AND time_slot < '0900'
  GROUP BY start_station_id
),
arr AS (
  SELECT end_station_id AS sid, SUM(total_cnt) AS cnt
  FROM od_usage IGNORE INDEX (idx_cover)
  WHERE agg_type = '도착시간'
    AND DAYOFWEEK(base_date) BETWEEN 2 AND 6
    AND time_slot >= '0700' AND time_slot < '0900'
  GROUP BY end_station_id
)
SELECT d.sid, d.cnt AS 대여, COALESCE(a.cnt, 0) AS 반납,
       d.cnt - COALESCE(a.cnt, 0) AS 순유출
FROM dep d
LEFT JOIN arr a ON d.sid = a.sid
ORDER BY 순유출 DESC
LIMIT 10;

-- [튜닝 1] 커버링 인덱스
-- 1단계: 조건 컬럼만 담은 기본 인덱스 (생성 844.8초)
CREATE INDEX idx_type_time ON od_usage (agg_type, time_slot);

-- 2단계: 쿼리에 필요한 컬럼을 모두 담은 커버링 인덱스 (생성 1,141.8초)
CREATE INDEX idx_cover ON od_usage
  (agg_type, time_slot, base_date, start_station_id, end_station_id, total_cnt);

-- 기본 인덱스는 커버링 인덱스의 앞부분과 겹치므로 삭제
DROP INDEX idx_type_time ON od_usage;

-- [튜닝 후] 실행계획
-- 결과: type = range, key = idx_cover, rows = 8,022,532 / 8,572,656, Extra = Using index
-- 실행 시간 46.9초 (EXPLAIN을 지우고 실행)
EXPLAIN
WITH dep AS (
  SELECT start_station_id AS sid, SUM(total_cnt) AS cnt
  FROM od_usage
  WHERE agg_type = '출발시간'
    AND DAYOFWEEK(base_date) BETWEEN 2 AND 6
    AND time_slot >= '0700' AND time_slot < '0900'
  GROUP BY start_station_id
),
arr AS (
  SELECT end_station_id AS sid, SUM(total_cnt) AS cnt
  FROM od_usage
  WHERE agg_type = '도착시간'
    AND DAYOFWEEK(base_date) BETWEEN 2 AND 6
    AND time_slot >= '0700' AND time_slot < '0900'
  GROUP BY end_station_id
)
SELECT d.sid, d.cnt AS 대여, COALESCE(a.cnt, 0) AS 반납,
       d.cnt - COALESCE(a.cnt, 0) AS 순유출
FROM dep d
LEFT JOIN arr a ON d.sid = a.sid
ORDER BY 순유출 DESC
LIMIT 10;

-- [튜닝 2] 요약 테이블: 03_morning_flow.sql의 morning_flow 조회 (0.000초)
