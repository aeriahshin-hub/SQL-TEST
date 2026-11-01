-- 04. 주중 퇴근 시간(17:00~18:59) 분석

USE ddareungi;

-- 1) 퇴근 시간 대여 TOP 5 (출발시간 기준) + 대여소명
WITH eve AS (
  SELECT start_station_id AS sid, SUM(total_cnt) AS cnt
  FROM od_usage
  WHERE agg_type = '출발시간'
    AND DAYOFWEEK(base_date) BETWEEN 2 AND 6
    AND time_slot >= '1700' AND time_slot < '1900'
  GROUP BY start_station_id
)
SELECT e.sid, s.station_nm, s.gu, e.cnt
FROM eve e
LEFT JOIN station s ON s.station_id = e.sid
ORDER BY e.cnt DESC
LIMIT 5;

-- 2) 퇴근 시간 반납 TOP 5 (도착시간 기준) + 대여소명
WITH eve AS (
  SELECT end_station_id AS sid, SUM(total_cnt) AS cnt
  FROM od_usage
  WHERE agg_type = '도착시간'
    AND DAYOFWEEK(base_date) BETWEEN 2 AND 6
    AND time_slot >= '1700' AND time_slot < '1900'
  GROUP BY end_station_id
)
SELECT e.sid, s.station_nm, s.gu, e.cnt
FROM eve e
LEFT JOIN station s ON s.station_id = e.sid
ORDER BY e.cnt DESC
LIMIT 5;

-- 3) 퇴근 시간 대여소별 순유출 집계 (요약 테이블)
CREATE TABLE evening_flow AS
WITH dep AS (
  SELECT start_station_id AS sid, SUM(total_cnt) AS cnt
  FROM od_usage
  WHERE agg_type = '출발시간'
    AND DAYOFWEEK(base_date) BETWEEN 2 AND 6
    AND time_slot >= '1700' AND time_slot < '1900'
  GROUP BY start_station_id
),
arr AS (
  SELECT end_station_id AS sid, SUM(total_cnt) AS cnt
  FROM od_usage
  WHERE agg_type = '도착시간'
    AND DAYOFWEEK(base_date) BETWEEN 2 AND 6
    AND time_slot >= '1700' AND time_slot < '1900'
  GROUP BY end_station_id
)
SELECT d.sid AS station_id,
       d.cnt AS rent_cnt,
       COALESCE(a.cnt, 0) AS return_cnt,
       d.cnt - COALESCE(a.cnt, 0) AS net_out
FROM dep d
LEFT JOIN arr a ON d.sid = a.sid;

-- 4) 퇴근 시간 순유출 TOP 10: 자전거가 비는 곳
SELECT f.station_id AS 대여소ID,
       s.station_nm AS 대여소명,
       s.gu         AS 자치구,
       f.rent_cnt   AS 대여,
       f.return_cnt AS 반납,
       f.net_out    AS 순유출,
       ROUND(f.net_out / 261, 1) AS 일평균
FROM evening_flow f
LEFT JOIN station s ON f.station_id = s.station_id
ORDER BY f.net_out DESC
LIMIT 10;

-- 5) 퇴근 시간 순유입 TOP 10: 자전거가 쌓이는 곳
SELECT f.station_id AS 대여소ID,
       s.station_nm AS 대여소명,
       s.gu         AS 자치구,
       f.rent_cnt   AS 대여,
       f.return_cnt AS 반납,
       -f.net_out   AS 순유입,
       ROUND(-f.net_out / 261, 1) AS 일평균
FROM evening_flow f
LEFT JOIN station s ON f.station_id = s.station_id
ORDER BY f.net_out ASC
LIMIT 10;
