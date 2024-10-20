param(
    [Parameter(Mandatory=$True, Position=0, ValueFromPipeline=$false)]
    [System.String]
    $ConfigPath
)

Function ReadConfigFile ($file) {
  $ini = @{}
  $section = "NO_SECTION"
  $ini[$section] = @{}
  switch -regex -file $file {
    "^\[(.+)\]$" {
      $section = $matches[1].Trim()
      $ini[$section] = @{}
    }
    "^\s*([^#].+?)\s*=\s*(.*)" {
      $name,$value = $matches[1..2]
      if (!($name.StartsWith(";"))) {
        $ini[$section][$name] = $value.Trim()
      }
    }
  }
  $ini
}

$config = ReadConfigFile $PSScriptRoot"\"$ConfigPath
$FullConnectionName = $config.connection.name + "_" + $config.connection.type.ToUpper()
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$caPath = $scriptPath + "\" + $config.ca.file_name
$crtPath = $scriptPath + "\" + $config.crt.file_name


$connectionParams = @{
    Name = $FullConnectionName
    ServerAddress = $config.connection.address
    TunnelType = $config.connection.type
    EncryptionLevel = $config.connection.EncryptionLevel
    AuthenticationMethod = $config.connection.AuthenticationMethod
    RememberCredential = [System.Convert]::ToBoolean($config.connection.RememberCredential)
    SplitTunneling = [System.Convert]::ToBoolean($config.connection.SplitTunneling)
    PassThru = $true
    AllUserConnection=[System.Convert]::ToBoolean($config.connection.AllUserConnection)
    UseWinlogonCredential=[System.Convert]::ToBoolean($config.connection.UseWinlogonCredential)
}
<# Только для L2TP#>
if ($config.connection.type -eq "L2tp") {
  if ($config.connection.L2tpPsk) {
      $connectionParams += @{
          L2tpPsk = $config.connection.L2tpPsk
      }
  }
}
try {

    $caParams = @{
        FilePath = $caPath
        CertStoreLocation = "Cert:\LocalMachine\Root"
    }

    $crtParams = @{
        FilePath = $crtPath
        CertStoreLocation = "Cert:\LocalMachine\My"
        Password = ConvertTo-SecureString $config.crt.pwd -AsPlainText -Force
    }
    Import-Certificate @caParams
    Import-PfxCertificate @crtParams
}
catch {
    Write-Host("ВНИМАНИЕ!!! Сертификаты не установлены. Если сервер не требует установки сертификатов на рабочую станцию - просто проигнорируйте данное предупреждение")
}


try {
    Add-VpnConnection @connectionParams -force
    <# Добавление маршрутов #>
    if ($config.connection.DestinationPrefix) {
        $DestinationPrefixes = $config.connection.DestinationPrefix.Split(",")
        foreach ($DestinationPrefix in $DestinationPrefixes) {
            Add-VpnConnectionRoute -ConnectionName $FullConnectionName -DestinationPrefix $DestinationPrefix –PassThru
        }
    }
}
catch {
    Write-Host("ОШИБКА!!!")
    Write-Host($_.ScriptStackTrace)
    Write-Host($_.Exception)
}