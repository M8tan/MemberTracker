param(
    [string]$User,
    [string]$Group,
    [string]$ExportDir,
    [switch]$Txt,
    [switch]$Json
)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
function Display-Error{
param(
[string]$ErrorMessage,
[string]$ErrorType
)
([System.Windows.Forms.MessageBox]::Show("Encountered an error -`r`n$($ErrorMessage)", "Oops!", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)) | Out-Null
}

function Test-Startup(){
    try{
        Import-Module activedirectory -ErrorAction Stop
    } catch {
        throw "Can't load AD module: $($_.exception.message)"
    }
    try{
        return (Get-ADForest -ErrorAction Stop).Domains 
    } catch {
        throw "Can't get domains: $($_.exception.message)"
    }
}

$AppState = [pscustomobject]@{
    User = $null
    Group = $null
    Paths = @()
    ExportPaths = @{
        Txt = $null
        Json = $null
    }
}

try{
    $Domains = Test-Startup
} catch {
    Display-Error -ErrorMessage $_.exception.message
    return
}

function Validate-User{
    [CmdletBinding()]
    param(
    [string]$Username,
    [string[]]$Domains
    )

    $UserFullObject = $null
    
    foreach($Domain in $Domains){
    
    try {
        $UserFullObject = Get-ADUser -Identity $Username -Server $Domain -Properties * -ErrorAction Stop
        if ($UserFullObject){return $UserFullObject}
    } catch {}
    }
    if (-not $UserFullObject){
        throw "User $($Username) not found"
    }  
}

function Validate-Group{
    [CmdletBinding()]
    param(
    [string]$Groupname,
    [string[]]$Domains
    )

    $GroupFullObject = $null
    foreach($Domain in $Domains){
    try {
        $GroupFullObject = Get-ADGroup -Identity $Groupname -Properties * -Server $Domain -ErrorAction Stop
        if ($GroupFullObject){
        return $GroupFullObject
        }
    } catch {}
    }
    if (-not $GroupFullObject){
        throw "Group $($Groupname) not found"
    } 
}

function Get-ADUserGroupPath {
    param(
        [Parameter(Mandatory)]
        [string]$UserDN,
        [Parameter(Mandatory)]
        [string]$GroupDN,
        [Parameter(Mandatory)]
        [Array]$Domains
    )

    function FindPathRecursive {
    param($GroupDN, $UserDN, $CheckedGroups)

    if ($CheckedGroups -contains $GroupDN) { return @() }
    $CheckedGroups += $GroupDN

    $AllPaths = @()

    
    $DomainDN = ($GroupDN -split '(?<!\\),DC=')[1..99] -join ',DC='
    $DomainFQDN = ($DomainDN -replace 'DC=', '') -replace ',', '.'

    try {
        $DC = (Get-ADDomainController -DomainName $DomainFQDN -Discover).HostName[0]
        $Group = Get-ADGroup -Identity $GroupDN -Server $DC -Properties Members, Name
    } catch { return @() }

    foreach ($MemberDN in $Group.Members) {

        try {
            $MemberObj = Get-ADObject -Identity $MemberDN -Server $DC -Properties objectClass, Name
        } catch { continue }

        # Direct membership
        if ($MemberObj.objectClass -eq 'user' -and $MemberObj.DistinguishedName -eq $UserDN) {
            $AllPaths += ,@($Group.Name)
        }

        # Nested group
        elseif ($MemberObj.objectClass -eq 'group') {
            $NestedPaths = FindPathRecursive -GroupDN $MemberDN -UserDN $UserDN -CheckedGroups $CheckedGroups
            
            foreach ($Path in $NestedPaths) {
                $AllPaths += ,(@($Group.Name) + $Path)
            }
        }
    }

    return $AllPaths
}


    return FindPathRecursive -GroupDN $GroupDN -UserDN $UserDN -CheckedGroups @()
}

