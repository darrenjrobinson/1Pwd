$CommandsToExport = @()
$Global:1PasswordConfiguration = $null 
$Global:Vault = $null 
$Global:SignInAddress = $null
$Global:SignInAccount = $null
$Global:SecretKey = $null
$Global:MasterPassword = $null
$Global:DefaultVault = $null
$Global:CliLocation = $null
$Global:OpCli = $null

# $IsWindows doesn't exist in Windows PowerShell 5.1
$onWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows
$opName = if ($onWindows) { 'op.exe' } else { 'op' }

# Locate the 1Password CLI on load. First match wins:
# OP_CLI_PATH override, current directory (legacy), PATH, then well-known install locations.
$searchLocations = @()
if ($env:OP_CLI_PATH) { $searchLocations += $env:OP_CLI_PATH }
$searchLocations += Join-Path (Get-Location).Path $opName
$opOnPath = Get-Command $opName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($opOnPath) { $searchLocations += $opOnPath.Source }
if ($onWindows) {
    if ($env:ProgramFiles) { $searchLocations += Join-Path $env:ProgramFiles (Join-Path '1Password CLI' $opName) }
}
elseif ($IsMacOS) {
    $searchLocations += '/opt/homebrew/bin/op', '/usr/local/bin/op'
}
else {
    $searchLocations += '/usr/local/bin/op', '/usr/bin/op'
}

$Global:OpCli = $searchLocations | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1

if ($null -eq $Global:OpCli) {
    Write-Error -message "1Password CLI '$($opName)' not found. Searched: $($searchLocations -join ', '). Install the 1Password CLI (https://developer.1password.com/docs/cli/get-started/) or set `$env:OP_CLI_PATH to the full path of '$($opName)'."
    break
}

Try {
    $Global:CliLocation = Split-Path -Path $Global:OpCli -Parent
    $version = [version](((& $Global:OpCli --version) | Select-Object -First 1).Trim())

    if ($version.Major -ge 2) {
        $Global:CLIVersion = 2
    }
    else {
        $Global:CLIVersion = 1
    }
    Write-Verbose "CLI Version $($Global:CLIVersion) detected at '$($Global:OpCli)'. CLI Version $($version)"
}
catch {
    Write-Error -message "1Password CLI found at '$($Global:OpCli)' but its version could not be determined. $($_)"
    break
}

# %LOCALAPPDATA% on Windows, ~/.local/share on macOS/Linux
$1PasswordConfigurationFile = Join-Path ([Environment]::GetFolderPath('LocalApplicationData', 'Create')) 1PasswordConfiguration.clixml

function Save-1PasswordConfigurationFile {
    param ($Configuration)

    Export-Clixml -Path $1PasswordConfigurationFile -InputObject $Configuration
    if (-not $onWindows) {
        # SecureStrings are not encrypted by Export-Clixml outside Windows (no DPAPI). Restrict the file to the current user.
        chmod 600 $1PasswordConfigurationFile
        Write-Warning "On macOS/Linux the 1Password configuration file '$($1PasswordConfigurationFile)' is NOT encrypted. It is protected only by file permissions (600)."
    }
}
if (Test-Path $1PasswordConfigurationFile) {
    $1PasswordConfiguration = Import-Clixml $1PasswordConfigurationFile
    
    if ($1PasswordConfiguration.DefaultVault) {
        $Global:1PasswordConfiguration = $1PasswordConfiguration.($1PasswordConfiguration.DefaultVault)      
        $Global:Vault = $Global:1PasswordConfiguration.Vault 
        $Global:SignInAddress = $Global:1PasswordConfiguration.SignInAddress
        $Global:SignInAccount = $Global:1PasswordConfiguration.SignInAccount
        $Global:SecretKey = $Global:1PasswordConfiguration.SecretKey
        $Global:MasterPassword = $Global:1PasswordConfiguration.MasterPassword
    }
}

