use ces

-- Prepare a query that counts up the number of observations for each series by year
SELECT [year], series_id, count (*)
FROM wrk.ceAllData
GROUP BY [year], series_id
ORDER BY [year]

	
--Filter the above query to determine which series and years have 13 annual observations. How many series have 13 observations in any given year?
SELECT COUNT(*)
FROM(
    SELECT [year], series_id, count (*) AS 'observations'
    FROM wrk.ceAllData
    GROUP BY [year], series_id
) as n
WHERE n.observations = 13  

--Filter the above query to determine which series and years have less than 12 observations. How many series have less than 12 observations in a year?
SELECT COUNT(*)
FROM(
    SELECT series_id, [year], count (*) AS 'observations'
    FROM wrk.ceAllData
    GROUP BY series_id, [year]
) as n
WHERE n.observations < 12

--Determine which series have an annual average
SELECT wrk.ceAllData.series_id, wrk.ceperiod.[month]
FROM wrk.ceAllData
INNER JOIN wrk.ceperiod ON wrk.ceAllData.[period] = wrk.ceperiod.[period]
WHERE wrk.ceperiod.[month] = 'Annual Average'
ORDER BY wrk.ceAllData.series_id

--Prepare a summary query that shows the series, series description, and the years that have an annual average
SELECT a.series_id, b.series_title, a.[year], c.[month]
FROM wrk.ceAllData AS a
LEFT JOIN wrk.ceseries AS b ON a.series_id = b.series_id
LEFT JOIN wrk.ceperiod AS c ON a.[period] = c.[period]
WHERE c.[month] = 'Annual Average'

--Creating new tables in the wrk schema:

--Using the AllSeries data filter out all annual records. Call this table wrk.ceAllDataMonthly
CREATE TABLE wrk.ceAllDataMonthly (
    series_id VARCHAR(100)
    ,[year] INT
    ,[period] VARCHAR(10)
    ,[value] NUMERIC(18,0)
    ,footnote_codes VARCHAR(100)
)
GO
INSERT INTO wrk.ceAllDataMonthly (
    series_id,
    [year],
    [period],
    [value],
    footnote_codes
)(
    SELECT series_id, [year], [period], [value], footnote_codes
    FROM wrk.ceAllData WHERE [period] <> 'M13'
)
GO

SELECT TOP 10 *
FROM wrk.ceAllDataMonthly

--Using the AllSeries data filter out all monthly records. Call this table wrk.ceAllDataAnnual

CREATE TABLE wrk.ceAllDataAnnual (
    series_id VARCHAR(100)
    ,[year] INT
    ,[period] VARCHAR(10)
    ,[value] NUMERIC(18,0)
    ,footnote_codes VARCHAR(100)
)
GO
INSERT INTO wrk.ceAllDataAnnual (
    series_id,
    [year],
    [period],
    [value],
    footnote_codes
)(
    SELECT series_id, [year], [period], [value], footnote_codes
    FROM wrk.ceAllData WHERE [period] = 'M13'
)
GO

--Using the wrk.ceAllDataMonthly table, convert the period and year fields into a SQL date. Assume the date occurs at the end of each month 
--(account for leap years and the length of each month). Call the new field SeriesDate.
ALTER TABLE wrk.ceAllDataMonthly
ADD SeriesDate DATE

UPDATE wrk.ceAllDataMonthly
SET SeriesDate = EOMONTH(CONVERT(DATE, CONCAT(LTRIM(RTRIM(b.[month])),
'01,',a.[year]), 106))
FROM wrk.ceAllDataMonthly AS a
LEFT JOIN wrk.ceperiod AS b ON a.[period] = b.[period]
WHERE a.[period] <> 'M13'

SELECT TOP 10 *
FROM wrk.ceAllDataMonthly

--Using the wrk.ceAllData table, convert the period for year fields into a SQL date. Assume the date occurs at the end of each month 
--(account for leap years and the length of each month). Call the new field SeriesDate.
ALTER TABLE wrk.ceAllData
ADD SeriesDate DATE

UPDATE wrk.ceAllData
SET SeriesDate = EOMONTH(CONVERT(DATE, CONCAT(LTRIM(RTRIM(b.[month])),
'01,',a.[year]), 106))
FROM wrk.ceAllData AS a
LEFT JOIN wrk.ceperiod AS b ON a.[period] = b.[period]
WHERE a.[period] <> 'M13'


