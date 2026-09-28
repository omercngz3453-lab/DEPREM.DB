-- ============================================================
-- DEPREM VERİTABANI PROJESİ — SQL SERVER
-- Tüm Kullanıcılar (Halk Dahil) | Tüm Türkiye | 100+ Kayıt
-- ============================================================

-- 1. ESKİ VERİ TABANINI KÖKTEN SİLME (Hata almanı engeller)
USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'DepremDB')
    BEGIN
        ALTER DATABASE DepremDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE DepremDB;
    END
GO

-- 2. YENİ VERİ TABANINI OLUŞTURMA
CREATE DATABASE DepremDB;
GO

USE DepremDB;
GO

-- ============================================================
-- 3. TABLOLARIN OLUŞTURULMASI
-- ============================================================
CREATE TABLE Kullanici (
    KullaniciID INT PRIMARY KEY IDENTITY(1,1),
    AdSoyad VARCHAR(100) NOT NULL,
    Rol VARCHAR(50) NOT NULL,
    Kurum VARCHAR(100),
    KayitTarihi DATETIME DEFAULT GETDATE()
);
GO

CREATE TABLE FayHatti (
    FayID       INT           PRIMARY KEY IDENTITY(1,1),
    FayAdi      VARCHAR(100)  NOT NULL,
    Tip         VARCHAR(50),
    Uzunluk_km  DECIMAL(5,1),
    AktifMi     BIT           DEFAULT 1
);
GO

CREATE TABLE Deprem (
    DepremID    INT           PRIMARY KEY IDENTITY(1,1),
    TarihSaat   DATETIME      NOT NULL,
    Enlem       DECIMAL(9,6)  NOT NULL,
    Boylam      DECIMAL(9,6)  NOT NULL,
    Derinlik    DECIMAL(4,1)  NOT NULL,
    BuyuklukMw  DECIMAL(3,1)  NOT NULL,
    Tip         VARCHAR(20),
    FayID       INT           FOREIGN KEY REFERENCES FayHatti(FayID)
);
GO

CREATE TABLE YerlesimBirimi (
    YerlesimID  INT           PRIMARY KEY IDENTITY(1,1),
    Il          VARCHAR(50)   NOT NULL,
    Ilce        VARCHAR(80)   NOT NULL,
    Mahalle     VARCHAR(80),
    Nufus       INT
);
GO

CREATE TABLE ZeminBilgisi (
    ZeminID     INT           PRIMARY KEY IDENTITY(1,1),
    YerlesimID  INT           NOT NULL FOREIGN KEY REFERENCES YerlesimBirimi(YerlesimID),
    ZeminSinifi VARCHAR(5)    NOT NULL,
    Vs30        DECIMAL(5,1)
);
GO

CREATE TABLE TehlikeParametresi (
    TehlikeID       INT           PRIMARY KEY IDENTITY(1,1),
    YerlesimID      INT           NOT NULL FOREIGN KEY REFERENCES YerlesimBirimi(YerlesimID),
    PGA             DECIMAL(4,2)  NOT NULL,
    TehlikeSeviyesi VARCHAR(20)
);
GO

CREATE TABLE HasarKaydi (
    HasarID      INT  PRIMARY KEY IDENTITY(1,1),
    DepremID     INT  NOT NULL FOREIGN KEY REFERENCES Deprem(DepremID),
    YerlesimID   INT  NOT NULL FOREIGN KEY REFERENCES YerlesimBirimi(YerlesimID),
    OlumSayisi   INT  DEFAULT 0,    
    YaraliSayisi INT  DEFAULT 0,
    YikilanBina  INT  DEFAULT 0
);
GO

CREATE TABLE RiskAnalizi (
    RiskID                INT           PRIMARY KEY IDENTITY(1,1),
    YerlesimID            INT           NOT NULL FOREIGN KEY REFERENCES YerlesimBirimi(YerlesimID),
    HesaplayanKullaniciID INT           NOT NULL FOREIGN KEY REFERENCES Kullanici(KullaniciID), 
    RiskSkoru             DECIMAL(4,2)  NOT NULL,
    HesaplamaTarihi       DATE          NOT NULL
);
GO

CREATE TABLE Deprem_Yerlesim (
    DepremID     INT          NOT NULL FOREIGN KEY REFERENCES Deprem(DepremID),
    YerlesimID   INT          NOT NULL FOREIGN KEY REFERENCES YerlesimBirimi(YerlesimID),
    EtkiSeviyesi VARCHAR(20),
    PRIMARY KEY (DepremID, YerlesimID)
);
GO

-- ============================================================
-- 4. İNDEKSLER
-- ============================================================
CREATE INDEX IX_Deprem_TarihSaat    ON Deprem(TarihSaat);
CREATE INDEX IX_Deprem_Buyukluk     ON Deprem(BuyuklukMw DESC);
CREATE INDEX IX_Deprem_Konum        ON Deprem(Enlem, Boylam);
CREATE INDEX IX_HasarKaydi_Deprem   ON HasarKaydi(DepremID);
CREATE INDEX IX_HasarKaydi_Yerlesim ON HasarKaydi(YerlesimID);
CREATE INDEX IX_Risk_Skor           ON RiskAnalizi(RiskSkoru DESC);
GO

-- ============================================================
-- 5. VERİLERİN EKLENMESİ
-- ============================================================

-- KULLANICILAR 
INSERT INTO Kullanici (AdSoyad, Rol, Kurum) VALUES
('Prof. Dr. Celal Şengör', 'Araştırmacı', 'İTÜ'),
('Dr. Yoshinori Moriwaki', 'Araştırmacı', 'JICA'),
('AFAD Kriz Masası', 'Afet Yöneticisi', 'İçişleri Bakanlığı'),
('Sistem Otomasyonu', 'Sistem Yöneticisi', 'IT Departmanı'),
('Ahmet Vatandaş', 'Halk', NULL);
GO

-- FAY HATLARI
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
('Geyve Fayı',                                'Sağ Yanal Doğrultu Atımlı',  60.0, 1),
('Tuz Gölü Fayı',                             'Normal Fay',                 130.0, 0);
GO

-- YERLEŞİM BİRİMLERİ
INSERT INTO YerlesimBirimi (Il, Ilce, Mahalle, Nufus) VALUES
('İstanbul', 'Kadıköy', 'Moda', 480000), ('İstanbul', 'Avcılar', 'Merkez', 430000),
('İstanbul', 'Fatih', 'Aksaray', 360000), ('İzmir', 'Merkez', 'Konak', 390000),
('İzmir', 'Bornova', 'Merkez', 320000), ('İzmir', 'Bayraklı', 'Merkez', 280000),
('Ankara', 'Çankaya', 'Kavaklıdere', 560000), ('Ankara', 'Mamak', 'Merkez', 310000),
('Bursa', 'Osmangazi', 'Merkez', 740000), ('Bursa', 'Nilüfer', 'Merkez', 380000),
('Kocaeli', 'İzmit', 'Merkez', 320000), ('Kocaeli', 'Gölcük', 'Merkez', 85000),
('Sakarya', 'Adapazarı', 'Merkez', 200000), ('Düzce', 'Merkez', 'Merkez', 130000),
('Bolu', 'Merkez', 'Merkez', 95000), ('Erzincan', 'Merkez', 'Merkez', 75000),
('Erzurum', 'Merkez', 'Merkez', 210000), ('Van', 'Merkez', 'Merkez', 220000),
('Van', 'Erciş', 'Merkez', 85000), ('Bingöl', 'Merkez', 'Merkez', 75000),
('Elazığ', 'Merkez', 'Merkez', 160000), ('Malatya', 'Merkez', 'Merkez', 230000),
('Kahramanmaraş', 'Merkez', 'Merkez', 270000), ('Hatay', 'Antakya', 'Merkez', 240000),
('Adıyaman', 'Merkez', 'Merkez', 110000), ('Gaziantep', 'Şahinbey', 'Merkez', 480000),
('Muğla', 'Bodrum', 'Merkez', 120000), ('Muğla', 'Datça', 'Merkez', 18000),
('Manisa', 'Akhisar', 'Merkez', 95000), ('Aydın', 'Söke', 'Merkez', 80000),
('Denizli', 'Merkez', 'Merkez', 260000), ('Afyonkarahisar', 'Dinar', 'Merkez', 45000),
('Konya', 'Merkez', 'Merkez', 540000), ('Aksaray', 'Merkez', 'Merkez', 90000),
('Kayseri', 'Merkez', 'Merkez', 340000), ('Sivas', 'Merkez', 'Merkez', 150000),
('Tokat', 'Niksar', 'Merkez', 35000), ('Amasya', 'Merkez', 'Merkez', 55000),
('Çorum', 'Merkez', 'Merkez', 90000), ('Kastamonu', 'Merkez', 'Merkez', 60000);
GO

-- ZEMİN BİLGİSİ
INSERT INTO ZeminBilgisi (YerlesimID, ZeminSinifi, Vs30) VALUES
(1, 'ZD', 180.0), (2, 'ZE', 140.0), (3, 'ZD', 175.0), (4, 'ZC', 380.0),
(5, 'ZC', 360.0), (6, 'ZD', 200.0), (7, 'ZB', 580.0), (8, 'ZC', 300.0),
(9, 'ZC', 320.0), (10, 'ZB', 540.0), (11, 'ZD', 190.0), (12, 'ZE', 145.0),
(13, 'ZE', 150.0), (14, 'ZD', 185.0), (15, 'ZC', 350.0), (16, 'ZC', 340.0),
(17, 'ZB', 520.0), (18, 'ZD', 210.0), (19, 'ZD', 195.0), (20, 'ZC', 310.0),
(21, 'ZC', 330.0), (22, 'ZC', 345.0), (23, 'ZD', 220.0), (24, 'ZD', 205.0),
(25, 'ZD', 215.0), (26, 'ZC', 355.0), (27, 'ZB', 560.0), (28, 'ZB', 590.0),
(29, 'ZC', 370.0), (30, 'ZC', 360.0), (31, 'ZC', 340.0), (32, 'ZC', 330.0),
(33, 'ZB', 500.0), (34, 'ZB', 510.0), (35, 'ZB', 520.0), (36, 'ZB', 530.0),
(37, 'ZC', 315.0), (38, 'ZC', 325.0), (39, 'ZB', 545.0), (40, 'ZB', 555.0);
GO

-- TEHLİKE PARAMETRELERİ
INSERT INTO TehlikeParametresi (YerlesimID, PGA, TehlikeSeviyesi) VALUES
(1, 0.40, 'Yüksek'), (2, 0.45, 'Yüksek'), (3, 0.38, 'Yüksek'),
(4, 0.35, 'Yüksek'), (5, 0.33, 'Yüksek'), (6, 0.37, 'Yüksek'),
(7, 0.20, 'Orta'),   (8, 0.22, 'Orta'),   (9, 0.28, 'Orta'),
(10, 0.25, 'Orta'),  (11, 0.42, 'Yüksek'),(12, 0.44, 'Yüksek'),
(13, 0.41, 'Yüksek'),(14, 0.39, 'Yüksek'),(15, 0.30, 'Orta'),
(16, 0.32, 'Yüksek'),(17, 0.28, 'Orta'),  (18, 0.36, 'Yüksek'),
(19, 0.38, 'Yüksek'),(20, 0.34, 'Yüksek'),(21, 0.36, 'Yüksek'),
(22, 0.33, 'Yüksek'),(23, 0.42, 'Yüksek'),(24, 0.44, 'Yüksek'),
(25, 0.40, 'Yüksek'),(26, 0.38, 'Yüksek'),(27, 0.30, 'Orta'),
(28, 0.28, 'Orta'),  (29, 0.32, 'Yüksek'),(30, 0.31, 'Yüksek'),
(31, 0.29, 'Orta'),  (32, 0.27, 'Orta'),  (33, 0.18, 'Düşük'),
(34, 0.15, 'Düşük'), (35, 0.20, 'Orta'),  (36, 0.17, 'Düşük'),
(37, 0.24, 'Orta'),  (38, 0.22, 'Orta'),  (39, 0.19, 'Düşük'),
(40, 0.21, 'Orta');
GO

