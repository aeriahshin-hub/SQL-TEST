"""
대여소 정보(거치대 수 포함)와 대여소 마스터 정보를 위도·경도로 1:1 연결해 station_info.csv를 만드는 스크립트

- 대여소 정보(CSV, 2025.12 기준): 대여소 번호, 대여소명, 자치구, 주소, 위도, 경도, 거치대 수 (ID 형식: 00102)
- 대여소 마스터(CSV): 대여소_ID, 주소, 위도, 경도 (ID 형식: ST-2050, 이동 데이터와 같음)
  위도·경도가 0인 대여소는 현재 사용하지 않는 대여소라 미리 제외한 파일을 사용
- 두 데이터의 ID 체계가 달라, 거리가 가까운 쌍부터 50m 이내에서 1:1로 짝지음
- 사용 전: pip install pandas numpy
"""
import numpy as np
import pandas as pd

# ===== 설정 =====
STATUS_CSV = r"data\공공자전거 대여소 정보(25.12월 기준).csv"   # 대여소 정보 파일 경로로 수정
MASTER_CSV = r"data\공공자전거 대여소 마스터 정보.csv"           # 대여소 마스터 파일 경로로 수정
MAX_DIST_M = 50
OUT_CSV = "station_info.csv"
# ================

# 1) 대여소 정보: 첫 줄이 머리글, 앞 10개 열만 사용
x = pd.read_csv(STATUS_CSV, encoding="utf-8-sig", dtype=str).iloc[:, :10]
x.columns = ["station_no", "station_nm", "gu", "addr", "lat", "lon",
             "installed", "lcd", "qr", "op"]
x = x.dropna(subset=["station_no"]).copy()
x["station_no"] = x["station_no"].astype(int)
x["lat"] = x["lat"].astype(float)
x["lon"] = x["lon"].astype(float)
x["racks"] = (pd.to_numeric(x["lcd"], errors="coerce").fillna(0)
              + pd.to_numeric(x["qr"], errors="coerce").fillna(0)).astype(int)   # 거치대 수 = LCD + QR

# 2) 마스터 정보 (좌표가 0인 행이 남아 있으면 제외)
m = pd.read_csv(MASTER_CSV, encoding="utf-8-sig", dtype=str)
m["station_id"] = m["대여소_ID"].str.strip()
m["lat"] = m["위도"].astype(float)
m["lon"] = m["경도"].astype(float)
m = m[(m["lat"] > 0) & (m["lon"] > 0)].reset_index(drop=True)

# 3) 모든 쌍의 거리(m) 계산 (하버사인 공식)
R = 6371000
la1, lo1 = np.radians(m["lat"].values)[:, None], np.radians(m["lon"].values)[:, None]
la2, lo2 = np.radians(x["lat"].values)[None, :], np.radians(x["lon"].values)[None, :]
d = 2 * R * np.arcsin(np.sqrt(np.sin((la2 - la1) / 2) ** 2
                              + np.cos(la1) * np.cos(la2) * np.sin((lo2 - lo1) / 2) ** 2))

# 4) 가까운 쌍부터 1:1로 짝짓기 (이미 짝지어진 대여소는 건너뜀)
pairs = sorted((d[i, j], i, j) for i, j in zip(*np.where(d <= MAX_DIST_M)))
used_m, used_x, matched = set(), set(), []
for dist, i, j in pairs:
    if i in used_m or j in used_x:
        continue
    used_m.add(i)
    used_x.add(j)
    matched.append((i, j))

mi, xj = zip(*matched)
out = pd.concat([
    m.loc[list(mi), ["station_id"]].reset_index(drop=True),
    x.iloc[list(xj)][["station_no", "station_nm", "gu", "addr", "lat", "lon", "racks"]].reset_index(drop=True),
], axis=1)
for c in ["station_nm", "gu", "addr"]:
    out[c] = out[c].astype(str).str.strip()
out = out.sort_values("station_id", key=lambda s: s.str[3:].astype(int))
out.to_csv(OUT_CSV, index=False, encoding="utf-8")

print(f"대여소 정보 {len(x):,}곳 중 {len(out):,}곳 연결 ({len(out) / len(x):.1%}) → {OUT_CSV}")
