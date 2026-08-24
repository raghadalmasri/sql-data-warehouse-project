/* crm_cust_info */
--=================================================
-- 1- CHECK FOR NULLS OR DUPLICATS IN PRIMERY KEY
-- EXPECTATION : NO RESULT
--=================================================
select * from bronze.crm_cust_info

SELECT 
cst_id, 
count(*) 
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING count(*) > 1

-- SOLVE (1):
select * 
from
(
SELECT *,
ROW_NUMBER() OVER(PARTITION BY cst_id order by cst_create_date DESC) AS flag_date
FROM bronze.crm_cust_info
WHERE cst_id IS NOT NULL
)t
where flag_date=1 


--=================================================
-- 2- CHECK FOR UNWANTED SPACES (ONLY CHECK THE STRING COLUMNS)
-- EXPECTATION :  NO RESULTS
--=================================================
SELECT * FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname)
--WHERE cst_lastname != TRIM(cst_lastname)
--WHERE cst_marital_status != TRIM(cst_marital_status)
--WHERE cst_gndr != TRIM(cst_gndr)



-- SOLVE (2) : BY UPDATING THE PREVIOUS QUERY 

select cst_id,
cst_key,
TRIM(cst_firstname) AS cst_firstname ,
TRIM(cst_lastname) AS cst_lastname,
cst_marital_status,
cst_gndr,
cst_create_date
from
(
SELECT *,
ROW_NUMBER() OVER(PARTITION BY cst_id order by cst_create_date DESC) AS flag_date
FROM bronze.crm_cust_info
WHERE cst_id IS NOT NULL
)t
where flag_date=1

--=================================================
-- 3- DATA STANDARDIZATION & CONSISTENCY
-- CHECK THE CONSISTANCY OF VALUES IN LOW CARDINALITY COLUMNS  (cst_gndr & cst_marital_status)
--=================================================
SELECT DISTINCT cst_gndr FROM bronze.crm_cust_info
SELECT DISTINCT cst_marital_status FROM bronze.crm_cust_info

--SOLVE (3) :

select cst_id,
cst_key,
TRIM(cst_firstname) AS cst_firstname ,
TRIM(cst_lastname) AS cst_lastname,
CASE UPPER(TRIM(cst_gndr)) 
	WHEN 'F' THEN 'FEMALE'
	WHEN 'M' THEN 'MALE'
	ELSE 'n/a'
END cst_gndr,

CASE UPPER(TRIM(cst_marital_status)) 
	WHEN 'S' THEN 'SINGLE'
	WHEN 'M' THEN 'MARRIED'
	ELSE 'n/a'
END cst_marital_status,
cst_create_date
FROM
(
SELECT *,
ROW_NUMBER() OVER(PARTITION BY cst_id order by cst_create_date DESC) AS flag_date
FROM bronze.crm_cust_info
WHERE cst_id IS NOT NULL
)t
where flag_date=1







--===================================================================================================
/* crm_prd_info */
--===================================================================================================
select * from bronze.crm_prd_info

--=================================================
-- 1- CHECK FOR NULLS OR DUPLICATS IN PRIMERY KEY
-- EXPECTATION : NO RESULT --> correct , no issue to solve
--=================================================

SELECT 
prd_id, 
count(*) 
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING count(*) > 1 or prd_id IS NULL

--=================================================
-- 2- Extract cat_id from  prd_key column (first 5 character) and replace '-' to '_' to match with px_cat_g1v2 table
-- and check
-- then extract the second part of prd_key  to match with sales_details table (sls_prd_key col)
--================================================

select *,
REPLACE (SUBSTRING(prd_key, 1 ,5 ), '-' , '_') AS cat_id
from bronze.crm_prd_info
--WHERE REPLACE (SUBSTRING(prd_key, 1 ,5 ), '-' , '_') NOT IN (select distinct id from bronze.erp_px_cat_g1v2)
--select DISTINCT id from bronze.erp_px_cat_g1v2  WHERE id like 'CO_%'


