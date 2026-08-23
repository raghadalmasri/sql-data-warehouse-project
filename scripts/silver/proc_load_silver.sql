/*
=================================================
Stored Procedure : Load Silver Layer (Bronze --> Silver)
=================================================
Script Purpose:
This SP perform ETL (Extract , Transformation, Load ) process to populate the 'silver' schema tables from 'bronze' schema.

*/


CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
/*
========================================
silver.crm_cust_info 
=========================================
*/

PRINT '>> TRUNCATING TABLE: silver.crm_cust_info';
TRUNCATE TABLE silver.crm_cust_info;
PRINT '>> INSERTING DATA INTO: silver.crm_cust_info';
INSERT INTO silver.crm_cust_info (cst_id,cst_key,cst_firstname,cst_lastname, cst_gndr ,cst_marital_status,cst_create_date )

select cst_id,
cst_key,
TRIM(cst_firstname) AS cst_firstname ,    -- remove unwanted spaces
TRIM(cst_lastname) AS cst_lastname,
CASE UPPER(TRIM(cst_gndr))    -- data standardization & normalization & consistency
	WHEN 'F' THEN 'FEMALE'
	WHEN 'M' THEN 'MALE'
	ELSE 'n/a'              -- handling missing values
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
ROW_NUMBER() OVER(PARTITION BY cst_id order by cst_create_date DESC) AS flag_date       -- remove duplicates
FROM bronze.crm_cust_info
WHERE cst_id IS NOT NULL
)t
where flag_date=1



/*
========================================
silver.crm_prd_info 
=========================================
*/


-- WE HAVE TO ADJUST THE DATATYPE BEFORE INSERT DATA 

IF OBJECT_ID('silver.crm_prd_info','U') IS NOT NULL
	DROP TABLE silver.crm_prd_info;
CREATE TABLE silver.crm_prd_info (
prd_id INT,
cat_id NVARCHAR(50),
prd_key NVARCHAR(50),
prd_nm NVARCHAR(50),
prd_cost INT,
prd_line NVARCHAR(50),
prd_start_dt DATE,
prd_end_dt DATE,
dwh_create_date DATETIME2 DEFAULT GETDATE()

);

PRINT '>> TRUNCATING TABLE: silver.crm_prd_info';
TRUNCATE TABLE silver.crm_prd_info;
PRINT '>> INSERTING DATA INTO: silver.crm_prd_info';

INSERT INTO silver.crm_prd_info (prd_id,cat_id,prd_key,prd_nm,prd_cost,prd_line,prd_start_dt,prd_end_dt)
SELECT prd_id,
REPLACE (SUBSTRING(prd_key, 1 ,5 ), '-' , '_') AS cat_id,   -- Extract the first part of prd_key to be match with px_cat_g1v2 table
SUBSTRING (prd_key , 7 , LEN(prd_key)) AS prd_key,    -- Extract the second part of prd_key to be match with sales_details table
prd_nm,
ISNULL (prd_cost , 0) AS prd_cost,    -- handling missing values by converting null into 0
CASE UPPER(TRIM(prd_line))     -- data normalization & standardization
	WHEN 'M' THEN 'Mountain'
	WHEN 'R' THEN 'Road'
	WHEN 'S' THEN 'Other Sales' 
	WHEN 'T' THEN 'Touring'
	ELSE 'n/a'
END prd_line,
CAST(prd_start_dt AS DATE),       -- convert datatime2 into date 
CAST (LEAD(prd_start_dt) OVER (PARTITION BY prd_key Order by prd_start_dt)-1 AS DATE) as prd_end_dt   -- rebuild prd_end_dt = prd_start_dt of the 'next' - 1 day
FROM bronze.crm_prd_info




/*
========================================
silver.crm_sales_details 
=========================================
*/

IF OBJECT_ID('silver.crm_sales_details','U') IS NOT NULL
	DROP TABLE silver.crm_sales_details;
