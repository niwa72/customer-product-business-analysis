-- ============================================================
-- PROJECT 2: CUSTOMER & PRODUCT BUSINESS ANALYSIS
-- 03. CATEGORY & PRODUCT ANALYSIS
--
-- Business question:
--   Which product categories are most important to the
--   highest-value customer segments, and where are there
--   opportunities to increase customer value?
--
-- Note: this file tests a hypothesis (high-value customers show
-- distinctive category preferences) and reports the result even
-- though it turned out to be a NULL result. The SQL below is
-- written to test the hypothesis, not to search for a positive
-- finding.
--
-- Depends on: customer_segments (created in 02_customer_analysis.sql)
-- ============================================================


-- ------------------------------------------------------------
-- 1. Category revenue & order contribution (overall)
-- ------------------------------------------------------------

SELECT
    p.category,
    ROUND(SUM(oi.line_total), 0)                                    AS revenue,
    ROUND(SUM(oi.line_total) * 100.0 / SUM(SUM(oi.line_total)) OVER (), 1) AS pct_revenue,
    COUNT(DISTINCT oi.order_id)                                     AS unique_orders,
    COUNT(DISTINCT o.customer_id)                                   AS unique_customers
FROM order_items oi
JOIN orders o    ON oi.order_id = o.order_id
JOIN products p  ON oi.product_id = p.product_id
WHERE oi.item_status = 'Completed'
GROUP BY p.category
ORDER BY revenue DESC;

-- Expected: Home 62.4%, Electronics 33.8%, Fashion 2.9%,
--           Groceries 0.5%, Beauty 0.4%


-- ------------------------------------------------------------
-- 2. Category revenue share WITHIN each customer segment,
--    compared against the OVERALL category mix (over-index test)
--
--    over_index = (category revenue share within segment)
--                  / (category revenue share overall)
--    Values substantially above or below 1.0 would indicate
--    potential over/under-indexing. The +/-15% band used below
--    is a descriptive business rule chosen for readability, NOT
--    a statistical significance test -- no hypothesis test was
--    run, so this threshold should be described as a heuristic
--    if asked, not as a p-value or confidence interval.
-- ------------------------------------------------------------

WITH segment_category_revenue AS (
    SELECT
        cs.customer_segment,
        p.category,
        SUM(oi.line_total) AS revenue
    FROM order_items oi
    JOIN orders o             ON oi.order_id = o.order_id
    JOIN products p           ON oi.product_id = p.product_id
    JOIN customer_segments cs ON o.customer_id = cs.customer_id
    WHERE oi.item_status = 'Completed'
    GROUP BY cs.customer_segment, p.category
),
segment_totals AS (
    SELECT customer_segment, SUM(revenue) AS segment_revenue
    FROM segment_category_revenue
    GROUP BY customer_segment
),
overall_category AS (
    SELECT category, SUM(revenue) AS category_revenue,
           SUM(revenue) * 1.0 / SUM(SUM(revenue)) OVER () AS overall_share
    FROM segment_category_revenue
    GROUP BY category
)
SELECT
    scr.customer_segment,
    scr.category,
    ROUND(scr.revenue * 100.0 / st.segment_revenue, 1)               AS pct_of_segment_revenue,
    ROUND(oc.overall_share * 100, 1)                                  AS overall_pct_baseline,
    ROUND((scr.revenue / st.segment_revenue) / oc.overall_share, 2)   AS over_index
FROM segment_category_revenue scr
JOIN segment_totals st  ON scr.customer_segment = st.customer_segment
JOIN overall_category oc ON scr.category = oc.category
WHERE scr.customer_segment IN (
    'B1: High-frequency, engaged',
    'B2: High-value, declining engagement'
)
ORDER BY scr.customer_segment, scr.category;

-- Expected result: all over_index values between ~0.95 and ~1.15
-- -> no meaningful over-indexing was observed under the defined
-- business threshold for B1 or B2. This is the reported finding;
-- the hypothesis was tested and not supported by the data.


-- ------------------------------------------------------------
-- 2b. PRODUCT-LEVEL over-index test (same hypothesis, finer
--     grain). Category-level found no affinity; this checks
--     whether it might still exist at the individual-product
--     level. Restricted to products with >=100 purchasing
--     customers to avoid small-sample artifacts, and to the
--     top 30 of those by revenue (matches the scope agreed
--     before running this check).
-- ------------------------------------------------------------

WITH eligible_products AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(oi.line_total)              AS revenue,
        COUNT(DISTINCT o.customer_id)    AS customers
    FROM order_items oi
    JOIN orders o    ON oi.order_id = o.order_id
    JOIN products p  ON oi.product_id = p.product_id
    WHERE oi.item_status = 'Completed'
    GROUP BY p.product_id, p.product_name, p.category
    HAVING COUNT(DISTINCT o.customer_id) >= 100
    ORDER BY revenue DESC
    LIMIT 30
),
product_segment_revenue AS (
    SELECT
        ep.product_id,
        cs.customer_segment,
        SUM(oi.line_total) AS seg_revenue
    FROM order_items oi
    JOIN orders o              ON oi.order_id = o.order_id
    JOIN customer_segments cs  ON o.customer_id = cs.customer_id
    JOIN eligible_products ep  ON oi.product_id = ep.product_id
    WHERE oi.item_status = 'Completed'
    GROUP BY ep.product_id, cs.customer_segment
)
SELECT
    ep.product_id,
    ep.product_name,
    ep.category,
    ROUND(ep.revenue, 0)                                        AS total_revenue,
    ep.customers                                                AS total_customers,
    ROUND(COALESCE(b1.seg_revenue, 0) * 100.0 / ep.revenue, 1)   AS b1_revshare_pct,
    ROUND(COALESCE(b2.seg_revenue, 0) * 100.0 / ep.revenue, 1)   AS b2_revshare_pct
