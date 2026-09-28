-- ================================================================
-- DEPREM VERİTABANI — TAM SQL SERVER PROJESİ
-- Coğrafi Kapsam : Türkiye (USGS verisi)
-- Zaman Aralığı  : 1964 - 2024 (60 Yıl)
-- Min Büyüklük   : Mw >= 3.5
-- ================================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'DepremDB')
BEGIN
    ALTER DATABASE DepremDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DepremDB;
END
GO

CREATE DATABASE DepremDB COLLATE Turkish_CI_AS;
GO
USE DepremDB;
GO

-- ================================================================
-- BÖLÜM 1: TABLOLAR
-- ================================================================

-- 1. FayHatti
CREATE TABLE FayHatti (
    FayID      INT          PRIMARY KEY IDENTITY(1,1),
    FayAdi     VARCHAR(100) NOT NULL,
    Tip        VARCHAR(50),
    Uzunluk_km DECIMAL(5,1),
    AktifMi    BIT          DEFAULT 1
);
GO

-- 2. Deprem
CREATE TABLE Deprem (
    DepremID   INT           PRIMARY KEY IDENTITY(1,1),
    USGS_ID    VARCHAR(30)   UNIQUE,          -- USGS orijinal ID (tekrar import engeli)
    TarihSaat  DATETIME      NOT NULL,
    Enlem      DECIMAL(9,6)  NOT NULL,
    Boylam     DECIMAL(9,6)  NOT NULL,
    Derinlik   DECIMAL(4,1)  NOT NULL,
    BuyuklukMw DECIMAL(3,1)  NOT NULL,
    Tip        VARCHAR(20),
    FayID      INT           FOREIGN KEY REFERENCES FayHatti(FayID)
);
GO

-- 3. YerlesimBirimi
CREATE TABLE YerlesimBirimi (
    YerlesimID INT          PRIMARY KEY IDENTITY(1,1),
    Il         VARCHAR(50)  NOT NULL,
    Ilce       VARCHAR(80)  NOT NULL,
    Mahalle    VARCHAR(80),
    Nufus      INT
);
GO

-- 4. ZeminBilgisi
CREATE TABLE ZeminBilgisi (
    ZeminID     INT          PRIMARY KEY IDENTITY(1,1),
    YerlesimID  INT          NOT NULL FOREIGN KEY REFERENCES YerlesimBirimi(YerlesimID),
    ZeminSinifi VARCHAR(5)   NOT NULL,  -- ZA...ZF
    Vs30        DECIMAL(5,1)
);
GO

-- 5. TehlikeParametresi
CREATE TABLE TehlikeParametresi (
    TehlikeID       INT           PRIMARY KEY IDENTITY(1,1),
    YerlesimID      INT           NOT NULL FOREIGN KEY REFERENCES YerlesimBirimi(YerlesimID),
    PGA             DECIMAL(4,2)  NOT NULL,
    TehlikeSeviyesi VARCHAR(20)
);
GO

-- 6. HasarKaydi
CREATE TABLE HasarKaydi (
    HasarID      INT  PRIMARY KEY IDENTITY(1,1),
    DepremID     INT  NOT NULL FOREIGN KEY REFERENCES Deprem(DepremID),
    YerlesimID   INT  NOT NULL FOREIGN KEY REFERENCES YerlesimBirimi(YerlesimID),
    OlumSayisi   INT  DEFAULT 0,
    YaraliSayisi INT  DEFAULT 0,
    YikilanBina  INT  DEFAULT 0
);
GO

-- 7. RiskAnalizi
CREATE TABLE RiskAnalizi (
    RiskID          INT           PRIMARY KEY IDENTITY(1,1),
    YerlesimID      INT           NOT NULL FOREIGN KEY REFERENCES YerlesimBirimi(YerlesimID),
    RiskSkoru       DECIMAL(4,2)  NOT NULL,
    HesaplamaTarihi DATE          NOT NULL
);
GO

-- 8. Deprem_Yerlesim (N:N)
CREATE TABLE Deprem_Yerlesim (
    DepremID     INT         NOT NULL FOREIGN KEY REFERENCES Deprem(DepremID),
    YerlesimID   INT         NOT NULL FOREIGN KEY REFERENCES YerlesimBirimi(YerlesimID),
    EtkiSeviyesi VARCHAR(20),
    PRIMARY KEY (DepremID, YerlesimID)
);
GO

-- ================================================================
-- BÖLÜM 2: KULLANICI & YETKİLENDİRME TABLOLARI
-- ================================================================

