import os
import bcrypt
import pyodbc
from functools import wraps
from dotenv import load_dotenv
from flask import Flask, session, redirect, url_for, request, render_template, flash, jsonify
from flask import request, jsonify

load_dotenv()
app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "deprem123")

ROL_ETIKET = {
    "kullanici":         "Kullanici",
    "arastirmaci":       "Arastirmaci",
    "afet_yoneticisi":   "Afet Yoneticisi",
    "sistem_yoneticisi": "Sistem Yoneticisi",
}
ROL_LISTESI = ["kullanici", "arastirmaci", "afet_yoneticisi", "sistem_yoneticisi"]

def get_db():
    server  = os.getenv("DB_SERVER", "localhost")
    db      = os.getenv("DB_NAME", "DepremDB")
    driver  = os.getenv("DB_DRIVER", "ODBC Driver 17 for SQL Server")
    trusted = os.getenv("DB_TRUSTED", "yes").lower() in ("yes","true","1")
    if trusted:
        cs = f"DRIVER={{{driver}}};SERVER={server};DATABASE={db};Trusted_Connection=yes;"
    else:
        cs = f"DRIVER={{{driver}}};SERVER={server};DATABASE={db};UID={os.getenv('DB_USER')};PWD={os.getenv('DB_PASS')};"
    return pyodbc.connect(cs, timeout=10)

def query(sql, params=(), many=True):
    conn = get_db()
    cur = conn.cursor()
    cur.execute(sql, params)
    cols = [c[0] for c in cur.description] if cur.description else []
    rows = [dict(zip(cols, r)) for r in cur.fetchall()]
    conn.close()
    return rows if many else (rows[0] if rows else None)

def execute(sql, params=()):
    conn = get_db()
    cur = conn.cursor()
    cur.execute(sql, params)
    conn.commit()
    conn.close()

def execute_sp(sp_name, **kwargs):
    conn = get_db()
    cur = conn.cursor()
    param_str = ", ".join(f"@{k}=?" for k in kwargs)
    cur.execute(f"EXEC {sp_name} {param_str}", list(kwargs.values()))
    cols = [c[0] for c in cur.description] if cur.description else []
    rows = [dict(zip(cols, r)) for r in cur.fetchall()] if cols else []
    conn.commit()
    conn.close()
    return rows

def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if "kullanici" not in session:
            return redirect(url_for("login"))
        return f(*args, **kwargs)
    return decorated

def rol_gerekli(*roller):
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            if "kullanici" not in session:
                return redirect(url_for("login"))
            k_rol = session["kullanici"].get("rol", "")
            if k_rol not in roller and k_rol != "sistem_yoneticisi":
                flash("Bu sayfaya erisim yetkiniz yok.", "danger")
                return redirect(url_for("dashboard"))
            return f(*args, **kwargs)
        return decorated
    return decorator

@app.route("/logout")
@login_required
def logout():
    kid = session["kullanici"]["id"]
    execute("UPDATE OturumLog SET CikisTarihi = GETDATE() WHERE KullaniciID = ? AND CikisTarihi IS NULL", (kid,))
    session.clear()
    return redirect(url_for("login"))

@app.route("/kriz-masasi")
@rol_gerekli("arastirmaci", "afet_yoneticisi", "sistem_yoneticisi")
def kriz_masasi():
    k = session["kullanici"]
    try:
        # Afet bildirimlerini, gönderen kişinin adıyla birlikte çekiyoruz (JOIN ile)
      # Sadece sorgu kısmını değiştirmen yeterli
        sorgu = """
            SELECT TOP 200 
                a.BildirimID, 
                a.Siddet, 
                a.BinaDurumu, 
                a.EkstraNot, 
                a.Enlem,        -- EKLENDİ
                a.Boylam,       -- EKLENDİ
                CONVERT(VARCHAR(16), a.BildirimZamani, 120) AS TarihSaat,
                k.AdSoyad,
                k.Gmail
            FROM AfetBildirimleri a
            JOIN Kullanici k ON a.KullaniciID = k.KullaniciID
            ORDER BY a.BildirimZamani DESC
        """
        bildirimler = query(sorgu)
    except Exception as e:
        bildirimler = []
        flash(f"Veriler çekilirken hata oluştu: {e}", "danger")
    
    return render_template("kriz_masasi.html", kullanici=k, bildirimler=bildirimler)

