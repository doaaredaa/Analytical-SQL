--
--1)    Write a query to find each one in family, has how many fathers, using recursive CTE
WITH FAMILY_CTE (NAME, FATHER, LVL) AS
(   SELECT F.NAME, F.FATHER, 0 AS LVL 
    FROM FAMILY F
    WHERE F.FATHER IS NULL
    UNION ALL
    SELECT F.NAME, F.FATHER, FC.LVL +1
    FROM FAMILY_CTE FC, FAMILY F
    WHERE F.FATHER = FC.NAME
)
SELECT *
FROM FAMILY_CTE
ORDER BY LVL, NAME;
--
SELECT * FROM FAMILY;
---------------------------------------------------------
-- 2)    Identify Departments with the Most Evenly Distributed Revenue , comment on your answer. 
-- ( Using STDDEV , get the top 4 departments with STDDEV on revenue )
SELECT DISTINCT DEPARTMENT,
                ROUND(STDDEV(REVENUE_GENERATED) OVER(PARTITION BY DEPARTMENT), 3) AS REVENUE_STDDEV
FROM EMPLOYEE_PERFORMANCE
ORDER BY REVENUE_STDDEV;
-------------------------------------------------------------------
--3)    Calculate the moving Average working hours  for Emp Quinn for last 5 rows.
SELECT EMP_NAME, EVALUATION_DATE, HOURS_WORKED,
       AVG(HOURS_WORKED) OVER(PARTITION BY EMP_ID ORDER BY EVALUATION_DATE 
       ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS MOVING_AVG_HOURS
FROM EMPLOYEE_PERFORMANCE
WHERE EMP_NAME = 'Quinn';
----------------------------------------------------------------------
--4)  Compare Revenue with a 2-Month Range For each evaluation, calculate the total revenue for evaluations that occurred within 1 month (60 days) before and including the current date.
SELECT EMP_NAME,EVALUATION_DATE,REVENUE_GENERATED,
SUM(REVENUE_GENERATED) OVER( ORDER BY EVALUATION_DATE 
RANGE BETWEEN INTERVAL '60' DAY  PRECEDING AND CURRENT ROW) AS MONTH_RANGE_REVENUE
FROM EMPLOYEE_PERFORMANCE
WHERE EMP_NAME='Quinn';
--------------------------------------------------------------------------
--5)    Flag Employees Who Are Falling Behind Department’s Rolling Average
--Business Need: Identify employees whose revenue is consistently below their department's rolling average over the last 3 rows.

SELECT EMP_NAME,DEPARTMENT,EVALUATION_DATE,REVENUE_GENERATED,
ROUND(AVG(REVENUE_GENERATED) OVER( PARTITION BY DEPARTMENT ORDER BY EVALUATION_DATE 
ROWS BETWEEN 2   PRECEDING AND CURRENT ROW),2) AS ROLLING_AVG_DEPARTMENT_REVENUE,
CASE WHEN REVENUE_GENERATED >= (AVG(REVENUE_GENERATED) OVER( PARTITION BY DEPARTMENT ORDER BY EVALUATION_DATE 
ROWS BETWEEN 2   PRECEDING AND CURRENT ROW) )THEN 'Above Rolling Avg'
ELSE  'Below Rolling Avg' END AS PERFORMANCE_FLAG
FROM EMPLOYEE_PERFORMANCE;
--------------------------------------------------------------------------
--6)    Find Revenue Peaks Within a Dynamic Date Range
--Business Need:For each employee, calculate the maximum revenue achieved within a rolling 60-day window (current row and preceding 60 days).
SELECT EMP_NAME,EVALUATION_DATE,REVENUE_GENERATED,
MAX(REVENUE_GENERATED) OVER(PARTITION BY EMP_ID ORDER BY EVALUATION_DATE 
RANGE BETWEEN INTERVAL '60' DAY PRECEDING AND CURRENT ROW) AS MAX_REVENUE_IN_60_DAYS
FROM EMPLOYEE_PERFORMANCE
WHERE EMP_ID=17;
-----------------------------------------------------------------
--7)    For each row for Quinn employee, make a flag to show that this revenue generated is more or less than the last revenue made by Quinn 
WITH CTE AS (SELECT EMP_NAME,PROJECT_ID,EVALUATION_DATE,REVENUE_GENERATED,
LAG(REVENUE_GENERATED) OVER(PARTITION BY EMP_ID ORDER BY EVALUATION_DATE) AS
PREV_REVENUE
FROM EMPLOYEE_PERFORMANCE
WHERE EMP_ID =17)
SELECT EMP_NAME,PROJECT_ID,EVALUATION_DATE,REVENUE_GENERATED,
CASE WHEN REVENUE_GENERATED > PREV_REVENUE THEN 'Increasing'
WHEN REVENUE_GENERATED < PREV_REVENUE THEN 'Decreasing'
ELSE 'Constant' END AS TREND_FLAG
FROM CTE;