-- Kullanıcı rolleri: kullanici | arastirmaci | sistem_yoneticisi | afet_yoneticisi
CREATE TABLE Kullanici (
    KullaniciID   INT           PRIMARY KEY IDENTITY(1,1),
    Gmail         VARCHAR(150)  NOT NULL UNIQUE,
    AdSoyad       VARCHAR(100)  NOT NULL,
    Rol           VARCHAR(30)   NOT NULL
        CONSTRAINT CHK_Rol CHECK (Rol IN ('kullanici','arastirmaci','sistem_yoneticisi','afet_yoneticisi')),
    GoogleSubID   VARCHAR(200)  UNIQUE,       -- Google OAuth2 sub claim
    AktifMi       BIT           DEFAULT 1,
    KayitTarihi   DATETIME      DEFAULT GETDATE(),
    SonGiris      DATETIME
);
GO

-- Oturum / token tablosu
CREATE TABLE OturumLog (
    LogID         INT           PRIMARY KEY IDENTITY(1,1),
    KullaniciID   INT           NOT NULL FOREIGN KEY REFERENCES Kullanici(KullaniciID),
    GirisTarihi   DATETIME      DEFAULT GETDATE(),
    CikisTarihi   DATETIME,
    IPAdresi      VARCHAR(45),
    UserAgent     VARCHAR(300)
);
GO

-- İzin tablosu (her rol için hangi VIEW/SP izinli)
CREATE TABLE RolIzin (
    IzinID        INT          PRIMARY KEY IDENTITY(1,1),
    Rol           VARCHAR(30)  NOT NULL,
    IslemAdi      VARCHAR(100) NOT NULL,   -- örn: 'VIEW_BuyukDepremler'
    Aciklama      VARCHAR(200)
);
GO

INSERT INTO RolIzin (Rol, IslemAdi, Aciklama) VALUES
('kullanici',        'vw_GenelDepremListesi',     'Genel deprem listesi görüntüleme'),
('kullanici',        'vw_BuyukDepremler',         'Büyük depremleri görme'),
('arastirmaci',      'vw_GenelDepremListesi',     'Genel deprem listesi'),
('arastirmaci',      'vw_BuyukDepremler',         'Büyük depremler'),
('arastirmaci',      'vw_FayIstatistikleri',      'Fay istatistikleri'),
('arastirmaci',      'vw_YillikIstatistik',       'Yıllık istatistik'),
('arastirmaci',      'sp_DepremSorgula',          'Tarih/büyüklük filtreli sorgulama'),
('arastirmaci',      'sp_YillikDepremOzeti',      'Yıllık özet raporu'),
('afet_yoneticisi',  'vw_GenelDepremListesi',     'Genel deprem listesi'),
('afet_yoneticisi',  'vw_BuyukDepremler',         'Büyük depremler'),
('afet_yoneticisi',  'vw_YuksekRiskliYerlesimler','Yüksek riskli bölgeler'),
('afet_yoneticisi',  'vw_HasarOzeti',             'Hasar özeti'),
('afet_yoneticisi',  'sp_DepremEtkiAnalizi',      'Etki analizi'),
('afet_yoneticisi',  'sp_YerlesimRiskRaporu',     'Yerleşim risk raporu'),
('sistem_yoneticisi','*',                         'Tüm işlemler');
GO

-- ================================================================
-- BÖLÜM 3: İNDEKSLER
-- ================================================================

CREATE INDEX IX_Deprem_TarihSaat    ON Deprem(TarihSaat DESC);
CREATE INDEX IX_Deprem_Buyukluk     ON Deprem(BuyuklukMw DESC);
CREATE INDEX IX_Deprem_Konum        ON Deprem(Enlem, Boylam);
CREATE INDEX IX_Deprem_USGSID       ON Deprem(USGS_ID);
CREATE INDEX IX_HasarKaydi_Deprem   ON HasarKaydi(DepremID);
CREATE INDEX IX_HasarKaydi_Yerlesim ON HasarKaydi(YerlesimID);
CREATE INDEX IX_Risk_Skor           ON RiskAnalizi(RiskSkoru DESC);
CREATE INDEX IX_Kullanici_Gmail     ON Kullanici(Gmail);
CREATE INDEX IX_Kullanici_GoogleSub ON Kullanici(GoogleSubID);
GO

-- ================================================================
-- BÖLÜM 4: VIEW'LAR (ROL BAZLI)
-- ================================================================

