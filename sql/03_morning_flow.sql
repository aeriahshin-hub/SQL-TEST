-- 03. 주중 출근 시간(07:00~08:59) 대여소별 순유출 분석

USE ddareungi;

-- 1) 대여소별 대여·반납·순유출 집계 (요약 테이블로 저장)
--    대여: 출발시간 행, 출발 대여소 기준 / 반납: 도착시간 행, 도착 대여소 기준
CREATE TABLE morning_flow AS
WITH dep AS (
  SELECT start_station_id AS sid, SUM(total_cnt) AS cnt
  FROM od_usage
  WHERE agg_type = '출발시간'
    AND DAYOFWEEK(base_date) BETWEEN 2 AND 6        -- 월~금
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
SELECT d.sid AS station_id,
       d.cnt AS rent_cnt,
       COALESCE(a.cnt, 0) AS return_cnt,              -- 반납이 없으면 0
       d.cnt - COALESCE(a.cnt, 0) AS net_out
FROM dep d
LEFT JOIN arr a ON d.sid = a.sid;

-- 2) 순유출 TOP 10: 자전거가 비는 곳
SELECT f.station_id AS 대여소ID,
       s.station_nm AS 대여소명,
       s.gu         AS 자치구,
       f.rent_cnt   AS 대여,
       f.return_cnt AS 반납,
       f.net_out    AS 순유출,
       ROUND(f.net_out / 261, 1) AS 일평균          -- 2025년 주중 261일
FROM morning_flow f
LEFT JOIN station s ON f.station_id = s.station_id  -- 연결 안 된 대여소도 남기기 위해 LEFT JOIN
ORDER BY f.net_out DESC
LIMIT 10;

-- 3) 순유입 TOP 10: 자전거가 쌓이는 곳
SELECT f.station_id AS 대여소ID,
       s.station_nm AS 대여소명,
       s.gu         AS 자치구,
       f.rent_cnt   AS 대여,
       f.return_cnt AS 반납,
       -f.net_out   AS 순유입,
       ROUND(-f.net_out / 261, 1) AS 일평균
FROM morning_flow f
LEFT JOIN station s ON f.station_id = s.station_id
ORDER BY f.net_out ASC
LIMIT 10;
