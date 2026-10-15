# FS22_ThrottleHold

A Farming Simulator 22 mod that **keeps a vehicle on the throttle after you get out**. When a tractor is stuck, let it keep driving while you pull it out with a second tractor.

## Features

- Set how much throttle the vehicle keeps applying: **5% to 100%**, in 5% steps
- Choose **forward or reverse**
- The engine keeps running after you get out
- The throttle only works while nobody is driving the vehicle. When you get back in, you drive normally
- A "Throttle hold armed" text shows on screen while it's on and you're in the vehicle
- The percentage and direction are saved per vehicle. The on/off state is not saved, so nothing drives off by itself when you load a savegame
- Works in multiplayer (the server applies the throttle)

## Installation

1. Download `FS22_ThrottleHold.zip` from the [Releases](../../releases) page.
2. Put the zip in `Documents\My Games\FarmingSimulator2022\mods`. Don't unzip it.
3. Turn on **Throttle Hold** when you load your savegame.

## Usage

| Input (in a vehicle) | Action |
|---|---|
| Left CTRL + T | Turn throttle hold on / off |
| Left CTRL + Page Up | Throttle +5% |
| Left CTRL + Page Down | Throttle -5% |
| Left CTRL + G | Switch forward / reverse |

You can change the keys in the game's controls menu.

### Pulling out a stuck tractor

1. Get in the stuck tractor.
2. Set the percentage with CTRL + Page Up / Page Down and the direction with CTRL + G.
3. Press CTRL + T to turn it on.
4. Get out. The tractor keeps driving at the percentage you chose, with the wheels straight.
5. Hook up your other tractor and pull.
6. Once it's free, get back in the stuck tractor and press CTRL + T to turn it off.

**Tip:** start low (30–50%). At 100% the wheels often just spin and dig in deeper.

**Reverse with manual direction change:** if you use the manual direction change setting, put the tractor in reverse yourself before you get out.

## Reporting problems

If something doesn't work, open `Documents\My Games\FarmingSimulator2022\log.txt`, search for `[ThrottleHold]` and `ThrottleHold.lua`, and open an issue with those lines and the vehicle you were using.

## Files

- `modDesc.xml`: mod description, key bindings and translations
- `scripts/register.lua`: adds the mod to every drivable vehicle
- `scripts/ThrottleHold.lua`: throttle logic, keys and on-screen text
- `scripts/ThrottleHoldEvent.lua`: multiplayer event

## Credits

Made by Timo.