select *,
REPLACE (SUBSTRING(prd_key, 1 ,5 ), '-' , '_') AS cat_id,
SUBSTRING (prd_key , 7 , LEN(prd_key)) AS prd_key
from bronze.crm_prd_info
--where SUBSTRING (prd_key , 7 , LEN(prd_key)) not in
--(select distinct sls_prd_key from bronze.crm_sales_details)




--=================================================
-- 3- CHECK FOR UNWANTED SPACES (ONLY CHECK THE STRING COLUMNS)
-- EXPECTATION :  NO RESULTS --> correct , no issue to solve 
--=================================================
SELECT * 
FROM bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm)


--=================================================
-- 4- CHECK FOR NULLS  OR NEGATIVE NUMBERS
-- EXPECTATION :  NO RESULTS
--=================================================
SELECT * 
FROM bronze.crm_prd_info
WHERE prd_cost <0 or prd_cost is null

-- solve :

select prd_id,
prd_key,
REPLACE (SUBSTRING(prd_key, 1 ,5 ), '-' , '_') AS cat_id,
SUBSTRING (prd_key , 7 , LEN(prd_key)) AS prd_key,
prd_nm,
ISNULL (prd_cost , 0) AS prd_cost,
prd_line , prd_start_dt , prd_end_dt
from bronze.crm_prd_info



--=================================================
-- 5- DATA STANDARDIZATION & CONSISTENCY
-- CHECK THE CONSISTANCY OF VALUES IN LOW CARDINALITY COLUMNS  (prd_line)
--=================================================
SELECT DISTINCT prd_line FROM bronze.crm_prd_info

-- solve :

select prd_id,
prd_key,
REPLACE (SUBSTRING(prd_key, 1 ,5 ), '-' , '_') AS cat_id,
SUBSTRING (prd_key , 7 , LEN(prd_key)) AS prd_key,
prd_nm,
ISNULL (prd_cost , 0) AS prd_cost,
CASE UPPER(TRIM(prd_line))
	WHEN 'M' THEN 'Mountain'
	WHEN 'R' THEN 'Road'
	WHEN 'S' THEN 'Other Sales' 
	WHEN 'T' THEN 'Touring'
	ELSE 'n/a'
END prd_line,
prd_start_dt , prd_end_dt
from bronze.crm_prd_info



--=================================================
-- 6- CHECK FOR INVALID DATE ORDER
-- SHOULD prd_end_dt > prd_start_dt
-- to solve the issue :  we will rebuild the end_date by using this rule--> // end_date = start_date of the 'next' - 1 day //
--=================================================
-- check 

select * from bronze.crm_prd_info
where prd_end_dt < prd_start_dt

-- solve:

SELECT prd_id,
prd_key,
REPLACE (SUBSTRING(prd_key, 1 ,5 ), '-' , '_') AS cat_id,
SUBSTRING (prd_key , 7 , LEN(prd_key)) AS prd_key,
prd_nm,
ISNULL (prd_cost , 0) AS prd_cost,
CASE UPPER(TRIM(prd_line))
	WHEN 'M' THEN 'Mountain'
	WHEN 'R' THEN 'Road'
	WHEN 'S' THEN 'Other Sales' 
	WHEN 'T' THEN 'Touring'
	ELSE 'n/a'
END prd_line,
CAST(prd_start_dt AS DATE), 
CAST (LEAD(prd_start_dt) OVER (PARTITION BY prd_key Order by prd_start_dt)-1 AS DATE) as prd_end_dt

FROM bronze.crm_prd_info





--===================================================================================================
/* crm_sales_details */
--===================================================================================================
SELECT * 
FROM bronze.crm_sales_details

--=================================================
-- 1- CHECK FOR UNWANTED SPACES
-- EXPECTATION :  NO RESULTS --> correct , no issue to solve 
--=================================================
SELECT * 
FROM bronze.crm_sales_details
WHERE sls_ord_num != TRIM(sls_ord_num)


