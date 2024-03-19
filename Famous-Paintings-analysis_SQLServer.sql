USE Paintings;

-- Identify the museums which are open on both Sunday and Monday. Display museum name, city.

SELECT 
	m.name,
	m.city 
FROM museum m 
JOIN museum_hours mh ON m.museum_id = mh.museum_id
WHERE mh.day IN ('Sunday', 'Monday')
GROUP BY m.name, m.city
HAVING count(*)=2
ORDER BY m.name;

-- Which museum is open for the longest during a day? Display museum name, state and hours open and which day?

WITH cte_openhours AS (
	SELECT
		m.name,
		m.state,
		mh.day,
		mh."open",
		mh."close",
		datediff(minute, "open", "close") AS duration_min,
		RANK() OVER (ORDER BY datediff(minute, "open", "close") DESC) AS rank
	FROM museum_hours mh
	JOIN museum m ON m.museum_id=mh.museum_id)

SELECT 
	name,
	state,
	day,
	"open",
	"close"
FROM cte_openhours
WHERE rank=1;

-- Are there museums without any paintings?

SELECT *
FROM museum m
LEFT JOIN work w ON m.museum_id=w.museum_id
WHERE w.work_id IS NULL

-- How many paintings have an asking price of more than their regular price?SELECT count(*) as total
FROM product_size
WHERE sale_price > regular_price;

-- Identify the paintings whose asking price is less than 50% of its regular price

SELECT 
	name, 
	sale_price, 
	regular_price
FROM product_size pz
JOIN work w ON pz.work_id=w.work_id
WHERE sale_price < (0.5*regular_price)

-- Which canva size costs the most?

WITH cte_sale_price AS (
	SELECT 
		label, 
		sale_price,
		RANK() OVER (ORDER BY sale_price DESC) AS rank
	FROM canvas_size c
	JOIN product_size p ON c.size_id=p.size_id)

SELECT
	label,
	sale_price
FROM cte_sale_price
WHERE rank=1

-- Delete duplicate records from work and subject tables

SELECT DISTINCT *
INTO work_no_dups
FROM work;

SELECT DISTINCT *
INTO subject_no_dups
FROM subject;

--  Identify the museums with invalid city information in the given dataset

SELECT museum_id, name, city
FROM museum
WHERE PATINDEX('%[0-9]%', city) > 0;

-- Fetch the top 10 most famous painting subject

SELECT subject, total 
FROM ( 
	SELECT subject, count(*) AS total, ROW_NUMBER() OVER (ORDER BY count(*) DESC) as row FROM subject
	GROUP BY subject) s 
WHERE s.row <= 10

-- How many museums are open every single day?

SELECT count(*) AS total
FROM (
	SELECT museum_id
	FROM museum_hours
	GROUP BY museum_id
	HAVING count(*) = 7 ) s

-- Who are the top 5 most popular artists? (Popularity is defined based on most no. of paintings done by an artist)

WITH cte_artists AS (
	SELECT 
		a.full_name, 
		count(w.work_id) AS no_of_paintings,
		ROW_NUMBER() OVER (ORDER BY count(w.work_id) DESC) as row
	FROM artist a
	JOIN work w ON a.artist_id=w.artist_id
	GROUP BY a.full_name)

SELECT full_name, no_of_paintings FROM cte_artists
WHERE row <= 5

-- Identify the artists whose paintings are displayed in multiple countries.

WITH cte_countries AS (
	SELECT 
		distinct full_name, 
		country
	FROM artist a
	JOIN work w ON a.artist_id=w.artist_id
	JOIN museum m ON w.museum_id=m.museum_id)

SELECT *, count(full_name) OVER (PARTITION BY full_name) as countries_count from cte_countries
ORDER BY countries_count DESC

/* Identify the artist and the museum where the most expensive and least expensive
painting is placed. Display the artist name, sale_price, painting name, museum
name, museum city and canvas label. */WITH cte_price_min AS (	SELECT 		a.full_name,		ps.sale_price,		w.name AS painting_name,		m.name AS museum_name,		m.city,		cs.label,		DENSE_RANK() OVER (ORDER BY ps.sale_price) AS rank	FROM artist a	JOIN work w ON a.artist_id=w.artist_id	JOIN museum m ON w.museum_id=m.museum_id	JOIN product_size ps ON w.work_id=ps.work_id	JOIN canvas_size cs ON ps.size_id=cs.size_id),	cte_price_max AS (	SELECT 		a.full_name,		ps.sale_price,		w.name AS painting_name,		m.name AS museum_name,		m.city,		cs.label,		DENSE_RANK() OVER (ORDER BY ps.sale_price DESC) AS rank	FROM artist a	JOIN work w ON a.artist_id=w.artist_id	JOIN museum m ON w.museum_id=m.museum_id	JOIN product_size ps ON w.work_id=ps.work_id	JOIN canvas_size cs ON ps.size_id=cs.size_id)SELECT * FROM cte_price_minWHERE rank=1UNIONSELECT * FROM cte_price_maxWHERE rank=1-- Which country has the 5th highest no of paintings?WITH cte_paintings AS (	SELECT		country,		count(*) AS no_of_paintings,		RANK() OVER (ORDER BY count(*) DESC) AS rank	FROM museum m	JOIN work w ON m.museum_id=w.museum_id	GROUP BY country)SELECT country, no_of_paintings FROM cte_paintingsWHERE rank <= 5-- Which are the 3 most popular and 3 least popular painting styles?WITH cte_style_min AS (	SELECT 		style, 		count(*) AS no_of_paintings, 		RANK() OVER (ORDER BY count(*)) AS rank	FROM work	GROUP BY style),	cte_style_max AS (	SELECT 		style, 		count(*) AS no_of_paintings, 		RANK() OVER (ORDER BY count(*) DESC) AS rank	FROM work	GROUP BY style)SELECT	style, 	no_of_paintingsFROM cte_style_minWHERE rank=1UNIONSELECT	style, 	no_of_paintingsFROM cte_style_maxWHERE rank=1/* Which artist has the most no of Portraits paintings outside USA? Display artist
name, no of paintings and the artist nationality. */
WITH cte_portraits AS (
	SELECT 
		a.full_name,
		a.nationality,
		count(w.work_id) AS no_of_paintings,
		RANK() OVER (ORDER BY count(w.work_id) DESC) AS rank
	FROM artist a
	JOIN work w ON a.artist_id=w.artist_id
	JOIN museum m ON w.museum_id=m.museum_id
	JOIN subject s ON w.work_id=s.work_id
	WHERE m.country<>'USA' AND s.subject='Portraits'
	GROUP BY a.full_name, a.nationality)

SELECT
	full_name,
	nationality,
	no_of_paintings
FROM cte_portraits
WHERE rank=1