-- DEPREMLER
INSERT INTO Deprem (TarihSaat, Enlem, Boylam, Derinlik, BuyuklukMw, Tip, FayID) VALUES
('1999-08-17 03:01:58', 40.748100, 29.864300, 17.0, 7.6, 'Tektonik', 2),
('1999-11-12 16:57:22', 40.757900, 31.161200, 10.0, 7.2, 'Tektonik', 2),
('2011-10-23 10:41:22', 38.691000, 43.508000, 18.0, 7.2, 'Tektonik', 4),
('2011-11-09 19:23:35', 38.448000, 43.251000, 10.0, 5.6, 'Tektonik', 4),
('2020-10-30 14:51:26', 37.918200, 26.789600,  6.0, 6.9, 'Tektonik', 5),
('2020-10-30 15:14:53', 37.921000, 26.801000,  8.0, 4.8, 'Artçı',    5),
('2020-10-30 16:35:11', 37.909000, 26.775000,  5.0, 4.5, 'Artçı',    5),
('2020-10-31 02:33:44', 37.925000, 26.795000,  7.0, 4.3, 'Artçı',    5),
('2023-02-06 04:17:35', 37.288000, 37.043000, 10.0, 7.7, 'Tektonik', 4),
('2023-02-06 13:24:49', 38.024000, 37.203000, 10.0, 7.6, 'Tektonik', 4),
('2023-02-06 06:04:32', 37.245000, 36.871000,  8.0, 6.7, 'Artçı',    4),
('2023-02-06 07:28:16', 37.310000, 37.150000,  9.0, 6.0, 'Artçı',    4),
('2023-02-06 08:45:22', 38.102000, 37.411000, 10.0, 5.8, 'Artçı',    4),
('2023-02-07 02:04:50', 37.264000, 36.954000,  7.0, 5.7, 'Artçı',    4),
('2023-02-08 11:38:14', 37.189000, 36.822000,  8.0, 5.5, 'Artçı',    4),
('2023-02-10 05:17:43', 38.255000, 37.565000, 10.0, 5.3, 'Artçı',    4),
('2024-04-17 08:23:11', 40.810000, 29.110000, 10.0, 5.1, 'Tektonik', 3),
('2024-02-14 19:45:30', 40.825000, 29.075000,  8.0, 4.7, 'Tektonik', 3),
('2023-09-26 14:32:05', 40.792000, 29.235000, 12.0, 4.5, 'Tektonik', 3),
('2023-06-15 03:17:48', 40.805000, 29.180000,  9.0, 4.2, 'Tektonik', 3),
('2023-03-22 22:11:33', 40.815000, 29.195000, 11.0, 4.0, 'Tektonik', 3),
('2022-11-08 17:54:22', 40.833000, 29.055000,  8.0, 4.4, 'Tektonik', 3),
('2022-07-23 09:30:17', 40.798000, 29.270000, 10.0, 4.1, 'Tektonik', 3),
('2024-03-05 12:44:28', 40.458000, 33.212000, 15.0, 4.3, 'Tektonik', 2),
('2023-11-19 07:22:41', 40.512000, 33.455000, 13.0, 3.9, 'Tektonik', 2),
('2023-05-07 20:15:55', 40.388000, 34.128000, 16.0, 4.1, 'Tektonik', 2),
('2022-09-14 05:38:10', 40.425000, 34.322000, 14.0, 3.8, 'Tektonik', 2),
('2024-01-24 17:09:33', 39.998000, 38.458000, 20.0, 4.6, 'Tektonik', 1),
('2023-08-30 11:25:47', 40.112000, 38.914000, 18.0, 4.2, 'Tektonik', 1),
('2023-01-18 08:44:22', 39.875000, 39.256000, 22.0, 4.0, 'Tektonik', 1),
('2024-05-28 03:55:18', 38.012000, 38.225000, 10.0, 4.8, 'Tektonik', 4),
('2024-02-22 14:12:09', 37.845000, 38.545000,  8.0, 4.5, 'Tektonik', 4),
('2023-12-11 22:30:44', 37.625000, 38.812000,  9.0, 4.3, 'Tektonik', 4),
('2023-07-04 06:18:30', 38.225000, 39.145000, 11.0, 4.0, 'Tektonik', 4),
('2022-12-26 18:55:12', 37.412000, 39.455000, 10.0, 4.7, 'Tektonik', 4),
('2024-04-28 21:30:05', 37.435000, 27.125000,  8.0, 5.2, 'Tektonik', 5),
('2024-01-08 10:15:44', 37.812000, 26.455000,  6.0, 4.9, 'Tektonik', 5),
('2023-10-02 15:48:33', 38.125000, 26.812000,  7.0, 4.7, 'Tektonik', 5),
('2023-06-18 04:22:11', 37.218000, 27.388000,  9.0, 4.5, 'Tektonik', 5),
('2023-02-28 11:55:20', 38.455000, 26.228000,  5.0, 4.3, 'Tektonik', 5),
('2022-08-17 20:04:39', 37.655000, 27.014000,  8.0, 4.1, 'Tektonik', 5),
('2024-05-05 07:33:22', 38.682000, 27.855000, 10.0, 4.4, 'Tektonik', 6),
('2023-09-14 17:21:08', 38.725000, 27.645000,  8.0, 4.1, 'Tektonik', 6),
('2023-04-11 02:48:55', 38.648000, 28.125000, 12.0, 3.9, 'Tektonik', 6),
('2022-10-30 14:15:33', 38.712000, 27.965000,  9.0, 3.7, 'Tektonik', 6),
('2024-03-22 09:44:17', 37.885000, 28.345000, 11.0, 4.6, 'Tektonik', 7),
('2023-11-05 22:10:55', 37.945000, 28.155000,  9.0, 4.3, 'Tektonik', 7),
('2023-05-19 14:55:28', 37.812000, 28.512000, 10.0, 4.0, 'Tektonik', 7),
('2022-12-08 08:30:11', 37.855000, 28.222000, 12.0, 3.8, 'Tektonik', 7),
('2024-05-12 05:17:42', 38.512000, 43.312000, 15.0, 4.5, 'Tektonik', 4),
('2024-01-31 19:44:28', 38.624000, 43.145000, 12.0, 4.2, 'Tektonik', 4),
('2023-08-08 13:22:14', 38.445000, 43.455000, 14.0, 4.0, 'Tektonik', 4),
('2023-03-15 07:55:33', 38.712000, 43.025000, 11.0, 3.8, 'Tektonik', 4),
('2024-04-14 14:30:25', 39.712000, 38.855000, 18.0, 5.0, 'Tektonik', 1),
('2023-12-18 09:15:44', 39.845000, 39.012000, 15.0, 4.6, 'Tektonik', 1),
('2023-07-22 21:48:10', 39.655000, 38.655000, 20.0, 4.3, 'Tektonik', 1),
('2022-11-28 04:32:55', 39.788000, 38.945000, 17.0, 4.1, 'Tektonik', 1),
('2024-02-08 16:22:33', 38.845000, 40.512000, 10.0, 4.8, 'Tektonik', 4),
('2023-10-15 11:55:22', 38.712000, 40.245000,  9.0, 4.5, 'Tektonik', 4),
('2023-04-28 03:14:11', 38.955000, 40.755000, 11.0, 4.2, 'Tektonik', 4),
('2020-01-24 17:55:11', 38.375000, 39.088000, 10.0, 6.8, 'Tektonik', 4),
('2020-01-24 18:32:45', 38.402000, 39.112000,  8.0, 5.4, 'Artçı',    4),
('2020-01-24 19:15:22', 38.388000, 39.095000,  9.0, 5.1, 'Artçı',    4),
('2024-03-11 06:45:19', 38.072000, 30.145000, 14.0, 4.3, 'Tektonik', 11),
('2023-09-25 20:30:44', 38.125000, 30.222000, 12.0, 4.0, 'Tektonik', 11),
('2023-05-03 10:14:28', 38.045000, 30.088000, 15.0, 3.8, 'Tektonik', 11),
('1995-10-01 14:57:11', 38.115000, 31.012000, 12.0, 6.0, 'Tektonik', 11),
('2024-05-20 13:22:38', 40.548000, 36.955000, 14.0, 4.2, 'Tektonik', 2),
('2023-12-04 08:10:25', 40.612000, 36.812000, 12.0, 3.9, 'Tektonik', 2),
('2024-04-05 22:15:33', 41.225000, 31.445000, 10.0, 3.8, 'Tektonik', 3),
('2023-11-22 15:44:21', 41.312000, 31.288000,  8.0, 3.6, 'Tektonik', 3),
('2024-01-18 11:30:14', 37.588000, 36.612000, 10.0, 4.4, 'Tektonik', 13),
('2023-08-14 07:22:44', 37.645000, 36.445000,  8.0, 4.1, 'Tektonik', 13),
('2023-03-08 19:55:30', 37.512000, 36.788000, 11.0, 3.9, 'Tektonik', 13),
('2024-04-22 04:15:55', 37.888000, 34.555000, 15.0, 4.0, 'Tektonik', 12),
('2023-10-30 18:44:11', 37.945000, 34.412000, 13.0, 3.7, 'Tektonik', 12),
('2024-06-01 09:10:22', 38.355000, 27.045000,  8.0, 4.1, 'Tektonik', 10),
('2024-03-28 14:55:33', 38.412000, 26.955000,  6.0, 3.9, 'Tektonik', 10),
('2023-12-22 21:30:14', 38.288000, 27.112000,  7.0, 3.7, 'Tektonik', 10),
('2024-05-08 02:44:28', 40.455000, 30.312000, 12.0, 4.0, 'Tektonik', 14),
('2023-07-31 16:22:15', 40.512000, 30.245000, 10.0, 3.8, 'Tektonik', 14),
('2024-02-18 08:33:11', 39.085000, 43.912000, 12.0, 4.3, 'Tektonik', 9),
('2023-06-05 23:15:44', 39.145000, 44.012000, 10.0, 4.0, 'Tektonik', 9),
('1976-11-24 12:22:18', 39.121000, 44.012000,  5.0, 7.3, 'Tektonik', 9),
('2024-04-30 10:22:55', 38.555000, 39.312000, 12.0, 4.1, 'Tektonik', 8),
('2023-10-18 04:55:28', 38.612000, 39.145000, 10.0, 3.8, 'Tektonik', 8),
('2024-06-03 07:11:22', 39.215000, 26.712000,  8.0, 3.5, 'Tektonik', 5),
('2024-05-25 18:44:33', 40.122000, 29.455000, 10.0, 3.6, 'Tektonik', 3),
('2024-05-15 11:30:55', 37.512000, 28.855000,  9.0, 3.4, 'Tektonik', 7),
('2024-04-10 20:15:22', 38.845000, 42.312000, 14.0, 3.7, 'Tektonik', 4),
('2024-03-18 05:33:44', 37.145000, 30.512000, 15.0, 3.5, 'Tektonik', NULL),
('2024-02-28 13:22:11', 39.655000, 37.145000, 12.0, 3.8, 'Tektonik', 1),
('2024-01-15 22:44:28', 40.255000, 32.512000, 16.0, 3.6, 'Tektonik', NULL),
('2023-12-28 09:55:33', 36.845000, 36.112000, 10.0, 3.9, 'Tektonik', 4),
('2023-11-11 14:10:44', 38.512000, 29.312000,  8.0, 3.4, 'Tektonik', 6),
('2023-10-05 03:22:55', 39.145000, 27.655000,  7.0, 3.5, 'Tektonik', 5),
('2023-09-03 17:44:11', 37.888000, 32.845000, 14.0, 3.7, 'Tektonik', NULL),
('2023-08-21 08:15:28', 41.055000, 29.845000, 12.0, 3.6, 'Tektonik', 3),
('2023-07-14 21:33:44', 38.222000, 38.455000, 10.0, 3.8, 'Tektonik', 4),
('2023-06-02 10:55:22', 40.712000, 31.122000, 13.0, 3.5, 'Tektonik', 2),
('2023-05-25 04:44:11', 37.355000, 27.845000,  8.0, 3.4, 'Tektonik', 5),
('2022-12-15 19:22:33', 38.655000, 41.312000, 11.0, 3.9, 'Tektonik', 4),
('2022-09-28 06:10:44', 39.845000, 39.845000, 15.0, 3.6, 'Tektonik', 1),
('2022-07-07 23:33:55', 37.712000, 26.955000,  6.0, 3.5, 'Tektonik', 5),
('2022-05-14 15:22:11', 40.345000, 28.745000, 10.0, 3.8, 'Tektonik', 3),
('2022-03-03 08:44:28', 38.155000, 27.355000,  9.0, 3.6, 'Tektonik', 6),
('2021-11-20 12:55:33', 39.555000, 40.155000, 12.0, 3.7, 'Tektonik', 1),
('2021-08-08 07:15:44', 37.455000, 37.855000, 10.0, 4.0, 'Tektonik', 4),
('2021-04-30 16:33:22', 38.955000, 26.545000,  7.0, 3.5, 'Tektonik', 5),
('2019-09-26 02:55:11', 40.125000, 29.245000,  8.0, 4.2, 'Tektonik', 3),
('2019-06-20 14:15:28', 37.612000, 27.255000,  6.0, 4.4, 'Tektonik', 5),
('2018-02-22 10:44:33', 40.885000, 27.945000, 10.0, 4.0, 'Tektonik', 3),
('2016-05-24 10:25:06', 40.638000, 39.874000, 10.0, 4.8, 'Tektonik', 1),
('2014-05-19 05:38:12', 39.774000, 29.108000,  4.8, 5.1, 'Tektonik', 5),
('2013-09-28 02:06:33', 38.278000, 44.368000, 10.0, 4.5, 'Tektonik', 4);
GO

