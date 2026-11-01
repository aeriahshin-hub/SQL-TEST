-- 01. 데이터베이스와 테이블 생성

CREATE DATABASE IF NOT EXISTS ddareungi
  DEFAULT CHARACTER SET utf8mb4;

USE ddareungi;

-- 대여소 간 이동 데이터 (load_ddareungi.py로 적재)
-- 튜닝 전 상태를 측정하기 위해 기본키와 인덱스를 두지 않음
CREATE TABLE od_usage (
  base_date        DATE,          -- 기준_날짜
  agg_type         VARCHAR(10),   -- 집계_기준 (출발시간 / 도착시간)
  time_slot        CHAR(4),       -- 기준_시간대 (0730 = 07:30)
  start_station_id VARCHAR(20),   -- 시작_대여소_ID
  start_station_nm VARCHAR(100),  -- 시작_대여소명
  end_station_id   VARCHAR(20),   -- 종료_대여소_ID
  end_station_nm   VARCHAR(100),  -- 종료_대여소명
  total_cnt        INT,           -- 전체_건수
  total_min        INT,           -- 전체_이용_분
  total_dist       INT            -- 전체_이용_거리(m)
);

-- 대여소 정보 (load_station.py가 생성·적재)
-- CREATE TABLE station (
--   station_id  VARCHAR(20) PRIMARY KEY,  -- 이동 데이터의 대여소 ID (ST-xxxx)
--   station_no  INT,                      -- 대여소 번호
--   station_nm  VARCHAR(100),             -- 대여소명
--   gu          VARCHAR(20),              -- 자치구
--   addr        VARCHAR(200),
--   lat         DECIMAL(10,7),
--   lon         DECIMAL(10,7),
--   racks       INT                       -- 거치대 수
-- );

-- LOAD DATA LOCAL INFILE 허용
SET GLOBAL local_infile = 1;
