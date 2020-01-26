----- Problem 1
----- Point a

----- Create database

CREATE DATABASE "IMDB" 
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8';

----- connect to IMDB
\c IMDB

----- from IMBD bulkload script
----- Note: to ingest the tsv files skipping the first line I used the Linux/mac command "tail"
DROP TABLE IF EXISTS NameBasics;
CREATE TABLE NameBasics (
	nid char(10),
	primaryName varchar(105),
	birthYear int,
    deathYear int,
    primaryProfession varchar(66),
    knownForTitles varchar(200));
COPY NameBasics FROM  PROGRAM 'tail -n +2 /tmp/name.basics.tsv' NULL '\N' ENCODING 'UTF8';
-- COPY 9808836

DROP TABLE IF EXISTS TitleBasics;
CREATE TABLE TitleBasics (
	tid char(10),
	ttype varchar(12),
	primaryTitle varchar(408),
	originalTitle varchar(408),
	isAdult int,
	startYear int,
	endYear int,
	runtimeMinutes int,
	genres varchar(200));
COPY TitleBasics FROM PROGRAM 'tail -n +2 /tmp/title.basics.tsv' NULL '\N' ENCODING 'UTF8';
-- COPY 6460644

DROP TABLE IF EXISTS TitlePrincipals;
CREATE TABLE TitlePrincipals (
	tid char(10),
	ordering int,
	nid char(10),
	category varchar(19),
	job varchar(286),
	characters varchar(463));
COPY TitlePrincipals FROM PROGRAM ' tail -n +2 /tmp/title.principals.tsv' NULL '\N' ENCODING 'UTF8';
--COPY 37343384

DROP TABLE IF EXISTS TitleRatings;
CREATE TABLE TitleRatings (
        tid char(10),
        avg_rating numeric,
        num_votes numeric);
COPY TitleRatings FROM PROGRAM 'tail -n +2 /tmp/title.ratings.tsv' NULL '\N' ENCODING 'UTF8';
--COPY 1012651

----- Point b

CREATE TABLE Movie (
	tid char(10),--TitleBasics.tid
	primaryTitle varchar(408),--TitleBasics.primaryTitle
	originalTitle varchar(408),--TitleBasics.originalTitle
	startYear int,--TitleBasics.startYear
	endYear int,--TitleBasics.endYear
	runtime int,--TitleBasics.runtimeMinutes
	avgRating numeric --TitleRatings.avg_rating
	);

CREATE TABLE Director ( --for insert join with TitlePrincipals where category=director
	nid        char(10), --NameBasics.nid
	name       varchar(105),--NameBasics.primaryName
	birthYear  int,--NameBasics.birthYear
    deathYear  int --NameBasics.deathYear
	);

CREATE TABLE Actor ( --for insert join with TitlePrincipals where category='act%'
	nid        char(10), --NameBasics.nid
	name       varchar(105),--NameBasics.primaryName
	birthYear  int,--NameBasics.birthYear
    deathYear  int --NameBasics.deathYear
	);

CREATE TABLE Directs ( --for insert join with TitlePrincipals where category=director
	tid char(10), --TitleBasics.tid
	nid char(10) --NameBasics.nid
    );

CREATE TABLE Starsin ( --for insert join with TitlePrincipals where category='act%'
	tid char(10), --TitleBasics.tid
	nid char(10) --NameBasics.nid
    );


----- Point c

INSERT INTO Movie(
	tid, 
	primaryTitle, 
	originalTitle, 
	startYear, 
	endYear,
	runtime, 
	avgRating)
SELECT  DISTINCT 
		tid, 
		primaryTitle, 
		originalTitle, 
		startYear, 
		endYear, 
		runtimeMinutes, 
		avg_rating
FROM TitleBasics JOIN TitleRatings USING (tid)
WHERE TitleBasics.ttype='movie' AND
TitleRatings.num_votes >= 5000
ORDER BY avg_rating DESC
LIMIT 5000;

