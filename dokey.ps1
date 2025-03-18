<#
    .SYNOPSIS
    This script shows a GUI with which passwords can be generated.

    .DESCRIPTION
    Within the displayed GUI you can set the options for the password generation.
    Presets for those can be added or modified in dokey-settings.psd1
#>
Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,System.Windows.Forms


<# gui #>

# load xaml file (gui)
[xml]$xaml = Get-Content -Path .\dokey.xaml
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# create for every named element in xaml an eponymous ps variable
$xaml.SelectNodes("//*[@Name]") | ForEach-Object {
    Set-Variable -Name ($_.Name) -Value $window.FindName($_.Name) -Description GuiVar
}

# for switching light / dark mode, color values of SolidColorBrush are stored / set in hashtable
$colors = @{
    Light = @{}
    # colors for dark mode are defined here:
    Dark = @{
        ForegroundColor = '#ffffff'
        WindowBorderColor = '#3b3b3b'
        WindowBackgroundColor = '#2b2b2b'
        DokeyToggleButtonColor = '#E5DDBE'
        ContextMenuBackgroundLeftColor = '#262626'
        ContextMenuBackgroundLeftEdgeColor = '#888888'
        ContextMenuBackgroundRightEdgeColor = '#474747'
        ContextMenuBackgroundRightColor = '#242424'
        ContextMenuBorderColor = '#888888'
        ContextMenuSeparatorColor = '#737373'
        MenuItemSelectedBackgroundColor = '#7F4d4d4d'
        TextBoxBorderColor = '#4f4f4f'
        TextBoxBackgroundColor = '#191919'
        GenerateButtonColor = '#FFD6FF'
        CopyButtonColor = '#E5DDBE'
        ButtonBackgroundColor = '#4d4d4d'
        WindowCloseButtonBackgroundColor = '#ea3133'
        CountdownColor = '#B76CB7'
        CheckBoxBackgroundColor = '#191919'
        CheckBoxBorderColor = '#8093E8'
        OptionMarkGlyphColor = '#8093E8'
        OptionMarkMouseOverBackgroundColor = '#191919'
        OptionMarkMouseOverBorderColor = '#80b3e7'
        OptionMarkMouseOverGlyphColor = '#80b3e7'
        OptionMarkPressedBackgroundColor = '#191919'
        OptionMarkPressedBorderColor = '#80b3e7'
        OptionMarkPressedGlyphColor = '#80b3e7'
        OptionMarkDisabledBackgroundColor = '#FFE6E6E6'
        OptionMarkDisabledBorderColor = '#FFBCBCBC'
        OptionMarkDisabledGlyphColor = '#FF707070'
    }
}

# Light color values are defined in dokey.xaml <Window.Resources>. They get stored in $colors.Light here:
foreach ($key in $colors.Dark.Keys) {
    try {
        $lightColorResource = $window.FindResource($key)
    }
    catch {
        Write-Host "Resource $key not found in dokey.xaml" -ForegroundColor Red
        continue
    }
    $lightColor = $lightColorResource.Color
    $colors.Light[$key] = $lightColor
}

function SwitchColors {
    <#
        .SYNOPSIS
        Switches color mode

        .DESCRIPTION
        Changes dokey colors to light or dark mode.

        .PARAMETER Mode
        Switch to Light or Dark Mode?
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Light','Dark')]
        [string]$Mode
    )

    foreach ($key in $colors[$Mode].Keys) {
        $window.Resources[$key] = [System.Windows.Media.SolidColorBrush]::new($colors[$Mode][$key])
    }
}


<# settings #>

# powershell data file dokey-settings.psd1 is loaded in variable $settings
$settings = Import-PowerShellDataFile "$PSScriptRoot\dokey-settings.psd1"

# script variable helps to load presets faster
$Script:DoNotCheckInput = $false

# script variable helps to check input faster
$Script:CanGenerate = $false

# script variable helps to clear clipboard from password
$Script:PasswordInClipboard = ''


# constants that are used multiple times in the script

$characterClasses = @('Lowercase','Uppercase','Numbers','Specials')
$minBoxes = @('MinLowercase','MinUppercase','MinNumbers','MinSpecials')
$lengthBoxes = $minBoxes + 'PasswordLength'

