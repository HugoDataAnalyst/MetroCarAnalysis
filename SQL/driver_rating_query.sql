-- Define a CTE 'driver_status' to gather information related to drivers, users, rides, reviews, and ratings
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
-- Define a CTE 'driver_rating_distribution' to calculate various statistics on driver ratings
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
-- Define a CTE 'unique_drivers_rating' to summarize driver ratings for unique drivers
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
/* 
   This code is intended to work with temporary tables and pagination, 
   but it's commented out due to permission limitations. 
   It describes the steps to obtain the driver rating distributin' data.
 
CREATE TEMP TABLE temp_driver_rating_distribution AS
SELECT * FROM driver_rating_distribution;
SELECT * FROM temp_driver_rating_distribution LIMIT 50000 OFFSET 0;
SELECT * FROM temp_driver_rating_distribution LIMIT 50000 OFFSET 50000;
SELECT * FROM temp_driver_rating_distribution LIMIT 50000 OFFSET 100000;
 */
-- Uncomment the next line to obtain the unique drivers rating
-- SELECT * FROM unique_drivers_rating;
-- Proceed to uncomment the next line and comment the previous one.
--SELECT * FROM driver_rating_distribution;

-- To obtain the dataset to download as CSV, run one by one.
-- SELECT * FROM driver_rating_distribution LIMIT 50000 OFFSET 0;
-- SELECT * FROM driver_rating_distribution LIMIT 50000 OFFSET 50000;
-- SELECT * FROM driver_rating_distribution LIMIT 50000 OFFSET 100000;
-- And now proceed to merge them in my case using Python