CREATE TABLE silver.crm_sales_details (
sls_ord_num NVARCHAR(50),
sls_prd_key NVARCHAR(50),
sls_cust_id INT,
sls_order_dt DATE,   -- change datatype from INT into DATE
sls_ship_dt DATE,    -- change datatype from INT into DATE
sls_due_dt DATE,     -- change datatype from INT into DATE
sls_sales INT,
sls_quantity INT,
sls_price INT,
dwh_create_date DATETIME2 DEFAULT GETDATE()

);
 

PRINT '>> TRUNCATING TABLE: silver.crm_sales_details';
TRUNCATE TABLE silver.crm_sales_details;
PRINT '>> INSERTING DATA INTO: silver.crm_sales_details';
INSERT INTO silver.crm_sales_details (
									sls_ord_num,sls_prd_key , sls_cust_id ,
									sls_order_dt, sls_ship_dt,sls_due_dt,
									sls_sales,sls_quantity ,sls_price )
SELECT sls_ord_num , 
sls_prd_key,
sls_cust_id,
CASE           -- Handling invalid date
	WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
	ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
END sls_order_dt,
CASE           -- Handling invalid date
	WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
	ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
END sls_ship_dt,
CASE           -- Handling invalid date
	WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
	ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
END sls_due_dt,

CASE     -- recalculate 'sales' if original value is missing or incorrect 
	WHEN sls_sales IS NULL OR sls_sales <=0 OR sls_sales != sls_quantity * ABS(sls_price) THEN sls_quantity * ABS(sls_price)
	ELSE sls_sales
END sls_sales,

sls_quantity,

CASE     -- recalculate 'price' if original value is missing or incorrect 
	WHEN sls_price IS NULL OR sls_price <=0 THEN sls_sales/NULLIF(sls_quantity,0 ) 
	ELSE sls_price
END sls_price
FROM bronze.crm_sales_details





/*
========================================
silver.erp_cust_az12 
=========================================
*/

PRINT '>> TRUNCATING TABLE: silver.erp_cust_az12';
TRUNCATE TABLE silver.erp_cust_az12;
PRINT '>> INSERTING DATA INTO: silver.erp_cust_az12';
INSERT INTO silver.erp_cust_az12 (cid , bdate , gen)
SELECT
CASE	WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid , 4, LEN(cid))    -- remove 'NAS' prefix if present
		ELSE cid
END cid,
CASE	WHEN bdate > GETDATE() THEN NULL      -- set future birthdate to 'NULL'
		ELSE bdate
END bdate,
CASE	WHEN UPPER(TRIM(gen)) IN ('F' ,'FEMALE') THEN 'Female' -- NORMALIZE GENDER VALUES AND HANDLE UNKNOWN CASES
		WHEN UPPER(TRIM(gen)) IN ('M' ,'MALE') THEN 'Male'
		ELSE 'n/a'
END gen
FROM bronze.erp_cust_az12



/*
========================================
silver.erp_loc_a101 
=========================================
*/

PRINT '>> TRUNCATING TABLE: silver.erp_loc_a101';
TRUNCATE TABLE silver.erp_loc_a101;
PRINT '>> INSERTING DATA INTO: silver.erp_loc_a101';
INSERT INTO silver.erp_loc_a101 (cid , cntry)
SELECT
REPLACE(cid , '-' , '')  cid,    -- Handling invalid values by removing '-'
CASE	WHEN TRIM(cntry)  = 'DE'  THEN 'Germany'     -- Normalize and Handle Missing or Blank country codes
		WHEN TRIM(cntry) = 'US' OR TRIM(cntry) = 'USA' THEN 'United States'
		WHEN TRIM(cntry) IS NULL OR TRIM(cntry)  = '' THEN 'n/a'
		ELSE TRIM(cntry)    -- save the country value without spaces
END cntry
FROM bronze.erp_loc_a101



/*
========================================
silver.erp_px_cat_g1v2
=========================================
*/

PRINT '>> TRUNCATING TABLE: silver.erp_px_cat_g1v2';
TRUNCATE TABLE silver.erp_px_cat_g1v2;
PRINT '>> INSERTING DATA INTO: silver.erp_px_cat_g1v2';
INSERT INTO silver.erp_px_cat_g1v2 (id, cat , subcat , maintenance)

SELECT id, cat , subcat , maintenance FROM bronze.erp_px_cat_g1v2

END
