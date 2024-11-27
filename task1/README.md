

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


task1=# EXPLAIN SELECT * 
FROM get_recommendations_by_device_id(
    (SELECT device_id 
     FROM public."user" 
     ORDER BY random() 
     LIMIT 1)
);
                                         QUERY PLAN                                          
---------------------------------------------------------------------------------------------
 Function Scan on get_recommendations_by_device_id  (cost=309.25..319.25 rows=1000 width=32)
   InitPlan 1 (returns $0)
     ->  Limit  (cost=309.00..309.00 rows=1 width=24)
           ->  Sort  (cost=309.00..334.00 rows=10000 width=24)
                 Sort Key: (random())
                 ->  Seq Scan on "user"  (cost=0.00..259.00 rows=10000 width=24)
(6 rows)



task1=# EXPLAIN SELECT * 
FROM get_recommendations_by_user_id(
    (SELECT user_id 
     FROM public."user" 
     ORDER BY random() 
     LIMIT 1)
);
                                        QUERY PLAN                                         
-------------------------------------------------------------------------------------------
 Function Scan on get_recommendations_by_user_id  (cost=309.25..319.25 rows=1000 width=32)
   InitPlan 1 (returns $0)
     ->  Limit  (cost=309.00..309.00 rows=1 width=24)
           ->  Sort  (cost=309.00..334.00 rows=10000 width=24)
                 Sort Key: (random())
                 ->  Seq Scan on "user"  (cost=0.00..259.00 rows=10000 width=24)
(6 rows)


### 1000 rps
```bash
pgbench -f device.sql -U postgres -d task1 -h localhost -p 5432 -c 50 -j 10 -T 60

transaction type: device.sql
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 10
duration: 60 s
number of transactions actually processed: 55149
latency average = 54.312 ms
initial connection time = 146.270 ms
tps = 920.614529 (without initial connection time)
```
latency average = 54.312 ms  - time of 1 transactions => average time for 1 query = 27,165
```bash
pgbench -f user.sql -U postgres -d task1 -h localhost -p 5432 -c 50 -j 10 -T 60


transaction type: user.sql
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 10
duration: 60 s
number of transactions actually processed: 55958
latency average = 53.533 ms
initial connection time = 152.614 ms
tps = 934.001147 (without initial connection time)


```
``` bash
pgbench -f device.sql -U postgres -d task1 -h localhost -p 5432 -c 500 -j 50 -T 60


transaction type: device.sql
scaling factor: 1
query mode: simple
number of clients: 500
number of threads: 50
duration: 60 s
number of transactions actually processed: 54603
latency average = 541.106 ms
initial connection time = 1458.647 ms
tps = 924.033913 (without initial connection time)

pgbench -f user.sql -U postgres -d task1 -h localhost -p 5432 -c 500 -j 50 -T 60

transaction type: user.sql
scaling factor: 1
query mode: simple
number of clients: 500
number of threads: 50
duration: 60 s
number of transactions actually processed: 55027
latency average = 536.395 ms
initial connection time = 1493.730 ms
tps = 932.148572 (without initial connection time)


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

task1=# EXPLAIN SELECT * 
FROM get_recommendations_by_device_id(
    (SELECT device_id 
     FROM public."user" 
     ORDER BY random() 
     LIMIT 1)
);
                                         QUERY PLAN                                          
---------------------------------------------------------------------------------------------
 Function Scan on get_recommendations_by_device_id  (cost=309.25..319.25 rows=1000 width=32)
   InitPlan 1 (returns $0)
     ->  Limit  (cost=309.00..309.00 rows=1 width=24)
           ->  Sort  (cost=309.00..334.00 rows=10000 width=24)
                 Sort Key: (random())
                 ->  Seq Scan on "user"  (cost=0.00..259.00 rows=10000 width=24)
(6 rows)


task1=# EXPLAIN SELECT * 
FROM get_recommendations_by_user_id(
    (SELECT user_id 
     FROM public."user" 
     ORDER BY random() 
     LIMIT 1)
);
                                        QUERY PLAN                                         
-------------------------------------------------------------------------------------------
 Function Scan on get_recommendations_by_user_id  (cost=309.25..319.25 rows=1000 width=32)
   InitPlan 1 (returns $0)
     ->  Limit  (cost=309.00..309.00 rows=1 width=24)
           ->  Sort  (cost=309.00..334.00 rows=10000 width=24)
                 Sort Key: (random())
                 ->  Seq Scan on "user"  (cost=0.00..259.00 rows=10000 width=24)
(6 rows)



# sdfffffffffffffffffffffffffffffffffffffffff
``` bash
pgbench -f device.sql -U postgres -d task1 -h localhost -p 5432 -c 50 -j 10 -T 60