function Export-Memberships{
    [cmdletbinding()]
    param(
        [parameter(mandatory)][pscustomobject]$State,
        [parameter(mandatory)][string]$ExportDir
    )
    if (-not $State.Paths -or $State.Paths.count -eq 0){
        throw "No paths to export"
    }
    $TimeStamp = ((Get-Date).ToString("HHmmssddMMyyyy"))
    $Basename = "{0}_{1}_{2}" -f $State.User.SamAccountName, $State.Group.SamAccountName, $TimeStamp
    $TxtPath = Join-Path $ExportDir "$($Basename).txt"
    $JsonPath = Join-Path $ExportDir "$($Basename).json"
    $TxtContent = foreach ($Path in $State.Paths){
        ($Path -join " → ") + " → $($State.User.cn)" 
    }
    Set-Content -Path $TxtPath -Value ($TxtContent -join "`r`n`r`n") -Encoding UTF8 -ErrorAction Stop
    $JsonContent = [pscustomobject]@{
        User = $State.User.SamAccountName
        Group = $State.Group.SamAccountName
        ExportTime = $TimeStamp
        PathCount = $State.Paths.count
        Paths = $State.Paths
    }
    $JsonContent | ConvertTo-Json -Depth 10 | Set-Content -Path $JsonPath -Encoding UTF8 -ErrorAction Stop
    return @{
        Txt = $TxtPath
        Json = $JsonPath
    }
}

function Run-CLI{
    param(
        [string]$User,
        [string]$Group,
        [string]$ExportDir,
        [switch]$Txt,
        [switch]$Json
    )
    try{
        if (-not $User){throw "User not specified"}
        if (-not $Group){throw "Group not specified"}
        if(($Txt -or $Json) -and -not $ExportDir){throw "Path not specified"}
        $UserObj = Validate-User -Username $User -Domains $Domains
        $GroupObj = Validate-Group -Groupname $Group -Domains $Domains

        Write-Host "Found $($UserObj.Name) and $($GroupObj.Name)"
        Write-Host "Searching membership paths..."

        $Paths = Get-ADUserGroupPath -UserDN $UserObj.DistinguishedName -GroupDN $GroupObj.DistinguishedName -Domains $Domains

        if ($Paths.Count -eq 0) {
            Write-Host "User is not a member of the group."
            return
        }

        Write-Host ""
        Write-Host "User is a member via $($Paths.Count) path(s):"
        Write-Host ""

        $i = 1
        foreach ($Path in $Paths) {
            Write-Host "$i. $($Path -join ' → ') → $($UserObj.cn)"
            $i++
        }

        if ($ExportDir) {
            if(-not (Test-Path -Path $ExportDir -PathType Container)){throw "Export path does not exist"}
            $State = [pscustomobject]@{
                User = $UserObj
                Group = $GroupObj
                Paths = $Paths
            }

            $Result = Export-Memberships -State $State -ExportDir $ExportDir

            if ($Txt) {
                Write-Host "TXT exported: $($Result.Txt)"
            }

            if ($Json) {
                Write-Host "JSON exported: $($Result.Json)"
            }

        }

    }
    catch {
        Write-Error $_
    }
}



$IsCliMode = $PSBoundParameters.ContainsKey("User") -or $PSBoundParameters.ContainsKey("Group")
if ($IsCliMode) {
    Run-CLI -User $User -Group $Group -ExportDir $ExportDir -Json:$Json -Txt:$Txt
    return
}


$Tooltip = new-object System.Windows.Forms.ToolTip
$Tooltip.AutoPopDelay = 5000
$Tooltip.InitialDelay = 500
$Tooltip.ReshowDelay = 200
$Tooltip.ShowAlways = $true

$FolderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
$FolderDialog.Description = "Choose where to save the results"
$FolderDialog.ShowNewFolderButton = $true


$OrderedDomains = ""
foreach($Domain in $Domains){ 
$OrderedDomains += "$($Domain)`r`n"
}

$MTForm = New-Object System.Windows.Forms.Form
$MTForm.Text = "Member Tracker" # - current operator: $($env:USERNAME)
$MTForm.Size = New-Object System.Drawing.Size(500,350)
$MTForm.StartPosition = "CenterScreen"


$UsernameLabel = New-Object System.Windows.Forms.Label
$UsernameLabel.Text = "Username:"
$UsernameLabel.Font = New-Object System.Drawing.font("arial", 10,  [System.Drawing.FontStyle]::Bold)
$UsernameLabel.Location = New-Object System.Drawing.Point(20,20)
$UsernameLabel.AutoSize = $true

