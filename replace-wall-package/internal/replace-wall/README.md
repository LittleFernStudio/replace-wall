# Replace Wall

Replace Wall lets you paint natural walls that should be mined and rebuilt. It remembers each
selection, designates the wall for mining, and hands the replacement construction to DFHack's
Buildingplan plugin after the tile becomes a floor.

## Requirements

- Dwarf Fortress with a compatible DFHack release
- The DFHack `buildingplan` plugin enabled

## Installation

### Install command

Extract `replace-wall.zip` anywhere outside the DFHack `hack/scripts` directory. From the extracted
files, drag both of these items into `DFHack/hack/scripts`:

```text
replace-wall-install.lua
replace-wall-package/
```

Keep the package folder intact; do not move its contents individually. Run this from the DFHack
console after both items are in `hack/scripts`:

```text
replace-wall-install
```

The installer copies the Lua files and `replace_wall.png` to their required locations, adds the
`Ctrl+Shift+R` shortcut if necessary, and deletes `replace-wall-package` after a successful install.
It skips files that already exist. To update or repair an existing installation, run:

```text
replace-wall-install --force
```

Restart Dwarf Fortress and DFHack after installation so the preview texture is loaded.

### Manual installation

Copy these files into the matching locations under your DFHack `hack/scripts` directory:

```text
replace-wall.lua
replace-wall-overlay.lua
internal/replace-wall/buildingplan.lua
internal/replace-wall/config.lua
internal/replace-wall/manager.lua
internal/replace-wall/selection.lua
internal/replace-wall/state.lua
internal/replace-wall/tiles.lua
internal/replace-wall/ui.lua
```

Copy `replace_wall.png` into DFHack's `hack/data/art` directory. The completed installation should
include these paths:

```text
DFHack/hack/data/art/replace_wall.png
DFHack/hack/scripts/replace-wall.lua
DFHack/hack/scripts/replace-wall-overlay.lua
DFHack/hack/scripts/internal/replace-wall/
```

Keep the `internal/replace-wall` directory structure intact. Restart Dwarf Fortress and DFHack after
copying the files. DFHack caches registered textures, so reloading only the scripts might not detect
a newly installed or updated `replace_wall.png`.

When only Lua files have changed during development, reload them from the DFHack console with:

```text
lua "require('script-manager').reload()"
```

Run the tool from the DFHack console:

```text
replace-wall paint
```

### Manual keyboard shortcut

DFHack may be installed in a different directory from Dwarf Fortress, and both directories can
contain a file named `dfhack-config/init/dfhack.init`. The active configuration is the one under
the Dwarf Fortress directory returned by `dfhack.getDFPath()`, not the similarly named file under
the separate DFHack directory.

For a typical Steam installation, edit:

```text
Steam/steamapps/common/Dwarf Fortress/dfhack-config/init/dfhack.init
```

Append this line without deleting or replacing anything already in the file:

```text
keybinding add Ctrl-Shift-R@dwarfmode/Default "replace-wall paint"
```

The installer follows the same process: it reads the existing file, checks whether this exact
shortcut is already present, and appends it only when necessary. Restart DFHack or run the command
once in the DFHack console. The shortcut works from the normal fortress map.

## Using the painter

- Left-click and drag to add a straight line.
- Hold Shift while dragging to add a rectangular area.
- Hold Ctrl while dragging to erase pending plans.
- Press `M` to choose a material.
- Press `B` to switch between blocks and boulders.
- Press Escape or right-click to close the painter.

Block mode supports stone, metal, glass, and wood. Boulder mode supports stone because other
materials do not exist as boulders. The material does not need to be available when the plan is
created; Buildingplan waits until a matching item becomes available.

Existing plans keep the material and item form that were selected when they were painted.

## Console commands

```text
replace-wall paint
replace-wall material MARBLE
replace-wall form blocks
replace-wall form boulders
replace-wall status
replace-wall resume
```

Material names may use a full token such as `INORGANIC:MARBLE` or a familiar inorganic name such
as `MARBLE`.

## Removing the script

Remove the two top-level scripts and the `internal/replace-wall` directory. Also remove the
`keybinding add` line from `dfhack.init` if you added it. Existing mining designations and
construction jobs remain in the fortress and can be cancelled normally.
