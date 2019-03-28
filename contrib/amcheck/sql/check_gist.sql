-- minimal test, basically just verifying that amcheck works with GiST
SELECT setseed(1);
CREATE TABLE gist_check AS SELECT point(random(),s) c FROM generate_series(1,10000) s;
INSERT INTO gist_check SELECT point(random(),s) c FROM generate_series(1,100000) s;
CREATE INDEX gist_check_idx ON gist_check USING gist(c);
SELECT gist_index_parent_check('gist_check_idx');
