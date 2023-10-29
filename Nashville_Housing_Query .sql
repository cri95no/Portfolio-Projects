-- Data cleaning ‘nashville_housing’ table: the dataset contains real estate sales for more than 55ooo records

SELECT * FROM nashville_housing LIMIT 5;

-- Change date to YYYY-MM-DD format

SELECT SaleDate, DATE_FORMAT(STR_TO_DATE(SaleDate, '%M %d, %Y'), '%Y-%m-%d') AS SaleDateConverted FROM nashville_housing;

-- Add a ‘SaleDateConverted’ field

ALTER TABLE nashville_housing
ADD SaleDateConverted DATE;
UPDATE nashville_housing
SET SaleDateConverted = DATE_FORMAT(STR_TO_DATE(SaleDate, '%M %d, %Y'), '%Y-%m-%d');

-- Drop ‘SaleDate’ and move ‘SaleDateConverted’ in its place

ALTER TABLE nashville_housing
DROP COLUMN SaleDate;
ALTER TABLE nashville_housing
MODIFY COLUMN SaleDateConverted DATE AFTER PropertyAddress;

--------------------------------------------------------------------------------------------------------------------------------------

-- Some records have a space instead of NULL value. Change ' ' to NULL for the PropertyAddress field.

UPDATE nashville_housing
SET PropertyAddress = NULL
WHERE PropertyAddress IS NOT NULL AND TRIM(PropertyAddress) = '';

-- We don't have an address for some records. But we know that if two records share a ParcelId, then they have the same Address. We can self-join the table to identify missing addresses. 

SELECT a.UniqueID, a.ParcelID, a.PropertyAddress, b.UniqueID,b.ParcelID, b.PropertyAddress
FROM nashville_housing a 
JOIN nashville_housing b 
ON a.ParcelID = b.ParcelID AND a.UniqueID <>b.UniqueID
WHERE a.PropertyAddress IS NULL
 

-- IFNULL: if a record has a missing address, then it assigns the address of the record with a common ParcelID

Select a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, IFNULL(a.PropertyAddress,b.PropertyAddress)
From nashville_housing a
JOIN nashville_housing b
	on a.ParcelID = b.ParcelID
	AND a.UniqueID <> b.UniqueID
Where a.PropertyAddress IS NULL
 

UPDATE nashville_housing a
JOIN nashville_housing b ON a.ParcelID = b.ParcelID AND a.UniqueID <> b.UniqueID
SET a.PropertyAddress = IFNULL(a.PropertyAddress, b.PropertyAddress)
WHERE a.PropertyAddress IS NULL;

--------------------------------------------------------------------------------------------------------------------------------------
-- Breaking out Address and City from the PropertyAddress field

-- Split of PropertyAddress 

SELECT SUBSTRING_INDEX(PropertyAddress, ',', 1) AS SplitAddress,
SUBSTRING_INDEX(PropertyAddress, ',', -1) AS SplitCity
FROM nashville_housing;
 
-- Add fields for the address and the city

ALTER TABLE nashville_housing
ADD PropertySplitAddress VARCHAR(255);
UPDATE nashville_housing
SET PropertySplitAddress = SUBSTRING_INDEX(PropertyAddress, ',', 1);

ALTER TABLE nashville_housing
ADD PropertySplitCity VARCHAR(255);
UPDATE nashville_housing
SET PropertySplitCity = SUBSTRING_INDEX(PropertyAddress, ',', -1);

-- Do the same for OwnerAddress (split into Address, City and State)

SELECT OwnerAddress, 
SUBSTRING_INDEX(OwnerAddress,',',1) AS SplitOwnerAddress,
SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress,',',-2),',',1) AS SplitOwnerCity,
SUBSTRING_INDEX(OwnerAddress,',',-1) AS SplitOwnerCity
FROM nashville_housing
 
-- Add the corresponding 3 fields

ALTER TABLE nashville_housing
ADD OwnerSplitAddress VARCHAR(255);
UPDATE nashville_housing
SET OwnerSplitAddress = SUBSTRING_INDEX(OwnerAddress,',',1);

