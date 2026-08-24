/*
====================
Quality Checks:
this script performs the quality checks to validate the integrity, consistency, and accurecy of the 'Gold' layer, includes:
  * Uniqueness of surrogate keys in  dimensions tables 
  * Referential integrity between fact and dimension tables
  * validation of relationships in the data model for analytical purposes
====================
*/


/*
=============================================================================================
FIRST OBJECT : CUSTOMERS
=============================================================================================
*/
--=============================
-- JOINING TABLES
--=============================

SELECT ci.cst_id,
ci.cst_key,
ci.cst_firstname,
ci.cst_lastname,
ci.cst_marital_status,
ci.cst_gndr,
ci.cst_create_date,
ca.bdate,
ca.gen,
la.cntry
FROM silver.crm_cust_info  ci
LEFT JOIN silver.erp_cust_az12 ca
ON		ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON		ci.cst_key  = la.cid 



--=============================
-- CHECK FOR DUPLICATE ROWS AFTER JOINING TABLES (UNIQUENESS) 
-- >> EACH CUSTOMER HAS ONLY ONE RECORD
--=============================

SELECT cst_id, COUNT(*)
FROM (
SELECT ci.cst_id,
ci.cst_key,
ci.cst_firstname,
ci.cst_lastname,
ci.cst_marital_status,
ci.cst_gndr,
ci.cst_create_date,
ca.bdate,
ca.gen,
la.cntry
FROM silver.crm_cust_info  ci
LEFT JOIN silver.erp_cust_az12 ca
ON		ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON		ci.cst_key  = la.cid 
)t
GROUP BY cst_id
HAVING COUNT(*) >1


--=======================================
-- CHECK FOR GENDER VALUE FROM 2 SOURCES
--=======================================


SELECT DISTINCT
ci.cst_gndr,
ca.gen,
--SOLVE: (DATA INTEGRATION)
	CASE	WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr -- CRM  is the master for gender info
			ELSE COALESCE(UPPER(ca.gen) , 'n/a')
	END new_gen
FROM silver.crm_cust_info  ci
LEFT JOIN silver.erp_cust_az12 ca
ON		ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON		ci.cst_key  = la.cid 
ORDER BY 1,2
--WHERE UPPER(ci.cst_gndr)!= UPPER(ca.gen)


--=============================
-- 1- RENAME COLUMNS
-- 2- SORT COLUMNS
-- 3- GENERATE SURROGATE KEY
-- 4- CREATE VIEW
--============================= 
CREATE VIEW gold.dim_customers AS
	SELECT 
		ROW_NUMBER() OVER(ORDER BY ci.cst_id) AS customer_key,
		ci.cst_id AS customer_id,
		ci.cst_key AS customer_number,
		ci.cst_firstname AS first_name,
		ci.cst_lastname AS last_name,
		la.cntry AS country,
		ci.cst_marital_status AS marital_status,
		CASE	WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr -- CRM  is the master for gender info
				ELSE COALESCE(UPPER(ca.gen) , 'n/a')
		END AS gender,
		ca.bdate AS birthdate,
		ci.cst_create_date AS create_date

	FROM silver.crm_cust_info  ci
	LEFT JOIN silver.erp_cust_az12 ca
	ON		ci.cst_key = ca.cid
	LEFT JOIN silver.erp_loc_a101 la
	ON		ci.cst_key  = la.cid 



--============= 
-- SELECT * FROM gold.dim_customers


/*
=============================================================================================
SECOND OBJECT : PRODUCTS
=============================================================================================
*/
  
--=============================
-- JOINING TABLES
--=============================
SELECT 
pn.prd_id,
pn.cat_id,
pn.prd_key,
pn.prd_nm,
pn.prd_cost,
pn.prd_line,
pn.prd_start_dt,
pc.cat,
pc.subcat,
pc.maintenance
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON pn.cat_id = pc.id
WHERE pn.prd_end_dt IS NULL  -- FILTER OUT ALL HISTORICAL DATA


--=============================
-- CHECK THE UNIQUENESS OR DUPLICATES OF PRD_ID >> EACH PRODUCT HAS ONLY ONE RECORD
--=============================

SELECT DISTINCT prd_id , COUNT(*)
FROM (
	SELECT 
	pn.prd_id,
	pn.cat_id,
	pn.prd_key,
	pn.prd_nm,
	pn.prd_cost,
	pn.prd_line,
	pn.prd_start_dt,
	pc.cat,
	pc.subcat,
	pc.maintenance
	FROM silver.crm_prd_info pn
	LEFT JOIN silver.erp_px_cat_g1v2 pc
	ON pn.cat_id = pc.id
	WHERE pn.prd_end_dt IS NULL  -- FILTER OUT ALL HISTORICAL DATA
)t GROUP BY prd_id
HAVING COUNT(*) >1

--=============================
-- SORT COLUMNS
-- RENAME COLUMNS
-- GENERATE PRIMARY KEY
-- CREATE VIEW
--=============================

CREATE VIEW gold.dim_products AS
	SELECT 
	ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt,pn.prd_key) AS product_key,
	pn.prd_id AS product_id,
	pn.prd_key AS product_number,
	pn.prd_nm AS product_name,
	pn.cat_id AS category_id,
	pc.cat AS category,
	pc.subcat AS subcategory,
	pc.maintenance  AS maintenance,
	pn.prd_cost AS cost,
	pn.prd_line AS product_line,
	pn.prd_start_dt AS start_date
	FROM silver.crm_prd_info pn
	LEFT JOIN silver.erp_px_cat_g1v2 pc
	ON pn.cat_id = pc.id
	WHERE pn.prd_end_dt IS NULL  -- FILTER OUT ALL HISTORICAL DATA


--============= 
-- SELECT * FROM gold.dim_products




/*
=============================================================================================
THIRD OBJECT : SALES
=============================================================================================
*/

--=============
-- SALES TABLE:
-- join tables to get 'surrogate key' instead of 'id'
-- rename columns
-- sort columns as fact schema ( Dimension Keys , Dates , Measures )
-- create view
--=============
CREATE VIEW gold.fact_sales AS
	SELECT 
	sls_ord_num AS order_number,
	pr.product_key,
	cu.customer_key,
	sls_order_dt AS order_date,
	sls_ship_dt AS ship_date,
	sls_due_dt AS due_date,
	sls_sales AS sales_amount,
	sls_quantity AS quantity,
	sls_price AS price
	FROM silver.crm_sales_details sd
	LEFT JOIN gold.dim_products pr
	ON sd.sls_prd_key = pr.product_number
	LEFT JOIN gold.dim_customers cu
	ON sd.sls_cust_id = cu.customer_id

--============= 
--SELECT * FROM gold.fact_sales

/*
=============================================================================================
CHECK RELATIONSHIPS BETWEEN FACT AND DIMENSIONS
=============================================================================================
*/

-- FOREGIN KEY INTEGRITY (DIMENSIONS)

SELECT *
FROM gold.fact_sales f
LEFT JOIN  gold.dim_products p
ON f.product_key = p.product_key
WHERE p.product_key IS NULL


SELECT *
FROM gold.fact_sales f
LEFT JOIN  gold.dim_customers c
ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL
