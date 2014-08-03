$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\DatabaseModule.ps1" 
. "$here\OracleModule.ps1" 




function Invoke-OracleSqlPlus($userName, $password, $server, $sql) {  
    $script = "WHENEVER SQLERROR EXIT SQL.SQLCODE`n" + ((Get-Content $sql) -join "`n")
    $script | &sqlplus "$userName/$password@$server"
    if(!$?) { 
        throw "SqlPlus failed!"
    }
}


#region SqlLoader

function Invoke-OracleSqlLoader
{
    param(
    $userName, $password, $server,
    [string]$ctlFile
    )

    $logFile = $ctlFile + '.log'
    &sqlldr  "userid=$userName/$password@$server control=$ctlFile log=$logFile"

}

function Export-OracleControlFile
{
    #http://psoug.org/reference/sqlloader.html
    [CmdletBinding()]
    param([string[]]$csvFiles,
    [char]$delimiter = ',',
    [string]$outputPath = 'control.ctl',
    [switch]$PassThru,
    [string]$intoTableName= '',
    [string]$dateTimeFormat = 'YYYYMMDD',

    [string]$recordNumberField = 'recno',
    [string]$sysdateField = 'rundate',
    [hashtable]$constants = @{},

    [validateSet(
'APPEND',
'INSERT',
'REPLACE',
'TRUNCATE'
)]
    [string]$modes = 'APPEND'
    )

    $firstCsvFile = $csvFiles[0]
   
    $csvFeed =  Import-Csv -Delimiter $delimiter -Path $firstCsvFile
    $csvHeaders =  $csvFeed | select -first 1 | get-member -type properties | select name
    

    $infileBody =  $csvFiles | %{"INFILE `'$_`'  BADFILE `'$($_).bad`'  DISCARDFILE  `'$($_).discard`'"} | out-string
    $headerBody =  $csvHeaders | %{$_.name +','} | out-string
    Write-Verbose "Headers:  $headerBody"

         
    #region body
    #region additional Fields 
    $recordNumberBody = ''
    if($recordNumberField)
    {
        $recordNumberBody = $recordNumberField + " RECNUM, `r`n"
    }


    $sysdateBody = ''
    if($sysdateField)
    {
        $sysdateBody = $sysdateField + " SYSDATE, `r`n"
    }


    $constantsBody = ''
    if($constants)
    {
        $constants.Keys | %{
             $key = $_
             $value = $constants[$key]
             $constantsBody += "$key CONSTANT `"$value`", `r`n"

        }
    }


    #endregion 

    $fieldBody = $headerBody + $recordNumberBody  + $sysdateBody + $constantsBody
    $fieldBody = ($fieldBody.Trim()) -replace ".$"


    [string]$ctlBody ="
-- Control file created on $(get-date)
LOAD DATA
$infileBody
$modes
INTO TABLE $intoTableName
TRAILING NULLCOLS

FIELDS TERMINATED BY `'$delimiter`' 
DATE FORMAT $dateTimeFormat
( 
$fieldBody  
)
"

    #endregion 

    #region file operation
    Remove-Item -Force -Path  $outputPath | Out-Null
    $ctlBody | out-file -FilePath  $outputPath -Encoding ascii -Force -NoClobber 

    #endregion


    if($PassThru)
    {
        return $ctlBody
    }
}

#endregion