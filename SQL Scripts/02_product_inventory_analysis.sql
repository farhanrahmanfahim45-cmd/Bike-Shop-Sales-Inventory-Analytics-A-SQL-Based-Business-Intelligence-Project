-- =========================================================
-- PRODUCT & INVENTORY ANALYSIS
-- =========================================================

-- ---------------------------------------------------------
-- SECTION A: BEST-SELLERS vs SLOW-MOVERS
-- ---------------------------------------------------------

-- A1. Revenue & units sold per product, ranked (best-sellers first)
SELECT
    p.product_id,
    p.product_name,
    b.brand_name,
    c.category_name,
    SUM(oi.quantity)                                        AS units_sold,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_revenue,
    COUNT(DISTINCT oi.order_id)                             AS num_orders
FROM order_items oi
JOIN products p   ON p.product_id = oi.product_id
JOIN brands b     ON b.brand_id = p.brand_id
JOIN categories c ON c.category_id = p.category_id
GROUP BY p.product_id, p.product_name, b.brand_name, c.category_name
ORDER BY units_sold DESC
LIMIT 10;

-- A2. Slow-movers: products with lowest units sold (still sold at least once)
SELECT
    p.product_id,
    p.product_name,
    b.brand_name,
    c.category_name,
    SUM(oi.quantity)                                        AS units_sold,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_revenue
FROM order_items oi
JOIN products p   ON p.product_id = oi.product_id
JOIN brands b     ON b.brand_id = p.brand_id
JOIN categories c ON c.category_id = p.category_id
GROUP BY p.product_id, p.product_name, b.brand_name, c.category_name
ORDER BY units_sold ASC
LIMIT 10;

-- A3. Never-sold products (true dead stock) - products with zero order_items
SELECT
    p.product_id,
    p.product_name,
    b.brand_name,
    c.category_name,
    p.list_price
FROM products p
JOIN brands b     ON b.brand_id = p.brand_id
JOIN categories c ON c.category_id = p.category_id
LEFT JOIN order_items oi ON oi.product_id = p.product_id
WHERE oi.product_id IS NULL
ORDER BY p.list_price DESC;

-- A4. Best-seller vs slow-mover classification using NTILE
-- Buckets all products (that have at least one sale) into quartiles by units sold
WITH product_sales AS (
    SELECT
        p.product_id,
        p.product_name,
        b.brand_name,
        c.category_name,
        SUM(oi.quantity) AS units_sold
    FROM order_items oi
    JOIN products p   ON p.product_id = oi.product_id
    JOIN brands b     ON b.brand_id = p.brand_id
    JOIN categories c ON c.category_id = p.category_id
    GROUP BY p.product_id, p.product_name, b.brand_name, c.category_name
)
SELECT
    *,
    NTILE(4) OVER (ORDER BY units_sold DESC) AS sales_quartile
    -- quartile 1 = best-sellers (top 25%), quartile 4 = slow-movers (bottom 25%)
FROM product_sales
ORDER BY units_sold DESC;

-- A5. Best-sellers vs slow-movers, aggregated by CATEGORY
SELECT
    c.category_name,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_net_revenue,
    COUNT(DISTINCT p.product_id) AS distinct_products_sold
FROM order_items oi
JOIN products p   ON p.product_id = oi.product_id
JOIN categories c ON c.category_id = p.category_id
GROUP BY c.category_name
ORDER BY total_units_sold DESC;

-- A6. Best-sellers vs slow-movers, aggregated by BRAND
SELECT
    b.brand_name,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_net_revenue,
    COUNT(DISTINCT p.product_id) AS distinct_products_sold
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN brands b   ON b.brand_id = p.brand_id
GROUP BY b.brand_name
ORDER BY total_units_sold DESC;

