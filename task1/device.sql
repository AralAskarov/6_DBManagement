SELECT * 
FROM get_recommendations_by_device_id(
    (SELECT device_id 
     FROM public."user" 
     ORDER BY random() 
     LIMIT 1)
);