-- [kullanici + üstü] — Genel deprem listesi
CREATE VIEW vw_GenelDepremListesi AS
SELECT
    d.DepremID,
    CONVERT(VARCHAR(19), d.TarihSaat, 120) AS TarihSaat,
    d.Enlem,
    d.Boylam,
    d.Derinlik,
    d.BuyuklukMw,
    d.Tip
FROM Deprem d;
GO

-- [kullanici + üstü] — Büyük depremler (Mw >= 5.0)
CREATE VIEW vw_BuyukDepremler AS
SELECT
    d.DepremID,
    CONVERT(VARCHAR(19), d.TarihSaat, 120) AS TarihSaat,
    d.Enlem,
    d.Boylam,
    d.Derinlik,
    d.BuyuklukMw,
    d.Tip,
    f.FayAdi,
    f.Tip AS FayTipi
FROM Deprem d
LEFT JOIN FayHatti f ON d.FayID = f.FayID
WHERE d.BuyuklukMw >= 5.0;
GO

-- [arastirmaci + üstü] — Fay istatistikleri
CREATE VIEW vw_FayIstatistikleri AS
SELECT
    f.FayID,
    f.FayAdi,
    f.Tip,
    f.Uzunluk_km,
    COUNT(d.DepremID)   AS ToplamDepremSayisi,
    MAX(d.BuyuklukMw)   AS MaksimumBuyukluk,
    CAST(AVG(d.BuyuklukMw) AS DECIMAL(3,1)) AS OrtalamaBuyukluk,
    CAST(AVG(d.Derinlik)   AS DECIMAL(5,1)) AS OrtalamaDerinlik
FROM FayHatti f
LEFT JOIN Deprem d ON f.FayID = d.FayID
GROUP BY f.FayID, f.FayAdi, f.Tip, f.Uzunluk_km;
GO

-- [arastirmaci + üstü] — Yıllık deprem istatistiği
CREATE VIEW vw_YillikIstatistik AS
SELECT
    YEAR(TarihSaat)  AS Yil,
    COUNT(*)         AS ToplamDeprem,
    MAX(BuyuklukMw)  AS EnBuyuk,
    CAST(AVG(BuyuklukMw) AS DECIMAL(3,1)) AS Ortalama,
    SUM(CASE WHEN BuyuklukMw >= 6.0 THEN 1 ELSE 0 END) AS BuyukDeprem_6plus,
    SUM(CASE WHEN BuyuklukMw >= 5.0 THEN 1 ELSE 0 END) AS BuyukDeprem_5plus
FROM Deprem
GROUP BY YEAR(TarihSaat);
GO

-- [afet_yoneticisi + üstü] — Yüksek riskli yerleşimler
CREATE VIEW vw_YuksekRiskliYerlesimler AS
SELECT
    y.YerlesimID,
    y.Il,
    y.Ilce,
    y.Nufus,
    r.RiskSkoru,
    t.PGA,
    t.TehlikeSeviyesi,
    z.ZeminSinifi,
    z.Vs30
FROM YerlesimBirimi y
JOIN RiskAnalizi       r ON y.YerlesimID = r.YerlesimID
JOIN TehlikeParametresi t ON y.YerlesimID = t.YerlesimID
JOIN ZeminBilgisi      z ON y.YerlesimID = z.YerlesimID
WHERE r.RiskSkoru >= 0.70;
GO

-- [afet_yoneticisi + üstü] — Hasar özeti
CREATE VIEW vw_HasarOzeti AS
SELECT
    d.DepremID,
    CONVERT(VARCHAR(10), d.TarihSaat, 23) AS DepremTarihi,
    d.BuyuklukMw,
    y.Il,
    y.Ilce,
    h.OlumSayisi,
    h.YaraliSayisi,
    h.YikilanBina
FROM HasarKaydi h
JOIN Deprem d         ON h.DepremID    = d.DepremID
JOIN YerlesimBirimi y ON h.YerlesimID  = y.YerlesimID;
GO

-- [sistem_yoneticisi] — Tüm kullanıcı aktiviteleri
CREATE VIEW vw_KullaniciAktivite AS
SELECT
    k.KullaniciID,
    k.Gmail,
    k.AdSoyad,
    k.Rol,
    o.GirisTarihi,
    o.CikisTarihi,
    o.IPAdresi,
    DATEDIFF(MINUTE, o.GirisTarihi, o.CikisTarihi) AS OturumDakika
FROM Kullanici k
LEFT JOIN OturumLog o ON k.KullaniciID = o.KullaniciID;
GO

-- ================================================================
-- BÖLÜM 5: STORED PROCEDURE'LER
-- ================================================================