-- A7. Sales velocity vs current stock — flag overstocked slow-movers
-- (high stock, low/no sales = capital tied up in inventory that isn't moving)
SELECT
    p.product_id,
    p.product_name,
    b.brand_name,
    c.category_name,
    COALESCE(SUM(oi.quantity), 0)      AS units_sold,
    SUM(s.quantity)                    AS total_stock_on_hand,
    ROUND(
        SUM(s.quantity) * 1.0 / NULLIF(SUM(oi.quantity), 0), 2
    ) AS stock_to_sales_ratio
FROM products p
JOIN brands b     ON b.brand_id = p.brand_id
JOIN categories c ON c.category_id = p.category_id
LEFT JOIN order_items oi ON oi.product_id = p.product_id
LEFT JOIN stocks s        ON s.product_id = p.product_id
GROUP BY p.product_id, p.product_name, b.brand_name, c.category_name
HAVING total_stock_on_hand > 0
ORDER BY stock_to_sales_ratio DESC
LIMIT 15;


-- ---------------------------------------------------------
-- SECTION B: PRICE DISTRIBUTION ACROSS CATEGORIES & BRANDS
-- ---------------------------------------------------------

-- B1. Price distribution stats per category (min, max, avg, median)
WITH ranked AS (
    SELECT
        p.category_id,
        p.list_price,
        ROW_NUMBER() OVER (PARTITION BY p.category_id ORDER BY p.list_price) AS rn,
        COUNT(*) OVER (PARTITION BY p.category_id) AS cnt
    FROM products p
),
medians AS (
    SELECT
        category_id,
        AVG(list_price) AS median_price   -- averages the 1 or 2 middle-ranked rows
    FROM ranked
    WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
    GROUP BY category_id
)
SELECT
    c.category_name,
    COUNT(p.product_id)          AS num_products,
    ROUND(MIN(p.list_price), 2)  AS min_price,
    ROUND(MAX(p.list_price), 2)  AS max_price,
    ROUND(AVG(p.list_price), 2)  AS avg_price,
    ROUND(m.median_price, 2)     AS median_price
FROM products p
JOIN categories c ON c.category_id = p.category_id
JOIN medians m    ON m.category_id = p.category_id
GROUP BY c.category_name, m.median_price
ORDER BY avg_price DESC;

-- B2. Price distribution stats per brand
SELECT
    b.brand_name,
    COUNT(p.product_id)          AS num_products,
    ROUND(MIN(p.list_price), 2)  AS min_price,
    ROUND(MAX(p.list_price), 2)  AS max_price,
    ROUND(AVG(p.list_price), 2)  AS avg_price
FROM products p
JOIN brands b ON b.brand_id = p.brand_id
GROUP BY b.brand_name
ORDER BY avg_price DESC;

-- B3. Price buckets/tiers (bucketed histogram) - overall
SELECT
    CASE
        WHEN list_price < 500  THEN '1. Under $500'
        WHEN list_price < 1000 THEN '2. $500-$999'
        WHEN list_price < 2000 THEN '3. $1000-$1999'
        WHEN list_price < 3000 THEN '4. $2000-$2999'
        ELSE '5. $3000+'
    END AS price_tier,
    COUNT(*) AS num_products,
    ROUND(AVG(list_price), 2) AS avg_price_in_tier
FROM products
GROUP BY price_tier
ORDER BY price_tier;

-- B4. Price tiers broken down by category (cross-tab style)
SELECT
    c.category_name,
    CASE
        WHEN p.list_price < 500  THEN '1. Under $500'
        WHEN p.list_price < 1000 THEN '2. $500-$999'
        WHEN p.list_price < 2000 THEN '3. $1000-$1999'
        WHEN p.list_price < 3000 THEN '4. $2000-$2999'
        ELSE '5. $3000+'
    END AS price_tier,
    COUNT(*) AS num_products
FROM products p
JOIN categories c ON c.category_id = p.category_id
GROUP BY c.category_name, price_tier
ORDER BY c.category_name, price_tier;

-- B5. Does higher list_price correlate with higher/lower discount given at sale?
SELECT
    CASE
        WHEN oi.list_price < 500  THEN '1. Under $500'
        WHEN oi.list_price < 1000 THEN '2. $500-$999'
        WHEN oi.list_price < 2000 THEN '3. $1000-$1999'
        WHEN oi.list_price < 3000 THEN '4. $2000-$2999'
        ELSE '5. $3000+'
    END AS price_tier,
    ROUND(AVG(oi.discount) * 100, 2) AS avg_discount_pct,
    COUNT(*) AS num_line_items
FROM order_items oi
GROUP BY price_tier
ORDER BY price_tier;


-- ---------------------------------------------------------
-- SECTION C: MODEL YEAR TRENDS
-- ---------------------------------------------------------

-- C1. Number of products introduced per model year, and their avg price
SELECT
    model_year,
    COUNT(*)                     AS num_products,
    ROUND(AVG(list_price), 2)    AS avg_list_price,
    ROUND(MIN(list_price), 2)    AS min_price,
    ROUND(MAX(list_price), 2)    AS max_price
FROM products
GROUP BY model_year
ORDER BY model_year;

-- C2. Units sold and revenue by model year (are newer models outselling older ones?)
SELECT
    p.model_year,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_revenue,
    ROUND(AVG(oi.discount) * 100, 2) AS avg_discount_pct
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.model_year
ORDER BY p.model_year;

-- C3. Model year performance broken down by category
SELECT
    p.model_year,
    c.category_name,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_revenue
FROM order_items oi
JOIN products p   ON p.product_id = oi.product_id
JOIN categories c ON c.category_id = p.category_id
GROUP BY p.model_year, c.category_name
ORDER BY p.model_year, units_sold DESC;

-- C4. Are older model-year bikes discounted more heavily (clearance pattern)?
SELECT
    p.model_year,
    ROUND(AVG(oi.discount) * 100, 2) AS avg_discount_pct,
    ROUND(AVG(oi.list_price), 2)     AS avg_list_price,
    SUM(oi.quantity)                 AS units_sold
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.model_year
ORDER BY p.model_year;

-- C5. Remaining stock by model year (are we sitting on old inventory?)
SELECT
    p.model_year,
    SUM(s.quantity) AS total_stock_remaining,
    COUNT(DISTINCT p.product_id) AS num_products
FROM stocks s
JOIN products p ON p.product_id = s.product_id
GROUP BY p.model_year
ORDER BY p.model_year;