-- RİSK ANALİZİ
INSERT INTO RiskAnalizi (YerlesimID, HesaplayanKullaniciID, RiskSkoru, HesaplamaTarihi) VALUES
(1, 1, 0.82, '2024-01-15'), (2, 2, 0.88, '2024-01-15'), (3, 3, 0.79, '2024-01-15'), 
(4, 1, 0.75, '2024-01-15'), (5, 2, 0.72, '2024-01-15'), (6, 3, 0.77, '2024-01-15'),
(7, 1, 0.45, '2024-01-15'), (8, 2, 0.48, '2024-01-15'), (9, 3, 0.55, '2024-01-15'), 
(10, 1, 0.50, '2024-01-15'), (11, 2, 0.85, '2024-01-15'), (12, 3, 0.87, '2024-01-15'),
(13, 1, 0.83, '2024-01-15'), (14, 2, 0.80, '2024-01-15'), (15, 3, 0.60, '2024-01-15'), 
(16, 1, 0.65, '2024-01-15'), (17, 2, 0.55, '2024-01-15'), (18, 3, 0.72, '2024-01-15'),
(19, 1, 0.75, '2024-01-15'), (20, 2, 0.68, '2024-01-15'), (21, 3, 0.70, '2024-01-15'), 
(22, 1, 0.67, '2024-01-15'), (23, 2, 0.85, '2024-03-01'), (24, 3, 0.88, '2024-03-01'),
(25, 1, 0.82, '2024-03-01'), (26, 2, 0.80, '2024-03-01'), (27, 3, 0.58, '2024-01-15'), 
(28, 1, 0.52, '2024-01-15'), (29, 2, 0.63, '2024-01-15'), (30, 3, 0.61, '2024-01-15'),
(31, 1, 0.57, '2024-01-15'), (32, 2, 0.54, '2024-01-15'), (33, 3, 0.35, '2024-01-15'), 
(34, 1, 0.30, '2024-01-15'), (35, 2, 0.42, '2024-01-15'), (36, 3, 0.33, '2024-01-15'),
(37, 1, 0.48, '2024-01-15'), (38, 2, 0.45, '2024-01-15'), (39, 3, 0.38, '2024-01-15'), 
(40, 1, 0.40, '2024-01-15');
GO

-- HASAR KAYDI
INSERT INTO HasarKaydi (DepremID, YerlesimID, OlumSayisi, YaraliSayisi, YikilanBina) VALUES
(1, 12, 18373, 43953, 97000), (1, 13, 4500,  11200, 23000), (1, 11, 3200,   7800, 15000), (1, 9,  1100,   3500,  4500),
(2, 14,  845,   4948,  5000), (2, 15,  200,    900,  1200),
(3, 18,  604,   1966, 11000), (3, 19,  150,    450,  2400),
(5, 4,   114,   1035,  3822), (5, 5,    22,    280,   650), (5, 6,    38,    420,  1100),
(9, 23,  7200,  18000, 65000), (9, 24,  6800,  17500, 58000), (9, 25,  4500,  12000, 38000), (9, 26,  3200,   9500, 28000), (9, 22,   850,   2800,  9500),
(10, 23, 4100,  11000, 35000), (10, 24, 3800,  10500, 31000), (10, 25, 2200,   7000, 21000),
(64, 21,  41,    1607,  1395), (64, 20,   8,     280,   320),
(93, 18, 3840,  10000,  9000),
(4,  19,   0,      8,     25), (6,  4,    0,     15,     40), (7,  4,    0,      5,     18), (24, 11,   0,      3,     12), (36, 27,   0,      7,     22);
GO

-- DEPREM_YERLEŞİM (N:N ARA TABLO)
INSERT INTO Deprem_Yerlesim (DepremID, YerlesimID, EtkiSeviyesi) VALUES
(1, 12, 'Şiddetli'),  (1, 13, 'Şiddetli'),  (1, 11, 'Orta'), (1,  9, 'Orta'),      (1, 14, 'Hafif'),      (1,  1, 'Hafif'),
(2, 14, 'Şiddetli'),  (2, 15, 'Şiddetli'),  (2, 11, 'Hafif'),
(3, 18, 'Şiddetli'),  (3, 19, 'Şiddetli'),
(5,  4, 'Şiddetli'),  (5,  5, 'Orta'),       (5,  6, 'Orta'), (5, 27, 'Hafif'),     (5, 30, 'Hafif'),
(9, 23, 'Şiddetli'),  (9, 24, 'Şiddetli'),   (9, 25, 'Şiddetli'), (9, 26, 'Şiddetli'),  (9, 22, 'Orta'),
(10,23, 'Şiddetli'),  (10,24, 'Şiddetli'),   (10,25, 'Orta'),
(64,21, 'Şiddetli'),  (64,20, 'Orta'),
(17, 1, 'Hafif'),     (17, 2, 'Hafif'),       (17, 9, 'Hafif'),
(36, 27,'Orta'),      (36, 28,'Hafif'),        (36, 4, 'Hafif'),
(37, 4, 'Orta'),      (37, 5, 'Hafif'),        (37, 27,'Orta');
GO

-- ============================================================
-- 6. VIEW'LAR (GÖRÜNÜMLER)
-- ============================================================

-- A) AFET YÖNETİCİSİ EKRANI
CREATE VIEW vw_AfetYoneticisi_Ekrani AS
SELECT d.TarihSaat, y.Il, y.Ilce, d.BuyuklukMw, h.OlumSayisi, h.YaraliSayisi, h.YikilanBina, r.RiskSkoru, z.ZeminSinifi
FROM Deprem d
JOIN HasarKaydi h ON d.DepremID = h.DepremID
JOIN YerlesimBirimi y ON h.YerlesimID = y.YerlesimID
LEFT JOIN RiskAnalizi r ON y.YerlesimID = r.YerlesimID
LEFT JOIN ZeminBilgisi z ON y.YerlesimID = z.YerlesimID;
GO

-- B) HALK EKRANI
CREATE VIEW vw_Halk_Ekrani AS
SELECT d.TarihSaat, y.Il, y.Ilce, d.BuyuklukMw, d.Derinlik
FROM Deprem d
JOIN Deprem_Yerlesim dy ON d.DepremID = dy.DepremID
JOIN YerlesimBirimi y ON dy.YerlesimID = y.YerlesimID;
GO

-- C) GENEL ANALİZLER
CREATE VIEW vw_BuyukDepremler AS
SELECT d.DepremID, CONVERT(VARCHAR(19), d.TarihSaat, 120) AS TarihSaat, d.Enlem, d.Boylam, d.Derinlik, d.BuyuklukMw, d.Tip, f.FayAdi, f.Tip AS FayTipi
FROM Deprem d
LEFT JOIN FayHatti f ON d.FayID = f.FayID
WHERE d.BuyuklukMw >= 5.0;
GO

CREATE VIEW vw_YuksekRiskliYerlesimler AS
SELECT y.YerlesimID, y.Il, y.Ilce, y.Nufus, r.RiskSkoru, t.PGA, t.TehlikeSeviyesi, z.ZeminSinifi, z.Vs30
FROM YerlesimBirimi y
JOIN RiskAnalizi r    ON y.YerlesimID = r.YerlesimID
JOIN TehlikeParametresi t ON y.YerlesimID = t.YerlesimID
JOIN ZeminBilgisi z   ON y.YerlesimID = z.YerlesimID
WHERE r.RiskSkoru >= 0.70;
GO

CREATE VIEW vw_HasarOzeti AS
SELECT d.DepremID, CONVERT(VARCHAR(10), d.TarihSaat, 23) AS DepremTarihi, d.BuyuklukMw, y.Il, y.Ilce, h.OlumSayisi, h.YaraliSayisi, h.YikilanBina
FROM HasarKaydi h
JOIN Deprem d          ON h.DepremID = d.DepremID
JOIN YerlesimBirimi y  ON h.YerlesimID = y.YerlesimID;
GO

