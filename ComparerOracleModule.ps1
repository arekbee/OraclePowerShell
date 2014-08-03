$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\DatabaseModule.ps1" 
. "$here\OracleModule.ps1" 


$ownerExcludsion = @('EXFSYS','OUTLN','PUBLIC','SYS','SYSTEM','XDB','DBSNMP','ORACLE','APPQOSSYS')
#http://www.techonthenet.com/oracle/sys_tables/


function Get-OracleSystemTables
{
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [Oracle.DataAccess.Client.OracleConnection]$conn,

[Parameter(Mandatory=$false)]
[ValidateSet('ALL_ARGUMENTS'
,'ALL_CATALOG'
,'ALL_COL_COMMENTS'
,'ALL_CONSTRAINTS'
,'ALL_CONS_COLUMNS'
,'ALL_DB_LINKS'
,'ALL_ERRORS'
,'ALL_INDEXES'
,'ALL_IND_COLUMNS'
,'ALL_LOBS'
,'ALL_OBJECTS'
,'ALL_OBJECT_TABLES'
,'ALL_SEQUENCES'
,'ALL_SNAPSHOTS'
,'ALL_SOURCE'
,'ALL_SYNONYMS'
,'ALL_TABLES'
,'ALL_TAB_COLUMNS'
,'ALL_TAB_COL_STATISTICS'
,'ALL_TAB_COMMENTS'
,'ALL_TRIGGERS'
,'ALL_TRIGGER_COLS'
,'ALL_TYPES'
,'ALL_UPDATABLE_COLUMNS'
,'ALL_USERS'
,'ALL_VIEWS'
,'DATABASE_COMPATIBLE_LEVEL'
,'DBA_DB_LINKS'
,'DBA_ERRORS'
,'DBA_OBJECTS'
,'DBA_ROLES'
,'DBA_ROLE_PRIVS'
,'DBA_SOURCE'
,'DBA_TABLESPACES'
,'DBA_TAB_PRIVS'
,'DBA_TRIGGERS'
,'DBA_TS_QUOTAS'
,'DBA_USERS'
,'DBA_VIEWS'
,'DICTIONARY'
,'DICT_COLUMNS'
,'GLOBAL_NAME'
,'NLS_DATABASE_PARAMETERS'
,'NLS_INSTANCE_PARAMETERS'
,'NLS_SESSION_PARAMETERS'
,'PRODUCT_COMPONENT_VERSION'
,'ROLE_TAB_PRIVS'
,'SESSION_PRIVS'
,'SESSION_ROLES'
,'SYSTEM_PRIVILEGE_MAP'
,'TABLE_PRIVILEGES'
,'TABLE_PRIVILEGE_MAP')]
[string]$SystemTable
,
[switch]$WithSystemTables
)
[string]$sql = "select * from $SystemTable "
if(!$WithSystemTables)
{
    $sql += " where owner not in ('$($ownerExcludsion -join "','")')"
}

return Get-OracleDataTable -conn $conn -sql $sql
}




function Get-OracleDdl()
{
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true)]
   [string]$object_type,
   [Parameter(Mandatory=$true)]
   [string]$name,
   [string]$schema  =$null,
   [string]$version ='COMPATIBLE',
   [string]$model    = 'ORACLE',
   [string]$transform ='DDL'
   )

    SELECT DBMS_METADATA.GET_DDL($object_type,$name,$schema,$version, $model, $transform ) FROM DUAL;
}

function Get-OracleDdlGrant
{
    [CmdletBinding()]
    param(
[Parameter(Mandatory=$true)]
[validateSet(
'OBJECT_GRANT',
'SYSTEM_GRANT',
'ROLE_GRANT',
'DEFAULT_ROLE'
)]
[string]$object_type,
[string]$grantee= $NULL,
[string]$version ='COMPATIBLE',
[string]$model  ='ORACLE',
[string]$transform ='DDL',
[string]$object_count =10000
)

    select dbms_metadata.get_granted_ddl($object_type, $grantee,$version,$model,$transform,$object_count)  

}


function Get-OracleDdlXml()
{
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true)]
   [string]$object_type,
   [Parameter(Mandatory=$true)]
   [string]$name,
   [string]$schema  =$null,
   [string]$version ='COMPATIBLE',
   [string]$model    = 'ORACLE',
   [string]$transform ='DDL'
   )

    select dbms_metadata.get_xml($object_type,$name,$schema,$version, $model, $transform ) FROM DUAL;
}

