"""
대여소 정보(station_info.csv)를 station 테이블에 적재하는 스크립트
- station_info.csv를 이 스크립트와 같은 폴더에 두고 실행
"""
import os
import getpass
import pymysql

CSV = os.path.join(os.path.dirname(os.path.abspath(__file__)), "station_info.csv")

pw = getpass.getpass("MySQL root 비밀번호: ")
conn = pymysql.connect(host="127.0.0.1", port=3306, user="root", password=pw,
                       database="ddareungi", charset="utf8mb4",
                       local_infile=True, autocommit=True)
cur = conn.cursor()

cur.execute("DROP TABLE IF EXISTS station")
cur.execute("""
    CREATE TABLE station (
      station_id  VARCHAR(20)  PRIMARY KEY,  -- 이동 데이터의 대여소 ID (ST-xxxx)
      station_no  INT,                       -- 대여소 번호 (현황 파일)
      station_nm  VARCHAR(100),              -- 실제 대여소 이름
      gu          VARCHAR(20),               -- 자치구
      addr        VARCHAR(200),
      lat         DECIMAL(10,7),
      lon         DECIMAL(10,7),
      racks       INT                        -- 거치대 수 (LCD + QR)
    )
""")
cur.execute("SET GLOBAL local_infile = 1")
n = cur.execute(f"""
    LOAD DATA LOCAL INFILE '{CSV.replace(os.sep, '/')}'
    INTO TABLE station
    CHARACTER SET utf8mb4
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\\n'
    IGNORE 1 LINES
    (station_id, station_no, station_nm, gu, addr, lat, lon, @racks)
    SET racks = TRIM(TRAILING '\\r' FROM @racks)
""")
print(f"station 테이블 적재: {n:,}행")
conn.close()