-- SP1: Gmail ile giriş / ilk kayıt
CREATE PROCEDURE sp_GmailGiris
    @Gmail      VARCHAR(150),
    @AdSoyad    VARCHAR(100),
    @GoogleSub  VARCHAR(200),
    @IPAdresi   VARCHAR(45) = NULL,
    @UserAgent  VARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @KullaniciID INT;
    DECLARE @Rol         VARCHAR(30);
    DECLARE @AktifMi     BIT;

    -- Kullanıcı var mı?
    SELECT @KullaniciID = KullaniciID, @Rol = Rol, @AktifMi = AktifMi
    FROM Kullanici
    WHERE Gmail = @Gmail OR GoogleSubID = @GoogleSub;

    IF @KullaniciID IS NULL
    BEGIN
        -- Yeni kullanıcı → varsayılan rol: kullanici
        INSERT INTO Kullanici (Gmail, AdSoyad, Rol, GoogleSubID)
        VALUES (@Gmail, @AdSoyad, 'kullanici', @GoogleSub);
        SET @KullaniciID = SCOPE_IDENTITY();
        SET @Rol = 'kullanici';
        SET @AktifMi = 1;
    END
    ELSE
    BEGIN
        -- Var olan kullanıcı → son giriş güncelle
        UPDATE Kullanici
        SET SonGiris = GETDATE(), GoogleSubID = @GoogleSub
        WHERE KullaniciID = @KullaniciID;
    END

    IF @AktifMi = 0
    BEGIN
        SELECT -1 AS Sonuc, 'Hesap devre dışı.' AS Mesaj, NULL AS Rol;
        RETURN;
    END

    -- Oturum logu
    INSERT INTO OturumLog (KullaniciID, IPAdresi, UserAgent)
    VALUES (@KullaniciID, @IPAdresi, @UserAgent);

    SELECT
        @KullaniciID AS KullaniciID,
        @Rol         AS Rol,
        @AdSoyad     AS AdSoyad,
        1            AS Sonuc,
        'Giriş başarılı.' AS Mesaj;
END;
GO

-- SP2: Kullanıcı rol güncelleme (sadece sistem_yoneticisi)
CREATE PROCEDURE sp_RolGuncelle
    @HedefGmail  VARCHAR(150),
    @YeniRol     VARCHAR(30),
    @IslemYapanID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @YapaninRolu VARCHAR(30);
    SELECT @YapaninRolu = Rol FROM Kullanici WHERE KullaniciID = @IslemYapanID;

    IF @YapaninRolu <> 'sistem_yoneticisi'
    BEGIN
        SELECT 0 AS Sonuc, 'Yetkisiz işlem.' AS Mesaj;
        RETURN;
    END

    IF @YeniRol NOT IN ('kullanici','arastirmaci','sistem_yoneticisi','afet_yoneticisi')
    BEGIN
        SELECT 0 AS Sonuc, 'Geçersiz rol.' AS Mesaj;
        RETURN;
    END

    UPDATE Kullanici SET Rol = @YeniRol WHERE Gmail = @HedefGmail;
    SELECT 1 AS Sonuc, 'Rol güncellendi.' AS Mesaj;
END;
GO

-- SP3: Tarih & büyüklük filtreli deprem sorgulama
CREATE PROCEDURE sp_DepremSorgula
    @BasTarih    DATETIME,
    @BitisTarih  DATETIME,
    @MinBuyukluk DECIMAL(3,1) = 3.5,
    @MaxBuyukluk DECIMAL(3,1) = 9.9
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        d.DepremID,
        CONVERT(VARCHAR(19), d.TarihSaat, 120) AS TarihSaat,
        d.Enlem,
        d.Boylam,
        d.Derinlik,
        d.BuyuklukMw,
        d.Tip,
        f.FayAdi
    FROM Deprem d
    LEFT JOIN FayHatti f ON d.FayID = f.FayID
    WHERE d.TarihSaat BETWEEN @BasTarih AND @BitisTarih
      AND d.BuyuklukMw BETWEEN @MinBuyukluk AND @MaxBuyukluk
    ORDER BY d.TarihSaat DESC;
END;
GO

