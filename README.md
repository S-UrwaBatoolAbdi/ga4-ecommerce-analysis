# Google Merchandise Store: GA4 E-commerce Analysis (SQL / BigQuery)

An end-to-end SQL analysis of real GA4 tracking data from Google's online merchandise store. I explored the data, checked its quality, fixed the issues I found, and then analysed the conversion funnel, marketing channels, customer retention, customer value and product performance.

**Tools:** Google BigQuery (GoogleSQL), VS Code, GitHub
**Skills shown:** CTEs, window functions (`ROW_NUMBER`, `LAG`, `FIRST_VALUE`), `UNNEST` on nested data, conditional aggregation, data quality checks, cohort analysis, customer segmentation

---

## Key findings

- **Most shoppers leave at the product page.** Only 20.5% of people who viewed a product added it to their cart. Inside checkout, the biggest drop is at payment, where 41% abandon.
- **Channels convert at almost the same rate (1.5–1.8%).** Revenue share mostly follows traffic volume. Organic Search brings 38% of users and 35% of revenue. Paid Search buyers spend the most per order ($75.87 vs $66.48 for Organic).
- **Almost no one comes back.** Only 2.5–6.6% of new visitors return the following week. December brought the most visitors but the weakest retention.
- **A quarter of buyers drive most of the revenue.** The top 25% of buyers (spending $97+) generate 60% of revenue. Repeat high-value buyers are 7.8% of buyers but 21.9% of revenue.
- **Winter clothing sells; tees and small accessories don't.** 9 of the top 10 revenue products are hoodies, sweatshirts, fleeces or jackets. 13 popular products, mostly T-shirts, had thousands of cart adds but no recorded sales at all.

## Recommendations

1. **Investigate the 13 zero-sale products.** They had high demand but no recorded orders. Check whether they were out of stock or missing from purchase tracking: either it's lost revenue, or the reported figures are understated.
2. **Turn one-time high spenders into repeat buyers.** 656 buyers spent an average of $179 on a single order. A follow-up offer or loyalty incentive targets the group most likely to become top customers.
3. **Capture holiday visitors for later.** December visitors rarely returned. Email sign-up offers during peak season, plus remarketing in January, could recover some of them.
4. **Review the payment step.** Losing 41% of shoppers after they've entered shipping details suggests surprise delivery costs or payment friction.
5. **Give the Canteen Bottle more visibility.** It converts 3–4 times better than most products (5.3 orders per 100 viewers) and is often bought in pairs, but it gets relatively few views.
6. **Fix tracking.** Add the store's own domain to GA4's referral exclusion list, and record transaction IDs on every purchase.

---

## Dataset

