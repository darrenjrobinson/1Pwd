@{
    RootModule           = '1Pwd.psm1'
    ModuleVersion        = '2.1.0'
    GUID                 = '37ae3083-de56-4688-8504-6df789c6e388'
    Author               = 'Darren J Robinson'
    CompanyName          = 'Community'
    Copyright            = '(c) 2023 Darren J Robinson. All rights reserved.'
    Description          = 'Cross-platform (Windows, macOS, Linux) PowerShell Module for 1Password CLI v1.x and v2.x'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = 'Core', 'Desktop'
    RequiredModules      = ''
    FunctionsToExport    = @('Set-1PasswordConfiguration',
        'Switch-1PasswordConfiguration',
        'Test-1PasswordCredentials',
        'Invoke-1PasswordExpression')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @('1pwd')
    PrivateData          = @{
        PSData = @{
            Tags         = @('1Password', 'Windows', 'MacOS', 'Linux', 'PSEdition_Core', 'PSEdition_Desktop')
            ProjectUri   = 'https://github.com/darrenjrobinson/1Pwd'
            ReleaseNotes = '2.1.0: Locates the 1Password CLI via OP_CLI_PATH, the current directory, PATH or the default install location. Adds macOS and Linux support. Module is no longer code signed.'
        }
    }
}
