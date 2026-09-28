import os
import time
import logging
import requests
import pyodbc
from datetime import datetime, timedelta
from tqdm import tqdm
from dotenv import load_dotenv

load_dotenv()
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler("usgs_import.log", encoding="utf-8"),
        logging.StreamHandler()
    ]
)
log = logging.getLogger(__name__)

TURKEY_BBOX = {
    "minlatitude":  35.8,
    "maxlatitude":  42.3,
    "minlongitude": 25.7,
    "maxlongitude": 44.8,
}

USGS_URL   = "https://earthquake.usgs.gov/fdsnws/event/1/query"
START_DATE = "1960-01-01" # 1960 yılından itibaren güncellendi
END_DATE   = datetime.utcnow().strftime("%Y-%m-%d")
MIN_MAG    = 3.5          # 3.5 ve üstü büyüklükler
CHUNK_DAYS = 365          # USGS API limitlerine takılmamak için 1 yıllık dilimler

# Türkiye illeri koordinat tablosu
SEHIRLER = [
    ("Istanbul",       40.5, 42.1, 27.5, 30.5),
    ("Kocaeli",        40.5, 41.5, 29.0, 31.5),
    ("Sakarya",        40.3, 41.0, 30.5, 32.0),
    ("Duzce",          40.2, 40.8, 31.0, 32.0),
    ("Bolu",           40.5, 41.2, 31.5, 33.0),
    ("Bursa",          39.5, 40.5, 29.0, 30.5),
    ("Izmir",          38.0, 39.5, 26.5, 28.5),
    ("Manisa",         38.5, 39.5, 27.5, 29.5),
    ("Aydin",          37.5, 38.5, 27.0, 29.0),
    ("Denizli",        37.0, 38.5, 28.5, 30.0),
    ("Mugla",          36.5, 37.5, 27.5, 30.0),
    ("Afyonkarahisar", 37.5, 39.0, 29.5, 31.5),
    ("Kutahya",        38.5, 39.8, 28.5, 30.5),
    ("Eskisehir",      39.0, 40.0, 30.0, 31.5),
    ("Ankara",         39.0, 40.5, 32.5, 34.5),
    ("Konya",          36.5, 38.5, 31.5, 34.5),
    ("Antalya",        36.0, 37.5, 29.5, 32.5),
    ("Isparta",        37.5, 38.5, 30.0, 31.5),
    ("Burdur",         37.0, 38.0, 29.5, 31.0),
    ("Adana",          36.5, 37.5, 34.5, 36.5),
    ("Mersin",         36.0, 37.5, 32.5, 35.0),
    ("Hatay",          36.0, 37.0, 35.5, 37.0),
    ("Gaziantep",      36.5, 37.5, 36.5, 38.0),
    ("Kahramanmaras",  37.0, 38.5, 36.0, 38.5),
    ("Adiyaman",       37.0, 38.0, 37.5, 39.5),
    ("Malatya",        37.5, 38.8, 37.5, 39.5),
    ("Elazig",         38.0, 39.0, 38.5, 40.5),
    ("Bingol",         38.5, 39.5, 40.0, 41.5),
    ("Mus",            38.5, 39.5, 41.0, 42.5),
    ("Van",            37.5, 39.5, 42.5, 44.5),
    ("Bitlis",         37.5, 38.8, 41.5, 43.0),
    ("Siirt",          37.0, 38.5, 41.5, 42.5),
    ("Hakkari",        37.0, 38.0, 43.0, 44.8),
    ("Sirnak",         37.0, 37.8, 42.0, 43.5),
    ("Mardin",         36.8, 37.8, 40.0, 42.5),
    ("Diyarbakir",     37.5, 38.8, 39.5, 41.5),
    ("Sanliurfa",      36.5, 38.0, 37.5, 40.5),
    ("Kilis",          36.5, 37.2, 36.5, 37.5),
    ("Nigde",          37.5, 38.5, 33.5, 35.5),
    ("Nevsehir",       38.0, 39.0, 34.0, 35.5),
    ("Kayseri",        38.0, 39.5, 35.0, 37.0),
    ("Sivas",          38.5, 40.5, 36.5, 39.5),
    ("Erzincan",       39.2, 40.2, 38.0, 40.0),
    ("Erzurum",        39.5, 41.0, 40.5, 43.0),
    ("Kars",           40.0, 41.5, 42.0, 44.0),
    ("Ardahan",        41.0, 41.5, 42.5, 43.5),
    ("Igdir",          39.5, 40.2, 43.5, 44.8),
    ("Agri",           39.0, 40.0, 42.5, 44.5),
    ("Tunceli",        38.5, 39.5, 39.0, 40.5),
    ("Trabzon",        40.5, 41.5, 38.5, 40.5),
    ("Rize",           40.8, 41.5, 40.0, 41.5),
    ("Artvin",         40.8, 41.5, 41.0, 42.5),
    ("Giresun",        40.3, 41.2, 37.5, 39.5),
    ("Ordu",           40.3, 41.2, 36.5, 38.0),
    ("Samsun",         40.8, 41.8, 35.5, 37.5),
    ("Sinop",          41.0, 42.3, 34.5, 36.0),
    ("Kastamonu",      41.0, 42.1, 33.0, 35.0),
    ("Zonguldak",      41.0, 41.8, 31.5, 32.5),
    ("Bartin",         41.2, 42.0, 32.0, 33.0),
    ("Karabuk",        41.0, 41.5, 32.5, 33.5),
    ("Cankiri",        40.0, 41.0, 33.0, 34.5),
    ("Corum",          40.0, 41.0, 34.0, 35.5),
    ("Amasya",         40.2, 41.0, 35.5, 37.0),
    ("Tokat",          39.5, 40.8, 35.5, 37.5),
    ("Yozgat",         39.0, 40.0, 34.5, 36.5),
    ("Kirikkale",      39.5, 40.2, 33.0, 34.0),
    ("Kirsehir",       38.8, 39.8, 33.5, 35.0),
    ("Aksaray",        37.8, 38.8, 33.0, 34.5),
    ("Karaman",        36.8, 38.0, 32.5, 34.5),
    ("Osmaniye",       36.8, 37.5, 35.5, 37.0),
]

