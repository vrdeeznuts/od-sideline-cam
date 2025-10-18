# 4v4 OD Sideline Camera
Orion Drift Sideline Camera for 4v4 (better than the one provided by AA fr). This camera script contains 3 primary features related that make it ideal for competitive players:
1. It's automated.
1. It provides a better perspective of the action compared to POV, 3rd person, or free cam. *It's also more feature-rich than the AA sideline cam.*
1. There is an auto-clipping functionality* for whenever goals are scored.

At its foundation, this camera follows the ball. Since there are plenty of POV/3rd person cameras out there already, I wanted to provide a camera that focuses more on the broad play (somewhat like freecam), while also being more watchable than a human-controlled camera (e.g., VRML casting - no hate, it's just a bit difficult to watch). **This camera is great for team-oriented content and VOD review.** I'd say the coverage (aka view of the ball and general play) is 90-95% with the right settings (see [Usage Section](#usage--customization) for more details).

*The auto-clipping feature is an external Powershell script that reads the auto-generated A2.log file and watches for a specific string before triggering your clipping software's hotkey.

NOTE: *The spectator feature is still under active development and is subject to change throughout closed early access.*

# Usage & Customization


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
