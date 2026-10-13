-- =====================================================================
-- 05_cohort_retention.sql
-- Business question: do new visitors come back in the weeks after
--                    their first visit?
-- Approach: group users into weekly "cohorts" by the week they first
--           appear, then measure what % of each cohort is active again
--           1, 2, 3 and 4 weeks later.
-- Notes:
--   * Weeks start on Sunday, so the data (which begins Sunday 1 Nov 2020)
--     splits into full weeks.
--   * Sunday 31 Jan 2021 is left out using _TABLE_SUFFIX, because it would
--     be a one-day "week" and make the last column look artificially low.
--   * A user's cohort is the first week they appear in THIS dataset.
--     Anyone who visited before November is treated as new (95% of users
--     have a first_visit event, so this affects few users).
--   * Empty cells (null) mean that week falls after the data ends.
-- =====================================================================

WITH user_weeks AS (
  -- One row per user per week they were active
  SELECT DISTINCT
    user_pseudo_id,
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(SUNDAY)) AS activity_week
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX <= '20210130'
),

cohorts AS (
  -- Each user's first active week = their cohort
  SELECT
    user_pseudo_id,
    MIN(activity_week) AS cohort_week
  FROM user_weeks
  GROUP BY user_pseudo_id
),

cohort_size AS (
  SELECT
    cohort_week,
    COUNT(*) AS cohort_users
  FROM cohorts
  GROUP BY cohort_week
),

cohort_activity AS (
  -- How many users from each cohort were active N weeks later
  SELECT
    c.cohort_week,
    DIV(DATE_DIFF(w.activity_week, c.cohort_week, DAY), 7) AS week_number,
    COUNT(DISTINCT w.user_pseudo_id)                       AS active_users
  FROM user_weeks AS w
  JOIN cohorts AS c
    USING (user_pseudo_id)
  GROUP BY c.cohort_week, week_number
)

SELECT
  s.cohort_week,
  s.cohort_users,
  MAX(IF(a.week_number = 1, ROUND(100 * a.active_users / s.cohort_users, 1), NULL)) AS week_1_pct,
  MAX(IF(a.week_number = 2, ROUND(100 * a.active_users / s.cohort_users, 1), NULL)) AS week_2_pct,
  MAX(IF(a.week_number = 3, ROUND(100 * a.active_users / s.cohort_users, 1), NULL)) AS week_3_pct,
  MAX(IF(a.week_number = 4, ROUND(100 * a.active_users / s.cohort_users, 1), NULL)) AS week_4_pct
FROM cohort_size AS s
LEFT JOIN cohort_activity AS a
  USING (cohort_week)
GROUP BY s.cohort_week, s.cohort_users
ORDER BY s.cohort_week;
