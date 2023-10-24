
WITH driver_status AS (
SELECT
	rr.driver_id,
  rr.user_id,
  rr.ride_id,
  rr.dropoff_ts,
  rr.cancel_ts,
  s.age_range,
  ad.platform,
  r.review_id,
  r.rating
FROM ride_requests rr
LEFT JOIN signups s ON rr.user_id = s.user_id
LEFT JOIN app_downloads ad ON s.session_id = ad.app_download_key
LEFT JOIN reviews r ON rr.ride_id = r.ride_id
),
driver_rating_distribution AS (
SELECT
	DISTINCT driver_id,
  COUNT(DISTINCT user_id) AS users,
  COUNT(DISTINCT ride_id) AS rides,
  COUNT(dropoff_ts) AS rides_completed,
  COUNT(cancel_ts) AS rides_canceled,
  age_range,
  platform,
  COUNT(review_id) AS reviews,
  ROUND(AVG(rating::numeric),2) AS avg_rating
FROM driver_status
GROUP BY driver_id, age_range, platform
ORDER BY driver_id, age_range, platform
),
unique_drivers_rating AS (
SELECT
	DISTINCT driver_id,
  SUM(rides::numeric) AS total_rides,
  SUM(users::numeric) AS total_users,
  SUM(rides_completed::numeric) AS rides_completed,
  SUM(rides_canceled::numeric) AS rides_canceled,
  SUM(reviews::numeric) AS reviews,
  ROUND(AVG(avg_rating),2) AS avg_ratings
FROM driver_rating_distribution
GROUP BY driver_id
ORDER BY driver_id
)
-- This would work if I had the proper permissions
--CREATE TEMP TABLE temp_driver_rating_distribution AS
--SELECT * FROM driver_rating_distribution;
--SELECT * FROM temp_driver_rating_distribution LIMIT 50000 OFFSET 0;
--SELECT * FROM temp_driver_rating_distribution LIMIT 50000 OFFSET 50000;
--SELECT * FROM temp_driver_rating_distribution LIMIT 50000 OFFSET 100000;
--SELECT * FROM unique_drivers_rating;
-- Since I don't, I most run the queries below one at a time and commenting them out one by one
SELECT * FROM driver_rating_distribution LIMIT 50000 OFFSET 0;
SELECT * FROM driver_rating_distribution LIMIT 50000 OFFSET 50000;
SELECT * FROM driver_rating_distribution LIMIT 50000 OFFSET 100000;
-- And now proceed to merge them in my case using Python