$filterRegex = @{
    Lowercase = '[^a-z]'
    Uppercase = '[^A-Z]'
    Numbers   = '[^0-9]'
    Specials  = '[\p{L}\p{Nd}]'
}

function CheckMinChars {
    <#
        .SYNOPSIS
        Checks tbx Min TextBoxes, if param InputTbx is given, then
        implausible input in the corresponding TextBoxes is highlighted with borders.
        If implausible input is found, the btnGenerate button gets disabled and false is returned.
        Otherwise the btnGenerate button gets enabled and true is returned.

        .DESCRIPTION
        Ensures valid input in
        - tbxLowercase
        - tbxUppercase
        - tbxNumbers
        - tbxSpecials
        - tbxPasswordLength
        - tbxMinLowercase
        - tbxMinUppercase
        - tbxMinNumbers
        - tbxMinSpecials

        .PARAMETER InputTbx
        If this parameter is set, input from a specific tbx Min TextBox is validated.
        If errors are found, they get highlighted with corresponding borders.
        Otherwise all highlighting borders are removed from tbx Min TextBoxes.

        .PARAMETER NewInputText
        This parameter must be passed if InputTbx -in @('Lowercase','Uppercase','Numbers','Specials')
    #>
    param(
        [Parameter()]
        [string]$InputTbx,
        [Parameter()]
        [string]$NewInputText
    )

    $lengthBoxesInputOK = $true
    $characterClassInputOK = $true

    $inputMode = if ($InputTbx -in $characterClasses) {
        'characterClass'
    } elseif ($InputTbx -in $minBoxes) {
        'minBox'
    } elseif ($InputTbx -eq 'PasswordLength') {
        'lengthBox'
    } else {
        'checkup'
    }

    if ($inputMode -eq 'characterClass' -and  $NewInputText -ne '' -and  $Script:CanGenerate) {
        return
    }

    $redBorderBrush = '#ffff0000'
    $transparentBorder = '#00ff0000'

    foreach ($cc in $characterClasses) {
        $ccTextBox = Get-Variable -Name "tbx$cc" -ValueOnly
        $ccBorder = Get-Variable -Name "bdr$cc" -ValueOnly
        if ($ccTextBox.Text -eq '') {
            $characterClassInputOK = $false
            $ccBorder.BorderBrush = $redBorderBrush
        } else {
            $ccBorder.BorderBrush = $transparentBorder
        }
    }

    $passwordLength = $tbxPasswordLength.Text -as [int]
    $minLowercase = if ($cbxLowercase.IsChecked) { $tbxMinLowercase.Text -as [int] } else { 0 }
    $minUppercase = if ($cbxUppercase.IsChecked) { $tbxMinUppercase.Text -as [int] } else { 0 }
    $minNumbers   = if ($cbxNumbers.IsChecked)   { $tbxMinNumbers.Text   -as [int] } else { 0 }
    $minSpecials  = if ($cbxSpecials.IsChecked)  { $tbxMinSpecials.Text  -as [int] } else { 0 }
    
    if ($passwordLength -le 0 -or `
    -not $cbxLowercase.IsChecked -and -not $cbxUppercase.IsChecked -and -not $cbxNumbers.IsChecked -and -not $cbxSpecials.IsChecked -or `
    $passwordLength -lt ($minLowercase + $minUppercase + $minNumbers + $minSpecials)) {
        $lengthBoxesInputOK = $false 
    }

    $btnGenerate.IsEnabled = ($lengthBoxesInputOK -and $characterClassInputOK)

    if ($characterClassInputOK) {
        foreach ($cc in $characterClasses) {
            $ccBorder = Get-Variable -Name "bdr$cc" -ValueOnly
            $ccBorder.BorderBrush = $transparentBorder
        }
    }
    if ($lengthBoxesInputOK) {
        foreach ($lb in $lengthBoxes) {
            $lbBorder = Get-Variable -Name "bdr$lb" -ValueOnly
            $lbBorder.BorderBrush = $transparentBorder
        }
    }

    if ($lengthBoxesInputOK -and $characterClassInputOK) {
        $Script:CanGenerate = $true
        $true
        return
    }

    $Script:CanGenerate = $false

    if ($lengthBoxesInputOK) {
        return
    }

    $bdrPasswordLength.BorderBrush = $redBorderBrush

    if ($passwordLength -le 0) {
        foreach ($min in $minBoxes) {
            $minBorder = Get-Variable -Name "bdr$min" -ValueOnly
            $minBorder.BorderBrush = $transparentBorder
        }
        $false
        return
    }

    if ($inputMode -ne 'minBox') {
        $false
        return
    }

    $ccCheckBox = Get-Variable -Name "cbx$($InputTbx.Substring(3))" -ValueOnly
    if ($ccCheckBox.IsChecked) {
        $minBorder = Get-Variable -Name "bdr$InputTbx" -ValueOnly
        $minBorder.BorderBrush = $redBorderBrush
    }
    $false
}

