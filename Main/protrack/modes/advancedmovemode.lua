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
---@type DraggableWidgets
AdvModeMode.gizmo = nil
AdvModeMode.trackContainerTransform = nil
AdvModeMode.lastTransform = nil
AdvModeMode.isRotating = false
AdvModeMode.cacheRotateSnapValue = false
AdvModeMode.moveThres = 0.000001
AdvModeMode.rotThres = 0.00174533

function AdvModeMode.StartEdit(gizmo, trackContainerTransform)
    AdvModeMode.gizmo = gizmo
    AdvModeMode.trackContainerTransform = trackContainerTransform
    AdvModeMode.isRotating = false
    AdvModeMode.lastTransform = nil

    AdvModeMode.cacheRotateSnapValue = api.world.GetWorldAPIs().gamevolatileconfig:GetRotationSnapEnabled()
    api.world.GetWorldAPIs().gamevolatileconfig:SetRotationSnapEnabled(false)
end

function AdvModeMode.EndEdit()
    if (AdvModeMode.gizmo) then
        AdvModeMode.gizmo:Stop()
    end
    AdvModeMode.lastTransform = nil
    AdvModeMode.trackContainerTransform = nil
    AdvModeMode.cacheRotateSnapValue = nil
    AdvModeMode.isRotating = false
    api.world.GetWorldAPIs().gamevolatileconfig:SetRotationSnapEnabled(AdvModeMode.cacheRotateSnapValue)
end

--- Advances the adv mode mode
--- If return true, a new point is needed.
---@param dt any
---@param tMouseInput any
---@param tGamepadAxisInput any
---@return boolean shouldRefreshTrack Whether the track should be refreshed.
function AdvModeMode.Advance(dt, tMouseInput, tGamepadAxisInput)
    if AdvModeMode.lastTransform == nil or AdvModeMode.gizmo == nil then
        return false
    end

    AdvModeMode.gizmo:Step(tMouseInput, tGamepadAxisInput)

    -- If not started, we should stop.
    if not AdvModeMode.gizmo:IsStarted() then
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
    if AdvModeMode.gizmo == nil then
        return
    end
    AdvModeMode.gizmo:ToggleWorldSpaceLocalSpace()
end

function AdvModeMode.SetTransformMode(isRotation)
    if AdvModeMode.gizmo == nil then
        return
    end

    AdvModeMode.gizmo:Stop()
    if isRotation then
        AdvModeMode.gizmo:Start3AxisRotation(
            AdvModeMode.lastTransform,
            AdvModeMode.lastTransform:GetPos(),
            true,
            true,
            ---@diagnostic disable-next-line: redundant-parameter
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

function AdvModeMode.StaticBuildEndPoint_Hook(originalMethod, startT, tData)
    local original = originalMethod(startT, tData)

    -- Leave if no gizmo
    if AdvModeMode.gizmo == nil then
        return originalMethod(startT, tData)
    end

    -- Set last transform first.
    if AdvModeMode.lastTransform == nil then
        AdvModeMode.lastTransform = AdvModeMode.trackContainerTransform:ToWorld(startT:GetTransformQ())
        AdvModeMode.SetTransformMode(AdvModeMode.isRotating)
    end

    -- Leave if not started yet
    if not AdvModeMode.gizmo:IsStarted() then
        return original
    end

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