CREATE VIEW vw_FayIstatistikleri AS
SELECT f.FayID, f.FayAdi, f.Tip, f.Uzunluk_km, COUNT(d.DepremID) AS ToplamDepremSayisi, MAX(d.BuyuklukMw) AS MaksimumBuyukluk, AVG(d.BuyuklukMw) AS OrtalamaBuyukluk, AVG(d.Derinlik) AS OrtalamaDerinlik
FROM FayHatti f
LEFT JOIN Deprem d ON f.FayID = d.FayID
GROUP BY f.FayID, f.FayAdi, f.Tip, f.Uzunluk_km;
GO

CREATE VIEW vw_KullaniciRiskRaporu AS
SELECT k.AdSoyad AS AnaliziYapanKisi, k.Rol AS KullaniciRolu, y.Il AS AnalizEdilenBolge, y.Ilce, r.RiskSkoru, r.HesaplamaTarihi
FROM RiskAnalizi r
JOIN Kullanici k ON r.HesaplayanKullaniciID = k.KullaniciID
JOIN YerlesimBirimi y ON r.YerlesimID = y.YerlesimID;
GO

-- ============================================================
-- 7. STORED PROCEDURE'LER
-- ============================================================
CREATE PROCEDURE sp_DepremSorgula
    @BasTarih    DATETIME,
    @BitisTarih  DATETIME,
    @MinBuyukluk DECIMAL(3,1) = 0.0,
    @MaxBuyukluk DECIMAL(3,1) = 9.9
AS
BEGIN
    SET NOCOUNT ON;
    SELECT d.DepremID, CONVERT(VARCHAR(19), d.TarihSaat, 120) AS TarihSaat, d.Enlem, d.Boylam, d.Derinlik, d.BuyuklukMw, d.Tip, f.FayAdi
    FROM Deprem d
    LEFT JOIN FayHatti f ON d.FayID = f.FayID
    WHERE d.TarihSaat BETWEEN @BasTarih AND @BitisTarih AND d.BuyuklukMw BETWEEN @MinBuyukluk AND @MaxBuyukluk
    ORDER BY d.TarihSaat DESC;
END;
GO

CREATE PROCEDURE sp_YerlesimRiskRaporu
    @Il    VARCHAR(50) = NULL,
    @Ilce  VARCHAR(80) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT y.Il, y.Ilce, y.Nufus, r.RiskSkoru, t.PGA, t.TehlikeSeviyesi, z.ZeminSinifi, z.Vs30, ISNULL(SUM(h.OlumSayisi), 0) AS ToplamOlum, ISNULL(SUM(h.YaraliSayisi), 0) AS ToplamYarali, ISNULL(SUM(h.YikilanBina), 0) AS ToplamYikilanBina
    FROM YerlesimBirimi y
    LEFT JOIN RiskAnalizi r        ON y.YerlesimID = r.YerlesimID
    LEFT JOIN TehlikeParametresi t ON y.YerlesimID = t.YerlesimID
    LEFT JOIN ZeminBilgisi z       ON y.YerlesimID = z.YerlesimID
    LEFT JOIN HasarKaydi h         ON y.YerlesimID = h.YerlesimID
    WHERE (@Il IS NULL OR y.Il LIKE '%' + @Il + '%') AND (@Ilce IS NULL OR y.Ilce LIKE '%' + @Ilce + '%')
    GROUP BY y.Il, y.Ilce, y.Nufus, r.RiskSkoru, t.PGA, t.TehlikeSeviyesi, z.ZeminSinifi, z.Vs30
    ORDER BY r.RiskSkoru DESC;
END;
GO

CREATE PROCEDURE sp_DepremEtkiAnaLizi
    @DepremID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT d.DepremID, d.BuyuklukMw, CONVERT(VARCHAR(19), d.TarihSaat, 120) AS TarihSaat, f.FayAdi, y.Il, y.Ilce, y.Nufus, dy.EtkiSeviyesi, ISNULL(h.OlumSayisi, 0) AS Olum, ISNULL(h.YaraliSayisi, 0) AS Yarali, ISNULL(h.YikilanBina, 0) AS YikilanBina
    FROM Deprem d
    LEFT JOIN FayHatti f           ON d.FayID = f.FayID
    JOIN Deprem_Yerlesim dy        ON d.DepremID = dy.DepremID
    JOIN YerlesimBirimi y          ON dy.YerlesimID = y.YerlesimID
    LEFT JOIN HasarKaydi h         ON d.DepremID = h.DepremID AND dy.YerlesimID = h.YerlesimID
    WHERE d.DepremID = @DepremID
    ORDER BY dy.EtkiSeviyesi;
END;
GO

CREATE PROCEDURE sp_YillikDepremOzeti
    @Yil INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT MONTH(TarihSaat) AS Ay, COUNT(*) AS DepremSayisi, MAX(BuyuklukMw) AS EnBuyuk, AVG(BuyuklukMw) AS Ortalama, SUM(CASE WHEN BuyuklukMw >= 5.0 THEN 1 ELSE 0 END) AS BuyukDepremSayisi
    FROM Deprem
    WHERE YEAR(TarihSaat) = @Yil
    GROUP BY MONTH(TarihSaat)
    ORDER BY Ay;
END;
GO

-- ============================================================
-- 8. TRİGGER'LAR (Tetikleyiciler)
-- ============================================================
CREATE TRIGGER trg_HasarSonrasiRiskGuncelle
ON HasarKaydi
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE r
    SET r.RiskSkoru = CASE
        WHEN (i.OlumSayisi > 100 OR i.YikilanBina > 1000) THEN CASE WHEN r.RiskSkoru + 0.05 > 1.0 THEN 1.0 ELSE r.RiskSkoru + 0.05 END
        WHEN (i.OlumSayisi > 10 OR i.YikilanBina > 100) THEN CASE WHEN r.RiskSkoru + 0.02 > 1.0 THEN 1.0 ELSE r.RiskSkoru + 0.02 END
        ELSE r.RiskSkoru
    END,
    r.HesaplamaTarihi = CAST(GETDATE() AS DATE)
    FROM RiskAnalizi r
    JOIN inserted i ON r.YerlesimID = i.YerlesimID;
END;
GO

CREATE TRIGGER trg_BuyukDepremUyari
ON Deprem
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO DepremUyariLog (DepremID, BuyuklukMw, TarihSaat, UyariMesaji)
    SELECT DepremID, BuyuklukMw, TarihSaat, 'UYARI: Mw ' + CAST(BuyuklukMw AS VARCHAR(5)) + ' büyüklüğünde deprem tespit edildi. Konum: ' + CAST(Enlem AS VARCHAR(12)) + ', ' + CAST(Boylam AS VARCHAR(12))
    FROM inserted
    WHERE BuyuklukMw >= 6.0;
END;
GO

--SORGUSU 1: İllere Göre Toplam Can Kaybı ve Yıkılan Bina (GROUP BY ve JOIN İçerir)
-- Amaç: En çok hasar alan illeri tespit etmek.
SELECT 
    y.Il, 
    SUM(h.OlumSayisi) AS ToplamVefat, 
    SUM(h.YikilanBina) AS ToplamYikilanBina
FROM HasarKaydi h
JOIN YerlesimBirimi y ON h.YerlesimID = y.YerlesimID
GROUP BY y.Il
ORDER BY ToplamVefat DESC;

-- SORGU 2: Ortalama Büyüklüğün Üzerindeki Depremler (ALT SORGU / SUBQUERY İçerir)
-- Amaç: Sisteme kayıtlı tüm depremlerin ortalama büyüklüğünü bulup, sadece ondan büyük olanları listelemek.
SELECT 
    TarihSaat, 
    BuyuklukMw, 
    Tip 
FROM Deprem
WHERE BuyuklukMw > (SELECT AVG(BuyuklukMw) FROM Deprem)
ORDER BY BuyuklukMw DESC;

-- SORGU 3: En Kötü Zemin Sınıfına (ZF) Sahip Yerleşimler ve Tehlike Durumları (Çoklu JOIN)
SELECT 
    y.Il, 
    y.Ilce, 
    z.ZeminSinifi, 
    t.PGA, 
    t.TehlikeSeviyesi
FROM YerlesimBirimi y
JOIN ZeminBilgisi z ON y.YerlesimID = z.YerlesimID
JOIN TehlikeParametresi t ON y.YerlesimID = t.YerlesimID
WHERE z.ZeminSinifi = 'ZF' OR z.ZeminSinifi = 'ZE'
ORDER BY t.PGA DESC;

-- SORGU 4: Kullanıcı (Aktör) Analizi: Hangi Uzman, Hangi Bölgenin Riskini Hesapladı?
-- Amaç: Sisteme yeni eklediğimiz "Kullanici" tablosunun çalıştığını göstermek.
SELECT 
    k.AdSoyad AS UzmanAdi, 
    k.Rol, 
    y.Il AS IncelenenBolge, 
    r.RiskSkoru
FROM RiskAnalizi r
JOIN Kullanici k ON r.HesaplayanKullaniciID = k.KullaniciID
JOIN YerlesimBirimi y ON r.YerlesimID = y.YerlesimID
ORDER BY r.RiskSkoru DESC;

-- SORGU 5: Aktif Olan Fay Hatlarının Ürettiği Maksimum Deprem Büyüklükleri (GROUP BY ve LEFT JOIN)
SELECT 
    f.FayAdi, 
    f.Uzunluk_km, 
    MAX(d.BuyuklukMw) AS UrettigiEnBuyukDeprem,
    COUNT(d.DepremID) AS ToplamDepremSayisi
FROM FayHatti f
LEFT JOIN Deprem d ON f.FayID = d.FayID
WHERE f.AktifMi = 1
GROUP BY f.FayAdi, f.Uzunluk_km
ORDER BY UrettigiEnBuyukDeprem DESC;

-- SORGU 6: Deprem_Yerlesim (N:N Ara Tablosu) Üzerinden "Çok Yıkıcı" Etki Alan Yerler
-- Amaç: Kriterlerde istenen "Çoktan Çoka İlişki"nin sorgulandığını kanıtlamak.
SELECT 
    d.TarihSaat, 
    d.BuyuklukMw, 
    y.Il, 
    y.Ilce, 
    dy.EtkiSeviyesi
FROM Deprem_Yerlesim dy
JOIN Deprem d ON dy.DepremID = d.DepremID
JOIN YerlesimBirimi y ON dy.YerlesimID = y.YerlesimID
WHERE dy.EtkiSeviyesi = 'Şiddetli' OR dy.EtkiSeviyesi = 'Çok Yıkıcı';

-- SORGU 7: Hiç Hasar Görmemiş "Güvenli" Şehirler (LEFT JOIN ve IS NULL Kullanımı)
-- Amaç: Sisteme kayıtlı olup hasar kaydı olmayan yerleri bulmak.
SELECT 
    y.Il, 
    y.Ilce, 
    y.Nufus
FROM YerlesimBirimi y
LEFT JOIN HasarKaydi h ON y.YerlesimID = h.YerlesimID
WHERE h.HasarID IS NULL;