$MTUserInput = New-Object System.Windows.Forms.TextBox
$MTUserInput.Location = New-Object System.Drawing.Point(100,18)
$MTUserInput.Font = New-Object System.Drawing.font("arial", 10,  [System.Drawing.FontStyle]::Bold)
$MTUserInput.Width = 100
$Tooltip.SetToolTip($MTUserInput, "Enter the username here`r`nshould be the SamAccountName, like Jasonc")

$GroupLabel = New-Object System.Windows.Forms.Label
$GroupLabel.Text = "Group:"
$GroupLabel.Font = New-Object System.Drawing.font("arial", 10,  [System.Drawing.FontStyle]::Bold)
$GroupLabel.Location = New-Object System.Drawing.Point(210,20)
$GroupLabel.AutoSize = $true

$MTGroupInput = New-Object System.Windows.Forms.TextBox
$MTGroupInput.Location = New-Object System.Drawing.Point(265,18)
$MTGroupInput.Font = New-Object System.Drawing.font("arial", 10,  [System.Drawing.FontStyle]::Bold)
$MTGroupInput.Width = 170
$Tooltip.SetToolTip($MTGroupInput, "Enter the group name here`r`nshould be the SamAccountName, like Delivery")

$MTInfoButton = New-Object System.Windows.Forms.Button
$MTInfoButton.Text = "?"
$MTInfoButton.Location = New-Object System.Drawing.Point(440,10)
$MTInfoButton.Font = New-Object System.Drawing.font("arial", 10,  [System.Drawing.FontStyle]::Bold)
$MTInfoButton.Width = 20

$MTButton = New-Object System.Windows.Forms.Button
$MTButton.Text = "Search membership"
$MTButton.Location = New-Object System.Drawing.Point(20,65)
$MTButton.Font = New-Object System.Drawing.font("arial", 10,  [System.Drawing.FontStyle]::Bold)
$MTButton.Width = 200
$Tooltip.SetToolTip($MTButton, "Searches for the user inside of the group")

$MTExportButton = New-Object System.Windows.Forms.Button
$MTExportButton.Text = "Export"
$MTExportButton.Location = New-Object System.Drawing.Point(320,65)
$MTExportButton.Font = New-Object System.Drawing.font("arial", 10,  [System.Drawing.FontStyle]::Bold)
$MTExportButton.Width = 100
$MTExportButton.Enabled = $false
$Tooltip.SetToolTip($MTExportButton, "Searches for the user inside of the group")

$MTTXTLink = New-Object System.Windows.Forms.LinkLabel
$MTTXTLink.Text = "TXT"
$MTTXTLink.Location = New-Object System.Drawing.Point(320,65)
$MTTXTLink.Font = New-Object System.Drawing.font("arial", 10,  [System.Drawing.FontStyle]::Bold)
$MTTXTLink.Width = 50
$Tooltip.SetToolTip($MTTXTLink, "Searches for the user inside of the group")

$MTJSONLink = New-Object System.Windows.Forms.LinkLabel
$MTJSONLink.Text = "JSON"
$MTJSONLink.Location = New-Object System.Drawing.Point(380,65)
$MTJSONLink.Font = New-Object System.Drawing.font("arial", 10,  [System.Drawing.FontStyle]::Bold)
$MTJSONLink.Width = 50
$Tooltip.SetToolTip($MTJSONLink, "Searches for the user inside of the group")

$MTTXTLink.LinkVisited = $false
$MTJSONLink.LinkVisited = $false
$MTTXTLink.Hide()
$MTJSONLink.Hide()

$OutputTB = New-Object System.Windows.Forms.TextBox
$OutputTB.Location = New-Object System.Drawing.Point(20,100)
$OutputTB.Size = New-Object System.Drawing.Size(440,180)
$OutputTB.Multiline = $true
$OutputTB.ScrollBars = "Vertical"
$OutputTB.ReadOnly = $true
$OutputTB.Font = New-Object System.Drawing.font("arial", 12,  [System.Drawing.FontStyle]::Bold)

function Set-UIBusy{
    param([bool]$Busy)
    $MTInfoButton.Enabled = -not $Busy
    $MTButton.Enabled = -not $Busy
}