@app.route("/", methods=["GET", "POST"])
def login():
    if "kullanici" in session:
        return redirect(url_for("dashboard"))
    if request.method == "POST":
        gmail = request.form.get("gmail", "").strip().lower()
        sifre = request.form.get("sifre", "").strip()
        if not gmail or not sifre:
            flash("Gmail ve sifre bos birakilamaz.", "danger")
            return render_template("login.html")
        kullanici = query("SELECT * FROM Kullanici WHERE Gmail = ?", (gmail,), many=False)
        if not kullanici:
            flash("Bu Gmail adresi kayitli degil.", "danger")
            return render_template("login.html")
        if not kullanici.get("AktifMi"):
            flash("Hesabiniz devre disi.", "danger")
            return render_template("login.html")
        sifre_hash = kullanici.get("SifreHash") or ""
        if not sifre_hash or not bcrypt.checkpw(sifre.encode(), sifre_hash.encode()):
            flash("Sifre hatali.", "danger")
            return render_template("login.html")
        execute("UPDATE Kullanici SET SonGiris = GETDATE() WHERE KullaniciID = ?", (kullanici["KullaniciID"],))
        execute("INSERT INTO OturumLog (KullaniciID, IPAdresi, UserAgent) VALUES (?,?,?)",
                (kullanici["KullaniciID"], request.remote_addr, request.user_agent.string[:300]))
        session["kullanici"] = {
            "id":     kullanici["KullaniciID"],
            "gmail":  gmail,
            "ad":     kullanici["AdSoyad"],
            "rol":    kullanici["Rol"],
            "etiket": ROL_ETIKET.get(kullanici["Rol"], kullanici["Rol"]),
        }
        return redirect(url_for("dashboard"))
    return render_template("login.html")

@app.route("/kayit", methods=["GET", "POST"])
def kayit():
    if "kullanici" in session:
        return redirect(url_for("dashboard"))
    if request.method == "POST":
        ad_soyad = request.form.get("ad_soyad", "").strip()
        gmail    = request.form.get("gmail", "").strip().lower()
        sifre    = request.form.get("sifre", "").strip()
        sifre2   = request.form.get("sifre2", "").strip()
        if not ad_soyad or not gmail or not sifre:
            flash("Tum alanlar zorunludur.", "danger")
            return render_template("kayit.html")
        if not gmail.endswith("@gmail.com"):
            flash("Sadece Gmail adresi ile kayit olunabilir.", "danger")
            return render_template("kayit.html")
        if sifre != sifre2:
            flash("Sifreler eslesmıyor.", "danger")
            return render_template("kayit.html")
        if len(sifre) < 6:
            flash("Sifre en az 6 karakter olmalidir.", "danger")
            return render_template("kayit.html")
        mevcut = query("SELECT KullaniciID FROM Kullanici WHERE Gmail = ?", (gmail,), many=False)
        if mevcut:
            flash("Bu Gmail adresi zaten kayitli.", "warning")
            return render_template("kayit.html")
        sifre_hash = bcrypt.hashpw(sifre.encode(), bcrypt.gensalt()).decode()
        execute("INSERT INTO Kullanici (Gmail, AdSoyad, Rol, SifreHash) VALUES (?, ?, 'kullanici', ?)",
                (gmail, ad_soyad, sifre_hash))
        flash("Kayit basarili! Giris yapabilirsiniz.", "success")
        return redirect(url_for("login"))
    return render_template("kayit.html")

@app.route("/api/bildirim-gonder", methods=["POST"])
def bildirim_gonder():
    if "kullanici" not in session:
        return jsonify({"durum": "hata", "mesaj": "Lütfen önce sisteme giriş yapın!"}), 401

    try:
        gelen_veri = request.get_json()
        siddet = gelen_veri.get("siddet")
        bina_durumu = gelen_veri.get("binaDurumu")
        ekstra_not = gelen_veri.get("ekstraNot")
        
        # YENİ EKLENEN KONUM VERİLERİ
        enlem = gelen_veri.get("enlem")
        boylam = gelen_veri.get("boylam")
        
        kullanici_id = session["kullanici"]["id"]

        # SQL sorgusuna Enlem ve Boylam eklendi
        sorgu = """
            INSERT INTO AfetBildirimleri (KullaniciID, Siddet, BinaDurumu, EkstraNot, Enlem, Boylam, BildirimZamani)
            VALUES (?, ?, ?, ?, ?, ?, GETDATE())
        """
        execute(sorgu, (kullanici_id, siddet, bina_durumu, ekstra_not, enlem, boylam))

        return jsonify({"durum": "basarili", "mesaj": "Durumunuz ve konumunuz merkeze başarıyla iletildi."})

    except Exception as e:
        print("------------- SQL KAYIT HATASI -------------")
        print("Hata Detayı:", str(e))
        return jsonify({"durum": "hata", "mesaj": "Veritabanına kaydedilemedi."}), 500

