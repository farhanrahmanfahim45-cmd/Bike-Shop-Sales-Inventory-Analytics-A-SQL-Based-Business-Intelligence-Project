-- =========================================================
-- SALES PERFORMANCE & REVENUE PATTERNS  (MySQL 8.0 syntax)
-- Covers: revenue trends over time, revenue by store/staff/category/brand,
--         discount impact on quantity, average order value by store/customer
-- =========================================================
-- NOTE ON ORDER STATUS: order_status = 3 is "Rejected" (never actually sold).
-- All revenue figures below exclude Rejected orders but INCLUDE Pending/Processing,
-- since those still represent real, expected sales (see note from prior analysis:
-- Pending/Processing orders are simply the most recent month that hadn't shipped
-- yet as of the data snapshot - they are not failed transactions).

-- ---------------------------------------------------------
-- SECTION A: REVENUE TRENDS OVER TIME
-- ---------------------------------------------------------

-- A1. Monthly revenue trend
SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
    COUNT(DISTINCT o.order_id) AS num_orders,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status != 3
GROUP BY order_month
ORDER BY order_month;

-- A2. Yearly revenue trend, with year-over-year growth
WITH yearly AS (
    SELECT
        YEAR(o.order_date) AS order_year,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS net_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status != 3
    GROUP BY order_year
)
SELECT
    order_year,
    ROUND(net_revenue, 2) AS net_revenue,
    ROUND(
        (net_revenue - LAG(net_revenue) OVER (ORDER BY order_year))
        / LAG(net_revenue) OVER (ORDER BY order_year) * 100, 2
    ) AS yoy_growth_pct
FROM yearly
ORDER BY order_year;

-- A3. Revenue by quarter (finer-grained seasonality than year, smoother than month)
SELECT
    YEAR(o.order_date) AS order_year,
    QUARTER(o.order_date) AS order_quarter,
    COUNT(DISTINCT o.order_id) AS num_orders,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status != 3
GROUP BY order_year, order_quarter
ORDER BY order_year, order_quarter;

-- A4. Revenue by calendar month across all years combined (is there a seasonal pattern, e.g. spring/summer bike sales spike?)
SELECT
    MONTH(o.order_date) AS calendar_month,
    MONTHNAME(o.order_date) AS month_name,
    COUNT(DISTINCT o.order_id) AS num_orders,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status != 3
GROUP BY calendar_month, month_name
ORDER BY calendar_month;

-- A5. Running (cumulative) monthly revenue - useful for a cumulative growth chart
WITH monthly AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS net_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status != 3
    GROUP BY order_month
)
SELECT
    order_month,
    ROUND(net_revenue, 2) AS net_revenue,
    ROUND(SUM(net_revenue) OVER (ORDER BY order_month), 2) AS cumulative_revenue
FROM monthly
ORDER BY order_month;


-- ---------------------------------------------------------
-- SECTION B: REVENUE BY STORE, STAFF, CATEGORY, BRAND
-- ---------------------------------------------------------

-- B1. Revenue by store
SELECT
    st.store_id,
    st.store_name,
    COUNT(DISTINCT o.order_id) AS num_orders,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_revenue,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)) * 100.0 /
        (SELECT SUM(oi2.quantity * oi2.list_price * (1 - oi2.discount))
         FROM orders o2 JOIN order_items oi2 ON oi2.order_id = o2.order_id
         WHERE o2.order_status != 3), 2) AS pct_of_total_revenue
FROM orders o
JOIN stores st ON st.store_id = o.store_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status != 3
GROUP BY st.store_id, st.store_name
ORDER BY net_revenue DESC;

-- B2. Revenue by staff member
SELECT
    s.staff_id,
    s.first_name,
    s.last_name,
    st.store_name,
    COUNT(DISTINCT o.order_id) AS num_orders,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_revenue
FROM orders o
JOIN staffs s ON s.staff_id = o.staff_id
JOIN stores st ON st.store_id = s.store_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status != 3
GROUP BY s.staff_id, s.first_name, s.last_name, st.store_name
ORDER BY net_revenue DESC;

-- B3. Revenue by category
SELECT
    c.category_name,
    COUNT(DISTINCT o.order_id) AS num_orders,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
JOIN categories c   ON c.category_id = p.category_id
WHERE o.order_status != 3
GROUP BY c.category_name
ORDER BY net_revenue DESC;

-- B4. Revenue by brand
SELECT
    b.brand_name,
    COUNT(DISTINCT o.order_id) AS num_orders,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
JOIN brands b       ON b.brand_id = p.brand_id
WHERE o.order_status != 3
GROUP BY b.brand_name
ORDER BY net_revenue DESC;

-- B5. Revenue by store AND category combined (cross-tab: which stores over/under-index on which categories?)
SELECT
    st.store_name,
    c.category_name,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_revenue
FROM orders o
JOIN stores st      ON st.store_id = o.store_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
JOIN categories c   ON c.category_id = p.category_id
WHERE o.order_status != 3
GROUP BY st.store_name, c.category_name
ORDER BY st.store_name, net_revenue DESC;


