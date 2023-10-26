-- Define a common table expression (CTE) 'charge_decline' to gather data related to charge declines
WITH charge_decline AS (
SELECT
	r.user_id,
	rr.ride_id,
	r.review_id,
  rr.driver_id,
	t.purchase_amount_usd,
	rr.cancel_ts,
	rr.dropoff_ts,
	t.charge_status
FROM ride_requests rr
LEFT JOIN reviews r ON rr.ride_id = r.ride_id
LEFT JOIN transactions t ON rr.ride_id = t.ride_id
ORDER BY user_id, review_id, charge_status DESC
),
-- Define a CTE 'charge_statistics' to calculate statistics on charge status
charge_statistics AS (
SELECT 
	charge_status,
  COUNT(DISTINCT user_id) AS users,
  COUNT(DISTINCT driver_id) AS drivers,
  COUNT(ride_id) AS rides,
  COUNT(review_id) AS reviews,
  ROUND(SUM(purchase_amount_usd::numeric),2) AS total_usd
FROM charge_decline
WHERE charge_status IS NOT NULL
GROUP BY charge_status
)
-- Select the result from the 'charge_statistics' CTE
SELECT * FROM charge_statistics;

-- Define a CTE 'user_declines' to analyze charge declines at the user level
WITH user_declines AS (
SELECT 
    rr.user_id,
    COUNT(DISTINCT rr.driver_id) AS unique_drivers,
    COUNT(DISTINCT rr.ride_id) AS unique_rides,
    SUM(CASE WHEN t.charge_status = 'Decline' THEN 1 ELSE 0 END) AS decline_count,
    ROUND(AVG(CASE WHEN t.charge_status = 'Decline' THEN r.rating ELSE NULL END),2) AS avg_rating,
    SUM(CASE WHEN t.charge_status = 'Decline' THEN t.purchase_amount_usd ELSE 0 END) AS lost_total_usd,
  	SUM(CASE WHEN t.charge_status = 'Approved' THEN t.purchase_amount_usd ELSE 0 END) as gained_total_usd
FROM ride_requests rr 
LEFT JOIN transactions t 
    ON rr.ride_id = t.ride_id 
LEFT JOIN reviews r 
    ON rr.ride_id = r.ride_id
GROUP BY rr.user_id
HAVING SUM(CASE WHEN t.charge_status = 'Decline' THEN 1 ELSE 0 END) > 1
ORDER BY decline_count DESC
)
-- Select the result from the 'user_declines' CTE
SELECT * FROM user_declines;

-- Define a CTE 'driver_declines' to analyze charge declines at the driver level
WITH driver_declines AS (
SELECT 
    rr.driver_id,
    COUNT(DISTINCT rr.user_id) AS unique_users,
    COUNT(DISTINCT rr.ride_id) AS unique_rides,
    SUM(CASE WHEN t.charge_status = 'Decline' THEN 1 ELSE 0 END) AS decline_count,
    ROUND(AVG(CASE WHEN t.charge_status = 'Decline' THEN r.rating ELSE NULL END),2) AS avg_rating,
    SUM(CASE WHEN t.charge_status = 'Decline' THEN t.purchase_amount_usd ELSE 0 END) AS lost_total_usd,
  	SUM(CASE WHEN t.charge_status = 'Approved' THEN t.purchase_amount_usd ELSE 0 END) as gained_total_usd  
FROM ride_requests rr 
LEFT JOIN transactions t 
    ON rr.ride_id = t.ride_id 
LEFT JOIN reviews r 
    ON rr.ride_id = r.ride_id
GROUP BY rr.driver_id
HAVING SUM(CASE WHEN t.charge_status = 'Decline' THEN 1 ELSE 0 END) > 1
ORDER BY decline_count DESC
)
-- Select the result from the 'driver_declines' CTE
SELECT * FROM driver_declines;