function Set-1PasswordConfiguration {
    <#
.SYNOPSIS
Sets the default 1Password Vault and credentials.

.DESCRIPTION
Sets the default 1Password Vault and credentials. Configuration values can
be securely saved to a user's profile using Set-1PasswordConfiguration.

.PARAMETER Default
Set the profile configuration being set as the Default. Default indicates that configuration is loaded when the module loads. 

.PARAMETER Vault
The Vault name used for the profile configuration. 

.PARAMETER SignInAddress
The 1Password User's Sign-In URI

.PARAMETER SignInAccount
The 1Password User's Sign-In email address

.PARAMETER SecretKey
The 1Password User's Secret Key

.PARAMETER MasterPassword
The 1Password User's Master Password

.EXAMPLE
$1PSignInAddress = "https://my.1password.com"
$1PSignInAccount = "you@yourDomain.com"
$1PSecretKey = Read-Host "Enter your 1Password SecretKey" -AsSecureString
$1PMasterPassword = Read-Host "Enter your 1Password Master Password" -AsSecureString
$account = Test-1PasswordCredentials -SignInAddress $1PSignInAddress -SignInAccount $1PSignInAccount -SecretKey $1PSecretKey -MasterPassword $1PMasterPassword

Set-1PasswordConfiguration -Vault $account.domain -SignInAddress $1PSignInAddress -SignInAccount $1PSignInAccount -SecretKey $1PSecretKey -MasterPassword $1PMasterPassword -Default

.LINK
http://darrenjrobinson.com/

#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)][switch]$default,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$Vault,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$SignInAddress,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$SignInAccount,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][SecureString]$SecretKey,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][SecureString]$MasterPassword)

    $newProfile = @{$Vault = @{
            Vault          = $Vault
            SignInAddress  = $SignInAddress
            SignInAccount  = $SignInAccount
            SecretKey      = $SecretKey
            MasterPassword = $MasterPassword
        } 
    }
    
    $Global:1PasswordConfiguration += $newProfile 
    if ($default) {
        $1PasswordConfiguration.DefaultVault = $Vault 
        Save-1PasswordConfigurationFile -Configuration $1PasswordConfiguration
    }
    else {
        Save-1PasswordConfigurationFile -Configuration $1PasswordConfiguration
    }
}
$CommandsToExport += 'Set-1PasswordConfiguration'

function Switch-1PasswordConfiguration {
    <#
.SYNOPSIS
Changes the 1Password configuration to a different Vault.

.DESCRIPTION
Changes the 1Password configuration used to a different Vault.
Optionally sets the default 1Password Vault. 
Configuration values can be securely saved to a user's profile using Set-1PasswordConfiguration.

.PARAMETER Vault
Vault to switch too. 

.PARAMETER default
(Optional) Set the Vault being switched to as the new Default Vault that will be loaded on Module Load. 

.EXAMPLE
Switch-1PasswordConfiguration -vault My

.EXAMPLE
Switch-1PasswordConfiguration -vault My -default 

.LINK
http://darrenjrobinson.com/

#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Vault,
        [Parameter(Mandatory = $false, Position = 0)]
        [switch]$default
    )

    if ($1PasswordConfiguration.$Vault) {
        $Global:1PasswordConfiguration = $1PasswordConfiguration.($1PasswordConfiguration.Vault)  
        Write-Information "Setting Globals"
        $Global:Vault = $Global:1PasswordConfiguration.Vault 
        $Global:SignInAddress = $Global:1PasswordConfiguration.SignInAddress
        $Global:SignInAccount = $Global:1PasswordConfiguration.SignInAccount
        $Global:SecretKey = $Global:1PasswordConfiguration.SecretKey
        $Global:MasterPassword = $Global:1PasswordConfiguration.MasterPassword

        if ($default) {
            $Global:1PasswordConfiguration.DefaultVault = $Vault
            Save-1PasswordConfigurationFile -Configuration $1PasswordConfiguration
        }
    }
    else {
        Write-Error "No Vault with name $($Vault) was found in the 1Password Configuration file."
        break
    }
}
$CommandsToExport += 'Switch-1PasswordConfiguration'

