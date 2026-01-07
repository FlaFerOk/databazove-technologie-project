# ELT proces datasetu Amazon Vendor Order to Cash - Sample

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
- Vytvorenie tabuľky InvoiceItems:
```sql
-- Vytvorenie tabuľky InvoiceItems
CREATE OR REPLACE TABLE invoice_items_staging (
    InvoiceID INT AUTOINCREMENT PRIMARY KEY,
    InvoiceNumber VARCHAR(25),
    PurchaseOrder VARCHAR(25),
    InvoiceAmount FLOAT,
    InvoiceDate DATE
);
```
- Vytvorenie tabuľky Catalog:
```sql
-- Vytvorenie tabuľky Catalog
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
- Vytvorenie tabuľky ReportInfo:
```sql
-- Vytvorenie tabuľky ReportInfo
CREATE OR REPLACE TABLE report_info_staging(
    ReportID INT AUTOINCREMENT PRIMARY KEY,
    FileID INT,
    SCRs VARCHAR(45)
);
```
- Vytvorenie tabuľky ShortageClaims:
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