INSERT INTO Director(
		nid,
		name,
		birthYear,
		deathYear)
SELECT DISTINCT  
		nid, 
		primaryName, 
		birthYear, 
		deathYear
FROM NameBasics JOIN TitlePrincipals USING (nid)
WHERE category = 'director'
AND tid IN (
	SELECT  tid
	FROM movie 
	);

--INSERT 0 2514


INSERT INTO Actor(
		nid,
		name,
		birthYear,
		deathYear)
SELECT DISTINCT  
		nid, 
		primaryName, 
		birthYear, 
		deathYear
FROM NameBasics JOIN TitlePrincipals USING (nid)
WHERE category LIKE 'act%'
AND tid IN (
	SELECT  tid
	FROM movie 
	);
--INSERT 0 10234



INSERT INTO Directs (
		tid,
		nid )
SELECT  tid, nid
FROM NameBasics JOIN TitlePrincipals USING (nid)
WHERE category = 'director'
AND tid IN (
	SELECT  tid
	FROM movie 
	);

--INSERT 0 5229

INSERT INTO starsIn (
		tid,
		nid )
SELECT  tid, nid
FROM NameBasics JOIN TitlePrincipals USING (nid)
WHERE category LIKE 'act%'
AND tid IN (
	SELECT  tid
	FROM movie 
	);

--INSERT 0 19180


----- Problem 2

----- Point a

ALTER TABLE Movie ADD PRIMARY KEY (tid);

ALTER TABLE Director ADD PRIMARY KEY (nid);

ALTER TABLE Actor ADD PRIMARY KEY (nid);

ALTER TABLE directs ADD PRIMARY KEY (tid, nid);

ALTER TABLE starsin ADD PRIMARY KEY (tid, nid);

ALTER TABLE directs 
ADD CONSTRAINT "director_name" FOREIGN KEY (nid) 
REFERENCES director (nid)
ON UPDATE CASCADE
ON DELETE CASCADE;

ALTER TABLE directs 
ADD CONSTRAINT "film_name" FOREIGN KEY (tid) 
REFERENCES movie (tid)
ON UPDATE CASCADE
ON DELETE CASCADE;

ALTER TABLE starsIn
ADD CONSTRAINT "actor_name" FOREIGN KEY (nid) 
REFERENCES actor (nid)
ON UPDATE CASCADE
ON DELETE CASCADE;

ALTER TABLE starsIn 
ADD CONSTRAINT "film_name" FOREIGN KEY (tid) 
REFERENCES movie (tid)
ON UPDATE CASCADE
ON DELETE CASCADE;

----- Point b

----- Check number of movie directed by nid of Ridley Scott:
SELECT  *
from directs
WHERE nid IN
	(SELECT nid
	 FROM director
	 WHERE name LIKE 'Ridley Scott%'
	);

-- (13 rows)

----- change the nid

UPDATE director
SET nid = 123456789
WHERE nid = (
	SELECT nid
	FROM director
	WHERE name LIKE 'Ridley Scott'
	);

---- repeat the first query
SELECT  *
from directs
WHERE nid IN
	(SELECT nid
	 FROM director
	 WHERE name LIKE 'Ridley Scott'
	);
----- same result with new nid: result 13

----- Point c
----- Check n. of movie whit Sigourney Weaver

SELECT *
from starsIn
WHERE nid = (
	SELECT nid 
	FROM actor
	WHERE name LIKE 'Sigourney Weaver'
	);

----- (14 rows)

----- delete Sigourney
DELETE 
FROM actor
WHERE name LIKE 'Sigourney Weaver';

---- repeat the first query

SELECT *
from starsIn
WHERE nid = (
	SELECT nid 
	FROM actor
	WHERE name LIKE 'Sigourney Weaver'
	);
---tid | nid 
   -----+-----
   (0 rows)

----- point d

----- try to insert in directs table a nid that is not in director table (123456799) for an existing film tid: (tt0078748)

