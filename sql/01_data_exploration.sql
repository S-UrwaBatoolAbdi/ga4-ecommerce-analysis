-- =====================================================================
-- 01_data_exploration.sql
-- Goal: understand the shape of the GA4 dataset before any analysis.
-- Dataset: Google Merchandise Store, GA4 obfuscated sample (BigQuery public data)
-- =====================================================================


-- 1. Date range, total events and total users
--    The data is split into one table per day (events_YYYYMMDD),
--    so the * wildcard queries all days at once.
SELECT
  MIN(PARSE_DATE('%Y%m%d', event_date)) AS first_day,
  MAX(PARSE_DATE('%Y%m%d', event_date)) AS last_day,
  COUNT(*)                              AS total_events,
  COUNT(DISTINCT user_pseudo_id)        AS total_users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`;


-- 2. Which events are tracked, and how often?
--    This tells us which funnel steps we can actually measure.
SELECT
  event_name,
  COUNT(*)                       AS events,
  COUNT(DISTINCT user_pseudo_id) AS users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY event_name
ORDER BY events DESC;


-- 3. Daily activity trend (useful later for spotting seasonality, e.g. Black Friday)
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS day,
  COUNT(DISTINCT user_pseudo_id)   AS daily_users,
  COUNTIF(event_name = 'purchase') AS purchases
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY day
ORDER BY day;
