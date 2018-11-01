-- lets create our temp table that will
-- hold our district names
CREATE TABLE #tmpDatabases (
 ID INT IDENTITY(1, 1) PRIMARY KEY,
 NAME NVARCHAR(100),
 SERVERNAME NVARCHAR(100)
 );
 
-- fill it in with the dbNames
-- avoiding global and system related dbs
INSERT INTO #tmpDatabases (NAME, SERVERNAME)
select 
  DatabaseName,
  ServerName
from DS_Admin..ADMIN_Districts
where
  (DatabaseName not like '%demo%' and DatabaseName not like '%temp%' and DatabaseName not like '%ext%' and DatabaseName not like '%staff%')
  and ServerName = @@SERVERNAME
 
--select * from #tmpDatabases
--drop table #tmpDatabases
 
 
------------------------------------------------------------------------------------------------------------------------------------------
-- begin the check process
-- Declare SQLString as nvarchar(4000)
-- for instances where we are connecting to a SQL Server 2000 instance,
-- we cannot use varchar(max) because this is a feature
-- introduced on SQL Server 2005
DECLARE @SQLString AS NVARCHAR(4000)
DECLARE @DS AS NVARCHAR(100)
DECLARE @DistrictCount INT
DECLARE @Looper INT
 
SET @Looper = 1
 
-- get the number of sites
SELECT @DistrictCount = COUNT(*)
FROM #tmpDatabases;
 
 
-- this part creates our temp table
-- that will hold our list
CREATE TABLE #myList (
 ID INT IDENTITY(1, 1) PRIMARY KEY,
 DistrictID INT,
 DistrictTitle NVARCHAR(300),
 DistrictAbbrev NVARCHAR(300),
 SecurityGroupNum INT,
 GroupName NVARCHAR(300),
 Fullname NVARCHAR(150),
 Email NVARCHAR(250),
 AppManager Varchar(3),
 TierOne Varchar(3)
 );
 
-- crawl process
-- this part is where SQL is made to crawl the
-- different sites base on the entries
-- of #tmpDatabases
WHILE (@looper <= @DistrictCount)
BEGIN
 -- only do the check if tblSecurityGroup exist
 -- could be redundant since we are already
 -- screening out non district replated dbs
 IF (
      EXISTS (
    SELECT *
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_NAME = 'tblSecurityGroup'
    )
      )
 BEGIN
  -- process each district
  SELECT @DS = NAME
  FROM #tmpDatabases
  WHERE ID = @looper
 
  SET @SQLString = '
                    insert into #myList(
                     DistrictID,
                     DistrictTitle,
                     DistrictAbbrev,
                     SecurityGroupNum,
                     GroupName,
                     Fullname,
                     Email,
                     AppManager,
                     TierOne
                    )
                    select
                        distinct
                        di.DistrictId,
                        di.DistrictTitle,
                        di.DistrictAbbrev,
                        sg.SecurityGroupNum,
                        sg.GroupName,
                        te.FullName,
                        te.email,
                        (case when tu.IsPrimaryContact = 1 then ''Yes'' else ''No'' end) as AppManager,
                        (case when tu.IsKeyContact = 1 then ''Yes'' else ''No'' end) as TierOne
                    from ' + @DS + '..tblSecurityGroup sg
                    left join ' + @DS + '..tblUsers tu on sg.SecurityGroupNum = tu.SecurityGroup and tu.inactiveDate is NULL
                    left join ' + @DS + '..tblDistrict di on tu.DistrictID = di.DistrictID
                    left join ' + @DS + '..tblEmployee te on tu.EmployeeId = te.EmployeeId and te.terminateDate is NULL
                    where te.email is not null and (IsPrimaryContact != 0 or IsKeyContact != 0);' ;
 
  -- run our string as an SQL
  EXECUTE sp_executesql @SQLString
 END
 
 
 SET @looper = @looper + 1
END
 
select * from #myList
order by
    DistrictTitle asc,
    SecurityGroupNum asc,
    Fullname asc
 
 
drop table #tmpDatabases
drop table #myList