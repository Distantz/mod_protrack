-----------------------------------------------------------------------
--/  @file    Managers.SceneryLineManager.lua
--/  @author  Inaki
--/  @version 1.0
--/
--/  @brief  Boilerplate template for a park manager script
--/  @see    https://github.com/OpenNaja/ACSE
-----------------------------------------------------------------------
local global = _G
---@type Api
local api = global.api
local pairs = global.pairs
local require = global.require

---@diagnostic disable-next-line: deprecated
local module = global.module

local Object = require("Common.object")
local Mutators = require("Environment.ModuleMutators")
local Vector3 = require("Vector3")
local logger = require("forgeutils.logger").Get("ProTrackManager")

--/ Main class definition
---@class protrackManager
local protrackManager = module(..., Mutators.Manager())

--
-- @Brief Init function for this manager
-- @param _tProperties  a table with initialization data for all the managers.
-- @param _tEnvironment a reference to the current Environment
--
-- The Init function is the first function of the manager being called by the game.
-- This function is used to initialize all the custom data required, however at this
-- stage the rest of the managers might not be available.
--
function protrackManager.Init(self, _tProperties, _tEnvironment)
    logger:Info("Init")
end

-- printTable: prints any Lua value (table, userdata, primitive)
-- All standard library calls are prefixed with `global`.
local function printTable(value)
    -- internal recursive printer
    local function printValue(v, indent, seen)
        indent = indent or 0
        seen = seen or {}

        local prefix = global.string.rep("  ", indent)
        local vType = global.type(v)

        if vType == "table" then
            if seen[v] then
                logger:Info(prefix .. "[table] (already seen)")
                return
            end
            seen[v] = true

            logger:Info(prefix .. "{")
            for k, val in global.pairs(v) do
                local okk, ks = global.pcall(global.tostring, k)
                ks = okk and ks or "[unprintable key]"
                -- print key on same line then nested value
                logger:Info(prefix .. "  " .. ks .. " =")
                printValue(val, indent + 2, seen)
            end
            logger:Info(prefix .. "}")
        elseif vType == "userdata" then
            if seen[v] then
                logger:Info(prefix .. "[userdata] (already seen)")
                return
            end
            seen[v] = true

            -- safe tostring
            local ok, s = global.pcall(global.tostring, v)
            s = ok and s or "[unprintable userdata]"

            -- try to name it from metatable.__name if present
            local mt = (global.getmetatable and global.getmetatable(v)) or nil
            local name = (mt and mt.__name) or nil
            if name then
                logger:Info(prefix .. "<" .. name .. "> " .. s)
            else
                logger:Info(prefix .. s)
            end

            -- If metatable.__index is a table, print it (many userdata expose methods via __index)
            if mt then
                local index = mt.__index
                if index and global.type(index) == "table" then
                    if not seen[index] then
                        logger:Info(prefix .. "metatable.__index = {")
                        seen[index] = true
                        for k, val in global.pairs(index) do
                            local okk, ks = global.pcall(global.tostring, k)
                            ks = okk and ks or "[unprintable key]"
                            logger:Info(prefix .. "  " .. ks .. " =")
                            printValue(val, indent + 2, seen)
                        end
                        logger:Info(prefix .. "}")
                    else
                        logger:Info(prefix .. "metatable.__index = [already seen]")
                    end
                end
            end
        else
            -- primitives or functions etc.
            local ok, s = global.pcall(global.tostring, v)
            s = ok and s or "[unprintable value]"
            logger:Info(prefix .. s)
        end
    end

    -- start printing with a fresh seen table
    printValue(value, 0, {})
end


local function convertExportSplToLuaTable(string)
    local items = {}

    -- Evil code.
    for item_block in string:gmatch("<item>(.-)</item>") do
        local pos_x, pos_y, pos_z = item_block:match('<Pos x="([%d%.%-]+)" y="([%d%.%-]+)" z="([%d%.%-]+)"')
        local rot_x, rot_y, rot_z = item_block:match('<YPR x="([%d%.%-]+)" y="([%d%.%-]+)" z="([%d%.%-]+)"')
        local twist = item_block:match("<Twist>([%d%.%-]+)</Twist>")

        local item = {
            pos = Vector3:new(
                global.tonumber(pos_x),
                global.tonumber(pos_y),
                global.tonumber(pos_z)
            ),
            rot = Vector3:new(
                global.tonumber(rot_x),
                global.tonumber(rot_y),
                global.tonumber(rot_z)
            ),
            twist = global.tonumber(twist),
        }

        global.table.insert(items, item)
    end
    return items
end



--
-- @Brief Activate function for this manager
--
-- Activate is called after all the Managers of this environment have been initialised,
-- and it is safe to assume that access to the rest of the game managers is guaranteed to
-- work.
--
function protrackManager.Activate(self)
    -- Our entry point simply calls inject on the submode override file:
    logger:Info("Injecting...")

    local trackeditsel = require("Editors.Track.TrackEditSelection")
    local baseDeleteSection = trackeditsel.DeleteSelection

    trackeditsel.DeleteSelection = function(slf)
        -- Hook ours
        logger:Info("DeleteSelection hook called!")

        -- printTable(slf.selection)

        -- local sData = api.track.DebugExportSelection(slf.selection, "test_export")
        -- local dps = convertExportSplToLuaTable(sData)

        -- local startPt = slf.selection:GetSelectionStartSplineJoinPoint(false)
        -- local endPt = slf.selection:GetSelectionEndSplineJoinPoint(false)

        -- logger:Info("startPt")
        -- printTable(startPt)
        -- logger:Info("endPt")
        -- printTable(endPt)

        local transforms = {}

        local track = slf.selection:GetTrack()
        local length = slf.selection:GetLength()

        for i = 1, length do
            logger:Info("Doing I " .. i)

            local section = slf.selection:GetSection(i)

            if i == 1 then
                transforms[1] = (api.track.GetTrackLocationFromSection(track, section, 1, 1.0))
                    :GetLocationTransform()
            end

            local trackLoc = (api.track.GetTrackLocationFromSection(track, section, 1, 0.0))

            if trackLoc ~= nil then
                transforms[#transforms + 1] = trackLoc:GetLocationTransform()
            end
        end

        logger:Info("Done. Trying to print!")
        for i, transform in global.ipairs(transforms) do
            logger:Info("I = " .. i)
            logger:Info(global.tostring(transform))
        end

        -- Call original
        baseDeleteSection(slf)

        -- Recreate original lol
    end

    logger:Info("Inserted hooks")
end

--
-- @Brief Deactivate function for this manager
--
-- Deactivate is called when the world is shutting down or closing. Use this function
-- to perform any deinitialization that still requires access to the current world data
-- or other Managers.
--
function protrackManager.Deactivate(self)

end

--/ Validate class methods and interfaces, the game needs
--/ to validate the Manager conform to the module requirements.
Mutators.VerifyManagerModule(protrackManager)
