-- ============================================================
-- PROJECT 2: CUSTOMER & PRODUCT BUSINESS ANALYSIS
-- 02. CUSTOMER ANALYSIS
--
-- Business question:
--   Which customers create the most value, and does a standard
--   RFM score reliably identify them, or does it need adjustment
--   for this dataset?
--
-- Metric definitions (established in 01_data_validation.sql):
--   A "purchase" = an order containing at least one item with
--   item_status = 'Completed'.
--   Realized revenue = SUM(line_total) WHERE item_status = 'Completed'.
--
--   Recency   = days between the most recent completed order and
--               the last date observed in the dataset
--   Frequency = number of DISTINCT orders containing >=1 completed
--               item (NOT number of completed line items)
--   Monetary  = SUM(line_total) from completed items only
-- ============================================================


-- ------------------------------------------------------------
-- 1. Base population: customer-level R/F/M
--    Only customers with >=1 completed order are eligible.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS customer_rfm_base;

CREATE TABLE customer_rfm_base AS
SELECT
    c.customer_id,
    c.registration_date,
    COUNT(DISTINCT o.order_id)                              AS frequency,
    SUM(oi.line_total)                                       AS monetary,
    DATEDIFF(
        (SELECT MAX(order_date) FROM orders),
        MAX(o.order_date)
    )                                                         AS recency,
    CASE
        WHEN c.registration_date >= DATE_SUB(
            (SELECT MAX(order_date) FROM orders), INTERVAL 3 MONTH
        )
        THEN 'Recent (<3mo tenure)'
        ELSE 'Established'
    END                                                       AS tenure_group
FROM customers c
JOIN orders o          ON c.customer_id = o.customer_id
JOIN order_items oi    ON o.order_id = oi.order_id
                       AND oi.item_status = 'Completed'
GROUP BY c.customer_id, c.registration_date;

-- Expected: 55,822 eligible customers
SELECT COUNT(*) AS eligible_customers FROM customer_rfm_base;


-- ------------------------------------------------------------
-- 2. Frequency distribution check
--    Why: standard RFM quintiles assume a roughly continuous
--    distribution. Frequency here is a small set of discrete
--    integers (1-19), heavily clustered at low values, so
--    quintiles were tested and found unsuitable (uneven,
--    non-interpretable bin sizes) before deciding on
--    business-defined bands below.
-- ------------------------------------------------------------

SELECT
    frequency,
    COUNT(*) AS n_customers
FROM customer_rfm_base
GROUP BY frequency
ORDER BY frequency;


-- ------------------------------------------------------------
-- 3. Frequency bands (business-defined, validated against the
--    distribution above rather than assumed)
-- ------------------------------------------------------------

DROP TABLE IF EXISTS customer_segments;

CREATE TABLE customer_segments AS
SELECT
    *,
    CASE
        WHEN frequency = 1                THEN '1: One-time'
        WHEN frequency BETWEEN 2 AND 3     THEN '2-3: Occasional repeat'
        WHEN frequency BETWEEN 4 AND 5     THEN '4-5: Regular'
        WHEN frequency BETWEEN 6 AND 8     THEN '6-8: Frequent'
        ELSE                                    '9+: Power buyer'
    END AS freq_band,

    -- ------------------------------------------------------------
    -- Final customer segment (Approach B: business-rule).
    --
    -- An additive RFM score (Approach A) was tested first and
    -- rejected: it placed newly-registered customers and
    -- one-time high-spend customers into the same "high value"
    -- tier as genuinely loyal repeat customers, because the
    -- score is blind to tenure and purchase count context.
    -- See analysis notes for the comparison.
    -- ------------------------------------------------------------
    CASE
        WHEN tenure_group = 'Recent (<3mo tenure)'
            THEN 'B0: New / recently acquired'
        WHEN frequency = 1 AND recency <= 90
            THEN 'B5: One-time buyer'
        WHEN frequency = 1 AND recency > 90
            THEN 'B6: One-time buyer, inactive'
        WHEN frequency >= 6 AND recency <= 90
            THEN 'B1: High-frequency, engaged'
        WHEN frequency >= 6 AND recency > 90
            THEN 'B2: High-value, declining engagement'
        WHEN frequency BETWEEN 2 AND 5 AND recency <= 180
            THEN 'B3: Regular/occasional, active'
        ELSE 'B4: Regular/occasional, inactive'
    END AS customer_segment
FROM customer_rfm_base;


-- ------------------------------------------------------------
-- 4. Business analysis: revenue contribution by frequency band
--    (Key finding: revenue rises consistently across every band,
--    not concentrated in a single tier)
-- ------------------------------------------------------------

SELECT
    freq_band,
    COUNT(*)                                                          AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)                 AS pct_customers,
    ROUND(SUM(monetary), 0)                                            AS total_revenue,
    ROUND(SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER (), 1)       AS pct_revenue,
    ROUND(AVG(monetary), 0)                                            AS avg_revenue_per_customer
FROM customer_segments
GROUP BY freq_band
ORDER BY MIN(frequency);

-- Expected: 6+ orders (bands "6-8" + "9+") = ~32.0% of customers,
-- ~55.7% of realized revenue


-- ------------------------------------------------------------
-- 5. Business analysis: final segment sizes and revenue
-- ------------------------------------------------------------

SELECT
    customer_segment,
    COUNT(*)                                                       AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)              AS pct_customers,
    ROUND(SUM(monetary), 0)                                         AS revenue,
    ROUND(SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER (), 1)    AS pct_revenue,
    ROUND(AVG(monetary), 0)                                         AS revenue_per_customer
FROM customer_segments
GROUP BY customer_segment
ORDER BY revenue DESC;

-- Expected: B1 = 28.6% of customers / 50.0% of revenue
--           B2 = 3.4% of customers (1,906) / 5.7% of revenue
--
-- NOTE ON TERMINOLOGY: B2 (frequency >= 6 AND recency > 90 days)
-- is the analytical segment reported above (1,906 customers).
-- A stricter subset of B2 -- frequency >= 6 AND recency > 180
-- days -- was separately identified as a smaller, higher-priority
-- watchlist (547 customers, 0.98% of the eligible base, ~1.58%
-- of revenue). These are NOT the same group: B2 is the full
-- analytical segment; the 547-customer group is a targeted
-- subset of it used for the "watchlist" recommendation. See the
-- query below for how to reproduce the 547-customer subset.
-- ============================================================

-- Reproduces the 547-customer "high-priority watchlist" subset
-- referenced in the business recommendations (stricter than B2):
SELECT
    COUNT(*)                    AS watchlist_customers,
    ROUND(SUM(monetary), 0)     AS watchlist_revenue,
    ROUND(COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM customer_segments), 2)      AS pct_of_eligible_customers
FROM customer_segments
WHERE frequency >= 6
  AND recency > 180;
-- Expected: 547 customers, ~฿48.2M revenue, 0.98% of eligible base
