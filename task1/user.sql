SELECT * 
FROM get_recommendations_by_user_id(
    (SELECT user_id 
     FROM public."user" 
     ORDER BY random() 
     LIMIT 1)
);
