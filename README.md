# **ELT proces datasetu Amazon Vendor Order to Cash - Sample

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

<p align="center">
  <img src="https://github.com/FlaFerOk/databazove-technologie-project/blob/main/img/star_schema.png" alt="Star Schema">
  <br>
  <em>Obrázok 2 Star Schema</em>
</p>




