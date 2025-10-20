# 4v4 OD Sideline Camera
Orion Drift Sideline Camera version 4 for 4v4. 

# Table of Contents
- [Description](#description)
- [Demo](#demo)
- [Usage & Customization](#usage--customization)
    - [Using the Camera](#using-the-camera)
        - [Workflow after Setup](#base-workflow-after-setup)
        - [Arena Navigation](#arena-navigation)
        - [Other KBM Functions](#other-keyboardmouse-functions)
    - [Recommended Settings](#Settings)
- [What's Included](#whats-included)
- [Setup](#setup)
    - [No Auto-Clipping](#option-1-easy-setup-no-auto-clipping)
    - [With Auto-Clipping](#option-2-setup-with-auto-clipping)
    - [Auto-Clipping Notice](#auto-clipping-notice)
- [Future Work](#future-work)
- [Credits](#credits)

# Description
This camera script contains many features that make it ideal for competitive players:
1. It's automated.
1. It provides a better perspective of the action compared to POV, 3rd person, or free cam. *It's also more feature-rich than the AA sideline cam.*
1. Auto-zoom.
1. Ball outline when the geo is blocking the view.
1. Colored ball trail to indicate who touched it last.
1. Game scoreboard in the GUI:
    - Team rosters (with goals per player)
    - Score
    - Clock
    - Last player who scored
1. Auto-clipping functionality* for whenever goals are scored.

At its foundation, this camera follows the ball. Since there are plenty of POV/3rd person cameras out there already, I wanted to provide a camera that focuses more on the broad play (somewhat like freecam), while also being more watchable than a human-controlled camera (e.g., VRML casting - no hate, it's just a bit difficult to watch). **This camera is great for team-oriented content and VOD review.** I'd say the coverage (aka view of the ball and general play) is 90-95% with the right settings (see [Usage Section](#usage--customization) for more details).

*The auto-clipping feature is an external Powershell script that reads the auto-generated A2.log file and watches for a specific string before triggering your clipping software's hotkey.

NOTE: *The spectator feature is still under active development and is subject to change throughout closed early access.*

# Demo
[iVi vs S7](https://youtu.be/LM-a9P_5bfg?si=wgDXQLXjnteWxeyO) YouTube video (unlisted)

# Usage & Customization
**DON'T FORGET TO SAVE YOUR SETTINGS AFTER YOU SET THINGS UP** (there's a `Save Current Settings` button).

## Using the camera
`Numpad 0` key: default keybind to select the camera when you open spec (you can change it if you like).<br>

Since this is an auto-cam, you don't need to do anything while actively running it. With that being said, you still currently have to select the arena you want to spectate if the default or saved arena is not the right one. *In a future version, I'll add an auto-select arena based on a whitelist.*

### Base Workflow After Setup
1. Open Spectator
1. Select server
1. Press `Numpad 0` key or other pre-defined key for this camera if not set as default
1. Navigate to desired arena (see [Arena Navigation](#arena-navigation) below)
1. Confirm settings are good
1. (Optional) Confirm clipping whitelist is good if using auto-clipping
1. (Optional) Start Powershell auto-clipping script (see [Auto-Clipping Setup](#option-2-setup-with-auto-clipping) for ways to run the script)
1. Win scrim!

### Arena Navigation
- `up` and `down` arrow keys: cycle between the arenas on the side you're on (e.g., if you're at West-1 and you click `down`, it'll move to West-3)
- `a`: jump between East and West Driftplexes
- `s`: swap sideline (if you have `Auto-switch Sideline` enabled, this is kind of useless tbh)

### Other Keyboard/Mouse Functions
#### Keyboard
- `n`: Toggle nametags (why? `n` for `names`)
- `z`: Toggle auto zoom (why? `z` for `zoom`)
- `e`: Toggle endzone rise (why? `e` for `endzone`)
- `c`: Toggle endzone inward hook (why? `c` for `curve`)

#### Mouse
- `Mouse scrolling`: zoom in or out<br>
    Details:
    - [x] Auto Zoom: it will try to keep the ball roughly the same size based on how much you've zoomed in
    - [ ] Auto Zoom (disabled): normal zoom in/out without auto-adjusting

## Settings
There are a ton of settings that you can use or configure to your preferences. There is also decent documentation and tooltips in the GUI to provide guidance on what each setting is. 

Recommended Settings (I leave the unmentioned settings as default):
- Arena
    - [x] Auto-switch Sideline
    - [x] Instant side switch
- Camera
    - Toggles
        - [x] Ball Outline when Hidden
        - [x] Auto Zoom
        - [ ] Endzone Rise (off)
        - [x] Endzone Inward Hook
    - Sliders
        - How much the camera moves inward: `2.5`
        - How much the camera moves backward: `0`
        - Sideline distance (x) from arena center: `2093`
        - Dolly rail length (y) from half field: `3072`
        - Ball tracking smoothing: `0.3 - 0.35`
        - Dolly smoothing: `0.2 - 0.3`
- Ball Trail
    - Trail length: `0.2 - 0.3`
    - Max Thickness: `25-26`
    - Ball Trail Start Offset: `1 or 2`

# What's Included
- `yuki.SIDE.luau` - this is the camera script that you would put with other camera scripts. It has 99% of the functionality but doesn't include the auto-clipping (the spectator API is sandboxed, so it can't send keystrokes by itself).
- `Goal Watcher.ps1` - this is a Powershell script that enables the auto-clipping feature. It listens for certain messages in the A2.log (which is auto-generated each time you run spec) to trigger your clipping hotkey.

# Setup
You can choose from either setup instructions below.<br> 
*If you choose [Option 2](#option-2-setup-with-auto-clipping), you only need to do this setup once. Any subsequent run should be pretty seamless.*
- If you're not interested in the auto-clipping feature, choose [Option 1](#option-1-easy-setup-no-auto-clipping). 
- If you want auto-clipping, choose [Option 2](#option-2-setup-with-auto-clipping).

## Option 1: Easy Setup, No Auto-Clipping
1. Download the `yuki.SIDE.luau` file and put it in your `...\Documents\Another-Axiom\A2\Cameras\Behaviors\` folder (same has how you'd normally do it with any other camera script).
1. Done.

## Option 2: Setup With Auto-Clipping
1. Download `yuki.SIDE.luau` and put it in your `...\Documents\Another-Axiom\A2\Cameras\Behaviors\` folder (same has how you'd normally do it with any other camera script).
1. Download `Goal Watcher.ps1`. Put it in a safe folder (I recommend making a new folder and putting it on your desktop).
1. If you've never used Powershell scripting before:
    1. Click the Windows key -> Type `powershell` -> Click `Run as Administrator` -> Click `Yes` in the admin pop-up.
    1. In the Powershell window that pops up, type `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` -> press `Enter` -> Type `a`, `Enter` if prompted (this allows you to run Powershell scripts, which is used to send the clipping hotkey when goals are scored), and finally close the Powershell terminal. <br>
    1. Go back to the File Explorer where the `Goal Watcher.ps1` file is located and Right click on the file -> Click Properties.
    1. In the Properties window, Click the `Unblock` checkbox then hit `Apply`. Click `OK` to close the window.
1. (Optional) Set the script up as a desktop shortcut (otherwise you will have to Right Click the file -> Click `Run with Powershell` each time).
    1. Right Click the file -> Click `Send to` -> Click `Desktop (create shortcut)`. <br>
    (If you don't see `Send to` as an option, you might need to click `Show more options` at the bottom first.)
    1. Right Click the shortcut you created -> Click `Properties`.
    1. In the Properties window in the `Target` text box, click the textbox and go to the beginning of the line. Add `powershell.exe ` in front of the file path<br> 
    It should now look something like `powershell.exe "C:\Users\username\OneDrive\Desktop\pwsh_scripts\Medal Clipper\Goal Watcher.ps1"`.
    1. (Optional) Add a Shortcut key.
    1. Click `Apply` -> Click `OK`.
1. Done.

Now with the setup complete, you can run the script. The first time you run it, it will prompt for the following info:
- `file path to A2.log`. Probably leave this as default (Click `Enter`)
- `delay`: how many seconds after a goal is scored to "press" your hotkey (default 0; change if you want to wait a few seconds after the goal before clipping)
- `hotkey`: the specific hotkey string you use for clipping (Default is F8 key). If you use a different function key, just make sure to put squiggly brackets around it (e.g., `{F6}`, `{F7}`, etc.). If you use a keyboard shortcut or macro, here's a helpful list of examples (full list of key->code mappings can be found at [Microsoft System Windows Forms](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.sendkeys?view=windowsdesktop-10.0)):
    - Ctrl:   `^` (example: `^c` for Ctrl+C)
    - Alt:    `%` (example: `%{F4}` for Alt+F4)
    - Shift:  `+` (example: `+a` for Shift+a)
    - Enter:  `~` 
    - Tab:    `{TAB}`
    - Esc:    `{ESC}`
    - Delete: `{DEL}`
    - Home:   `{HOME}`
    - End:    `{End}`

### Auto-Clipping Notice
Because the camera scripts are sandboxed (aka no way to interact with your computer outside of the game), I had to write that Powershell script to be able to send keystrokes. It works by listening to the auto-generated A2.log file (usually found at `%LOCALAPPDATA%\A2\Saved\Logs\A2.log`) for a specific string - `"GOAL_SCORED_MEDAL_TRIGGER"`. When the script sees that string in the log, it will send your specified clipping hotkey after an optional delay. Refer to the [auto-clipping instructions](#option-2-setup-with-auto-clipping) below to set it up.

# Future Work
Things I plan to add or want to add to this camera.
- [ ] Add auto-select arena based on whitelist
- [ ] Add more info to scoreboard GUI
    - [ ] Assists
    - [ ] Saves
    - [ ] Other stats? (pass completion, tackles, etc.)
- [ ] I'm open to requests and/or feedback

# Credits
- scripts written by `Yuki.10` (iVi NA/TTT)
- some components inspired by `Dennssen` and `Brick.Rage`
- script idea by `Mozzy` (Riptide)
- auto-clipping requested by `Dwagin` (Aesir)