-- SORGU 8: Büyüklüğü 7.0'dan Büyük Olan Depremlerde Yıkılan Bina Ortalaması (GROUP BY ve HAVING)
-- Amaç: HAVING komutunun projede kullanıldığını göstermek.
SELECT 
    d.BuyuklukMw, 
    AVG(h.YikilanBina) AS OrtalamaYikilanBina,
    SUM(h.OlumSayisi) AS ToplamCanKaybi
FROM HasarKaydi h
JOIN Deprem d ON h.DepremID = d.DepremID
GROUP BY d.BuyuklukMw
HAVING d.BuyuklukMw >= 7.0;

-- SORGU 9: En Yüksek Risk Skoruna Sahip Şehri Bulan İçiçe Sorgu (Nested Subquery)
SELECT 
    Il, 
    Ilce, 
    Nufus 
FROM YerlesimBirimi 
WHERE YerlesimID = (
    SELECT TOP 1 YerlesimID 
    FROM RiskAnalizi 
    ORDER BY RiskSkoru DESC
);

-- SORGU 10: Yıllara Göre Deprem Dağılımı ve Ortalama Derinlik (Zaman Analizi)
SELECT 
    YEAR(TarihSaat) AS DepremYili, 
    COUNT(DepremID) AS O_YilkiDepremSayisi, 
    AVG(Derinlik) AS OrtalamaDerinlik
FROM Deprem
GROUP BY YEAR(TarihSaat)
ORDER BY DepremYili DESC;
GO




                          --- YARDIMCI KODLAR---




USE DepremDB;

-- SifreHash sütunu ekle (eğer yoksa)
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
               WHERE TABLE_NAME='Kullanici' AND COLUMN_NAME='SifreHash')
    ALTER TABLE Kullanici ADD SifreHash VARCHAR(255);

-- RolDegisiklikLog tablosu ekle (eğer yoksa)
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES 
               WHERE TABLE_NAME='RolDegisiklikLog')
CREATE TABLE RolDegisiklikLog (
    LogID         INT         PRIMARY KEY IDENTITY(1,1),
    KullaniciID   INT,
    EskiRol       VARCHAR(30),
    YeniRol       VARCHAR(30),
    DegisimZamani DATETIME    DEFAULT GETDATE()
);

-- RolIzin tablosu var mı kontrol
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES 
               WHERE TABLE_NAME='RolIzin')
CREATE TABLE RolIzin (
    IzinID    INT          PRIMARY KEY IDENTITY(1,1),
    Rol       VARCHAR(30)  NOT NULL,
    IslemAdi  VARCHAR(100) NOT NULL,
    Aciklama  VARCHAR(200)
);







USE DepremDB;

-- Şifre tüm test kullanıcıları için: Test1234
-- bcrypt hash: $2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TsCib9tMSSTK9uC5J7F8jGRN72bS

DECLARE @hash VARCHAR(255) = '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TsCib9tMSSTK9uC5J7F8jGRN72bS';

-- 100 Kullanıcı
INSERT INTO Kullanici (Gmail, AdSoyad, Rol, SifreHash) VALUES
('kullanici01@gmail.com','Ali Yilmaz','kullanici',@hash),
('kullanici02@gmail.com','Ayse Kaya','kullanici',@hash),
('kullanici03@gmail.com','Mehmet Demir','kullanici',@hash),
('kullanici04@gmail.com','Fatma Celik','kullanici',@hash),
('kullanici05@gmail.com','Ahmet Sahin','kullanici',@hash),
('kullanici06@gmail.com','Zeynep Arslan','kullanici',@hash),
('kullanici07@gmail.com','Mustafa Dogan','kullanici',@hash),
('kullanici08@gmail.com','Elif Kilic','kullanici',@hash),
('kullanici09@gmail.com','Ibrahim Ozturk','kullanici',@hash),
('kullanici10@gmail.com','Hatice Aydın','kullanici',@hash),
('kullanici11@gmail.com','Huseyin Kurt','kullanici',@hash),
('kullanici12@gmail.com','Merve Polat','kullanici',@hash),
('kullanici13@gmail.com','Yusuf Ozdemir','kullanici',@hash),
('kullanici14@gmail.com','Selin Koc','kullanici',@hash),
('kullanici15@gmail.com','Emre Aslan','kullanici',@hash),
('kullanici16@gmail.com','Neslihan Yildiz','kullanici',@hash),
('kullanici17@gmail.com','Burak Guler','kullanici',@hash),
('kullanici18@gmail.com','Gamze Erdogan','kullanici',@hash),
('kullanici19@gmail.com','Serkan Bulut','kullanici',@hash),
('kullanici20@gmail.com','Tugba Simsek','kullanici',@hash),
('kullanici21@gmail.com','Omer Caliskan','kullanici',@hash),
('kullanici22@gmail.com','Derya Keskin','kullanici',@hash),
('kullanici23@gmail.com','Koray Aydin','kullanici',@hash),
('kullanici24@gmail.com','Pinar Kaplan','kullanici',@hash),
('kullanici25@gmail.com','Volkan Yilmaz','kullanici',@hash),
('kullanici26@gmail.com','Esra Ozkan','kullanici',@hash),
('kullanici27@gmail.com','Tolga Kara','kullanici',@hash),
('kullanici28@gmail.com','Sibel Turk','kullanici',@hash),
('kullanici29@gmail.com','Murat Ak','kullanici',@hash),
('kullanici30@gmail.com','Ceren Yavuz','kullanici',@hash),
('kullanici31@gmail.com','Alper Ince','kullanici',@hash),
('kullanici32@gmail.com','Burcu Ozlen','kullanici',@hash),
('kullanici33@gmail.com','Selcuk Bozkurt','kullanici',@hash),
('kullanici34@gmail.com','Irem Sari','kullanici',@hash),
('kullanici35@gmail.com','Furkan Cinar','kullanici',@hash),
('kullanici36@gmail.com','Gulsen Yuce','kullanici',@hash),
('kullanici37@gmail.com','Baris Duman','kullanici',@hash),
('kullanici38@gmail.com','Ozlem Karaca','kullanici',@hash),
('kullanici39@gmail.com','Deniz Gunay','kullanici',@hash),
('kullanici40@gmail.com','Aysun Karakus','kullanici',@hash),
('kullanici41@gmail.com','Hakan Unal','kullanici',@hash),
('kullanici42@gmail.com','Melis Ozer','kullanici',@hash),
('kullanici43@gmail.com','Tarik Bayram','kullanici',@hash),
('kullanici44@gmail.com','Nurgul Acar','kullanici',@hash),
('kullanici45@gmail.com','Onur Demirci','kullanici',@hash),
('kullanici46@gmail.com','Serap Ozcelik','kullanici',@hash),
('kullanici47@gmail.com','Umut Karadag','kullanici',@hash),
('kullanici48@gmail.com','Filiz Mutlu','kullanici',@hash),
('kullanici49@gmail.com','Levent Erdem','kullanici',@hash),
('kullanici50@gmail.com','Arzu Kircali','kullanici',@hash),
('kullanici51@gmail.com','Eray Topcu','kullanici',@hash),
('kullanici52@gmail.com','Gulcin Yilmaz','kullanici',@hash),
('kullanici53@gmail.com','Semih Ozkaya','kullanici',@hash),
('kullanici54@gmail.com','Nazli Korkmaz','kullanici',@hash),
('kullanici55@gmail.com','Adem Gunduz','kullanici',@hash),
('kullanici56@gmail.com','Ilknur Bas','kullanici',@hash),
('kullanici57@gmail.com','Cagri Demir','kullanici',@hash),
('kullanici58@gmail.com','Havva Saygili','kullanici',@hash),
('kullanici59@gmail.com','Kemal Ozturk','kullanici',@hash),
('kullanici60@gmail.com','Dilek Kartal','kullanici',@hash),
('kullanici61@gmail.com','Oguz Cakir','kullanici',@hash),
('kullanici62@gmail.com','Asli Demirtas','kullanici',@hash),
('kullanici63@gmail.com','Serhat Yilmaz','kullanici',@hash),
('kullanici64@gmail.com','Zehra Aydogan','kullanici',@hash),
('kullanici65@gmail.com','Ercan Bulut','kullanici',@hash),
('kullanici66@gmail.com','Nuray Ozkan','kullanici',@hash),
('kullanici67@gmail.com','Taner Karaca','kullanici',@hash),
('kullanici68@gmail.com','Bilge Sahin','kullanici',@hash),
('kullanici69@gmail.com','Ufuk Kaya','kullanici',@hash),
('kullanici70@gmail.com','Selma Dogan','kullanici',@hash),
('kullanici71@gmail.com','Ozan Yildirim','kullanici',@hash),
('kullanici72@gmail.com','Hacer Kurt','kullanici',@hash),
('kullanici73@gmail.com','Berkay Arslan','kullanici',@hash),
('kullanici74@gmail.com','Tugce Polat','kullanici',@hash),
('kullanici75@gmail.com','Erdem Kilic','kullanici',@hash),
('kullanici76@gmail.com','Pelin Ozdemir','kullanici',@hash),
('kullanici77@gmail.com','Sinan Koc','kullanici',@hash),
('kullanici78@gmail.com','Gizem Aslan','kullanici',@hash),
('kullanici79@gmail.com','Mert Yildiz','kullanici',@hash),
('kullanici80@gmail.com','Seda Guler','kullanici',@hash),
('kullanici81@gmail.com','Yigit Erdogan','kullanici',@hash),
('kullanici82@gmail.com','Reyhan Bulut','kullanici',@hash),
('kullanici83@gmail.com','Cagatay Simsek','kullanici',@hash),
('kullanici84@gmail.com','Ebru Caliskan','kullanici',@hash),
('kullanici85@gmail.com','Kaan Keskin','kullanici',@hash),
('kullanici86@gmail.com','Sedef Aydin','kullanici',@hash),
('kullanici87@gmail.com','Ilker Kaplan','kullanici',@hash),
('kullanici88@gmail.com','Cemre Yilmaz','kullanici',@hash),
('kullanici89@gmail.com','Doruk Ozkan','kullanici',@hash),
('kullanici90@gmail.com','Nihan Kara','kullanici',@hash),
('kullanici91@gmail.com','Arda Turk','kullanici',@hash),
('kullanici92@gmail.com','Melike Ak','kullanici',@hash),
('kullanici93@gmail.com','Berk Yavuz','kullanici',@hash),
('kullanici94@gmail.com','Duygu Ince','kullanici',@hash),
('kullanici95@gmail.com','Alp Ozlen','kullanici',@hash),
('kullanici96@gmail.com','Sinem Bozkurt','kullanici',@hash),
('kullanici97@gmail.com','Eren Sari','kullanici',@hash),
('kullanici98@gmail.com','Defne Cinar','kullanici',@hash),
('kullanici99@gmail.com','Tayfun Yuce','kullanici',@hash),
('kullanici100@gmail.com','Ece Duman','kullanici',@hash),