-- SP4: Yerleşim risk raporu
CREATE PROCEDURE sp_YerlesimRiskRaporu
    @Il   VARCHAR(50) = NULL,
    @Ilce VARCHAR(80) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        y.Il,
        y.Ilce,
        y.Nufus,
        r.RiskSkoru,
        t.PGA,
        t.TehlikeSeviyesi,
        z.ZeminSinifi,
        z.Vs30,
        ISNULL(SUM(h.OlumSayisi),   0) AS ToplamOlum,
        ISNULL(SUM(h.YaraliSayisi), 0) AS ToplamYarali,
        ISNULL(SUM(h.YikilanBina),  0) AS ToplamYikilanBina
    FROM YerlesimBirimi y
    LEFT JOIN RiskAnalizi       r ON y.YerlesimID = r.YerlesimID
    LEFT JOIN TehlikeParametresi t ON y.YerlesimID = t.YerlesimID
    LEFT JOIN ZeminBilgisi      z ON y.YerlesimID = z.YerlesimID
    LEFT JOIN HasarKaydi        h ON y.YerlesimID = h.YerlesimID
    WHERE (@Il   IS NULL OR y.Il   LIKE '%' + @Il   + '%')
      AND (@Ilce IS NULL OR y.Ilce LIKE '%' + @Ilce + '%')
    GROUP BY y.Il, y.Ilce, y.Nufus, r.RiskSkoru,
             t.PGA, t.TehlikeSeviyesi, z.ZeminSinifi, z.Vs30
    ORDER BY r.RiskSkoru DESC;
END;
GO

-- SP5: Deprem etki analizi
CREATE PROCEDURE sp_DepremEtkiAnalizi
    @DepremID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        d.DepremID,
        d.BuyuklukMw,
        CONVERT(VARCHAR(19), d.TarihSaat, 120) AS TarihSaat,
        f.FayAdi,
        y.Il,
        y.Ilce,
        y.Nufus,
        dy.EtkiSeviyesi,
        ISNULL(h.OlumSayisi,   0) AS Olum,
        ISNULL(h.YaraliSayisi, 0) AS Yarali,
        ISNULL(h.YikilanBina,  0) AS YikilanBina
    FROM Deprem d
    LEFT JOIN FayHatti f        ON d.FayID = f.FayID
    JOIN Deprem_Yerlesim dy     ON d.DepremID = dy.DepremID
    JOIN YerlesimBirimi y       ON dy.YerlesimID = y.YerlesimID
    LEFT JOIN HasarKaydi h      ON d.DepremID = h.DepremID
                               AND dy.YerlesimID = h.YerlesimID
    WHERE d.DepremID = @DepremID
    ORDER BY dy.EtkiSeviyesi;
END;
GO

-- SP6: Yıllık deprem özeti
CREATE PROCEDURE sp_YillikDepremOzeti
    @Yil INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        MONTH(TarihSaat) AS Ay,
        COUNT(*)         AS DepremSayisi,
        MAX(BuyuklukMw)  AS EnBuyuk,
        CAST(AVG(BuyuklukMw) AS DECIMAL(3,1)) AS Ortalama,
        SUM(CASE WHEN BuyuklukMw >= 5.0 THEN 1 ELSE 0 END) AS BuyukDepremSayisi
    FROM Deprem
    WHERE YEAR(TarihSaat) = @Yil
    GROUP BY MONTH(TarihSaat)
    ORDER BY Ay;
END;
GO

-- SP7: Çıkış işlemi
CREATE PROCEDURE sp_Cikis
    @KullaniciID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE OturumLog
    SET CikisTarihi = GETDATE()
    WHERE KullaniciID = @KullaniciID
      AND CikisTarihi IS NULL;
END;
GO

-- ================================================================
-- BÖLÜM 6: TRİGGERLAR
-- ================================================================

-- Büyük deprem uyarı log tablosu
CREATE TABLE DepremUyariLog (
    LogID       INT           PRIMARY KEY IDENTITY(1,1),
    DepremID    INT,
    BuyuklukMw  DECIMAL(3,1),
    TarihSaat   DATETIME,
    UyariMesaji VARCHAR(500),
    LogZamani   DATETIME DEFAULT GETDATE()
);
GO

-- T1: Mw >= 6.0 deprem eklenince uyarı oluştur
CREATE TRIGGER trg_BuyukDepremUyari
ON Deprem
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO DepremUyariLog (DepremID, BuyuklukMw, TarihSaat, UyariMesaji)
    SELECT
        DepremID,
        BuyuklukMw,
        TarihSaat,
        'KRİTİK UYARI — Mw ' + CAST(BuyuklukMw AS VARCHAR(5)) +
        ' büyüklüğünde deprem | Konum: (' +
        CAST(Enlem AS VARCHAR(12)) + ', ' + CAST(Boylam AS VARCHAR(12)) +
        ') | Derinlik: ' + CAST(Derinlik AS VARCHAR(8)) + ' km'
    FROM inserted
    WHERE BuyuklukMw >= 6.0;
