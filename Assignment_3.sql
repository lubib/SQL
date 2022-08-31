use ces

--Parse the Series ID column to extract the relevant information.

INTO #temp1
FROM wrk.ceAllData

ALTER TABLE #temp1
ADD Seasonal_Not_seasonal VARCHAR(10) -- adding necessary fields
	, Supersector_code INT -- adding necessary fields
	, Industry_code INT -- adding necessary fields
	, Data_type_code INT -- adding necessary fields
	, Gutter VARCHAR(255) -- adding necessary fields

UPDATE #temp1
SET Gutter = series_id

UPDATE #temp1
SET Seasonal_Not_seasonal = SUBSTRING(Gutter, 3,1)

UPDATE #temp1
SET Supersector_code = SUBSTRING(Gutter, 4,2)

UPDATE #temp1
SET Industry_code = SUBSTRING(Gutter, 4,8)

UPDATE #temp1
SET Data_type_code = SUBSTRING(Gutter, 12,2)

SELECT *
FROM #temp1 AS a
INNER JOIN wrk.ceseries AS b ON a.series_id=b.series_id


--Similar to the above, Parse the Series_Title column to extract relevant information about the series.  
--For example, "Average weekly earnings of production and nonsupervisory employees, family clothing stores, not seasonally adjusted" Should be parsed into the following:
--		Average Weekly Earnings <- Data Type
--		Production and Nonsupervisory Employees <-  Data Type
--		Family Clothing Stores <- Industry
--		Not Seasonally Adjusted  <- Seasonal / Not Seasonal


SELECT DISTINCT TOP 1000 series_id, series_title
INTO #temp2
FROM wrk.ceseries

ALTER TABLE #temp2
ADD Data_type VARCHAR(500)
    , Industry VARCHAR(500)
    , Seasonal_NotSeasonal VARCHAR(50)
    , Gutter VARCHAR(255) -- adding necesary fields

UPDATE #temp2
SET Gutter = series_title

UPDATE #temp2
SET Data_type = RTRIM(LTRIM(SUBSTRING(Gutter, 1,PATINDEX('%,%', Gutter)-1)))

UPDATE #temp2
SET Industry = RTRIM(LTRIM(REVERSE(SUBSTRING(REVERSE(Gutter), PATINDEX('%,%',
REVERSE(Gutter))+1, 255))))

UPDATE #temp2
SET Industry = RTRIM(LTRIM(REVERSE(SUBSTRING(REVERSE(Industry ),1,PATINDEX('%,%',
REVERSE(Industry ))-1))))

UPDATE #temp2
SET Seasonal_NotSeasonal = RTRIM(LTRIM(REVERSE(SUBSTRING(REVERSE(Gutter),
1,PATINDEX('%,%', REVERSE(Gutter))-1))))


--Using the Total Non-Farm Employment series as base, determine the Ratio of total employment in each employment sector by industry and year for 2015 to 2020.  
SELECT a.[year], supersector_name, Avg_Total_Empl,
Avg_Total_Empl/Avg_Total_Emp_Base AS Ratio
FROM(
    SELECT AVG(Value) AS Avg_Total_Emp_Base, [year]
    FROM wrk.ceAllData
    WHERE series_id = 'CES0000000001'
    AND [year] BETWEEN 2015 AND 2020 --requested this data range
    GROUP BY [year]
) AS a
INNER JOIN (
    SELECT AVG(Value) AS Avg_Total_Empl, b.supersector_code, c.supersector_name,
a.[year]
    FROM wrk.ceAllData AS a
    INNER JOIN wrk.ceseries AS b ON a.series_id = b.series_id
    INNER JOIN wrk.ceSupersector AS c ON b.supersector_code = c.supersector_code
    WHERE industry_code LIKE '%000000%'
    AND data_type_code = '01'
    AND [year] BETWEEN 2015 AND 2020 --requested this data range
    AND seasonal = 'S'
    GROUP BY b.supersector_code, c.supersector_name, a.[year]
) AS b
ON a.[year] = b.[year]

