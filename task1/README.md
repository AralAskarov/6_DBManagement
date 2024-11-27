

get_recommendations_by_device_id
```bash
CREATE FUNCTION public.get_recommendations_by_device_id(
    p_device_id UUID
)
RETURNS TABLE(
    device_id UUID,
    movie_id UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.device_id,
        m.movie_id
    FROM public.user_recommendation ur
    JOIN public."user" u
      ON u.iin = ur.iin
    JOIN public.movie m 
      ON m.movie_id = ur.movie_id
    WHERE u.device_id = p_device_id
      AND CURRENT_TIMESTAMP < upper(ur.period)
      AND NOT EXISTS (
          SELECT 1
          FROM public.reaction r
          WHERE r.device_id = p_device_id
            AND r.movie_id = ur.movie_id
      );
END;
$$ LANGUAGE plpgsql STABLE;
```


get_recommendations_by_user_id
```bash
CREATE OR REPLACE FUNCTION public.get_recommendations_by_user_id(
    p_user_id UUID
)
RETURNS TABLE(
    user_id UUID,
    movie_id UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.user_id,
        ur.movie_id
    FROM public.user_recommendation ur
    JOIN public."user" u 
    ON u.iin = ur.iin
    JOIN public.movie m 
    ON m.movie_id = ur.movie_id
    WHERE u.user_id = p_user_id
      AND CURRENT_TIMESTAMP < upper(ur.period)
      AND NOT EXISTS (
          SELECT 1
          FROM public.reaction r
          WHERE r.user_id = p_user_id
            AND r.movie_id = ur.movie_id
      );
END;
$$ LANGUAGE plpgsql STABLE;
```


testing methods
1) psycopg2
