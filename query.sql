-- Cleaning data with SQL: Data Science Job Posting on Glassdoor. 
-- Link to the dataset: https://www.kaggle.com/datasets/rashikrahmanpritom/data-science-job-posting-on-glassdoor

-- 1.Rename columns removing spaces
ALTER TABLE jobs
    CHANGE COLUMN `index` PostID INT,
    CHANGE COLUMN `Job Title` JobTitle VARCHAR(255),
    CHANGE COLUMN `Salary Estimate` SalaryEstimate VARCHAR(255),
    CHANGE COLUMN `Job Description` JobDescription TEXT,
    CHANGE COLUMN `Company Name` CompanyName VARCHAR(255),
    CHANGE COLUMN `Type of ownership` OwnershipType VARCHAR(255);


-- 2.Check for duplicate records
WITH RowNumCTE AS (
SELECT *, 
	ROW_NUMBER() OVER(
    PARTITION BY `JobTitle`,`SalaryEstimate`,`JobDescription`,`CompanyName`,`Location`
    ORDER BY `PostID`) as row_number
FROM jobs
)
SELECT *
FROM RowNumCTE
WHERE row_number >1;

-- We find 13 duplicate records: we should drop them from our TABLE

-- Delete duplicate records
DELETE 
FROM jobs
WHERE PostID IN (
    SELECT PostID 
    FROM (SELECT *, ROW_NUMBER() OVER(
            PARTITION BY `JobTitle`,`SalaryEstimate`,`JobDescription`,`CompanyName`,`Location`
            ORDER BY `PostID`) as row_number
           	FROM jobs) AS RowNumCTE
            WHERE row_number > 1
         );


-- 3.Clean and split the salary column into 2 different columns: SalaryMin, SalaryMax
-- Remove symbols first

UPDATE jobs
SET SalaryEstimate = TRIM(REPLACE(REPLACE(SalaryEstimate,'$',''),'K',''));

-- Identify the minimum salary Estimate
SELECT SUBSTRING_INDEX(SalaryEstimate,'-',1) AS SalaryMin
FROM jobs

-- Identify the maximum salary Estimate
SELECT SUBSTRING_INDEX(SUBSTRING_INDEX(SalaryEstimate,'(',1),'-',-1) AS SalaryMax
FROM jobs

-- Create the corresponding columns
ALTER TABLE jobs
ADD SalaryMin INT;
UPDATE jobs
SET SalaryMin = SUBSTRING_INDEX(SalaryEstimate,'-',1); 

ALTER TABLE jobs
ADD SalaryMax INT;
UPDATE jobs
SET SalaryMax = SUBSTRING_INDEX(SUBSTRING_INDEX(SalaryEstimate,'(',1),'-',-1); 

-- 4.Clean the CompanyName column: the rating ended up into this column by mistake

-- Find the dirty records
SELECT CompanyName
FROM jobs
WHERE `CompanyName` REGEXP '[0-9]';

-- Dirty vs Clean records
SELECT CompanyName, TRIM(REPLACE(REGEXP_REPLACE(CompanyName, '[0-9]', ''),'.',''))
FROM jobs;

-- Update column
UPDATE jobs
SET CompanyName = TRIM(REPLACE(REGEXP_REPLACE(CompanyName, '[0-9]', ''),'.',''));


-- 5.Split Location into City and State columns
-- Look at the distinct value for the City column
WITH SplitCTE AS(
SELECT SUBSTRING_INDEX(`Location`,',',1) AS City, SUBSTRING_INDEX(`Location`,',',-1) AS State
FROM jobs)
SELECT DISTINCT City
FROM SplitCTE;

-- Create columns
ALTER TABLE jobs
ADD COLUMN City VARCHAR(50);
UPDATE jobs
SET City = TRIM(SUBSTRING_INDEX(`Location`,',',1));

ALTER TABLE jobs
ADD COLUMN State VARCHAR(50);
UPDATE jobs
SET State = TRIM(SUBSTRING_INDEX(`Location`,',',-1));

-- We can identify values like 'California', 'United States', 'Remote', 'New Jersey', 'Texas','Utah'
-- We need to change them into 'Unknown' values
UPDATE jobs
SET City =
CASE WHEN City IN ('California', 'United States', 'Remote', 'New Jersey', 'Texas','Utah') THEN 'Unkwown'
ELSE City
END;
    

-- The same for the State column, but we change the states into their abbreviated version ('CA','TX'...)
UPDATE jobs
SET State = 
	CASE WHEN State IN ('United States', 'Remote') THEN 'Unkwown' 
		WHEN State = 'California' THEN 'CA' 
        WHEN State = 'New Jersey' THEN 'NJ' 
        WHEN State = 'Texas' THEN 'TX' 
        WHEN State = 'Utah' THEN 'UT' 
        ELSE State
END
;

-- 6.Rating has some values outside of the range 0-5
SELECT rating
FROM jobs
WHERE Rating NOT BETWEEN 0 AND 5