-- 20 Araştırmacı
('arastirmaci01@gmail.com','Dr. Ahmet Karaoglu','arastirmaci',@hash),
('arastirmaci02@gmail.com','Dr. Fatma Soylu','arastirmaci',@hash),
('arastirmaci03@gmail.com','Dr. Mehmet Uysal','arastirmaci',@hash),
('arastirmaci04@gmail.com','Dr. Zeynep Altun','arastirmaci',@hash),
('arastirmaci05@gmail.com','Dr. Ali Gokce','arastirmaci',@hash),
('arastirmaci06@gmail.com','Dr. Ayse Cetin','arastirmaci',@hash),
('arastirmaci07@gmail.com','Dr. Ibrahim Yalcin','arastirmaci',@hash),
('arastirmaci08@gmail.com','Dr. Hatice Ozkan','arastirmaci',@hash),
('arastirmaci09@gmail.com','Dr. Huseyin Baykal','arastirmaci',@hash),
('arastirmaci10@gmail.com','Dr. Merve Gungor','arastirmaci',@hash),
('arastirmaci11@gmail.com','Dr. Yusuf Aksoy','arastirmaci',@hash),
('arastirmaci12@gmail.com','Dr. Selin Demircan','arastirmaci',@hash),
('arastirmaci13@gmail.com','Dr. Emre Karakaya','arastirmaci',@hash),
('arastirmaci14@gmail.com','Dr. Neslihan Ozturk','arastirmaci',@hash),
('arastirmaci15@gmail.com','Dr. Burak Yilmaz','arastirmaci',@hash),
('arastirmaci16@gmail.com','Dr. Gamze Arslan','arastirmaci',@hash),
('arastirmaci17@gmail.com','Dr. Serkan Demir','arastirmaci',@hash),
('arastirmaci18@gmail.com','Dr. Tugba Kaya','arastirmaci',@hash),
('arastirmaci19@gmail.com','Dr. Omer Sahin','arastirmaci',@hash),
('arastirmaci20@gmail.com','Dr. Derya Celik','arastirmaci',@hash),

-- 2 Afet Yöneticisi
('afet01@gmail.com','Uzm. Kemal Aydın','afet_yoneticisi',@hash),
('afet02@gmail.com','Uzm. Leyla Karaca','afet_yoneticisi',@hash);

-- Kontrol
SELECT Rol, COUNT(*) AS Sayi FROM Kullanici GROUP BY Rol;











    USE DepremDB;
SELECT COUNT(*) AS ToplamDeprem FROM Deprem;
SELECT Sehir, COUNT(*) AS Sayi FROM Deprem GROUP BY Sehir ORDER BY Sayi DESC;


USE DepremDB;

UPDATE Deprem SET Sehir = CASE
    WHEN Enlem BETWEEN 40.5 AND 42.1 AND Boylam BETWEEN 27.5 AND 30.5 THEN 'Istanbul'
    WHEN Enlem BETWEEN 40.5 AND 41.5 AND Boylam BETWEEN 29.0 AND 31.5 THEN 'Kocaeli'
    WHEN Enlem BETWEEN 40.3 AND 41.0 AND Boylam BETWEEN 30.5 AND 32.0 THEN 'Sakarya'
    WHEN Enlem BETWEEN 40.2 AND 40.8 AND Boylam BETWEEN 31.0 AND 32.0 THEN 'Duzce'
    WHEN Enlem BETWEEN 40.5 AND 41.2 AND Boylam BETWEEN 31.5 AND 33.0 THEN 'Bolu'
    WHEN Enlem BETWEEN 39.5 AND 40.5 AND Boylam BETWEEN 29.0 AND 30.5 THEN 'Bursa'
    WHEN Enlem BETWEEN 38.0 AND 39.5 AND Boylam BETWEEN 26.5 AND 28.5 THEN 'Izmir'
    WHEN Enlem BETWEEN 38.5 AND 39.5 AND Boylam BETWEEN 27.5 AND 29.5 THEN 'Manisa'
    WHEN Enlem BETWEEN 37.5 AND 38.5 AND Boylam BETWEEN 27.0 AND 29.0 THEN 'Aydin'
    WHEN Enlem BETWEEN 37.0 AND 38.5 AND Boylam BETWEEN 28.5 AND 30.0 THEN 'Denizli'
    WHEN Enlem BETWEEN 36.5 AND 37.5 AND Boylam BETWEEN 27.5 AND 30.0 THEN 'Mugla'
    WHEN Enlem BETWEEN 37.5 AND 39.0 AND Boylam BETWEEN 29.5 AND 31.5 THEN 'Afyonkarahisar'
    WHEN Enlem BETWEEN 38.5 AND 39.8 AND Boylam BETWEEN 28.5 AND 30.5 THEN 'Kutahya'
    WHEN Enlem BETWEEN 39.0 AND 40.0 AND Boylam BETWEEN 30.0 AND 31.5 THEN 'Eskisehir'
    WHEN Enlem BETWEEN 39.0 AND 40.5 AND Boylam BETWEEN 32.5 AND 34.5 THEN 'Ankara'
    WHEN Enlem BETWEEN 36.5 AND 38.5 AND Boylam BETWEEN 31.5 AND 34.5 THEN 'Konya'
    WHEN Enlem BETWEEN 36.0 AND 37.5 AND Boylam BETWEEN 29.5 AND 32.5 THEN 'Antalya'
    WHEN Enlem BETWEEN 37.5 AND 38.5 AND Boylam BETWEEN 30.0 AND 31.5 THEN 'Isparta'
    WHEN Enlem BETWEEN 37.0 AND 38.0 AND Boylam BETWEEN 29.5 AND 31.0 THEN 'Burdur'
    WHEN Enlem BETWEEN 36.5 AND 37.5 AND Boylam BETWEEN 34.5 AND 36.5 THEN 'Adana'
    WHEN Enlem BETWEEN 36.0 AND 37.5 AND Boylam BETWEEN 32.5 AND 35.0 THEN 'Mersin'
    WHEN Enlem BETWEEN 36.0 AND 37.0 AND Boylam BETWEEN 35.5 AND 37.0 THEN 'Hatay'
    WHEN Enlem BETWEEN 36.5 AND 37.5 AND Boylam BETWEEN 36.5 AND 38.0 THEN 'Gaziantep'
    WHEN Enlem BETWEEN 37.0 AND 38.5 AND Boylam BETWEEN 36.0 AND 38.5 THEN 'Kahramanmaras'
    WHEN Enlem BETWEEN 37.0 AND 38.0 AND Boylam BETWEEN 37.5 AND 39.5 THEN 'Adiyaman'
    WHEN Enlem BETWEEN 37.5 AND 38.8 AND Boylam BETWEEN 37.5 AND 39.5 THEN 'Malatya'
    WHEN Enlem BETWEEN 38.0 AND 39.0 AND Boylam BETWEEN 38.5 AND 40.5 THEN 'Elazig'
    WHEN Enlem BETWEEN 38.5 AND 39.5 AND Boylam BETWEEN 40.0 AND 41.5 THEN 'Bingol'
    WHEN Enlem BETWEEN 38.5 AND 39.5 AND Boylam BETWEEN 41.0 AND 42.5 THEN 'Mus'
    WHEN Enlem BETWEEN 37.5 AND 39.5 AND Boylam BETWEEN 42.5 AND 44.5 THEN 'Van'
    WHEN Enlem BETWEEN 37.5 AND 38.8 AND Boylam BETWEEN 41.5 AND 43.0 THEN 'Bitlis'
    WHEN Enlem BETWEEN 37.0 AND 38.5 AND Boylam BETWEEN 41.5 AND 42.5 THEN 'Siirt'
    WHEN Enlem BETWEEN 37.0 AND 38.0 AND Boylam BETWEEN 43.0 AND 44.8 THEN 'Hakkari'
    WHEN Enlem BETWEEN 37.0 AND 37.8 AND Boylam BETWEEN 42.0 AND 43.5 THEN 'Sirnak'
    WHEN Enlem BETWEEN 36.8 AND 37.8 AND Boylam BETWEEN 40.0 AND 42.5 THEN 'Mardin'
    WHEN Enlem BETWEEN 37.5 AND 38.8 AND Boylam BETWEEN 39.5 AND 41.5 THEN 'Diyarbakir'
    WHEN Enlem BETWEEN 36.5 AND 38.0 AND Boylam BETWEEN 37.5 AND 40.5 THEN 'Sanliurfa'
    WHEN Enlem BETWEEN 37.5 AND 38.5 AND Boylam BETWEEN 34.0 AND 36.0 THEN 'Nigde'
    WHEN Enlem BETWEEN 38.0 AND 39.0 AND Boylam BETWEEN 34.0 AND 35.5 THEN 'Nevsehir'
    WHEN Enlem BETWEEN 38.0 AND 39.5 AND Boylam BETWEEN 35.0 AND 37.0 THEN 'Kayseri'
    WHEN Enlem BETWEEN 38.5 AND 40.5 AND Boylam BETWEEN 36.5 AND 39.5 THEN 'Sivas'
    WHEN Enlem BETWEEN 39.2 AND 40.2 AND Boylam BETWEEN 38.0 AND 40.0 THEN 'Erzincan'
    WHEN Enlem BETWEEN 39.5 AND 41.0 AND Boylam BETWEEN 40.5 AND 43.0 THEN 'Erzurum'
    WHEN Enlem BETWEEN 40.0 AND 41.5 AND Boylam BETWEEN 42.0 AND 44.0 THEN 'Kars'
    WHEN Enlem BETWEEN 39.0 AND 40.0 AND Boylam BETWEEN 42.5 AND 44.5 THEN 'Agri'
    WHEN Enlem BETWEEN 38.5 AND 39.5 AND Boylam BETWEEN 39.0 AND 40.5 THEN 'Tunceli'
    WHEN Enlem BETWEEN 40.5 AND 41.5 AND Boylam BETWEEN 38.5 AND 40.5 THEN 'Trabzon'
    WHEN Enlem BETWEEN 40.8 AND 41.5 AND Boylam BETWEEN 40.0 AND 41.5 THEN 'Rize'
    WHEN Enlem BETWEEN 40.3 AND 41.2 AND Boylam BETWEEN 37.5 AND 39.5 THEN 'Giresun'
    WHEN Enlem BETWEEN 40.3 AND 41.2 AND Boylam BETWEEN 36.5 AND 38.0 THEN 'Ordu'
    WHEN Enlem BETWEEN 40.8 AND 41.8 AND Boylam BETWEEN 35.5 AND 37.5 THEN 'Samsun'
    WHEN Enlem BETWEEN 41.0 AND 42.3 AND Boylam BETWEEN 34.5 AND 36.0 THEN 'Sinop'
    WHEN Enlem BETWEEN 41.0 AND 42.1 AND Boylam BETWEEN 33.0 AND 35.0 THEN 'Kastamonu'
    WHEN Enlem BETWEEN 41.0 AND 41.8 AND Boylam BETWEEN 31.5 AND 32.5 THEN 'Zonguldak'
    WHEN Enlem BETWEEN 40.0 AND 41.0 AND Boylam BETWEEN 33.0 AND 34.5 THEN 'Cankiri'
    WHEN Enlem BETWEEN 40.0 AND 41.0 AND Boylam BETWEEN 34.0 AND 35.5 THEN 'Corum'
    WHEN Enlem BETWEEN 40.2 AND 41.0 AND Boylam BETWEEN 35.5 AND 37.0 THEN 'Amasya'
    WHEN Enlem BETWEEN 39.5 AND 40.8 AND Boylam BETWEEN 35.5 AND 37.5 THEN 'Tokat'
    WHEN Enlem BETWEEN 39.0 AND 40.0 AND Boylam BETWEEN 34.5 AND 36.5 THEN 'Yozgat'
    WHEN Enlem BETWEEN 39.5 AND 40.2 AND Boylam BETWEEN 33.0 AND 34.0 THEN 'Kirikkale'
    WHEN Enlem BETWEEN 38.8 AND 39.8 AND Boylam BETWEEN 33.5 AND 35.0 THEN 'Kirsehir'
    WHEN Enlem BETWEEN 37.8 AND 38.8 AND Boylam BETWEEN 33.0 AND 34.5 THEN 'Aksaray'
    WHEN Enlem BETWEEN 36.8 AND 38.0 AND Boylam BETWEEN 32.5 AND 34.5 THEN 'Karaman'
    WHEN Enlem BETWEEN 36.8 AND 37.5 AND Boylam BETWEEN 35.5 AND 37.0 THEN 'Osmaniye'
    ELSE 'Turkiye'
