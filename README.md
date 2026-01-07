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
## **3.2 Transform**

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
### **3.3 Transfor**

V rámci transformačnej fázy boli zo staging tabuliek vytvorené tabuľky dimenzií a faktová tabuľka, ktoré spolu tvoria viacrozmerný dátový model typu hviezda (Star Schema). Počas transformácie boli dáta vyčistené, odfiltrované a upravené do štruktúry vhodnej pre analytické dotazy.

Dimenzná tabuľka `dim_catalog` bola vytvorená na základe tabuľky `catalog_staging` a obsahuje informácie o produktoch, vrátane ASIN, názvu produktu, značky, kategórie, spoločnosti, krajiny pôvodu, dátumu vydania a identifikátora predajcu. V rámci čistenia dát boli odfiltrované záznamy, ktoré neobsahovali hodnotu v stĺpci `ReleaseDate`, keďže dátum vydania je povinným atribútom pre ďalšiu analýzu.

Dimenzná tabuľka `dim_invoice` bola vytvorená z tabuľky `invoice_items_staging` a zahŕňa údaje o faktúrach, ako je číslo faktúry, číslo objednávky, suma faktúry a dátum vystavenia. Táto tabuľka sa používa na analýzu finančných aspektov nedostatkov tovaru.

Dimenzná tabuľka `dim_date` bola vytvorená na základe jedinečných hodnôt dátumu nedostatku (`ShortageDate`) z tabuľky `shortage_claims_staging`. Obsahuje kalendárne atribúty, vrátane dňa, dňa v týždni, mesiaca, roka, týždňa a štvrťroka. Táto tabuľka umožňuje časovú analýzu a sledovanie vývoja nedostatkov v čase. Záznamy s chýbajúcou hodnotou dátumu boli z procesu spracovania vylúčené.

Dimenzná tabuľka `dim_report` obsahuje informácie o reportoch a zdrojových súboroch, vrátane identifikátorov reportov (`ReportID`), súborov (`FileID`) a súvisiacich ukazovateľov (`SCRs`). Tieto údaje sa používajú na prepojenie nedostatkov s konkrétnymi reportovacími zdrojmi.

Faktová tabuľka `fact_shortage_claims` bola vytvorená na základe tabuľky `shortage_claims_staging` a prepája údaje so všetkými dimenznými tabuľkami. Obsahuje jedinečný identifikátor reklamácie, odkazy na dimenzie produktov, faktúr, dátumov a reportov, ako aj kľúčové metriky, ako sú množstvo nedodaného tovaru, hodnota nedostatku a typ reklamácie. Okrem toho bola pomocou okennej funkcie vypočítaná kumulatívna suma nedostatkov pre každú faktúru, čo umožňuje analyzovať celkový finančný dopad nedostatkov v čase.

Týmto spôsobom transformačná fáza zabezpečila prípravu konzistentnej a vyčistenej dátovej štruktúry optimalizovanej na analytické spracovanie a tvorbu reportov v rámci modelu Star Schema.

V rámci študentského projektu bolo rozhodnuté používať prevažne SCD typu 0, keďže analýza je zameraná na aktuálny stav referenčných údajov a neexistuje požiadavka na uchovávanie historických zmien.

Po úspešnom vytvorení dimenzií a faktovej tabuľky boli dáta nahraté do finálnej štruktúry. Na záver boli staging tabuľky odstránené, aby sa optimalizovalo využitie úložiska:
```sql
DROP TABLE IF EXISTS invoice_items_staging;
DROP TABLE IF EXISTS catalog_staging;
DROP TABLE IF EXISTS report_info_staging;
DROP TABLE IF EXISTS shortage_claims_staging;
```