--=================================================
-- 2- CHECK sls_cust_id & sls_prd_key columns , should be match with other tables
-- EXPECTATION :  NO RESULTS
--=================================================

SELECT * 
FROM bronze.crm_sales_details
WHERE sls_cust_id NOT IN (
SELECT cst_id FROM bronze.crm_cust_info
)

SELECT * 
FROM bronze.crm_sales_details
WHERE sls_prd_key NOT IN (
SELECT prd_key FROM silver.crm_prd_info
)

--=================================================
-- 3- CHECK FOR INVALID DATE, (0) VALUES , OR LENGTH != 8 
-- (sls_order_dt , sls_ship_dt , sls_due_dt)  CONVERT from   'INT' -->  'VARCHAR' -->  'DATE'
-- CHECK sls_order_dt < sls_ship_dt  & sls_order_dt < sls_due_dt 
--=================================================

SELECT * 
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0 
or len(sls_order_dt) !=8 
or sls_order_dt <= 19000101
or sls_order_dt >= 20230000


--solve (1):
SELECT sls_ord_num , 
sls_prd_key,
sls_cust_id,
CASE 
	WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
	ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
END sls_order_dt,
CASE 
	WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
	ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
END sls_ship_dt,
CASE 
	WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
	ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
END sls_due_dt,
sls_sales,
sls_quantity,
sls_price
FROM bronze.crm_sales_details

-- CHECK sls_order_dt < sls_ship_dt 
SELECT * 
FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt 



--=================================================
-- 4- CHECK FOR DATA CONSISTENCY : BETWEEN SALES, QUANTITY, PRICE
-->> SALES = QUANTITY * PRICE
-->> VALUES MUST NOT BE : ZERO , NEGATIVE , OR NULL 
--=================================================

SELECT sls_sales, 
sls_quantity ,
sls_price
FROM bronze.crm_sales_details
WHERE sls_sales != (sls_quantity * sls_price)
OR sls_sales IS NULL OR  sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR  sls_quantity <=0 OR sls_price <=0
ORDER BY sls_sales, 
sls_quantity ,
sls_price

-- SOLVE (2):
SELECT sls_ord_num , 
sls_prd_key,
sls_cust_id,
CASE 
	WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
	ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
END sls_order_dt,
CASE 
	WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
	ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
END sls_ship_dt,
CASE 
	WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
	ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
END sls_due_dt,

CASE  
	WHEN sls_sales IS NULL OR sls_sales <=0 OR sls_sales != sls_quantity * ABS(sls_price) THEN sls_quantity * ABS(sls_price)
	ELSE sls_sales
END sls_sales,

sls_quantity,

CASE
	WHEN sls_price IS NULL OR sls_price <=0 THEN sls_sales/NULLIF(sls_quantity,0 ) 
	ELSE sls_price
END sls_price

FROM bronze.crm_sales_details



--===================================================================================================
/* erp_cust_az12 */
--===================================================================================================
SELECT * 
FROM bronze.erp_cust_az12

--=================================================
-- 1-- CHECK FOR UNMATCHING cid with cst_key
--=================================================

SELECT * 
FROM bronze.erp_cust_az12
WHERE cid NOT IN (SELECT cst_key FROM silver.crm_cust_info)


-- SOLVE 1:
SELECT cid ,
CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid , 4, LEN(cid))
	ELSE cid
END cid,
bdate,
gen 
FROM bronze.erp_cust_az12
WHERE CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid , 4, LEN(cid))  -- CHECK AGAIN AFTER TRANSFORMATION
	ELSE cid
END NOT IN  (SELECT cst_key FROM silver.crm_cust_info)

--=================================================
-- 2-- CHECK FOR OUT OF RANGE 'bdate'
--=================================================
SELECT * 
FROM bronze.erp_cust_az12
WHERE bdate < '1924-01-01' OR bdate > GETDATE()

-- SOLVE 2:

SELECT 
CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid , 4, LEN(cid))
	ELSE cid
