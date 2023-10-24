--TODO LIST
-- verificar rides no funnelstep 4
-- recriar isto mas retirar os pct_value/top e adicionar daily_date
-- começar python para visualização
-- verificar ratings com drivers para poder fazer sugestão de remoção de condutores com < x rating
-- extrair os dados do charge_status
WITH user_ride_status AS (
  SELECT
    rr.user_id,
    ad.platform
  FROM ride_requests rr
  LEFT JOIN signups s ON rr.user_id = s.user_id
  LEFT JOIN app_downloads ad ON s.session_id = ad.app_download_key
  GROUP BY rr.user_id, ad.platform
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
    ad.platform
  FROM signups s
  LEFT JOIN app_downloads ad
  ON s.session_id = ad.app_download_key
  GROUP BY ad.platform
),
totals_rides_requested AS (
  SELECT
    COUNT(*) AS total_users_signed_up,
    COUNT(DISTINCT urs.user_id) AS total_users_ride_requested,
    urs.platform,
    COUNT(rrs.ride_id) AS rides,
    COUNT(rrs.cancel_ts) AS cancellations
  FROM signups s
  LEFT JOIN user_ride_status urs ON s.user_id = urs.user_id
  LEFT JOIN ride_requested_status rrs ON s.user_id = rrs.user_id
  GROUP BY urs.platform
),
totals_rides_completed AS (
 SELECT
    COUNT(DISTINCT rr.user_id) AS total_users_ride_completed,
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
  GROUP BY urs.platform
),
totals_downloads AS (
  SELECT
    COUNT(DISTINCT app_download_key) AS total_downloads,
    platform
  FROM app_downloads
  GROUP BY platform
UNION ALL
  SELECT
    NULL AS total_downloads,
    NULL AS platform
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
  total_usd,
  rides,
  cancellations,
  total_reviews,
  avg_rating,
  LAG(value) OVER (
    PARTITION BY platform
    ORDER BY funnel_step
  ) AS previous_users,
  value::float / LAG(NULLIF(value,0)) OVER (
    PARTITION BY platform
    ORDER BY funnel_step
  ) AS pct_previous_value,
  value::float / FIRST_VALUE(NULLIF(value,0)) OVER (
    PARTITION BY platform
    ORDER BY funnel_step
  ) AS pct_from_top
FROM funnel_stages
ORDER BY funnel_step, platform, users
),
test2 AS (
--SELECT * FROM test
SELECT 
SUM(CASE WHEN funnel_step = '1' THEN users ELSE 0 END) AS funnel_1,
SUM(CASE WHEN funnel_step = '2' THEN users ELSE 0 END) AS funnel_2,
SUM(CASE WHEN funnel_step = '3' THEN users ELSE 0 END) AS funnel_3,
SUM(CASE WHEN funnel_step = '4' THEN users ELSE 0 END) AS funnel_4
FROM test
)
SELECT * FROM test;
--SELECT 	ROUND(funnel_1/funnel_1,2) AS funnel_1_ratio,   ROUND(funnel_2/funnel_1,2) AS funnel_2_ratio,   ROUND(funnel_3/funnel_1,2) AS funnel_3_ratio,   ROUND(funnel_4/funnel_1,2) AS funnel_4_ratio FROM test2 GROUP BY funnel_1,funnel_2,funnel_3, funnel_4


















