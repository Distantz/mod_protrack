-- The lua environment for cobra games does not have everything imported by default.
-- You must import things yourself. For instance, the function tostring() is not imported,
-- you must either do global.tostring() or local tostring = global.tostring, then use that global function.
-- You can see that happening here with the table local.
local global = _G
local table = global.table
local MainButtonPrompts = require("Database.MainButtonPrompts")

-- Since api isn't default lua, this has a warning.
-- Disable it so we don't get weird errors if using LuaCATS.
---@type Api
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
    if not api.acse or api.acse.versionNumber < 0.7 then
        return
    end
    table.insert(_tContentToCall, require("database.mod_protrackluadatabase"))
end

-- This is one database function that can be called.
-- If your mod works, you should see this print message in your log when using ACSEDebug!
LuaDB.Init = function()
    require("forgeutils.moddb").RegisterMod("Mod_ProTrack", 1.0)
    logger:Info("Mod_ProTrack called Init()!")
    api.ui2.MapResources("ProTrackUI")
end

LuaDB.Shutdown = function()
    api.ui2.UnmapResources("ProTrackUI")
end

LuaDB.tManagers = {
    ["Environments.CPTEnvironment"] = {
        ["managers.mod_protrack"] = {},
    },
}

-- @brief Add
function LuaDB.AddLuaManagers(_fnAdd)
    local tData = LuaDB.tManagers
    for sEnvironmentName, tParams in pairs(tData) do
        _fnAdd(sEnvironmentName, tParams)
    end
end

-- If using ForgeUtils, this method is called when database data should be inserted.
-- Use the builders or bindings defined by ForgeUtils, or call your own SQL bindings in here.
-- function LuaDB.InsertToDBs() end

-- We return the LuaDB down here so that when this file
-- is required by the game, it returns the table with our functions.
return LuaDB