@app.route("/dashboard")
@login_required
def dashboard():
    k = session["kullanici"]
    stats = {}
    try:
        r = query("SELECT COUNT(*) AS n FROM Deprem", many=False)
        stats["toplam_deprem"] = r["n"] if r else 0
        r = query("SELECT COUNT(*) AS n FROM Deprem WHERE BuyuklukMw >= 5.0", many=False)
        stats["buyuk_deprem"] = r["n"] if r else 0
        r = query("SELECT MAX(BuyuklukMw) AS m FROM Deprem", many=False)
        stats["max_buyukluk"] = r["m"] if r else "-"
        r = query("SELECT COUNT(*) AS n FROM Kullanici", many=False)
        stats["toplam_kullanici"] = r["n"] if r else 0
        r = query("SELECT COUNT(*) AS n FROM Deprem WHERE TarihSaat >= DATEADD(HOUR,-24,GETDATE())", many=False)
        stats["son24"] = r["n"] if r else 0
        r = query("SELECT ISNULL(SUM(OlumSayisi),0) AS n FROM HasarKaydi", many=False)
        stats["toplam_olum"] = r["n"] if r else 0
        if k["rol"] in ("arastirmaci", "afet_yoneticisi", "sistem_yoneticisi"):
            r = query("SELECT ISNULL(SUM(YaraliSayisi),0) AS n FROM HasarKaydi", many=False)
            stats["toplam_yarali"] = r["n"] if r else 0
        if k["rol"] in ("afet_yoneticisi", "sistem_yoneticisi"):
            r = query("SELECT ISNULL(SUM(YikilanBina),0) AS n FROM HasarKaydi", many=False)
            stats["toplam_bina"] = r["n"] if r else 0
    except Exception as e:
        stats["hata"] = str(e)

    en_buyuk = []
    try:
        en_buyuk = query("""
            SELECT TOP 10
                d.DepremID,
                CONVERT(VARCHAR(10), d.TarihSaat, 23) AS Tarih,
                d.BuyuklukMw, d.Sehir, d.Derinlik,
                f.FayAdi,
                ISNULL(SUM(h.OlumSayisi),0)   AS OlumSayisi,
                ISNULL(SUM(h.YaraliSayisi),0) AS YaraliSayisi,
                ISNULL(SUM(h.YikilanBina),0)  AS YikilanBina
            FROM Deprem d
            LEFT JOIN FayHatti f  ON d.FayID    = f.FayID
            LEFT JOIN HasarKaydi h ON d.DepremID = h.DepremID
            GROUP BY d.DepremID, d.TarihSaat, d.BuyuklukMw, d.Sehir, d.Derinlik, f.FayAdi
            ORDER BY d.BuyuklukMw DESC
        """)
    except:
        pass

    son_depremler = []
    try:
        son_depremler = query("""
            SELECT TOP 10
                CONVERT(VARCHAR(19), TarihSaat, 120) AS TarihSaat,
                BuyuklukMw, Sehir, Derinlik
            FROM Deprem
            ORDER BY TarihSaat DESC
        """)
    except:
        pass

    hasar_kayitlari = []
    try:
        hasar_kayitlari = query("""
            SELECT TOP 20 * FROM vw_HasarOzeti
            ORDER BY OlumSayisi DESC
        """)
    except:
        pass

    return render_template("dashboard.html", kullanici=k, stats=stats,
                           en_buyuk=en_buyuk, son_depremler=son_depremler,
                           hasar_kayitlari=hasar_kayitlari)