FAY_ATAMALARI = [
    (3, 40.0, 41.5, 27.0, 32.0),   # KAF Bati
    (2, 40.0, 41.0, 32.0, 36.0),   # KAF Orta
    (1, 39.5, 40.5, 36.0, 40.0),   # KAF Dogu
    (4, 37.0, 39.5, 36.0, 42.0),   # DAF
    (5, 37.0, 39.5, 25.5, 28.5),   # Ege
    (6, 38.0, 39.5, 27.0, 29.0),   # Gediz
    (7, 37.5, 38.5, 27.5, 29.5),   # Menderes
    (8, 38.0, 39.0, 38.5, 40.5),   # Palu-Hazar
    (9, 38.5, 39.5, 43.0, 45.0),   # Caldiran
    (10, 38.0, 39.0, 26.5, 28.0),  # Izmir Fay
]

def koordinat_sehir(lat, lon):
    for sehir, min_lat, max_lat, min_lon, max_lon in SEHIRLER:
        if min_lat <= lat <= max_lat and min_lon <= lon <= max_lon:
            return sehir
    return "Turkiye"

def koordinat_fay(lat, lon):
    for fay_id, min_lat, max_lat, min_lon, max_lon in FAY_ATAMALARI:
        if min_lat <= lat <= max_lat and min_lon <= lon <= max_lon:
            return fay_id
    return None

def get_connection():
    server  = os.getenv("DB_SERVER", "localhost")
    db      = os.getenv("DB_NAME", "DepremDB")
    driver  = os.getenv("DB_DRIVER", "ODBC Driver 17 for SQL Server")
    trusted = os.getenv("DB_TRUSTED", "yes").lower() in ("yes","true","1")
    if trusted:
        cs = f"DRIVER={{{driver}}};SERVER={server};DATABASE={db};Trusted_Connection=yes;"
    else:
        cs = f"DRIVER={{{driver}}};SERVER={server};DATABASE={db};UID={os.getenv('DB_USER')};PWD={os.getenv('DB_PASS')};"
    conn = pyodbc.connect(cs, timeout=30)
    conn.autocommit = False
    log.info(f"Veritabani baglantisi kuruldu → {server}/{db}")
    return conn

