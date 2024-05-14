/* These SQL queries retrieve data from olympics database, and showcase the skills related to the following topics:
- using aggregate functions (COUNT, COUNT DISTINCT, AVG, MAX, SUM)
- joining tables
- filtering with WHERE and HAVING
- UNION tables
- creating custom fields with a hard-coded column, calculations, or CASE statement
- using subqueries within FROM and WHERE clause
- fixing inconsistent data types with CAST function
- parsing strings with string functions
- handling nulls with COALESCE
- dealing with duplication
- using window functions SUM() and ROW_NUMBER()
*/

USE olympics;

-- 1. What are the top 3 summer sports with most athletes represented?
-- pracicing COUNT, and grouping and ordering results
SELECT 
	sport, 
    COUNT(DISTINCT athlete_id) AS athletes
FROM summer_games
GROUP BY sport
ORDER BY athletes DESC
LIMIT 3;

-- 2. What is the age of the oldest athlete by region?
-- practicing MAX, and JOIN tables
SELECT 
	c.region,
    MAX(a.age) AS age_of_oldest_athlete
FROM athletes a
JOIN summer_games sg
ON a.id = sg.athlete_id
JOIN countries c
ON sg.country_id = c.id
WHERE C.REGION <> ""
GROUP BY region
ORDER BY age_of_oldest_athlete DESC;

-- 3. What is the number of events in each sport - summer and winter?
-- practicing UNION
SELECT 
	sport, 
    COUNT(DISTINCT event) AS events
FROM summer_games
GROUP BY sport
UNION
SELECT 
	sport, 
    COUNT(DISTINCT event) AS events
FROM winter_games
GROUP BY sport
ORDER BY events DESC;

-- 4. Who are the most decorated summer athletes?
-- practicing HAVING to filter by aggregated field
SELECT 
	a.name AS athlete_name, 
    COUNT(medal) AS number_of_medals
FROM summer_games AS s
JOIN athletes AS a
ON a.id = s.athlete_id
WHERE medal = "Gold"
GROUP BY a.name
HAVING COUNT(medal) >= 3
ORDER BY number_of_medals DESC;

-- 5. What are the top 10 athletes in nobel-prized countries?
-- using CASE statement to create new column
-- using UNION to merge rows from two tables
-- using a subquery nested within WHERE clause
SELECT 
    event,
    CASE WHEN event LIKE '%Women%' THEN 'female' 
    ELSE 'male' END AS gender,
    COUNT(DISTINCT athlete_id) AS athletes
FROM summer_games
WHERE country_id IN 
	(SELECT country_id 
    FROM country_stats 
    WHERE nobel_prize_winners > 0)
GROUP BY event
UNION
SELECT 
	event,
    CASE WHEN event LIKE '%Women%' THEN 'female' 
    ELSE 'male' END AS gender,
    COUNT(DISTINCT athlete_id) AS athletes
FROM winter_games
WHERE country_id IN 
	(SELECT country_id
    FROM country_stats
    WHERE nobel_prize_winners > 0)
GROUP BY event
ORDER BY athletes DESC
LIMIT 10;

-- 6. What are the countries with high medal rates?
-- cleaning up the 'country' column by selecting only the 3-letter country code
-- using CASE statement to sum up the number of medals won within each country
-- adding additional validation while joining tables (by date) to handle duplication
SELECT
    LEFT(REPLACE(UPPER(TRIM(c.country)),'.',''),3) AS country_code,
	population / 1000000 AS pop_in_millions,
    SUM(CASE WHEN medal <> '' THEN 1 ELSE 0 END) AS medals,
	SUM(CASE WHEN medal <> '' THEN 1 ELSE 0 END) / CAST(cs.population / 1000000 AS float) AS medals_per_million
FROM summer_games AS s
JOIN countries AS c
ON s.country_id = c.id
JOIN country_stats AS cs 
ON s.country_id = cs.country_id AND s.year = CAST(cs.year AS date)
GROUP BY c.country, pop_in_millions
ORDER BY medals_per_million DESC
LIMIT 25;

-- 7. What is the most decorated athlete per region?
-- using window function ROW_NUMBER to rank gold-medal athletes by region, from highest to lowest 
-- using subquery and filter for top row only
SELECT 
	region,
    athlete_name,
    total_golds
FROM
    (SELECT 
        region, 
        name AS athlete_name, 
        SUM(gold) AS total_golds,
        ROW_NUMBER() OVER (PARTITION BY region ORDER BY SUM(gold) DESC) AS row_num
    FROM summer_games_clean AS s
    JOIN athletes AS a
    ON a.id = s.athlete_id
    JOIN countries AS c
    ON s.country_id = c.id
    GROUP BY region, athlete_name) AS subquery
WHERE row_num = 1;

-- 8. What is the percent of GDP per country?
-- using window function SUM to calculate global gdp, and then percent of gdp per region
SELECT 
	region,
    country,
	SUM(gdp) AS country_gdp,
    SUM(SUM(gdp)) OVER () AS global_gdp,
    SUM(gdp) / SUM(SUM(gdp)) OVER () AS perc_global_gdp,
    SUM(gdp) / SUM(SUM(gdp)) OVER ( PARTITION BY region ) AS perc_region_gdp
FROM country_stats AS cs
JOIN countries AS c
ON cs.country_id = c.id
WHERE gdp IS NOT NULL
GROUP BY region, country
ORDER BY country_gdp DESC;

-- 9. What is the GDP per capita performance index for 2016?
-- performance index compares each row to a benchmark
-- using window function SUM to calculate the total worlds gdp per million, and then calculate each country performance index
SELECT 
    region,
    country,
    SUM(gdp) / SUM(pop_in_millions) AS gdp_per_million,
    SUM(SUM(gdp)) OVER () / SUM(SUM(pop_in_millions)) OVER () AS gdp_per_million_total,
    (SUM(gdp) / SUM(pop_in_millions))
    /
    (SUM(SUM(gdp)) OVER () / SUM(SUM(pop_in_millions)) OVER ()) AS performance_index
FROM country_stats AS cs
JOIN countries AS c 
ON cs.country_id = c.id
WHERE year = '2016-01-01' AND gdp IS NOT NULL
GROUP BY region, country
ORDER BY gdp_per_million DESC;

-- 10. What are the tallest athletes and what is the percent of GDP by region?
-- using ROW_NUMBER to rank athletes by height
-- using SUM window function to calculate region's percent of world gdp

SELECT
    region,
    AVG(height) AS avg_tallest,
    -- Calculate region's percent of world gdp
    SUM(gdp) / SUM(SUM(gdp)) OVER () AS perc_world_gdp    
FROM countries AS c
JOIN
    (SELECT 
        country_id, 
        height, 
        -- Number the height of each country's athletes
        ROW_NUMBER() OVER (PARTITION BY country_id ORDER BY height DESC) AS row_num
    FROM winter_games AS w 
    JOIN athletes AS a ON w.athlete_id = a.id
    GROUP BY country_id, height
    ORDER BY country_id, height DESC) AS subquery
ON c.id = subquery.country_id
JOIN country_stats AS cs
ON c.id = cs.country_id
-- Only include the tallest height for each country
WHERE row_num = 1
GROUP BY region;

