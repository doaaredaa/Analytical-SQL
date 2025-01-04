--
-- 1. You want to calculate the time difference between consecutive purchases for each customer and identify their previous and next purchase amounts.

SELECT CUSTOMER_ID, 
            PURCHASE_DATE, 
            PURCHASE_AMOUNT,
            
            LAG(PURCHASE_AMOUNT, 1, 0) OVER(PARTITION BY CUSTOMER_ID 
            ORDER BY PURCHASE_DATE) AS PREVIOUS_PURCHASE,
            
            LEAD(PURCHASE_AMOUNT, 1, 0) OVER(PARTITION BY CUSTOMER_ID 
            ORDER BY PURCHASE_DATE) AS NEXT_PURCHASE,
            ----------------------
            LAG(TO_CHAR(PURCHASE_DATE, 'FMDD-MON-YYYY'), 1, NULL) 
            OVER(PARTITION BY CUSTOMER_ID ORDER BY PURCHASE_DATE) 
            AS PREVIOUS_PURCHASE_DATE,
            
            LEAD(TO_CHAR(PURCHASE_DATE, 'FMDD-MON-YYYY'), 1, NULL) 
            OVER(PARTITION BY CUSTOMER_ID ORDER BY PURCHASE_DATE) 
            AS NEXT_PURCHASE_DATE,
            --------------------------------
            ( NVL(PURCHASE_DATE, NULL) - LAG(PURCHASE_DATE, 1, NULL) 
            OVER(PARTITION BY CUSTOMER_ID ORDER BY PURCHASE_DATE) ) 
            AS DAYS_SINCE_LAST_PURCHASE,
            
            ( LEAD(PURCHASE_DATE, 1, NULL) OVER(PARTITION BY CUSTOMER_ID 
            ORDER BY PURCHASE_DATE) - NVL(PURCHASE_DATE, NULL) ) 
            AS DAYS_UNTIL_NEXT_PURCHASE

FROM CUSTOMER_PURCHASES;

----------------------------------------------------------------------------------------------
--1)  Evaluate Team Productivity For each department, calculate:
-- The cumulative hours worked over time.
-- The cumulative revenue generated over time.
-- Rank the employees by their contribution to revenue in their department.

SELECT   EMP_ID, 
              EMP_NAME, 
              DEPARTMENT, 
              REVENUE_GENERATED, 
              EVALUATION_DATE, 
              HOURS_WORKED, 
              
              SUM(HOURS_WORKED) OVER(PARTITION BY DEPARTMENT 
              ORDER BY EVALUATION_DATE) AS "Cumulative hours worked",

             SUM(REVENUE_GENERATED) OVER(PARTITION BY DEPARTMENT 
             ORDER BY EVALUATION_DATE) AS "Cumulative revenue generated",

             RANK() OVER(PARTITION BY DEPARTMENT 
             ORDER BY REVENUE_GENERATED DESC) AS "Ranking Emps"
          
FROM EMPLOYEE_PERFORMANCE;

-------------------------------------------------------------------------------------------------
--3. Identify Revenue Growth Trends
-- Calculate the revenue growth rate for each employee relative to their previous evaluation.
-- Revenue Growth Rate= ((Revenue in Current Period - Revenue in Previous Period) /Revenue in Previous Period) * 100

SELECT EMP_ID, 
            EMP_NAME, 
            DEPARTMENT, 
            TO_CHAR(EVALUATION_DATE, 'FMDD-MON-YYYY') 
            AS EVALUATION_DATE , REVENUE_GENERATED,
            ----------------------------
            LAG(REVENUE_GENERATED,1,NULL) OVER(PARTITION BY EMP_ID 
            ORDER BY EVALUATION_DATE) AS "Previous evaluation",
            -------------------------
            ((REVENUE_GENERATED - NVL(LAG(REVENUE_GENERATED,1,NULL) 
            OVER(PARTITION BY EMP_ID ORDER BY EVALUATION_DATE),NULL))
            
            /NVL(LAG(REVENUE_GENERATED,1,NULL) OVER(PARTITION BY EMP_ID 
            ORDER BY EVALUATION_DATE),NULL))*100 AS "Revenue growth rate"
            
