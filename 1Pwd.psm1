$CommandsToExport = @()
$Global:1PasswordConfiguration = $null 
$Global:Vault = $null 
$Global:SignInAddress = $null
$Global:SignInAccount = $null
$Global:SecretKey = $null
$Global:MasterPassword = $null
$Global:DefaultVault = $null

$1PasswordConfigurationFile = Join-Path $env:LOCALAPPDATA 1PasswordConfiguration.clixml
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

.PARAMETER CliLocation
Full file path of the CLI binary

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
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][SecureString]$MasterPassword,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)][String]$CliLocation = $Global:CLiLocation
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

        if (!$CliLocation) {
            try {
                $Global:CLiLocation = (get-location).Path 
                Set-Location -Path $Global:CLiLocation
            }
            catch {
                Write-Error $_
            }
        }

        $Global:sessionToken = echo $1PMasterPasswordDecrypted | .\\op.exe signin $SignInAddress $SignInAccount $1PSecretKeyDecrypted -r 
        if ($sessionToken) {
            return (Invoke-Expression -command "$($Global:CLiLocation)\\op.exe get account --cache --session $($sessionToken)" ) | ConvertFrom-json
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

.PARAMETER CliLocation
Full path to the location of the 1Password CLI binary

.PARAMETER sessionToken
The 1Password current Session Token to be used to execute the CLI command

.EXAMPLE
    Invoke-1PasswordExpression "Get Item Twitter"

.LINK
    http://darrenjrobinson.com
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$Expression,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)][String]$CliLocation = $Global:CLiLocation,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)][String]$sessionToken = $Global:sessionToken
    )
    
    try {
        if (!$CliLocation) {
            try {
                $testLocation = (get-location).Path 
                Invoke-Expression -command "$($testLocation)\op --version"
                $CliLocation = $testLocation
            }
            catch {
                Write-Error "1Password CLI not found in the current path and not specified using -CliLocation. Provide CLI location."
                return $_
                break 
            }
        }

        if (!$sessionToken) {
            Write-Information "No session token found. Attempting refresh"
            try {
                $Global:sessionToken = echo $1PMasterPasswordDecrypted | .\\op.exe signin $SignInAddress $SignInAccount $1PSecretKeyDecrypted -r 
            }
            Catch {
                Write-Error "No session token found, and a new one couldn't be obtained."
                return $_
                break 
            }
        }
        else {
            if ($Global:1PasswordConfiguration.Vault) {
                # Check if the Session Token is still valid
                $pinfo = New-Object System.Diagnostics.ProcessStartInfo
                $pinfo.FileName = "$($CliLocation)\op.exe"
                $pinfo.Arguments = "get vault $($Global:1PasswordConfiguration.Vault) --session $($sessionToken)"
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
        try {
            return (Invoke-Expression -command "$($CliLocation)\op $($Expression) --cache --session $($Global:sessionToken)" ) | ConvertFrom-json
        }
        catch {
            return (Invoke-Expression -command "$($CliLocation)\op $($Expression) --cache --session $($Global:sessionToken)" ) 
        }
        
    }
    Catch {
        return $_
    }

}
$CommandsToExport += 'Invoke-1PasswordExpression'

# SIG # Begin signature block
# MIINSwYJKoZIhvcNAQcCoIINPDCCDTgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUq8/5wVarAO8YgwCp5j0PMo8y
# NIKgggqNMIIFMDCCBBigAwIBAgIQBAkYG1/Vu2Z1U0O1b5VQCDANBgkqhkiG9w0B
# AQsFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVk
# IElEIFJvb3QgQ0EwHhcNMTMxMDIyMTIwMDAwWhcNMjgxMDIyMTIwMDAwWjByMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQg
# Q29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
# +NOzHH8OEa9ndwfTCzFJGc/Q+0WZsTrbRPV/5aid2zLXcep2nQUut4/6kkPApfmJ
# 1DcZ17aq8JyGpdglrA55KDp+6dFn08b7KSfH03sjlOSRI5aQd4L5oYQjZhJUM1B0
# sSgmuyRpwsJS8hRniolF1C2ho+mILCCVrhxKhwjfDPXiTWAYvqrEsq5wMWYzcT6s
# cKKrzn/pfMuSoeU7MRzP6vIK5Fe7SrXpdOYr/mzLfnQ5Ng2Q7+S1TqSp6moKq4Tz
# rGdOtcT3jNEgJSPrCGQ+UpbB8g8S9MWOD8Gi6CxR93O8vYWxYoNzQYIH5DiLanMg
# 0A9kczyen6Yzqf0Z3yWT0QIDAQABo4IBzTCCAckwEgYDVR0TAQH/BAgwBgEB/wIB
# ADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMweQYIKwYBBQUH
# AQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYI
# KwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFz
# c3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmw0
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaG
# NGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RD
# QS5jcmwwTwYDVR0gBEgwRjA4BgpghkgBhv1sAAIEMCowKAYIKwYBBQUHAgEWHGh0
# dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCgYIYIZIAYb9bAMwHQYDVR0OBBYE
# FFrEuXsqCqOl6nEDwGD5LfZldQ5YMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6en
# IZ3zbcgPMA0GCSqGSIb3DQEBCwUAA4IBAQA+7A1aJLPzItEVyCx8JSl2qB1dHC06
# GsTvMGHXfgtg/cM9D8Svi/3vKt8gVTew4fbRknUPUbRupY5a4l4kgU4QpO4/cY5j
# DhNLrddfRHnzNhQGivecRk5c/5CxGwcOkRX7uq+1UcKNJK4kxscnKqEpKBo6cSgC
# PC6Ro8AlEeKcFEehemhor5unXCBc2XGxDI+7qPjFEmifz0DLQESlE/DmZAwlCEIy
# sjaKJAL+L3J+HNdJRZboWR3p+nRka7LrZkPas7CM1ekN3fYBIM6ZMWM9CBoYs4Gb
# T8aTEAb8B4H6i9r5gkn3Ym6hU/oSlBiFLpKR6mhsRDKyZqHnGKSaZFHvMIIFVTCC
# BD2gAwIBAgIQDOzRdXezgbkTF+1Qo8ZgrzANBgkqhkiG9w0BAQsFADByMQswCQYD
# VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGln
# aWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29k
# ZSBTaWduaW5nIENBMB4XDTIwMDYxNDAwMDAwMFoXDTIzMDYxOTEyMDAwMFowgZEx
# CzAJBgNVBAYTAkFVMRgwFgYDVQQIEw9OZXcgU291dGggV2FsZXMxFDASBgNVBAcT
# C0NoZXJyeWJyb29rMRowGAYDVQQKExFEYXJyZW4gSiBSb2JpbnNvbjEaMBgGA1UE
# CxMRRGFycmVuIEogUm9iaW5zb24xGjAYBgNVBAMTEURhcnJlbiBKIFJvYmluc29u
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwj7PLmjkknFA0MIbRPwc
# T1JwU/xUZ6UFMy6AUyltGEigMVGxFEXoVybjQXwI9hhpzDh2gdxL3W8V5dTXyzqN
# 8LUXa6NODjIzh+egJf/fkXOgzWOPD5fToL7mm4JWofuaAwv2DmI2UtgvQGwRhkUx
# Y3hh0+MNDSyz28cqExf8H6mTTcuafgu/Nt4A0ddjr1hYBHU4g51ZJ96YcRsvMZSu
# 8qycBUNEp8/EZJxBUmqCp7mKi72jojkhu+6ujOPi2xgG8IWE6GqlmuMVhRSUvF7F
# 9PreiwPtGim92RG9Rsn8kg1tkxX/1dUYbjOIgXOmE1FAo/QU6nKVioJMNpNsVEBz
# /QIDAQABo4IBxTCCAcEwHwYDVR0jBBgwFoAUWsS5eyoKo6XqcQPAYPkt9mV1Dlgw
# HQYDVR0OBBYEFOh6QLkkiXXHi1nqeGozeiSEHADoMA4GA1UdDwEB/wQEAwIHgDAT
# BgNVHSUEDDAKBggrBgEFBQcDAzB3BgNVHR8EcDBuMDWgM6Axhi9odHRwOi8vY3Js
# My5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNybDA1oDOgMYYvaHR0
# cDovL2NybDQuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1jcy1nMS5jcmwwTAYD
# VR0gBEUwQzA3BglghkgBhv1sAwEwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cu
# ZGlnaWNlcnQuY29tL0NQUzAIBgZngQwBBAEwgYQGCCsGAQUFBwEBBHgwdjAkBggr
# BgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tME4GCCsGAQUFBzAChkJo
# dHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRTSEEyQXNzdXJlZElE
# Q29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOC
# AQEANWoHDjN7Hg9QrOaZx0V8MK4c4nkYBeFDCYAyP/SqwYeAtKPA7F72mvmJV6E3
# YZnilv8b+YvZpFTZrw98GtwCnuQjcIj3OZMfepQuwV1n3S6GO3o30xpKGu6h0d4L
# rJkIbmVvi3RZr7U8ruHqnI4TgbYaCWKdwfLb/CUffaUsRX7BOguFRnYShwJmZAzI
# mgBx2r2vWcZePlKH/k7kupUAWSY8PF8O+lvdwzVPSVDW+PoTqfI4q9au/0U77UN0
# Fq/ohMyQ/CUX731xeC6Rb5TjlmDhdthFP3Iho1FX0GIu55Py5x84qW+Ou+OytQcA
# FZx22DA8dAUbS3P7OIPamcU68TGCAigwggIkAgEBMIGGMHIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25p
# bmcgQ0ECEAzs0XV3s4G5ExftUKPGYK8wCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcC
# AQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYB
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFIjYpJy5pp5t
# 1OZ64pXTDctlIAoNMA0GCSqGSIb3DQEBAQUABIIBAGkEOx+rV4YU9jEV1iQniB7M
# n+kkGNv/Mr51XJAHLj7k/mLwZz0adPMb2hweEGgvdHN0CAmVgig85y8CrzALcBiZ
# JYnxXDQ3NO7FdQiE6zTY5mqS7P54rBYUint1v8uqZgb8hsNyL+6LoPNd48sl6I1+
# f/hka71Yt5gnxp0lCV3Opf1xXfucuqy+dcrhJncluvwMjtv8sQCQc+992HScJkQ7
# V67oe2XoJacoSWpwcuG5Shf8Zg8foMW3JZ+4eFFWfDVdji3LS/a/5H7F6jqVq7Oq
# f9ZwxCLsFpB+oFzgO+a9S7k0WKMWkYZzO3amHLr4xelrX4DUH3JwzvfdgwN4kJY=
# SIG # End signature block