END;
GO

-- T2: Hasar kaydı sonrası risk skorunu otomatik güncelle
CREATE TRIGGER trg_HasarSonrasiRiskGuncelle
ON HasarKaydi
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE r
    SET
        r.RiskSkoru = CASE
            WHEN (i.OlumSayisi > 100 OR i.YikilanBina > 1000) THEN
                CASE WHEN r.RiskSkoru + 0.05 > 1.0 THEN 1.0 ELSE r.RiskSkoru + 0.05 END
            WHEN (i.OlumSayisi > 10  OR i.YikilanBina > 100)  THEN
                CASE WHEN r.RiskSkoru + 0.02 > 1.0 THEN 1.0 ELSE r.RiskSkoru + 0.02 END
            ELSE r.RiskSkoru
        END,
        r.HesaplamaTarihi = CAST(GETDATE() AS DATE)
    FROM RiskAnalizi r
    JOIN inserted i ON r.YerlesimID = i.YerlesimID;
END;
GO

-- T3: Rol değişikliklerini logla
CREATE TABLE RolDegisiklikLog (
    LogID        INT          PRIMARY KEY IDENTITY(1,1),
    KullaniciID  INT,
    EskiRol      VARCHAR(30),
    YeniRol      VARCHAR(30),
    DegisimZamani DATETIME   DEFAULT GETDATE()
);
GO

CREATE TRIGGER trg_RolDegisiklikLog
ON Kullanici
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(Rol)
    BEGIN
        INSERT INTO RolDegisiklikLog (KullaniciID, EskiRol, YeniRol)
        SELECT d.KullaniciID, d.Rol, i.Rol
        FROM deleted d
        JOIN inserted i ON d.KullaniciID = i.KullaniciID
        WHERE d.Rol <> i.Rol;
    END
END;
GO

-- ================================================================
-- BÖLÜM 7: SQL SERVER ROLLER & İZİNLER
-- ================================================================

-- DB rolleri oluştur
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_kullanici')
    CREATE ROLE rol_kullanici;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_arastirmaci')
    CREATE ROLE rol_arastirmaci;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_afet_yoneticisi')
    CREATE ROLE rol_afet_yoneticisi;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_sistem_yoneticisi')
    CREATE ROLE rol_sistem_yoneticisi;
GO

-- kullanici rolü izinleri
GRANT SELECT ON vw_GenelDepremListesi  TO rol_kullanici;
GRANT SELECT ON vw_BuyukDepremler      TO rol_kullanici;

-- arastirmaci rolü izinleri
GRANT SELECT ON vw_GenelDepremListesi  TO rol_arastirmaci;
GRANT SELECT ON vw_BuyukDepremler      TO rol_arastirmaci;
GRANT SELECT ON vw_FayIstatistikleri   TO rol_arastirmaci;
GRANT SELECT ON vw_YillikIstatistik    TO rol_arastirmaci;
GRANT EXECUTE ON sp_DepremSorgula      TO rol_arastirmaci;
GRANT EXECUTE ON sp_YillikDepremOzeti  TO rol_arastirmaci;

-- afet yöneticisi izinleri
GRANT SELECT ON vw_GenelDepremListesi       TO rol_afet_yoneticisi;
GRANT SELECT ON vw_BuyukDepremler           TO rol_afet_yoneticisi;
GRANT SELECT ON vw_YuksekRiskliYerlesimler  TO rol_afet_yoneticisi;
GRANT SELECT ON vw_HasarOzeti               TO rol_afet_yoneticisi;
GRANT EXECUTE ON sp_DepremEtkiAnalizi       TO rol_afet_yoneticisi;
GRANT EXECUTE ON sp_YerlesimRiskRaporu      TO rol_afet_yoneticisi;
GRANT EXECUTE ON sp_DepremSorgula           TO rol_afet_yoneticisi;

-- sistem yöneticisi — tam yetki
GRANT CONTROL ON DATABASE::DepremDB TO rol_sistem_yoneticisi;
GO

-- ================================================================
-- BÖLÜM 8: İLK VERİLER (FAY HATLARI + YERLEŞİM)
-- ================================================================