FROM EMPLOYEE_PERFORMANCE;
-------------------------------------------------------------------------------------------------
--4. Identify employees whose revenue falls below the average revenue for their department.

WITH CTE_REVENUE (EMP_ID, EMP_NAME, DEPARTMENT, TOTAL_REV_FOR_EACH_EMP ) AS
        (SELECT EMP_ID, 
                     EMP_NAME , 
                     DEPARTMENT, 
                     SUM(REVENUE_GENERATED) AS TOTAL_REV_FOR_EACH_EMP
                     
        FROM EMPLOYEE_PERFORMANCE
        GROUP BY EMP_ID, EMP_NAME, DEPARTMENT)
---------------------
SELECT EMP_ID, 
            EMP_NAME, 
            DEPARTMENT, 
            TOTAL_REV_FOR_EACH_EMP AS REVENUE_GENERATED, 
            
            AVG(TOTAL_REV_FOR_EACH_EMP) OVER(PARTITION BY DEPARTMENT) AS AVG_REVENUE,
            
            CASE WHEN TOTAL_REV_FOR_EACH_EMP < AVG(TOTAL_REV_FOR_EACH_EMP) 
                                OVER(PARTITION BY DEPARTMENT) THEN 'LOW PERFORMANCE'
                                
                     WHEN TOTAL_REV_FOR_EACH_EMP >= AVG(TOTAL_REV_FOR_EACH_EMP) 
                                OVER(PARTITION BY DEPARTMENT) THEN 'GOOD PERFORMANCE'
                                
             END AS PERFORMANCE_FLAG
             
FROM CTE_REVENUE;
---------------------------------------------------------------------------------------------------------
--5. Flag employees whose revenue differs significantly (e.g., >20%) from the average revenue in their department.

WITH CTE_REVENUE (EMP_ID, EMP_NAME, DEPARTMENT, TOTAL_REV_FOR_EACH_EMP ) AS
        (SELECT EMP_ID, 
                     EMP_NAME , 
                     DEPARTMENT, 
                     SUM(REVENUE_GENERATED) AS TOTAL_REV_FOR_EACH_EMP
                     
        FROM EMPLOYEE_PERFORMANCE
        GROUP BY EMP_ID, EMP_NAME, DEPARTMENT)
---------------------
SELECT EMP_ID, 
            EMP_NAME, 
            DEPARTMENT, 
            TOTAL_REV_FOR_EACH_EMP AS REVENUE_GENERATED, 
            
            AVG(TOTAL_REV_FOR_EACH_EMP) OVER(PARTITION BY DEPARTMENT) AS AVG_REVENUE,
            
            CASE WHEN TOTAL_REV_FOR_EACH_EMP >=  1.2* AVG(TOTAL_REV_FOR_EACH_EMP)  -- (1.2 * AVG_REVENUE) for "HIGH REVENUE" (greater than 20% above average).
                                OVER(PARTITION BY DEPARTMENT) THEN 'INCONSISTENT (HIGHT) REVENUE'
                                
                     WHEN TOTAL_REV_FOR_EACH_EMP <= 0.8* AVG(TOTAL_REV_FOR_EACH_EMP)  --(0.8 * AVG_REVENUE) for "LOW REVENUE" (less than 20% below average).
                                OVER(PARTITION BY DEPARTMENT) THEN 'INCONSISTENT (LOW) REVENUE'
                                
            ELSE  'CONSISTENT REVENUE'                     
             END AS PERFORMANCE_FLAG
