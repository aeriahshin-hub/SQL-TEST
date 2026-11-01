"""
따릉이 2025년 대여소 간 이동 데이터 일괄 적재 스크립트
- BASE_DIR 아래의 모든 하위 폴더(202501 ~ 202512)에서 .csv 파일을 찾아 od_usage 테이블에 적재
- 사용 전: pip install pymysql, sql/01_create_tables.sql 실행
"""
import os
import time
import getpass
import pymysql

# ===== 설정 =====
BASE_DIR = r"data\2025따릉이대여이력"   # 202501~202512 폴더가 들어 있는 원본 CSV 폴더 경로로 수정
TEST_MODE = False   # True: 첫 파일 1개만 적재(테스트) / False: 전체 적재
DB_NAME = "ddareungi"
# ================


def find_csv_files(base_dir):
    files = []
    for root, _, names in os.walk(base_dir):
        for n in names:
            if n.lower().endswith(".csv"):
                files.append(os.path.join(root, n))
    return sorted(files)


def main():
    files = find_csv_files(BASE_DIR)
    if not files:
        print(f"CSV 파일을 찾지 못했어요: {BASE_DIR}")
        return

    if TEST_MODE:
        files = files[:1]
        print("[테스트 모드] 첫 파일 1개만 적재합니다.")

    print(f"적재할 파일 {len(files)}개\n")

    pw = getpass.getpass("MySQL root 비밀번호: ")
    conn = pymysql.connect(host="127.0.0.1", port=3306, user="root", password=pw,
                           database=DB_NAME, charset="utf8mb4",
                           local_infile=True, autocommit=True)
    cur = conn.cursor()
    cur.execute("SET GLOBAL local_infile = 1")

    total_start = time.time()
    total_rows = 0
    failed = []

    for i, path in enumerate(files, 1):
        # 파일마다 줄바꿈(\r\n / \n)이 섞여 있어 항상 \n으로 나누고, 마지막 값의 \r은 제거 (README 트러블슈팅 1)
        sql = f"""
            LOAD DATA LOCAL INFILE '{path.replace(os.sep, '/')}'
            INTO TABLE od_usage
            CHARACTER SET euckr
            FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
            LINES TERMINATED BY '\\n'
            IGNORE 1 LINES
            (@d, agg_type, time_slot, start_station_id, start_station_nm,
             end_station_id, end_station_nm, total_cnt, total_min, @dist)
            SET base_date = STR_TO_DATE(@d, '%Y%m%d'),
                total_dist = TRIM(TRAILING '\\r' FROM @dist)
        """
        t = time.time()
        try:
            rows = cur.execute(sql)
            total_rows += rows
            print(f"[{i}/{len(files)}] {os.path.basename(path)}: {rows:,}행 ({time.time() - t:.1f}초)")
        except Exception as e:
            failed.append(path)
            print(f"[{i}/{len(files)}] 실패 {os.path.basename(path)}: {e}")

    cur.execute("SELECT COUNT(*) FROM od_usage")
    print(f"\n이번 적재: {total_rows:,}행 / 테이블 전체: {cur.fetchone()[0]:,}행")
    print(f"총 소요: {(time.time() - total_start) / 60:.1f}분")
    if failed:
        print("\n실패한 파일:")
        for f in failed:
            print(" -", f)

    conn.close()


if __name__ == "__main__":
    main()
