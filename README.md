# **ELT proces datasetu Amazon Vendor Order to Cash - Sample**

Tento dataset sme si vybrali, pretože sa nám zdal zaujímavý a dobre zodpovedal zadaniu. Tento repozitár predstavuje ukážkovú implementáciu ELT procesu v Snowflake a vytvorenie dátového skladu so schémou Star Schema. Projekt pracuje s [**Amazon Vendor Order to Cash - Sample**](https://app.snowflake.com/marketplace/listing/GZTYZTJ3E1/merchant-ai-incorporated-amazon-vendor-order-to-cash-sample?search=Amazon+vendor) datasetom. Cieľom projektu je vytvoriť funkčnú databázu na analýzu a spracovanie reklamácií týkajúcich sa nedostatku tovaru v dodávkach pre marketplace.

Cieľom je vytvorenie dokumentácie, realizácia a vizualizácia záverečného projektu.

---
## **1. Úvod a popis zdrojových dát**
V tomto príklade analyzujeme dáta o nedostatkoch tovaru v dodávkach a súvisiacich faktúrach. Cieľom je porozumieť:
- typom a príčinám nedostatkov tovaru
- objemu a finančnému dopadu nedostatkov
- vzťahu medzi faktúrami, produktmi a hláseniami o nedostatkoch
- trendom v čase a najčastejšie sa opakujúcim problémom v dodávkach

Zo všetkých dostupných tabuliek sme vybrali iba tie, ktoré priamo súvisia s témou našej Star Schema a sú potrebné na analýzu zvoleného biznis procesu:
- `Catalog` - informácie o produktoch
- `InvoiceItems` - údaje o faktúrach
- `ReportInfo` - informácie o reportoch
- `ShortageClaims` - zaznamenáva reklamácie týkajúce sa nedodaného alebo poškodeného tovaru.


### **ERD diagram**
Surové dáta sú usporiadané v relačnom modeli, ktorý je znázornený na **entitno-relačnom diagrame (ERD)**:

<p align="center">
  <img src="https://github.com/FlaFerOk/databazove-technologie-project/blob/main/img/erd_schema.png" alt="ERD Schema">
  <br>
  <em>Obrázok 1 ERD Schema</em>
</p>

---
## **2 Dimenzionálny model**

V tomto projekte bola navrhnutá schéma hviezdy (star schema) podľa Kimballovej metodológie. Model obsahuje jednu tabuľku faktov — fact_shortage_claims, ktorej primárnym kľúčom je stĺpec ShortageClaimsID. Táto tabuľka je prepojená s nasledujúcimi dimenziami:
- `dim_catalog`: obsahuje podrobné informácie o produktoch, ako sú identifikátor produktu (ASIN), názov produktu, značka, kategória, spoločnosť, krajina pôvodu a dátum uvedenia na trh.
- `dim_invoice`: obsahuje informácie o faktúrach vrátane čísla faktúry, objednávky, celkovej sumy a dátumu vystavenia.
- `dim_report`: zahŕňa údaje o reportoch a zdrojových súboroch, z ktorých boli hlásenia o nedostatkoch vytvorené.
- `dim_date`: obsahuje kalendárne informácie, ako sú deň, deň v týždni, mesiac, rok, týždeň a štvrťrok.

Tabuľka faktov fact_shortage_claims obsahuje merateľné ukazovatele súvisiace s nedostatkami tovaru, ako je množstvo nedostatkov a ich finančný dopad, a zároveň slúži ako centrálny bod pre analytické dotazy.

Štruktúra hviezdicového modelu je znázornená na diagrame nižšie, ktorý zobrazuje vzťahy medzi tabuľkou faktov a jednotlivými dimenziami, čo uľahčuje pochopenie a implementáciu modelu.

<p align="center">
  <img src="https://github.com/FlaFerOk/databazove-technologie-project/blob/main/img/star_schema.png" alt="Star Schema">
  <br>
  <em>Obrázok 2 Star Schema</em>
</p>

---
## **3.1 Extract**

Dáta boli získané z verejného datasetu [**Amazon Vendor Order to Cash - Sample**](https://app.snowflake.com/marketplace/listing/GZTYZTJ3E1/merchant-ai-incorporated-amazon-vendor-order-to-cash-sample?search=Amazon+vendor), ktorý je dostupný v Snowflake Marketplace. Dataset je poskytovaný vo forme hotovej databázy a schémy obsahujúcej tabuľky súvisiace s objednávkami, faktúrami, reklamáciami nedostatkov. 

Zdrojové tabuľky boli importované z databázy `AMAZON_VENDOR_ORDER_TO_CASH__SAMPLE` a zo schémy `PUBLIC`.

Vytvorenie staging tabuliek:
- InvoiceItems:
```sql
CREATE OR REPLACE TABLE invoice_items_staging (
    InvoiceID INT AUTOINCREMENT PRIMARY KEY,
    InvoiceNumber VARCHAR(25),
    PurchaseOrder VARCHAR(25),
    InvoiceAmount FLOAT,
    InvoiceDate DATE
);
```
- Catalog:
```sql
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
```
- ReportInfo:
```sql
CREATE OR REPLACE TABLE report_info_staging(
    ReportID INT AUTOINCREMENT PRIMARY KEY,
    FileID INT,
    SCRs VARCHAR(45)
);
```
- ShortageClaims:
```sql
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
```
---
## **3.2 Load**

Údaje o produktoch (catalog), faktúrach (invoices), reklamáciách na nedostatky tovaru (shortage claims) a reportoch boli načítané z datasetu [**Amazon Vendor Order to Cash - Sample**](https://app.snowflake.com/marketplace/listing/GZTYZTJ3E1/merchant-ai-incorporated-amazon-vendor-order-to-cash-sample?search=Amazon+vendor) do staging tabuliek v Snowflake pomocou príkazu `INSERT INTO`. Nižšie sú uvedené príkazy použité na načítanie dát do jednotlivých staging tabuliek:
- InvoiceItems:
```sql
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
```

- Catalog:
```sql
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
```
Z dátového súboru boli odfiltrované záznamy bez informácie v stĺpci `ReleaseDate` pomocou podmienky `WHERE "ReleaseDate" IS NOT NULL`.

- ReportInfo:
```sql
INSERT INTO report_info_staging (
    FileID,
    SCRs
) SELECT 
    "FileID",
    "SCRs"
FROM AMAZON_VENDOR_ORDER_TO_CASH__SAMPLE.PUBLIC."ShortageClaims";
```

- ShortageClaims:
```sql
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
```
Pri načítaní dát sa používajú spojenia so staging tabuľkami faktúr, katalógu a reportov. Na zabránenie duplicitám sa využíva okenná funkcia `ROW_NUMBER()`, ktorá umožňuje vybrať iba jednu relevantnú verziu záznamu pre každú entitu (InvoiceNumber, ASIN, FileID + SCRs). Výber je realizovaný pomocou podmienky `rn = 1`.

---
## **3.3 Transform**

V rámci transformačnej fázy boli zo staging tabuliek vytvorené tabuľky dimenzií a faktová tabuľka, ktoré spolu tvoria viacrozmerný dátový model typu hviezda (Star Schema). Počas transformácie boli dáta vyčistené, odfiltrované a upravené do štruktúry vhodnej pre analytické dotazy.

---
Dimenzná tabuľka `dim_catalog` bola vytvorená na základe tabuľky `catalog_staging` a obsahuje informácie o produktoch, vrátane ASIN, názvu produktu, značky, kategórie, spoločnosti, krajiny pôvodu, dátumu vydania a identifikátora predajcu. V rámci čistenia dát boli odfiltrované záznamy, ktoré neobsahovali hodnotu v stĺpci `ReleaseDate`, keďže dátum vydania je povinným atribútom pre ďalšiu analýzu.
```sql
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
```
---
Dimenzná tabuľka `dim_invoice` bola vytvorená z tabuľky `invoice_items_staging` a zahŕňa údaje o faktúrach, ako je číslo faktúry, číslo objednávky, suma faktúry a dátum vystavenia. Táto tabuľka sa používa na analýzu finančných aspektov nedostatkov tovaru.
```sql
CREATE OR REPLACE TABLE dim_invoice AS (
 SELECT
    InvoiceID,
    InvoiceNumber,
    PurchaseOrder, 
    InvoiceAmount, 
    InvoiceDate 
 FROM invoice_items_staging its
);
```
---
Dimenzná tabuľka `dim_date` bola vytvorená na základe jedinečných hodnôt dátumu nedostatku (`ShortageDate`) z tabuľky `shortage_claims_staging`. Obsahuje kalendárne atribúty, vrátane dňa, dňa v týždni, mesiaca, roka, týždňa a štvrťroka. Táto tabuľka umožňuje časovú analýzu a sledovanie vývoja nedostatkov v čase. Záznamy s chýbajúcou hodnotou dátumu boli z procesu spracovania vylúčené.
```sql
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
```
---
Dimenzná tabuľka `dim_report` obsahuje informácie o reportoch a zdrojových súboroch, vrátane identifikátorov reportov (`ReportID`), súborov (`FileID`) a súvisiacich ukazovateľov (`SCRs`). Tieto údaje sa používajú na prepojenie nedostatkov s konkrétnymi reportovacími zdrojmi.
```sql
CREATE OR REPLACE TABLE dim_report AS (
    SELECT DISTINCT
        ReportId,
        FileID,
        SCRs
    FROM report_info_staging
);
```
---
Faktová tabuľka `fact_shortage_claims` bola vytvorená na základe tabuľky `shortage_claims_staging` a prepája údaje so všetkými dimenznými tabuľkami. Obsahuje jedinečný identifikátor reklamácie, odkazy na dimenzie produktov, faktúr, dátumov a reportov, ako aj kľúčové metriky, ako sú množstvo nedodaného tovaru, hodnota nedostatku a typ reklamácie. Okrem toho bola pomocou okennej funkcie vypočítaná kumulatívna suma nedostatkov pre každú faktúru, čo umožňuje analyzovať celkový finančný dopad nedostatkov v čase.
```sql
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
```
---
Týmto spôsobom transformačná fáza zabezpečila prípravu konzistentnej a vyčistenej dátovej štruktúry optimalizovanej na analytické spracovanie a tvorbu reportov v rámci modelu Star Schema.

V rámci študentského projektu bolo rozhodnuté používať prevažne SCD typu 0, keďže analýza je zameraná na aktuálny stav referenčných údajov a neexistuje požiadavka na uchovávanie historických zmien.

ELT proces v Snowflake umožnil spracovanie dát z datasetu [**Amazon Vendor Order to Cash - Sample**](https://app.snowflake.com/marketplace/listing/GZTYZTJ3E1/merchant-ai-incorporated-amazon-vendor-order-to-cash-sample?search=Amazon+vendor) a ich transformáciu do schémy typu Star Schema. V rámci procesu boli dáta zo schémy `AMAZON_VENDOR_ORDER_TO_CASH__SAMPLE.PUBLIC` načítané do staging tabuliek, po čom nasledovalo čistenie a transformácia. Výsledkom je hviezdicový model s dimenziami `dim_catalog`, `dim_invoice`, `dim_date`, `dim_report` a faktovou tabuľkou `fact_shortage_claims`[.](https://youtu.be/dQw4w9WgXcQ?si=Z-d_HPhE5n8_8cmI) Vytvorený model umožňuje analyzovať nedostatky tovaru, ich finančný dopad a vývoj v čase a zároveň slúži ako základ pre tvorbu vizualizácií a reportov.

Po úspešnom vytvorení dimenzií a faktovej tabuľky boli dáta nahraté do finálnej štruktúry. Na záver boli staging tabuľky odstránené, aby sa optimalizovalo využitie úložiska:
```sql
DROP TABLE IF EXISTS invoice_items_staging;
DROP TABLE IF EXISTS catalog_staging;
DROP TABLE IF EXISTS report_info_staging;
DROP TABLE IF EXISTS shortage_claims_staging;
```

---
## **4 Vizualizácia dát**

Dashboard obsahuje 6 vizualizácií, ktoré poskytujú základný prehľad o kľúčových metrikách a trendoch súvisiacich s reklamáciami nedostatkov tovaru. Vizualizácie odpovedajú na dôležité otázky a pomáhajú lepšie pochopiť, ktoré produkty a značky sú najproblematickejšie, aký je finančný dopad reklamácií, ako sa reklamácie vyvíjajú v čase a ako sa líšia podľa krajín, faktúr a spoločností.

<p align="center">
  <img src="https://github.com/FlaFerOk/databazove-technologie-project/blob/main/img/vizualizacia.png" alt="Vizualizacia">
  <br>
  <em>Obrázok 3 Vizualizacia</em>
</p>

---
### **Graf 1: Produkty, ktoré boli najčastejšie predmetom reklamácií (top 10)**
Graf zobrazuje produkty, pri ktorých bol zaznamenaný najvyšší počet reklamácií. Pomáha identifikovať tovary, ktoré najčastejšie spôsobujú problémy pri dodávkach.

```sql
SELECT 
    c.Product as product_name,
    COUNT(f.shortageclaimsID) as total_claims
FROM fact_shortage_claims f
JOIN dim_catalog c ON f.CatalogID = c.CatalogID
GROUP BY c.Product
ORDER BY total_claims DESC
LIMIT 10;
```
---
### **Graf 2: Celková hodnota reklamácii podľa značky**
Vizualizácia zobrazuje celkovú finančnú hodnotu reklamácií pre jednotlivé značky. Umožňuje zistiť, ktoré značky majú najväčší finančný dopad z dôvodu nedostatkov.

```sql
SELECT 
    c.Brand,
    ROUND(SUM(f.ShortageAmount), 2) as total_shortage_amount
FROM fact_shortage_claims f
JOIN dim_catalog c ON f.CatalogID = c.CatalogID 
GROUP BY c.Brand
ORDER BY total_shortage_amount;
```
---
### **Graf 3: Počet reklamácií podľa rokov**
Graf ukazuje, ako sa počet reklamácií menil v priebehu rokov. Pomáha identifikovať trendy a vývoj problémov v čase.

```sql
SELECT 
    d.year,
    COUNT(f.ShortageClaimsID) as total_claims
FROM fact_shortage_claims f
JOIN dim_date d ON d.DateID = f.DateID
GROUP BY d.year
ORDER BY d.year;
```
---
### **Graf 4: Počet reklamácií podľa krajín**
Vizualizácia zobrazuje rozdelenie reklamácií podľa krajín pôvodu produktov. Umožňuje určiť, z ktorých krajín pochádza najviac problémových dodávok.

```sql
SELECT
 c.CountryCode,
 COUNT(f.ShortageClaimsID) AS total_claims
FROM fact_shortage_claims f
JOIN dim_catalog c ON c.CatalogID = f.CatalogID
GROUP BY c.CountryCode
ORDER BY total_claims DESC;
```
---
### **Graf 5: Priemerná hodnota reklamácie podľa faktúry**
Graf zobrazuje priemernú finančnú hodnotu reklamácií pre jednotlivé faktúry. Pomáha identifikovať faktúry s najvyšším finančným dopadom.

```sql
SELECT 
    i.InvoiceNumber,
    ROUND(AVG(f.ShortageAmount), 2) AS avg_shortage_amount,
    COUNT(f.ShortageClaimsID) AS total_claims
FROM fact_shortage_claims f
JOIN dim_invoice i ON i.InvoiceID = f.InvoiceID
GROUP BY i.InvoiceNumber
ORDER BY avg_shortage_amount
LIMIT 15;
```
---
### **Graf 6: Počet faktúr pre jednotlivé spoločnosti**
Vizualizácia zobrazuje počet faktúr pre jednotlivé spoločnosti. Umožňuje lepšie pochopiť, ktoré spoločnosti sa najčastejšie vyskytujú v dátach.

```sql
SELECT 
    c.Company as company_name,
    COUNT(i.InvoiceID) as total_invoices
FROM fact_shortage_claims f
JOIN dim_invoice i ON i.InvoiceID = f.InvoiceID
JOIN dim_catalog c ON c.CatalogID = f.CatalogID
GROUP BY c.Company
ORDER BY total_invoices;
```
---