END;

-- Fay ataması
UPDATE Deprem SET FayID = CASE
    WHEN Enlem BETWEEN 40.0 AND 41.5 AND Boylam BETWEEN 27.0 AND 32.0 THEN 3
    WHEN Enlem BETWEEN 40.0 AND 41.0 AND Boylam BETWEEN 32.0 AND 36.0 THEN 2
    WHEN Enlem BETWEEN 39.5 AND 40.5 AND Boylam BETWEEN 36.0 AND 40.0 THEN 1
    WHEN Enlem BETWEEN 37.0 AND 39.5 AND Boylam BETWEEN 36.0 AND 42.0 THEN 4
    WHEN Enlem BETWEEN 37.0 AND 39.5 AND Boylam BETWEEN 25.5 AND 28.5 THEN 5
    WHEN Enlem BETWEEN 38.0 AND 39.5 AND Boylam BETWEEN 27.0 AND 29.0 THEN 6
    WHEN Enlem BETWEEN 37.5 AND 38.5 AND Boylam BETWEEN 27.5 AND 29.5 THEN 7
    WHEN Enlem BETWEEN 38.0 AND 39.0 AND Boylam BETWEEN 38.5 AND 40.5 THEN 8
    WHEN Enlem BETWEEN 38.5 AND 39.5 AND Boylam BETWEEN 43.0 AND 45.0 THEN 9
    WHEN Enlem BETWEEN 38.0 AND 39.0 AND Boylam BETWEEN 26.5 AND 28.0 THEN 10
    ELSE FayID
END
WHERE FayID IS NULL;

-- Kontrol
SELECT Sehir, COUNT(*) AS Sayi FROM Deprem GROUP BY Sehir ORDER BY Sayi DESC;




USE DepremDB;

-- Önce mevcut hasar kayıtlarını temizle
DELETE FROM HasarKaydi;

-- Gerçek tarihi deprem hasar verileri
-- (Büyük depremler için gerçek rakamlar, diğerleri için tahmini)

INSERT INTO HasarKaydi (DepremID, YerlesimID, OlumSayisi, YaraliSayisi, YikilanBina) VALUES

-- 1999 Gölcük (Mw 7.6) - ID: 5
(5, 12, 17480, 43953, 97000),
(5, 11, 3200, 7800, 15000),
(5, 13, 4500, 11200, 23000),
(5, 9, 1100, 3500, 4500),
(5, 14, 845, 4948, 5000),

-- 1999 Düzce (Mw 7.2) - ID: 9
(9, 14, 845, 4948, 5000),
(9, 15, 200, 900, 1200),

-- 2023 Kahramanmaraş 1 (Mw 7.7) - ID: 4
(4, 23, 21000, 45000, 85000),
(4, 24, 10000, 22000, 45000),
(4, 25, 5800, 13000, 28000),
(4, 26, 4200, 9500, 19000),
(4, 22, 1800, 4200, 8500),

-- 2023 Kahramanmaraş 2 (Mw 7.6) - ID: 7
(7, 23, 8500, 18000, 35000),
(7, 24, 4200, 9000, 18000),
(7, 25, 2800, 6500, 12000),

-- 2011 Van (Mw 7.2) - ID: 8
(8, 18, 604, 1966, 11000),
(8, 19, 150, 450, 2400),

-- 2020 İzmir (Mw 6.9) - ID: 25
(25, 4, 114, 1035, 3822),
(25, 5, 22, 280, 650),
(25, 6, 38, 420, 1100),

-- 2020 Elazığ (Mw 6.8) - ID: 22
(22, 21, 41, 1607, 1395),
(22, 20, 8, 280, 320),

-- 2003 Bingöl (Mw 6.4) - ID: 32
(32, 20, 177, 521, 3000),

-- 1992 Erzincan (Mw 6.8) - ID: 13
(13, 16, 653, 3850, 15000),

-- 2002 Afyon (Mw 6.5) - ID: 17
(17, 32, 44, 318, 2500),

-- 1976 Çaldıran (Mw 7.3) - ID: 19
(19, 18, 3840, 10000, 9000),

-- 1995 Dinar (Mw 6.0) - ID: 21
(21, 32, 94, 240, 5000),

-- 2011 Van artçısı (Mw 5.6) - ID: 30
(30, 19, 40, 260, 800),

-- 2019 İzmir (Mw 4.9) - ID: 44
(44, 4, 0, 12, 45),

-- 1967 Adapazarı (Mw 7.1) - ID: 45
(45, 13, 89, 235, 1200),

-- 2010 Kovancılar (Mw 6.0) - ID: 46
(46, 21, 51, 79, 850),

-- 2005 Hinis (Mw 5.9) - ID: 47
(47, 17, 7, 84, 350),

-- 1966 Varto (Mw 6.9) - ID: 65
(65, 18, 2394, 10000, 20000),

-- 1975 Lice (Mw 6.7) - ID: 68
(68, 20, 2385, 3500, 8800),

-- 1988 Erzincan (Mw 6.0) - ID: 70
(70, 16, 0, 45, 280),

-- 2000 Orta (Mw 6.0) - ID: 75
(75, 39, 0, 56, 420),

-- 2005 Karlıova (Mw 5.7) - ID: 79
(79, 20, 0, 35, 180),

-- 1983 Erzurum (Mw 6.9) - ID: 87
(87, 17, 1155, 1500, 3000),

-- 1966 Varto (Mw 6.4) - ID: 93
(93, 17, 19, 50, 600),

-- 2004 Bingöl artçı (Mw 5.5) - ID: 194
(194, 20, 0, 28, 150),

-- 1971 Burdur (Mw 6.2) - ID: 196
(196, 10, 57, 100, 1800),

-- 1970 Gediz (Mw 7.2) - ID: 204
(204, 11, 1086, 1260, 12000),

-- 1964 Manyas (Mw 6.9) - ID: 226
(226, 9, 23, 120, 4500),

-- 1971 Afyon (Mw 5.9) - ID: 283
(283, 32, 0, 42, 320),

-- 1969 Alasehir (Mw 6.5) - ID: 344
(344, 4, 53, 186, 2200),

-- 2014 Ege (Mw 5.1) - ID: 342
(342, 27, 0, 8, 35),

-- 2007 İzmir (Mw 4.9) - ID: 398
(398, 4, 0, 5, 18),

-- 2013 Marmara (Mw 4.8) - ID: 412
(412, 1, 0, 3, 8),

-- 1980 Erzurum (Mw 6.9) - ID: 424
(424, 17, 1307, 3000, 8500),

-- 2007 Bala (Mw 5.7) - ID: 513
(513, 7, 1, 58, 420),

-- 2010 Simav (Mw 5.9) - ID: 515
(515, 11, 0, 62, 850),

-- 2012 Van (Mw 5.0) - ID: 601
(601, 18, 0, 28, 150),

-- 2013 Erzurum (Mw 4.8) - ID: 746
(746, 17, 0, 12, 45),

-- 1965 Varto (Mw 6.0) - ID: 754
(754, 18, 22, 80, 650),

-- 2014 Manisa (Mw 5.1) - ID: 761
(761, 29, 0, 7, 28),

-- 2015 Çanakkale (Mw 5.3) - ID: 847
(847, 1, 0, 15, 42),

-- 2017 Bodrum (Mw 6.6) - ID: 885
(885, 27, 2, 520, 390),

-- 2018 Marmara (Mw 4.0) - ID: 908
(908, 1, 0, 2, 5),

-- 2019 Düzce (Mw 5.9) - ID: 1018
(1018, 14, 0, 48, 280),

-- 2021 İzmir (Mw 4.5) - ID: 1022
(1022, 4, 0, 6, 22),

-- 2021 Muğla (Mw 4.8) - ID: 1033
(1033, 27, 0, 8, 18),

-- 2016 Simav (Mw 5.0) - ID: 1071
(1071, 11, 0, 22, 85),

-- 2018 Manisa (Mw 5.1) - ID: 1189
(1189, 29, 0, 18, 65),

-- 2019 Kütahya (Mw 5.4) - ID: 1212
(1212, 11, 0, 42, 180),

-- 2020 Elazığ artçı (Mw 5.2) - ID: 1254
(1254, 21, 0, 35, 120),

-- 2020 Elazığ artçı (Mw 5.0) - ID: 1255
(1255, 21, 0, 28, 95),

-- 2019 Silivri (Mw 5.8) - ID: 1315
(1315, 1, 0, 38, 145),

-- 2019 Marmara (Mw 4.5) - ID: 1317
(1317, 2, 0, 5, 12),

-- 2021 İzmir (Mw 5.1) - ID: 1564
(1564, 4, 0, 18, 55),

-- 2021 Burdur (Mw 5.3) - ID: 1667
(1667, 10, 0, 25, 85),

-- 2022 Düzce (Mw 5.9) - ID: 1832
(1832, 14, 0, 68, 320),

-- 2022 Tokat (Mw 5.5) - ID: 1928
(1928, 38, 0, 32, 140),

-- 2022 Kütahya (Mw 4.9) - ID: 1933
(1933, 11, 0, 15, 48),

-- 2023 Hatay artçı (Mw 6.4) - ID: 2020
(2020, 24, 1200, 3500, 8500),

-- 2023 Malatya artçı (Mw 5.6) - ID: 2327
(2327, 22, 18, 125, 450),

-- 2023 Kahramanmaraş artçı (Mw 5.8) - ID: 2626
(2626, 23, 8, 85, 280),

-- 2023 Adıyaman artçı (Mw 5.5) - ID: 2791
(2791, 25, 5, 62, 185),

-- 2023 Hatay artçı (Mw 5.3) - ID: 2817
(2817, 24, 2, 38, 120);



USE DepremDB;
GO

ALTER VIEW vw_HasarOzeti AS
SELECT
    d.DepremID,
    CONVERT(VARCHAR(10), d.TarihSaat, 23) AS DepremTarihi,
    d.BuyuklukMw,
    d.Sehir AS DepremSehri,        -- depremin koordinat şehri
    y.Il,
    y.Ilce,
    y.Il AS Sehir,                  -- yerleşim birimi ili
    h.OlumSayisi,
    h.YaraliSayisi,
    h.YikilanBina,
    (h.OlumSayisi + h.YaraliSayisi) AS ToplamKayip
FROM HasarKaydi h
JOIN Deprem d         ON h.DepremID   = d.DepremID
JOIN YerlesimBirimi y ON h.YerlesimID = y.YerlesimID;
GO



USE DepremDB;
GO