INSERT INTO FayHatti (FayAdi, Tip, Uzunluk_km, AktifMi) VALUES
('Kuzey Anadolu Fay Hattı - Doğu Segmenti',  'Sağ Yanal Doğrultu Atımlı', 600.0, 1),
('Kuzey Anadolu Fay Hattı - Orta Segmenti',  'Sağ Yanal Doğrultu Atımlı', 450.0, 1),
('Kuzey Anadolu Fay Hattı - Batı Segmenti',  'Sağ Yanal Doğrultu Atımlı', 350.0, 1),
('Doğu Anadolu Fay Hattı',                   'Sol Yanal Doğrultu Atımlı', 700.0, 1),
('Ege Genişleme Zonu',                        'Normal Fay',                 480.0, 1),
('Gediz Grabeni Fayı',                        'Normal Fay',                 140.0, 1),
('Büyük Menderes Grabeni Fayı',               'Normal Fay',                 175.0, 1),
('Palu - Hazar Gölü Fayı',                   'Sol Yanal Doğrultu Atımlı', 120.0, 1),
('Çaldıran Fayı',                             'Sol Yanal Doğrultu Atımlı',  90.0, 1),
('İzmir Fay Zonu',                            'Normal Fay',                  85.0, 1),
('Sultandağı Fayı',                           'Normal Fay',                  95.0, 1),
('Ecemiş Fay Zonu',                           'Sol Yanal Doğrultu Atımlı', 200.0, 1),
('Maraş Fay Zonu',                            'Sol Yanal Doğrultu Atımlı', 160.0, 1),
('Geyve Fayı',                                'Sağ Yanal Doğrultu Atımlı',  60.0, 1);
GO

INSERT INTO YerlesimBirimi (Il, Ilce, Mahalle, Nufus) VALUES
('İstanbul','Kadıköy','Moda',480000),        ('İstanbul','Avcılar','Merkez',430000),
('İstanbul','Fatih','Aksaray',360000),        ('İzmir','Merkez','Konak',390000),
('İzmir','Bornova','Merkez',320000),          ('İzmir','Bayraklı','Merkez',280000),
('Ankara','Çankaya','Kavaklıdere',560000),    ('Ankara','Mamak','Merkez',310000),
('Bursa','Osmangazi','Merkez',740000),         ('Bursa','Nilüfer','Merkez',380000),
('Kocaeli','İzmit','Merkez',320000),          ('Kocaeli','Gölcük','Merkez',85000),
('Sakarya','Adapazarı','Merkez',200000),       ('Düzce','Merkez','Merkez',130000),
('Bolu','Merkez','Merkez',95000),             ('Erzincan','Merkez','Merkez',75000),
('Erzurum','Merkez','Merkez',210000),          ('Van','Merkez','Merkez',220000),
('Van','Erciş','Merkez',85000),               ('Bingöl','Merkez','Merkez',75000),
('Elazığ','Merkez','Merkez',160000),           ('Malatya','Merkez','Merkez',230000),
('Kahramanmaraş','Merkez','Merkez',270000),    ('Hatay','Antakya','Merkez',240000),
('Adıyaman','Merkez','Merkez',110000),         ('Gaziantep','Şahinbey','Merkez',480000),
('Muğla','Bodrum','Merkez',120000),            ('Muğla','Datça','Merkez',18000),
('Manisa','Akhisar','Merkez',95000),           ('Aydın','Söke','Merkez',80000),
('Denizli','Merkez','Merkez',260000),          ('Afyonkarahisar','Dinar','Merkez',45000),
('Konya','Merkez','Merkez',540000),            ('Aksaray','Merkez','Merkez',90000),
('Kayseri','Merkez','Merkez',340000),          ('Sivas','Merkez','Merkez',150000),
('Tokat','Niksar','Merkez',35000),             ('Amasya','Merkez','Merkez',55000),
('Çorum','Merkez','Merkez',90000),             ('Kastamonu','Merkez','Merkez',60000);
GO

INSERT INTO ZeminBilgisi (YerlesimID, ZeminSinifi, Vs30) VALUES
(1,'ZD',180),(2,'ZE',140),(3,'ZD',175),(4,'ZC',380),(5,'ZC',360),
(6,'ZD',200),(7,'ZB',580),(8,'ZC',300),(9,'ZC',320),(10,'ZB',540),
(11,'ZD',190),(12,'ZE',145),(13,'ZE',150),(14,'ZD',185),(15,'ZC',350),
(16,'ZC',340),(17,'ZB',520),(18,'ZD',210),(19,'ZD',195),(20,'ZC',310),
(21,'ZC',330),(22,'ZC',345),(23,'ZD',220),(24,'ZD',205),(25,'ZD',215),
(26,'ZC',355),(27,'ZB',560),(28,'ZB',590),(29,'ZC',370),(30,'ZC',360),
(31,'ZC',340),(32,'ZC',330),(33,'ZB',500),(34,'ZB',510),(35,'ZB',520),
(36,'ZB',530),(37,'ZC',315),(38,'ZC',325),(39,'ZB',545),(40,'ZB',555);
GO

