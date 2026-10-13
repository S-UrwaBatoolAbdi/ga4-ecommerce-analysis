-- =====================================================================
-- 06_customer_segmentation.sql
-- Business question: who are the most valuable customers, and how much
--                    of the revenue depends on them?
-- Approach: build one row per buyer (orders, total spend, last order),
--           then split buyers into 4 segments using two questions:
--             1. Did they order more than once?  (repeat vs one-time)
--             2. Is their total spend in the top 25%?  (high vs standard)
-- Why not a full RFM model? Retention is very low (see 05), so most
--   buyers ordered only once. A full RFM score would put nearly everyone
--   in the same group, so a simpler 4-segment split is more useful here.
-- Cleaning rules applied (from 03): one row per order, and purchases
--   with no transaction ID are excluded (no reliable revenue).
-- =====================================================================

WITH clean_orders AS (
  SELECT
    ecommerce.transaction_id                                              AS transaction_id,
    ARRAY_AGG(user_pseudo_id ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS user_pseudo_id,
    MIN(PARSE_DATE('%Y%m%d', event_date))                                 AS order_date,
    MAX(ecommerce.purchase_revenue_in_usd)                                AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name = 'purchase'
    AND ecommerce.transaction_id IS NOT NULL
    AND ecommerce.transaction_id != '(not set)'
  GROUP BY transaction_id
),

buyers AS (
  -- One row per buyer
  SELECT
    user_pseudo_id,
    COUNT(*)        AS orders,
    SUM(revenue)    AS total_spend,
    MAX(order_date) AS last_order_date
  FROM clean_orders
  GROUP BY user_pseudo_id
),

threshold AS (
  -- Spend level that marks the top 25% of buyers
  SELECT APPROX_QUANTILES(total_spend, 4)[OFFSET(3)] AS high_value_cutoff
  FROM buyers
),

segmented AS (
  SELECT
    b.*,
    t.high_value_cutoff,
    CASE
      WHEN b.orders >= 2 AND b.total_spend >= t.high_value_cutoff THEN '1. Repeat, high value'
      WHEN b.orders >= 2                                          THEN '2. Repeat, standard value'
      WHEN b.total_spend >= t.high_value_cutoff                   THEN '3. One-time, high value'
      ELSE                                                             '4. One-time, standard value'
    END AS segment
  FROM buyers AS b
  CROSS JOIN threshold AS t
)

SELECT
  segment,
  COUNT(*)                                                       AS buyers,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)               AS pct_of_buyers,
  ROUND(SUM(total_spend), 0)                                     AS revenue_usd,
  ROUND(100 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 1) AS pct_of_revenue,
  ROUND(AVG(total_spend), 2)                                     AS avg_spend_per_buyer,
  ROUND(AVG(orders), 2)                                          AS avg_orders,
  ROUND(AVG(DATE_DIFF(DATE '2021-01-31', last_order_date, DAY)), 0) AS avg_days_since_last_order,
  ROUND(ANY_VALUE(high_value_cutoff), 2)                         AS high_value_cutoff_usd
FROM segmented
GROUP BY segment
ORDER BY segment;
