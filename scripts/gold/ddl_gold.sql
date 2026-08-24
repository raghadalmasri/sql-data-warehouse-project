/*
=================================================
DDL Script : Create Gold Views
=================================================
script purpose:
this script create views for the 'Gold' Layer in the data warehouse.
the Gold layer represent the final Dimension and Fact tables (Star Schema)..
each view perform transformations and combines data from Silver Layer to produce a clean, enriched , and business-ready dataset.

*/
/*
=====================================================
Create Dimension : gold.dim_customers 
=====================================================
1- RENAME COLUMNS
2- SORT COLUMNS
3- GENERATE SURROGATE KEY
4- CREATE VIEW
============================= 
*/
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


/*
=====================================================
Create Dimension : gold.dim_products
=====================================================
-- SORT COLUMNS
-- RENAME COLUMNS
-- GENERATE PRIMARY KEY
-- CREATE VIEW
===============================
*/
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

/*
=====================================================
Create Fact : gold.fact_sales
=====================================================
-- SALES TABLE:
-- join tables to get 'surrogate key' instead of 'id'
-- rename columns
-- sort columns as fact schema ( Dimension Keys , Dates , Measures )
-- create view
================================
*/
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