END cid,
CASE WHEN bdate > GETDATE() THEN NULL
	ELSE bdate
END bdate,
gen 
FROM bronze.erp_cust_az12

--=================================================
-- 3 -- CHECK FOR DATA STANDARDIZATION AND CONSISTENCY
--=================================================
SELECT DISTINCT gen
FROM bronze.erp_cust_az12


-- SOLVE 3:

SELECT
CASE	WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid , 4, LEN(cid))
		ELSE cid
END cid,
CASE	WHEN bdate > GETDATE() THEN NULL
		ELSE bdate
END bdate,
CASE	WHEN UPPER(TRIM(gen)) IN ('F' ,'FEMALE') THEN 'Female'
		WHEN UPPER(TRIM(gen)) IN ('M' ,'MALE') THEN 'Male'
		ELSE 'n/a'
END gen
FROM bronze.erp_cust_az12




--===================================================================================================
/* erp_loc_a101*/
--===================================================================================================
SELECT * 
FROM bronze.erp_loc_a101

--=================================================
-- 1-- CHECK FOR UNMATCHING cid with cst_key
--=================================================

SELECT * 
FROM bronze.erp_loc_a101
WHERE cid NOT IN (SELECT cst_key FROM silver.crm_cust_info)


-- SOLVE 1:
SELECT 
REPLACE(cid , '-' , '')  cid,
cntry
FROM bronze.erp_loc_a101
WHERE REPLACE(cid , '-' , '') NOT IN (SELECT cst_key FROM silver.crm_cust_info) -- check again

--=================================================
-- 2 -- CHECK FOR DATA STANDARDIZATION AND CONSISTENCY
--=================================================

SELECT DISTINCT cntry 
FROM bronze.erp_loc_a101
ORDER BY cntry

-- SOLVE 2:
SELECT
REPLACE(cid , '-' , '')  cid,
CASE	WHEN TRIM(cntry)  = 'DE'  THEN 'Germany'
		WHEN TRIM(cntry) = 'US' OR TRIM(cntry) = 'USA' THEN 'United States'
		WHEN TRIM(cntry) IS NULL OR TRIM(cntry)  = '' THEN 'n/a'
		ELSE TRIM(cntry)
END cntry
FROM bronze.erp_loc_a101

-- TO CHECK AGAIN
SELECT DISTINCT cntry as old_cntry,
CASE	WHEN TRIM(cntry)  = 'DE'  THEN 'Germany'
		WHEN TRIM(cntry) = 'US' OR TRIM(cntry) = 'USA' THEN 'United States'
		WHEN TRIM(cntry) IS NULL OR TRIM(cntry)  = '' THEN 'n/a'
		ELSE TRIM(cntry)
END cntry
FROM bronze.erp_loc_a101
ORDER BY cntry



--===================================================================================================
/* erp_px_cat_g1v2*/
--===================================================================================================
SELECT * 
FROM bronze.erp_px_cat_g1v2

--=================================================
-- 1-- CHECK FOR UNMATCHING cid with cst_key
-- CORRECT -->> NO ISSUE TO SOLVE
--=================================================

SELECT * 
FROM bronze.erp_px_cat_g1v2
WHERE id NOT IN (
SELECT DISTINCT cat_id FROM silver.crm_prd_info)


--=================================================
-- 2-- CHECK FOR UNWANTED SPACES in 'cat' & 'subcat' & 'maintenance'
-- NO ISSUE
--=================================================

SELECT *
FROM bronze.erp_px_cat_g1v2
WHERE cat != TRIM(cat) OR subcat != TRIM(subcat) OR maintenance != TRIM(maintenance)


--=================================================
-- 3-- CHECK FOR CONSISTENCY
-- NO ISSUE
--=================================================

SELECT DISTINCT cat
FROM bronze.erp_px_cat_g1v2

SELECT DISTINCT subcat
FROM bronze.erp_px_cat_g1v2


SELECT DISTINCT maintenance
FROM bronze.erp_px_cat_g1v2