function SetByCheckBox {
    <#
        .SYNOPSIS
        Sets gui by CheckBox

        .DESCRIPTION
        Enables or disables dokey tbx TextBoxes by CheckBox:
        - cbxLowercase
        - cbxUppercase
        - cbxNumbers
        - cbxSpecials

        .PARAMETER CharacterClass
        Which character class is checked or unchecked?

        .PARAMETER State
        Is CheckBox Checked or Unchecked?
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Lowercase','Uppercase','Numbers','Specials')]
        [string]$CharacterClass,
        [ValidateSet('Checked','Unchecked')]
        [string]$State
    )
    $enable = $State -eq 'Checked'
    $uiElemente = @('tbx','lbl','tbxMin')
    foreach ($u in $uiElemente) {
        $switchElement = Get-Variable -Name "$u$CharacterClass" -ErrorAction SilentlyContinue -ValueOnly
        $switchElement.IsEnabled = $enable
    }
    if (-not $enable) {
        $minBorder = Get-Variable -Name "bdrMin$CharacterClass" -ValueOnly
        $minBorder.BorderBrush = '#00ff0000'
        CheckMinChars | Out-Null
    } else {
        CheckMinChars -InputTbx "Min$CharacterClass" | Out-Null
    }
    switch ($CharacterClass) {
        Lowercase {
            $labelText = $lblCharacterClass.Content.ToString()
            if ($enable) {
                $lblCharacterClass.Content = $labelText -replace '^(× )(.*)','$1c$2' # [×] (c)C3+
                break
            } else {
                $lblCharacterClass.Content = $labelText -replace '^(× )c(.*?)','$1$2' # [ ] |C3+
            }
        }
        Uppercase {
            $labelText = $lblCharacterClass.Content.ToString()
            if ($enable) {
                $lblCharacterClass.Content = $labelText -replace '^(× c{0,1})(.*?)','$1C$2' # [×] c(C)3+
                break
            } else {
                $lblCharacterClass.Content = $labelText -replace '^(× c{0,1})C(.*?)','$1$2' # [ ] c|3+
            }
        }
        Numbers {
            $labelText = $lblCharacterClass.Content.ToString()
            if ($enable) {
                $lblCharacterClass.Content = $labelText -replace '^(× c{0,1}C{0,1})(.*?)','${1}3$2' # [×] cC(3)+
                break
            } else {
                $lblCharacterClass.Content = $labelText -replace '^(× c{0,1}C{0,1})3(.*?)','$1$2' # [ ] cC|+
            }
        }
        Specials {
            $labelText = $lblCharacterClass.Content.ToString()
            if ($enable) {
                $lblCharacterClass.Content = $labelText + '+' # [×] cC3(+)
                break
            } else {
                $lblCharacterClass.Content = $labelText.Trim('+') # [ ] cC3|
            }
        }
    }
}
function SetInputByPreset {
    <#
        .SYNOPSIS
        Sets tbx TextBoxes by Preset parameter (from dokey-settings.psd1)

        .DESCRIPTION
        Sets dokey tbx TextBoxes by Preset:
        - tbxPasswordLength
        - tbxLowercase
        - tbxMinLowercase
        - tbxUppercase
        - tbxMinUppercase
        - tbxNumbers
        - tbxMinNumbers
        - tbxSpecials
        - tbxMinSpecials

        .PARAMETER Preset
        Preset usually comes from dokey-settings.psd1
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Preset
    )
    $Script:DoNotCheckInput = $true
    foreach ($num in $lengthBoxes) {
        if (-not $Preset.ContainsKey($num)) {
            continue
        }
        $txt = $Preset[$num] -replace '[^0-9]'
        $txt = $txt -replace '^[0]+'
        if ([string]::IsNullOrEmpty($txt)) {
            $txt = '0'
        }
        $tbx = Get-Variable -Name "tbx$num" -ValueOnly
        $tbx.Text = $txt
    }
    foreach ($cc in $characterClasses) {
        $hasKey = $Preset.ContainsKey($cc)
        $cbx = Get-Variable -Name "cbx$cc" -ValueOnly
        if ($hasKey -ne $cbx.IsChecked) {
            $cbx.IsChecked = $hasKey
            $state = if ($hasKey) { 'Checked' } else { 'Unchecked' }
            SetByCheckBox -CharacterClass $cc -State $state
        }

        if (-not $hasKey) {
            continue
        }

        $tbx = Get-Variable -Name "tbx$cc" -ValueOnly
        $replacedTxt = $Preset[$cc] -replace $filterRegex[$cc]
        $uniqueChars = @()
        foreach ($c in $replacedTxt.ToCharArray()) {
            if ($c -notin $uniqueChars) {
                $uniqueChars += $c
            }
        }
        $txt = -join $uniqueChars
        $tbx.Text = $txt
    }
    $Script:DoNotCheckInput = $false
    CheckMinChars | Out-Null
}


