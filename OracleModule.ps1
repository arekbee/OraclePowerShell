
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\DatabaseModule.ps1" 


function Load-OracleAssemblyes
{
    [CmdletBinding()]
    param([string[]]$pathToOracleDataAccessDll)

    
    Load-DatabaseAssemblyes
    [void][Reflection.Assembly]::LoadWithPartialName('System.Data.OracleClient')


    if($pathToOracleDataAccessDll)
    {
      $pathToOracleDataAccessDll | %{
        [void][System.Reflection.Assembly]::LoadFrom($_)
        }
    }else
    {
      [void][Reflection.Assembly]::LoadWithPartialName('Oracle.DataAccess')
    }
}

function Get-LoadedOracleAssemblyes
{
    [appdomain]::CurrentDomain.GetAssemblies() | ?{$_.FullName.ToUpper().Contains('ORACLE')}
}

function Get-OracleConnectionString($user, $pass, $hostName, $port, $sid)
{
    $dataSource = ('(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST={0})(PORT={1}))(CONNECT_DATA=(SERVICE_NAME={2})))' -f $hostName, $port, $sid)
    return ('Data Source={0}User Id={1}Password={2}Connection Timeout=10' -f $dataSource, $user, $pass)
}

function Get-OracleTNSDataSources
{
    $enu = New-Object 'Oracle.DataAccess.Client.OracleDataSourceEnumerator'
    return $enu.GetDataSources()
}

function New-OracleConnection ([string] $connectionString)
{
    [string]$oracleConnectionType = 'Oracle.DataAccess.Client.OracleConnection'
    if($connectionString)
    {
        return new-object -TypeName $oracleConnectionType -ArgumentList $connectionString 
    }
    else
    {
        return new-object -TypeName $oracleConnectionType
    }
}

function Get-OracleServerVersion
{
[CmdletBinding()]
    param(
     [string]$connectionString 
    )
    
    $version="-1"

    $oracleConnection = New-OracleConnection $connectionString 
    try
    {
        $oracleConnection.Open()
        $version = $oracleConnection.ServerVersion
    }
    Finally
    {
        $oracleConnection.Close()
    }
    return $version
}

function Get-TnsOracleConnectionString()
{
    $file = join-path $env:TNS_NAMES 'tnsnames.ora'
   
    $pettern = '(?<alias>^[A-Z][A-Z0-9\.]+)\=(?<source>\(+.+\)+).+'
    $tnsContent = gc $file
    $commentlessTnsContent = $tnsContent | ? {-not $_.ToString().StartsWith('#')}  | select-string $pettern 

    $commentlessTnsContent | %{
        $_.Line -match $pettern | out-Null
        $alias = $matches['alias']
        $source = $matches['source']

        $rAliasAndSource = new-object PSObject
        $rAliasAndSource | Add-Member -MemberType NoteProperty -Name Alias -Value $alias
        $rAliasAndSource | Add-Member -MemberType NoteProperty -Name Source -Value $source 
        $rAliasAndSource 
    }

}

function Get-OracleDataTable 
{
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [Oracle.DataAccess.Client.OracleConnection]$conn, 
    [Parameter(Mandatory=$false)]
    [string]$sql,
    [Parameter(Mandatory=$false)]
    [string]$file
)
    if($file)
    {
      $sql = gc $file
    }
    $cmd = New-Object Oracle.DataAccess.Client.OracleCommand($sql,$conn)
    $da = New-Object Oracle.DataAccess.Client.OracleDataAdapter($cmd)
    $dt = New-Object System.Data.DataTable
    [void]$da.Fill($dt) 
    return ,$dt
}


