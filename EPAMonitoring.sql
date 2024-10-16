-- Create the database
DROP DATABASE EPAMonitoring;
CREATE DATABASE EPAMonitoring;
GO
USE EPAMonitoring;

-- Create DIM_Activity
CREATE TABLE DIM_Activity (
    Activity_ID INT PRIMARY KEY,
    Activity_Type NVARCHAR(100),
);

-- Create DIM_Officer
CREATE TABLE DIM_Officer (
    Officer_ID INT PRIMARY KEY,
    Officer_Name NVARCHAR(100)
);

-- Create DIM_Site
CREATE TABLE DIM_Site (
    Site_ID INT PRIMARY KEY,
    Site_Name NVARCHAR(100),
    Site_Location NVARCHAR(255)
);

-- Create price history table
CREATE TABLE DIM_PriceHistory (
    Price_ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    Price DECIMAL(10, 2),
    Monitoring_Date DATE,
);

-- Create the Fact Table
CREATE TABLE Fact_EPAMonitoring (
    Fact_ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),  -- UUID Primary Key
    Transaction_ID INT,
    Officer_ID INT,
    Site_ID INT,
    Activity_ID INT,
    Use_More_Than_Five_Equipments BIT,
    Equipment_Used INT,
    Compliance_Status NVARCHAR(50),
    Community_Feedback_Rating INT,
    Pollution_Level_Detected DECIMAL(10, 2),
    Activity_Duration DECIMAL(5, 2),
    Activity_Description NVARCHAR(255),
    Price_ID UNIQUEIDENTIFIER,
    Total DECIMAL(10, 2)
    FOREIGN KEY (Officer_ID) REFERENCES DIM_Officer(Officer_ID),
    FOREIGN KEY (Site_ID) REFERENCES DIM_Site(Site_ID),
    FOREIGN KEY (Activity_ID) REFERENCES DIM_Activity(Activity_ID),
    FOREIGN KEY (Price_ID) REFERENCES DIM_PriceHistory(Price_ID),
);

CREATE TABLE Temp_EPAMonitoring (
    Monitoring_Date VARCHAR(100),
    Officer_ID INT,
    Officer_Name NVARCHAR(100),
    Site_ID INT,
    Site_Name NVARCHAR(100),
    Site_Location NVARCHAR(255),
    Activity_ID VARCHAR(10),
    Activity_Type NVARCHAR(100),
    Activity_Description NVARCHAR(255),
    Activity_Duration VARCHAR(20),
    Equipment_Used VARCHAR(50),
    Pollution_Level_Detected DECIMAL(10, 2),
    Compliance_Status NVARCHAR(50),
    Community_Feedback_Rating INT,
    Transaction_ID INT,
);

-- delete all values without ids
DELETE FROM Temp_EPAMonitoring WHERE Activity_ID IS NULL OR Site_ID IS NULL OR Officer_ID IS NULL;

-- Change data from Equipment Used to integer or easier calculation
UPDATE Temp_EPAMonitoring
SET Equipment_Used = SUBSTRING(Equipment_Used,
                                  PATINDEX('%[0-9]%', Equipment_Used),
                                  LEN(Equipment_Used))
WHERE Equipment_Used IS NOT NULL;

-- update unique ids for each officer
-- create temporary table for storing unique officer
CREATE TABLE #UniqueOfficer (
    Officer_ID INT,
    Officer_Name NVARCHAR(100)
);

-- insert distinct values in #UniqueOfficer table
INSERT INTO #UniqueOfficer (Officer_ID, Officer_Name)
SELECT DISTINCT
    NUll As Officer_ID,
    Officer_Name
FROM Temp_EPAMonitoring;

-- insert unique values and ids in DIM_Officer table after checking duplicates
INSERT INTO DIM_Officer (Officer_ID, Officer_Name)
SELECT
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + (SELECT ISNULL(MAX(Officer_ID), 0) FROM DIM_Officer),
    ua.Officer_Name
FROM #UniqueOfficer ua
LEFT JOIN DIM_Officer da ON
    ua.Officer_Name = da.Officer_Name
WHERE da.Officer_Id IS NULL; -- Only insert if it doesn't exist