<# dokeyContextMenu #>

# remove items (from xaml)
$dokeyContextMenu.Items.Clear()

# add items from dokey-settings.psd1 Presets
if ($settings.ContainsKey('Presets')) {
    $first = $true
    foreach ($key in $settings.Presets.Keys) {
        $item = (New-Object System.Windows.Controls.MenuItem)
        $item.Header = $key
        $preset = $settings.Presets[$key]
        if ($preset.ContainsKey('ToolTip')) {
            $item.ToolTip = $preset.ToolTip
        }
        $dokeyContextMenu.Items.Add($item) | Out-Null
        $item.Add_Click({
            $key = $this.Header
            $preset = $settings.Presets[$key]
            SetInputByPreset -Preset $preset
            $this.FontWeight = '600'
            foreach ($i in $dokeyContextMenu.Items) {
                if ($i.Header -ne $key) {
                    $i.FontWeight = 'Normal'
                }
            }
        })
        if ($first) {
            # first preset is default
            SetInputByPreset -Preset $preset
            $item.FontWeight = '600'
        }
        $first = $false
    }
}

$sep = (New-Object System.Windows.Controls.Separator)
$dokeyContextMenu.Items.Add($sep) | Out-Null

# script variable helps to switch hide password option
$Script:HidePassword = if ($settings.ContainsKey('HidePassword')) {
    try {
        [System.Convert]::ToBoolean($settings['HidePassword']) 
    } catch [FormatException] {
        $false
    }
} else {
    $false
}

# hide password option is set
if ($Script:HidePassword) {
    $tbxPassword.Visibility = 'Collapsed'
    $pbxPassword.Visibility = 'Visible'
} else {
    $pbxPassword.Visibility = 'Collapsed'
    $tbxPassword.Visibility = 'Visible'
}

# hide password option is added to context menu
$hidePasswordItem = (New-Object System.Windows.Controls.MenuItem)
$hidePasswordItem.Header = 'hide password'
$hidePasswordItem.IsCheckable = $true
$hidePasswordItem.IsChecked = $Script:HidePassword
$dokeyContextMenu.Items.Add($hidePasswordItem) | Out-Null

# event handlers for hide password option:

$hidePasswordItem.Add_Checked({
    $pbxPassword.Password = $tbxPassword.Text.Trim()
    $tbxPassword.Visibility = 'Collapsed'
    $pbxPassword.Visibility = 'Visible'
    $Script:HidePassword = $true
})

$hidePasswordItem.Add_Unchecked({
    $tbxPassword.Text = $pbxPassword.Password.Trim()
    $pbxPassword.Visibility = 'Collapsed'
    $tbxPassword.Visibility = 'Visible'
    $Script:HidePassword = $false
})

