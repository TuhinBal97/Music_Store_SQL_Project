

/* Q1: Who is the senior most employee based on job title? */

SELECT title, last_name, first_name 
FROM employee
ORDER BY levels DESC
LIMIT 1

/* Q2: Which countries have the most Invoices? */

SELECT billing_country,COUNT(invoice_id) AS ic 
FROM invoice
GROUP BY billing_country 
ORDER BY ic DESC;

/* Q3: What are top 3 values of total invoice? */

SELECT total 
FROM invoice
ORDER BY total DESC


/* Q4: Which city has the best customers? We would like to throw a promotional Music Festival in the city we made the most money. 
Write a query that returns one city that has the highest sum of invoice totals. 
Return both the city name & sum of all invoice totals */

SELECT billing_city,SUM(total) AS InvoiceTotal
FROM invoice
GROUP BY billing_city
ORDER BY InvoiceTotal DESC
LIMIT 1;


/* Q5: Who is the best customer? The customer who has spent the most money will be declared the best customer. 
Write a query that returns the person who has spent the most money.*/

SELECT customer.customer_id, first_name, last_name, SUM(total) AS total_spending
FROM customer
JOIN invoice ON customer.customer_id = invoice.customer_id
GROUP BY customer.customer_id
ORDER BY total_spending DESC
LIMIT 1;


/* Question Set 2 - Moderate */

/* Q1: Write query to return the email, first name, last name, & Genre of all Rock Music listeners. 
Return your list ordered alphabetically by email starting with A. */

SELECT c.first_name, c.last_name,c.email,g.name FROM customer AS c
INNER JOIN invoice 
	ON invoice.customer_id= c.customer_id
INNER JOIN invoice_line 
	ON invoice.invoice_id = invoice_line.invoice_id
INNER JOIN track 
	ON track.track_id = invoice_line.track_id
INNER JOIN genre AS g
	ON track.genre_id = g.genre_id	
	WHERE g.name LIKE 'Rock'
ORDER BY c.email;


/* Q2: Let's invite the artists who have written the most rock music in our dataset. 
Write a query that returns the Artist name and total track count of the top 10 rock bands. */

SELECT ar.name AS artist_name, COUNT(t.track_id) AS track_count 
FROM track AS t
INNER JOIN genre AS g
    ON t.genre_id = g.genre_id  
INNER JOIN album AS a
    ON a.album_id = t.album_id
INNER JOIN artist AS ar
    ON ar.artist_id = a.artist_id
WHERE g.name = 'Rock'
GROUP BY ar.name
ORDER BY track_count DESC
LIMIT 10;

/* Q3: Return all the track names that have a song length longer than the average song length. 
Return the Name and Milliseconds for each track. Order by the song length with the longest songs listed first. */

SELECT name,miliseconds
FROM track
WHERE miliseconds > (
	SELECT AVG(miliseconds) AS avg_track_length
	FROM track )
ORDER BY miliseconds DESC;




/* Question Set 3 - Advance */

🤔 /* Q1: Find how much amount spent by each customer on artists? Write a query to return customer name, artist name and total spent */

/* Steps to Solve: First, find which artist has earned the most according to the InvoiceLines. Now use this artist to find 
which customer spent the most on this artist. For this query, you will need to use the Invoice, InvoiceLine, Track, Customer, 
Album, and Artist tables. Note, this one is tricky because the Total spent in the Invoice table might not be on a single product, 
so you need to use the InvoiceLine table to find out how many of each product was purchased, and then multiply this by the price
for each artist. */

-- ➡️Solution 1: using CTE

WITH best_selling_artist AS (
    SELECT 
        ar.artist_id, 
        ar.name AS artist_name, 
        SUM(il.unit_price * il.quantity) AS total_sales
    FROM invoice_line il
    JOIN track t ON t.track_id = il.track_id
    JOIN album a ON a.album_id = t.album_id
    JOIN artist ar ON ar.artist_id = a.artist_id
    GROUP BY ar.artist_id
    ORDER BY total_sales DESC
    LIMIT 1
)
SELECT 
    c.customer_id, 
    c.first_name, 
    c.last_name, 
    bsa.artist_name, 
    SUM(il.unit_price * il.quantity) AS amount_spent
FROM invoice i
JOIN customer c ON c.customer_id = i.customer_id
JOIN invoice_line il ON il.invoice_id = i.invoice_id
JOIN track t ON t.track_id = il.track_id
JOIN album a ON a.album_id = t.album_id
JOIN best_selling_artist bsa ON bsa.artist_id = a.artist_id
GROUP BY c.customer_id, c.first_name, c.last_name, bsa.artist_name
ORDER BY amount_spent DESC;


-- ➡️Solution 2: using Window Function:

WITH artist_sales AS (
    SELECT 
        ar.artist_id, 
        ar.name AS artist_name, 
        SUM(il.unit_price * il.quantity) AS total_sales,
        RANK() OVER (ORDER BY SUM(il.unit_price * il.quantity) DESC) AS sales_rank
    FROM invoice_line il
    JOIN track t ON t.track_id = il.track_id
    JOIN album a ON a.album_id = t.album_id
    JOIN artist ar ON ar.artist_id = a.artist_id
    GROUP BY ar.artist_id, ar.name
)
SELECT 
    c.customer_id, 
    c.first_name, 
    c.last_name, 
    ar.artist_name, 
    SUM(il.unit_price * il.quantity) AS amount_spent
