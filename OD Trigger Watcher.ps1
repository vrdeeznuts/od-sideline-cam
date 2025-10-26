# get folder where this script is located
$scriptRoot = $PSScriptRoot
$configPath = Join-Path $scriptRoot "config.json"

# default settings
$defaultConfig = @{
    logFilePath = "$env:LOCALAPPDATA\A2\Saved\Logs\A2.log"
    goalMedalHotkey      = "{F8}"
    goalChapterHotkey = "^%+{MULTIPLY}"
    # chapterHotkey = "^%+{F10}"
    roundStartHotkey = "^%+{DIVIDE}"
    roundEndHotkey = "^%+{BACKSPACE}"
    recordHotkey = "^%+{F11}"
    stopRecordHotkey = "^%+{SUBTRACT}"
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

    # prompt for Medal clipping hotkey
    $goalMedalHotkeyInput = Read-Host -Prompt "Enter Goal hotkey (e.g., if your hotkey is F8, type {F8} - this will change in the future to be easier to input) (Default: $($defaultConfig.goalMedalHotkey))"
    $configGoalMedalHotkey = if ([string]::IsNullOrWhiteSpace($goalMedalHotkeyInput)) { $defaultConfig.goalMedalHotkey } else { $goalMedalHotkeyInput }
    
    # prompt for goal marker hotkey
    $goalChapterHotkeyInput = Read-Host -Prompt "Enter Goal Marker hotkey (e.g., if your hotkey is F8, type {F8} - this will change in the future to be easier to input) (Default: $($defaultConfig.goalChapterHotkey))"
    $configGoalChapterHotkey = if ([string]::IsNullOrWhiteSpace($goalChapterHotkeyInput)) { $defaultConfig.goalChapterHotkey } else { $goalChapterHotkeyInput }
    
    # prompt for Chapter Marker hotkey
    # $chapterHotkeyInput = Read-Host -Prompt "Enter Chapter Marker hotkey (Default: $($defaultConfig.chapterHotkey))"
    # $configChapterHotkey = if ([string]::IsNullOrWhiteSpace($chapterHotkeyInput)) { $defaultConfig.chapterHotkey } else { $chapterHotkeyInput }
    
    # prompt for Round Start hotkey
    $roundStartHotkeyInput = Read-Host -Prompt "Enter Round Start/End hotkey (Default: $($defaultConfig.roundStartHotkey))"
    $configroundStartHotkey = if ([string]::IsNullOrWhiteSpace($roundStartHotkeyInput)) { $defaultConfig.roundStartHotkey } else { $roundStartHotkeyInput }
    
    # prompt for Round End hotkey
    $roundEndHotkeyInput = Read-Host -Prompt "Enter Round End/End hotkey (Default: $($defaultConfig.roundEndHotkey))"
    $configRoundEndHotkey = if ([string]::IsNullOrWhiteSpace($roundEndHotkeyInput)) { $defaultConfig.roundEndHotkey } else { $roundEndHotkeyInput }
    
    # prompt for Record hotkey
    $recordHotkeyInput = Read-Host -Prompt "Enter Record hotkey (Default: $($defaultConfig.recordHotkey))"
    $configRecordHotkey = if ([string]::IsNullOrWhiteSpace($recordHotkeyInput)) { $defaultConfig.recordHotkey } else { $recordHotkeyInput }
    
    # prompt for Stop Record hotkey
    $stopRecordHotkeyInput = Read-Host -Prompt "Enter Stop Record hotkey (Default: $($defaultConfig.stopRecordHotkey))"
    $configStopRecordHotkey = if ([string]::IsNullOrWhiteSpace($stopRecordHotkeyInput)) { $defaultConfig.stopRecordHotkey } else { $stopRecordHotkeyInput }

    # create config object
    $config = @{
        logFilePath = $configLogFilePath
        goalMedalHotkey      = $configGoalMedalHotkey
        goalChapterHotkey = $configGoalChapterHotkey
        # chapterHotkey = $configChapterHotkey
        roundStartHotkey = $configroundStartHotkey
        roundEndHotkey = $configRoundEndHotkey
        recordHotkey = $configRecordHotkey
        stopRecordHotkey = $configStopRecordHotkey
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
Write-Host "Don't close this window until you're done getting clips. (Press Ctrl+c to stop)"

$goalTriggerString = "GOAL_SCORED_MEDAL_TRIGGER"
# $chapterTriggerString = "GOAL_SCORED_MEDAL_TRIGGER","ROUND_STARTED_TRIGGER","ROUND_ENDED_TRIGGER"
$roundStartTriggerString = "ROUND_STARTED_TRIGGER"
$roundEndTriggerString = "ROUND_ENDED_TRIGGER"
$recordTriggerString = "START_RECORDING_TRIGGER"
$stopRecordTriggerString = "STOP_RECORDING_TRIGGER"



if (-not (Test-Path $config.logFilePath)) {
    Write-Host "ERROR: Log file not found at $($config.logFilePath)" -ForegroundColor Red
    Write-Host "Please delete the 'config.json' file in this folder and run the script again to set the correct path."
    Read-Host -Prompt "Press Enter to exit"
    exit
}

Get-Content $config.logFilePath -Wait -Tail 1 | ForEach-Object {
    # Check for Goal
    if ($_.Contains($goalTriggerString)) {
        Write-Host "Goal detected! Sending Medal clip: $($configGoalMedalHotkey)"
        [System.Windows.Forms.SendKeys]::SendWait($config.goalMedalHotkey)

        Write-Host "Sending Chapter marker: $($configGoalChapterHotkey)"
        [System.Windows.Forms.SendKeys]::SendWait($config.goalChapterHotkey)
    }
    # Check for Round Start
    elseif ($_.Contains($roundStartTriggerString)) {
        Write-Host "Round Start detected! Sending keypress: $($config.roundStartHotkey)"
        [System.Windows.Forms.SendKeys]::SendWait($config.roundStartHotkey)
    }
    # Check for Round End
    elseif ($_.Contains($roundEndTriggerString)) {
        Write-Host "Round End detected! Sending keypress: $($config.roundEndHotkey)"
        [System.Windows.Forms.SendKeys]::SendWait($config.roundEndHotkey)
    }
    # Check for Record Start
    elseif ($_.Contains($recordTriggerString)) {
        Write-Host "Start Record detected! Sending keypress: $($config.recordHotkey)"
        [System.Windows.Forms.SendKeys]::SendWait($config.recordHotkey)
    }
    # Check for Record Stop
    elseif ($_.Contains($stopRecordTriggerString)) {
        Write-Host "Stop Record detected! Sending keypress: $($config.stopRecordHotkey)"
        [System.Windows.Forms.SendKeys]::SendWait($config.stopRecordHotkey)
    }
}