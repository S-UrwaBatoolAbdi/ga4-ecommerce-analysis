-- =====================================================================
-- 02_conversion_funnel.sql  (revised after data quality checks)
-- Business question: where do users drop off on the way to a purchase?
-- Approach: count unique users reaching each e-commerce step, then
--           compare each step with the first step and the previous step.
-- Change after check 03d: 'begin_checkout' and 'add_shipping_info' fire
--           together (only 3 users differed), so they are treated as ONE
--           step. The funnel now has 5 steps instead of 6.
-- Note: this is a user-level funnel (did the user ever do this step?),
--       not a strict step-by-step sequence.
-- =====================================================================

WITH funnel_events AS (
  SELECT
    user_pseudo_id,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name IN (
    'view_item',
    'add_to_cart',
    'begin_checkout',
    'add_payment_info',
    'purchase'
  )
),

step_counts AS (
  SELECT
    CASE event_name
      WHEN 'view_item'        THEN 1
      WHEN 'add_to_cart'      THEN 2
      WHEN 'begin_checkout'   THEN 3
      WHEN 'add_payment_info' THEN 4
      WHEN 'purchase'         THEN 5
    END                            AS step_order,
    event_name                     AS step,
    COUNT(DISTINCT user_pseudo_id) AS users
  FROM funnel_events
  GROUP BY event_name
)

SELECT
  step_order,
  step,
  users,
  -- % of product viewers who reached this step
  ROUND(100 * users / FIRST_VALUE(users) OVER (ORDER BY step_order), 1) AS pct_of_viewers,
  -- % of the previous step who made it to this step
  ROUND(100 * users / LAG(users) OVER (ORDER BY step_order), 1)         AS pct_from_previous_step
FROM step_counts
ORDER BY step_order;
