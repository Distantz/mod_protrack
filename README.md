# ACSE Mod Template
This repository is a template for an ACSE Cobra Engine mod. This repository should be located within the `GAME_NAME\Win64\ovldata\` folder.

## First Setup
### Renames
There are two find and replace operations you must complete on this repository:
- The text `INSERT_MODNAME_HERE` must be changed to your mods name across every file in the repository. 
  - Additionally, the root folder directory should be named like `GAME_NAME\Win64\ovldata\INSERT_MODNAME_HERE\`, with the `INSERT_MODNAME_HERE` being changed. 
  - Additionally, the file `INSERT_MODNAME_HEREluadatabase.lua` must also be renamed.
- The text `INSERT_UUID_HERE` must be changed to a 128-bit UUID. You can generate such a UUID here: https://www.uuidgenerator.net/.

### Cobra Tools setup
This repository is set up to work with the "flatten lua subfolders" setting in Cobra Tools. Please turn it on if it isn't. If you do not want to use this setting, simply add `database.` to the start of the luadatabase file, and move it directly under the Main folder.

### Packaging
In the OVL tool `ovl_tool_gui.py`, navigate in the top bar to `File > New`. Then select the Main folder within this folder. You will note any lua or file errors in the console. Then, navigate to `File > Save`, this will save the OVL, and you should see the toplevel directory contains three files:
- Main (folder)
- Main.ovl
- Manifest.xml

You should then, if running ACSEDebug, see the printout in the log: `INSERT_MODNAME_HERE called Init()!`. If you do not see this, something has gone wrong. Recheck all renames, and make sure your Manifest has a UUID.