--Determine the gender breakdown of each industry between 2015 to 2020.
SELECT a.[year], b.industry_code, industry_name,
Avg_employment_women/Avg_Total_Emp as empl_women,
(Avg_Total_Emp-Avg_employment_women)/Avg_Total_Emp as empl_men
FROM(
    SELECT [year], series_title, b.industry_code, CAST(AVG(Value) AS NUMERIC(18,2)) AS
Avg_Total_Emp
    FROM wrk.ceAllData as a
    INNER JOIN wrk.ceseries as b ON a.series_id = b.series_id
    WHERE [year] BETWEEN 2015 AND 2020 --requested this data range
    AND data_type_code = '01' -- All employees
    AND seasonal = 'S'
    GROUP BY [year], series_title, b.industry_code
) AS a
INNER JOIN (
    SELECT d.industry_name, [year], b.industry_code
    , CAST(AVG(value) AS NUMERIC(18,2)) AS Avg_employment_women
    FROM wrk.ceAllData AS a
    LEFT JOIN wrk.ceseries AS b ON a.series_id = b.series_id
    LEFT JOIN wrk.ceindustry AS d ON b.industry_code = d.industry_code
    LEFT JOIN wrk.cedatatype AS e ON b.data_type_code = e.data_type_code
    WHERE a.[year] BETWEEN 2015 AND 2020 --requested this data range
    AND e.data_type_text = 'WOMEN EMPLOYEES, THOUSANDS'
    AND seasonal = 'S' -- Seasonally Adjusted
    GROUP BY d.industry_name, [year], b.industry_code
) AS b
ON a.industry_code = b.industry_code


--Calculate the percentage change in average weekly wages for all "business" related industries. Keeping each Series_Id separate.
-- I'm going to look at the change between 2015 and 2020
SELECT [2020].series_id, (Avg_wkly_wages_2020-Avg_wkly_wages_2015)/Avg_wkly_wages_2015
AS perc_change
FROM (
    SELECT a.series_id, c.industry_name, AVG(a.[value]) AS Avg_wkly_wages_2015
    FROM wrk.ceAllData AS a
    INNER JOIN wrk.ceseries AS b ON a.series_id = b.series_id
    INNER JOIN wrk.ceindustry AS c ON b.industry_code = c.industry_code
    WHERE c.industry_name LIKE '%business%'
    AND b.data_type_code = 11 -- AVERAGE WEEKLY EARNINGS OF ALL EMPLOYEES
    AND [period] <> 'M13' --filter out all annual records
    AND a.[year] = 2015
    GROUP BY a.series_id, c.industry_name
) AS [2015]
INNER JOIN(
    SELECT a.series_id, c.industry_name, AVG(a.[value]) AS Avg_wkly_wages_2020
    FROM wrk.ceAllData AS a
    INNER JOIN wrk.ceseries AS b ON a.series_id = b.series_id
    INNER JOIN wrk.ceindustry AS c ON b.industry_code = c.industry_code
    WHERE c.industry_name LIKE '%business%'
    AND b.data_type_code = 11 -- AVERAGE WEEKLY EARNINGS OF ALL EMPLOYEES
    AND [period] <> 'M13' --filter out all annual records
    AND a.[year] = 2020
    GROUP BY a.series_id, c.industry_name
) AS [2020]
ON [2015].series_id=[2020].series_id



--Create a #temp table to handles both addresses.  

SELECT *
INTO #temp6
FROM (
    SELECT '515 S. Flower Street, Los Angeles, CA 90017' as addr
) AS z
UNION (
    SELECT '2000 K Street NW, Washington, DC 20006-0001' as addr
)

ALTER TABLE #temp6
ADD Str_No INT
    , Street VARCHAR(50)
    , City VARCHAR(50)
    , St VARCHAR(10)
    , Zip VARCHAR(20)
    , Gutter VARCHAR(255) -- altering table with necessary fields

SELECT *
FROM #temp6

UPDATE #temp6
SET Gutter = Addr

UPDATE #temp6
SET Zip = RTRIM(LTRIM(REVERSE(SUBSTRING(REVERSE(Gutter),1,PATINDEX('% %',
REVERSE(gutter)))))) -- updating zip code

UPDATE #temp6
SET St = RTRIM(LTRIM(REVERSE(SUBSTRING(REVERSE(Gutter), PATINDEX('%, %',
REVERSE(Gutter))+LEN(REVERSE(SUBSTRING(REVERSE(Gutter),1,
PATINDEX('% %', REVERSE(Gutter))+1))),2)))) -- getting state only

UPDATE #temp6
SET Str_no = RTRIM(LTRIM(SUBSTRING(Gutter, 1, PATINDEX('% %', Gutter))))

UPDATE #temp6
SET Street = RTRIM(LTRIM(SUBSTRING(Gutter, PATINDEX('% %', Gutter)+1,
PATINDEX('%,%', Gutter)-LEN(SUBSTRING(Gutter,1,PATINDEX('% %', Gutter)+1))))) --getting street without a comma

UPDATE #temp6
SET City = RTRIM(LTRIM(REVERSE(SUBSTRING(REVERSE(Gutter), PATINDEX('%,%',
REVERSE(Gutter))+1, 255))))

UPDATE #temp6
SET City = RTRIM(LTRIM(REVERSE(SUBSTRING(REVERSE(City),1,PATINDEX('%,%',
REVERSE(City))-1)))) --reducing the string into just the City