-- update Temp_EPAMonitoring database officer ids with one in DIM_Officer table
UPDATE t
SET t.Officer_ID = am.Officer_ID
FROM Temp_EPAMonitoring t
JOIN DIM_Officer am ON
    t.Officer_Name = am.Officer_Name

-- drop temporary table
DROP TABLE #UniqueOfficer;



-- update unique ids for each site
-- create temporary table for storing unique site
CREATE TABLE #UniqueSite (
    Site_ID INT,
    Site_Name NVARCHAR(100),
    Site_Location NVARCHAR(255)
);

-- insert distinct values in #UniqueSite table
INSERT INTO #UniqueSite (Site_ID, Site_Name, Site_Location)
SELECT DISTINCT
    NUll As Site_ID,
    Site_Name,
    Site_Location
FROM Temp_EPAMonitoring;

-- insert unique values and ids in DIM_Site table after checking duplicates
INSERT INTO DIM_Site (Site_ID, Site_Name, Site_Location)
SELECT
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + (SELECT ISNULL(MAX(Site_ID), 0) FROM DIM_Site),
    ua.Site_Name,
    ua.Site_Location
FROM #UniqueSite ua
LEFT JOIN DIM_Site da ON
    ua.Site_Name = da.Site_Name AND
    ua.Site_Location = da.Site_Location
WHERE da.Site_ID IS NULL; -- Only insert if it doesn't exist

-- update Temp_EPAMonitoring database site ids with one in DIM_Site table
UPDATE t
SET t.Site_ID = am.Site_ID
FROM Temp_EPAMonitoring t
JOIN DIM_Site am ON
    t.Site_Name = am.Site_Name AND
    t.Site_Location = am.Site_Location

-- drop temporary table
DROP TABLE #UniqueSite;


-- update unique ids for each site
-- create temporary table for storing unique activity
CREATE TABLE #UniqueActivity (
    Activity_ID INT,
    Activity_Type NVARCHAR(100),
);

-- insert distinct values in #UniqueSite table
INSERT INTO #UniqueActivity (Activity_ID, Activity_Type)
SELECT DISTINCT
    NUll As Activity_ID,
    Activity_Type
FROM Temp_EPAMonitoring;

-- insert unique values and ids in DIM_Site table after checking duplicates
INSERT INTO DIM_Activity (Activity_ID, Activity_Type)
SELECT
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + (SELECT ISNULL(MAX(Activity_ID), 0) FROM DIM_Activity),
    ua.Activity_Type
FROM #UniqueActivity ua
LEFT JOIN DIM_Activity da ON
    ua.Activity_Type = da.Activity_Type
WHERE da.Activity_ID IS NULL; -- Only insert if it doesn't exist

-- update Temp_EPAMonitoring database site ids with one in DIM_Site table
UPDATE t
SET t.Activity_ID = am.Activity_ID
FROM Temp_EPAMonitoring t
JOIN DIM_Activity am ON
    t.Activity_Type = am.Activity_Type

-- drop temporary table
DROP TABLE #UniqueActivity;

-- update price history table with random values and unique monitoring date
INSERT INTO DIM_PriceHistory (Monitoring_Date, Price)
SELECT DISTINCT
    CAST(Monitoring_Date AS DATE),  -- Convert Monitoring_Date to DATE
    CAST(ROUND((RAND(CHECKSUM(NEWID())) * (500 - 100) + 100), 2) AS NVARCHAR(100))  -- Generate unique random price between 100 and 500 for each row
FROM Temp_EPAMonitoring
WHERE Monitoring_Date IS NOT NULL

INSERT INTO Fact_EPAMonitoring (
    Transaction_ID,
    Officer_ID,
    Site_ID,
    Activity_ID,
    Use_More_Than_Five_Equipments,
    Equipment_Used,
    Compliance_Status,
    Community_Feedback_Rating,
    Pollution_Level_Detected,
    Activity_Duration,
    Activity_Description,
    Price_ID,
    Total
)
SELECT
    Transaction_ID,
    Officer_ID,
    Site_ID,
    Activity_ID,
    IIF(Equipment_Used > 5, 1, 0) AS Use_More_Than_Five_Equipments,
    Equipment_Used,
    Compliance_Status,
    Community_Feedback_Rating,
    Pollution_Level_Detected,
    Activity_Duration,
    Activity_Description,
    ph.Price_ID,
    (ph.Price * Equipment_Used)
