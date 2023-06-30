$CommandsToExport = @()
$Global:1PasswordConfiguration = $null 
$Global:Vault = $null 
$Global:SignInAddress = $null
$Global:SignInAccount = $null
$Global:SecretKey = $null
$Global:MasterPassword = $null
$Global:DefaultVault = $null
$Global:CliLocation = $null 

# Ensure op.exe is in the directory on load. 
if ($null -eq $CliLocation) {
    Try {
        $version = $(.\op.exe --version)
        $Global:CliLocation = (get-location).Path 
        Set-Location -Path $Global:CliLocation

        if ($version -ge 2) {
            $Global:CLIVersion = 2
            Write-Verbose "CLI Version $($Global:CLIVersion) detected in the local directory '$($Global:CliLocation)'. CLI Verson $($version)"
        }
        elseif ($version -lt 2 ) {
            $Global:CLIVersion = 1
            Write-Verbose "CLI Version $($Global:CLIVersion) detected in the local directory '$($Global:CliLocation)'. CLI Verson $($version)"
        }
    }
    catch {
        Write-Error -message "1Password CLI not found in the current path. Download the 1Password CLI executable 'op.exe' and put it in the same directory as your script(s)."
        break 
    }
}

$1PasswordConfigurationFile = Join-Path "$($env:LOCALAPPDATA)" 1PasswordConfiguration.clixml
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
        Export-Clixml -Path $1PasswordConfigurationFile -InputObject $1PasswordConfiguration
    }
    else {
        Export-Clixml -Path $1PasswordConfigurationFile -InputObject $1PasswordConfiguration
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
            Export-Clixml -Path $1PasswordConfigurationFile -InputObject $1PasswordConfiguration
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
                $Global:sessionToken = write-output $1PMasterPasswordDecrypted | .\op.exe signin $SignInAddress $SignInAccount $1PSecretKeyDecrypted -r 
                if ($sessionToken) {
                    return (Invoke-Expression -command "'.\op.exe get account --cache --session $($sessionToken)'" ) 
                }
            }
            "2" {
                # Check if account prev added
                try {
                    $accountList = $null 
                    $accountList = (.\op.exe account list)
                    if ($accountList.count -gt 1) {
                        # sign in 
                        $Global:sessionToken = write-output $1PMasterPasswordDecrypted | .\op.exe signin --raw 
                        if ($sessionToken) {
                            return (.\op.exe account get --session $Global:sessionToken)
                        }
                    }
                    else {
                        # add account and signin 
                        $Global:sessionToken = write-output $1PMasterPasswordDecrypted | .\op.exe account add --address $SignInAddress --email $SignInAccount --secret-key $1PSecretKeyDecrypted --signin --raw 
                        if ($sessionToken) {
                            return (.\op.exe account get)
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
                    $Global:sessionToken = write-output $1PMasterPasswordDecrypted | .\op.exe signin $SignInAddress $SignInAccount $1PSecretKeyDecrypted -r 
                    return (Invoke-Expression -command "'.\op.exe get account --cache --session $($sessionToken)'" ) | ConvertFrom-json
                }

                "2" {
                    $Global:sessionToken = write-output $1PMasterPasswordDecrypted | op.exe account add --address $1PSignInAddress --email $1PSignInAccount --secret-key $1PSecretKeyDecrypted --signin --raw 
                    if ($sessionToken) {
                        return .\op.exe account get
                    }
                }
            }
        }
        else {
            if ($Global:1PasswordConfiguration.Vault) {
                # Check if the Session Token is still valid
                $pinfo = New-Object System.Diagnostics.ProcessStartInfo
                $localPath = $null 
                $localPath = ((get-location).path)
                $pinfo.FileName = "$($localPath)\op.exe"

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
                    return (Invoke-Expression -command ".\op $($Expression) --cache --session `'$($Global:sessionToken)`'" ) | ConvertFrom-json
                }
                "2" {
                    Write-Debug "CLI 2: Invoking command for JSON response"
                    return (Invoke-Expression -command ".\op $($Expression) --cache --format=json --session `'$($Global:sessionToken)`'") | ConvertFrom-json
                }
            }
        }
        catch {
            try {
                Write-Debug "Fallback to non-json response local path"
                return (Invoke-Expression -command ".\op $($Expression) --cache --session `'$($Global:sessionToken)`'" ) 
            }
            catch {
                return (op.exe $($Expression) --cache --session $($Global:sessionToken)) 
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
    

# SIG # Begin signature block
# MIIoKQYJKoZIhvcNAQcCoIIoGjCCKBYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBXRjgJLTcTPVqq
# Lf/T0XajAZUga+KI35QlPNTUn0jov6CCISwwggWNMIIEdaADAgECAhAOmxiO+dAt
# 5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEwMDAwMDBa
# Fw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lD
# ZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprNrnsbhA3E
# MB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKy
# unWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGbNOsF
# xl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclPXuU1
# 5zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJB
# MtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFPObUR
# WBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTvkpI6
# nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWMcCxB
# YKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5S
# UUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+x
# q4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGjggE6MIIB
# NjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/57qYrhwP
# TzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8BAf8EBAMC
# AYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENB
# LmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEBAHCgv0Nc
# Vec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0aFPQTSnov
# Lbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNEm0Mh65Zy
# oUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZqaVSwuKFW
# juyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCsWKAOQGPF
# mCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9FcrBjDTZ9z
# twGpn1eqXijiuZQwggauMIIElqADAgECAhAHNje3JFR82Ees/ShmKl5bMA0GCSqG
# SIb3DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRy
# dXN0ZWQgUm9vdCBHNDAeFw0yMjAzMjMwMDAwMDBaFw0zNzAzMjIyMzU5NTlaMGMx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMy
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcg
# Q0EwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDGhjUGSbPBPXJJUVXH
# JQPE8pE3qZdRodbSg9GeTKJtoLDMg/la9hGhRBVCX6SI82j6ffOciQt/nR+eDzMf
# UBMLJnOWbfhXqAJ9/UO0hNoR8XOxs+4rgISKIhjf69o9xBd/qxkrPkLcZ47qUT3w
# 1lbU5ygt69OxtXXnHwZljZQp09nsad/ZkIdGAHvbREGJ3HxqV3rwN3mfXazL6IRk
# tFLydkf3YYMZ3V+0VAshaG43IbtArF+y3kp9zvU5EmfvDqVjbOSmxR3NNg1c1eYb
# qMFkdECnwHLFuk4fsbVYTXn+149zk6wsOeKlSNbwsDETqVcplicu9Yemj052FVUm
# cJgmf6AaRyBD40NjgHt1biclkJg6OBGz9vae5jtb7IHeIhTZgirHkr+g3uM+onP6
# 5x9abJTyUpURK1h0QCirc0PO30qhHGs4xSnzyqqWc0Jon7ZGs506o9UD4L/wojzK
# QtwYSH8UNM/STKvvmz3+DrhkKvp1KCRB7UK/BZxmSVJQ9FHzNklNiyDSLFc1eSuo
# 80VgvCONWPfcYd6T/jnA+bIwpUzX6ZhKWD7TA4j+s4/TXkt2ElGTyYwMO1uKIqjB
# Jgj5FBASA31fI7tk42PgpuE+9sJ0sj8eCXbsq11GdeJgo1gJASgADoRU7s7pXche
# MBK9Rp6103a50g5rmQzSM7TNsQIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB
# /wIBADAdBgNVHQ4EFgQUuhbZbU2FL3MpdpovdYxqII+eyG8wHwYDVR0jBBgwFoAU
# 7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoG
# CCsGAQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29j
# c3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDig
# NqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9v
# dEc0LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZI
# hvcNAQELBQADggIBAH1ZjsCTtm+YqUQiAX5m1tghQuGwGC4QTRPPMFPOvxj7x1Bd
# 4ksp+3CKDaopafxpwc8dB+k+YMjYC+VcW9dth/qEICU0MWfNthKWb8RQTGIdDAiC
# qBa9qVbPFXONASIlzpVpP0d3+3J0FNf/q0+KLHqrhc1DX+1gtqpPkWaeLJ7giqzl
# /Yy8ZCaHbJK9nXzQcAp876i8dU+6WvepELJd6f8oVInw1YpxdmXazPByoyP6wCeC
# RK6ZJxurJB4mwbfeKuv2nrF5mYGjVoarCkXJ38SNoOeY+/umnXKvxMfBwWpx2cYT
# gAnEtp/Nh4cku0+jSbl3ZpHxcpzpSwJSpzd+k1OsOx0ISQ+UzTl63f8lY5knLD0/
# a6fxZsNBzU+2QJshIUDQtxMkzdwdeDrknq3lNHGS1yZr5Dhzq6YBT70/O3itTK37
# xJV77QpfMzmHQXh6OOmc4d0j/R0o08f56PGYX/sr2H7yRp11LB4nLCbbbxV7HhmL
# NriT1ObyF5lZynDwN7+YAN8gFk8n+2BnFqFmut1VwDophrCYoCvtlUG3OtUVmDG0
# YgkPCr2B2RP+v6TR81fZvAT6gt4y3wSJ8ADNXcL50CN/AAvkdgIm2fBldkKmKYcJ
# RyvmfxqkhQ/8mJb2VVQrH4D6wPIOK+XW+6kvRBVK5xMOHds3OBqhK/bt1nz8MIIG
# sDCCBJigAwIBAgIQCK1AsmDSnEyfXs2pvZOu2TANBgkqhkiG9w0BAQwFADBiMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQw
# HhcNMjEwNDI5MDAwMDAwWhcNMzYwNDI4MjM1OTU5WjBpMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0
# ZWQgRzQgQ29kZSBTaWduaW5nIFJTQTQwOTYgU0hBMzg0IDIwMjEgQ0ExMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA1bQvQtAorXi3XdU5WRuxiEL1M4zr
# PYGXcMW7xIUmMJ+kjmjYXPXrNCQH4UtP03hD9BfXHtr50tVnGlJPDqFX/IiZwZHM
# gQM+TXAkZLON4gh9NH1MgFcSa0OamfLFOx/y78tHWhOmTLMBICXzENOLsvsI8Irg
# nQnAZaf6mIBJNYc9URnokCF4RS6hnyzhGMIazMXuk0lwQjKP+8bqHPNlaJGiTUyC
# EUhSaN4QvRRXXegYE2XFf7JPhSxIpFaENdb5LpyqABXRN/4aBpTCfMjqGzLmysL0
# p6MDDnSlrzm2q2AS4+jWufcx4dyt5Big2MEjR0ezoQ9uo6ttmAaDG7dqZy3SvUQa
# khCBj7A7CdfHmzJawv9qYFSLScGT7eG0XOBv6yb5jNWy+TgQ5urOkfW+0/tvk2E0
# XLyTRSiDNipmKF+wc86LJiUGsoPUXPYVGUztYuBeM/Lo6OwKp7ADK5GyNnm+960I
# HnWmZcy740hQ83eRGv7bUKJGyGFYmPV8AhY8gyitOYbs1LcNU9D4R+Z1MI3sMJN2
# FKZbS110YU0/EpF23r9Yy3IQKUHw1cVtJnZoEUETWJrcJisB9IlNWdt4z4FKPkBH
# X8mBUHOFECMhWWCKZFTBzCEa6DgZfGYczXg4RTCZT/9jT0y7qg0IU0F8WD1Hs/q2
# 7IwyCQLMbDwMVhECAwEAAaOCAVkwggFVMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYD
# VR0OBBYEFGg34Ou2O/hfEYb7/mF7CIhl9E5CMB8GA1UdIwQYMBaAFOzX44LScV1k
# TN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcD
# AzB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2lj
# ZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0
# cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmww
# HAYDVR0gBBUwEzAHBgVngQwBAzAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIB
# ADojRD2NCHbuj7w6mdNW4AIapfhINPMstuZ0ZveUcrEAyq9sMCcTEp6QRJ9L/Z6j
# fCbVN7w6XUhtldU/SfQnuxaBRVD9nL22heB2fjdxyyL3WqqQz/WTauPrINHVUHmI
# moqKwba9oUgYftzYgBoRGRjNYZmBVvbJ43bnxOQbX0P4PpT/djk9ntSZz0rdKOtf
# JqGVWEjVGv7XJz/9kNF2ht0csGBc8w2o7uCJob054ThO2m67Np375SFTWsPK6Wrx
# oj7bQ7gzyE84FJKZ9d3OVG3ZXQIUH0AzfAPilbLCIXVzUstG2MQ0HKKlS43Nb3Y3
# LIU/Gs4m6Ri+kAewQ3+ViCCCcPDMyu/9KTVcH4k4Vfc3iosJocsL6TEa/y4ZXDlx
# 4b6cpwoG1iZnt5LmTl/eeqxJzy6kdJKt2zyknIYf48FWGysj/4+16oh7cGvmoLr9
# Oj9FpsToFpFSi0HASIRLlk2rREDjjfAVKM7t8RhWByovEMQMCGQ8M4+uKIw8y4+I
# Cw2/O/TOHnuO77Xry7fwdxPm5yg/rBKupS8ibEH5glwVZsxsDsrFhsP2JjMMB0ug
# 0wcCampAMEhLNKhRILutG4UI4lkNbcoFUCvqShyepf2gpx8GdOfy1lKQ/a+FSCH5
# Vzu0nAPthkX0tGFuv2jiJmCG6sivqf6UHedjGzqGVnhOMIIGwDCCBKigAwIBAgIQ
# DE1pckuU+jwqSj0pB4A9WjANBgkqhkiG9w0BAQsFADBjMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0
# ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBMB4XDTIyMDkyMTAw
# MDAwMFoXDTMzMTEyMTIzNTk1OVowRjELMAkGA1UEBhMCVVMxETAPBgNVBAoTCERp
# Z2lDZXJ0MSQwIgYDVQQDExtEaWdpQ2VydCBUaW1lc3RhbXAgMjAyMiAtIDIwggIi
# MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDP7KUmOsap8mu7jcENmtuh6BSF
# dDMaJqzQHFUeHjZtvJJVDGH0nQl3PRWWCC9rZKT9BoMW15GSOBwxApb7crGXOlWv
# M+xhiummKNuQY1y9iVPgOi2Mh0KuJqTku3h4uXoW4VbGwLpkU7sqFudQSLuIaQyI
# xvG+4C99O7HKU41Agx7ny3JJKB5MgB6FVueF7fJhvKo6B332q27lZt3iXPUv7Y3U
# TZWEaOOAy2p50dIQkUYp6z4m8rSMzUy5Zsi7qlA4DeWMlF0ZWr/1e0BubxaompyV
# R4aFeT4MXmaMGgokvpyq0py2909ueMQoP6McD1AGN7oI2TWmtR7aeFgdOej4TJEQ
# ln5N4d3CraV++C0bH+wrRhijGfY59/XBT3EuiQMRoku7mL/6T+R7Nu8GRORV/zbq
# 5Xwx5/PCUsTmFntafqUlc9vAapkhLWPlWfVNL5AfJ7fSqxTlOGaHUQhr+1NDOdBk
# +lbP4PQK5hRtZHi7mP2Uw3Mh8y/CLiDXgazT8QfU4b3ZXUtuMZQpi+ZBpGWUwFjl
# 5S4pkKa3YWT62SBsGFFguqaBDwklU/G/O+mrBw5qBzliGcnWhX8T2Y15z2LF7OF7
# ucxnEweawXjtxojIsG4yeccLWYONxu71LHx7jstkifGxxLjnU15fVdJ9GSlZA076
# XepFcxyEftfO4tQ6dwIDAQABo4IBizCCAYcwDgYDVR0PAQH/BAQDAgeAMAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwIAYDVR0gBBkwFzAIBgZn
# gQwBBAIwCwYJYIZIAYb9bAcBMB8GA1UdIwQYMBaAFLoW2W1NhS9zKXaaL3WMaiCP
# nshvMB0GA1UdDgQWBBRiit7QYfyPMRTtlwvNPSqUFN9SnDBaBgNVHR8EUzBRME+g
# TaBLhklodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRS
# U0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3JsMIGQBggrBgEFBQcBAQSBgzCB
# gDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMFgGCCsGAQUF
# BzAChkxodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVk
# RzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3J0MA0GCSqGSIb3DQEBCwUA
# A4ICAQBVqioa80bzeFc3MPx140/WhSPx/PmVOZsl5vdyipjDd9Rk/BX7NsJJUSx4
# iGNVCUY5APxp1MqbKfujP8DJAJsTHbCYidx48s18hc1Tna9i4mFmoxQqRYdKmEIr
# UPwbtZ4IMAn65C3XCYl5+QnmiM59G7hqopvBU2AJ6KO4ndetHxy47JhB8PYOgPvk
# /9+dEKfrALpfSo8aOlK06r8JSRU1NlmaD1TSsht/fl4JrXZUinRtytIFZyt26/+Y
# siaVOBmIRBTlClmia+ciPkQh0j8cwJvtfEiy2JIMkU88ZpSvXQJT657inuTTH4YB
# ZJwAwuladHUNPeF5iL8cAZfJGSOA1zZaX5YWsWMMxkZAO85dNdRZPkOaGK7DycvD
# +5sTX2q1x+DzBcNZ3ydiK95ByVO5/zQQZ/YmMph7/lxClIGUgp2sCovGSxVK05iQ
# RWAzgOAj3vgDpPZFR+XOuANCR+hBNnF3rf2i6Jd0Ti7aHh2MWsgemtXC8MYiqE+b
# vdgcmlHEL5r2X6cnl7qWLoVXwGDneFZ/au/ClZpLEQLIgpzJGgV8unG1TnqZbPTo
# ntRamMifv427GFxD9dAq6OJi7ngE273R+1sKqHB+8JeEeOMIA11HLGOoJTiXAdI/
# Otrl5fbmm9x+LMz/F0xNAKLY1gEOuIvu5uByVYksJxlh9ncBjDCCB20wggVVoAMC
# AQICEAnI7Fw0fQcgWcyoNeinb/gwDQYJKoZIhvcNAQELBQAwaTELMAkGA1UEBhMC
# VVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBU
# cnVzdGVkIEc0IENvZGUgU2lnbmluZyBSU0E0MDk2IFNIQTM4NCAyMDIxIENBMTAe
# Fw0yMzAzMjkwMDAwMDBaFw0yNjA2MjIyMzU5NTlaMHUxCzAJBgNVBAYTAkFVMRgw
# FgYDVQQIEw9OZXcgU291dGggV2FsZXMxFDASBgNVBAcTC0NoZXJyeWJyb29rMRow
# GAYDVQQKExFEYXJyZW4gSiBSb2JpbnNvbjEaMBgGA1UEAxMRRGFycmVuIEogUm9i
# aW5zb24wggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDHrKfntVGeXaDp
# 6S/nqZuiKuhmIqivGTXM9VwXuzO3gV8FcuLWD+QciGujTkWBLHpVViPV5jtTPnD0
# uo0TK6WW/cbVB/jaSmTvnkrYYEwLZxDtXVmgCumOwB/2VY5oDk1mVwVYm4wBPyUC
# iH2cseB5uRTh+oat27JQPkVEKaNzUMTb9gLs3JCkMG1uwKFyDbnY9HbmAog2LIZ/
# /Zh884C9FaTWEaZoBGu1loHNSR9e1fkmJWn+qjFqWKFrjg8Lg5bUh9qee6gCNv+C
# eq1GBL57O0GfbICFHRpVK+fen6dGOI7sqclRhO0a9GvD7Qci1lLqcle2eZCj6/zE
# Y3q1wJgZ3+gHYSN5GOho89+en2ZDwOPVLgiFxYMk2U/OAKOipcPtEaie9CQ7eOPV
# JMu4XWvofIdj4lHX+610Gplee5mOufpRwJnOPlIE7lrJ6cJ07jZZG2cUZwsNg/lt
# 6raNmgYQ3m3Iimc4r34gFpVn03B7QqcveoDOS/jgeOXsw6VOigB9YcEUozkVJVuc
# qBU11Gz1AUX5VNztm2dMHQCXslGGh1gGsjaMhX7ina5gi7SMe9ujtOnc/SoPnCX/
# tWXSeynFL2YEdnfBdfRVeRtQlTJzs4TGUdnZyHieYdBIHDijR5d4TChXVUceJYVv
# LXK0EDeGU9hIBnyPXwXNItxl0xQNMQIDAQABo4ICAzCCAf8wHwYDVR0jBBgwFoAU
# aDfg67Y7+F8Rhvv+YXsIiGX0TkIwHQYDVR0OBBYEFAUxVql07mJzafndN3rNijPS
# XRlIMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzCBtQYDVR0f
# BIGtMIGqMFOgUaBPhk1odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRU
# cnVzdGVkRzRDb2RlU2lnbmluZ1JTQTQwOTZTSEEzODQyMDIxQ0ExLmNybDBToFGg
# T4ZNaHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0Q29k
# ZVNpZ25pbmdSU0E0MDk2U0hBMzg0MjAyMUNBMS5jcmwwPgYDVR0gBDcwNTAzBgZn
# gQwBBAEwKTAnBggrBgEFBQcCARYbaHR0cDovL3d3dy5kaWdpY2VydC5jb20vQ1BT
# MIGUBggrBgEFBQcBAQSBhzCBhDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGln
# aWNlcnQuY29tMFwGCCsGAQUFBzAChlBodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRUcnVzdGVkRzRDb2RlU2lnbmluZ1JTQTQwOTZTSEEzODQyMDIx
# Q0ExLmNydDAJBgNVHRMEAjAAMA0GCSqGSIb3DQEBCwUAA4ICAQBYQAlozzK3Gn8A
# 32eZnv51K5L+MmICIud+XHXTwJv9rMBg07s0lQVRyDAafC1i5s1zwNRm8QTpgOC/
# L7w4IxKUBfSPT4eTDWIGIYNMUqQCKffygKHODkJ8JckRjzfgo2smONMcU8+P4R6I
# VoOK5yTCLlRI5DLSpzHU26Z6lPOcO/AEJXw+/b/4FkNnS9U959fBzhI07fFUrq8Z
# BIUOSN0h/Aq/WIVL/eDm1iFGzilLeUhu5v3fstpn5CkUjpkZbi0qGCz1m8d+aQK7
# GJGj6Y3+WJeY4iT2NxkMxFP0kVVtK68AwG7SkjdIClrWcYozw27PGkFGAooxX43u
# jlhheEZ5j0kIdBX/AMsz0HMfS40P/Fu4FBC7BOiBblz+W49ouoHi8uuS0XuOkGZW
# A6v2zGs1KGUE5Y3v4bOqZDi+H9Sr+7WyWZjBDVVVESTZng0Xo7zZYh2mhhAL/4hd
# GaO6ar4+MAgghht4/7DUeVkkWJ8X+cUOK/YvYGapOMo8JPwyQltq5ijQlKMTSGVo
# dhCJTEg88NwzCpNspWXYmPywIuRpmwshi7erE8/yBNcNTWMK6f8+r+CPdZQ4HV4P
# n05IYcbeO4VpozDg92WFUhc0JoPGpdYkP/ukWCoH7MMOuLSJMvCTjmV/97LP7ocS
# lIzycWCZDsEMFMqAGM43LvwBOwctKzGCBlMwggZPAgEBMH0waTELMAkGA1UEBhMC
# VVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBU
# cnVzdGVkIEc0IENvZGUgU2lnbmluZyBSU0E0MDk2IFNIQTM4NCAyMDIxIENBMQIQ
# CcjsXDR9ByBZzKg16Kdv+DANBglghkgBZQMEAgEFAKCBhDAYBgorBgEEAYI3AgEM
# MQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDLlyJjMGVGMA/e
# EusTLH/waXYOBZAynIFlsHJ9QSEJ0zANBgkqhkiG9w0BAQEFAASCAgC0HdM3LfDi
# Y0CZiEILzqgCd7rE42w2Bo0VuWKxE0TPVEUIeJFLh6KJBTHkxYAYz/TttnIwhERr
# htU2qQk+4gHrHs43S8d2AaOt8bIMCL3Icxuro0Is+EL/BGctq4uU+8MmfxTYDwKZ
# GptVyWeuPYofBStJhgonrRer5FGBXTC38nSO5SkwmryoU8l/Pie1tDEjlGf0M1hg
# WE8Wg5i3uht7lGShUbARJQguoJQSCv2QSBICYujpF3r8JYARqSLjUEOFWu+/sq8D
# +PfWff6feH/eNhBDjPDrCgEBqec8iGD/9KtHWkytpNxfYG3XzPRC8/sT7a12K36J
# ZqiIeBGW5g9o7U9BAFemXb/0RxUW1MGg6MVnDaF6pINEPMig3Xaf0L0O7Uw0mdmg
# 2+Itpdseju6GYwfgHFPE/ZU1EAOW2xzpCihhyeE4szsEN2qP/63gtfggZVmebYcU
# ILIF0ngnRjmh04kD86reUUXHJTO7QDPXMFvkm41eHtV8DX1reEwoCQvssqduX0Ga
# ijh7MSZLjCiyeeF4/y1C2B2MuYFBtzd6lAzHlpH1jbtNh8b8vtAwgdZ7n/V6YxR8
# ql6+XxssmGrHsXyOpqsWkVAjQLCT9YnN88TyeCdtuvV007mXSos84oZO5dTnl8t8
# EzUgNDdlUwBHbHbSiFewa7gRq+bkRbfXkqGCAyAwggMcBgkqhkiG9w0BCQYxggMN
# MIIDCQIBATB3MGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5j
# LjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBU
# aW1lU3RhbXBpbmcgQ0ECEAxNaXJLlPo8Kko9KQeAPVowDQYJYIZIAWUDBAIBBQCg
# aTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yMzA2
# MjkyMTA0MTlaMC8GCSqGSIb3DQEJBDEiBCAThHaOyyHk22+3WyR6CQFLLnD/eHxi
# 8KZWZrXBJZY5xzANBgkqhkiG9w0BAQEFAASCAgAeoAo/clPU0HncWr3FobEexzxv
# 9egi1FSsvrPqd/Pp5VqklfeRQMYm8gnsPBBipW7QsWlyfLPPZlXR1ueeI/7acNSz
# iOVCMu+9YWSY8NeDmu/8z2P99ZEDMbISbAwGa1OsmbhxlTEuFW5zXDyMIjNx50p1
# gd8I7ks1362FgYMqwjvIgUNVdLCt0qpR73A95qoo0piwFWDuI8S/h0bEWISmGyk6
# iahAfRzYI8y4DTwEqjZlZZU5CNueDc435psMY89zCN72Sm6OVUDF8vSYo8BQfGN1
# isykdgGMkttjrXfa3lOTZ5/vLEsXsHSP933kSEeal4Dum5kzFJJTzcTROsPtKHoL
# M8e4RsQofhCtIGsbkaUAVz6MjWX9Od/Y5luaplgRzkRTg4T1JG8jqjf933KsCNsN
# LAN5Jncj7jmEfeFl8IpEAEWVta6p1k2ObQfhK2+pTxtsHjr+4jWK6ibF/ij4IWpF
# Ce6N/mkFzTrRh2tMoDJBa+PdOpWM/bFjtltAgaYPl1Fn4wq+uo5Ix4hc240IREzd
# OZk+ktvF6qpd0u7lHjFTe1BerhZ7NPESHicqmxnkOS47ENzCktm3GLy9Cl+7pP3a
# OHfGJqBAKI5fvQr+sh34+CGMy7PNPQDVo2j2J4J7PZ4PWYoqalh7FjMGsGCPtzU1
# YyCF47OvVi5MQZGuYA==
# SIG # End signature block