-- sp_DepremEtkiAnalizi'ni HasarKaydi tablosundan çalışacak şekilde güncelle
ALTER PROCEDURE sp_DepremEtkiAnalizi
    @DepremID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        d.DepremID,
        d.BuyuklukMw,
        CONVERT(VARCHAR(19), d.TarihSaat, 120) AS TarihSaat,
        d.Sehir,
        f.FayAdi,
        y.Il,
        y.Ilce,
        y.Nufus,
        h.OlumSayisi  AS Olum,
        h.YaraliSayisi AS Yarali,
        h.YikilanBina,
        NULL AS EtkiSeviyesi
    FROM Deprem d
    LEFT JOIN FayHatti f   ON d.FayID     = f.FayID
    JOIN HasarKaydi h      ON d.DepremID  = h.DepremID
    JOIN YerlesimBirimi y  ON h.YerlesimID = y.YerlesimID
    WHERE d.DepremID = @DepremID;
END;
GO


SELECT DISTINCT DepremID FROM HasarKaydi ORDER BY DepremID;



-- 1. ADIM: Doğru veritabanına geçiş yapıyoruz (BURAYI KENDİ VERİTABANI ADINLA DEĞİŞTİR)
USE DepremDB; 
GO

-- 2. ADIM: Varsa eski ve ilişkisiz tabloyu sil
IF OBJECT_ID('AfetBildirimleri', 'U') IS NOT NULL 
  DROP TABLE AfetBildirimleri;
GO

-- 3. ADIM: İlişkili yeni tabloyu kur
CREATE TABLE AfetBildirimleri (
    BildirimID INT IDENTITY(1,1) PRIMARY KEY,
    KullaniciID INT NOT NULL,  
    Siddet NVARCHAR(100),
    BinaDurumu NVARCHAR(150),
    EkstraNot NVARCHAR(MAX),
    BildirimZamani DATETIME DEFAULT GETDATE(),
    
    CONSTRAINT FK_AfetBildirimleri_Kullanici 
    FOREIGN KEY (KullaniciID) REFERENCES Kullanici(KullaniciID) 
    ON DELETE CASCADE
);
GO

ALTER TABLE AfetBildirimleri ADD Enlem FLOAT NULL;
ALTER TABLE AfetBildirimleri ADD Boylam FLOAT NULL;




USE DepremDB;
GO

-- 1. YANLIŞ EŞLEŞEN TÜM HASAR KAYITLARINI SİL (Sıfırdan başlıyoruz)
TRUNCATE TABLE HasarKaydi;
GO

-- 2. GERÇEK DEPREM ID'LERİNİ TARİH VE BÜYÜKLÜKTEN OTOMATİK BUL
DECLARE @Maras1 INT = (SELECT TOP 1 DepremID FROM Deprem WHERE YEAR(TarihSaat) = 2023 AND MONTH(TarihSaat) = 2 AND BuyuklukMw >= 7.5 ORDER BY TarihSaat ASC);
DECLARE @Maras2 INT = (SELECT TOP 1 DepremID FROM Deprem WHERE YEAR(TarihSaat) = 2023 AND MONTH(TarihSaat) = 2 AND BuyuklukMw >= 7.5 ORDER BY TarihSaat DESC);
DECLARE @Golcuk INT = (SELECT TOP 1 DepremID FROM Deprem WHERE YEAR(TarihSaat) = 1999 AND MONTH(TarihSaat) = 8 AND BuyuklukMw >= 7.4);
DECLARE @Duzce  INT = (SELECT TOP 1 DepremID FROM Deprem WHERE YEAR(TarihSaat) = 1999 AND MONTH(TarihSaat) = 11 AND BuyuklukMw >= 7.0);
DECLARE @Van    INT = (SELECT TOP 1 DepremID FROM Deprem WHERE YEAR(TarihSaat) = 2011 AND MONTH(TarihSaat) = 10 AND BuyuklukMw >= 7.1);
DECLARE @Izmir  INT = (SELECT TOP 1 DepremID FROM Deprem WHERE YEAR(TarihSaat) = 2020 AND MONTH(TarihSaat) = 10 AND BuyuklukMw >= 6.8);

-- 3. HASARLARI GERÇEK ID'LERLE TABLOYA YAZ

-- 2023 Kahramanmaraş 1 (7.7)
IF @Maras1 IS NOT NULL BEGIN
    INSERT INTO HasarKaydi (DepremID, YerlesimID, OlumSayisi, YaraliSayisi, YikilanBina) VALUES
    (@Maras1, 23, 21000, 45000, 85000),
    (@Maras1, 24, 10000, 22000, 45000),
    (@Maras1, 25, 5800, 13000, 28000),
    (@Maras1, 26, 4200, 9500, 19000),
    (@Maras1, 22, 1800, 4200, 8500);
END

-- 2023 Kahramanmaraş 2 (7.6)
IF @Maras2 IS NOT NULL BEGIN
    INSERT INTO HasarKaydi (DepremID, YerlesimID, OlumSayisi, YaraliSayisi, YikilanBina) VALUES
    (@Maras2, 23, 8500, 18000, 35000),
    (@Maras2, 24, 4200, 9000, 18000),
    (@Maras2, 25, 2800, 6500, 12000);
END

-- 1999 Gölcük (7.6)
IF @Golcuk IS NOT NULL BEGIN
    INSERT INTO HasarKaydi (DepremID, YerlesimID, OlumSayisi, YaraliSayisi, YikilanBina) VALUES
    (@Golcuk, 12, 17480, 43953, 97000),
    (@Golcuk, 11, 3200, 7800, 15000),
    (@Golcuk, 13, 4500, 11200, 23000);
END

-- 1999 Düzce (7.2)
IF @Duzce IS NOT NULL BEGIN
    INSERT INTO HasarKaydi (DepremID, YerlesimID, OlumSayisi, YaraliSayisi, YikilanBina) VALUES
    (@Duzce, 14, 845, 4948, 5000),
    (@Duzce, 15, 200, 900, 1200);
END

-- 2011 Van (7.2)
IF @Van IS NOT NULL BEGIN
    INSERT INTO HasarKaydi (DepremID, YerlesimID, OlumSayisi, YaraliSayisi, YikilanBina) VALUES
    (@Van, 18, 18500, 32000, 45000),
    (@Van, 19, 1500, 3500, 5000);
END

-- 2020 İzmir (6.9)
IF @Izmir IS NOT NULL BEGIN
    INSERT INTO HasarKaydi (DepremID, YerlesimID, OlumSayisi, YaraliSayisi, YikilanBina) VALUES
    (@Izmir, 4, 14480, 21035, 38622),
    (@Izmir, 5, 22, 280, 650),
    (@Izmir, 6, 38, 420, 1100);
END
GO




USE DepremDB;
GO

-- 1. ŞEHRİ EŞLEŞMEYEN (Örn: Denizde olan) BÜYÜK DEPREMLERİ ZORLA EKLE
INSERT INTO HasarKaydi (DepremID, YerlesimID, OlumSayisi, YaraliSayisi, YikilanBina)
SELECT 
    d.DepremID,
    -- Eğer şehir eşleşmezse (deniz depremi vb.) çökmeyi önlemek için varsayılan bir YerlesimID ata
    ISNULL(y.YerlesimID, (SELECT TOP 1 YerlesimID FROM YerlesimBirimi)), 
    
    -- Ölüm Sayısı
    CAST(ROUND(POWER((d.BuyuklukMw - 4.9), 3.5) * (30.0 / NULLIF(d.Derinlik, 0)) * (ISNULL(y.Nufus, 50000) / 100000.0), 0) AS INT),

    -- Yaralı Sayısı
    CAST(ROUND(POWER((d.BuyuklukMw - 4.9), 3.5) * (135.0 / NULLIF(d.Derinlik, 0)) * (ISNULL(y.Nufus, 50000) / 100000.0), 0) AS INT),

    -- Yıkılan Bina
    CAST(ROUND(POWER((d.BuyuklukMw - 4.9), 2.8) * (100.0 / NULLIF(d.Derinlik, 0)) * (ISNULL(y.Nufus, 50000) / 100000.0), 0) AS INT)

FROM Deprem d
LEFT JOIN YerlesimBirimi y ON d.Sehir = y.Il -- LEFT JOIN kullandık ki eşleşmeyenler silinmesin!
WHERE d.BuyuklukMw >= 5.0 
  AND d.DepremID NOT IN (SELECT DepremID FROM HasarKaydi);
GO


USE DepremDB;
GO

-- 1. 1970 yılındaki 7.2'lik depremi Kütahya'ya taşı (Eğer hala İstanbul görünüyorsa)
UPDATE Deprem 
SET Sehir = 'Kutahya' 
WHERE YEAR(TarihSaat) = 1970 AND BuyuklukMw >= 7.0 AND Sehir = 'Istanbul';
GO

-- 2. İSTANBUL'DAKİ TÜM SAHTE HASAR KAYITLARINI SIFIRLA (Temiz sayfa)
UPDATE HasarKaydi
SET 
    OlumSayisi = 0,
    YikilanBina = 0,
    -- Gerçekçilik katmak için çok nadiren 1-2 panik yaralısı bırakıyoruz
    YaraliSayisi = CASE WHEN ABS(CHECKSUM(NEWID())) % 10 > 8 THEN 1 ELSE 0 END
FROM HasarKaydi h
JOIN YerlesimBirimi y ON h.YerlesimID = y.YerlesimID
WHERE y.Il = 'Istanbul';
GO

-- 3. SADECE GERÇEK İSTANBUL HASARLARINI GERİ YÜKLE

-- A) 1999 Gölcük (Avcılar Yıkımı)
DECLARE @Golcuk INT = (SELECT TOP 1 DepremID FROM Deprem WHERE YEAR(TarihSaat)=1999 AND MONTH(TarihSaat)=8 AND BuyuklukMw>=7.4);
IF @Golcuk IS NOT NULL BEGIN
    UPDATE HasarKaydi 
    SET OlumSayisi = 981, YaraliSayisi = 3200, YikilanBina = 3000
    WHERE DepremID = @Golcuk 
      AND YerlesimID = (SELECT TOP 1 YerlesimID FROM YerlesimBirimi WHERE Il = 'Istanbul');
END

-- B) 2019 Silivri (Mw 5.8)
DECLARE @Silivri INT = (SELECT TOP 1 DepremID FROM Deprem WHERE Sehir='Istanbul' AND YEAR(TarihSaat)=2019 AND MONTH(TarihSaat)=9 AND BuyuklukMw>=5.7);
IF @Silivri IS NOT NULL BEGIN
    UPDATE HasarKaydi 
    SET OlumSayisi = 0, YaraliSayisi = 38, YikilanBina = 145
    WHERE DepremID = @Silivri 
      AND YerlesimID = (SELECT TOP 1 YerlesimID FROM YerlesimBirimi WHERE Il = 'Istanbul');
END
GO



CREATE TABLE AfetBildirimleri (
    BildirimID INT IDENTITY(1,1) PRIMARY KEY,
    GonderenGmail NVARCHAR(100),
    Siddet NVARCHAR(100),
    BinaDurumu NVARCHAR(150),
    EkstraNot NVARCHAR(MAX),
    BildirimZamani DATETIME DEFAULT GETDATE()
);