function Test-1PasswordCredentials {
    <#
.SYNOPSIS
    Tests if the configured 1Password CLI configuration is valid.

.DESCRIPTION
    Attempts to SignIn to 1Password using the configured credentials

.PARAMETER SignInAddress
The 1Password User's Sign-In URI

.PARAMETER SignInAccount
The 1Password User's Sign-In email address

.PARAMETER SecretKey
The 1Password User's Secret Key

.PARAMETER MasterPassword
The 1Password User's Master Password

.EXAMPLE
    Test-1PasswordCredentials

.LINK
    http://darrenjrobinson.com
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$SignInAddress,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$SignInAccount,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][SecureString]$SecretKey,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][SecureString]$MasterPassword
    )
    
    try {
        if ($psversiontable.PSEdition -eq 'Desktop') {
            $bMPwd = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($MasterPassword)
            $1PMasterPasswordDecrypted = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bMPwd)
            $bSKey = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecretKey)
            $1PSecretKeyDecrypted = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bSKey)
        }
        else {
            $1PMasterPasswordDecrypted = ConvertFrom-SecureString $MasterPassword -AsPlainText 
            $1PSecretKeyDecrypted = ConvertFrom-SecureString $SecretKey -AsPlainText     
        }

        switch ($CLIVersion) {
            "1" {
                $Global:sessionToken = write-output $1PMasterPasswordDecrypted | & $Global:OpCli signin $SignInAddress $SignInAccount $1PSecretKeyDecrypted -r 
                if ($sessionToken) {
                    return (& $Global:OpCli get account --cache --session $($sessionToken) | ConvertFrom-Json) 
                }
            }
            "2" {
                # Check if account prev added
                try {
                    $accountList = $null 
                    $accountList = (& $Global:OpCli account list)
                    if ($accountList.count -ge 1) {
                        # sign in 
                        $Global:sessionToken = write-output $1PMasterPasswordDecrypted | & $Global:OpCli signin --raw 
                        if ($sessionToken) {
                            return (& $Global:OpCli account get --session $Global:sessionToken)
                        }
                    }
                    else {
                        # add account and signin 
                        $Global:sessionToken = write-output $1PMasterPasswordDecrypted | & $Global:OpCli account add --address $SignInAddress --email $SignInAccount --secret-key $1PSecretKeyDecrypted --signin --raw 
                        if ($sessionToken) {
                            return (& $Global:OpCli account get)
                        }
                    }
                }
                catch {
                    return $_
                }
            }
        }
    }
    Catch {
        return $_
    }
}
$CommandsToExport += 'Test-1PasswordCredentials'