function Get-OracleDbTypeMapping
{

    $mapping =   @{}     
    $mapping.Add([byte] , [Oracle.DataAccess.Client.OracleDbType]::Byte)
    $mapping.Add( [byte[]] , [Oracle.DataAccess.Client.OracleDbType]::Raw            )
    $mapping.Add( [sbyte], [Oracle.DataAccess.Client.OracleDbType]::Byte             )
    $mapping.Add( [sbyte[]], [Oracle.DataAccess.Client.OracleDbType]::Raw            )
    $mapping.Add( [char], [Oracle.DataAccess.Client.OracleDbType]::Varchar2          )
    $mapping.Add( [char[]], [Oracle.DataAccess.Client.OracleDbType]::Varchar2        )
    $mapping.Add( [DateTime], [Oracle.DataAccess.Client.OracleDbType]::TimeStamp     )
    $mapping.Add( [Guid], [Oracle.DataAccess.Client.OracleDbType]::Raw               )
    $mapping.Add( [short], [Oracle.DataAccess.Client.OracleDbType]::Int16            )
    $mapping.Add( [int], [Oracle.DataAccess.Client.OracleDbType]::Int32              )
    $mapping.Add( [long], [Oracle.DataAccess.Client.OracleDbType]::Int64             )
    $mapping.Add( [float], [Oracle.DataAccess.Client.OracleDbType]::Single           )
    $mapping.Add( [double], [Oracle.DataAccess.Client.OracleDbType]::Double          )
    $mapping.Add( [decimal], [Oracle.DataAccess.Client.OracleDbType]::Decimal        )
    $mapping.Add( [string], [Oracle.DataAccess.Client.OracleDbType]::Varchar2        )
    $mapping.Add( [Enum], [Oracle.DataAccess.Client.OracleDbType]::Int32             )
    $mapping.Add( [TimeSpan], [Oracle.DataAccess.Client.OracleDbType]::IntervalDS    )

    return $mapping
}




#////////////////
#TODO:
#Init-OracleModule



