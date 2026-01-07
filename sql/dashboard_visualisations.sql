-- Graf 1: Produkty, ktoré boli najčastejšie predmetom reklamácií (top 10)
SELECT 
    c.Product as product_name,
    COUNT(f.shortageclaimsID) as total_claims
FROM fact_shortage_claims f
JOIN dim_catalog c ON f.CatalogID = c.CatalogID
GROUP BY c.Product
ORDER BY total_claims DESC
LIMIT 10;

-- Graf 2: Celková hodnota reklamácii podľa značky
SELECT 
    c.Brand,
    ROUND(SUM(f.ShortageAmount), 2) as total_shortage_amount
FROM fact_shortage_claims f
JOIN dim_catalog c ON f.CatalogID = c.CatalogID 
GROUP BY c.Brand
ORDER BY total_shortage_amount;

-- Graf 3: Počet reklamácií podľa rokov
SELECT 
    d.year,
    COUNT(f.ShortageClaimsID) as total_claims
FROM fact_shortage_claims f
JOIN dim_date d ON d.DateID = f.DateID
GROUP BY d.year
ORDER BY d.year;

-- Graf 4: Počet reklamácií podľa krajín
SELECT
 c.CountryCode,
 COUNT(f.ShortageClaimsID) AS total_claims
FROM fact_shortage_claims f
JOIN dim_catalog c ON c.CatalogID = f.CatalogID
GROUP BY c.CountryCode
ORDER BY total_claims DESC;

-- Graf 5: Priemerná hodnota reklamácie podľa faktúry
SELECT 
    i.InvoiceNumber,
    ROUND(AVG(f.ShortageAmount), 2) AS avg_shortage_amount,
    COUNT(f.ShortageClaimsID) AS total_claims
FROM fact_shortage_claims f
JOIN dim_invoice i ON i.InvoiceID = f.InvoiceID
GROUP BY i.InvoiceNumber
ORDER BY avg_shortage_amount
LIMIT 15;

-- Graf 6: Počet faktúr pre jednotlivé spoločnosti
SELECT 
    c.Company as company_name,
    COUNT(i.InvoiceID) as total_invoices
FROM fact_shortage_claims f
JOIN dim_invoice i ON i.InvoiceID = f.InvoiceID
JOIN dim_catalog c ON c.CatalogID = f.CatalogID
GROUP BY c.Company
ORDER BY total_invoices;