FROM eligible_products ep
LEFT JOIN product_segment_revenue b1
    ON ep.product_id = b1.product_id AND b1.customer_segment = 'B1: High-frequency, engaged'
LEFT JOIN product_segment_revenue b2
    ON ep.product_id = b2.product_id AND b2.customer_segment = 'B2: High-value, declining engagement'
ORDER BY ep.revenue DESC;

-- Expected: b1_revshare_pct averages ~50.4% (baseline: B1 = 50.0%
-- of total realized revenue), b2_revshare_pct averages ~5.7%
-- (baseline: B2 = 5.7% of total realized revenue). Both closely
-- track their overall baseline share -> confirms the category-level
-- null result at the product level; no meaningful concentration
-- of B1/B2 revenue in any specific top product.


-- ------------------------------------------------------------
-- 3. Repeat-purchase behavior by category
--    (Independent of the segment question above: which
--    categories drive repeat behavior in general?)
-- ------------------------------------------------------------

WITH customer_category_orders AS (
    SELECT
        p.category,
        o.customer_id,
        COUNT(DISTINCT oi.order_id) AS orders_in_category
    FROM order_items oi
    JOIN orders o    ON oi.order_id = o.order_id
    JOIN products p  ON oi.product_id = p.product_id
    WHERE oi.item_status = 'Completed'
    GROUP BY p.category, o.customer_id
)
SELECT
    category,
    COUNT(*)                                                          AS customers,
    ROUND(AVG(orders_in_category), 2)                                 AS avg_orders_per_customer,
    ROUND(SUM(CASE WHEN orders_in_category > 1 THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)                                      AS pct_repeat_within_category
FROM customer_category_orders
GROUP BY category
ORDER BY avg_orders_per_customer DESC;

-- Expected: Home has both the highest revenue AND the highest
-- repeat rate (75.5%); Electronics has the highest AOV but a
-- lower repeat rate (41.1%) -- investigated further below.


-- ------------------------------------------------------------
-- 4. Electronics vs Home: is the lower Electronics repeat rate
--    a retention problem, or a naturally longer purchase cycle?
--
--    Compares customers who bought each category on:
--    overall (all-category) frequency and monetary value, and
--    the median gap between purchases WITHIN the category.
-- ------------------------------------------------------------

-- IMPORTANT: must reduce to one row per (category, customer) BEFORE
-- joining to customer_segments and averaging. Averaging directly
-- over order_item-level rows would overweight customers who bought
-- the category more often, distorting the comparison.
WITH cat_customers AS (
    SELECT DISTINCT p.category, o.customer_id
    FROM order_items oi
    JOIN orders o    ON oi.order_id = o.order_id
    JOIN products p  ON oi.product_id = p.product_id
    WHERE oi.item_status = 'Completed'
      AND p.category IN ('Electronics', 'Home')
)
SELECT
    cc.category,
    COUNT(*)                            AS customers,
    ROUND(AVG(cs.frequency), 2)         AS avg_overall_frequency,
    ROUND(AVG(cs.monetary), 0)          AS avg_overall_monetary
FROM cat_customers cc
JOIN customer_segments cs ON cc.customer_id = cs.customer_id
GROUP BY cc.category;

-- Expected: Electronics buyers have HIGHER overall frequency
-- (5.44 vs 4.76) and monetary value (~74k vs ~59k) than Home
-- buyers, despite lower in-category repeat -- consistent with
-- Electronics being a durable-goods category with a naturally
-- longer purchase cycle, not a sign of disengaged customers.


-- ------------------------------------------------------------
-- 5. Median gap between purchases WITHIN each category
--    (for customers with 2+ purchases in that category).
--    This is the evidence for the "naturally longer purchase
--    cycle" interpretation of Electronics used above.
--
--    MySQL 8.0 has no built-in MEDIAN() function, so this uses
--    PERCENT_RANK() to find the middle value(s) of the gap
--    distribution per category.
-- ------------------------------------------------------------

WITH category_order_dates AS (
    SELECT DISTINCT
        p.category,
        o.customer_id,
        o.order_id,
        o.order_date
    FROM order_items oi
    JOIN orders o    ON oi.order_id = o.order_id
    JOIN products p  ON oi.product_id = p.product_id
    WHERE oi.item_status = 'Completed'
      AND p.category IN ('Electronics', 'Home')
),
gaps AS (
    SELECT
        category,
        customer_id,
        DATEDIFF(
            order_date,
            LAG(order_date) OVER (
                PARTITION BY category, customer_id ORDER BY order_date
            )
        ) AS days_since_prev
    FROM category_order_dates
),
ranked_gaps AS (
    SELECT
        category,
        days_since_prev,
        PERCENT_RANK() OVER (
            PARTITION BY category ORDER BY days_since_prev
        ) AS pct_rank
    FROM gaps
    WHERE days_since_prev IS NOT NULL
)
SELECT
    category,
    MIN(days_since_prev) AS median_gap_days
FROM ranked_gaps
WHERE pct_rank >= 0.5
GROUP BY category;

-- Expected: Electronics median gap ~208-209 days, Home median gap
-- ~126-127 days -- confirms Electronics has a materially longer
-- natural repurchase cycle, supporting the interpretation above.
-- (A 1-day difference from the original Python result is expected:
-- pandas' median() interpolates between the two middle values for
-- an even-sized distribution, while this PERCENT_RANK approach
-- uses nearest-rank. Both describe the same underlying pattern.)
-- ============================================================