--Which series IDs have seasonally adjusted data from 2000 to 2020 and involve the "business" industry?

SELECT a.series_id, c.seasonal_text, a.[year], d.industry_name
FROM wrk.ceAllData AS a
LEFT JOIN wrk.ceseries AS b ON a.series_id = b.series_id
LEFT JOIN wrk.ceseasonal AS c ON b.seasonal = c.seasonal_code
LEFT JOIN wrk.ceindustry AS d ON b.industry_code = d.industry_code
WHERE c.seasonal_text = 'Seasonally Adjusted'
AND d.industry_name LIKE '%business%'
AND [year] BETWEEN 2000 AND 2020


--What SuperSectors are these series IDs part of?
SELECT e.supersector_name
FROM wrk.ceAllData AS a
LEFT JOIN wrk.ceseries AS b ON a.series_id = b.series_id
LEFT JOIN wrk.ceseasonal AS c ON b.seasonal = c.seasonal_code
LEFT JOIN wrk.ceindustry AS d ON b.industry_code = d.industry_code
LEFT JOIN wrk.cesupersector AS e ON b.supersector_code = e.supersector_code
WHERE c.seasonal_text = 'Seasonally Adjusted'
AND d.industry_name LIKE '%business%'
AND [year] BETWEEN 2000 AND 2020
GROUP BY e.supersector_name
ORDER BY e.supersector_name


--Prepare a summary table that summarizes the total employment from 2010 to 2020 for the "business" industry. Use seasonal adjusted values only.
SELECT b.series_title, a.[year]
FROM wrk.ceAllData AS a
LEFT JOIN wrk.ceseries AS b ON a.series_id = b.series_id
LEFT JOIN wrk.ceseasonal AS c ON b.seasonal = c.seasonal_code
LEFT JOIN wrk.ceindustry AS d ON b.industry_code = d.industry_code
LEFT JOIN wrk.cedatatype AS e ON b.data_type_code = e.data_type_code
WHERE e.data_type_text = 'ALL EMPLOYEES, THOUSANDS'
AND c.seasonal_text = 'Seasonally Adjusted'
AND d.industry_name LIKE '%business%'
AND a.[year] BETWEEN 2010 AND 2020
GROUP BY b.series_title, a.[year]
ORDER BY b.series_title, a.[year]


