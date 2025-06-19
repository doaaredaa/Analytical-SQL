--
-- 1. write the query that show:
--the emp name, group name , avg performance of each employee per day, avg performance of all employees per day, avg performance of each employee per month, avg performance of all employees per month 
--and if the average perfromance of an employee per day and per month are less than both average performance of all employees per day and per month write "Fired" 
--and if he is less than one of the averages of all employees write "Need Training". answer it in orcale knowing that all the columns needed are in the employee table.

SELECT EMP_ID, 
            EMP_NAME, 
            GROUP_NAME, 
            TO_CHAR(PERFORMANCE_DATE, 'FMDD-MON-YYYY') AS PERFORMANCE_DATE,
            
            ROUND(AVG(PERFORMANCE) OVER(PARTITION BY EMP_ID, PERFORMANCE_DATE), 2) 
            AS AVG_PERFORMANCE_PER_DAY,
            
            ROUND(AVG(PERFORMANCE) OVER(PARTITION BY PERFORMANCE_DATE), 2) 
            AS AVG_PERFORMANCE_ALL_PER_DAY,
            
            ROUND(AVG(PERFORMANCE) OVER(PARTITION BY EMP_ID, TO_CHAR(PERFORMANCE_DATE, 'FMMON-YYYY')), 2) 
            AS AVG_PERFORMANCE_PER_MONTH,
            
            ROUND(AVG(PERFORMANCE) OVER(PARTITION BY TO_CHAR(PERFORMANCE_DATE, 'FMMON-YYYY')), 2) 
            AS AVG_PERFORMANCE_ALL_PER_MONTH,
            
            CASE WHEN ROUND(AVG(PERFORMANCE) OVER(PARTITION BY EMP_ID, PERFORMANCE_DATE), 2) < 
                              ROUND(AVG(PERFORMANCE) OVER(PARTITION BY PERFORMANCE_DATE), 2) 
            
                        AND ROUND(AVG(PERFORMANCE) OVER(PARTITION BY EMP_ID, TO_CHAR(PERFORMANCE_DATE, 'FMMON-YYYY')), 2) < 
                              ROUND(AVG(PERFORMANCE) OVER(PARTITION BY TO_CHAR(PERFORMANCE_DATE, 'FMMON-YYYY')), 2) 
                              THEN 'Fired'
                    
                    WHEN ROUND(AVG(PERFORMANCE) OVER(PARTITION BY EMP_ID, PERFORMANCE_DATE), 2) < 
                              ROUND(AVG(PERFORMANCE) OVER(PARTITION BY PERFORMANCE_DATE), 2)
            
                         OR ROUND(AVG(PERFORMANCE) OVER(PARTITION BY EMP_ID, TO_CHAR(PERFORMANCE_DATE, 'FMMON-YYYY')), 2) < 
                              ROUND(AVG(PERFORMANCE) OVER(PARTITION BY TO_CHAR(PERFORMANCE_DATE, 'FMMON-YYYY')), 2) 
                              THEN 'Need Training'
                    
           ELSE 'Good'         
           END AS STATUS

FROM EMP_1;
-------------------------------------------------------
-- 2. Identify the days and the store id where sales in a store show decreasing in the rolling 5-day average over 4 consecutive periods.
WITH CTE_AVG_SALES AS 
            (SELECT STORE_ID, 
                        TO_DATE(SALE_DATE, 'YYYY-MM-DD') AS SALE_DATE, 
                        SALES,
                        ROUND(AVG(SALES) OVER(PARTITION BY STORE_ID ORDER BY TO_DATE(SALE_DATE, 'YYYY-MM-DD') RANGE BETWEEN INTERVAL '4' DAY  PRECEDING AND CURRENT ROW), 2) AS AVG_SALES
            FROM TABLE_2),
            -----------------------
        CTE_PREVIOUS_AVERAGES AS 
            (SELECT STORE_ID, 
                        SALE_DATE, 
                        SALES,
                        AVG_SALES,
                        LAG(AVG_SALES, 1) OVER(PARTITION BY STORE_ID ORDER BY SALE_DATE) AS PREVIOUS_1,
                        LAG(AVG_SALES, 2) OVER(PARTITION BY STORE_ID ORDER BY SALE_DATE) AS PREVIOUS_2,
                        LAG(AVG_SALES, 3) OVER(PARTITION BY STORE_ID ORDER BY SALE_DATE) AS PREVIOUS_3                        
            FROM CTE_AVG_SALES)