- **Source:** [GA4 obfuscated sample e-commerce dataset](https://developers.google.com/analytics/bigquery/web-ecommerce-demo-dataset) (`bigquery-public-data.ga4_obfuscated_sample_ecommerce`), BigQuery public data
- **Business:** Google Merchandise Store, which sells Google-branded clothing and accessories
- **Period:** 1 November 2020 – 31 January 2021
- **Size:** 4,295,584 events from 270,154 users
- **Note:** Google obfuscates some values for privacy, so absolute figures don't match the store's real totals. Patterns and proportions are still meaningful.

## Project structure

| File | What it does |
|---|---|
| `sql/01_data_exploration.sql` | Date range, event types, daily activity |
| `sql/02_conversion_funnel_v1.sql` | First funnel (6 steps), kept for comparison |
| `sql/02_conversion_funnel_v2.sql` | Revised funnel (5 steps) after quality checks |
| `sql/03_data_quality_checks.sql` | Duplicates, purchase records, traffic sources, funnel logic |
| `sql/04_channel_performance.sql` | Users, buyers, orders and revenue by channel |
| `sql/05_cohort_retention.sql` | Weekly cohort retention |
| `sql/06_customer_segmentation.sql` | Buyer segments by repeat purchase and spend |
| `sql/07_product_insights.sql` | Top products, low converters, zero-sales check |
| `results/` | Full query results as CSV files, one per query |

---

## Data quality: what I checked and how I handled it

Before the main analysis, I ran checks to make sure the results could be trusted.

| Check | Finding | Decision |
|---|---|---|
| Duplicate events | None. All 4,295,584 rows are unique | No action needed |
| Missing transaction IDs | 906 purchase events (16%) had none. All 450 zero-revenue purchases were in this group | Counted for conversion, excluded from orders and revenue |
| Duplicate orders | 335 extra purchase events across 326 orders | Each order counted once |
| Traffic source placeholders | ~28% `<Other>`, ~5% `(data deleted)` | Grouped channels by medium; the rest labelled "Unknown" |
| Self-referral | The store's own domain appeared as a referrer | Labelled "Internal", not a real referral partner |
| Funnel logic | `begin_checkout` and `add_shipping_info` fire together (only 3 users differed) | Merged into one funnel step |
| Purchases without a product view | 26 buyers (<1%) | Kept, noted as a tracking gap |
| Products with no sales | 13 products with 1,000+ viewers had no purchases under any name or item ID | Reported separately, not ranked |

**Validation:** After cleaning, the numbers agree across queries. Channel users add up to the 270,154 total, and both the channel and segmentation analyses arrive at the same **4,451 orders** and **$308,200 revenue**.

Full results: [03a](results/03a_duplicate_check.csv) · [03b](results/03b_purchase_records.csv) · [03c](results/03c_traffic_sources.csv) · [03d](results/03d_funnel_sanity_check.csv) · [03e](results/03e_duplicate_orders.csv) · [07b](results/07b_zero_orders_check.csv)

---

## Analysis

### 1. Conversion funnel
*Where do users drop off on the way to a purchase?*

| Step | Users | % of viewers | % from previous step |
|---|---|---|---|
| Viewed product | 61,252 | 100% | – |
| Added to cart | 12,545 | 20.5% | 20.5% |
| Began checkout | 9,715 | 15.9% | 77.4% |
| Added payment info | 5,751 | 9.4% | 59.2% |
| Purchased | 4,419 | 7.2% | 76.8% |

Only about 23% of all visitors ever viewed a product, and around 1.6% of all visitors bought something.

Full results: [funnel v2](results/02_conversion_funnel_v2.csv) · [funnel v1 (before cleaning)](results/02_conversion_funnel_v1.csv)

### 2. Daily trend
- Weekends are consistently quieter for both visitors and purchases.
- Purchases rose around Black Friday week and Cyber Monday (141 purchases on 30 November), but the real peak came on 9–11 December (143–160 purchases a day).
- Purchases fell sharply after 19 December, likely due to the Christmas shipping cutoff.

Full results: [01c_daily_trend.csv](results/01c_daily_trend.csv) (all 92 days)

### 3. Channel performance
*Which channels bring buyers and revenue, not just visitors?*

| Channel | Users | Conversion | Revenue | % of revenue | Avg order value |
|---|---|---|---|---|---|
| Organic Search | 101,742 | 1.53% | $107,231 | 34.8% | $66.48 |
| Direct | 64,109 | 1.58% | $71,767 | 23.3% | $70.57 |
| Unknown | 50,001 | 1.78% | $64,201 | 20.8% | $71.10 |
| Referral | 25,257 | 1.64% | $26,683 | 8.7% | $68.07 |
| Internal (self-referral) | 14,763 | 2.24% | $22,764 | 7.4% | $70.92 |
| Paid Search | 14,282 | 1.53% | $15,554 | 5.0% | $75.87 |

- Conversion rates are close across channels, so differences in revenue come mainly from traffic volume.
- Paid Search has the highest order value, but without ad spend data its profitability can't be judged.
- "Unknown" accounts for 21% of revenue, a blind spot caused by obfuscation.
- Internal self-referral shows the highest conversion, but it's misleading: these users were already shopping, so the credit belongs to their original channel.

Full results: [04_channel_performance.csv](results/04_channel_performance.csv)

### 4. Cohort retention
*Do new visitors come back?*

- Week 1 retention ranged from 2.5% to 6.6%, and by week 4 most cohorts were below 1%.
- Early November visitors were the most loyal (6%+ in week 1). Their return weeks fell during the Black Friday and December peak, which suggests early holiday browsers coming back to buy.
- December cohorts were the largest (28,069 users in the week of 6 December) but had the weakest retention (2.5–3.5%), consistent with one-off gift shopping.

Full results: [05_cohort_retention.csv](results/05_cohort_retention.csv)

### 5. Customer segmentation
*Who are the most valuable customers?*

Buyers were split by two questions: did they order more than once, and is their total spend in the top 25% ($97+)?

| Segment | Buyers | % of buyers | Revenue | % of revenue | Avg spend |
|---|---|---|---|---|---|
| Repeat, high value | 287 | 7.8% | $67,351 | 21.9% | $234.67 |
| Repeat, standard value | 152 | 4.1% | $9,259 | 3.0% | $60.91 |
| One-time, high value | 656 | 17.7% | $117,360 | 38.1% | $178.90 |
| One-time, standard value | 2,607 | 70.4% | $114,230 | 37.1% | $43.82 |

- Of the 439 repeat buyers, 65% ended up in the high-value group, so a second purchase is closely linked to becoming a valuable customer.
- **Why not RFM?** Retention is so low that most buyers ordered once, and recency barely differed between segments (43–49 days). A full RFM model would put nearly everyone in the same group, so I used a simpler split that fits the data better.
- **Reproducibility fix:** The first version used `APPROX_QUANTILES` for the top-25% cutoff. It is an estimate, so it gave slightly different cutoffs on different runs ($98, then $97). I replaced it with `PERCENTILE_CONT`, which is exact and gives the same result every time.

Full results: [06_customer_segmentation.csv](results/06_customer_segmentation.csv)

### 6. Product insights
*Which products sell, and which attract interest but don't?*

**Top revenue:** Google Zip Hoodie F/C ($10,488), Crewneck Sweatshirt Navy ($9,878) and Badge Heavyweight Pullover ($8,444) lead. Super G Unisex Joggers had the most orders (220).

**Popular but rarely bought:** Products such as the YouTube Women's Favorite Tee, Google Tee Green and Android Small Trace Journal were added to carts at normal rates (19–29%, similar to top sellers) but produced only 0.0–0.2 orders per 100 viewers, compared with 0.8–5.3 for top sellers. Since people do add them to carts, the problem appears to come after the cart rather than on the product page. Many are low-priced items such as tees, stickers and notepads, so delivery costs relative to price may play a part. This is a hypothesis worth testing, not a confirmed cause.

**Zero recorded sales:** 13 products with 1,000+ viewers had no purchases under any name or item ID (see Data quality).

Full results: [07_product_insights.csv](results/07_product_insights.csv)

---

## Limitations

- **Obfuscated data:** Some values are hidden, and absolute totals don't reflect the store's real figures.
- **Device-based users:** `user_pseudo_id` identifies a browser or device, so someone returning on another device counts as a new user. Retention is likely understated.
- **Short time window:** Three months over the holiday season, so patterns may not represent the rest of the year.
- **No cost data:** Channel profitability and return on ad spend can't be calculated.
- **First-touch channel:** Each user is credited to the channel from their first recorded visit.
- **Funnel method:** The funnel counts whether a user ever reached each step, not whether they completed the steps in strict order.

## How to run

1. Create a free Google Cloud project and open BigQuery (the sandbox needs no card).
2. The dataset is public, so no download is needed. Open any file in `sql/` and run it in the BigQuery console.
3. Each file starts with comments explaining the business question and approach.
4. To check the results without running anything, open the matching CSV in `results/`.

---

**Author:** Syeda Urwa Batool Abdi · MSc Marketing & Digital Analytics,
[LinkedIn](www.linkedin.com/in/syedaurwabatool) · [Email](s.urwabatoolabdi@gmail.com)