--Using the above, prepare a table that summarizes the total amount of employment that falls into Professional and Business Services vs all other employment in the "business" industry?
SELECT b.series_title, d.industry_name, e.data_type_text
, CAST(SUM(Value) AS int) AS sum_value
FROM wrk.ceAllData AS a
LEFT JOIN wrk.ceseries AS b ON a.series_id = b.series_id
LEFT JOIN wrk.ceseasonal AS c ON b.seasonal = c.seasonal_code
LEFT JOIN wrk.ceindustry AS d ON b.industry_code = d.industry_code
LEFT JOIN wrk.cedatatype AS e ON b.data_type_code = e.data_type_code
WHERE e.data_type_text = 'ALL EMPLOYEES, THOUSANDS'
AND c.seasonal_text = 'Seasonally Adjusted'
AND a.[year] BETWEEN 2010 AND 2020
GROUP BY b.series_title, d.industry_name, e.data_type_text
HAVING d.industry_name = 'Professional and Business Services'
OR (d.industry_name LIKE '%business%' AND d.industry_name <>'Professional and Business
Services')
ORDER BY b.series_title DESC

--For Professional and business services that are part of the "business" industry, how many average hours do they work over this period? 
--Compute the annual average by series ID.
SELECT a.series_id, CAST(AVG(a.value) AS NUMERIC(18,2)) AS AvgValue, c.industry_name
FROM wrk.ceAllData AS a
LEFT JOIN wrk.ceseries AS b ON a.series_id = b.series_id
LEFT JOIN wrk.ceindustry AS c ON b.industry_code = c.industry_code
WHERE a.[period] NOT LIKE 'm13'--m13 equals annual average
AND a.[year] BETWEEN 2010 AND 2020
AND c.industry_name LIKE '%business%'
AND b.data_type_code = 2 -- average weekly hours of ALL EMPLOYEES
GROUP BY a.series_id, c.industry_name
ORDER BY a.series_id

--What proportion of Professional and Business Services is women compared to all employment.
SELECT l.industry_name, CAST(w.women/l.all_employment
AS NUMERIC(18,2)) AS women
FROM(
SELECT e.data_type_text, d.industry_name
, CAST(SUM(value) AS NUMERIC(18,2)) AS women
FROM wrk.ceAllData AS a
LEFT JOIN wrk.ceseries AS b ON a.series_id = b.series_id
LEFT JOIN wrk.ceseasonal AS c ON b.seasonal = c.seasonal_code
LEFT JOIN wrk.ceindustry AS d ON b.industry_code = d.industry_code
LEFT JOIN wrk.cedatatype AS e ON b.data_type_code = e.data_type_code
WHERE a.[year] BETWEEN 2010 AND 2020
AND c.seasonal_text = 'Seasonally Adjusted'
AND e.data_type_text = 'WOMEN EMPLOYEES, THOUSANDS'
GROUP BY e.data_type_text, d.industry_name
HAVING d.industry_name ='Professional and Business Services'
) AS w
FULL OUTER JOIN (
SELECT e.data_type_text, d.industry_name
, CAST(SUM(value) AS NUMERIC(18,2)) AS all_employment
FROM wrk.ceAllData AS a
LEFT JOIN wrk.ceseries AS b ON a.series_id = b.series_id
LEFT JOIN wrk.ceseasonal AS c ON b.seasonal = c.seasonal_code
LEFT JOIN wrk.ceindustry AS d ON b.industry_code = d.industry_code
LEFT JOIN wrk.cedatatype AS e ON b.data_type_code = e.data_type_code
WHERE a.[year] BETWEEN 2010 AND 2020
AND c.seasonal_text = 'Seasonally Adjusted'
AND e.data_type_text = 'ALL EMPLOYEES, THOUSANDS'
GROUP BY e.data_type_text, d.industry_name
HAVING d.industry_name ='Professional and Business Services'
)
AS l
ON w.industry_name = l.industry_name


--Which series IDs have seasonally adjusted data from 2010 to 2020 and involve the "business" industry?
SELECT TOP 10 a.series_id, a.[year]
FROM wrk.ceAllData AS a
LEFT JOIN wrk.ceseries AS b ON a.series_id = b.series_id
LEFT JOIN wrk.ceseasonal AS c ON b.seasonal = c.seasonal_code
LEFT JOIN wrk.ceindustry AS d ON b.industry_code = d.industry_code
WHERE c.seasonal_text = 'Seasonally Adjusted'
AND d.industry_name LIKE '%business%'
AND a.[year] BETWEEN 2010 AND 2020
GROUP BY a.series_id, a.[year]
ORDER BY a.series_id


--Taking only "professional business" industries, build a summary table that shows the average, variance, std deviation of employment for all employees.
SELECT b.series_title, d.industry_name
, CAST(AVG(value) AS NUMERIC(18,2)) AS AVG_employment
, CAST(VAR(value) AS NUMERIC(18,2)) AS Variance_employment
, CAST(STDEV(value) AS NUMERIC(18,2)) AS SD_employment
FROM wrk.ceAllData AS a
LEFT JOIN wrk.ceseries AS b ON a.series_id = b.series_id
LEFT JOIN wrk.ceseasonal AS c ON b.seasonal = c.seasonal_code
LEFT JOIN wrk.ceindustry AS d ON b.industry_code = d.industry_code
LEFT JOIN wrk.cedatatype AS e ON b.data_type_code = e.data_type_code
WHERE c.seasonal_text = 'Seasonally Adjusted'
AND a.[year] BETWEEN 2010 AND 2020
AND e.data_type_text = 'ALL EMPLOYEES, THOUSANDS'
GROUP BY b.series_title, d.industry_name
HAVING d.industry_name ='Professional and Business Services'
ORDER BY b.series_title


--Taking only "professional business" industries, build a summary table that shows the average, variance, std deviation of employment for women employees.
SELECT b.series_title, d.industry_name
, CAST(AVG(value) AS NUMERIC(18,2)) AS AVG_employment
, CAST(VAR(value) AS NUMERIC(18,2)) AS Variance_employment
, CAST(STDEV(value) AS NUMERIC(18,2)) AS SD_employment
FROM wrk.ceAllData AS a
LEFT JOIN wrk.ceseries AS b ON a.series_id = b.series_id
LEFT JOIN wrk.ceseasonal AS c ON b.seasonal = c.seasonal_code
LEFT JOIN wrk.ceindustry AS d ON b.industry_code = d.industry_code
LEFT JOIN wrk.cedatatype AS e ON b.data_type_code = e.data_type_code
WHERE c.seasonal_text = 'Seasonally Adjusted'
AND a.[year] BETWEEN 2010 AND 2020
AND e.data_type_text = 'WOMEN EMPLOYEES, THOUSANDS'
GROUP BY b.series_title, d.industry_name
HAVING d.industry_name ='Professional and Business Services'
ORDER BY b.series_title

--Build a ratio that shows the average % employment of the workforce between men and women.
SELECT z.industry_name, CAST(w.AVG_employment_women/z.AVG_employment_all *100
AS NUMERIC(18,2)) AS perc_epml_women,
CAST((z.AVG_employment_all-w.AVG_employment_women)/z.AVG_employment_all *100
AS NUMERIC(18,2)) AS perc_empl_man
FROM (
    SELECT d.industry_name
    , CAST(AVG(value) AS NUMERIC(18,2)) AS AVG_employment_women
    FROM wrk.ceAllData AS a
    LEFT JOIN wrk.ceseries AS b ON a.series_id = b.series_id
    LEFT JOIN wrk.ceseasonal AS c ON b.seasonal = c.seasonal_code
    LEFT JOIN wrk.ceindustry AS d ON b.industry_code = d.industry_code
    LEFT JOIN wrk.cedatatype AS e ON b.data_type_code = e.data_type_code
    WHERE c.seasonal_text = 'Seasonally Adjusted'
    AND a.year BETWEEN 2010 AND 2020
    AND e.data_type_text = 'WOMEN EMPLOYEES, THOUSANDS'
    GROUP BY d.industry_name
    HAVING d.industry_name = 'Professional and Business Services'
) AS w
FULL OUTER JOIN (
    SELECT d.industry_name
    , CAST(AVG(value) AS NUMERIC(18,2)) AS AVG_employment_all
    FROM wrk.ceAllData AS a
    LEFT JOIN wrk.ceseries AS b ON a.series_id = b.series_id
    LEFT JOIN wrk.ceseasonal AS c ON b.seasonal = c.seasonal_code
    LEFT JOIN wrk.ceindustry AS d ON b.industry_code = d.industry_code
    LEFT JOIN wrk.cedatatype AS e ON b.data_type_code = e.data_type_code
    WHERE c.seasonal_text = 'Seasonally Adjusted'
    AND a.[year] BETWEEN 2010 AND 2020
    AND e.data_type_text = 'ALL EMPLOYEES, THOUSANDS'
    GROUP BY d.industry_name
    HAVING d.industry_name ='Professional and Business Services'
) AS z
ON w.industry_name= z.industry_name


--Compare the DataGoog file to the Series file
--Determine the number of unique series that are in the DataGoog table that are in the Series table
SELECT COUNT (DISTINCT a.series_id)
FROM wrk.ceDataGoog AS a
INNER JOIN wrk.ceseries AS b ON a.series_id = b.series_id

--Apply the label for the Series that are both the DataGoog and Series tables and display the min and max years for the series with the series labels
SELECT TOP 10 a.series_id, MIN([year]) AS [min], MAX([year]) AS [max]
FROM wrk.ceDataGoog AS a
INNER JOIN wrk.ceseries AS b ON a.series_id = b.series_id
GROUP BY a.series_id
ORDER BY a.series_id

--Build a summary query that shows the number of series that are in both DataGoog and AllData, just in DataGoog, just in AllData. 
SELECT COUNT(distinct b.series_id) AS in_AllData ,
COUNT(distinct a.series_id) AS in_DataGoog,
COUNT(CASE WHEN a.series_id = b.series_id THEN 1 END) AS In_both_DataGoog_and_AllData
FROM wrk.ceDataGoog AS a
FULL OUTER JOIN wrk.ceAllData AS b ON a.series_id = b.series_id

--Compare the DataType table to the data type field in the Series table. 
SELECT count (*),
CASE WHEN b.data_type_code = a.data_type_code THEN 'Match'
WHEN a.data_type_code > 0 THEN 'In_Data_Type_Not_in_Series'
ELSE 'In_Series_Not_in_Data_Type' END AS comparison
FROM wrk.cedatatype AS a
FULL OUTER JOIN wrk.ceseries AS b ON b.data_type_code = a.data_type_code
GROUP BY CASE WHEN b.data_type_code = a.data_type_code THEN 'Match'
WHEN a.data_type_code > 0 THEN 'In_Data_Type_Not_in_Series'
ELSE 'In_Series_Not_in_Data_Type' END
