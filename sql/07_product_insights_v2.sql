-- =====================================================================
-- 07_product_insights.sql
-- Business questions:
--   A. Which products bring in the most revenue?
--   B. Which products attract lots of interest but rarely sell?
--      (these are the best candidates for fixing product pages or pricing)
-- Approach: product details sit inside the nested 'items' column, so we
--   UNNEST it to get one row per product per event.
-- Cleaning rules applied (from 03):
--   * Each order counted once: for repeated transaction IDs, only the
--     first purchase event is used.
--   * Purchases with no transaction ID are excluded from sales figures.
--   * Products named '(not set)' are excluded.
-- Note: product revenue may not exactly match order revenue in 04/06,
--   because order totals can include extras such as shipping or tax.
-- Output: list A = top 10 by revenue; list B = 10 products with at
--   least 1,000 viewers, at least 1 order, and the fewest orders per
--   100 viewers.
-- Why "at least 1 order"? Check 07b found 13 popular products with no
--   purchase records at all, under any name or item ID. That points to a
--   tracking or stock issue in the source data rather than real customer
--   behaviour, so those products are reported separately, not ranked here.
-- =====================================================================
 
WITH purchase_first_event AS (
  -- The first recorded event for each real order (removes duplicates)
  SELECT
    ecommerce.transaction_id AS transaction_id,
    MIN(event_timestamp)     AS first_ts
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name = 'purchase'
    AND ecommerce.transaction_id IS NOT NULL
    AND ecommerce.transaction_id != '(not set)'
  GROUP BY transaction_id
),
 
item_rows AS (
  -- UNNEST turns the list of products in each event into separate rows
  SELECT
    e.event_name,
    e.event_timestamp,
    e.user_pseudo_id,
    e.ecommerce.transaction_id AS transaction_id,
    item.item_name,
    item.item_category,
    item.quantity,
    item.item_revenue_in_usd
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` AS e,
    UNNEST(e.items) AS item
  WHERE e.event_name IN ('view_item', 'add_to_cart', 'purchase')
    AND item.item_name IS NOT NULL
    AND item.item_name != '(not set)'
),
 
views_and_carts AS (
  SELECT
    item_name,
    ANY_VALUE(item_category)                                          AS category,
    COUNT(DISTINCT IF(event_name = 'view_item',   user_pseudo_id, NULL)) AS viewers,
    COUNT(DISTINCT IF(event_name = 'add_to_cart', user_pseudo_id, NULL)) AS cart_adders
  FROM item_rows
  WHERE event_name IN ('view_item', 'add_to_cart')
  GROUP BY item_name
),
 
sales AS (
  -- Only the first event of each order is joined, so duplicates drop out
  SELECT
    r.item_name,
    COUNT(DISTINCT r.transaction_id) AS orders,
    SUM(r.quantity)                  AS units_sold,
    SUM(r.item_revenue_in_usd)       AS revenue
  FROM item_rows AS r
  JOIN purchase_first_event AS p
    ON  r.transaction_id  = p.transaction_id
    AND r.event_timestamp = p.first_ts
  WHERE r.event_name = 'purchase'
  GROUP BY r.item_name
),
 
product_stats AS (
  SELECT
    v.item_name,
    v.category,
    v.viewers,
    v.cart_adders,
    COALESCE(s.orders, 0)                                       AS orders,
    COALESCE(s.units_sold, 0)                                   AS units_sold,
    ROUND(COALESCE(s.revenue, 0), 0)                            AS revenue_usd,
    ROUND(100 * SAFE_DIVIDE(v.cart_adders, v.viewers), 1)       AS view_to_cart_pct,
    ROUND(100 * SAFE_DIVIDE(COALESCE(s.orders, 0), v.viewers), 1) AS orders_per_100_viewers
  FROM views_and_carts AS v
  LEFT JOIN sales AS s
    USING (item_name)
),
 
top_revenue AS (
  SELECT *, ROW_NUMBER() OVER (ORDER BY revenue_usd DESC) AS list_rank
  FROM product_stats
),
 
low_conversion AS (
  SELECT *, ROW_NUMBER() OVER (ORDER BY orders_per_100_viewers ASC, viewers DESC) AS list_rank
  FROM product_stats
  WHERE viewers >= 1000
    AND orders > 0   -- products with zero recorded sales are excluded (see check 07b)
)
 
SELECT 'A. Top revenue' AS list, list_rank, item_name, category, viewers, cart_adders,
       orders, units_sold, revenue_usd, view_to_cart_pct, orders_per_100_viewers
FROM top_revenue
WHERE list_rank <= 10
 
UNION ALL
 
SELECT 'B. Popular but rarely bought' AS list, list_rank, item_name, category, viewers, cart_adders,
       orders, units_sold, revenue_usd, view_to_cart_pct, orders_per_100_viewers
FROM low_conversion
WHERE list_rank <= 10
 
ORDER BY list, list_rank;
