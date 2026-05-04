-- Creating stored procedure for the silver load

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
		SET @batch_start_time = GETDATE();
			PRINT('====================================');
			PRINT('Loading Silver Table');
			PRINT('====================================');

			PRINT('Truncating the table')
	
		SET @start_time = GETDATE()
			TRUNCATE TABLE silver.crm_cust_info;
			PRINT('Inserting the data into the table')
			INSERT INTO silver.crm_cust_info(
			cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr, cst_create_date)
			SELECT cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname,
			TRIM(cst_lastname) AS cst_lastname,
			CASE
				WHEN TRIM(UPPER(cst_marital_status)) = 'S' THEN 'Single'
				WHEN TRIM(UPPER(cst_marital_status)) = 'M' THEN 'Married'
				ELSE'n/a'
				END  AS cst_marital_status,
			CASE
				WHEN TRIM(UPPER(cst_gndr)) = 'F' THEN 'Female'
				WHEN TRIM(UPPER(cst_gndr)) = 'M' THEN 'Male'
				ELSE 'n/a'
			END AS cst_gndr,
			cst_create_date
			FROM 
			(
			SELECT *,
			ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_state
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL
			)t
			WHERE flag_state = 1
		SET @end_time = GETDATE()
		PRINT('Loading Duration: '+ CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds')
		PRINT('------------------------------------')

		SET @start_time = GETDATE()
			PRINT('Truncating the table')
			TRUNCATE TABLE silver.crm_prd_info
			PRINT('Inserting the data into the table')
			INSERT INTO silver.crm_prd_info
			(prd_id, category_id, prd_key, prd_nm, prd_cost, prd_line, prd_start_dt, prd_end_dt)
			SELECT 
				prd_id,
				REPLACE(SUBSTRING(prd_key,1,5),'-','_') AS category_id, -- Extract category_id
				SUBSTRING(prd_key, 7 , LEN(prd_key)) AS prd_key, -- Extract prd_key
				TRIM(prd_nm) AS prd_nm,
				ISNULL(prd_cost,0) AS prd_cost, -- Handling NULL values to 0
				CASE UPPER(TRIM(prd_line))
					WHEN 'M' THEN 'Mountain'
					WHEN 'R' THEN 'Road'
					WHEN 'S' THEN 'Other Sales'
					WHEN 'T' THEN 'Touring'
					ELSE 'n/a'
				END AS prd_line,				-- Map product line codes to descriptive values 
				prd_start_dt,
				DATEADD(DAY,-1, LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt)) AS prd_end_dt -- Calcualte end date as obe day before the next start date
			FROM bronze.crm_prd_info
		SET @end_time = GETDATE()
		PRINT('Load Duration: '+ CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds')
		PRINT('------------------------------------')
		
		SET @start_time = GETDATE()
			PRINT('Truncating the table')
			TRUNCATE TABLE silver.crm_sales_details
			PRINT('Inserting the data into the table')
			INSERT INTO silver.crm_sales_details(
				sls_ord_num,
				sls_prd_key,
				sls_cust_id,
				sls_order_dt,
				sls_ship_dt,
				sls_due_dt,
				sls_sales,
				sls_quantity,
				sls_price)
			SELECT
				sls_ord_num,
				sls_prd_key,
				sls_cust_id,
				CASE
					WHEN LEN(sls_order_dt) != 8 OR sls_order_dt = 0 THEN NULL
					ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
				END sls_order_dt,										-- Handling invalid data
				CASE
					WHEN LEN(sls_ship_dt) != 8 OR sls_ship_dt = 0 THEN NULL
					ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
				END sls_ship_dt,										-- Handling invalid data
				CASE
					WHEN LEN(sls_due_dt) != 8 OR sls_due_dt = 0 THEN NULL
					ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
				END sls_due_dt,											-- Handling invalid data
				CASE
					WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity*ABS(sls_price)
					THEN sls_quantity*ABS(sls_price)
					ELSE sls_sales
				END AS sls_sales,										-- Recalculating sales if the original value is missing
				sls_quantity,
				CASE
					WHEN sls_price IS NULL OR sls_price <= 0
					THEN sls_sales / NULLIF(sls_quantity,0)
					ELSE sls_price
				END AS sls_price										-- Derive price is original value is missing/invalid
			FROM bronze.crm_sales_details
		SET @end_time = GETDATE()
		PRINT('Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds')
		PRINT('------------------------------------')

		SET @start_time = GETDATE()
			PRINT('Truncating the table')
			TRUNCATE TABLE silver.erp_cust_az12
			PRINT('Inserting the data into the table')
			INSERT INTO silver.erp_cust_az12(
				cid,
				bdate,
				GEN)
			SELECT 
				CASE
					WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))		----- Remove 'NAS' prefix id present
					ELSE cid
				END AS cid,
				CASE
					WHEN bdate > GETDATE() THEN NULL						----- Set future birthdates to NULL
					ELSE bdate
				END bdate,
				CASE														----- Normalize gender values and handle unknown cases
					WHEN UPPER(TRIM(GEN)) IN ('F' , 'FEMALE') THEN 'Female'
					WHEN UPPER(TRIM(GEN)) IN ('M' , 'MALE') THEN 'Male'
					ELSE 'n/a'
				END GEN
			FROM bronze.erp_cust_az12 
		SET @end_time = GETDATE()
		PRINT('Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds')
		PRINT('------------------------------------')
		
		SET @start_time = GETDATE()
			PRINT('Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds')
			PRINT('Truncating the table')
			TRUNCATE TABLE silver.erp_loc_a101
			PRINT('Inserting the data into the table')
			INSERT INTO silver.erp_loc_a101(
				cid, 
				cntry)
				SELECT 
					REPLACE(cid,'-','') AS cid,
					CASE
						WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
						WHEN UPPER(TRIM(cntry)) IN ('US','USA') THEN 'United States'
						WHEN UPPER(TRIM(cntry)) = '' OR cntry IS NULL THEN 'n/a'
						ELSE TRIM(cntry)
					END AS cntry
				FROM bronze.erp_loc_a101
			SET @end_time = GETDATE()
			PRINT('Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds')
			PRINT('------------------------------------')
			
			SET @start_time = GETDATE()
				PRINT('Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds')
				PRINT('Truncating the table')
				TRUNCATE TABLE silver.erp_px_cat_g1v2
				PRINT('Inserting the data into the table')
				INSERT INTO silver.erp_px_cat_g1v2(
				id,
				cat,
				subcat,
				maintenance
				)
				SELECT * FROM bronze.erp_px_cat_g1v2
			SET @end_time = GETDATE()
			PRINT('Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds')
			PRINT('--------------------------------------------------------');
			SET @batch_end_time = GETDATE();
			PRINT('Batch Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds')
		END TRY
		BEGIN CATCH
			PRINT('------------------------------------------');
			PRINT('ERROR PROCEDURE:'+' '+ ERROR_PROCEDURE());
			PRINT('ERROR MESSAGE:'+' '+ ERROR_MESSAGE());
			PRINT('ERROR NUMBER:'+' '+ CAST(ERROR_NUMBER() AS NVARCHAR));
			PRINT('ERROR LINE:'+' '+ CAST(ERROR_LINE() AS NVARCHAR));
			PRINT('------------------------------------------');
		END CATCH
	END
