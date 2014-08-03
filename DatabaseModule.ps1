function Load-DatabaseAssemblyes
{
    [void][Reflection.Assembly]::LoadWithPartialName('System.Configuration')
    [void][Reflection.Assembly]::LoadWithPartialName('System.Core')
    [void][Reflection.Assembly]::LoadWithPartialName('System.Data')
    [void][Reflection.Assembly]::LoadWithPartialName('System.Data.Entity')
    [void][Reflection.Assembly]::LoadWithPartialName('System.Security')
    [void][Reflection.Assembly]::LoadWithPartialName('System.Reflection')
    [void][Reflection.Assembly]::LoadWithPartialName('System.EnterpriseServices')
    [void][Reflection.Assembly]::LoadWithPartialName('System.Transactions')
    [void][Reflection.Assembly]::LoadWithPartialName('System.Xml')

}



function Get-ConfigConnectionString(
    [string] $filename = $(throw 'filename is required'),
    [string] $name = $(throw 'connection string name is required'))
{
    $config = [xml](gc $filename)
    $item = $config.configuration.connectionStrings.add | ? {$_.name -eq $name}
    if (!$item) 
    { throw "Failed to find a connection string with name '{0}'" -f $name}
    
    return $item.connectionString
}

function Get-Password
{
    $securePass = Read-Host 'Enter Password' -AsSecureString
    $bstr       = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass)
    $pass       = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [void][System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    return $securePass,$pass
}


