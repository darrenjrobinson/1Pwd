# 1Password CLI PowerShell Module

PowerShell Module for [1Password CLI](https://app-updates.agilebits.com/product_history/CLI)

[![PSGallery Version](https://img.shields.io/powershellgallery/v/1Pwd.svg?style=flat&logo=powershell&label=PSGallery%20Version)](https://www.powershellgallery.com/packages/1Pwd) [![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/1Pwd.svg?style=flat&logo=powershell&label=PSGallery%20Downloads)](https://www.powershellgallery.com/packages/1Pwd)

## Description
A PowerShell Module enabling simple methods for accessing your 1Password Vault. 

## Features
- Allows a configuration to be securely stored in your local Windows Profile that automatically loads with the module.
- Stores a profile configuration using Export-CliXML. The Export-Clixml cmdlet encrypts credential objects by using the Windows Data Protection API. The encryption ensures that only your user account on only that computer can decrypt the contents of the credential object. The exported CLIXML file can't be used on a different computer or by a different user.
- You can then use the [1Password CLI commands](https://support.1password.com/command-line-reference/) without having to worry about Signing In and managing the Session Tokens.
- You can use the module in Demo's and Presentations and not expose your API Keys or Credentials.
- Works in Jupyter Notebook
- Works with Windows PowerShell and PowerShell (6.x+)

## Installation
Install from the PowerShell Gallery on Windows PowerShell 5.1+ or PowerShell Core 6.x or PowerShell.

```
Install-Module -name 1Pwd
```

## Prerequsites 
To use this module you will need:
- A Paide [1Password account] (https://1password.com/sign-up/)
- [Your Secret Key or Setup Code](https://support.1password.com/secret-key/)
- Your Master Password that you use for accessing your 1Password Vault
- [1Password CLI](https://support.1password.com/command-line/). Install it in your system path or in the same directory as the scripts you'll be running that will use this 1Pwd PowerShell Module.

Test the 1Password CLI is accessible by running the following command that will return the 1Password CLI version. If you haven't setup credentials yet you will also receive a message to that effect. 
```
    Invoke-1PasswordExpression "--version"
```

## Cmdlets
The module contains 4 cmdlets. 
```
Get-Command -Module 1Pwd | Sort-Object Name | Get-Help | Format-Table Name, Synopsis -Autosize | clip

Name                          Synopsis
----                          --------
Invoke-1PasswordExpression    Invokes a 1Password CLI command.
Set-1PasswordConfiguration    Sets the default 1Password Vault and credentials.
Switch-1PasswordConfiguration Changes the 1Password configuration to a different Vault.
Test-1PasswordCredentials     Tests if the configured 1Password CLI configuration is valid.
```

## Configuration 
To create a secure profile for use with the 1Pwd Module execute the following PowerShell commands with the user account on the computer that you will be using to retrieve/set 1Password Vault items. This will create the secure configuration under your Windows Profile for the logged in user on computer it was executed on. It can only be opened and the Secret Key and Master Password read using the same account on the same computer. 

### Set Credentials and Profile Info
Update the following with your Sign-In Address and Sign In Account (Email Address) retrieved above. You will be prompted to securely input your Secret Key and Master Password. 

```
$1PSignInAddress = "https://my.1password.com"
$1PSignInAccount = "your@emailaddress.com"
$1PSecretKey = Read-Host "Enter your 1Password SecretKey" -AsSecureString
$1PMasterPassword = Read-Host "Enter your 1Password Master Password" -AsSecureString
```

### Get 1Password Account Details
Using the information input above the Test-1PasswordCredentials cmdlet is used to validate them and return your account details. 

```
$account = Test-1PasswordCredentials -SignInAddress $1PSignInAddress -SignInAccount $1PSignInAccount -SecretKey $1PSecretKey -MasterPassword $1PMasterPassword
```

### Save 1Pwd Configuration
Having successfully provided and validated your credentials the Set-1PasswordConfiguration cmdlet will securely store the configuration in the logged in users local Windows Profile. When saving a configuration you can use the -default switch to specify that it is the default configuration. It will automatically be retrieved and a session created when the module loads.

```
Set-1PasswordConfiguration -Vault $account.domain -SignInAddress $1PSignInAddress -SignInAccount $1PSignInAccount -SecretKey $1PSecretKey -MasterPassword $1PMasterPassword -Default
```

- ### Switch-1PasswordConfiguration
The Switch-1PasswordConfiguration cmdlet allows you to switch vaults/configuration. This is useful if you have multiple accounts. Each configuration needs to be saved  using Set-1PasswordConfiguration. When saving a configuration you can use the -default switch with Set-1PasswordConfiguration to specify which is the default configuration that will be loaded when the module loads. 

To change to the configuration for PersonalVault2 you would use the command.

```
Switch-1PasswordConfiguration -vault PersonalVault2
```

To switch to the PersonalVault2 configuration and make it the default use the -default switch. 

```
Switch-1PasswordConfiguration -vault PersonalVault2 -Default
```

# Using the 1Pwd Module
The primary command/cmdlet that you will use after configuration is Invoke-1PasswordExpression. 

## Invoke-1PasswordExpression

Invokes 1Password CLI command.
[Any command that the 1Password CLI supports](https://support.1password.com/command-line-reference/) can be provided. 

There is NO NEED to specify the op.exe executable or the --session --cache switches.

Example: List Vaults
```
Invoke-1PasswordExpression "list vaults"
```

Example: Get Item Twitter
```
Invoke-1PasswordExpression "get item Twitter"
```

Example: Get Item 'Twitter Other Account'
e.g An Item with spaces
```
Invoke-1PasswordExpression "get item 'Twitter - darrenjrobinson'"
```

Example: Get the Twitter Vault Item and return the password
```
((Invoke-1PasswordExpression "get item 'Twitter - darrenjrobinson'").details.fields | where-object {$_.designation -eq 'password'} | select-object -property value).value
```

## Also See
If you want to use the new [PowerShell Secret Management](https://github.com/powershell/secretmanagement#powershell-secretmanagement-module) with 1Password then [this Secret Management Extension](https://github.com/cdhunt/SecretManagement.1Password) from [Chris Hunt](https://twitter.com/logicaldiagram/)


## How can I contribute to the project?
* Found an issue and want us to fix it? [Log it](https://github.com/darrenjrobinson/1Pwd/issues)
* Want to fix an issue yourself or add functionality? Clone the project and submit a pull request.
* Any and all contributions are more than welcome and appreciated. 

## Keep up to date
* [Visit my blog](https://blog.darrenjrobinson.com)
* ![](http://twitter.com/favicon.ico) [Follow darrenjrobinson](https://twitter.com/darrenjrobinson)