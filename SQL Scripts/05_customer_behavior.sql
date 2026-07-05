-- =========================================================
-- CUSTOMER BEHAVIOR ANALYSIS  (MySQL 8.0 syntax)
-- Covers: one-time vs repeat customers, geographic patterns, customer lifetime value
-- =========================================================

-- ---------------------------------------------------------
-- SECTION A: ONE-TIME vs REPEAT CUSTOMERS
-- ---------------------------------------------------------

-- A1. Order frequency per customer (foundation table used by the rest of this section)
-- Counts ALL orders regardless of status, since even a rejected/pending order shows intent to buy
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(o.order_id) AS num_orders
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY num_orders DESC;

-- A2. One-time vs repeat customer segmentation (headline split)
WITH customer_order_counts AS (
    SELECT customer_id, COUNT(*) AS num_orders
    FROM orders
    GROUP BY customer_id
)
SELECT
    CASE WHEN num_orders = 1 THEN '1. One-time customer' ELSE '2. Repeat customer' END AS customer_segment,
    COUNT(*) AS num_customers,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(DISTINCT customer_id) FROM orders), 2) AS pct_of_customers
FROM customer_order_counts
GROUP BY customer_segment;

-- A3. Repeat customers, broken into finer frequency bands (2 orders, 3 orders, 4+ orders)
WITH customer_order_counts AS (
    SELECT customer_id, COUNT(*) AS num_orders
    FROM orders
    GROUP BY customer_id
)
SELECT
    CASE
        WHEN num_orders = 1 THEN '1. One-time (1 order)'
        WHEN num_orders = 2 THEN '2. Occasional (2 orders)'
        WHEN num_orders BETWEEN 3 AND 4 THEN '3. Regular (3-4 orders)'
        ELSE '4. Loyal (5+ orders)'
    END AS frequency_band,
    COUNT(*) AS num_customers
FROM customer_order_counts
GROUP BY frequency_band
ORDER BY frequency_band;

-- A4. Revenue contribution: one-time vs repeat customers
-- (this shows whether repeat customers punch above their weight in revenue, not just headcount)
WITH customer_order_counts AS (
    SELECT customer_id, COUNT(*) AS num_orders
    FROM orders
    GROUP BY customer_id
),
customer_revenue AS (
    SELECT
        o.customer_id,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spend
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status != 3
    GROUP BY o.customer_id
)
SELECT
    CASE WHEN coc.num_orders = 1 THEN '1. One-time customer' ELSE '2. Repeat customer' END AS customer_segment,
    COUNT(DISTINCT coc.customer_id) AS num_customers,
    ROUND(SUM(COALESCE(cr.total_spend, 0)), 2) AS total_revenue,
    ROUND(SUM(COALESCE(cr.total_spend, 0)) / COUNT(DISTINCT coc.customer_id), 2) AS avg_revenue_per_customer
FROM customer_order_counts coc
LEFT JOIN customer_revenue cr ON cr.customer_id = coc.customer_id
GROUP BY customer_segment;


-- ---------------------------------------------------------
-- SECTION B: GEOGRAPHIC PATTERNS
-- ---------------------------------------------------------

-- B1. Customer count and order count by state
SELECT
    c.state,
    COUNT(DISTINCT c.customer_id) AS num_customers,
    COUNT(o.order_id) AS num_orders,
    ROUND(COUNT(o.order_id) * 1.0 / COUNT(DISTINCT c.customer_id), 2) AS avg_orders_per_customer
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.state
ORDER BY num_customers DESC;

-- B2. Revenue by state (where is demand concentrated in dollar terms, not just headcount?)
SELECT
    c.state,
    COUNT(DISTINCT c.customer_id) AS num_customers,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_revenue,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)) / COUNT(DISTINCT c.customer_id), 2) AS revenue_per_customer
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id AND o.order_status != 3
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY c.state
ORDER BY total_revenue DESC;

-- B3. Top 15 cities by customer count and revenue
SELECT
    c.city,
    c.state,
    COUNT(DISTINCT c.customer_id) AS num_customers,
    ROUND(COALESCE(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 0), 2) AS total_revenue
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.order_status != 3
LEFT JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY c.city, c.state
ORDER BY num_customers DESC
LIMIT 15;

-- B4. Does geography line up with which store fulfills the order? (customer state vs. store state)
-- Useful to see if customers are buying locally or from an out-of-state store
SELECT
    c.state AS customer_state,
    st.state AS store_state,
    COUNT(*) AS num_orders
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN stores st    ON st.store_id = o.store_id
GROUP BY c.state, st.state
ORDER BY c.state, num_orders DESC;


-- ---------------------------------------------------------
-- SECTION C: CUSTOMER LIFETIME VALUE (CLV)
-- ---------------------------------------------------------

-- C1. Basic CLV: total historical spend per customer, ranked highest to lowest
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.city,
    c.state,
    COUNT(DISTINCT o.order_id) AS num_orders,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS lifetime_value,
    ROUND(
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) / COUNT(DISTINCT o.order_id), 2
    ) AS avg_order_value
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id AND o.order_status != 3
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.city, c.state
ORDER BY lifetime_value DESC
LIMIT 20;

-- C2. CLV distribution in tiers (how concentrated is spend among a few high-value customers?)
WITH clv AS (
    SELECT
        o.customer_id,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS lifetime_value
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status != 3
    GROUP BY o.customer_id
)
SELECT
    CASE
        WHEN lifetime_value < 500   THEN '1. Under $500'
        WHEN lifetime_value < 1500  THEN '2. $500-$1499'
        WHEN lifetime_value < 3000  THEN '3. $1500-$2999'
        WHEN lifetime_value < 6000  THEN '4. $3000-$5999'
        ELSE '5. $6000+'
    END AS clv_tier,
    COUNT(*) AS num_customers,
    ROUND(SUM(lifetime_value), 2) AS tier_total_revenue,
    ROUND(SUM(lifetime_value) * 100.0 / (SELECT SUM(lifetime_value) FROM clv), 2) AS pct_of_total_revenue
FROM clv
GROUP BY clv_tier
ORDER BY clv_tier;

-- C3. Customer span: first purchase to most recent purchase (how long customers stick around)
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    MIN(o.order_date) AS first_order_date,
    MAX(o.order_date) AS most_recent_order_date,
    DATEDIFF(MAX(o.order_date), MIN(o.order_date)) AS customer_span_days,
    COUNT(DISTINCT o.order_id) AS num_orders,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS lifetime_value
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id AND o.order_status != 3
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING num_orders > 1
ORDER BY customer_span_days DESC
LIMIT 20;

-- C4. Top 10 highest-CLV customers with their state (cross-reference CLV with geography)
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.state,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS lifetime_value
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id AND o.order_status != 3
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.state
ORDER BY lifetime_value DESC
LIMIT 10;