ALTER TABLE nashville_housing
ADD OwnerSplitCity VARCHAR(255);
UPDATE nashville_housing
SET OwnerSplitCity = SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress,',',-2),',',1);

ALTER TABLE nashville_housing
ADD OwnerSplitState VARCHAR(255);
UPDATE nashville_housing
SET OwnerSplitState = SUBSTRING_INDEX(OwnerAddress,',',-1);

--------------------------------------------------------------------------------------------------------------------------------------
-- Change SoldAsVacant into ‘Yes’ e ‘No’ only (do not accept 'Y' and 'N')

Select Distinct(SoldAsVacant), Count(SoldAsVacant) AS Count
From nashville_housing
Group by SoldAsVacant
order by 2

UPDATE nashville_housing
SET SoldAsVacant = CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
    WHEN SoldAsVacant = 'N' THEN 'No'
    ELSE SoldAsVacant
END
 
--------------------------------------------------------------------------------------------------------------------------------------

-- Removing ‘$’ and ‘,’ from the sales fields and setting them as integers
SELECT SalePrice, `LandValue`,`BuildingValue`,`TotalValue`
FROM nashville_housing
WHERE SalePrice LIKE '%$%'

UPDATE nashville_housing
SET SalePrice = TRIM(REPLACE(SalePrice, '$', '')); 
UPDATE nashville_housing
SET SalePrice = TRIM(REPLACE(SalePrice, ',', ''));

ALTER TABLE nashville_housing
MODIFY SalePrice INT,
MODIFY LandValue INT,
MODIFY BuildingValue INT,
MODIFY TotalValue INT;

-- PARTITION BY vs GROUP BY
SELECT UniqueID, `PropertySplitCity`, 
COUNT(UniqueID) OVER (PARTITION BY PropertySplitCity) AS BigHouses 
FROM nashville_housing 
WHERE `Acreage`>25;
 
SELECT `PropertySplitCity`, COUNT(`UniqueID`) AS BigHouses 
FROM nashville_housing 
WHERE `Acreage`>25
GROUP BY PropertySplitCity
 
-- Identify and remove duplicate records (having a different UniqueId).
-- generate a row number = 1 for unique records with respect to the fields specified below.
-- if a record has the exact same values for all of these fields, then it will have a row_number >1

SELECT *,
ROW_NUMBER() OVER(
    PARTITION BY `ParcelID`,`PropertyAddress`,`SaleDateConverted`,`SalePrice`,`LegalReference`
    ORDER BY `UniqueID`) AS row_number
from nashville_housing
ORDER BY ParcelID

-- Identify the duplicate records using a CTE
WITH RowNumCTE AS (
SELECT *,
ROW_NUMBER() OVER(
    PARTITION BY `ParcelID`,`PropertyAddress`,`SaleDateConverted`,`SalePrice`,`LegalReference`
    ORDER BY `UniqueID`) AS row_number
FROM nashville_housing
)
SELECT *
FROM RowNumCTE
WHERE row_number>1
ORDER BY PropertyAddress;
 
DELETE FROM nashville_housing
WHERE UniqueID IN (
  SELECT UniqueID
  FROM (
    SELECT *,
      ROW_NUMBER() OVER(
        PARTITION BY `ParcelID`, `PropertyAddress`, `SaleDateConverted`, `SalePrice`, `LegalReference`
        ORDER BY `UniqueID`
      ) AS row_number
    FROM nashville_housing
  ) AS RowNumCTE
  WHERE row_number > 1
);

------------------------------------------------------------------------------------------------------------------------------------------
-- Delete unnecessary columns 
ALTER TABLE nashville_housing
DROP COLUMN OwnerAddress;

ALTER TABLE nashville_housing
DROP COLUMN TaxDistrict;

ALTER TABLE nashville_housing
DROP COLUMN PropertyAddress;

ALTER TABLE nashville_housing
DROP COLUMN PropertyAddress_copy;
