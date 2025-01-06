WITH first_activity AS (
    SELECT DATE_FORMAT(MIN(start_time), '%H:%i:00') as first_time
    FROM user_app_usage_1
    WHERE DATE(start_time) = '2024-04-01'
),
time_intervals AS (
    SELECT 
        DATE_FORMAT(time_slot, '%H:%i') AS interval_start,
        DATE_FORMAT(DATE_ADD(time_slot, INTERVAL 5 MINUTE), '%H:%i') AS interval_end
    FROM (
        SELECT 
            DATE_ADD((SELECT CONCAT('2024-04-01 ', first_time) FROM first_activity), 
                    INTERVAL (a.a + (10 * b.a) + (100 * c.a)) * 5 MINUTE) as time_slot
        FROM (SELECT 0 as a UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) as a
        CROSS JOIN (SELECT 0 as a UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) as b
        CROSS JOIN (SELECT 0 as a UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) as c
    ) times
    WHERE DATE(time_slot) = '2024-04-01'
),
usage_by_interval AS (
    SELECT 
        ti.interval_start,
        ti.interval_end,
        COALESCE(u.app_name, 'No Activity') as app_name,
        COALESCE(u.productivity_level, 1) as productivity_level,
        GREATEST(
            LEAST(
                TIMESTAMPDIFF(SECOND, 
                    GREATEST(u.start_time, CONCAT('2024-04-01 ', ti.interval_start)), 
                    LEAST(u.end_time, CONCAT('2024-04-01 ', ti.interval_end))
                ),
                300
            ),
            0
        ) as duration_seconds
    FROM time_intervals ti
    LEFT JOIN user_app_usage_1 u ON 
        u.usage_date = '2024-04-01' AND  
        u.start_time < CONCAT('2024-04-01 ', ti.interval_end) AND 
        u.end_time > CONCAT('2024-04-01 ', ti.interval_start)
    GROUP BY ti.interval_start, ti.interval_end, u.app_name, u.productivity_level
)
SELECT 
    interval_start,
    interval_end,
    GROUP_CONCAT(
        DISTINCT CONCAT(app_name, ' (', duration_seconds, ')')
        ORDER BY duration_seconds DESC
        SEPARATOR ', '
    ) AS apps_used,
    ROUND(
        SUM(CASE WHEN productivity_level = 2 THEN duration_seconds ELSE 0 END) /
        NULLIF(SUM(duration_seconds), 0) * 100,
        2
    ) AS productive_percentage,
    ROUND(
        SUM(CASE WHEN productivity_level = 0 THEN duration_seconds ELSE 0 END) /
        NULLIF(SUM(duration_seconds), 0) * 100,
        2
    ) AS unproductive_percentage
FROM usage_by_interval
GROUP BY interval_start, interval_end
ORDER BY interval_start;