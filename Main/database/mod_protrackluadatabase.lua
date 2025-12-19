-- The lua environment for cobra games does not have everything imported by default.
-- You must import things yourself. For instance, the function tostring() is not imported,
-- you must either do global.tostring() or local tostring = global.tostring, then use that global function.
-- You can see that happening here with the table local.
local global = _G
local table = global.table
local FrictionHelper = require("database.frictionhelper")

-- Since api isn't default lua, this has a warning.
-- Disable it so we don't get weird errors if using LuaCATS.
---@type Api
---@diagnostic disable-next-line: undefined-field
local api = global.api

-- Optional: ForgeUtils has logger support! You should use it if you have ForgeUtils installed #plug
-- We require the logger table (which is returned) and call the Get method which returns a logger with
-- a name (our file name for example).
-- Comment out this below line if you want to use the logger instead!
local logger = require("forgeutils.logger").Get("Mod_ProTrackluadatabase")

-- This is our lua database table.
-- The game will run the code in this file and use this table.
-- There are a lot of functions that are called on this file if added.
local LuaDB = {}

-- This call adds "content" (lua files) to call with database functions (like Init, Setup, and InsertToDBs)
-- Any file added in here will have these functions from their table called (if present).
function LuaDB.AddContentToCall(_tContentToCall)
    -- Requires ACSE. If not present, the mod doesn't add this file to be called..
    ---@diagnostic disable-next-line: undefined-field
    if not api.acse or api.acse.versionNumber < 0.7 then
        return
    end
    table.insert(_tContentToCall, require("database.mod_protrackluadatabase"))
end

-- This is one database function that can be called.
-- If your mod works, you should see this print message in your log when using ACSEDebug!
function LuaDB.Init()
    -- Need 1.3 for the Hook Manager.
    require("forgeutils.moddb").RegisterMod("Mod_ProTrack", 1.51)
    logger:Info("Mod_ProTrack called Init()!")
    api.ui2.MapResources("ProTrackUI")
    require("managers.mod_protrack").SetupHooks()
end

LuaDB.Shutdown = function()
    api.ui2.UnmapResources("ProTrackUI")
end

LuaDB.tManagers = {
    ["Environments.CPTEnvironment"] = {
        ["managers.mod_protrack"] = {},
    },
}

function LuaDB.AddLuaManagers(_fnAdd)
    local tData = LuaDB.tManagers
    for sEnvironmentName, tParams in pairs(tData) do
        _fnAdd(sEnvironmentName, tParams)
    end
end

function LuaDB.AddWithFile(filename, _fnAdd)
    _fnAdd(filename, require(filename).GetRoot())
end

function LuaDB.AddLuaPrefabs(_fnAdd)
    logger:Info("Adding prefabs!")
    LuaDB.AddWithFile("prefab_protrack_endpoint", _fnAdd)
    LuaDB.AddWithFile("prefab_protrack_markergizmo", _fnAdd)
    LuaDB.AddWithFile("prefab_protrack_referencepoint", _fnAdd)
end

function LuaDB.PreBuildPrefabs()
    FrictionHelper.Bind()
end

-- We return the LuaDB down here so that when this file
-- is required by the game, it returns the table with our functions.
return LuaDB
