-- 06. 2025년 달력 테이블 (주말·공휴일)
-- calendar_2025.csv를 C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/ 에 복사한 뒤 실행

USE ddareungi;

DROP TABLE IF EXISTS calendar;
CREATE TABLE calendar (
  dt          DATE PRIMARY KEY,  -- 날짜
  dow         TINYINT,           -- 요일 (0=월 ~ 6=일)
  is_weekend  TINYINT,           -- 주말 여부
  is_holiday  TINYINT,           -- 공휴일 여부
  is_offday   TINYINT            -- 쉬는 날 (0=평일, 1=주말 또는 공휴일)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/calendar_2025.csv'
INTO TABLE calendar
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(dt, dow, is_weekend, is_holiday, @off)
SET is_offday = TRIM(TRAILING '\r' FROM @off);

-- 확인: 평일 244 / 주중 공휴일 17 / 주말 104
SELECT SUM(is_offday = 0) AS 평일,
       SUM(is_weekend = 0 AND is_holiday = 1) AS 주중_공휴일,
       SUM(is_weekend = 1) AS 주말
FROM calendar;

-- 평일 vs 주말 vs 주중 공휴일: 출근 시간(07~09시) 일평균 대여
SELECT CASE WHEN c.is_weekend = 1 THEN '주말'
            WHEN c.is_holiday = 1 THEN '주중 공휴일'
            ELSE '평일' END AS 구분,
       COUNT(DISTINCT o.base_date) AS 일수,
       ROUND(SUM(o.total_cnt) / COUNT(DISTINCT o.base_date)) AS 출근시간_일평균_대여
FROM od_usage o
JOIN calendar c ON c.dt = o.base_date
WHERE o.agg_type = '출발시간'
  AND o.time_slot >= '0700' AND o.time_slot < '0900'
GROUP BY 구분;

-- 평일(244일) 기준 출근 시간 요약 테이블
-- DAYOFWEEK() 대신 달력 테이블 JOIN으로 평일을 고름
CREATE TABLE morning_flow_work AS
WITH dep AS (
  SELECT o.start_station_id AS sid, SUM(o.total_cnt) AS cnt
  FROM od_usage o
  JOIN calendar c ON c.dt = o.base_date
  WHERE o.agg_type = '출발시간' AND c.is_offday = 0
    AND o.time_slot >= '0700' AND o.time_slot < '0900'
  GROUP BY o.start_station_id
),
arr AS (
  SELECT o.end_station_id AS sid, SUM(o.total_cnt) AS cnt
  FROM od_usage o
  JOIN calendar c ON c.dt = o.base_date
  WHERE o.agg_type = '도착시간' AND c.is_offday = 0
    AND o.time_slot >= '0700' AND o.time_slot < '0900'
  GROUP BY o.end_station_id
)
SELECT d.sid AS station_id, d.cnt AS rent_cnt,
       COALESCE(a.cnt, 0) AS return_cnt,
       d.cnt - COALESCE(a.cnt, 0) AS net_out
FROM dep d
LEFT JOIN arr a ON d.sid = a.sid;

-- 평일 기준 순유출 TOP 10 (순유입은 ORDER BY f.net_out ASC, -f.net_out)
SELECT f.station_id AS 대여소ID,
       s.station_nm AS 대여소명,
       s.gu         AS 자치구,
       f.rent_cnt   AS 대여,
       f.return_cnt AS 반납,
       f.net_out    AS 순유출,
       ROUND(f.net_out / 244, 1) AS 일평균
FROM morning_flow_work f
LEFT JOIN station s ON f.station_id = s.station_id
ORDER BY f.net_out DESC
LIMIT 10;

-- 평일(244일) 기준 퇴근 시간 요약 테이블
CREATE TABLE evening_flow_work AS
WITH dep AS (
  SELECT o.start_station_id AS sid, SUM(o.total_cnt) AS cnt
  FROM od_usage o
  JOIN calendar c ON c.dt = o.base_date
  WHERE o.agg_type = '출발시간' AND c.is_offday = 0
    AND o.time_slot >= '1700' AND o.time_slot < '1900'
  GROUP BY o.start_station_id
),
arr AS (
  SELECT o.end_station_id AS sid, SUM(o.total_cnt) AS cnt
  FROM od_usage o
  JOIN calendar c ON c.dt = o.base_date
  WHERE o.agg_type = '도착시간' AND c.is_offday = 0
    AND o.time_slot >= '1700' AND o.time_slot < '1900'
  GROUP BY o.end_station_id
)
SELECT d.sid AS station_id, d.cnt AS rent_cnt,
       COALESCE(a.cnt, 0) AS return_cnt,
       d.cnt - COALESCE(a.cnt, 0) AS net_out
FROM dep d
LEFT JOIN arr a ON d.sid = a.sid;

-- 평일 기준 퇴근 순유출 TOP 10 (순유입은 ORDER BY f.net_out ASC, -f.net_out)
SELECT s.station_nm AS 대여소명, f.net_out AS 순유출,
       ROUND(f.net_out / 244, 1) AS 일평균
FROM evening_flow_work f
LEFT JOIN station s ON f.station_id = s.station_id
ORDER BY f.net_out DESC
LIMIT 10;
