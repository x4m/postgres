CREATE EXTENSION pg_background;

--run 5 workers which wait about 1 second
CREATE TABLE input as SELECT x FROM generate_series(1,5,1) x ORDER BY x DESC;
CREATE TABLE output(place int,value int);
CREATE sequence s start 1;
CREATE TABLE handles as SELECT pg_background_launch('select pg_sleep('||x||'); insert into output values (nextval(''s''),'||x||');') h FROM input;
SELECT (SELECT * FROM pg_background_result(h) as (x text) limit 1) FROM handles;
SELECT * FROM output ORDER BY place;