-- 39 values are -1.0: we should change them to NULL values (if we change them to 'N/A' we should change the field type)

UPDATE jobs
SET Rating =
    CASE WHEN Rating = -1.0 THEN NULL 
        ELSE Rating
END
;

-- 7.Change the -1 into Unknown values for Company Size

SELECT DISTINCT Size
FROM jobs

UPDATE jobs
SET Size =
    CASE WHEN Size = -1.0 THEN 'Unknown' 
        ELSE Size
END
;

-- 8. Clean OwnershipType

SELECT DISTINCT OwnershipType
FROM jobs


-- We can change the format of some values like 'Public' or 'Private' while also dealing with the missing values like the previous column.

UPDATE jobs
SET OwnershipType =
CASE WHEN OwnershipType = 'Nonprofit Organization' THEN 'Nonprofit'
	WHEN OwnershipType = '-1' THEN 'Unknown'
    WHEN OwnershipType = 'Company - Public' THEN 'Public'
    WHEN OwnershipType IN ('Private Practice / Firm', 'Company - Private') THEN 'Private'
    WHEN OwnershipType = 'Other Organization' THEN 'Other'
	ELSE OwnershipType
END
;

-- 9. Clean Industry: from -1 to Unknown values
SELECT DISTINCT Industry
FROM jobs

UPDATE jobs
SET Industry =
    CASE WHEN Industry = '-1' THEN 'Unknown' 
        ELSE Industry
END
;


-- 10. Clean Sector: from -1 to Unknown values
SELECT DISTINCT Sector
FROM jobs

UPDATE jobs
SET Sector =
    CASE WHEN Sector = '-1' THEN 'Unknown' 
        ELSE Sector
END
;

-- 11. Clean Revenue: more than 220 records have Unknown or -1 values. We can drop this column

SELECT Revenue, COUNT(Revenue)
from jobs
GROUP BY Revenue
ORDER BY COUNT(Revenue) DESC;

ALTER TABLE jobs
DROP COLUMN Revenue
;


-- 12. We do the same for Competitors, since 488 records have value equal to -1

SELECT `Competitors`, COUNT(`Competitors`)
from jobs
GROUP BY `Competitors`
ORDER BY COUNT(`Competitors`) DESC;


-- 13. We can also drop the Location (we split it into 2 columns) and Headquarters (we are not interested in this information) columns

ALTER TABLE jobs
DROP COLUMN Location
;

ALTER TABLE jobs
DROP COLUMN Headquarters
;


-- 14. Create a column to categorize the job roles, since there are many different job titles in the postings

SELECT JobTitle,
CASE
  WHEN JobTitle REGEXP 'data science|data scientist' THEN 'Data Scientist'
  WHEN JobTitle REGEXP 'data analyst|analyst' THEN 'Data Analyst'
  WHEN JobTitle REGEXP 'data engineer' THEN 'Data Engineer'
  WHEN JobTitle REGEXP 'machine learning|ai' THEN 'Machine Learning Engineer'
  WHEN JobTitle REGEXP 'business intelligence|bi analyst' THEN 'BI Analyst'
  ELSE 'Other'
END AS JobRole
FROM jobs

ALTER TABLE jobs
ADD JobRole VARCHAR(255);

UPDATE jobs
SET JobRole =
CASE
  WHEN JobTitle REGEXP 'data science|data scientist' THEN 'Data Scientist'
  WHEN JobTitle REGEXP 'data analyst|analyst' THEN 'Data Analyst'
  WHEN JobTitle REGEXP 'data engineer' THEN 'Data Engineer'
  WHEN JobTitle REGEXP 'machine learning|ai' THEN 'Machine Learning Engineer'
  WHEN JobTitle REGEXP 'business intelligence|bi analyst' THEN 'BI Analyst'
  ELSE 'Other'
END;


-- 15. Create columns for the skills required for the job in the job Description: look for keywords in the description

ALTER TABLE jobs
ADD Excel BOOLEAN;

ALTER TABLE jobs
ADD DbSQL BOOLEAN;

ALTER TABLE jobs
ADD Python BOOLEAN;

ALTER TABLE jobs
ADD PowerBi BOOLEAN;

ALTER TABLE jobs
ADD Tableau BOOLEAN;

UPDATE jobs
SET Excel =
CASE
  WHEN `JobDescription` REGEXP 'excel' THEN 1
  ELSE 0
END;

UPDATE jobs
SET DbSQL =
CASE
  WHEN `JobDescription` REGEXP 'sql|mysql|rdbms' THEN 1
  ELSE 0
END;

UPDATE jobs
SET Python =
CASE
  WHEN `JobDescription` REGEXP 'python|pandas|numpy|pyspark|scipy' THEN 1
  ELSE 0
END;

UPDATE jobs
SET PowerBi =
CASE
  WHEN `JobDescription` REGEXP 'powerbi|powerquery' THEN 1
  ELSE 0
END;

UPDATE jobs
SET Tableau =
CASE
  WHEN `JobDescription` REGEXP 'tableau' THEN 1
  ELSE 0
END;
