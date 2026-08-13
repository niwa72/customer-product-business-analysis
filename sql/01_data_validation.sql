-- ============================================================
-- PROJECT 2: CUSTOMER & PRODUCT BUSINESS ANALYSIS
-- 01. DATA VALIDATION
--
-- Business question:
--   Before analyzing customer value, is the data reliable enough
--   to support the analysis, and what does "revenue" actually mean
--   in this dataset?
--
-- Tables used:
--   orders, order_items, customers, products, sellers
--
-- Why this file exists:
--   Every downstream metric (customer segmentation, category
--   analysis, seller analysis) depends on a correct definition of
--   "realized revenue." This file establishes that definition and
--   documents the data-quality checks that justified it.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Structural integrity checks
-- ------------------------------------------------------------

-- 1a. Duplicate primary keys (should return 0 rows)
SELECT order_id, COUNT(*) AS n
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

SELECT order_item_id, COUNT(*) AS n
FROM order_items
GROUP BY order_item_id
HAVING COUNT(*) > 1;

-- 1b. Referential integrity: every order_item must map to a real order,
--     product, and every order must map to a real customer
--     (should all return 0 rows)
SELECT oi.order_id
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT oi.product_id
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT o.customer_id
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- ------------------------------------------------------------
-- 2. item_status distribution
--    Establishes how much of the dataset is actually fulfilled
-- ------------------------------------------------------------

SELECT
    item_status,
    COUNT(*)                                            AS n_items,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)   AS pct_of_items
FROM order_items
GROUP BY item_status;

-- Result: ~75.0% Completed, ~20.0% Cancelled, ~5.0% Refunded


-- ------------------------------------------------------------
-- 3. Revenue reconciliation
--    KEY FINDING: does orders.total_amount already reflect
--    fulfilled ("realized") revenue, or does it include items
--    that were later cancelled/refunded?
-- ------------------------------------------------------------

-- 3a. Compare orders.subtotal_amount to the sum of ALL order_items
--     (regardless of status). If these match, subtotal_amount
--     includes cancelled/refunded items.
SELECT
    COUNT(*) AS mismatched_orders
FROM orders o
JOIN (
    SELECT order_id, SUM(line_total) AS sum_all_items
    FROM order_items
    GROUP BY order_id
) oi_all ON o.order_id = oi_all.order_id
WHERE ABS(o.subtotal_amount - oi_all.sum_all_items) > 0.05;
-- Result: 0 mismatches -> subtotal_amount = sum of ALL items,
-- including Cancelled and Refunded.

-- 3b. Compare orders.subtotal_amount to the sum of COMPLETED-only
--     order_items. If these do NOT match, orders.total_amount
--     cannot be used as realized revenue.
SELECT
    COUNT(*) AS mismatched_orders
FROM orders o
LEFT JOIN (
    SELECT order_id, SUM(line_total) AS sum_completed_items
    FROM order_items
    WHERE item_status = 'Completed'
    GROUP BY order_id
) oi_completed ON o.order_id = oi_completed.order_id
WHERE ABS(o.subtotal_amount - COALESCE(oi_completed.sum_completed_items, 0)) > 0.05;
-- Result: ~105,429 mismatched orders (35% of all orders)

-- 3c. How many orders have ZERO realized revenue
--     (every item cancelled or refunded), despite orders.total_amount
--     showing a positive figure?
SELECT
    COUNT(*) AS orders_with_no_completed_items,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 1) AS pct_of_all_orders
FROM orders o
WHERE NOT EXISTS (
    SELECT 1 FROM order_items oi
    WHERE oi.order_id = o.order_id
      AND oi.item_status = 'Completed'
);
-- Result: 49,951 orders (16.7%) generated no realized revenue at all


-- ------------------------------------------------------------
-- CONCLUSION
-- ------------------------------------------------------------
-- orders.total_amount / subtotal_amount is GROSS order value,
-- not realized revenue: it includes items that were never
-- actually fulfilled.
--
-- DEFINITION USED THROUGHOUT THIS PROJECT:
--
--   realized_revenue = SUM(order_items.line_total)
--                       WHERE order_items.item_status = 'Completed'
--
-- This definition is applied consistently in
-- 02_customer_analysis.sql, 03_category_analysis.sql, and
-- 04_seller_analysis.sql.
-- ============================================================