FROM CTE_REVENUE;
---------------------------------------------------------------------------------------------------------
--6. Rank employees by revenue generated per hour worked in their department.
WITH CTE_REV_HOUR AS
        (SELECT EMP_NAME,
                     DEPARTMENT, 
                     REVENUE_GENERATED,
                     HOURS_WORKED,  
                     ROUND((SUM(REVENUE_GENERATED) / SUM(HOURS_WORKED) ), 2) AS REVENUE_PER_HOUR
                     
         FROM EMPLOYEE_PERFORMANCE
         GROUP BY  EMP_NAME, DEPARTMENT, REVENUE_GENERATED, HOURS_WORKED )
------------------------         
SELECT EMP_NAME, 
            DEPARTMENT, 
            REVENUE_GENERATED, 
            HOURS_WORKED, 
            REVENUE_PER_HOUR,
            RANK() OVER(PARTITION BY DEPARTMENT ORDER BY REVENUE_PER_HOUR DESC) AS RANKING
FROM CTE_REV_HOUR; 
---------------------------------------------------------------------------------------
--7. Identify Performance Drop
--Identify employees whose revenue dropped by more than 30% compared to their previous evaluation.
SELECT *
FROM (
                SELECT EMP_NAME, 
                            DEPARTMENT, 
                            TO_CHAR(EVALUATION_DATE, 'FMDD-MON-YYYY') AS EVALUATION_DATE,
                            REVENUE_GENERATED,
                            -----------------------
                            LAG(REVENUE_GENERATED, 1, 0) OVER(PARTITION BY EMP_NAME 
                            ORDER BY EVALUATION_DATE) AS PREVIOUS_REVENUE,
                            ----------------------
                            ((REVENUE_GENERATED - LAG(REVENUE_GENERATED, 1, 0) 
                            OVER(PARTITION BY EMP_NAME ORDER BY EVALUATION_DATE)) 
                            
                            /  LAG(REVENUE_GENERATED, 1, NULL) OVER(PARTITION BY EMP_NAME 
                            ORDER BY EVALUATION_DATE))*100  AS REVENUE_CHANGE_PERCENTAGE
                            
                FROM EMPLOYEE_PERFORMANCE ) X
WHERE X.REVENUE_CHANGE_PERCENTAGE <30;
------------------------------------------------------------------
--8. Flag Overloaded Employees
--Identify employees whose hours worked exceed the average hours worked for their department by more than 25%.

WITH CTE__TOTAL_HOURS  AS 
            (SELECT EMP_NAME,
                          DEPARTMENT, 
                          SUM(HOURS_WORKED) AS HOURS_FOR_EACH_EMP
            FROM EMPLOYEE_PERFORMANCE
            GROUP BY EMP_NAME, DEPARTMENT)
 --------------------------           
SELECT EMP_NAME, 
            DEPARTMENT, 
            HOURS_FOR_EACH_EMP,
            AVG(HOURS_FOR_EACH_EMP) OVER(PARTITION BY DEPARTMENT) AS AVG_HOURS_WORKED,
            CASE WHEN HOURS_FOR_EACH_EMP > 1.25* AVG(HOURS_FOR_EACH_EMP) OVER(PARTITION BY DEPARTMENT) THEN  'UNNORMAL'  
            ELSE 'NORMAL'
            END AS WORKLOAD_FLAG
            
FROM CTE__TOTAL_HOURS;
------------------------------------------------------------------
--9. Find the top contributor (employee) to each project based on revenue generated.
SELECT * 
FROM (
                WITH CTE_PROJECT AS
                            (SELECT PROJECT_ID, 
                                        EMP_NAME,
                                        SUM(REVENUE_GENERATED) AS TOTAL_REV_FOR_EACH_EMP
                            FROM EMPLOYEE_PERFORMANCE
                            GROUP BY PROJECT_ID, EMP_NAME)
                            
                SELECT PROJECT_ID, 
                            EMP_NAME, 
                            TOTAL_REV_FOR_EACH_EMP AS REVENUE_GENERATED,
                            RANK() OVER(PARTITION BY PROJECT_ID ORDER BY TOTAL_REV_FOR_EACH_EMP DESC) AS TOP_RANKING_EMPS
                            
                FROM CTE_PROJECT) X
WHERE X.TOP_RANKING_EMPS < 2;                






