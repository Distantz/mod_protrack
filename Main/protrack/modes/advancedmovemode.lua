local TranslationGizmo = require("Editors.Scenery.Utils.TranslationGizmo")
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
---@diagnostic disable-next-line: undefined-field
local api = global.api
local pairs = global.pairs
local coroutine = global.coroutine
local require = global.require

---@diagnostic disable-next-line: deprecated
local module = global.module

local Object = require("Common.object")
local Mutators = require("Environment.ModuleMutators")
local Vector3 = require("Vector3")
local Quaternion = require("Quaternion")
local CameraUtils = require("Components.Cameras.CameraUtils")
local TransformQ = require("TransformQ")
local Utils = require("protrack.utils")
local Gizmo = require("protrack.displaygizmo")
local Line = require("protrack.displayline")
local Cam = require("protrack.cam")
local Datastore = require("protrack.datastore")
local FrictionHelper = require("database.frictionhelper")
local InputEventHandler = require("Components.Input.InputEventHandler")
local logger = require("forgeutils.logger").Get("AdvMoveMode")
local ForceOverlay = require("protrack.ui.forceoverlay")
local table = require("common.tableplus")
local mathUtils = require("Common.mathUtils")
local UnitConversion = require("Helpers.UnitConversion")

--/ Main class definition
---@class AdvModeMode
local AdvModeMode = {}
AdvModeMode.translationGizmo = nil

function AdvModeMode.StartEdit()
    AdvModeMode.translationGizmo = TranslationGizmo:new()
    AdvModeMode.translationGizmo:Init()
    AdvModeMode.translationGizmo:SetType(nil)
end

function AdvModeMode.EndEdit()
    if (AdvModeMode.translationGizmo) then
        AdvModeMode.translationGizmo:Shutdown()
        AdvModeMode.translationGizmo = nil
    end
end

function AdvModeMode.StaticBuildEndPoint_Hook(originalMethod, startT, tData)
    return originalMethod(startT, tData)
end

return AdvModeMode