INSERT INTO directs (tid, nid)
VALUES ('tt0078748' , '123456799');

ERROR:  insert or update on table "directs" violates foreign key constraint "director_name"
DETAIL:  Key (nid)=(123456799 ) is not present in table "director".


----- Problem 3
----- point a

SELECT *
FROM movie
ORDER BY avgRating DESC
LIMIT 20; 

----- point b
SELECT name, birthYear, deathYear, COUNT(tid) AS num_movies
FROM actor
JOIN starsIn USING (nid)
	GROUP BY nid
	ORDER BY num_movies DESC
	LIMIT 20;

----- point c. As discussed in class endYear is "null" for every movie.

SELECT DISTINCT primaryTitle, startYear, endYear, (endYear - startYear) AS production_duration
FROM movie JOIN directs USING (tid)
WHERE nid IN (
	SELECT nid 
	FROM director 
	WHERE deathYear IS NULL
)
ORDER BY (endYear - startYear) DESC
LIMIT 20;

----- point d
SELECT name,  MAX(startYear) AS recent, MIN(startYear) AS older
FROM directs JOIN movie USING (tid)
JOIN director USING (nid)
GROUP BY name
ORDER BY MAX(startYear) - MIN(startYear) DESC
LIMIT 20;


----- point e
SELECT actor.name AS actor_name, 
		director.name AS director_name, 
		COUNT (*) AS num_movies_tog
FROM starsIn at JOIN movie USING (tid) JOIN actor ON (at.nid = actor.nid)
JOIN directs bt USING (tid)	JOIN director ON (bt.nid = director.nid)
WHERE at.tid = bt.tid 
GROUP BY actor.name, director.name
ORDER BY COUNT(*) DESC
LIMIT 20;


----- point f 
SELECT DISTINCT d.name FROM
        (
        SELECT  director.nid,director.name, max(movie.avgRating) AS dir_rat
        FROM directs
        JOIN movie USING (tid) JOIN director USING (nid)
        GROUP BY director.nid,director.name
        )d
 JOIN
        (
        SELECT actor.nid, actor.name,
                   MAX(movie.avgRating) AS max_act_rating
        FROM starsin
        JOIN movie USING (tid) JOIN actor USING (nid)
        GROUP BY primaryTitle, startYear, actor.name,actor.nid
        )a
 ON d.nid=a.nid
 WHERE d.dir_rat<a.max_act_rating
 ORDER BY name;

----- point g
SELECT * FROM (
	SELECT 	runtime,primaryTitle,startYear,
		COUNT (*) over() AS total,
		COUNT (*) over(ORDER by runtime, startYear, primaryTitle) AS ordered
	FROM movie
	WHERE runtime IS NOT NULL
	) foo
WHERE ceiling((foo.total +0.1)/2)=foo.ordered ;

----- point h
SELECT name FROM actor WHERE nid IN 
(
SELECT nid
FROM StarsIn WHERE tid IN
(SELECT tid FROM movie WHERE primaryTitle LIKE 'Star Trek%' AND startYear BETWEEN 1982 AND 1991)   
  EXCEPT   
SELECT C.nid   
FROM (SELECT A.nid, B.tid 
FROM StarsIn A, Movie B WHERE B.primaryTitle LIKE 'Star Trek%' AND startYear BETWEEN 1982 AND 1991         
       EXCEPT         
      SELECT nid, tid FROM StarsIn) C
	);

---version 2:
SELECT actor.name
FROM actor JOIN starsIn USING (nid) JOIN movie USING (tid)
WHERE primaryTitle LIKE 'Star Trek%' 
AND startYear BETWEEN 1982 AND 1991
GROUP BY actor.name
HAVING COUNT(*) IN (
	SELECT COUNT (DISTINCT primaryTitle)
	FROM movie 
	WHERE primaryTitle LIKE 'Star Trek%'
	AND startYear BETWEEN 1982 AND 1991);

