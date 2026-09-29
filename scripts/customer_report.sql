
/*

=================================================================
Customer Report
=================================================================
Purpose:
	- this report consolidates key customer metrics and behaviors
Highlights:
	1. Gather essential fields such as names, ages, and transaction details.
	2. Segments customers into categories (VIP , Regular , New) and age group.
	3. Aggregate customer - level metrics:
		- total orders
		- total sales
		- total quantity purchased
		- total product
		- lifespan (in months)
	4. Calculates value KPIs:
		- recency (months since last order)
		- avaerage order value
		- average monthly spend
*/


CREATE OR ALTER VIEW gold.report_customers AS

/*---------------------------------------------------------------------------
1- Base Query : Retrieves core columns from tables >> CTE
-----------------------------------------------------------------------------*/

WITH base_query AS (
SELECT 
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
CONCAT(c.first_name,' ', c.last_name) AS customer_name,
c.birthdate,
DATEDIFF(YEAR,c.birthdate,GETDATE()) AS age
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key  = c.customer_key
WHERE order_date IS NOT NULL
)


/*---------------------------------------------------------------------------
2- Customer Aggregations: summarizes key metrics at the customer level >> CTE
-----------------------------------------------------------------------------*/
,
customer_aggregation AS
(
SELECT 
customer_key,
customer_number,
customer_name,
age,
COUNT(DISTINCT order_number ) AS total_orders,
SUM(sales_amount) AS total_sales,
SUM(quantity) AS total_quantity,
COUNT(DISTINCT product_key) AS total_product,
MAX(order_date) AS last_order_date,
DATEDIFF(MONTH , MIN(order_date) , MAX(order_date)) AS lifespane

FROM base_query
GROUP BY customer_key,
customer_number,
customer_name,
age
)


/*---------------------------------------------------------------------------
3- Final Report & Do Final Transformation 
-----------------------------------------------------------------------------*/

SELECT
customer_key,
customer_number,
customer_name,
age,
CASE	WHEN total_sales >= 5000 AND  lifespane >= 12 THEN 'VIP'
		WHEN total_sales < 5000 AND  lifespane >= 12 THEN 'Regular'
		ELSE 'NEW'
END AS customer_segment,

CASE	WHEN age <= 20 THEN 'under 20'
		WHEN age BETWEEN 20 AND 30  THEN '20 - 30'
		WHEN age BETWEEN 30 AND 40  THEN '30 - 40'
		WHEN age BETWEEN 40 AND 50  THEN '40 - 50'
		WHEN age BETWEEN 50 AND 60  THEN '50 - 60'
		ELSE 'above 60'
END AS age_segment,
last_order_date,
DATEDIFF(MONTH , last_order_date , GETDATE()) AS recency,
total_orders,
total_sales,
total_quantity,
total_product,
-- compute avg order value = total_sales/total_orders
-- to handle total_orders = 0 
CASE	WHEN total_orders = 0 THEN 0
		ELSE total_sales/total_orders
END AS avg_order_value,

-- compute avg month spend = total_sales/number_of_months (lifespan)
-- to handle lifespane = 0
CASE	WHEN lifespane = 0 THEN total_sales
		ELSE total_sales/lifespane
END AS avg_month_spend

FROM customer_aggregation


-- Execution:
-- SELECT * FROM gold.report_customers
