# Gadget Cycle

A tiny [Cyber Engine Tweaks](https://github.com/maximegmd/CyberEngineTweaks) mod for **Cyberpunk 2077 (2.x)**:
one hotkey cycles the combat-gadget button through your **favorite** grenades and ability
cyberware (Optical Camo, Projectile Launch System), without opening the Alt radial wheel.

## Features

- **Cycle hotkey**: each press puts the next favorite on the combat-gadget button. Throw or activate it with your usual key.
- **Favorites checklist** in the CET overlay. If nothing is ticked, it cycles everything you own.
- **Key lock slider**: ignores repeated presses for a short time (0.35 s by default), so a hard mouse-wheel flick moves one step instead of several.
- **Stays quiet** while a game menu or the CET overlay is open.
- Only installed ability cyberware is cycled. Grenade stacks of the same type count once.

## Requirements

- Cyberpunk 2077 2.x (PC)
- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) for your game version

## Installation

Download `gadget_cycle.zip` from the [latest release](../../releases/latest).

### With Amethyst (supported)

1. Install Cyber Engine Tweaks first, if you don't have it.
2. In Amethyst, add `gadget_cycle.zip` as a new mod (install from archive / drag and drop the zip).
3. Enable the mod and deploy, then start the game.

### Manually

Extract `gadget_cycle.zip` into your Cyberpunk 2077 install folder (the one containing `bin/` and `r6/`).
You should end up with:

```
Cyberpunk 2077/bin/x64/plugins/cyber_engine_tweaks/mods/gadget_cycle/init.lua
```

### Vortex / Nexus Mod Manager

Not supported.

## Upgrading from QuickFav

Remove the old `quickfav` mod. To keep your settings, copy its `favorites.json` into the `gadget_cycle` folder. Set the key binding again in CET.

## Usage

1. Load a save and open the CET overlay (default `~`).
2. **Bindings** → set a key for *Cycle favorite grenade / ability*.
3. In the **Gadget Cycle** window, tick your favorites and adjust *Key lock (s)* if needed.
4. Close the overlay and press your key. The gadget icon on the HUD changes.

Settings are saved to `favorites.json` next to `init.lua`. The favorites list is saved as soon as you tick or untick an item; the slider value is saved when you close the overlay.

## Troubleshooting

- **An ability is missing from the list**: open the Gadget Cycle window, click *Debug: print cyberware to console*, and include the CET console output in an issue.
- **Errors**: copy the error from the CET console into an issue.

## Development

- All code is in `bin/x64/plugins/cyber_engine_tweaks/mods/gadget_cycle/init.lua`. After editing, use *Reload All Mods* in the CET overlay.
- Run the mock self-test: `luajit test_gadget_cycle.lua`
- Build the release zip: `zip -r gadget_cycle.zip bin`
