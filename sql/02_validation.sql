-- 02. 적재 결과 검증

USE ddareungi;

-- 월별 행 수와 일수 (트러블슈팅: 8개월치가 하루 1행씩만 적재된 문제 발견)
SELECT DATE_FORMAT(base_date, '%Y-%m') AS 월,
       COUNT(*) AS 행수,
       COUNT(DISTINCT base_date) AS 일수
FROM od_usage
GROUP BY 월
ORDER BY 월;

-- 집계 기준별 월별 건수 비교 (출발시간 / 도착시간: 10개월 동일, 6·9월 소폭 차이)
SELECT DATE_FORMAT(base_date, '%Y-%m') AS 월,
       SUM(CASE WHEN agg_type = '출발시간' THEN total_cnt ELSE 0 END) AS 출발시간_건수,
       SUM(CASE WHEN agg_type = '도착시간' THEN total_cnt ELSE 0 END) AS 도착시간_건수
FROM od_usage
GROUP BY 월
ORDER BY 월;

-- 하루치 행 단위 비교: 출발시간 행과 도착시간 행을 짝지어 시간대 차이 확인
CREATE TEMPORARY TABLE dep_day AS
SELECT start_station_id, end_station_id, total_min, total_dist, time_slot,
       LEFT(time_slot, 2) * 60 + RIGHT(time_slot, 2) AS t
FROM od_usage
WHERE agg_type = '출발시간' AND base_date = '2025-06-02' AND total_cnt = 1;

CREATE TEMPORARY TABLE arr_day AS
SELECT start_station_id, end_station_id, total_min, total_dist, time_slot,
       LEFT(time_slot, 2) * 60 + RIGHT(time_slot, 2) AS t
FROM od_usage
WHERE agg_type = '도착시간' AND base_date = '2025-06-02' AND total_cnt = 1;

SELECT d.start_station_id, d.end_station_id, d.total_min, d.total_dist,
       d.time_slot AS 출발_시간대, a.time_slot AS 도착_시간대,
       a.t - d.t   AS 시간대_차이_분
FROM dep_day d
JOIN arr_day a
  ON  a.start_station_id = d.start_station_id
  AND a.end_station_id   = d.end_station_id
  AND a.total_min        = d.total_min
  AND a.total_dist       = d.total_dist
  AND a.t - d.t BETWEEN d.total_min - 5 AND d.total_min + 5
LIMIT 20;

-- 월별 이용 건수 (이중 기록을 피하기 위해 출발시간 행만 합산)
SELECT DATE_FORMAT(base_date, '%Y-%m') AS 월,
       SUM(total_cnt) AS 이용건수
FROM od_usage
WHERE agg_type = '출발시간'
GROUP BY 월
ORDER BY 월;
