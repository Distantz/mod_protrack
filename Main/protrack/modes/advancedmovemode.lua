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

local Vector3 = require("Vector3")
local logger = require("forgeutils.logger").Get("AdvMoveMode")
local AngleUtils = require("Common.angleUtils")

--/ Main class definition
---@class AdvModeMode
local AdvModeMode = {}
AdvModeMode.gizmo = nil
AdvModeMode.trackContainerTransform = nil
AdvModeMode.lastTransform = nil
AdvModeMode.isRotating = false
AdvModeMode.moveThres = 0.000001
AdvModeMode.rotThres = 0.00174533

function AdvModeMode.StartEdit(gizmo, trackContainerTransform)
    AdvModeMode.gizmo = gizmo
    logger:Info(global.tostring(trackContainerTransform))
    AdvModeMode.trackContainerTransform = trackContainerTransform
end

function AdvModeMode.EndEdit()
    if (AdvModeMode.gizmo) then
        AdvModeMode.gizmo:Stop()
    end
    AdvModeMode.lastTransform = nil
    AdvModeMode.isRotating = false
end

--- Advances the adv mode mode
--- If return true, a new point is needed.
---@param dt any
---@param tMouseInput any
---@param tGamepadAxisInput any
---@return boolean shouldRefreshTrack Whether the track should be refreshed.
function AdvModeMode.Advance(dt, tMouseInput, tGamepadAxisInput)
    AdvModeMode.gizmo:Step(tMouseInput, tGamepadAxisInput)
    if AdvModeMode.lastTransform == nil or AdvModeMode.gizmo == nil then
        return false
    end

    local thisTransform = AdvModeMode.gizmo:GetTransform()
    local thisPos = thisTransform:GetPos()

    local lastPos = AdvModeMode.lastTransform:GetPos()

    local quaternionDiff = AngleUtils.AngleBetween(AdvModeMode.lastTransform:GetOr(), thisTransform:GetOr())
    if Vector3.LengthSq(thisPos - lastPos) < AdvModeMode.moveThres and quaternionDiff < AdvModeMode.rotThres then
        return false
    end

    AdvModeMode.lastTransform = thisTransform
    return true
end

function AdvModeMode.SwitchTransformMode()
    AdvModeMode.isRotating = not AdvModeMode.isRotating
    AdvModeMode.SetTransformMode(AdvModeMode.isRotating)
end

function AdvModeMode.SwitchTransformSpace()
    AdvModeMode.gizmo:ToggleWorldSpaceLocalSpace()
end

function AdvModeMode.SetTransformMode(isRotation)
    AdvModeMode.gizmo:Stop()
    if isRotation then
        AdvModeMode.gizmo:Start3AxisRotation(
            AdvModeMode.lastTransform,
            AdvModeMode.lastTransform:GetPos(),
            true,
            true,
            true
        )
    else
        AdvModeMode.gizmo:StartTranslation(
            AdvModeMode.lastTransform,
            AdvModeMode.lastTransform:GetPos(),
            true,
            Vector3:new(10, 10, 10)
        )
    end

    AdvModeMode.isRotating = isRotation
end

function AdvModeMode.StaticBuildEndPoint_Hook(_, startT, _)
    if AdvModeMode.lastTransform == nil then
        AdvModeMode.lastTransform = AdvModeMode.trackContainerTransform:ToWorld(startT:GetTransformQ())
        AdvModeMode.SetTransformMode(false)
    end

    logger:Info("Static build end point")
    local transform = AdvModeMode.trackContainerTransform:ToLocal(AdvModeMode.gizmo:GetTransform())
    local pos = transform:GetPos()
    local ypr = transform:GetOr():ToYawPitchRoll()
    return api.track.CreateJoinPoint(
        pos,
        ypr,
        0
    )
end

return AdvModeMode
