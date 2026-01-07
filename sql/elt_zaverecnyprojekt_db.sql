USE WAREHOUSE LEMUR_WH;
USE DATABASE LEMUR_DB;

--  Vytvorenie schémy pre staging tabuľky
CREATE OR REPLACE SCHEMA ZAVARECNY_PROJEKT;

-- Vytvorenie tabuľky InvoiceItems (staging)
CREATE OR REPLACE TABLE invoice_items_staging (
    InvoiceID INT AUTOINCREMENT PRIMARY KEY,
    InvoiceNumber VARCHAR(25),
    PurchaseOrder VARCHAR(25),
    InvoiceAmount FLOAT,
    InvoiceDate DATE
);

-- Vytvorenie tabuľky Catalog (staging)
CREATE OR REPLACE TABLE catalog_staging(
    CatalogID INT AUTOINCREMENT PRIMARY KEY,
    ASIN VARCHAR(45),
    Product VARCHAR(250),
    Brand VARCHAR(100),
    CategoryPath VARCHAR(250),
    Company VARCHAR(100),
    CountryCode VARCHAR(100),
    ReleaseDate DATE,
    SoldOnUID VARCHAR(100)
);

-- Vytvorenie tabuľky ReportInfo (staging)
CREATE OR REPLACE TABLE report_info_staging(
    ReportID INT AUTOINCREMENT PRIMARY KEY,
    FileID INT,
    SCRs VARCHAR(45)
);

-- Vytvorenie tabuľky ShortageClaims (staging)
CREATE OR REPLACE TABLE shortage_claims_staging(
    ShortageClaimsID INT PRIMARY KEY,
    InvoiceID INT,
    CatalogID INT,
    ReportID INT,
    ShortageQty INT,
    ShortageAmount FLOAT,
    ShortageType VARCHAR(100),
    ShortageDate DATE,
    FOREIGN KEY (InvoiceID) REFERENCES invoice_items_staging(InvoiceID),
    FOREIGN KEY (CatalogID) REFERENCES catalog_staging(CatalogID),
    FOREIGN KEY (ReportID) REFERENCES report_info_staging(ReportID)
);

-- Načítanie údajov o fákturach do staging tabuľky invoice_items_staging
INSERT INTO invoice_items_staging (
    InvoiceNumber,
    PurchaseOrder,
    InvoiceAmount,
    InvoiceDate
) SELECT
    "InvoiceNumber",
    "PurchaseOrder",
    "InvoiceAmount",
    "InvoiceDate"
FROM AMAZON_VENDOR_ORDER_TO_CASH__SAMPLE.PUBLIC."InvoiceItems";

-- Načítanie údajov o produktoch do staging tabuľky catalog_staging
INSERT INTO catalog_staging (
    ASIN,
    Product,
    Brand,
    CategoryPath,
    Company,
    CountryCode,
    ReleaseDate,
    SoldOnUID
)SELECT 
    "ASIN",
    "Product",
    "Brand",
    "CategoryPath",
    "Company",
    "CountryCode",
    "ReleaseDate",
    "SoldOnUID"
FROM AMAZON_VENDOR_ORDER_TO_CASH__SAMPLE.PUBLIC."Catalog"
WHERE "ReleaseDate" IS NOT NULL;

-- Načítanie informacíí o reportoch do staging tabuľky report_info_staging
INSERT INTO report_info_staging (
    FileID,
    SCRs
) SELECT 
    "FileID",
    "SCRs"
FROM AMAZON_VENDOR_ORDER_TO_CASH__SAMPLE.PUBLIC."ShortageClaims";

-- Transformácia a načítanie údajov o reklamáciách do staging tabuľky shortage_claims_staging
INSERT INTO shortage_claims_staging(
    ShortageClaimsID,
    InvoiceID,
    CatalogID,
    ReportID,
    ShortageQty,
    ShortageAmount,
    ShortageType,
    ShortageDate
)SELECT
    ROW_NUMBER() OVER (ORDER BY sc."InvoiceNumber"), 
    i.InvoiceID,
    c.CatalogID,
    r.reportID,
    sc."ShortageQty",
    sc."ShortageAmount",
    sc."ShortageType",
    sc."ReportDate"
FROM AMAZON_VENDOR_ORDER_TO_CASH__SAMPLE.PUBLIC."ShortageClaims" sc

