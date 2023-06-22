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
Sets the default 1Password Vault and credentials

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
# MIIR2QYJKoZIhvcNAQcCoIIRyjCCEcYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU5uoH5CxU8KX3sy3w8dW0KG+f
# 5rCggg4lMIIGsDCCBJigAwIBAgIQCK1AsmDSnEyfXs2pvZOu2TANBgkqhkiG9w0B
# AQwFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVk
# IFJvb3QgRzQwHhcNMjEwNDI5MDAwMDAwWhcNMzYwNDI4MjM1OTU5WjBpMQswCQYD
# VQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lD
# ZXJ0IFRydXN0ZWQgRzQgQ29kZSBTaWduaW5nIFJTQTQwOTYgU0hBMzg0IDIwMjEg
# Q0ExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA1bQvQtAorXi3XdU5
# WRuxiEL1M4zrPYGXcMW7xIUmMJ+kjmjYXPXrNCQH4UtP03hD9BfXHtr50tVnGlJP
# DqFX/IiZwZHMgQM+TXAkZLON4gh9NH1MgFcSa0OamfLFOx/y78tHWhOmTLMBICXz
# ENOLsvsI8IrgnQnAZaf6mIBJNYc9URnokCF4RS6hnyzhGMIazMXuk0lwQjKP+8bq
# HPNlaJGiTUyCEUhSaN4QvRRXXegYE2XFf7JPhSxIpFaENdb5LpyqABXRN/4aBpTC
# fMjqGzLmysL0p6MDDnSlrzm2q2AS4+jWufcx4dyt5Big2MEjR0ezoQ9uo6ttmAaD
# G7dqZy3SvUQakhCBj7A7CdfHmzJawv9qYFSLScGT7eG0XOBv6yb5jNWy+TgQ5urO
# kfW+0/tvk2E0XLyTRSiDNipmKF+wc86LJiUGsoPUXPYVGUztYuBeM/Lo6OwKp7AD
# K5GyNnm+960IHnWmZcy740hQ83eRGv7bUKJGyGFYmPV8AhY8gyitOYbs1LcNU9D4
# R+Z1MI3sMJN2FKZbS110YU0/EpF23r9Yy3IQKUHw1cVtJnZoEUETWJrcJisB9IlN
# Wdt4z4FKPkBHX8mBUHOFECMhWWCKZFTBzCEa6DgZfGYczXg4RTCZT/9jT0y7qg0I
# U0F8WD1Hs/q27IwyCQLMbDwMVhECAwEAAaOCAVkwggFVMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwHQYDVR0OBBYEFGg34Ou2O/hfEYb7/mF7CIhl9E5CMB8GA1UdIwQYMBaA
# FOzX44LScV1kTN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAK
# BggrBgEFBQcDAzB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9v
# Y3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4
# oDagNIYyaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJv
# b3RHNC5jcmwwHAYDVR0gBBUwEzAHBgVngQwBAzAIBgZngQwBBAEwDQYJKoZIhvcN
# AQEMBQADggIBADojRD2NCHbuj7w6mdNW4AIapfhINPMstuZ0ZveUcrEAyq9sMCcT
# Ep6QRJ9L/Z6jfCbVN7w6XUhtldU/SfQnuxaBRVD9nL22heB2fjdxyyL3WqqQz/WT
# auPrINHVUHmImoqKwba9oUgYftzYgBoRGRjNYZmBVvbJ43bnxOQbX0P4PpT/djk9
# ntSZz0rdKOtfJqGVWEjVGv7XJz/9kNF2ht0csGBc8w2o7uCJob054ThO2m67Np37
# 5SFTWsPK6Wrxoj7bQ7gzyE84FJKZ9d3OVG3ZXQIUH0AzfAPilbLCIXVzUstG2MQ0
# HKKlS43Nb3Y3LIU/Gs4m6Ri+kAewQ3+ViCCCcPDMyu/9KTVcH4k4Vfc3iosJocsL
# 6TEa/y4ZXDlx4b6cpwoG1iZnt5LmTl/eeqxJzy6kdJKt2zyknIYf48FWGysj/4+1
# 6oh7cGvmoLr9Oj9FpsToFpFSi0HASIRLlk2rREDjjfAVKM7t8RhWByovEMQMCGQ8
# M4+uKIw8y4+ICw2/O/TOHnuO77Xry7fwdxPm5yg/rBKupS8ibEH5glwVZsxsDsrF
# hsP2JjMMB0ug0wcCampAMEhLNKhRILutG4UI4lkNbcoFUCvqShyepf2gpx8GdOfy
# 1lKQ/a+FSCH5Vzu0nAPthkX0tGFuv2jiJmCG6sivqf6UHedjGzqGVnhOMIIHbTCC
# BVWgAwIBAgIQCcjsXDR9ByBZzKg16Kdv+DANBgkqhkiG9w0BAQsFADBpMQswCQYD
# VQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lD
# ZXJ0IFRydXN0ZWQgRzQgQ29kZSBTaWduaW5nIFJTQTQwOTYgU0hBMzg0IDIwMjEg
# Q0ExMB4XDTIzMDMyOTAwMDAwMFoXDTI2MDYyMjIzNTk1OVowdTELMAkGA1UEBhMC
# QVUxGDAWBgNVBAgTD05ldyBTb3V0aCBXYWxlczEUMBIGA1UEBxMLQ2hlcnJ5YnJv
# b2sxGjAYBgNVBAoTEURhcnJlbiBKIFJvYmluc29uMRowGAYDVQQDExFEYXJyZW4g
# SiBSb2JpbnNvbjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMesp+e1
# UZ5doOnpL+epm6Iq6GYiqK8ZNcz1XBe7M7eBXwVy4tYP5ByIa6NORYEselVWI9Xm
# O1M+cPS6jRMrpZb9xtUH+NpKZO+eSthgTAtnEO1dWaAK6Y7AH/ZVjmgOTWZXBVib
# jAE/JQKIfZyx4Hm5FOH6hq3bslA+RUQpo3NQxNv2AuzckKQwbW7AoXINudj0duYC
# iDYshn/9mHzzgL0VpNYRpmgEa7WWgc1JH17V+SYlaf6qMWpYoWuODwuDltSH2p57
# qAI2/4J6rUYEvns7QZ9sgIUdGlUr596fp0Y4juypyVGE7Rr0a8PtByLWUupyV7Z5
# kKPr/MRjerXAmBnf6AdhI3kY6Gjz356fZkPA49UuCIXFgyTZT84Ao6Klw+0RqJ70
# JDt449Uky7hda+h8h2PiUdf7rXQamV57mY65+lHAmc4+UgTuWsnpwnTuNlkbZxRn
# Cw2D+W3qto2aBhDebciKZzivfiAWlWfTcHtCpy96gM5L+OB45ezDpU6KAH1hwRSj
# ORUlW5yoFTXUbPUBRflU3O2bZ0wdAJeyUYaHWAayNoyFfuKdrmCLtIx726O06dz9
# Kg+cJf+1ZdJ7KcUvZgR2d8F19FV5G1CVMnOzhMZR2dnIeJ5h0EgcOKNHl3hMKFdV
# Rx4lhW8tcrQQN4ZT2EgGfI9fBc0i3GXTFA0xAgMBAAGjggIDMIIB/zAfBgNVHSME
# GDAWgBRoN+Drtjv4XxGG+/5hewiIZfROQjAdBgNVHQ4EFgQUBTFWqXTuYnNp+d03
# es2KM9JdGUgwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMIG1
# BgNVHR8Ega0wgaowU6BRoE+GTWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydFRydXN0ZWRHNENvZGVTaWduaW5nUlNBNDA5NlNIQTM4NDIwMjFDQTEuY3Js
# MFOgUaBPhk1odHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVk
# RzRDb2RlU2lnbmluZ1JTQTQwOTZTSEEzODQyMDIxQ0ExLmNybDA+BgNVHSAENzA1
# MDMGBmeBDAEEATApMCcGCCsGAQUFBwIBFhtodHRwOi8vd3d3LmRpZ2ljZXJ0LmNv
# bS9DUFMwgZQGCCsGAQUFBwEBBIGHMIGEMCQGCCsGAQUFBzABhhhodHRwOi8vb2Nz
# cC5kaWdpY2VydC5jb20wXAYIKwYBBQUHMAKGUGh0dHA6Ly9jYWNlcnRzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNENvZGVTaWduaW5nUlNBNDA5NlNIQTM4
# NDIwMjFDQTEuY3J0MAkGA1UdEwQCMAAwDQYJKoZIhvcNAQELBQADggIBAFhACWjP
# MrcafwDfZ5me/nUrkv4yYgIi535cddPAm/2swGDTuzSVBVHIMBp8LWLmzXPA1Gbx
# BOmA4L8vvDgjEpQF9I9Ph5MNYgYhg0xSpAIp9/KAoc4OQnwlyRGPN+CjayY40xxT
# z4/hHohWg4rnJMIuVEjkMtKnMdTbpnqU85w78AQlfD79v/gWQ2dL1T3n18HOEjTt
# 8VSurxkEhQ5I3SH8Cr9YhUv94ObWIUbOKUt5SG7m/d+y2mfkKRSOmRluLSoYLPWb
# x35pArsYkaPpjf5Yl5jiJPY3GQzEU/SRVW0rrwDAbtKSN0gKWtZxijPDbs8aQUYC
# ijFfje6OWGF4RnmPSQh0Ff8AyzPQcx9LjQ/8W7gUELsE6IFuXP5bj2i6geLy65LR
# e46QZlYDq/bMazUoZQTlje/hs6pkOL4f1Kv7tbJZmMENVVURJNmeDRejvNliHaaG
# EAv/iF0Zo7pqvj4wCCCGG3j/sNR5WSRYnxf5xQ4r9i9gZqk4yjwk/DJCW2rmKNCU
# oxNIZWh2EIlMSDzw3DMKk2ylZdiY/LAi5GmbCyGLt6sTz/IE1w1NYwrp/z6v4I91
# lDgdXg+fTkhhxt47hWmjMOD3ZYVSFzQmg8al1iQ/+6RYKgfsww64tIky8JOOZX/3
# ss/uhxKUjPJxYJkOwQwUyoAYzjcu/AE7By0rMYIDHjCCAxoCAQEwfTBpMQswCQYD
# VQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lD
# ZXJ0IFRydXN0ZWQgRzQgQ29kZSBTaWduaW5nIFJTQTQwOTYgU0hBMzg0IDIwMjEg
# Q0ExAhAJyOxcNH0HIFnMqDXop2/4MAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEM
# MQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSD0xauYcbCEWjR
# 46IZ/jOKpOFu1DANBgkqhkiG9w0BAQEFAASCAgBAorJ4UD/sWd9QgvbVfKck5WCa
# h9bavuSoRjRFDIlThHFHi6q7BTKHBGif66sn47P887iOjyLOen4R9anCh6I/F4F6
# LttzW15kURL0jei8YcUVxABBASCfYJ++faXxEmzFJcBcOB/AT9svvBFXI/Yocvo2
# 1C/4znXF4J+VUDhmY+WfYLNzomjTbpYCgCa5FzGeEmNINwfD37fRESAHi6+yv6Uo
# 3yrEiePZOXkt1y+j0+9LSkiL+u0y9yDQEmkA1Gt5sB5v2+7yXLWP1DHLdY0tLJuO
# sq0QkxnHiFQkM9o645J0fTkglAZhxjZFaTOhBBPGtkJiwxM3+IOXTBSwOk9ffdYf
# JuKKqxaGxbcoJtxZP4ya6yttyFVXNZPtEbnmxzDlqdVlgdywuJNM+vJ7HLyDIIex
# XNT97OCl8nYV9K7ukI0wSXt3929gO1LCUEAi21vyHzqlPMd5fXjUPRRe7socWzeC
# v3nLn7N0Kbr6dINONkSdzpahWDJBQ38XSOtQ+TkrxegQnzJV4ItLkuVrJlpFZ/js
# H72uxZfrw99PN/8p3dAE4kCqOzLL257XX7tbuf9FeOSQa62Wvkw7Wp9N72WLP3vY
# ZWPTjSNRFvxFSOSNi2CpceFZyCakgzBYnRjTSC4+UWn/5tOUH8xZshkOYKoW4v32
# aUYuF9Ft1cIDE1LEiQ==
# SIG # End signature block
