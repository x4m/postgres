\timing
SET client_min_messages = 'DEBUG5';
SET log_min_messages = 'DEBUG5';
SET wal_level = 'minimal';

create extension if not exists cube;

begin transaction;
SELECT setseed(.43);


create table dataTable(c cube);
create index idx on dataTable using gist(c);

insert into dataTable(c) select cube(array[random(),random(),random()]) from generate_series(1,1e2,1) x,generate_series(1,1e2,1) y,generate_series(1,3e3,1) z;


/*create table queries(id int,l1 float,l2 float,l3 float, u1 float,u2 float, u3 float, q cube);
insert into queries(id,l1,l2,l3) select s,random()/1.3,random()/1.3,random()/1.3 from generate_series(1,1e4,1) s;
update queries set q = cube(array[l1,l2,l3],array[l1+0.01001,l2+0.10001,l3+0.10001]);

select id,(select count(*) from dataTable dt where dt.c<@q) from queries order by id;*/

rollback;
--drop index idx;
--drop table dataTable;
--drop table queries;