FROM
    Temp_EPAMonitoring t
LEFT JOIN DIM_PriceHistory ph ON CAST(t.Monitoring_Date AS DATE) = ph.Monitoring_Date
WHERE ph.Monitoring_Date IS NOT NULL;  -- Ensure you are inserting only when there's a matching price


DROP TABLE Temp_EPAMonitoring


-- Here I am calculating the best officer. --
WITH FACT AS (
    SELECT
        ofc.Officer_Name,
        Fa.Community_Feedback_Rating,
        Fa.Compliance_Status,
        Fa.Activity_Duration,
        Fa.Total,
        Fa.Use_More_Than_Five_Equipments,
        da.Activity_Type
    FROM Fact_EPAMonitoring AS Fa
    JOIN DIM_Officer AS Ofc ON Ofc.Officer_ID = Fa.Officer_ID
    JOIN DIM_PriceHistory AS Ph ON Ph.Price_ID = Fa.Price_ID
    JOIN DIM_Activity AS da ON da.Activity_ID = Fa.Activity_ID
),
RESULT AS (
    SELECT
        Officer_Name,
        SUM(CAST(Use_More_Than_Five_Equipments AS INT)) AS Total_Activities_Using_Above_Five_Equipments,
        COUNT(*)                                        AS Total_Activities,
        SUM(IIF(Compliance_Status = 'Compliant', 1, 0)) AS Total_Compliant_Activities,
        AVG(Community_Feedback_Rating)                  AS Average_Community_Feedback,
        COUNT(DISTINCT Activity_Type)                   AS Unique_Activity_Types,
        IIF(
            SUM(Activity_Duration) > 0,
            SUM(Total) / SUM(Activity_Duration),
            0
        )                                               AS Average_Expense_Per_Duration
    FROM FACT
    GROUP BY Officer_Name
),
NORMALIZED AS (
    SELECT
        Officer_Name,
        (CAST(Total_Activities_Using_Above_Five_Equipments AS FLOAT) / NULLIF(Total_Activities, 0)) * 100 AS Ratio_Of_More_Than_5_Equipments_Used_By_Total_Activities_Performed,
        (CAST(Total_Compliant_Activities AS FLOAT) / NULLIF(Total_Activities, 0)) * 100 AS Ratio_Of_Compliant_Activities,
        (CAST(Average_Community_Feedback AS FLOAT) / 4) * 100 AS Ratio_Of_Community_Feedback,
        (CAST(Unique_Activity_Types AS FLOAT) / 4) * 100 AS Ratio_Of_Activity_Types_Performed,
        (Average_Expense_Per_Duration / 10) AS Average_Expense_Per_Duration_By_10
    FROM RESULT
),
SCORED AS (
    SELECT
        Officer_Name,
        Ratio_Of_More_Than_5_Equipments_Used_By_Total_Activities_Performed,
        Ratio_Of_Compliant_Activities,
        Ratio_Of_Community_Feedback,
        Ratio_Of_Activity_Types_Performed,
        Average_Expense_Per_Duration_By_10,
        (0.05 * Ratio_Of_More_Than_5_Equipments_Used_By_Total_Activities_Performed) +
        (0.30 * Ratio_Of_Compliant_Activities) +
        (0.25 * Ratio_Of_Community_Feedback) +
        (0.05 * Ratio_Of_Activity_Types_Performed) +
        (0.35 * Average_Expense_Per_Duration_By_10) AS Final_Score_Percentage
    FROM NORMALIZED
)
SELECT
    Officer_Name,
    Ratio_Of_More_Than_5_Equipments_Used_By_Total_Activities_Performed,
    Ratio_Of_Compliant_Activities,
    Ratio_Of_Community_Feedback,
    Ratio_Of_Activity_Types_Performed,
    Average_Expense_Per_Duration_By_10,
    Final_Score_Percentage
FROM SCORED
ORDER BY Final_Score_Percentage DESC;