@app.route("/depremler")
@login_required
def depremler():
    k      = session["kullanici"]
    min_mw = request.args.get("min_mw", "3.5")
    bas    = request.args.get("bas", "1964-01-01")
    bitis  = request.args.get("bitis", "2024-12-31")
    sehir  = request.args.get("sehir", "")
    siralama = request.args.get("siralama", "tarih")

    try:
        if siralama == "hasar":
            rows = query("""
                SELECT TOP 500
                    d.DepremID,
                    CONVERT(VARCHAR(19), d.TarihSaat, 120) AS TarihSaat,
                    d.Enlem, d.Boylam, d.Derinlik,
                    d.BuyuklukMw, d.Tip, d.Sehir,
                    f.FayAdi,
                    ISNULL(SUM(h.OlumSayisi),0)   AS ToplamOlum,
                    ISNULL(SUM(h.YaraliSayisi),0) AS ToplamYarali,
                    ISNULL(SUM(h.YikilanBina),0)  AS ToplamBina
                FROM Deprem d
                LEFT JOIN FayHatti f   ON d.FayID    = f.FayID
                LEFT JOIN HasarKaydi h ON d.DepremID = h.DepremID
                WHERE d.BuyuklukMw >= ? AND d.TarihSaat BETWEEN ? AND ?
                GROUP BY d.DepremID, d.TarihSaat, d.Enlem, d.Boylam,
                         d.Derinlik, d.BuyuklukMw, d.Tip, d.Sehir, f.FayAdi
                HAVING ISNULL(SUM(h.OlumSayisi),0) > 0
                ORDER BY ToplamOlum DESC
            """, (float(min_mw), bas, bitis))
        elif siralama == "buyukluk":
            rows = execute_sp("sp_DepremSorgula", BasTarih=bas, BitisTarih=bitis,
                              MinBuyukluk=float(min_mw), MaxBuyukluk=9.9)
            rows = sorted(rows, key=lambda x: float(x.get("BuyuklukMw") or 0), reverse=True)
        else:
            rows = execute_sp("sp_DepremSorgula", BasTarih=bas, BitisTarih=bitis,
                              MinBuyukluk=float(min_mw), MaxBuyukluk=9.9)

        if sehir:
            rows = [r for r in rows if r.get("Sehir","").lower() == sehir.lower()]
        rows = rows[:500]

    except Exception as e:
        rows = []
        flash(f"Sorgu hatasi: {e}", "danger")

    sehir_listesi = []
    try:
        sehir_listesi = query("SELECT DISTINCT Sehir FROM Deprem WHERE Sehir IS NOT NULL ORDER BY Sehir")
    except:
        pass

    return render_template("depremler.html", kullanici=k, depremler=rows,
                           min_mw=min_mw, bas=bas, bitis=bitis,
                           sehir=sehir, sehir_listesi=sehir_listesi,
                           siralama=siralama)

@app.route("/rehber")
def rehber():
    # Sadece giriş yapmış kullanıcılar görebilsin
    if "kullanici" not in session:
        flash("Lütfen önce giriş yapın.", "warning")
        return redirect("/")
    
    # Giriş yapan kullanıcının verileriyle sayfayı render et
    return render_template("rehber.html", kullanici=session["kullanici"])

@app.route("/faylar")
@login_required
def faylar():
    k = session["kullanici"]
    try:
        fay_listesi = query("""
            SELECT f.FayID, f.FayAdi, f.Tip, f.Uzunluk_km, f.AktifMi,
                   COUNT(d.DepremID)    AS ToplamDeprem,
                   MAX(d.BuyuklukMw)   AS MaxBuyukluk,
                   AVG(d.BuyuklukMw)   AS OrtBuyukluk
            FROM FayHatti f
            LEFT JOIN Deprem d ON f.FayID = d.FayID
            GROUP BY f.FayID, f.FayAdi, f.Tip, f.Uzunluk_km, f.AktifMi
            ORDER BY ToplamDeprem DESC
        """)
    except Exception as e:
        fay_listesi = []
        flash(f"Hata: {e}", "danger")
    return render_template("faylar.html", kullanici=k, fay_listesi=fay_listesi)

@app.route("/harita")
@login_required
def harita():
    k = session["kullanici"]
    return render_template("harita.html", kullanici=k)

@app.route("/api/harita-verisi")
@login_required
def api_harita_verisi():
    min_mw = float(request.args.get("min_mw", "4.0"))
    try:
        rows = query("""
            SELECT TOP 2000
                DepremID, Enlem, Boylam, BuyuklukMw, Derinlik,
                Sehir, Tip,
                CONVERT(VARCHAR(19), TarihSaat, 120) AS TarihSaat
            FROM Deprem
            WHERE BuyuklukMw >= ? AND Enlem IS NOT NULL AND Boylam IS NOT NULL
            ORDER BY TarihSaat DESC
        """, (min_mw,))
        for r in rows:
            for k2, v in r.items():
                if hasattr(v, 'item'):
                    r[k2] = v.item()
        return jsonify(rows)
    except Exception as e:
        return jsonify([])