$MTInfoButton.add_click({
$MTTXTLink.LinkVisited = $false
$MTJSONLink.LinkVisited = $false
$MTTXTLink.Hide()
$MTJSONLink.Hide()
$MTExportButton.Show()
$MTExportButton.Enabled = $AppState.Paths.count -gt 0
$OutputTB.Clear()
$OutputTB.AppendText(@"
Instructions:
1. Enter the SAMAccountName of the user
2. Enter the name of the group
3. Press the button
4. It will show every membership path in which the user is included in the group
"@)
})



$MTButton.Add_Click({
$MTTXTLink.LinkVisited = $false
$MTJSONLink.LinkVisited = $false
$MTTXTLink.Hide()
$MTJSONLink.Hide()
$MTExportButton.Show()

$MTExportButton.Enabled = $AppState.Paths.count -gt 0
Set-UIBusy -Busy $true
$OutputTB.Clear()
try{
$AppState.Paths = @()
$AppState.User = $null
$AppState.Group = $null
$RawUsername = $MTUserInput.Text.Trim()
$RawGroupName = $MTGroupInput.Text.Trim()
if ([string]::IsNullOrWhiteSpace($RawUsername)) {
        throw "Username not specified"
    }
    if ([string]::IsNullOrWhiteSpace($RawGroupName)) {
        throw "Group not specified"
    }
$User = Validate-User -Username $RawUsername -Domains $Domains -ErrorAction Stop
$Group = Validate-Group -Groupname $RawGroupName -Domains $Domains -ErrorAction Stop
$OutputTB.AppendText("Found $($User.name) and $($Group.name),`r`nSearching for group membership... `r`n")
    
    $AppState.User = $User
    $AppState.Group = $Group
    $AppState.Paths = Get-ADUserGroupPath -UserDN $User.DistinguishedName -GroupDN $Group.DistinguishedName -Domains $Domains

    

    if ($AppState.Paths.count -gt 0) {
        $SerialNum = 1
        if ($AppState.Paths.count -eq 1) {$NumPresentation = "$($AppState.Paths.count) path:"} else {$NumPresentation = "$($AppState.Paths.count) paths:"} 
        $OutputTB.Text = "User is a member via $($NumPresentation)`r`n`r`n"
        foreach($Path in $AppState.Paths){
            $OutputTB.AppendText($SerialNum.ToString() + ". " + ($Path -join " → ") + " → $($AppState.User.cn)" + "`r`n`r`n")
            $SerialNum++
        }
    } else {
        $OutputTB.Text = "User is not a member of the group."
    }
    $MTExportButton.Enabled = $AppState.Paths.count -gt 0
} catch {
$OutputTB.Text = $_.exception.message 
} finally {
Set-UIBusy -Busy $false
}    
    
})



$MTExportButton.add_click({
    Set-UIBusy -Busy $true
    $OutputTB.Clear()

    try{
        if($FolderDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){return}
        $ExportDir = $FolderDialog.SelectedPath
        $Result = Export-Memberships -State $AppState -ExportDir $ExportDir
        $AppState.ExportPaths.Txt = $Result.Txt
        $AppState.ExportPaths.Json = $Result.Json
        $OutputTB.AppendText("Files saved successfully`r`n")
        $MTExportButton.Hide()
        $MTTXTLink.Show()
        $MTJSONLink.Show()
    } catch {
        $OutputTB.Text = $_.exception.message
    } finally {
        Set-UIBusy -Busy $false
    }

})

$MTTXTLink.add_linkclicked({
try{
Start-Process -FilePath $AppState.ExportPaths.Txt -ErrorAction Stop
$MTTXTLink.LinkVisited = $true
} catch {
Display-Error -ErrorMessage $($_.exception.message) -ErrorType ""
}
})

$MTJSONLink.add_linkclicked({
try{
Start-Process -FilePath $AppState.ExportPaths.Json -ErrorAction Stop
$MTJSONLink.LinkVisited = $true
} catch {
Display-Error -ErrorMessage $($_.exception.message) -ErrorType ""
}
})

$MTForm.Controls.AddRange(@(
    $UsernameLabel,
    $MTUserInput,
    $GroupLabel,
    $MTGroupInput,
    $MTInfoButton,
    $MTButton,
    $MTExportButton,
    $MTTXTLink,
    $MTJSONLink,
    $OutputTB
))

[void]$MTForm.ShowDialog()