function New-OracleParam ($name, $type, $value, 
    $size = 0, $direction = [System.Data.ParameterDirection]::Input,
    [switch]$isCursor)
{
    if($isCursor)
    {
       $type =  ([Oracle.DataAccess.Client.OracleDbType]::RefCursor) 
       $direction = ([System.Data.ParameterDirection]::Output)
       $value = $null
    }
    New-Object Oracle.DataAccess.Client.OracleParameter($name, $type, $size) `
        -property @{Direction = $direction; Value = $value}
}


function New-OracleProcCommand ($connection, $procedure, $parameters)
{
    $cmd = New-Object Oracle.DataAccess.Client.OracleCommand($procedure, $connection)
    $cmd.CommandType = [System.Data.CommandType]::StoredProcedure
    $parameters | foreach {$cmd.Parameters.Add($_) | Out-Null}    
    $cmd
}

function Get-OracleProcReader ($procedure, $parameters)
{    
    $cmd = New-OracleProcCommand $procedure $parameters    
    if ($cmd.Connnection.State -ne [System.Data.ConnectionState]::Open)
    {
        $cmd.Connection.Open()
    }    
    ,$cmd.ExecuteReader()
}

function Invoke-OracleProc ($procedure, $parameters)
{    
    $cmd = New-OracleProcCommand $procedure $parameters    
    if ($cmd.Connnection.State -ne [System.Data.ConnectionState]::Open) {$cmd.Connection.Open()}
    $rValue = $cmd.ExecuteNonQuery() 
    $cmd.Connection.Close() 
    $cmd.Connection.Dispose() 
    $cmd.Dispose()
    return $rValue 
}






function Invoke-Oracle 
{
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)][Oracle.DataAccess.Client.OracleConnection]$conn, 
    [Parameter(Mandatory=$true)][string]$sql,        
    [Parameter(Mandatory=$false)][System.Collections.Hashtable]$paramValues,
    [Parameter(Mandatory=$false)][switch]$passThru
) 
    $cmd = New-Object Oracle.DataAccess.Client.OracleCommand($sql,$conn)
    $cmd.BindByName = $true
    
    if ($paramValues)
    {
        foreach ($p in $paramValues.GetEnumerator())
        {
            $oraParam = New-Object Oracle.DataAccess.Client.OracleParameter
            $oraParam.ParameterName = $p.Key
            $oraParam.Value = $p.Value
            $cmd.Parameters.Add($oraParam) | Out-Null
        }
    }   
    
    $result = $cmd.ExecuteNonQuery()      
    $cmd.Dispose()
    
    if ($passThru) { $result }
}



function Insert-OracleDataFeed 
{
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)][Oracle.DataAccess.Client.OracleConnection]$conn, 
    [Parameter(Mandatory=$true)][string]$sql,        
    [Parameter(Mandatory=$false)][System.Collections.Hashtable] $paramValues,
    [Parameter(Mandatory=$false)][string]$idColumn
) 
    $cmd = New-Object Oracle.DataAccess.Client.OracleCommand($sql,$conn)
    $cmd.BindByName = $true
    $idParam = $null
    
    if ($idColumn)
    {
        $cmd.CommandText = "{0} RETURNING {1} INTO :{2} " -f $cmd.CommandText, $idColumn, $idColumn
        $idParam = New-Object Oracle.DataAccess.Client.OracleParameter
        $idParam.Direction = [System.Data.ParameterDirection]::Output
        $idParam.DbType = [System.Data.DbType]::Int32
        $idParam.Value = [DBNull]::Value
        $idParam.SourceColumn = $idColumn
        $idParam.ParameterName = $idColumn
        $cmd.Parameters.Add($idParam) | Out-Null
    }
    
    if ($paramValues)
    {
        foreach ($p in $paramValues.GetEnumerator())
        {
            $oraParam = New-Object Oracle.DataAccess.Client.OracleParameter
            $oraParam.ParameterName = $p.Key
            $oraParam.Value = $p.Value
            $cmd.Parameters.Add($oraParam) | Out-Null
        }
    }   
    
    $result = $cmd.ExecuteNonQuery()
    
    if ($idParam)
    {
        if ($idParam.Value -ne [DBNull]::Value) { $idParam.Value } else { $null }
        $idParam.Dispose()
    }
    
    $cmd.Dispose()    
}



function Get-OracleDataReader 
{
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Oracle.DataAccess.Client.OracleConnection]$conn, 
    [Parameter(Mandatory=$true)]
    [string]$sql
)
    $cmd = New-Object Oracle.DataAccess.Client.OracleCommand($sql,$conn)
    if($conn.State -eq [System.Data.ConnectionState]::Closed)
    {
        [void] $conn.Open()
    }

    $reader = $cmd.ExecuteReader()    
    return ,$reader
}



function Get-OracleDataSourceProvider
{
  $ProviderName = 'Oracle.DataAccess.Client'
  $factory = [System.Data.Common.DbProviderFactories]::GetFactory($ProviderName)

  #DbDataSourceEnumerator 
  $dsenum = $factory.CreateDataSourceEnumerator()
      #DataTable 
  $dt = $dsenum.GetDataSources()
  return $dt
}


function ConvertFrom-OracleLob
{
#http://msdn.microsoft.com/en-us/library/system.data.oracleclient.oraclelob.read.aspx
[CmdletBinding()]
    param([VAlidateSet('blob','clob','nclob')] #http://msdn.microsoft.com/en-us/library/system.data.oracleclient.oraclelob.lobtype.aspx
    [string]$lobType='blob'
    ,
    [System.Data.OracleClient.OracleLob]$lobValue
    )
    #System.Text.Encoding.UTF8.GetString(theclob)


    if($lobValue.IsNull)
    {
        return 'NULL'
    }
    else {
    
      $value = [string]($lobValue.Value)
    
    }

}

function Get-OracleObjectsOwners
{
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [Oracle.DataAccess.Client.OracleConnection]$conn
)
[string]$sql = "select distinct owner from all_objects"
return Get-OracleDataTable -conn $conn -sql $sql
}