@app.route("/api/son-depremler")
@login_required
def api_son_depremler():
    try:
        rows = query("""
            SELECT TOP 10
                CONVERT(VARCHAR(19), TarihSaat, 120) AS TarihSaat,
                BuyuklukMw, Sehir, Derinlik
            FROM Deprem
            ORDER BY TarihSaat DESC
        """)
        for r in rows:
            for k2, v in r.items():
                if hasattr(v, 'item'):
                    r[k2] = v.item()
        return jsonify(rows)
    except Exception as e:
        return jsonify([])

    

@app.route("/istatistik")
@rol_gerekli("arastirmaci", "afet_yoneticisi", "sistem_yoneticisi")
def istatistik():
    k   = session["kullanici"]
    yil = int(request.args.get("yil", 2023))
    try:
        aylik  = execute_sp("sp_YillikDepremOzeti", Yil=yil)
        fay    = query("SELECT * FROM vw_FayIstatistikleri ORDER BY ToplamDepremSayisi DESC")
        yillik = query("SELECT * FROM vw_YillikIstatistik ORDER BY Yil DESC")
        sehir_dagilim = query("""
            SELECT TOP 15 Sehir, COUNT(*) AS Sayi, MAX(BuyuklukMw) AS EnBuyuk
            FROM Deprem WHERE Sehir IS NOT NULL
            GROUP BY Sehir ORDER BY Sayi DESC
        """)
        hasar_veri = query("""
            SELECT TOP 5 y.Il, SUM(h.OlumSayisi) AS ToplamOlu, SUM(h.YikilanBina) AS ToplamBina 
            FROM HasarKaydi h 
            JOIN YerlesimBirimi y ON h.YerlesimID = y.YerlesimID 
            GROUP BY y.Il 
            ORDER BY ToplamOlu DESC
        """)

    except Exception as e:
        aylik, fay, yillik, sehir_dagilim = [], [], [], []
        flash(f"Hata: {e}", "danger")
    return render_template("istatistik.html", kullanici=k, aylik=aylik,
                           fay=fay, yillik=yillik, secili_yil=yil,
                           sehir_dagilim=sehir_dagilim, hasar_veri=hasar_veri)

@app.route("/hasar")
@login_required
def hasar():
    k = session["kullanici"]
    il_filtre = request.args.get("il_filtre", "").strip()
    min_mw    = request.args.get("min_mw", "").strip()
    min_olu   = request.args.get("min_olu", "").strip()
    try:
        hasar_list = query("SELECT * FROM vw_HasarOzeti ORDER BY OlumSayisi DESC")
        toplam = query("""
            SELECT 
                ISNULL(SUM(OlumSayisi),0)   AS OlumSayisi,
                ISNULL(SUM(YaraliSayisi),0) AS YaraliSayisi,
                ISNULL(SUM(YikilanBina),0)  AS YikilanBina
            FROM HasarKaydi
        """, many=False)
        zemin = query("""
            SELECT y.Il, y.Ilce, z.ZeminSinifi, z.Vs30,
                   t.PGA, t.TehlikeSeviyesi, r.RiskSkoru
            FROM YerlesimBirimi y
            JOIN ZeminBilgisi z ON y.YerlesimID = z.YerlesimID
            JOIN TehlikeParametresi t ON y.YerlesimID = t.YerlesimID
            JOIN RiskAnalizi r ON y.YerlesimID = r.YerlesimID
            ORDER BY r.RiskSkoru DESC
        """)

        # Filtreleme
        hasar_filtered = list(hasar_list)
        if il_filtre:
            hasar_filtered = [h for h in hasar_filtered
                              if il_filtre.lower() in str(h.get("Il","")).lower()]
        if min_mw:
            hasar_filtered = [h for h in hasar_filtered
                              if float(h.get("BuyuklukMw") or 0) >= float(min_mw)]
        if min_olu:
            hasar_filtered = [h for h in hasar_filtered
                              if int(h.get("OlumSayisi") or 0) >= int(min_olu)]

    except Exception as e:
        hasar_list, hasar_filtered, toplam, zemin = [], [], {}, []
        flash(f"Hata: {e}", "danger")

    sorgu = """
        SELECT 
            d.BuyuklukMw,
            CONVERT(VARCHAR(10), d.TarihSaat, 23) AS DepremTarihi,
            y.Il,
            y.Ilce,
            h.OlumSayisi,
            h.YaraliSayisi,
            h.YikilanBina,
            (h.OlumSayisi + h.YaraliSayisi) AS ToplamKayip
        FROM HasarKaydi h
        JOIN Deprem d ON h.DepremID = d.DepremID
        JOIN YerlesimBirimi y ON h.YerlesimID = y.YerlesimID
        ORDER BY h.OlumSayisi DESC, d.BuyuklukMw DESC
    """
    
    hasar_kayitlari = query(sorgu)

    return render_template("hasar.html", kullanici=k,
                           hasar=hasar_list,
                           hasar_filtered=hasar_filtered,
                           toplam=toplam, zemin=zemin,
                           il_filtre=il_filtre, min_mw=min_mw, min_olu=min_olu)

