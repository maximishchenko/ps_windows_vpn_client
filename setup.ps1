Function Parse-IniFile ($file) {
  $ini = @{}
  # Create a default section if none exist in the file. Like a java prop file.
  $section = "NO_SECTION"
  $ini[$section] = @{}
  switch -regex -file $file {
    "^\[(.+)\]$" {
      $section = $matches[1].Trim()
      $ini[$section] = @{}
    }
    "^\s*([^#].+?)\s*=\s*(.*)" {
      $name,$value = $matches[1..2]
      # skip comments that start with semicolon:
      if (!($name.StartsWith(";"))) {
        $ini[$section][$name] = $value.Trim()
      }
    }
  }
  $ini
}

$config = Parse-IniFile $PSScriptRoot"\config\config.ini"

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$caPath = $scriptPath + "\" + $config.ca.file_name
$crtPath = $scriptPath + "\" + $config.crt.file_name




$connectionParams = @{
    Name = $config.connection.name + "_" + $config.connection.type.ToUpper()
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
    Add-VpnConnection @connectionParams
}
catch {
    Write-Host("ОШИБКА!!!")
    Write-Host($_.ScriptStackTrace)
    Write-Host($_.Exception)
}