CREATE EXTENSION test_multixact;

--
-- All the logic is in the test_multixact() function. It will throw
-- an error if something fails.
--
SELECT test_multixact();
