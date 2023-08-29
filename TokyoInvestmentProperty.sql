select *
from property_transaction;

/* 
EDA SECTION

Numerical values: min, max, avg, avg by municipality
- TradePrice
- Area
- UnitPrice (To be calculated)

Categorical: Count by group, distinct values
- Municipality
- FloorPlan
- Building Year
- Structure
- YearSold
- YearQuarter
*/

-- Basic info about TradePrice, Area, UnitPrice w/o group
select min(tradePrice), max(tradePrice), avg(tradeprice),
min(Area), max(Area), avg(Area),
min(tradePrice/Area), max(tradePrice/Area), avg(tradePrice/Area)
from property_transaction
where (BuildingType != 'Forest Land'  and BuildingType != 'Agricultural Land');

-- Basic info about TradePrice, Area and UnitPrice w group
select municipality, min(tradePrice), max(tradePrice), avg(tradePrice), avg(area), avg(tradeprice/area) as AvgUnitPrice
from property_transaction
group by municipality
order by AvgUnitPrice desc;

select floorplan, count(floorplan)
from property_transaction
group by floorplan
order by count(floorplan) desc;

select sum(floorplan is null) as 'NA'
from property_transaction;

select structure, count(structure)
from property_transaction
group by structure
order by count(structure) desc;

WITH CTE_BuildingDecade as (
select buildingYear,
Case
	When buildingYear >= 1940 and buildingYear < 1950 THEN '1940s'
    When buildingYear >= 1950 and buildingYear < 1960 THEN '1950s'
    When buildingYear >= 1960 and buildingYear < 1970 THEN '1960s'
    When buildingYear >= 1970 and buildingYear < 1980 THEN '1970s'
    When buildingYear >= 1980 and buildingYear < 1990 THEN '1980s'
    When buildingYear >= 1990 and buildingYear < 2000 THEN '1990s'
    When buildingYear >= 2000 and buildingYear < 2010 THEN '2000s'
    When buildingYear >= 2010 and buildingYear < 2020 THEN '2010s'
End decade
from property_transaction
where buildingYear != 0
order by buildingyear
)
Select decade, count(decade) as DecadeBuilt
from CTE_BuildingDecade
group by decade;

-- Find avg by municipality and labels trade price against this avg
WITH CTE_priceMunicipality1LDK as(
select Municipality, AVG(TradePrice) as AverageTradeByMunicipality
from property_transaction
where floorPlan = '1LDK' and TradePrice > 1000000
group by Municipality
order by AverageTradeByMunicipality asc
)
Select ID, MunicipalityCode, Prefecture, property_transaction.Municipality, DistrictName, TradePrice, FloorPlan, Area, BuildingYear, Structure, AverageTradeByMunicipality, 
CASE
	WHEN TradePrice < AverageTradeByMunicipality THEN 'GOOD INVESTEMENT'
    WHEN tradePrice > AverageTradeByMunicipality THEN 'BAD INVESTMENT'
    ELSE 'EVEN'
END AS InvestOrNot
From property_transaction left join CTE_priceMunicipality1LDK
on property_transaction.Municipality = CTE_priceMunicipality1LDK.Municipality
where property_transaction.TradePrice > 1000000
and property_transaction.FloorPlan = '1LDK' and BuildingYear >= 2000
order by property_transaction.TradePrice asc, InvestOrNot desc;


                
CREATE temporary table Temp_depricProp (
ID INTEGER,
MunicipalityCode INTEGER,
Municipality varchar(255),
DistrictName varchar(255),
MinTimeToNearestStation INTEGER,
MaxTimeToNearestStation INTEGER,
TradePrice BIGINT,
FloorPlan varchar(255),
Area INTEGER,
UnitPrice INTEGER,
BuildingYear INTEGER,
Structure varchar(255),
Uses varchar(255),
YearSold INTEGER,
YearQuarter INTEGER,
Renovation varchar(255),
avgTradeMun BIGINT,
HouseValueExists varchar(255)
);                
                
                    
-- Determine if there is any property value left, or if all depreciated     
Insert into Temp_depricProp                
WITH CTE_municipalityAvg as(
Select Municipality, Avg(tradePrice) as avgTradeMun
from property_transaction
where floorplan = '1LDK'
group by Municipality
)
Select ID, MunicipalityCode, property_transaction.Municipality, DistrictName, MinTimeToNearestStation, MaxTimeToNearestStation, TradePrice, FloorPlan,
Area, UnitPrice, BuildingYear, Structure, Uses, YearSold, YearQuarter, Renovation, avgTradeMun,
CASE
	When structure = 'W' and 2023-BuildingYear < 22 THEN 'Yes'
    When structure = 'W' and 2023-BuildingYear > 22 THEN 'No'
    When structure = 'B' and 2023-BuildingYear < 47 THEN 'Yes'
    When structure = 'B' and 2023-BuildingYear > 47 THEN 'No'
    When structure = 'SRC' and 2023-BuildingYear < 47 THEN 'Yes'
    When structure = 'SRC' and 2023-BuildingYear > 47 THEN 'No'
    When structure = 'RC' and 2023-BuildingYear < 47 THEN 'Yes'
    When structure = 'RC' and 2023-BuildingYear > 47 THEN 'No'
    When structure = 'S' and 2023-BuildingYear < 60 THEN 'Yes'
    When structure = 'S' and 2023-BuildingYear > 60 THEN 'No'
    When structure = 'LS' and 2023-BuildingYear < 60 THEN 'Yes'
    When structure = 'LS' and 2023-BuildingYear > 60 THEN 'No'
END AS HouseValueExists
From property_transaction left join CTE_municipalityAvg
on property_transaction.Municipality = CTE_municipalityAvg.Municipality
where property_transaction.renovation = 'Done' and property_transaction.tradePrice < avgTradeMun;


-- Create a temporary table for calculating the price per m^2 by municipality
-- Include unique identifier
create temporary table PriceMeterSquared (
ID INTEGER,
MunicipalityCode INTEGER,
Municipality varchar(255),
DistrictName varchar(255),
TradePrice BIGINT,
FloorPlan varchar(255),
Area INTEGER,
CalculatedUnitPrice Double
);

Insert into PriceMeterSquared
select ID, MunicipalityCode, Municipality, DistrictName, TradePrice,
FloorPlan, Area, AVG(TradePrice/Area) OVER (Partition by Municipality) as CalculatedUnitPrice
from property_transaction;

-- Output excel file to work in Tableau
select *, Temp_depricProp.tradePrice/Temp_depricProp.area as RealUnitPrice
from Temp_depricProp left join PriceMeterSquared
on Temp_depricProp.ID = PriceMeterSquared.ID
where HouseValueExists = 'Yes' AND Temp_depricProp.tradePrice/Temp_depricProp.area < CalculatedUnitPrice
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/output.csv' FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\r\n';