transaction type: device.sql
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 10
duration: 60 s
number of transactions actually processed: 327318
latency average = 9.147 ms
initial connection time = 142.937 ms
tps = 5466.143188 (without initial connection time)


pgbench -f user.sql -U postgres -d task1 -h localhost -p 5432 -c 50 -j 10 -T 60

transaction type: user.sql
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 10
duration: 60 s
number of transactions actually processed: 335841
latency average = 8.912 ms
initial connection time = 154.176 ms
tps = 5610.321531 (without initial connection time)


pgbench -f device.sql -U postgres -d task1 -h localhost -p 5432 -c 500 -j 50 -T 60

transaction type: device.sql
scaling factor: 1
query mode: simple
number of clients: 500
number of threads: 50
duration: 60 s
number of transactions actually processed: 308171
latency average = 95.307 ms
initial connection time = 1478.829 ms
tps = 5246.215981 (without initial connection time)


pgbench -f user.sql -U postgres -d task1 -h localhost -p 5432 -c 500 -j 50 -T 60

transaction type: user.sql
scaling factor: 1
query mode: simple
number of clients: 500
number of threads: 50
duration: 60 s
number of transactions actually processed: 312227
latency average = 93.906 ms
initial connection time = 1535.589 ms
tps = 5324.492235 (without initial connection time)


```
rps = ~ 11000

### 3) conf changes
shared_buffers = 4GB
work_mem = 64MB
maintenance_work_mem = 512MB
max_parallel_workers_per_gather = 4
parallel_setup_cost = 1000
parallel_tuple_cost = 0.1
max_worker_processes = 8
max_parallel_workers = 8
max_connections = 600
wal_buffers = 16MB
checkpoint_completion_target = 0.9
synchronous_commit = off
fsync = off

```bash
pgbench -f device.sql -U postgres -d task1 -h localhost -p 5432 -c 50 -j 10 -T 60

transaction type: device.sql
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 10
duration: 60 s
number of transactions actually processed: 340727
latency average = 8.786 ms
initial connection time = 141.993 ms
tps = 5690.660786 (without initial connection time)
```
```bash
pgbench -f device.sql -U postgres -d task1 -h localhost -p 5432 -c 500 -j 50 -T 60
transaction type: device.sql
scaling factor: 1
query mode: simple
number of clients: 500
number of threads: 50
duration: 60 s
number of transactions actually processed: 316429
latency average = 92.675 ms
initial connection time = 1465.605 ms
tps = 5395.212086 (without initial connection time)

```

```bash
pgbench -f user.sql -U postgres -d task1 -h localhost -p 5432 -c 50 -j 10 -T 60

transaction type: user.sql
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 10
duration: 60 s
number of transactions actually processed: 335129
latency average = 8.932 ms
initial connection time = 147.908 ms
tps = 5597.852348 (without initial connection time)
```
```bash
pgbench -f user.sql -U postgres -d task1 -h localhost -p 5432 -c 500 -j 50 -T 60
transaction type: user.sql
scaling factor: 1
query mode: simple
number of clients: 500
number of threads: 50
duration: 60 s
number of transactions actually processed: 309520
latency average = 94.722 ms
initial connection time = 1541.091 ms
tps = 5278.577022 (without initial connection time)

```

4) Pgbouncer
pgbench -f device.sql -U postgres -d task1 -h 127.0.0.1 -p 6432 -c 50 -j 10 -T 60
transaction type: device.sql
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 10
duration: 60 s
number of transactions actually processed: 343225
latency average = 8.742 ms
initial connection time = 3.195 ms
tps = 5719.785012 (without initial connection time)

pgbench -f user.sql -U postgres -d task1 -h 127.0.0.1 -p 6432 -c 50 -j 10 -T 60
transaction type: user.sql
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 10
duration: 60 s
number of transactions actually processed: 342087
latency average = 8.771 ms
initial connection time = 3.330 ms
tps = 5700.866611 (without initial connection time)