FROM invoice i
JOIN customer c ON c.customer_id = i.customer_id
JOIN invoice_line il ON il.invoice_id = i.invoice_id
JOIN track t ON t.track_id = il.track_id
JOIN album a ON a.album_id = t.album_id
JOIN artist_sales ar ON ar.artist_id = a.artist_id
WHERE ar.sales_rank = 1
GROUP BY c.customer_id, c.first_name, c.last_name, ar.artist_name
ORDER BY amount_spent  DESC;


🤔 /* Q2: We want to find out the most popular music Genre for each country. We determine the most popular genre as the genre 
with the highest amount of purchases. Write a query that returns each country along with the top Genre. For countries where 
the maximum number of purchases is shared return all Genres. */

-- ➡️Solution 1: using CTE

WITH genre_purchases AS (
    SELECT 
        customer.country, 
        genre.name AS genre_name, 
        COUNT(invoice_line.quantity) AS purchases
    FROM invoice_line 
    JOIN invoice ON invoice.invoice_id = invoice_line.invoice_id
    JOIN customer ON customer.customer_id = invoice.customer_id
    JOIN track ON track.track_id = invoice_line.track_id
    JOIN genre ON genre.genre_id = track.genre_id
    GROUP BY customer.country, genre.name
),
max_purchases_per_country AS (
    SELECT 
        country, 
        MAX(purchases) AS max_purchases
    FROM genre_purchases
    GROUP BY country
)
SELECT 
    gp.country, 
    gp.genre_name, 
    gp.purchases
FROM genre_purchases gp
JOIN max_purchases_per_country mp 
    ON gp.country = mp.country AND gp.purchases = mp.max_purchases
ORDER BY gp.country, gp.purchases DESC;


-- ➡️Solution 2: Using window function

WITH popular_genre AS 
(
    SELECT 
        customer.country, 
        genre.name AS genre_name, 
        COUNT(invoice_line.quantity) AS purchases, 
        RANK() OVER(PARTITION BY customer.country ORDER BY COUNT(invoice_line.quantity) DESC) AS rank
    FROM invoice_line 
    JOIN invoice ON invoice.invoice_id = invoice_line.invoice_id
    JOIN customer ON customer.customer_id = invoice.customer_id
    JOIN track ON track.track_id = invoice_line.track_id
    JOIN genre ON genre.genre_id = track.genre_id
    GROUP BY customer.country, genre.name
)
SELECT 
    country, 
    genre_name, 
    purchases 
FROM popular_genre 
WHERE rank = 1;



🤔 /* Q3: Write a query that determines the customer that has spent the most on music for each country. 
Write a query that returns the country along with the top customer and how much they spent. 
For countries where the top amount spent is shared, provide all customers who spent this amount. */

-- 🔸🔹Solution 1 : using CTE 

WITH customer_spending AS (
    SELECT 
        customer.customer_id,
        customer.first_name,
        customer.last_name,
        customer.country,
        SUM(invoice.total) AS total_spending
    FROM customer
    JOIN invoice ON customer.customer_id = invoice.customer_id
    GROUP BY customer.customer_id, customer.first_name, customer.last_name, customer.country
),
max_spending_per_country AS (
    SELECT 
        country,
        MAX(total_spending) AS max_spending
    FROM customer_spending
    GROUP BY country
)
SELECT 
    cs.country,
    cs.total_spending,
    cs.first_name,
    cs.last_name,
    cs.customer_id
FROM customer_spending cs
JOIN max_spending_per_country mspc ON cs.country = mspc.country AND cs.total_spending = mspc.max_spending
ORDER BY cs.country;


-- Solution 1 : using Recurssive

WITH RECURSIVE 
	customter_with_country AS (
		SELECT customer.customer_id,first_name,last_name,billing_country,SUM(total) AS total_spending
		FROM invoice
		JOIN customer ON customer.customer_id = invoice.customer_id
		GROUP BY 1,2,3,4
		ORDER BY 2,3 DESC),

	country_max_spending AS(
		SELECT billing_country,MAX(total_spending) AS max_spending
		FROM customter_with_country
		GROUP BY billing_country)

SELECT cc.billing_country, cc.total_spending, cc.first_name, cc.last_name, cc.customer_id
FROM customter_with_country cc
JOIN country_max_spending ms
ON cc.billing_country = ms.billing_country
WHERE cc.total_spending = ms.max_spending
ORDER BY 1;

/* Method 2: Using Recursive */

WITH RECURSIVE 
	customter_with_country AS (
		SELECT customer.customer_id,first_name,last_name,billing_country,SUM(total) AS total_spending
		FROM invoice
		JOIN customer ON customer.customer_id = invoice.customer_id
		GROUP BY 1,2,3,4
		ORDER BY 2,3 DESC),

	country_max_spending AS(
		SELECT billing_country,MAX(total_spending) AS max_spending
		FROM customter_with_country
		GROUP BY billing_country)

SELECT cc.billing_country, cc.total_spending, cc.first_name, cc.last_name, cc.customer_id
FROM customter_with_country cc
JOIN country_max_spending ms
ON cc.billing_country = ms.billing_country
WHERE cc.total_spending = ms.max_spending
ORDER BY 1;