# script variable helps to switch dark mode option
$Script:DarkMode = if ($settings.ContainsKey('DarkMode')) {
    try {
        [System.Convert]::ToBoolean($settings['DarkMode']) 
    } catch [FormatException] {
        $false
    }
} elseif ((Get-ItemPropertyValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme -ErrorAction SilentlyContinue) -eq 0) {
    $true
} else {
    $false
}

# dark mode option is set if necessary
if ($Script:DarkMode) {
    SwitchColors -Mode 'Dark'
}

# dark mode option is added to context menu
$darkModeItem = (New-Object System.Windows.Controls.MenuItem)
$darkModeItem.Header = 'dark mode'
$darkModeItem.IsCheckable = $true
$darkModeItem.IsChecked = $Script:DarkMode
$dokeyContextMenu.Items.Add($darkModeItem) | Out-Null

# event handlers for dark mode option:

$darkModeItem.Add_Checked({
    SwitchColors -Mode 'Dark'
    $Script:DarkMode = $true
})

$darkModeItem.Add_Unchecked({
    SwitchColors -Mode 'Light'
    $Script:DarkMode = $false
})

# event handlers for toggle button (key icon) and context menu:

$dokeyToggleButton.Add_Checked({
    $dokeyContextMenu.PlacementTarget = $this
    $dokeyContextMenu.IsOpen = $true
})

$dokeyToggleButton.Add_MouseRightButtonUp({
    $_.Handled = $true
})

$dokeyContextMenu.Add_Closed({
    $this.PlacementTarget.IsChecked = $false
})

# event handler for expand / collapse button
$expandCollapseButton.Add_Click({
    if ($pthCollapse.Opacity -eq 0) {
        $pthExpand.Opacity = 0
        $pthCollapse.Opacity = 1
        $stkSettings.Visibility = 'Collapsed'
    } else {
        $pthCollapse.Opacity = 0
        $pthExpand.Opacity = 1
        $stkSettings.Visibility = 'Visible'
    }
})

# event handler for all checkboxes
[System.Windows.RoutedEventHandler]$Script:CheckStateChangedEventHandler = {
    if ($Script:DoNotCheckInput) {
        return
    }
    $characterClass = $this.Name.Substring(3)
    $state = $_.RoutedEvent.Name
    SetByCheckBox -CharacterClass $characterClass -State $state
}

# event handlers for password length textbox

