

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
## to measure the performance i will use explain and pgbench

scripts for testin

for device id
``` bash
SELECT * 
FROM get_recommendations_by_device_id(
    (SELECT device_id 
     FROM public."user" 
     ORDER BY random() 
     LIMIT 1)
);
```

for user id
``` bash
SELECT * 
FROM get_recommendations_by_user_id(
    (SELECT user_id 
     FROM public."user" 
     ORDER BY random() 
     LIMIT 1)
);
```

### 1. without any optimization


devops_sila=# EXPLAIN SELECT * 
devops_sila-# FROM get_recommendations_by_device_id(
devops_sila(#     (SELECT device_id 
devops_sila(#      FROM public."user" 
devops_sila(#      ORDER BY random() 
devops_sila(#      LIMIT 1)
devops_sila(# );
                                         QUERY PLAN                                          
---------------------------------------------------------------------------------------------
 Function Scan on get_recommendations_by_device_id  (cost=309.25..319.25 rows=1000 width=32)
   InitPlan 1
     ->  Limit  (cost=309.00..309.00 rows=1 width=24)
           ->  Sort  (cost=309.00..334.00 rows=10000 width=24)
                 Sort Key: (random())
                 ->  Seq Scan on "user"  (cost=0.00..259.00 rows=10000 width=24)
(6 rows)


devops_sila=# EXPLAIN SELECT * 
devops_sila-# FROM get_recommendations_by_user_id(
devops_sila(#     (SELECT user_id 
devops_sila(#      FROM public."user" 
devops_sila(#      ORDER BY random() 
devops_sila(#      LIMIT 1)
devops_sila(# );
                                        QUERY PLAN                                         
-------------------------------------------------------------------------------------------
 Function Scan on get_recommendations_by_user_id  (cost=309.25..319.25 rows=1000 width=32)
   InitPlan 1
     ->  Limit  (cost=309.00..309.00 rows=1 width=24)
           ->  Sort  (cost=309.00..334.00 rows=10000 width=24)
                 Sort Key: (random())
                 ->  Seq Scan on "user"  (cost=0.00..259.00 rows=10000 width=24)
(6 rows)

### 1000 rps
```bash
pgbench -f device.sql -U kbtu_admin -d devops_sila -h localhost -p 5434 -c 50 -j 10 -T 60

transaction type: device.sql
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 10
duration: 60 s
number of transactions actually processed: 59092
latency average = 50.689 ms
initial connection time = 140.930 ms
tps = 986.400915 (without initial connection time)
```
latency average = 50.689 ms  - time of 1 transactions => average time for 1 query = 25,34
```bash
pgbench -f user.sql -U kbtu_admin -d devops_sila -h localhost -p 5434 -c 50 -j 10 -T 60

transaction type: user.sql
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 10
duration: 60 s
number of transactions actually processed: 60983
latency average = 49.143 ms
initial connection time = 114.984 ms
tps = 1017.433494 (without initial connection time)

```
``` bash
pgbench -f device.sql -U kbtu_admin -d devops_sila -h localhost -p 5434 -c 500 -j 50 -T 60

transaction type: device.sql
scaling factor: 1
query mode: simple
number of clients: 500
number of threads: 50
duration: 60 s
number of transactions actually processed: 55519
latency average = 534.855 ms
initial connection time = 1166.281 ms
tps = 934.832183 (without initial connection time)

pgbench -f user.sql -U kbtu_admin -d devops_sila -h localhost -p 5434 -c 500 -j 50 -T 60

transaction type: user.sql
scaling factor: 1
query mode: simple
number of clients: 500
number of threads: 50
duration: 60 s
number of transactions actually processed: 60113
latency average = 491.804 ms
initial connection time = 1345.446 ms
tps = 1016.664758 (without initial connection time)

```


### 2 index
``` bash
CREATE INDEX idx_user_recommendation_iin_movie_period 
ON public.user_recommendation (iin, movie_id, period);
CREATE INDEX idx_reaction_device_movie 
ON public.reaction (device_id, movie_id);
CREATE INDEX idx_reaction_user_movie 
ON public.reaction (user_id, movie_id);
CREATE INDEX idx_user_device_id 
ON public."user" (device_id);
CREATE INDEX idx_user_user_id 
ON public."user" (user_id);
CREATE INDEX idx_movie_movie_id 
ON public.movie (movie_id);
```