----- point i
SELECT DISTINCT 
		(SELECT name FROM actor WHERE nid = S1.nid),
		(SELECT name FROM actor WHERE nid = S2.nid)
FROM StarsIn S1, StarsIn S2 	             			        
WHERE S1.nid < S2.nid AND NOT exists (
    (SELECT tid FROM StarsIn WHERE nid=S1.nid
     EXCEPT ALL 
     SELECT tid FROM StarsIn WHERE nid=S2.nid)
    UNION ALL 
    (SELECT tid FROM StarsIn WHERE nid=S2.nid
     EXCEPT ALL 
     SELECT tid FROM StarsIn WHERE nid=S1.nid)
);


----- Problem 4

----- Point a
CREATE OR REPLACE FUNCTION checkActorYear()
	RETURNS trigger AS $$
	DECLARE
	actor_name VARCHAR=NEW.name;
	birthYear INT =NEW.birthYear;
	old_birthYear INT;
	BEGIN
		SELECT actor.birthYear INTO old_birthYear FROM actor WHERE actor.name=actor_name;
		IF old_birthYear<>birthYear THEN
			RAISE EXCEPTION 'Different birthYear for the same actor %', actor_name  USING ERRCODE = 'unique_violation';
		END if;
		RETURN NEW;
	END;
$$ LANGUAGE plpgsql; 


CREATE TRIGGER actor_birthYear
	BEFORE INSERT ON public.actor
	FOR EACH ROW
	EXECUTE PROCEDURE public.checkActorYear('name', 'birthYear');

----- Point b
INSERT INTO actor VALUES ('0123456777', 'Fred Astaire', 1905, 1987 );
ERROR:  Different birthYear for the same actor Fred Astaire
CONTEXT:  PL/pgSQL function checkactoryear() line 9 at RAISE

INSERT INTO actor VALUES ('0123456677', 'Alvaro Vitali', 1950 );
INSERT 0 1

----- Point c
CREATE OR REPLACE FUNCTION deleteActor()
	RETURNS trigger AS $$
	DECLARE
	del_actor_nid VARCHAR=OLD.nid;
	BEGIN
		DELETE FROM starsIn WHERE starsIn.nid =del_actor_nid;
		RETURN NEW;
	END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER delete_actor 
	AFTER DELETE ON actor 
	FOR EACH ROW
	EXECUTE PROCEDURE deleteActor();

---- point d
ALTER TABLE starsIn DROP CONSTRAINT actor_name;

SELECT tid 
FROM starsIn 
WHERE nid = (
SELECT nid FROM actor
	WHERE name LIKE 'Robert De Niro'
);

-- (31 rows)

----- delete De Niro
DELETE FROM actor WHERE name='Robert De Niro';


SELECT tid 
FROM starsIn 
WHERE nid = (
SELECT nid FROM actor
	WHERE name LIKE 'Robert De Niro'
);
----- 0 row.

SELECT * FROM actor
WHERE name LIKE 'Robert De Niro';
----- 0 row


----- Problem 5
---- point a

-- First check for frequent combinations of actors who acted in at least 3 movies
SELECT nid
FROM starsin 
GROUP BY nid
HAVING COUNT(tid)>=3;
(1622 rows)

-- A-Priori Step 1: Materialize the frequent 1-itemsets into a new table starsin_step1
CREATE OR REPLACE VIEW starsin_step1 AS (
SELECT s1.nid, s1.tid
  FROM starsin s1 
  WHERE EXISTS (
    SELECT s2.nid
	FROM starsin s2 
	WHERE s1.nid = s2.nid 
	GROUP BY s2.nid
	HAVING COUNT(s2.tid)>=3)
	);


-- Now check for frequent combinations of Actor and 2-itemsets

SELECT DISTINCT 
		(SELECT name FROM actor WHERE nid = S1.nid),
		(SELECT name FROM actor WHERE nid = S2.nid)