$tbxPasswordLength.Add_PreviewTextInput({
    if ($Script:DoNotCheckInput) {
        return
    }
    if ($_.Source.Text -eq '0' -and $_.Source.CaretIndex -eq 1 `
        -or $_.Text -match '[^0-9]') {
        $_.Handled = $true
    }
})

$tbxPasswordLength.Add_TextChanged({
    if ($Script:DoNotCheckInput) {
        return
    }
    if ($this.Text -match '^[0]+$') {
        $this.Text = '0'
        $this.CaretIndex = 1
    }
    CheckMinChars -InputTbx 'PasswordLength' | Out-Null
})

# event handler for all textboxes with minimum number of certain characters
[System.Windows.RoutedEventHandler]$Script:MinTextChangedEventHandler = {
    if ($Script:DoNotCheckInput) {
        return
    }
    if ($this.Text -eq '') {
        $this.Text = '0'
        $this.CaretIndex = 1
        return
    }
    $tbx = $this.Name.Substring(3)
    CheckMinChars -InputTbx $tbx | Out-Null
}

# event handler for all textboxes with characters of a certain class @('Lowercase','Uppercase','Numbers','Specials')
[System.Windows.RoutedEventHandler]$Script:TextChangedEventHandler = {
    if ($Script:DoNotCheckInput) {
        return
    }
    $element = $this
    $characterClass = $element.Name.Substring(3)
    $replacedText = $this.Text -creplace $filterRegex[$characterClass]
    $validText = @()
    foreach ($c in $replacedText.ToCharArray()) {
        if ($c -notin $validText) {
            $validText += $c
        }
    }
    $validText = -join $validText
    if ($this.Text -ne $validText) {
        $oldIndex = $this.CaretIndex
        $x = $_.Changes.GetEnumerator()
        $x.MoveNext()
        $this.Text = $validText
        $this.CaretIndex = $oldIndex - $x.Current.AddedLength
    }
    CheckMinChars -InputTbx $characterClass -NewInputText $validText | Out-Null
}

# add event handlers for all relevant checkboxes and textboxes
foreach ($c in $characterClasses) {
    $cCbx = Get-Variable "cbx$c" -ValueOnly
    $cCbx.AddHandler([System.Windows.Controls.CheckBox]::CheckedEvent,$CheckStateChangedEventHandler)
    $cCbx.AddHandler([System.Windows.Controls.CheckBox]::UncheckedEvent,$CheckStateChangedEventHandler)
    $cTbx = Get-Variable "tbx$c" -ValueOnly
    $cTbx.AddHandler([System.Windows.Controls.TextBox]::TextChangedEvent,$TextChangedEventHandler)
    $cTbxMin = Get-Variable "tbxMin$c" -ValueOnly
    $cTbxMin.AddHandler([System.Windows.Controls.TextBox]::TextChangedEvent,$MinTextChangedEventHandler)
}


# event handler for generate button click

$btnGenerate.ToolTip = "generate`n<< as set below"
$btnGenerate.Add_Click({
    if (-not (CheckMinChars)) {
        return
    }
    $length = $tbxPasswordLength.Text.Trim() -as [int]
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[]($length)
    $rng.GetBytes($bytes)
 
    $newPassword = New-Object char[]($length)

    $pos = 0
    $min = 0
    $allChars = ''
    foreach ($cc in $characterClasses) {
        $cbx = Get-Variable -Name "cbx$cc" -ValueOnly
        $checked = $cbx.IsChecked
        if (-not $checked) {
            continue
        }
        $tbx = Get-Variable -Name "tbx$cc" -ValueOnly
        $chars = $tbx.Text.Trim()
        $allChars += $chars
        $tbxMin = Get-Variable -Name "tbxMin$cc" -ValueOnly
        $min += $tbxMin.Text.Trim() -as [int]
        for ($i = $pos ; $i -lt $min ; $i++) {
            $newPassword[$i] = $chars[$bytes[$i] % $chars.Length]
            $pos++
        }
    }

    $allCharsArray = $allChars.ToCharArray()
    for ($i = $pos ; $i -lt $length ; $i++) {
        $newPassword[$i] = $allCharsArray[$bytes[$i] % $allCharsArray.Length]
    }

    $newPassword = $newPassword | Sort-Object { Get-Random }
    $newPassword = (-join $newPassword)

    if ($Script:HidePassword) {
        $pbxPassword.Password = $newPassword
    } else {
        $tbxPassword.Text = $newPassword
    }

    $btnCopy.IsEnabled = $true
})


# event handler for copy button click

$btnCopy.ToolTip = "copy to clipboard`nclear after 20 sec"
$btnCopy.Add_Click({
    $copyPassword = if ($Script:HidePassword) {
        $pbxPassword.Password.Trim()
    } else {
        $tbxPassword.Text.Trim()
    }
    $Script:PasswordInClipboard = $copyPassword
    Set-Clipboard $copyPassword
    [System.Windows.Media.Animation.Storyboard]$window.Resources["Countdown"].Begin()
})

# event handler for the end of the countdown animation (clipboard gets cleared from password)
$CountdownPointAnimation.Add_Completed({
    $clipboardContent = (Get-Clipboard -ErrorAction SilentlyContinue) -as [string]
    if ($clipboardContent -eq $Script:PasswordInClipboard) {
        Set-Clipboard $null
    }
    $Script:PasswordInClipboard = ''
})

# event handler for minimize button click
$windowMinimizeButton.Add_Click({
    $window.WindowState = 'Minimized'
})

# event handler for closing GUI window (usually close button click)
$window.Add_Closing({
    if (-not [string]::IsNullOrEmpty($Script:PasswordInClipboard)) {
        $clipboardContent = (Get-Clipboard -ErrorAction SilentlyContinue) -as [string]
        if ($clipboardContent -eq $Script:PasswordInClipboard) {
            Set-Clipboard $null
        }
    }
    $clipboardContent = $null
    $Script:PasswordInClipboard = $null
    $Script:DoNotCheckInput = $null
    $Script:CanGenerate = $null
    $Script:PasswordInClipboard = $null
})


<# show gui #>
$window.ShowDialog() | Out-Null