# Data Lake Project (S3 + Athena + Glue)

This project demonstrates a real-world scenario of consolidating regional sales data into a unified analytical layer.

1. Data Ingestion:
Regional CSV files (sales_south.csv and sales_north.csv) are uploaded to the S3 bucket. These files contain raw transaction data such as product, value, and date.

2. Automated Schema Inference:
The Glue Crawler identifies that although the data comes from different files, they share a common structure. It creates a single sales table in the Data Catalog that represents the union of all files in the folder.

3. Performance Optimization (ETL):
Using Athena's CTAS (Create Table As Select), the raw CSV data is transformed into Apache Parquet.

## AWS Resources used in this project
This project implements a serverless data pipeline with the following components:

1. Storage (Amazon S3)
The S3 Bucket serves as the "heart" of the Data Lake, providing durable storage for physical files (CSV, JSON, Parquet). In this implementation, the data is logically partitioned into:

/raw-data/: Landing zone for raw, unprocessed files.

/athena-results/: Dedicated path for storing query execution logs and results.

2. Data Catalog (AWS Glue Catalog)
The Glue Catalog acts as a centralized metadata inventory. It doesn't store the actual data but maintains the "recipe"—defining the schema (columns, data types) and the physical location of the files.

3. Automatic Discovery (AWS Glue Crawler)
The Glue Crawler provides the intelligence for the project. It automatically scans designated S3 folders, identifies file formats (e.g., CSV), infers headers/schemas, and creates or updates table definitions in the Data Catalog.
The Crawler is configured with a specific schema_change_policy:

Update Behavior: UPDATE_IN_DATABASE ensures that if new files bring new columns, the Data Catalog reflects them immediately.

Delete Behavior: DEPRECATE_IN_DATABASE prevents accidental data loss in the catalog if a raw file is temporarily moved or renamed.

If this project were to scale to millions of daily files, a transition to Glue Jobs with Bookmarks would be the  next step to prevent re-processing the entire Raw layer.

4. Serverless Query Engine (Amazon Athena)
Athena enables high-performance SQL queries  directly against files stored in S3. As a serverless service, there is no infrastructure to manage, and you only pay for the amount of data scanned per query.
Athena Charges only for the data scanned during the conversion to Parquet ($5.00 per TB). Since the current dataset is small, the cost is virtually zero.


## Testing guide

1. Data Ingestion (Raw Layer)
Create two dummy datasets (South and North regions) and upload them to the S3 Raw zone.

```powershell
$BUCKET_NAME = "data-lake-test"

# Create first dataset
$csvSouth = @"
id,product,value,date
1,Notebook,5000,2023-10-01
2,Mouse,150,2023-10-02
3,Keyboard,300,2023-10-03
"@
$csvSouth | Out-File -FilePath "sales_south.csv" -Encoding utf8

# Create second dataset
$csvNorth = @"
id,product,value,date
101,Monitor,1200,2026-02-15
102,Gamer Chair,1500,2026-02-16
"@
$csvNorth | Out-File -FilePath "sales_north.csv" -Encoding utf8

# Upload files to S3
aws s3 cp sales_south.csv "s3://$BUCKET_NAME/raw-data/sales/sales_south.csv"
aws s3 cp sales_north.csv "s3://$BUCKET_NAME/raw-data/sales/sales_north.csv"

```

3. Data Discovery (AWS Glue)
Trigger the Crawler to scan the S3 bucket and populate the Glue Data Catalog.

```powershell

# Start the Crawler
aws glue start-crawler --name "s3-data-crawler"

# Monitor status (Execute until it returns 'READY')
aws glue get-crawler --name "s3-data-crawler" --query "Crawler.State" --output text

```

4. Data Transformation (CTAS - Parquet)
Convert the raw CSV data into optimized Parquet format using a Create Table As Select (CTAS) query in Athena.

```powershell
# Clean up previous metadata and files if retrying
aws athena start-query-execution `
    --query-string "DROP TABLE IF EXISTS sales_data_db.sales_processed;" `
    --result-configuration OutputLocation="s3://$BUCKET_NAME/athena-results/"


# Run CTAS Query
$ctas_query = @"
CREATE TABLE sales_data_db.sales_processed
WITH (
    format = 'PARQUET',
    parquet_compression = 'SNAPPY',
    external_location = 's3://$BUCKET_NAME/processed-data/'
) AS
SELECT 
    CAST(id AS BIGINT) as id,
    product,
    CAST(value AS DECIMAL(10,2)) as price,
    CAST(date_parse(date, '%Y-%m-%d') AS DATE) as sale_date
FROM sales_data_db.sales;
"@

aws athena start-query-execution `
    --query-string "$ctas_query" `
    --work-group "primary_analysis" `
    --query-execution-context Database=sales_data_db `
    --result-configuration OutputLocation="s3://$BUCKET_NAME/athena-results/"

```

5. Querying Results
Retrieve the final unified data in a readable format.

```powershell
# Run a select query
$query = "SELECT DISTINCT * FROM sales_data_db.sales_processed ORDER BY sale_date DESC;"

$ID = aws athena start-query-execution `
    --query-string "$query" `
    --work-group "primary_analysis" `
    --query-execution-context Database=sales_data_db `
    --result-configuration OutputLocation="s3://$BUCKET_NAME/athena-results/" `
    --query "QueryExecutionId" --output text

# Wait for execution and get results in YAML format
Start-Sleep -Seconds 5

aws athena get-query-results --query-execution-id $ID `
    --query "ResultSet.Rows[*].Data[*].VarCharValue" --output yaml

```
	
## Troubleshooting

Permissions: Ensure your IAM User has Administrator Access or specific policies for S3, Athena, and Glue.

Costs: Athena charges $5 per TB scanned. Using Parquet reduces costs significantly by only scanning the columns used in the query.

Cleanup
Remove all resources

```powershell
# Empty the S3 Bucket
aws s3 rm "s3://$BUCKET_NAME" --recursive

# Force delete the Athena Workgroup
aws athena delete-work-group --work-group "primary_analysis" --recursive-delete-option

terraform destroy -auto-approve
```