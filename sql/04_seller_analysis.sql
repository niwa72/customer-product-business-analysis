-- ============================================================
-- PROJECT 2: CUSTOMER & PRODUCT BUSINESS ANALYSIS
-- 04. SELLER ANALYSIS
--
-- Business question:
--   Are high-value customer outcomes concentrated among
--   particular seller types or seller characteristics, and
--   where might seller support have the greatest business value?
--
-- Depends on: customer_segments (02_customer_analysis.sql)
-- ============================================================


-- ------------------------------------------------------------
-- 1. Sample-size validation
--    Confirm every seller has enough volume before comparing
--    seller-level metrics (avoid drawing conclusions from
--    sellers with very small order/customer counts)
-- ------------------------------------------------------------

SELECT
    MIN(item_count)     AS min_items_per_seller,
    MIN(customer_count)  AS min_customers_per_seller
FROM (
    SELECT
        p.seller_id,
        COUNT(*)                        AS item_count,
        COUNT(DISTINCT o.customer_id)   AS customer_count
    FROM order_items oi
    JOIN orders o    ON oi.order_id = o.order_id
    JOIN products p  ON oi.product_id = p.product_id
    GROUP BY p.seller_id
) seller_volume;

-- Expected: min 188 items, min 187 customers -> no extremely
-- small-volume sellers that would make descriptive seller
-- comparisons obviously unstable. (This is not a formal
-- statistical power check -- no significance test is run in
-- this analysis -- just a floor check before comparing means.)


-- ------------------------------------------------------------
-- 2. CRITICAL CONFOUND CHECK
--    Is catalog size (product count) deterministically tied to
--    the fbs_standard (logistics) flag? If so, raw seller
--    revenue CANNOT be used to compare FBS vs Standard fairly.
-- ------------------------------------------------------------

SELECT
    s.fbs_standard,
    COUNT(DISTINCT s.seller_id)     AS sellers,
    MIN(pc.n_products)               AS min_products,
    MAX(pc.n_products)               AS max_products,
    AVG(pc.n_products)               AS avg_products
FROM sellers s
JOIN (
    SELECT seller_id, COUNT(*) AS n_products
    FROM products
    GROUP BY seller_id
) pc ON s.seller_id = pc.seller_id
GROUP BY s.fbs_standard;

-- Result: FBS sellers = exactly 16 products each (min=max=16),
-- Standard sellers = exactly 28 products each (min=max=28).
-- This is a DETERMINISTIC relationship, not a tendency.
--
-- CONSEQUENCE: any FBS vs Standard revenue comparison must be
-- normalized by product count (revenue per product), never
-- compared as raw seller totals.


-- ------------------------------------------------------------
-- 3. Seller-level performance: raw vs normalized
--    Reported with BOTH mean and median because seller
--    performance is right-skewed.
-- ------------------------------------------------------------

-- NOTE ON revenue_per_customer BELOW: this is realized revenue
-- divided by the count of DISTINCT customers who bought from
-- THIS seller. A single customer may buy from multiple sellers,
-- so this is NOT customer lifetime value -- it is realized
-- revenue generated per unique customer associated with that
-- specific seller (a seller-attributed metric).

DROP TABLE IF EXISTS seller_metrics;

CREATE TABLE seller_metrics AS
SELECT
    s.seller_id,
    s.seller_type,
    s.fbs_standard,
    pc.n_products,
    SUM(oi.line_total)                                  AS revenue,
    COUNT(DISTINCT o.customer_id)                        AS customers,
    SUM(oi.line_total) / pc.n_products                   AS revenue_per_product,
    SUM(oi.line_total) / COUNT(DISTINCT o.customer_id)    AS revenue_per_customer
FROM order_items oi
JOIN orders o    ON oi.order_id = o.order_id
JOIN products p  ON oi.product_id = p.product_id
JOIN sellers s   ON p.seller_id = s.seller_id
JOIN (
    SELECT seller_id, COUNT(*) AS n_products FROM products GROUP BY seller_id
) pc ON s.seller_id = pc.seller_id
WHERE oi.item_status = 'Completed'
GROUP BY s.seller_id, s.seller_type, s.fbs_standard, pc.n_products;

-- 3a. seller_type: Company vs Individual
SELECT
    seller_type,
    ROUND(AVG(revenue_per_product), 0)    AS mean_revenue_per_product,
    ROUND(AVG(revenue_per_customer), 0)   AS mean_revenue_per_customer
FROM seller_metrics
GROUP BY seller_type;

-- Expected: Company ~฿651,788/product, Individual ~฿553,222/product
-- (~18% gap -- NOT explained by catalog size; Company/Individual
-- average product counts are nearly equal, ~24-25 each)

-- 3b. fbs_standard: FBS vs Standard (normalized)
SELECT
    fbs_standard,
    ROUND(AVG(revenue), 0)                 AS mean_raw_revenue,
    ROUND(AVG(revenue_per_product), 0)     AS mean_revenue_per_product
FROM seller_metrics
GROUP BY fbs_standard;

-- Expected: raw revenue looks very different (FBS ~10.1M vs
-- Standard ~17.5M), but revenue_per_product is nearly IDENTICAL
-- (~฿634K vs ~฿624K) -- confirming the raw gap is a catalog-size
-- artifact, not a logistics-performance difference.


-- ------------------------------------------------------------
-- 4. Operational outcomes: completed vs cancelled/refunded rate
--    by seller characteristic
-- ------------------------------------------------------------

SELECT
    s.seller_type,
    oi.item_status,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY s.seller_type), 1)    AS pct
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN sellers s  ON p.seller_id = s.seller_id
GROUP BY s.seller_type, oi.item_status
ORDER BY s.seller_type, oi.item_status;

-- Expected: completed/cancelled/refunded rates nearly identical
-- across seller_type (~75/20/5 split each) -- no operational
-- quality difference found by seller_type.

-- Same check for fbs_standard (logistics type) -- reported
-- separately per the "analyze seller_type and fbs_standard
-- independently" requirement, not combined into one variable.
SELECT
    s.fbs_standard,
    oi.item_status,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY s.fbs_standard), 1)   AS pct
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN sellers s  ON p.seller_id = s.seller_id
GROUP BY s.fbs_standard, oi.item_status
ORDER BY s.fbs_standard, oi.item_status;

-- Expected: FBS cancel rate ~20.2% vs Standard ~19.8% -- also
-- flat, no meaningful operational difference by logistics type.


-- ------------------------------------------------------------
-- 5. Customer segment composition by seller characteristic
--    (which segments' customers buy from which seller types)
-- ------------------------------------------------------------

SELECT
    s.seller_type,
    cs.customer_segment,
    ROUND(COUNT(DISTINCT o.customer_id) * 100.0 /
        SUM(COUNT(DISTINCT o.customer_id)) OVER (PARTITION BY s.seller_type), 1) AS pct_of_sellertype_customers
FROM order_items oi
JOIN orders o              ON oi.order_id = o.order_id
JOIN products p            ON oi.product_id = p.product_id
JOIN sellers s              ON p.seller_id = s.seller_id
JOIN customer_segments cs   ON o.customer_id = cs.customer_id
WHERE oi.item_status = 'Completed'
GROUP BY s.seller_type, cs.customer_segment
ORDER BY s.seller_type, cs.customer_segment;

-- Expected: Individual sellers show a higher share of
-- B1 (High-frequency, engaged) customers than Company sellers
-- (36.8% vs 29.4%) -- despite Company's higher revenue efficiency
-- above. Seller type is not simply "better/worse."
-- ============================================================