SELECT STORE_ID, 
            SALE_DATE, 
            SALES,
            AVG_SALES,
            PREVIOUS_1,
            PREVIOUS_2,
            PREVIOUS_3
            
FROM CTE_PREVIOUS_AVERAGES
WHERE AVG_SALES < PREVIOUS_1
AND     PREVIOUS_1 < PREVIOUS_2
AND     PREVIOUS_2 < PREVIOUS_3
ORDER BY STORE_ID, SALE_DATE;
---------------------------------------------------------------
--3. Write a solution to display the records with three or more rows with consecutive id's, and the number of people is greater than or equal to 100 for each.
--Return the result table ordered by visit_date in ascending order.
WITH CTE_CHECK AS
            (SELECT ID, VISIT_DATE, PEOPLE,
                        LAG(ID) OVER(ORDER BY ID) AS PREV_ID,
                        LAG(ID, 2) OVER(ORDER BY ID) AS PREV_ID2,
                        LEAD (ID) OVER(ORDER BY ID) AS NEXT_ID,
                        LEAD(ID, 2) OVER(ORDER BY ID) AS NEXT_ID2
            FROM Stadium_3
            WHERE PEOPLE >= 100)
            
SELECT ID, VISIT_DATE, PEOPLE
FROM CTE_CHECK 
WHERE ID - PREV_ID = 1 AND ID - PREV_ID2 = 2
      OR ID + 1 = NEXT_ID AND ID + 2= NEXT_ID2;
--------------------------------------------------------------
--4. You are working with a company that tracks employee salary increments over time. The company wants to analyze employee salary growth and identify patterns. 
--Specifically, they want to know: How much salary growth each employee has experienced over the last 12 months.
WITH CTE_SALARY AS
            (SELECT EMP_ID, 
                        EMP_NAME, 
                        DEPARTMENT, 
                        TO_CHAR(SALARY_DATE, 'FMDD_MON_YYYY') AS SALARY_DATE,
                        SALARY,
                        FIRST_VALUE(SALARY) OVER(PARTITION BY EMP_ID ORDER BY SALARY_DATE 
                        RANGE BETWEEN INTERVAL '12' MONTH PRECEDING AND CURRENT ROW) AS FIRST_SALARY,
                        
                        FIRST_VALUE(SALARY) OVER(PARTITION BY EMP_ID ORDER BY SALARY_DATE DESC 
                        RANGE BETWEEN INTERVAL '12' MONTH PRECEDING AND CURRENT ROW) AS LAST_SALARY,
                        
                        NVL(FIRST_VALUE(SALARY) OVER(PARTITION BY EMP_ID ORDER BY SALARY_DATE DESC -- AS LAST_SALARY 
                        RANGE BETWEEN INTERVAL '12' MONTH PRECEDING AND CURRENT ROW) - 
                        FIRST_VALUE(SALARY) OVER(PARTITION BY EMP_ID ORDER BY SALARY_DATE -- AS FIRST_SALARY
                         RANGE BETWEEN INTERVAL '12' MONTH PRECEDING AND CURRENT ROW), 0) 
                         AS SALARY_GROWTH,
                         
                        RANK() OVER(PARTITION BY EMP_ID ORDER BY SALARY_DATE DESC) AS RANKING                                                
              FROM EMP_SALARIES_4
              WHERE SALARY_DATE >= ADD_MONTHS(SYSDATE, -12) )          
                
