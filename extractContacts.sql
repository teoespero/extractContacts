-- lets create our temp table that will
-- hold our district names
CREATE TABLE #tmpDatabases (
  ID int IDENTITY (1, 1) PRIMARY KEY,
  NAME nvarchar(100),
  SERVERNAME nvarchar(100),
  [READONLY] bit
);

-- fill it in with the dbNames
-- avoiding global and system related dbs
INSERT INTO #tmpDatabases (NAME, SERVERNAME, [READONLY])
  SELECT
    DatabaseName,
    ServerName,
    [ReadOnly]
  FROM DS_Admin..ADMIN_Districts
  WHERE (
  DatabaseName NOT LIKE '%demo%'
  AND DatabaseName NOT LIKE '%temp%'
  AND DatabaseName NOT LIKE '%ext%'
  AND DatabaseName NOT LIKE '%staff%'
  AND DatabaseName NOT LIKE '%test%'
  AND DatabaseName NOT LIKE '%dev%'
  AND DatabaseName LIKE 'ds%'
  )
  AND ServerName LIKE '%' + @@SERVERNAME + '%'
  AND ISNULL([ReadOnly], 0) = 0

------------------------------------------------------------------------------------------------------------------------------------------
-- begin the check process
-- Declare SQLString as nvarchar(4000)
-- for instances where we are connecting to a SQL Server 2000 instance,
-- we cannot use varchar(max) because this is a feature
-- introduced on SQL Server 2005
DECLARE @SQLString AS nvarchar(4000)
DECLARE @DS AS nvarchar(100)
DECLARE @DistrictCount int
DECLARE @Looper int

SET @Looper = 1

-- get the number of sites
SELECT
  @DistrictCount = COUNT(*)
FROM #tmpDatabases;


-- this part creates our temp table
-- that will hold our list
CREATE TABLE #myList (
  ID int IDENTITY (1, 1) PRIMARY KEY,
  County nvarchar(300),
  DistrictID int,
  DistrictTitle nvarchar(300),
  DistrictAbbrev nvarchar(300),
  SecurityGroupNum int,
  GroupName nvarchar(300),
  Fullname nvarchar(150),
  LName nvarchar(150),
  FName nvarchar(150),
  Email nvarchar(250),
  AppManager varchar(3),
  TierOne varchar(3),
  ContactType nvarchar(250)
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
    EXISTS (SELECT
      *
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_NAME = 'tblSecurityGroup')
    )
  BEGIN
    -- process each district
    SELECT
      @DS = NAME
    FROM #tmpDatabases
    WHERE ID = @looper

    SET @SQLString = '
                    insert into #myList(
           County,  
                     DistrictID,
                     DistrictTitle,
                     DistrictAbbrev,
                     SecurityGroupNum,
                     GroupName,
                     Fullname,
           LName,
           FName,
                     Email,
                     AppManager,
                     TierOne,
           ContactType
                    )
                    select
                        distinct
            cast([CountySetting].[Setting] as varchar(200)),
                        di.DistrictId,
                        di.DistrictTitle,
                        di.DistrictAbbrev,
                        sg.SecurityGroupNum,
                        sg.GroupName,
                        te.fullname,
            te.LName,
            te.FName,
                        lower(te.email),
                        (case when isnull(tu.IsPrimaryContact,0) = 1 then ''Yes'' else ''No'' end) as AppManager,
                        (case when isnull(tu.IsKeyContact,0) = 1 then ''Yes'' else ''No'' end) as TierOne,
            ct.[Description]
                    from ' + @DS + '..tblSecurityGroup sg
                    left join ' + @DS + '..tblUsers tu on sg.SecurityGroupNum = tu.SecurityGroup and (tu.inactiveDate is NULL or tu.inactiveDate >= GetDate())
                    left join ' + @DS + '..tblDistrict di on tu.DistrictID = di.DistrictID
                    left join ' + @DS + '..tblEmployee te on tu.EmployeeId = te.EmployeeId and (te.terminateDate is NULL or te.terminatedate >= GetDate())
          left join DS_Global..ContactType ct on tu.ContactType = ct.id
          cross join (select isnull(Setting,'''') as [Setting] from ' + @DS + '..tblDistrictSetting where Name = ''County'') [CountySetting]
                    where te.email is not null and (IsPrimaryContact != 0 or IsKeyContact != 0)
          and tu.employeeid > 0
          and te.fname is not null
          and te.email like ''[a-z,0-9,_,-]%@[a-z,0-9,_,-]%.[a-z][a-z]%'' 
          and te.email NOT like ''%@%@%''  
          and charindex(''.@'',te.email) = 0  
          and charindex(''..'',te.email) = 0  
          and charindex('','',te.email) = 0  
          and right(te.email,1) between ''a'' and ''z''  
          and te.lname is not null;';

    -- run our string as an SQL
    EXECUTE sp_executesql @SQLString
  END


  SET @looper = @looper + 1
END

-- get our list
SELECT
  *
FROM #myList
ORDER BY County ASC,
DistrictTitle ASC,
SecurityGroupNum ASC,
Fullname ASC

-- housekeeping
DROP TABLE #tmpDatabases
DROP TABLE #myList