-- Pripojenie k staging tabuľke faktúr, výber len jednej verzie na základe dátumu  
JOIN (SELECT *, ROW_NUMBER() OVER (PARTITION BY InvoiceNumber ORDER BY InvoiceDate) as rn FROM invoice_items_staging) i ON sc."InvoiceNumber" = i.invoicenumber and i.rn = 1

-- Pripojenie k staging tabuľke produktov, výber len jednej verzie na základe dátumu
JOIN (SELECT *, ROW_NUMBER() OVER (PARTITION BY asin ORDER BY RELEASEDATE) as rn FROM catalog_staging) c ON sc."ASIN" = c.asin and c.rn = 1

-- Pripojenie k staging tabuľke reportov, výber len jednej kombinácie FileID + SCRs
JOIN (SELECT *, ROW_NUMBER() OVER (PARTITION BY FileID,SCRS ORDER BY FILEID) as rn FROM report_info_staging) r ON sc."FileID" = r.fileid AND sc."SCRs" = r.SCRs and r.rn = 1;

--- ELT - (T)ransform
-- dim_catalog
CREATE OR REPLACE TABLE dim_catalog AS (
    SELECT 
        CatalogID,    
        ASIN,
        product,
        brand, 
        categorypath, 
        company,
        countrycode, 
        releasedate, 
        soldonuid 
    FROM catalog_staging 
    WHERE ReleaseDate IS NOT NULL
);

-- dim_invoice
CREATE OR REPLACE TABLE dim_invoice AS (
 SELECT
    InvoiceID,
    InvoiceNumber,
    PurchaseOrder, 
    InvoiceAmount, 
    InvoiceDate 
 FROM invoice_items_staging its
);

-- dim_date
-- Obsahuje kálendarne údaje odvodené z dátumu reklamácie (ShortageDate) 
CREATE OR REPLACE TABLE dim_date AS (
    SELECT DISTINCT
        ROW_NUMBER() OVER (ORDER BY date) as DateID,
        date as date,
        DATE_PART(day, date) as day,
        DATE_PART(dow, date) + 1 as dayOfWeek,
        DATE_PART(month, date) as month,
        DATE_PART(year, date) as year,
        DATE_PART(week,date) as week,
        DATE_PART(quarter,date) as quarter
        FROM (
            SELECT DISTINCT ShortageDate AS date
            FROM shortage_claims_staging 
            WHERE ShortageDate IS NOT NULL
        )
);

-- dim_report
CREATE OR REPLACE TABLE dim_report AS (
    SELECT DISTINCT
        ReportId,
        FileID,
        SCRs
    FROM report_info_staging
);

-- fact_shortage_claims
CREATE OR REPLACE TABLE fact_shortage_claims AS (
    SELECT
        s.ShortageClaimsID,  -- Unikátne ID reklamácie
        i.InvoiceID,         -- Pripojenie s dimenziou faktúr
        c.CatalogID,         -- Pripojenie s dimenziou produktov
        d.dateid,            -- Pripojenie s dimenziou dátumov
        r.ReportID,          -- Pripojenie s dimenziou reportov
        s.shortageqty,       -- Množstvo nedodaného tovaru podľa danej reklamácie
        s.shortageamount,    -- Finančná hodnota nedodávky v peňažnom vyjadrení
        s.shortagetype,      -- Typ reklamácie
        SUM(s.SHORTAGEAMOUNT) OVER (PARTITION BY s.InvoiceID ORDER BY d.dateid, s.shortageclaimsid) as CumulativeShortageAmount
    FROM shortage_claims_staging s

    JOIN dim_invoice i ON i.InvoiceID = s.InvoiceID  -- Pripojenie na základe faktúr
    JOIN dim_catalog c ON s.catalogid = c.catalogid  -- Pripojenie na základe produktov
    JOIN dim_report r ON r.reportid = s.reportid     -- Pripojenie na základe reportov
    JOIN dim_date d ON s.ShortageDate = d.date       -- Pripojenie na základe dátumov
);

-- DROP stagging tables
DROP TABLE IF EXISTS invoice_items_staging;
DROP TABLE IF EXISTS catalog_staging;
DROP TABLE IF EXISTS report_info_staging;
DROP TABLE IF EXISTS shortage_claims_staging;
