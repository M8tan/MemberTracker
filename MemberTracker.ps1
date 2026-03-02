Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
try{
Import-Module activedirectory -ErrorAction Stop
} catch {
([System.Windows.Forms.MessageBox]::Show("$($_.exception.message)", "Oops!", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error))
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

try{
$Domains = (Get-ADForest).Domains
} catch {
([System.Windows.Forms.MessageBox]::Show("$($_.exception.message)", "Oops!", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error))
return
}
$OrderedDomains = ""
foreach($Domain in $Domains){ 
$OrderedDomains += "$($Domain)`r`n"
}

$script:Found = $false
function Update-Export(){
if ($script:Found){
$MTExportButton.Enabled = $true
} else {
$MTExportButton.Enabled = $false
}
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
$MTExportButton.Enabled = $Found
$Tooltip.SetToolTip($MTExportButton, "Searches for the user inside of the group")

$OutputTB = New-Object System.Windows.Forms.TextBox
$OutputTB.Location = New-Object System.Drawing.Point(20,100)
$OutputTB.Size = New-Object System.Drawing.Size(440,180)
$OutputTB.Multiline = $true
$OutputTB.ScrollBars = "Vertical"
$OutputTB.ReadOnly = $true
$OutputTB.Font = New-Object System.Drawing.font("arial", 12,  [System.Drawing.FontStyle]::Bold)

function Get-ADUserGroupPath {
    param(
        [Parameter(Mandatory)]
        [string]$UserSamAccountName,
        [Parameter(Mandatory)]
        [string]$GroupDN,
        [Parameter(Mandatory)]
        [Array]$Domains
    )

    $User = $null
    foreach ($Domain in $Domains) {
        try {
            $User = Get-ADUser -Identity $UserSamAccountName -Server $Domain -ErrorAction Stop
            if ($User) { break }
        } catch {}
    }
    if (-not $User) { return $null }

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


    return FindPathRecursive -GroupDN $GroupDN -UserDN $User.DistinguishedName -CheckedGroups @()
}



$MTInfoButton.add_click({
$script:Found = $false
Update-Export
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
$script:Found = $false
Update-Export
$MTButton.Enabled = $false
    $OutputTB.Text = ""
    $RawUsername = $MTUserInput.Text.Trim()
    $RawGroupName = $MTGroupInput.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($RawUsername)) {
        $OutputTB.AppendText("Username not specified :)`r`n")
        $MTButton.Enabled = $true
        return
    }
    if ([string]::IsNullOrWhiteSpace($RawGroupName)) {
        $OutputTB.AppendText("Group not specified :)`r`n")
        $MTButton.Enabled = $true
        return
    }
    
    $UserFullObject = $null
    
    foreach($Domain in $Domains){
    
    try {
        $UserFullObject = Get-ADUser -Identity $RawUsername -Server $Domain -Properties * -ErrorAction Stop
        if ($UserFullObject){
        $OutputTB.AppendText("Found $($UserFullObject.cn) - $($UserFullObject.title) in: $($Domain) `r`n")
        break
        }
    } catch {
        
    }
    }
    if (-not $UserFullObject){
    $OutputTB.Text = "No user named $($RawUsername) in all of: `r`n$($OrderedDomains) :( `r`n"
    $MTButton.Enabled = $true
    return
    }
    
    $GroupFullObject = $null
    
    foreach($Domain in $Domains){
    
    try {
        $GroupFullObject = Get-ADGroup -Identity $RawGroupName -Properties * -Server $Domain -ErrorAction Stop
        if ($GroupFullObject){
        $OutputTB.AppendText("Found $($GroupFullObject.cn) in: $($Domain) `r`n")
        break
        }
    } catch {
        
    }
    }
    if (-not $GroupFullObject){
    $OutputTB.Text = "No group named $($RawGroupName) in all of: `r`n$($OrderedDomains) :( `r`n"
    $MTButton.Enabled = $true
    return
    }
    $OutputTB.AppendText("`r`nSearching for group membership... `r`n")
    $OutputTB.Clear()
    $UserSam = $UserFullObject.SamAccountName
    $GroupDN = $GroupFullObject.DistinguishedName
    
    $script:Paths = Get-ADUserGroupPath -UserSamAccountName $UserSam -GroupDN $GroupDN -Domains $Domains
    $script:UsernameFE = $UserFullObject.SamAccountName
    $script:GroupnameFE = $GroupFullObject.SamAccountName

    if ($script:Paths -and $script:Paths.count -gt 0) {
        $SerialNum = 1
        if ($script:Paths.count -eq 1) {$NumPresentation = "$($script:Paths.count) path:"} else {$NumPresentation = "$($script:Paths.count) paths:"} 
        $OutputTB.Text = "User is a member via $($NumPresentation)`r`n`r`n"
        foreach($Path in $script:Paths){
            $OutputTB.AppendText($SerialNum.ToString() + ". " + ($Path -join " → ") + " → $($UserFullObject.cn)" + "`r`n`r`n")
            $SerialNum++
        }
        $script:Found = $true
        Update-Export
    } else {
        $OutputTB.Text = "User is NOT a member of the group."
    }
    $MTButton.Enabled = $true

    
    
})

$MTExportButton.add_click({
    $OutputTB.Text = ""
    if($FolderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
    $ExportDir = $FolderDialog.SelectedPath
    $TimeStamp = ((Get-Date).ToString("HHmmssddMMyyyy"))
    $ExportTXTFileName = "$($script:UsernameFE)_$($script:GroupnameFE)_$($TimeStamp).txt"
    $ExportTXTPath = Join-Path $ExportDir $ExportTXTFileName
    $ExportJSONFileName = "$($script:UsernameFE)_$($script:GroupnameFE)_$($TimeStamp).json"
    $ExportJSONPath = Join-Path $ExportDir $ExportJSONFileName
    $TXTFormattedPaths = ""
    
    $ExportJSONObject = [pscustomobject]@{
        User = $script:UsernameFE
        Group = $script:GroupnameFE
        ExportTime = $TimeStamp
        PathCount = if($script:Paths){$script:Paths.Count} else {0}
        Paths = @()
    }
    
    foreach ($Path in $script:Paths){
    $TXTFormattedPaths += (($Path -join " → ") + " → $($script:UsernameFE)" + "`r`n`r`n")
    $ExportJSONObject.Paths += ,$Path
    }

    $OutputTB.Text = "Saving results to $($ExportTXTPath)...`r`n"

    try {
    Set-Content -Path $ExportTXTPath -Value $TXTFormattedPaths -Encoding UTF8 -Confirm:$false -ErrorAction Stop
    $OutputTB.AppendText("Done!`r`n")
    } catch {
    $OutputTB.AppendText("Failed - $($_.exception.message)`r`n")
    }
    $OutputTB.AppendText("Saving results to $($ExportJSONPath)...`r`n")
    try {
    $JSONData = $ExportJSONObject | ConvertTo-Json -Depth 10
    Set-Content -Path $ExportJSONPath -Value $JSONData -Encoding UTF8 -Confirm:$false -ErrorAction Stop
    $OutputTB.AppendText("Done!`r`n")
    } catch {
    $OutputTB.AppendText("Failed - $($_.exception.message)`r`n")
    }
    } else {
    $OutputTB.Text = "Fine"
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
    $OutputTB
))

[void]$MTForm.ShowDialog()
