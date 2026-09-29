/*
==========================
1 >> CHANGE OVER-TIME ANALYSIS
==========================
*/

-- ANALYZE SALES PERFORMANCE OVER TIME
SELECT DATETRUNC(MONTH , order_date) order_date,
sum(sales_amount) total_sales,
COUNT(DISTINCT customer_key) total_customer,
SUM(quantity) total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH , order_date)
ORDER BY DATETRUNC(MONTH , order_date)



/*
==========================
2 >> CUMULATIVE ANALYSIS
==========================
*/
-- CALCULATE THE TOTAL SALES PER MONTH, AND THE RUNNING TOTAL OF SALES OVER TIME

SELECT *,
SUM(total_sales) OVER(ORDER BY order_date) AS running_total_sales,
AVG(avg_price) OVER(ORDER BY order_date) AS moving_avg_price
FROM
(
SELECT DATETRUNC(MONTH , order_date) order_date,
SUM(sales_amount) total_sales,
AVG(price) avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH , order_date)
)t

/* I WANT TO CHECK WHY IS NOT WORKING (WINDOW FUNCTION WITH GROUP BY)

SELECT DATETRUNC(MONTH , order_date) order_date,
SUM(sales_amount) total_sales,
SUM(sales_amount) OVER(ORDER BY DATETRUNC(MONTH , order_date) ) AS running_total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH , order_date)

*/

/*
==========================
3 >> PERFORMANCE ANALYSIS
==========================
*/
--ANALYZE THE YEARLY PERFORMANCE OF PRODUCTS BY COMPARING EACH PRODUCT'S SALES TO BOTH :
-- * ITS AVG SALES PERFORMANCE 
-- * AND THE PREVIOUS YEAR SALES

WITH CTE_AGG AS
(
SELECT 
product_name as product_name,
DATETRUNC(YEAR , order_date) as year_date,
SUM(sales_amount) as total_sales
FROM gold.fact_sales s
LEFT JOIN gold.dim_products p
ON s.product_key = p.product_key
WHERE order_date IS NOT NULL
GROUP BY product_name ,  DATETRUNC(YEAR , order_date) 
)

SELECT *,
AVG(total_sales) OVER(PARTITION BY product_name) AS avg_procust_sales,
CASE	WHEN total_sales < AVG(total_sales) OVER(PARTITION BY product_name) THEN 'below avg'
		WHEN total_sales > AVG(total_sales) OVER(PARTITION BY product_name) THEN 'above avg'
		ELSE 'avg'
END 'compare with AVG',

LAG(total_sales) OVER(PARTITION BY product_name ORDER BY year_date ) AS pre_year_sales,
CASE	WHEN total_sales < LAG(total_sales) OVER(PARTITION BY product_name ORDER BY year_date ) THEN 'decrease'
		WHEN total_sales >= LAG(total_sales) OVER(PARTITION BY product_name ORDER BY year_date ) THEN 'increase'
		ELSE 'no change'
END 'compare with pre_year'
FROM CTE_AGG
ORDER BY product_name , year_date


/*
==========================
4 >> PART-TO-WHOLE ANALYSIS
==========================
*/
-- WHICH CATEGORIES CONTRIBUTE THE MOST TO OVERALL SALES ?

SELECT * ,
SUM(total_sales) OVER() AS whole_sales,
CONCAT(ROUND((CAST(total_sales AS float) / SUM(total_sales) OVER())*100,2) , '%') AS percentage_of_total
FROM
(
SELECT 
p.category as category,
SUM(sales_amount) as total_sales
FROM gold.fact_sales s
LEFT JOIN gold.dim_products p
ON s.product_key = p.product_key
WHERE order_date IS NOT NULL
GROUP BY p.category  
)T
ORDER BY percentage_of_total DESC

/*
==========================
5 >> DATA SEGMENTATION
==========================
*/ 
-- 1- DO GROUP BY AND AGGREGATION >> THEN APPLY SEGMENTATION USING 'CASE WHEN'
-- WE WILL APPLY IT IN THE CUSTOMER REPORT