FROM starsin_step1 s1, starsin_step1 s2
WHERE s1.tid = s2.tid
  AND s1.nid< s2.nid
GROUP BY s1.nid, s2.nid
HAVING COUNT(s1.tid)>=3;
(184 rows)


NOTE: OPTIONAL
--the above query gives 184 rows, the same result of this query
SELECT DISTINCT 
		(SELECT name FROM actor WHERE nid = S1.nid),
		(SELECT name FROM actor WHERE nid = S2.nid)

       FROM starsin s1 join starsin s2
       ON s1.tid= s2.tid
       WHERE s1.nid > s2.nid
           GROUP BY s2.nid, s1.nid
           HAVING COUNT(*)  >= 3
           ORDER BY 2,1;

----point b

-- A-Priori Step 2: Perform the next iteration for frequent 2-itemsets

CREATE OR REPLACE VIEW starsin_step2 AS (
  SELECT s1.tid, 
  		 s1.nid AS nid1, 
  		 s2.nid AS nid2
  FROM starsin_step1 s1, starsin_step1 s2
  WHERE s1.tid = s2.tid
  	AND s1.nid < s2.nid
  AND EXISTS (
    SELECT s3.nid, s4.nid
    FROM starsin_step1 s3, 
    	 starsin_step1 s4
    WHERE s3.tid = s4.tid
	  AND s1.nid = s3.nid
	  AND s2.nid = s4.nid
      AND s3.nid < s4.nid
    GROUP BY  s3.nid, s4.nid
    HAVING COUNT(s3.tid)>=3)
  );

--Lets check how many records view has ==> 655 records 
SELECT COUNT(*) FROM starsin_step2; 

-- Select frequent combinations of actors and 3-itemsets
---39 records

SELECT DISTINCT 
		(SELECT name FROM actor WHERE nid = b1.nid1) AS actor1,
		(SELECT name FROM actor WHERE nid = b1.nid2) AS actor2,
		(SELECT name FROM actor WHERE nid = b2.nid2) AS actor3

FROM starsin_step2 b1, starsin_step2 b2
WHERE b1.tid = b2.tid
  AND b1.nid1 = b2.nid1 
  AND b1.nid2 < b2.nid2
GROUP BY b1.nid1, b1.nid2, b2.nid2
HAVING COUNT(b1.tid)>=3;

--We finally double checked, the number of records is the same of the previous point (39). For sake of simplicity we just select "nid"

SELECT DISTINCT  s1.nid AS nid_1,s2.nid AS nid_2,s3.nid AS nid_3
       FROM starsin s1 join starsin s2 ON (s1.tid= s2.tid)
       				   join starsin s3 ON (s1.tid= s3.tid)
       WHERE  s1.nid > s2.nid
       		AND s2.nid>s3.nid
           GROUP BY s1.nid, s2.nid,s3.nid
           HAVING COUNT(*)  >= 3
           ORDER BY 1,2,3;

--Optional: query that perform an "except" between 5b and 5c to compare not only the number of records but also the content: this query should return 0 rows:

SELECT b1.nid1 AS Actor1,
	   b1.nid2 AS Actor2,
	   b2.nid2 AS Actor3
FROM starsin_step2 b1, starsin_step2 b2
WHERE b1.tid = b2.tid
  AND b1.nid1 = b2.nid1 
  AND b1.nid2 < b2.nid2
GROUP BY b1.nid1, b1.nid2, b2.nid2
HAVING COUNT(b1.tid)>=3
EXCEPT ALL
SELECT DISTINCT  s3.nid AS actor1, s2.nid AS actor2, s1.nid AS actor3
       FROM starsin s1 join starsin s2 ON (s1.tid= s2.tid)
       				   join starsin s3 ON (s1.tid= s3.tid)
       WHERE  s1.nid > s2.nid
       		AND s2.nid>s3.nid
           GROUP BY s1.nid, s2.nid,s3.nid
           HAVING COUNT(*)  >= 3;
