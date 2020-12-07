-- test creating table with compression method
CREATE TABLE cmdata(f1 text COMPRESSION pglz);
CREATE INDEX idx ON cmdata(f1);
INSERT INTO cmdata VALUES(repeat('1234567890',1000));
\d+ cmdata

CREATE TABLE cmdata1(f1 TEXT COMPRESSION lz4);
INSERT INTO cmdata1 VALUES(repeat('1234567890',1004));
\d+ cmdata1

-- try setting compression for incompressible data type
CREATE TABLE cmdata2 (f1 int COMPRESSION pglz);

-- verify stored compression method
SELECT pg_column_compression(f1) FROM cmdata;
SELECT pg_column_compression(f1) FROM cmdata1;

-- decompress data slice
SELECT SUBSTR(f1, 200, 5) FROM cmdata;
SELECT SUBSTR(f1, 2000, 50) FROM cmdata1;

-- copy with table creation
SELECT * INTO cmmove1 FROM cmdata;
SELECT pg_column_compression(f1) FROM cmmove1;

-- update using datum from different table
CREATE TABLE cmmove2(f1 text COMPRESSION pglz);
INSERT INTO cmmove2 VALUES (repeat('1234567890',1004));
SELECT pg_column_compression(f1) FROM cmmove2;

UPDATE cmmove2 SET f1 = cmdata.f1 FROM cmdata;
SELECT pg_column_compression(f1) FROM cmmove2;
UPDATE cmmove2 SET f1 = cmdata1.f1 FROM cmdata1;
SELECT pg_column_compression(f1) FROM cmmove2;

-- copy to existing table
CREATE TABLE cmmove3(f1 text COMPRESSION pglz);
INSERT INTO cmmove3 SELECT * FROM cmdata;
INSERT INTO cmmove3 SELECT * FROM cmdata1;
SELECT pg_column_compression(f1) FROM cmmove2;



-- test LIKE INCLUDING COMPRESSION
CREATE TABLE cmdata2 (LIKE cmdata1 INCLUDING COMPRESSION);
\d+ cmdata2

-- test compression with materialized view
CREATE MATERIALIZED VIEW mv(x) AS SELECT * FROM cmdata1;
\d+ mv
SELECT pg_column_compression(f1) FROM cmdata1;
SELECT pg_column_compression(x) FROM mv;

-- test compression with partition
CREATE TABLE cmpart(f1 text COMPRESSION lz4) PARTITION BY HASH(f1);
CREATE TABLE cmpart1 PARTITION OF cmpart FOR VALUES WITH (MODULUS 2, REMAINDER 0);
CREATE TABLE cmpart2(f1 text COMPRESSION pglz);

ALTER TABLE cmpart ATTACH PARTITION cmpart2 FOR VALUES WITH (MODULUS 2, REMAINDER 1);
INSERT INTO cmpart VALUES (repeat('123456789',1004));
INSERT INTO cmpart VALUES (repeat('123456789',4004));
SELECT pg_column_compression(f1) FROM cmpart;

-- test compression with inheritence, error
CREATE TABLE cminh() INHERITS(cmdata, cmdata1);
CREATE TABLE cminh(f1 TEXT COMPRESSION lz4) INHERITS(cmdata);

-- test alter compression method with rewrite
ALTER TABLE cmdata ALTER COLUMN f1 SET COMPRESSION lz4;
\d+ cmdata
SELECT pg_column_compression(f1) FROM cmdata;

-- test alter compression method for the materialized view
ALTER TABLE cmdata1 ALTER COLUMN f1 SET COMPRESSION pglz;
ALTER MATERIALIZED VIEW mv ALTER COLUMN x SET COMPRESSION lz4;
REFRESH MATERIALIZED VIEW mv;
\d+ mv
SELECT pg_column_compression(f1) FROM cmdata1;
SELECT pg_column_compression(x) FROM mv;

-- test alter compression method for the partioned table
ALTER TABLE cmpart ALTER COLUMN f1 SET COMPRESSION pglz;
SELECT pg_column_compression(f1) FROM cmpart;

ALTER TABLE cmpart1 ALTER COLUMN f1 SET COMPRESSION pglz;
ALTER TABLE cmpart2 ALTER COLUMN f1 SET COMPRESSION lz4;
SELECT pg_column_compression(f1) FROM cmpart;

-- preserve old compression method
ALTER TABLE cmdata ALTER COLUMN f1 SET COMPRESSION pglz PRESERVE (lz4);
INSERT INTO cmdata VALUES (repeat('1234567890',1004));
\d+ cmdata
SELECT pg_column_compression(f1) FROM cmdata;
\d+ cmdata
ALTER TABLE cmdata ALTER COLUMN f1 SET COMPRESSION lz4 PRESERVE ALL;
SELECT pg_column_compression(f1) FROM cmdata;

-- create compression method
CREATE ACCESS METHOD pglz2 TYPE COMPRESSION HANDLER pglzhandler;
ALTER TABLE cmdata ALTER COLUMN f1 SET COMPRESSION pglz2 PRESERVE ALL;
INSERT INTO cmdata VALUES (repeat('1234567890',1004));
\d+ cmdata
SELECT pg_column_compression(f1) FROM cmdata;
ALTER TABLE cmdata ALTER COLUMN f1 SET COMPRESSION lz4 PRESERVE (pglz2);
SELECT pg_column_compression(f1) FROM cmdata;
\d+ cmdata

-- check data is ok
SELECT length(f1) FROM cmdata;
SELECT length(f1) FROM cmdata1;
SELECT length(f1) FROM cmmove1;
SELECT length(f1) FROM cmmove2;
SELECT length(f1) FROM cmmove3;

DROP MATERIALIZED VIEW mv;
DROP TABLE cmdata, cmdata1, cmmove1, cmmove2, cmmove3, cmpart;
DROP ACCESS METHOD pglz2;
