-- 07. QGIS 지도용 데이터 추출 (평일 244일 기준)
-- 06_calendar.sql의 morning_flow_work, evening_flow_work를 먼저 만든 뒤 실행
-- Workbench에서 Limit을 Don't Limit으로 바꾸고 실행 → Export로 station_flow.csv 저장 → QGIS에서 불러옴

USE ddareungi;

SELECT s.station_id, s.station_nm, s.gu, s.lat, s.lon,
       ROUND(COALESCE(m.net_out, 0) / 244, 1) AS am_net,   -- 출근 일평균 순유출 (+ 비는 곳, - 쌓이는 곳)
       ROUND(COALESCE(e.net_out, 0) / 244, 1) AS pm_net    -- 퇴근 일평균 순유출
FROM station s
LEFT JOIN morning_flow_work m ON m.station_id = s.station_id
LEFT JOIN evening_flow_work e ON e.station_id = s.station_id;