-- ---------------------------------------------------------
-- SECTION C: DISCOUNT IMPACT ON QUANTITY SOLD
-- ---------------------------------------------------------

-- C1. Discount tier vs. average quantity per line item (does a bigger discount move more units per sale?)
SELECT
    CASE
        WHEN oi.discount = 0                     THEN '1. No discount (0%)'
        WHEN oi.discount > 0    AND oi.discount <= 0.05 THEN '2. 1-5%'
        WHEN oi.discount > 0.05 AND oi.discount <= 0.10 THEN '3. 6-10%'
        WHEN oi.discount > 0.10 AND oi.discount <= 0.15 THEN '4. 11-15%'
        WHEN oi.discount > 0.15 AND oi.discount <= 0.20 THEN '5. 16-20%'
        ELSE '6. 20%+'
    END AS discount_tier,
    COUNT(*) AS num_line_items,
    ROUND(AVG(oi.quantity), 2) AS avg_quantity_per_line_item,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_revenue
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status != 3
GROUP BY discount_tier
ORDER BY discount_tier;

-- C2. Correlation check: average discount vs. average quantity, per product
-- (products with generally higher discounts - do they show higher average order quantity?)
SELECT
    p.product_id,
    p.product_name,
    COUNT(*) AS num_line_items,
    ROUND(AVG(oi.discount) * 100, 2) AS avg_discount_pct,
    ROUND(AVG(oi.quantity), 2) AS avg_quantity_per_line_item,
    SUM(oi.quantity) AS total_units_sold
FROM order_items oi
JOIN orders o   ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.order_status != 3
GROUP BY p.product_id, p.product_name
HAVING num_line_items >= 5   -- filter out very low-sample products for a cleaner signal
ORDER BY avg_discount_pct DESC;

-- C3. Overall summary stats to directly answer "do bigger discounts move more volume?"
-- Compares total units sold and per-line-item average quantity between discounted and non-discounted line items
SELECT
    CASE WHEN oi.discount = 0 THEN '1. No discount' ELSE '2. Discounted' END AS discount_flag,
    COUNT(*) AS num_line_items,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(AVG(oi.quantity), 2) AS avg_quantity_per_line_item,
    ROUND(AVG(oi.discount) * 100, 2) AS avg_discount_pct
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status != 3
GROUP BY discount_flag;

-- C4. Discount tier vs. quantity, broken down by category (the pattern may differ by product type)
SELECT
    c.category_name,
    CASE
        WHEN oi.discount = 0                     THEN '1. No discount (0%)'
        WHEN oi.discount > 0    AND oi.discount <= 0.10 THEN '2. 1-10%'
        WHEN oi.discount > 0.10 AND oi.discount <= 0.20 THEN '3. 11-20%'
        ELSE '4. 20%+'
    END AS discount_tier,
    COUNT(*) AS num_line_items,
    ROUND(AVG(oi.quantity), 2) AS avg_quantity_per_line_item
FROM order_items oi
JOIN orders o     ON o.order_id = oi.order_id
JOIN products p   ON p.product_id = oi.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE o.order_status != 3
GROUP BY c.category_name, discount_tier
ORDER BY c.category_name, discount_tier;


-- ---------------------------------------------------------
-- SECTION D: AVERAGE ORDER VALUE (AOV)
-- ---------------------------------------------------------

-- D1. Overall average order value
SELECT
    COUNT(DISTINCT o.order_id) AS num_orders,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_revenue,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status != 3;

-- D2. Average order value by store
SELECT
    st.store_id,
    st.store_name,
    COUNT(DISTINCT o.order_id) AS num_orders,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN stores st      ON st.store_id = o.store_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status != 3
GROUP BY st.store_id, st.store_name
ORDER BY avg_order_value DESC;

-- D3. Average order value by customer (top 20 highest-AOV customers, min 2 orders for a meaningful average)
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.state,
    COUNT(DISTINCT o.order_id) AS num_orders,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN customers c    ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status != 3
GROUP BY c.customer_id, c.first_name, c.last_name, c.state
HAVING num_orders >= 2
ORDER BY avg_order_value DESC
LIMIT 20;

-- D4. AOV distribution across all customers (bucketed, to see the overall shape)
WITH customer_aov AS (
    SELECT
        o.customer_id,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) / COUNT(DISTINCT o.order_id) AS aov
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status != 3
    GROUP BY o.customer_id
)
SELECT
    CASE
        WHEN aov < 1000  THEN '1. Under $1000'
        WHEN aov < 2500  THEN '2. $1000-$2499'
        WHEN aov < 5000  THEN '3. $2500-$4999'
        WHEN aov < 10000 THEN '4. $5000-$9999'
        ELSE '5. $10000+'
    END AS aov_bucket,
    COUNT(*) AS num_customers
FROM customer_aov
GROUP BY aov_bucket
ORDER BY aov_bucket;

-- D5. Monthly AOV trend (is the average order getting bigger or smaller over time?)
SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
    COUNT(DISTINCT o.order_id) AS num_orders,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status != 3
GROUP BY order_month
ORDER BY order_month;
