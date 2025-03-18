@{
    <# Presets can be selected in context menu of dokey toggle button (key icon)
                                                   `· dokeyToggleButton
                                                        -> ToggleButton.ContextMenu
    #>
    Presets = @{
        # first gets loaded by default
        'dokey defaults' = @{
            ToolTip = 'layer 8 hardened'
            PasswordLength = '12'
            Lowercase = 'abcdefghijkmnpqrstuvxyz'
            MinLowercase = '4'
            Uppercase = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
            MinUppercase = '3'
            Numbers = '123456789'
            MinNumbers = '1'
            Specials = ",.-#+*!§`$%&/?"
            MinSpecials = '1'
        }
        'more characters' = @{
            ToolTip = 'advanced stuff'
            PasswordLength = '16'
            Lowercase = 'abcdefghijklmnopqrstuvxyz'
            MinLowercase = '5'
            Uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
            MinUppercase = '4'
            Numbers = '1234567890'
            MinNumbers = '1'
            Specials = ",;.:_-#`'+*\!`"§`$%&/()[]{}=?"
            MinSpecials = '2'
        }
        # … modify or add your own …
    }
    # hide password - default for option in context menu of dokey toggle button (key icon)
    HidePassword = $false
    
    # dark mode - default for option in context menu of dokey toggle button (key icon)
    #           - if not set then it defaults to system setting
    #DarkMode = $false
}