INSERT INTO TehlikeParametresi (YerlesimID, PGA, TehlikeSeviyesi) VALUES
(1,0.40,'Yüksek'),(2,0.45,'Yüksek'),(3,0.38,'Yüksek'),(4,0.35,'Yüksek'),
(5,0.33,'Yüksek'),(6,0.37,'Yüksek'),(7,0.20,'Orta'),(8,0.22,'Orta'),
(9,0.28,'Orta'),(10,0.25,'Orta'),(11,0.42,'Yüksek'),(12,0.44,'Yüksek'),
(13,0.41,'Yüksek'),(14,0.39,'Yüksek'),(15,0.30,'Orta'),(16,0.32,'Yüksek'),
(17,0.28,'Orta'),(18,0.36,'Yüksek'),(19,0.38,'Yüksek'),(20,0.34,'Yüksek'),
(21,0.36,'Yüksek'),(22,0.33,'Yüksek'),(23,0.42,'Yüksek'),(24,0.44,'Yüksek'),
(25,0.40,'Yüksek'),(26,0.38,'Yüksek'),(27,0.30,'Orta'),(28,0.28,'Orta'),
(29,0.32,'Yüksek'),(30,0.31,'Yüksek'),(31,0.29,'Orta'),(32,0.27,'Orta'),
(33,0.18,'Düşük'),(34,0.15,'Düşük'),(35,0.20,'Orta'),(36,0.17,'Düşük'),
(37,0.24,'Orta'),(38,0.22,'Orta'),(39,0.19,'Düşük'),(40,0.21,'Orta');
GO

INSERT INTO RiskAnalizi (YerlesimID, RiskSkoru, HesaplamaTarihi) VALUES
(1,0.82,'2024-01-15'),(2,0.88,'2024-01-15'),(3,0.79,'2024-01-15'),
(4,0.75,'2024-01-15'),(5,0.72,'2024-01-15'),(6,0.77,'2024-01-15'),
(7,0.45,'2024-01-15'),(8,0.48,'2024-01-15'),(9,0.55,'2024-01-15'),
(10,0.50,'2024-01-15'),(11,0.85,'2024-01-15'),(12,0.87,'2024-01-15'),
(13,0.83,'2024-01-15'),(14,0.80,'2024-01-15'),(15,0.60,'2024-01-15'),
(16,0.65,'2024-01-15'),(17,0.55,'2024-01-15'),(18,0.72,'2024-01-15'),
(19,0.75,'2024-01-15'),(20,0.68,'2024-01-15'),(21,0.70,'2024-01-15'),
(22,0.67,'2024-01-15'),(23,0.85,'2024-03-01'),(24,0.88,'2024-03-01'),
(25,0.82,'2024-03-01'),(26,0.80,'2024-03-01'),(27,0.58,'2024-01-15'),
(28,0.52,'2024-01-15'),(29,0.63,'2024-01-15'),(30,0.61,'2024-01-15'),
(31,0.57,'2024-01-15'),(32,0.54,'2024-01-15'),(33,0.35,'2024-01-15'),
(34,0.30,'2024-01-15'),(35,0.42,'2024-01-15'),(36,0.33,'2024-01-15'),
(37,0.48,'2024-01-15'),(38,0.45,'2024-01-15'),(39,0.38,'2024-01-15'),
(40,0.40,'2024-01-15');
GO

-- ================================================================
-- BÖLÜM 9: TEST KULLANICILARI
-- ================================================================

INSERT INTO Kullanici (Gmail, AdSoyad, Rol, GoogleSubID) VALUES
('admin@gmail.com',        'Sistem Yöneticisi', 'sistem_yoneticisi', 'google-sub-001'),
('afet@gmail.com',         'Afet Yöneticisi',   'afet_yoneticisi',   'google-sub-002'),
('arastirmaci@gmail.com',  'Dr. Araştırmacı',   'arastirmaci',       'google-sub-003'),
('kullanici@gmail.com',    'Normal Kullanıcı',  'kullanici',         'google-sub-004');
GO

PRINT '✅ DepremDB başarıyla oluşturuldu.';
PRINT '   Tablolar  : 12';
PRINT '   View lar  : 7';
PRINT '   SP ler    : 7';
PRINT '   Trigger ler: 3';
PRINT '   İndeksler : 9';
GO