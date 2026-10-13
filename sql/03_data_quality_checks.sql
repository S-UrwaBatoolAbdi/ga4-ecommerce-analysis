-- =====================================================================
-- 03_data_quality_checks.sql
-- Goal: check the data is reliable before going deeper into analysis.
-- Each check answers one question. Run each query in its own tab.
-- =====================================================================


-- 03a. Are there duplicate events or missing user IDs?
--      If unique_events is lower than total_rows, some events appear twice.
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT CONCAT(user_pseudo_id, '|', CAST(event_timestamp AS STRING), '|', event_name)) AS unique_events,
  COUNTIF(user_pseudo_id IS NULL) AS missing_user_id
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`;


-- 03b. Are purchases recorded properly?
--      Checks for repeated or missing transaction IDs and missing/zero revenue.
SELECT
  COUNT(*)                                       AS purchase_events,
  COUNT(DISTINCT ecommerce.transaction_id)       AS distinct_transaction_ids,
  COUNTIF(ecommerce.transaction_id IS NULL
          OR ecommerce.transaction_id = '(not set)') AS missing_transaction_id,
  COUNTIF(ecommerce.purchase_revenue_in_usd IS NULL) AS missing_revenue,
  COUNTIF(ecommerce.purchase_revenue_in_usd = 0)     AS zero_revenue
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE event_name = 'purchase';


-- 03c. How clean are the traffic source values?
--      Looks for placeholders like '<Other>', '(data deleted)' and '(not set)'
--      before we use these fields for channel analysis.
SELECT
  traffic_source.source          AS source,
  traffic_source.medium          AS medium,
  COUNT(DISTINCT user_pseudo_id) AS users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY source, medium
ORDER BY users DESC;


-- 03d. Do the funnel steps behave as expected?
--      Explains two oddities from the funnel: checkout and shipping had almost
--      identical user counts, and we want to know if anyone purchased
--      without ever viewing a product.
WITH user_steps AS (
  SELECT
    user_pseudo_id,
    MAX(IF(event_name = 'view_item',         1, 0)) AS did_view,
    MAX(IF(event_name = 'begin_checkout',    1, 0)) AS did_checkout,
    MAX(IF(event_name = 'add_shipping_info', 1, 0)) AS did_shipping,
    MAX(IF(event_name = 'purchase',          1, 0)) AS did_purchase
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name IN ('view_item', 'begin_checkout', 'add_shipping_info', 'purchase')
  GROUP BY user_pseudo_id
)
SELECT
  COUNTIF(did_checkout = 1 AND did_shipping = 0) AS checkout_without_shipping,
  COUNTIF(did_shipping = 1 AND did_checkout = 0) AS shipping_without_checkout,
  COUNTIF(did_purchase = 1 AND did_view = 0)     AS purchase_without_view
FROM user_steps;

-- 03e. Follow-up to 03b: how many purchases are duplicates,
--      and where do the zero-revenue purchases sit?
WITH purchases AS (
  SELECT
    ecommerce.transaction_id         AS transaction_id,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name = 'purchase'
),
 
repeated AS (
  SELECT
    transaction_id,
    COUNT(*) AS times_recorded
  FROM purchases
  WHERE transaction_id IS NOT NULL
    AND transaction_id != '(not set)'
  GROUP BY transaction_id
  HAVING COUNT(*) > 1
)
 
SELECT
  (SELECT COUNT(*) FROM repeated)                AS ids_recorded_more_than_once,
  (SELECT SUM(times_recorded - 1) FROM repeated) AS extra_duplicate_events,
  (SELECT COUNTIF(revenue = 0) FROM purchases
     WHERE transaction_id IS NULL OR transaction_id = '(not set)')       AS zero_revenue_missing_id,
  (SELECT COUNTIF(revenue = 0) FROM purchases
     WHERE transaction_id IS NOT NULL AND transaction_id != '(not set)') AS zero_revenue_valid_id;
 
