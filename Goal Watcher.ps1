# get folder where this script is located
$scriptRoot = $PSScriptRoot
$configPath = Join-Path $scriptRoot "config.json"

# default settings
$defaultConfig = @{
    logFilePath = "$env:LOCALAPPDATA\A2\Saved\Logs\A2.log"
    delay       = 0
    hotkey      = "{F8}"
}

# prompt user first time to configure script settings
if (-not (Test-Path $configPath)) {
    Write-Host "--- First Time Setup ---" -ForegroundColor Yellow
    Write-Host "Provide answers to the following prompts. Your answers will be saved in config.json."
    Write-Host "You can press Enter for any prompt to accept the (Default) value."
    Write-Host "------------------------"

    # prompt for OD log file path (user should probably keep default)
    $logFilePathInput = Read-Host -Prompt "Enter the OD log file path (Default: $($defaultConfig.logFilePath))"
    $configLogFilePath = if ([string]::IsNullOrWhiteSpace($logFilePathInput)) { $defaultConfig.logFilePath } else { $logFilePathInput }

    # prompt for delay (seconds) after goal scored to begin clip
    $delayInput = Read-Host -Prompt "Enter delay in seconds before clipping (Default: $($defaultConfig.delay))"
    $configDelay = if ([string]::IsNullOrWhiteSpace($delayInput)) { $defaultConfig.delay } else { [int]$delayInput }

    # prompt for Medal clipping hotkey
    $hotkeyInput = Read-Host -Prompt "Enter Medal hotkey (e.g., {F8}, G, ^G) (Default: $($defaultConfig.hotkey))"
    $configHotkey = if ([string]::IsNullOrWhiteSpace($hotkeyInput)) { $defaultConfig.hotkey } else { $hotkeyInput }

    # create config object
    $config = @{
        logFilePath = $configLogFilePath
        delay       = $configDelay
        hotkey      = $configHotkey
    }

    # save configuration to config.json
    $config | ConvertTo-Json | Out-File $configPath
    Write-Host "Configuration saved! Starting the clipper..." -ForegroundColor Green
}
else {
    $config = Get-Content $configPath | ConvertFrom-Json
    Write-Host "Configuration loaded from config.json. Starting the clipper..." -ForegroundColor Green
}

# main loop to watch OD log
Add-Type -AssemblyName System.Windows.Forms
Write-Host "Watching log file: $($config.logFilePath)"
Write-Host "Trigger key: $($config.hotkey) | Delay: $($config.delay)s"
Write-Host "Don't close this window until you're done getting clips. (Press Ctrl+c to stop)"

$triggerString = "GOAL_SCORED_MEDAL_TRIGGER"

if (-not (Test-Path $config.logFilePath)) {
    Write-Host "ERROR: Log file not found at $($config.logFilePath)" -ForegroundColor Red
    Write-Host "Please delete the 'config.json' file in this folder and run the script again to set the correct path."
    Read-Host -Prompt "Press Enter to exit"
    exit
}

Get-Content $config.logFilePath -Wait -Tail 1 | ForEach-Object {
    if ($_.Contains($triggerString)) {
        Write-Host "Goal detected! Waiting $($config.delay) second(s) before clipping..."
        Start-Sleep -Seconds $config.delay
        Write-Host "Sending keypress: $($config.hotkey)"
        [System.Windows.Forms.SendKeys]::SendWait($config.hotkey)
    }
}