@app.route("/risk")
@rol_gerekli("afet_yoneticisi", "sistem_yoneticisi")
def risk():
    k         = session["kullanici"]
    il        = request.args.get("il", "").strip()
    deprem_id = request.args.get("deprem_id", "").strip()
    aktif_tab = request.args.get("aktif_tab", "risk")

    try:
        yuksek = query("SELECT * FROM vw_YuksekRiskliYerlesimler ORDER BY RiskSkoru DESC")
        if il:
            yuksek = [r for r in yuksek if il.lower() in r.get("Il","").lower()]

        zemin = query("""
            SELECT y.Il, y.Ilce, z.ZeminSinifi, z.Vs30,
                   t.PGA, t.TehlikeSeviyesi, r.RiskSkoru
            FROM YerlesimBirimi y
            JOIN ZeminBilgisi z ON y.YerlesimID = z.YerlesimID
            JOIN TehlikeParametresi t ON y.YerlesimID = t.YerlesimID
            JOIN RiskAnalizi r ON y.YerlesimID = r.YerlesimID
            ORDER BY r.RiskSkoru DESC
        """)

        etki = []
        if deprem_id and deprem_id.isdigit():
            try:
                etki = execute_sp("sp_DepremEtkiAnalizi", DepremID=int(deprem_id))
            except Exception as e:
                flash(f"Etki analizi hatasi: {e}", "danger")

    except Exception as e:
        yuksek, zemin, etki = [], [], []
        flash(f"Hata: {e}", "danger")

    return render_template("risk.html", kullanici=k,
                           yuksek=yuksek, zemin=zemin,
                           etki=etki, il=il,
                           deprem_id=deprem_id,
                           aktif_tab=aktif_tab)
                           
@app.route("/yonetim")
@rol_gerekli("sistem_yoneticisi")
def yonetim():
    k = session["kullanici"]
    try:
        kullanicilar = query("SELECT KullaniciID, Gmail, AdSoyad, Rol, AktifMi, SonGiris FROM Kullanici ORDER BY KayitTarihi DESC")
        uyarilar     = query("SELECT TOP 20 * FROM DepremUyariLog ORDER BY LogZamani DESC")
        loglar       = query("SELECT TOP 50 * FROM vw_KullaniciAktivite ORDER BY GirisTarihi DESC")
    except Exception as e:
        kullanicilar, uyarilar, loglar = [], [], []
        flash(f"Hata: {e}", "danger")
    return render_template("yonetim.html", kullanici=k, kullanicilar=kullanicilar,
                           uyarilar=uyarilar, loglar=loglar, rol_listesi=ROL_LISTESI)

@app.route("/yonetim/rol-guncelle", methods=["POST"])
@rol_gerekli("sistem_yoneticisi")
def rol_guncelle():
    hedef_gmail = request.form.get("gmail")
    yeni_rol    = request.form.get("rol")
    yapan_id    = session["kullanici"]["id"]
    sonuc = execute_sp("sp_RolGuncelle", HedefGmail=hedef_gmail, YeniRol=yeni_rol, IslemYapanID=yapan_id)
    if sonuc and sonuc[0].get("Sonuc") == 1:
        flash(f"{hedef_gmail} guncellendi.", "success")
    else:
        flash("Hata olustu.", "danger")
    return redirect(url_for("yonetim"))

@app.route("/yonetim/kullanici-durum", methods=["POST"])
@rol_gerekli("sistem_yoneticisi")
def kullanici_durum():
    kid   = request.form.get("kid")
    aktif = request.form.get("aktif")
    execute("UPDATE Kullanici SET AktifMi = ? WHERE KullaniciID = ?", (aktif, kid))
    flash("Kullanici durumu guncellendi.", "success")
    return redirect(url_for("yonetim"))

if __name__ == "__main__":
    app.run(debug=True, port=5000)