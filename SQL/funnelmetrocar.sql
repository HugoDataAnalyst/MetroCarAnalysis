--TODO LIST
-- verificar rides no funnelstep 4?!?
-- começar python para visualização

-- Perguntas do projecto:
-- What steps of the funnel should we research and improve? 
-- Are there any specific drop-off points preventing users from completing their first ride?
-- 1.
-- Metrocar currently supports 3 different platforms: ios, android, and web. 
-- To recommend where to focus our marketing budget for the upcoming year, what insights can we make based on the platform?
-- 2.
-- What age groups perform best at each stage of our funnel? Which age group(s) likely contain our target customers?
-- 3.
-- Surge pricing is the practice of increasing the price of goods or services when there is the greatest demand for them.
-- If we want to adopt a price-surging strategy, what does the distribution of ride requests look like throughout the day?
-- 4.
-- What part of our funnel has the lowest conversion rate? What can we do to improve this part of the funnel?

-- AVANÇADO:
-- usar os dados extraídos da charge_status/user_declines/driver_declines para fazer visualizações.
-- Criar gráficos dos driver_rating_distribution e dar merge dos csv no python para poder filtrar condutores maus e bons.



WITH user_ride_status AS (
  SELECT
    rr.user_id,
    s.age_range,
    ad.platform
  FROM ride_requests rr
  LEFT JOIN signups s ON rr.user_id = s.user_id
  LEFT JOIN app_downloads ad ON s.session_id = ad.app_download_key
  GROUP BY rr.user_id, s.age_range, ad.platform
),
ride_requested_status AS (
  SELECT
    DISTINCT (user_id),
    ride_id,
    dropoff_ts,
    cancel_ts
  FROM ride_requests
),
totals_signups AS (
  SELECT
    COUNT(DISTINCT s.user_id) AS total_users_signed_up,
    s.age_range,
    ad.platform
  FROM signups s
  LEFT JOIN app_downloads ad
  ON s.session_id = ad.app_download_key
  GROUP BY s.age_range, ad.platform
),
totals_rides_requested AS (
  SELECT
    COUNT(*) AS total_users_signed_up,
    COUNT(DISTINCT urs.user_id) AS total_users_ride_requested,
    s.age_range,
    urs.platform,
    COUNT(rrs.ride_id) AS rides,
    COUNT(rrs.cancel_ts) AS cancellations
  FROM signups s
  LEFT JOIN user_ride_status urs ON s.user_id = urs.user_id
  LEFT JOIN ride_requested_status rrs ON s.user_id = rrs.user_id
  GROUP BY s.age_range, urs.platform
),
totals_rides_completed AS (
 SELECT
    COUNT(DISTINCT rr.user_id) AS total_users_ride_completed,
    s.age_range,
    urs.platform,
    ROUND(SUM(
        CASE
            WHEN t.charge_status = 'Approved' THEN t.purchase_amount_usd::numeric
            ELSE 0
        END
    ),0) As total_usd,
    COUNT(DISTINCT r.review_id) AS total_reviews,
    COUNT(rr.ride_id) AS rides,
    COUNT(rr.cancel_ts) AS cancellations,
    AVG(r.rating) AS avg_rating
  FROM signups s
  LEFT JOIN ride_requests rr ON s.user_id = rr.user_id
  LEFT JOIN user_ride_status urs ON s.user_id = urs.user_id
  LEFT JOIN transactions t ON rr.ride_id = t.ride_id
  LEFT JOIN reviews r ON rr.ride_id = r.ride_id
  WHERE rr.dropoff_ts IS NOT NULL AND t.charge_status = 'Approved'
  GROUP BY s.age_range, urs.platform
),
totals_downloads AS (
  SELECT
    COUNT(DISTINCT app_download_key) AS total_downloads,
    platform,
    NULL AS age_range
  FROM app_downloads
  GROUP BY platform
UNION ALL
  SELECT
    NULL AS total_downloads,
    NULL AS platform,
    age_range
  FROM signups s
  LEFT JOIN app_downloads ad ON s.session_id = ad.app_download_key
),
reviews_per_user AS (
  SELECT
    r.user_id,
    COUNT(*) AS review_count
  FROM reviews r
  GROUP BY r.user_id
),
funnel_stages AS (
  SELECT
    1 AS funnel_step,
    'downloads' AS funnel_name,
    total_downloads AS value,
    NULL::numeric AS rides,
    NULL::numeric AS cancellations,
    age_range,
    platform,
    NULL::numeric AS total_usd,
    NULL::numeric AS total_reviews,
    NULL::numeric AS avg_rating
  FROM totals_downloads
  UNION
  SELECT
    2 AS funnel_step,
    'signups' AS funnel_name,
    total_users_signed_up AS value,
    NULL::numeric AS rides,
    NULL::numeric AS cancellations,
    age_range,
    platform,
    NULL::numeric AS total_usd,
    NULL::numeric AS total_reviews,
    NULL::numeric AS avg_rating
  FROM totals_signups
  UNION
  SELECT
    3 AS funnel_step,
    'rides_requested' AS funnel_name,
    total_users_ride_requested AS value,
    rides::numeric,
    cancellations,
    age_range,
    platform,
    NULL::numeric AS total_usd,
    NULL::numeric AS total_reviews,
    NULL::numeric AS avg_rating
  FROM totals_rides_requested
  UNION
  SELECT
    4 AS funnel_step,
    'rides_completed' AS funnel_name,
    total_users_ride_completed AS value,
    rides,
    cancellations,
    age_range,
    platform,
    total_usd::numeric,
    total_reviews::numeric,
    avg_rating::numeric
  FROM totals_rides_completed
),
test AS (
SELECT 
  funnel_step,
  funnel_name,
  value AS users,
  platform,
  age_range,
  total_usd,
  rides,
  cancellations,
  total_reviews,
  avg_rating,
  LAG(value) OVER (
    PARTITION BY age_range, platform
    ORDER BY funnel_step
  ) AS previous_users,
  value::float / LAG(NULLIF(value,0)) OVER (
    PARTITION BY age_range, platform
    ORDER BY funnel_step
  ) AS pct_previous_value,
  value::float / FIRST_VALUE(NULLIF(value,0)) OVER (
    PARTITION BY age_range, platform
    ORDER BY funnel_step
  ) AS pct_from_top
FROM funnel_stages
ORDER BY funnel_step, platform, age_range, users
)

SELECT * FROM test
--SELECT SUM(total_usd), SUM(total_reviews), SUM(CASE WHEN funnel_step = '4' THEN value ELSE 0  END  ) FROM test;


--156,211
-- surgepricingdata
SELECT EXTRACT(HOUR FROM request_ts) AS request_hour, COUNT(*) AS num_requests
FROM ride_requests
GROUP BY request_hour
ORDER BY request_hour;
