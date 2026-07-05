-- =========================================================
-- OPERATIONAL EFFICIENCY ANALYSIS  (MySQL 8.0 syntax)
-- Covers: order_status breakdown, order fulfillment time
-- =========================================================

-- ---------------------------------------------------------
-- SECTION A: ORDER STATUS BREAKDOWN
-- ---------------------------------------------------------

-- A1. Overall order_status breakdown (order_status: 1=Pending, 2=Processing, 3=Rejected, 4=Completed)
SELECT
    order_status,
    CASE order_status
        WHEN 1 THEN 'Pending'
        WHEN 2 THEN 'Processing'
        WHEN 3 THEN 'Rejected'
        WHEN 4 THEN 'Completed'
        ELSE 'Unknown'
    END AS status_label,
    COUNT(*) AS num_orders,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS pct_of_all_orders
FROM orders
GROUP BY order_status
ORDER BY order_status;

-- A2. Order status breakdown by store (are some stores rejecting/delaying more than others?)
SELECT
    o.store_id,
    st.store_name,
    SUM(CASE WHEN o.order_status = 1 THEN 1 ELSE 0 END) AS pending,
    SUM(CASE WHEN o.order_status = 2 THEN 1 ELSE 0 END) AS processing,
    SUM(CASE WHEN o.order_status = 3 THEN 1 ELSE 0 END) AS rejected,
    SUM(CASE WHEN o.order_status = 4 THEN 1 ELSE 0 END) AS completed,
    COUNT(*) AS total_orders,
    ROUND(SUM(CASE WHEN o.order_status = 3 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS rejection_rate_pct
FROM orders o
JOIN stores st ON st.store_id = o.store_id
GROUP BY o.store_id, st.store_name
ORDER BY rejection_rate_pct DESC;

-- A3. Order status breakdown by month (seasonality in rejections/pending backlog)
SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS order_month,
    SUM(CASE WHEN order_status = 1 THEN 1 ELSE 0 END) AS pending,
    SUM(CASE WHEN order_status = 2 THEN 1 ELSE 0 END) AS processing,
    SUM(CASE WHEN order_status = 3 THEN 1 ELSE 0 END) AS rejected,
    SUM(CASE WHEN order_status = 4 THEN 1 ELSE 0 END) AS completed,
    COUNT(*) AS total_orders
FROM orders
GROUP BY order_month
ORDER BY order_month;


-- ---------------------------------------------------------
-- SECTION B: ORDER FULFILLMENT TIME
-- ---------------------------------------------------------
-- NOTE: only COMPLETED orders (order_status = 4) have a shipped_date.
-- Pending/Processing/Rejected orders have shipped_date = NULL, so they
-- are excluded from fulfillment-time math (there's nothing to measure yet).

-- B1. Overall average fulfillment time (order_date -> shipped_date), completed orders only
SELECT
    COUNT(*) AS num_completed_orders,
    ROUND(AVG(DATEDIFF(shipped_date, order_date)), 2) AS avg_days_to_ship,
    MIN(DATEDIFF(shipped_date, order_date)) AS fastest_fulfillment_days,
    MAX(DATEDIFF(shipped_date, order_date)) AS slowest_fulfillment_days
FROM orders
WHERE order_status = 4 AND shipped_date IS NOT NULL;

-- B2. Fulfillment time vs. the promised required_date
-- Negative value = shipped early/on-time ahead of deadline; positive = shipped late
SELECT
    COUNT(*) AS num_completed_orders,
    ROUND(AVG(DATEDIFF(shipped_date, required_date)), 2) AS avg_days_early_or_late,
    SUM(CASE WHEN shipped_date > required_date THEN 1 ELSE 0 END) AS num_late_orders,
    ROUND(SUM(CASE WHEN shipped_date > required_date THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS pct_late
FROM orders
WHERE order_status = 4 AND shipped_date IS NOT NULL;

-- B3. Fulfillment time by STORE (which store ships fastest / has the most late orders?)
SELECT
    o.store_id,
    st.store_name,
    COUNT(*) AS num_completed_orders,
    ROUND(AVG(DATEDIFF(o.shipped_date, o.order_date)), 2) AS avg_days_to_ship,
    ROUND(AVG(DATEDIFF(o.shipped_date, o.required_date)), 2) AS avg_days_early_or_late,
    SUM(CASE WHEN o.shipped_date > o.required_date THEN 1 ELSE 0 END) AS num_late_orders,
    ROUND(SUM(CASE WHEN o.shipped_date > o.required_date THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS pct_late
FROM orders o
JOIN stores st ON st.store_id = o.store_id
WHERE o.order_status = 4 AND o.shipped_date IS NOT NULL
GROUP BY o.store_id, st.store_name
ORDER BY pct_late DESC;

-- B4. Fulfillment time by STAFF member (who ships fastest / has the most late orders?)
SELECT
    s.staff_id,
    s.first_name,
    s.last_name,
    COUNT(*) AS num_completed_orders,
    ROUND(AVG(DATEDIFF(o.shipped_date, o.order_date)), 2) AS avg_days_to_ship,
    SUM(CASE WHEN o.shipped_date > o.required_date THEN 1 ELSE 0 END) AS num_late_orders,
    ROUND(SUM(CASE WHEN o.shipped_date > o.required_date THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS pct_late
FROM orders o
JOIN staffs s ON s.staff_id = o.staff_id
WHERE o.order_status = 4 AND o.shipped_date IS NOT NULL
GROUP BY s.staff_id, s.first_name, s.last_name
ORDER BY pct_late DESC;

-- B5. Fulfillment time distribution (bucketed) - how many orders ship same-day, next-day, 2-3 days, 4+ days?
SELECT
    CASE
        WHEN DATEDIFF(shipped_date, order_date) = 0 THEN '0. Same day'
        WHEN DATEDIFF(shipped_date, order_date) = 1 THEN '1. Next day'
        WHEN DATEDIFF(shipped_date, order_date) BETWEEN 2 AND 3 THEN '2. 2-3 days'
        ELSE '3. 4+ days'
    END AS fulfillment_bucket,
    COUNT(*) AS num_orders,
    ROUND(COUNT(*) * 100.0 / (
        SELECT COUNT(*) FROM orders WHERE order_status = 4 AND shipped_date IS NOT NULL
    ), 2) AS pct_of_completed_orders
FROM orders
WHERE order_status = 4 AND shipped_date IS NOT NULL
GROUP BY fulfillment_bucket
ORDER BY fulfillment_bucket;

-- B6. Monthly trend of average fulfillment time (is it getting better or worse over time?)
SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS order_month,
    COUNT(*) AS num_completed_orders,
    ROUND(AVG(DATEDIFF(shipped_date, order_date)), 2) AS avg_days_to_ship
FROM orders
WHERE order_status = 4 AND shipped_date IS NOT NULL
GROUP BY order_month
ORDER BY order_month;
