-- =====================================================================
-- 04_channel_performance.sql
-- Business question: which marketing channels bring buyers and revenue,
--                    not just visitors?
-- Cleaning rules applied (from 03_data_quality_checks.sql):
--   * Channels are grouped by MEDIUM, because the source is often hidden
--     as '<Other>' or '(data deleted)'. Anything unclear goes to 'Unknown'.
--   * The store referring to itself (self-referral) is labelled 'Internal'.
--   * Each order is counted once (335 duplicate purchase events removed).
--   * Purchases with no transaction ID count towards buyers, but are left
--     out of orders and revenue (all 450 zero-revenue purchases were in
--     this group).
--   * Each user is given the channel from their first recorded event.
-- =====================================================================

WITH events AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    event_name,
    ecommerce.transaction_id          AS transaction_id,
    ecommerce.purchase_revenue_in_usd AS revenue,
    CASE
      WHEN traffic_source.source LIKE '%googlemerchandisestore%' THEN 'Internal (self-referral)'
      WHEN traffic_source.medium = 'organic'  THEN 'Organic Search'
      WHEN traffic_source.medium = 'cpc'      THEN 'Paid Search'
      WHEN traffic_source.medium = '(none)'   THEN 'Direct'
      WHEN traffic_source.medium = 'referral' THEN 'Referral'
      ELSE 'Unknown'
    END AS channel
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),

-- One row per user: their channel, and whether they viewed or bought
user_summary AS (
  SELECT
    user_pseudo_id,
    ARRAY_AGG(channel ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS channel,
    MAX(IF(event_name = 'view_item', 1, 0)) AS viewed_product,
    MAX(IF(event_name = 'purchase',  1, 0)) AS purchased
  FROM events
  GROUP BY user_pseudo_id
),

-- One row per real order (duplicates and missing IDs removed)
clean_orders AS (
  SELECT
    transaction_id,
    ARRAY_AGG(user_pseudo_id ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS user_pseudo_id,
    MAX(revenue) AS revenue
  FROM events
  WHERE event_name = 'purchase'
    AND transaction_id IS NOT NULL
    AND transaction_id != '(not set)'
  GROUP BY transaction_id
),

orders_per_user AS (
  SELECT
    user_pseudo_id,
    COUNT(*)     AS orders,
    SUM(revenue) AS revenue
  FROM clean_orders
  GROUP BY user_pseudo_id
)

SELECT
  u.channel,
  COUNT(*)                                                AS users,
  SUM(u.viewed_product)                                   AS product_viewers,
  SUM(u.purchased)                                        AS buyers,
  ROUND(100 * SUM(u.purchased) / COUNT(*), 2)             AS conversion_rate_pct,
  COALESCE(SUM(o.orders), 0)                              AS orders,
  ROUND(COALESCE(SUM(o.revenue), 0), 0)                   AS revenue_usd,
  ROUND(SAFE_DIVIDE(SUM(o.revenue), SUM(o.orders)), 2)    AS avg_order_value_usd,
  ROUND(100 * COALESCE(SUM(o.revenue), 0)
            / SUM(SUM(o.revenue)) OVER (), 1)             AS pct_of_total_revenue
FROM user_summary AS u
LEFT JOIN orders_per_user AS o
  USING (user_pseudo_id)
GROUP BY u.channel
ORDER BY revenue_usd DESC;
