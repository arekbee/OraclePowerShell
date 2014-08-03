$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\DatabaseModule.ps1" 
. "$here\OracleModule.ps1" 


#region sql query
#http://viralpatel.net/blogs/useful-oracle-queries/
$sqlHelpQueryCollection = @{
DatabaseSize= @'
select    round(sum(used.bytes) / 1024 / 1024  ) || ' MB' "Database Size"
,    round(sum(used.bytes) / 1024 / 1024  ) -
    round(free.p / 1024 / 1024) || ' MB' "Used space"
,    round(free.p / 1024 / 1024 ) || ' MB' "Free space"
from    (select    bytes
    from    v$datafile
    union    all
    select     bytes
    from     v$log) used
,    (select sum(bytes) as p
    from dba_free_space) free
group by free.p
'@;

ObjectSizes=@'
 SELECT owner,
         segment_name,
         segment_type,
         SUM (bytes) / 1024 / 1024 / 1024 GB,
         (SELECT DISTINCT table_name
            FROM dba_lobs
           WHERE segment_name = dba_segments.segment_name)
            lob_table_name
    FROM dba_segments
   WHERE tablespace_name LIKE 'DSO%'
GROUP BY owner, segment_name, segment_type
ORDER BY SUM (bytes) DESC
'@;

TablespaceStorage = @'
select t.tablespace_name "Tablespace",
       round(sum(bytes)/1048576) "Mbytes",
       round((sum(bytes)-nvl(sum(tfree),0))/1048576) "Alloc.",
       nvl(round(sum(tfree)/1048576),0) "Avail.",
       round(max(mfree)/1048576) "Max",
       nvl(round((sum(bytes)-sum(tfree))/sum(bytes)*100),100) "(%)"
from dba_data_files d,(select max(bytes) mfree,
                            sum(bytes) tfree,
                            tablespace_name ts,
                            file_id fid
                     from dba_free_space
                     group by tablespace_name,file_id),dba_tablespaces t
where (upper(t.contents)='PERMANENT' or upper(t.contents)='TEMPORARY' or upper(t.contents)='UNDO') and
      d.tablespace_name=t.tablespace_name and
      ts(+)=d.tablespace_name and
      fid(+)=file_id
group by t.tablespace_name
order by t.tablespace_name
'@;

IOUsagebySession = @'
SELECT NVL (ses.USERNAME, 'ORACLE PROC') username,
         ses.OSUSER,
         status,
         ses.action,
         ses.module,
         ses.client_info,
         PROCESS pid,
         ses.SID sid,
         SERIAL#,
         PHYSICAL_READS,
         BLOCK_GETS,
         CONSISTENT_GETS,
         BLOCK_CHANGES,
         CONSISTENT_CHANGES,
         PROGRAM,
         sql.sql_text
    FROM v$session ses, v$sess_io sio, v$sql sql
   WHERE ses.SID = sio.SID AND sql.ADDRESS = ses.SQL_ADDRESS
ORDER BY status, PHYSICAL_READS DESC, ses.USERNAME
'@;

TempUsage  =@'
 SELECT S.sid || ',' || S.serial# sid_serial,
         S.username,
         S.osuser,
         P.spid,
         S.module,
         S.program,
         SUM (T.blocks) * TBS.block_size / 1024 / 1024 mb_used,
         T.tablespace,
         COUNT (*) sort_ops
    FROM v$sort_usage T,
         v$session S,
         dba_tablespaces TBS,
         v$process P
   WHERE     T.session_addr = S.saddr
         AND S.paddr = P.addr
         AND T.tablespace = TBS.tablespace_name
GROUP BY S.sid,
         S.serial#,
         S.username,
         S.osuser,
         P.spid,
         S.module,
         S.program,
         TBS.block_size,
         T.tablespace
ORDER BY sid_serial
'@;

CurrentSchema = @'
SELECT SYS_CONTEXT ('userenv', 'current_schema') FROM DUAL
'@;

ServerVersion =@'
SELECT * FROM v$version
'@;

DatabaseCharacterSet =@'
SELECT * FROM nls_database_parameters
'@;

DatabaseExtentsSize = @'
select sum(BYTES)/1024/1024 MB from DBA_EXTENTS
'@;

DatabaseActualSize =@'
SELECT SUM (bytes) / 1024 / 1024 / 1024 AS GB FROM dba_data_files
'@;

DatabaseFiles =@'
select * from dba_data_files
'@;

LastSqlByUser =@'
SELECT S.USERNAME || '(' || s.sid || ')-' || s.osuser UNAME,
         s.program || '-' || s.terminal || '(' || s.machine || ')' PROG,
         s.sid || '/' || s.serial# sid,
         s.status "Status",
         p.spid,
         sql_text sqltext
    FROM v$sqltext_with_newlines t, V$SESSION s, v$process p
   WHERE     t.address = s.sql_address
         AND p.addr = s.paddr(+)
         AND t.hash_value = s.sql_hash_value
ORDER BY s.sid, t.piece;
'@;

CpuUsageByUser = @'
SELECT ss.username, se.SID, VALUE / 100 cpu_usage_seconds
    FROM v$session ss, v$sesstat se, v$statname sn
   WHERE     se.STATISTIC# = sn.STATISTIC#
         AND NAME LIKE '%CPU used by this session%'
         AND se.SID = ss.SID
         AND ss.status = 'ACTIVE'
         AND ss.username IS NOT NULL
ORDER BY VALUE DESC
'@;

ClientProcess = @'
SELECT b.sid,
       b.serial#,
       a.spid processid,
       b.process clientpid
  FROM v$process a, v$session b
 WHERE a.addr = b.paddr AND b.audsid = USERENV ('sessionid');
'@;

OracleConnections = @'
SELECT osuser,
         username,
         machine,
         program
    FROM v$session
ORDER BY osuser
'@;

OracleConnectionsApplication =@'
SELECT program application, COUNT (program) Numero_Sesiones
    FROM v$session
GROUP BY program
ORDER BY Numero_Sesiones DESC
'@;

OracleConnectionsUsers =@'
SELECT username Usuario_Oracle, COUNT (username) Numero_Sesiones
FROM v$session
WHERE username is not null
GROUP BY username
ORDER BY Numero_Sesiones DESC
'@;

DatabaseName = @'
select ora_database_name from dual
'@;

BackupSet =@'
  select ctime "Date"  
         , decode(backup_type, 'L', 'Archive Log', 'D', 'Full', 'Incremental') backup_type  
         , bsize "Size MB"  
    from (select trunc(bp.completion_time) ctime  
        , backup_type  
        , round(sum(bp.bytes/1024/1024),2) bsize  
       from v$backup_set bs, v$backup_piece bp  
       where bs.set_stamp = bp.set_stamp  
       and bs.set_count  = bp.set_count  
     and bp.status = 'A'  
     group by trunc(bp.completion_time), backup_type)  
  order by 1, 2

'@;


Instance = @'
select * from v$instance
'@;


OracleDataDictionary = @'
select * from dictionary
'@;


IntegrityRules =@'
select * from sys.all_cons_columns
'@;


OracleActualValue =@'
SELECT v.name, v.value value, decode(ISSYS_MODIFIABLE, 'DEFERRED',
'TRUE', 'FALSE') ISSYS_MODIFIABLE, decode(v.isDefault, 'TRUE', 'YES',
'FALSE', 'NO') "DEFAULT", DECODE(ISSES_MODIFIABLE, 'IMMEDIATE',
'YES','FALSE', 'NO', 'DEFERRED', 'NO', 'YES') SES_MODIFIABLE,
DECODE(ISSYS_MODIFIABLE, 'IMMEDIATE', 'YES', 'FALSE', 'NO',
'DEFERRED', 'YES','YES') SYS_MODIFIABLE , v.description
FROM V$PARAMETER v
WHERE name not like 'nls%' ORDER BY 1

'@;


OracleCache = @'
select sum(pins) pinSum, 
sum(reloads) reloadSum,
trunc(sum(reloads)/sum(pins)*100,2) percentage
from v$librarycache
where namespace in ('TABLE/PROCEDURE','SQL AREA','BODY','TRIGGER')
'@;


OracleStdFunction = @'
SELECT distinct object_name
FROM all_arguments
WHERE package_name = 'STANDARD'
order by object_name
'@;


DatabaseLocks = @'
select a.event , a.seconds_in_wait, s.status, s.state,  a.sid, a.wait_class, 
 s.username, s.machine, s.port, s.terminal, s.program, s.logon_time, s.lockwait, s.schemaname, s.osuser, s.process , s.module
from v$session_wait a, v$session s
where a.sid=s.sid
order by a.seconds_in_wait desc
'@;

}