function Invoke-1PasswordExpression {
    <#
.SYNOPSIS
    Invokes a 1Password CLI command.

.DESCRIPTION
    Cmdlet to invoke 1Password CLI commands using session token and cache

.PARAMETER Expression
The 1Password command to be performed

.PARAMETER sessionToken
The 1Password current Session Token to be used to execute the CLI command

.EXAMPLE
    Invoke-1PasswordExpression "Get Item Twitter"

.EXAMPLE
    Invoke-1PasswordExpression "Item Get Twitter"

.LINK
    http://darrenjrobinson.com
#>

    [CmdletBinding()]
    [alias("1pwd")]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$Expression,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)][String]$sessionToken = $Global:sessionToken
    )
    
    try {
        if (!$sessionToken) {
            switch ($CLIVersion) {
                "1" {
                    $Global:sessionToken = write-output $1PMasterPasswordDecrypted | & $Global:OpCli signin $SignInAddress $SignInAccount $1PSecretKeyDecrypted -r 
                    return (& $Global:OpCli get account --cache --session $Global:sessionToken | ConvertFrom-Json)
                }

                "2" {
                    $Global:sessionToken = write-output $1PMasterPasswordDecrypted | & $Global:OpCli account add --address $Global:SignInAddress --email $Global:SignInAccount --secret-key $1PSecretKeyDecrypted --signin --raw 
                    if ($sessionToken) {
                        return & $Global:OpCli account get
                    }
                }
            }
        }
        else {
            if ($Global:1PasswordConfiguration.Vault) {
                # Check if the Session Token is still valid
                $pinfo = New-Object System.Diagnostics.ProcessStartInfo
                $pinfo.FileName = $Global:OpCli

                # nuances for CLI versions
                switch ($CLIVersion) {
                    "1" {
                        $pinfo.Arguments = "get vault $($Global:1PasswordConfiguration.Vault) --session $($sessionToken)"
                    }
                    "2" {
                        $pinfo.Arguments = "vault get $($Global:1PasswordConfiguration.Vault) --session $($sessionToken)"
                    }
                }
                
                $pinfo.UseShellExecute = $false
                $pinfo.CreateNoWindow = $true
                $pinfo.RedirectStandardOutput = $true
                $pinfo.RedirectStandardError = $true

                $process = New-Object System.Diagnostics.Process
                $process.StartInfo = $pinfo
                $process.Start() | Out-Null
                
                [int]$sleepcount = 0
                do {
                    Start-Sleep -Seconds 1
                    $sleepcount++
                    Write-Verbose "Waiting for response for Session Token expiration check."
                } until ($sleepcount -gt 5 -or $process.HasExited)
                
                if (!$process.HasExited) {
                    $process.Kill()
                    Write-Verbose "Killing process validating Session Token expiration check."
                } 

                $stdout, $stderr = $null 
                $stdout = $process.StandardOutput.ReadToEnd()
                $stderr = $process.StandardError.ReadToEnd()

                if ((($stdout.Contains("[ERROR]") -and $stdout.Contains("session expired")) -or ($stdout.Contains("[ERROR]") -and $stdout.Contains("You are not currently signed in")))) {
                    # Session expired or invalid
                    try {
                        # Use the Test-1PasswordCredentials cmdlet so we don't have to decode the secure strings
                        Test-1PasswordCredentials -SignInAddress $Global:1PasswordConfiguration.SignInAddress -SignInAccount $Global:1PasswordConfiguration.SignInAccount -SecretKey $Global:1PasswordConfiguration.SecretKey -MasterPassword $Global:1PasswordConfiguration.MasterPassword | out-null 
                    }
                    catch {
                        Write-Error "Session Token expired and a new one couldn't be obtained."
                        return $_
                        break 
                    }
                }
                else {
                    if ((($stderr.Contains("[ERROR]") -and $stderr.Contains("session expired")) -or ($stderr.Contains("[ERROR]") -and $stderr.Contains("You are not currently signed in")))) {
                        # Session expired or invalid
                        try {
                            # Use the Test-1PasswordCredentials cmdlet so we don't have to decode the secure strings
                            Test-1PasswordCredentials -SignInAddress $Global:1PasswordConfiguration.SignInAddress -SignInAccount $Global:1PasswordConfiguration.SignInAccount -SecretKey $Global:1PasswordConfiguration.SecretKey -MasterPassword $Global:1PasswordConfiguration.MasterPassword | out-null 
                        }
                        catch {
                            Write-Error "Session Token expired and a new one couldn't be obtained."
                            return $_
                            break 
                        }
                    }
                }
            }
        }

        # Not everything returns JSON, sometimes just a string. Go for gold and fall back if it fails
        # CLI version 2 we need to get as JSON and convert to a PSObject
        try {
            switch ($CLIVersion) {
                "1" {
                    Write-Debug "CLI 1: Invoking command for JSON response"
                    return (Invoke-Expression -command "& '$($Global:OpCli)' $($Expression) --cache --session `'$($Global:sessionToken)`'" ) | ConvertFrom-json
                }
                "2" {
                    Write-Debug "CLI 2: Invoking command for JSON response"
                    return (Invoke-Expression -command "& '$($Global:OpCli)' $($Expression) --cache --format=json --session `'$($Global:sessionToken)`'") | ConvertFrom-json
                }
            }
        }
        catch {
            try {
                Write-Debug "Fallback to non-json response local path"
                return (Invoke-Expression -command "& '$($Global:OpCli)' $($Expression) --cache --session `'$($Global:sessionToken)`'" ) 
            }
            catch {
                return (& $Global:OpCli $($Expression) --cache --session $($Global:sessionToken)) 
            }
        }
    }
    Catch {
        return $_
    }
}
    
$CommandsToExport += 'Invoke-1PasswordExpression'

if ($1PasswordConfiguration.DefaultVault) {
    Write-Debug "1password Module Configuration Loaded. Initiating Session. "
    # Use the Test-1PasswordCredentials cmdlet so we don't have to decode the secure strings and sign-in so we're ready to go
    Test-1PasswordCredentials -SignInAddress $Global:1PasswordConfiguration.SignInAddress -SignInAccount $Global:1PasswordConfiguration.SignInAccount -SecretKey $Global:1PasswordConfiguration.SecretKey -MasterPassword $Global:1PasswordConfiguration.MasterPassword | out-null 
}
else {
    Write-Debug "NO 1password Module Configuration Loaded. Test-1PasswordCredentials needs to be executed."
}