SELECT EMP_ID, EMP_NAME, SALARY_GROWTH
FROM CTE_SALARY
WHERE RANKING =1;
-------------------------------------------------------------
--6. Generate a report for each course, showing the top 1 student per track.
WITH CTE AS (
    SELECT 
        S.STUDENT_NAME,
        C.COURSE_NAME,
        S.TRACK AS STUDENT_TRACK,
        NVL(SE.ASSIGNMENT, 0) +
        CASE 
            WHEN SE.ATTENDANCE = 'True' THEN 5
            ELSE 0 
        END +
        NVL(SE.LAB, 0) +
        NVL(SE.GRADE, 0) AS TOTAL_GRADES
    FROM 
        SESSIONS SE 
        JOIN STUDENT_6 S ON SE.STUDENT_ID = S.STUDENT_ID
        JOIN COURSE_6 C ON SE.COURSE_ID = C.COURSE_ID
),
CTE2 AS (
    SELECT DISTINCT 
        STUDENT_NAME, 
        COURSE_NAME, 
        STUDENT_TRACK,
        SUM(TOTAL_GRADES) OVER(PARTITION BY STUDENT_NAME, COURSE_NAME) AS TOTAL_GRADE 
    FROM CTE
)
SELECT DISTINCT 
    COURSE_NAME,
    NTH_VALUE(STUDENT_NAME, 1) OVER(
        PARTITION BY COURSE_NAME, STUDENT_TRACK 
        ORDER BY TOTAL_GRADE DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS STUDENT_NAME,
    STUDENT_TRACK,
    NTH_VALUE(TOTAL_GRADE, 1) OVER(
        PARTITION BY COURSE_NAME, STUDENT_TRACK 
        ORDER BY TOTAL_GRADE DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS TOTAL_GRADE 
FROM CTE2;
-----------------------------------------------------------------------
-- On each day, which product had the highest sales?
-- Create a table to show the day and the names of the product with highest qty sale.
WITH TBL AS (
  SELECT DAY, 
         PRODUCT,
         QTY,
         MAX(QTY) OVER (PARTITION BY DAY) AS MAXQTY
  FROM DEMANDS_7
)
SELECT *
FROM TBL
WHERE QTY = MAXQTY;
--------------------------------------------------------------------
--8. A retail business sells products whose performance is heavily influenced by seasonal and market trends. The company needs to clearly understand 
--the peak and low sales periods for each product category throughout the year. The objective is to determine:
--1.    The highest sales month and total sales for each category.
--2.    The lowest sales month and total sales for each category.

WITH CATEGORY_MONTHLY_SALES AS (
    SELECT P.CATEGORY, TO_CHAR(S.TRANS_DATE, 'MM-YYYY') SALES_MONTH, 
           SUM(S.QUANTITY * P.PRODUCT_PRICE) AS TOTAL_SALES
    FROM PRODUCTS_8 P
    INNER JOIN SALES_TRANSACTIONS_8 S
    ON P.PROD_ID = S.PROD_ID
    GROUP BY P.CATEGORY, TO_CHAR(S.TRANS_DATE, 'MM-YYYY')
)
SELECT DISTINCT CATEGORY,
                FIRST_VALUE(SALES_MONTH) OVER(PARTITION BY CATEGORY ORDER BY TOTAL_SALES DESC) HIGHEST_MONTH, 
                FIRST_VALUE(TOTAL_SALES) OVER(PARTITION BY CATEGORY ORDER BY TOTAL_SALES DESC) HIGHEST_VALUE,
                FIRST_VALUE(SALES_MONTH) OVER(PARTITION BY CATEGORY ORDER BY TOTAL_SALES ASC) LOWEST_MONTH, 
                FIRST_VALUE(TOTAL_SALES) OVER(PARTITION BY CATEGORY ORDER BY TOTAL_SALES ASC) LOWEST_VALUE
FROM CATEGORY_MONTHLY_SALES;
----------------------------------------------------------------
WITH DEPARTMENTSTATS AS (
    -- CALCULATE THE STANDARD DEVIATION OF REVENUE AND THE AVERAGE REVENUE FOR EACH DEPARTMENT
    SELECT
        DEPARTMENT_ID,
        STDDEV_SAMP(REVENUE) AS REVENUE_STDDEV,
        AVG(REVENUE) AS AVG_REVENUE,
        COVAR_SAMP(HOURS_WORKED, REVENUE) AS HOURS_REVENUE_COVARIANCE
    FROM 
        EMP_DATA_5
    GROUP BY 
        DEPARTMENT_ID
)
-- COMBINE RESULTS AND FLAG INCONSISTENT DEPARTMENTS
SELECT 
    DS.DEPARTMENT_ID,
    DS.REVENUE_STDDEV,
    DS.AVG_REVENUE,
    DS.HOURS_REVENUE_COVARIANCE,
    CASE 
        WHEN DS.REVENUE_STDDEV > 1.2 * DS.AVG_REVENUE THEN 'HIGH INCONSISTENCY'
        ELSE 'CONSISTENT'
    END AS CONSISTENCY_FLAG
FROM 
    DEPARTMENTSTATS DS
ORDER BY 
    DS.REVENUE_STDDEV DESC;