#endregion

function Get-DynamicParam
{
    param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [array]$paramSet, 
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$paramName)

        $attributes = new-object System.Management.Automation.ParameterAttribute
        $attributes.ParameterSetName = "__AllParameterSets" 
        $attributes.Mandatory = $true
        $attributeCollection =      new-object -Type System.Collections.ObjectModel.Collection[System.Attribute]
        $attributeCollection.Add($attributes)
        $_Values  = $paramSet
        $ValidateSet =      new-object System.Management.Automation.ValidateSetAttribute($_Values)
        $attributeCollection.Add($ValidateSet)
        $dynParam1 = new-object -Type System.Management.Automation.RuntimeDefinedParameter( $paramName, [string], $attributeCollection)
        $paramDictionary = new-object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
        $paramDictionary.Add($paramName, $dynParam1)
        return $paramDictionary
}

function Invoke-OracleSqlHelpQuery
{
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$false)]
    [ValidateNotNull()]
    #[Oracle.DataAccess.Client.OracleConnection]
    $conn
    )

    dynamicParam {

        return Get-DynamicParam -paramSet $sqlHelpQueryCollection.Keys -paramName 'sqlHelpQuery'
       #$attributes = new-object System.Management.Automation.ParameterAttribute
       #$attributes.ParameterSetName = "__AllParameterSets" 
       #$attributes.Mandatory = $true
       #$attributeCollection =      new-object -Type System.Collections.ObjectModel.Collection[System.Attribute]
       #$attributeCollection.Add($attributes)
       #$_Values  = $sqlHelpQueryCollection.Keys
       #$ValidateSet =      new-object System.Management.Automation.ValidateSetAttribute($_Values)
       #$attributeCollection.Add($ValidateSet)
       #$dynParam1 = new-object -Type System.Management.Automation.RuntimeDefinedParameter( "sqlHelpQuery", [string], $attributeCollection)
       #$paramDictionary = new-object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
       #$paramDictionary.Add("sqlHelpQuery", $dynParam1)
       #return $paramDictionary
    }

    begin{}
    process{
    $sql = $sqlHelpQueryCollection[$sqlHelpQuery]
    return Get-OracleDataTable -conn $conn -sql $sql
    }
    end{}
}

 