def fetch_usgs_chunk(start, end):
    params = {
        "format":       "geojson",
        "starttime":    start,
        "endtime":      end,
        "minmagnitude": MIN_MAG,
        "orderby":      "time-asc",
        **TURKEY_BBOX,
    }
    for attempt in range(1, 4):
        try:
            resp = requests.get(USGS_URL, params=params, timeout=60)
            resp.raise_for_status()
            return resp.json().get("features", [])
        except requests.RequestException as e:
            log.warning(f"Deneme {attempt}/3 basarisiz: {e}")
            time.sleep(5 * attempt)
    return []

INSERT_SQL = """
    IF NOT EXISTS (SELECT 1 FROM Deprem WHERE USGS_ID = ?)
    INSERT INTO Deprem (USGS_ID, TarihSaat, Enlem, Boylam, Derinlik, BuyuklukMw, Tip, FayID, Sehir)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
"""

def insert_feature(cursor, feature):
    props   = feature.get("properties", {})
    geom    = feature.get("geometry", {})
    usgs_id = feature.get("id", "")

    if not usgs_id or not props.get("mag") or not geom.get("coordinates"):
        return False

    lon, lat, depth = geom["coordinates"]
    mag   = float(props["mag"])
    ts_ms = props.get("time")
    if not ts_ms:
        return False

    ts    = datetime.utcfromtimestamp(ts_ms / 1000)
    tip   = (props.get("type") or "Tektonik")[:20]
    depth = max(float(depth), 0.0)
    sehir = koordinat_sehir(float(lat), float(lon))
    fay   = koordinat_fay(float(lat), float(lon))

    cursor.execute(INSERT_SQL, (
        usgs_id, usgs_id, ts,
        float(lat), float(lon),
        round(depth, 1), round(mag, 1),
        tip, fay, sehir
    ))
    return cursor.rowcount > 0

def date_chunks(start, end, chunk_days):
    cur = datetime.strptime(start, "%Y-%m-%d")
    fin = datetime.strptime(end,   "%Y-%m-%d")
    while cur < fin:
        nxt = min(cur + timedelta(days=chunk_days - 1), fin)
        yield cur.strftime("%Y-%m-%d"), nxt.strftime("%Y-%m-%d")
        cur = nxt + timedelta(days=1)

def main():
    log.info("=" * 60)
    log.info("USGS → DepremDB aktarimi basliyor")
    log.info(f"Kapsam  : {START_DATE} → {END_DATE}")
    log.info(f"Min Mw  : {MIN_MAG}")
    log.info("=" * 60)

    chunks = list(date_chunks(START_DATE, END_DATE, CHUNK_DAYS))
    total_inserted = 0
    total_skipped  = 0

    conn   = get_connection()
    cursor = conn.cursor()

    try:
        for start, end in tqdm(chunks, desc="Yillik dilimler"):
            features = fetch_usgs_chunk(start, end)
            if not features:
                continue

            batch_ins = 0
            batch_skp = 0
            for f in features:
                try:
                    added = insert_feature(cursor, f)
                    if added:
                        batch_ins += 1
                    else:
                        batch_skp += 1
                except Exception as e:
                    log.error(f"Kayit hatasi ({f.get('id')}): {e}")
                    batch_skp += 1

            conn.commit()
            total_inserted += batch_ins
            total_skipped  += batch_skp
            log.info(f"  {start} → {end}: +{batch_ins} eklendi, {batch_skp} atlandi")
            time.sleep(1)

    except KeyboardInterrupt:
        log.warning("Durduruldu. Kismi commit yapildi.")
        conn.commit()
    finally:
        cursor.close()
        conn.close()

    log.info("=" * 60)
    log.info(f"Aktarim tamamlandi")
    log.info(f"  Eklenen : {total_inserted}")
    log.info(f"  Atlanan : {total_skipped}")
    log.info("=" * 60)

if __name__ == "__main__":
    main()