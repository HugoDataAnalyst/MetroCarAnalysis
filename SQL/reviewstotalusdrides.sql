WITH reviews AS (
    SELECT
        r.user_id,
        rr.ride_id,
        r.review_id,
        t.purchase_amount_usd AS usd,
        rr.cancel_ts,
        rr.dropoff_ts,
        t.charge_status,
        r.rating
    FROM reviews r
    LEFT JOIN ride_requests rr ON r.ride_id = rr.ride_id
    LEFT JOIN transactions t ON r.ride_id = t.ride_id
    ORDER BY review_id, charge_status DESC
),

withoutreviews AS (
    SELECT
        rr.ride_id
    FROM ride_requests rr
    LEFT JOIN reviews r ON rr.ride_id = r.ride_id
    WHERE r.ride_id IS NULL
),
test as (
SELECT
    rs.rating,
    COUNT(DISTINCT rs.user_id) AS users,
    COUNT(rs.ride_id) AS rides,
    COUNT(rs.review_id) AS reviews,
    SUM(rs.usd) AS total_usd
FROM reviews rs
GROUP BY rating

UNION ALL

SELECT
    NULL AS rating,
    COUNT(DISTINCT rr.user_id) AS users,
    COUNT(rr.ride_id) AS rides,
    NULL AS reviews,
    SUM(t.purchase_amount_usd) AS total_usd
FROM ride_requests rr
LEFT JOIN transactions t ON rr.ride_id = t.ride_id
WHERE rr.ride_id IN (SELECT ride_id FROM withoutreviews)
)
SELECT * FROM test;
--SELECT SUM(reviews), SUM(total_usd) FROm test;