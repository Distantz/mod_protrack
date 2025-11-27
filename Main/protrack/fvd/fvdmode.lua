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
local logger = require("forgeutils.logger").Get("FvdMode")
local ForceOverlay = require("protrack.ui.forceoverlay")
local table = require("common.tableplus")
local mathUtils = require("Common.mathUtils")
local UnitConversion = require("Helpers.UnitConversion")
require("forgeutils.logger").GLOBAL_LEVEL = "INFO"

--/ Main class definition
---@class FvdMode
local FvdMode = {}
FvdMode.active = true
FvdMode.posG = 2.5
FvdMode.latG = 0

function FvdMode:StartFvdMode(trackEditMode)
    self.active = true
end

function FvdMode:EndFvdMode()
    self.active = false
end

function FvdMode.StaticBuildEndPoint_Hook(originalMethod, startT, tData)
    if not FvdMode.active then
        return originalMethod(startT, tData)
    end

    if not Datastore.HasData() or Vector3.Length(startT:GetPos() - Datastore.tDatapoints[#Datastore.tDatapoints].transform:GetPos()) > 0.02 then
        logger:Info("FVD mode enabled but skipped due to a lack of Protrack data.")
        return originalMethod(startT, tData)
    end

    local startRoll = startT:GetBank()
    local gravity = Vector3:new(0, 1, 0)
    local userAccel = Vector3:new(FvdMode.latG, FvdMode.posG, 0)

    logger:Info("Using acceleration: " .. global.tostring(userAccel))

    local lastDatapoint = Datastore.tDatapoints[#Datastore.tDatapoints]
    local lastVelocity = lastDatapoint.speed * lastDatapoint.transform:GetF()
    local lastPoint = lastDatapoint.transform:GetPos() + lastDatapoint.transform:ToWorldDir(Datastore.heartlineOffset)
    local lastTransform = TransformQ.FromOrPos(lastDatapoint.transform:GetOr(), lastDatapoint.transform:GetPos())
    local accumArcLength = 0

    local dt = 0.01

    logger:Info("Protrack data is current, fvd mode can continue.")
    logger:Info("Doing steps...")

    while accumArcLength < tData.nLength do
        local worldAcceleration = (lastTransform:ToWorldDir(userAccel) - gravity) * 9.81

        local nextVelocity = lastVelocity + worldAcceleration * dt
        local nextPt = lastPoint + nextVelocity * dt

        accumArcLength = accumArcLength + Vector3.Length(nextPt - lastPoint)
        lastVelocity = nextVelocity
        lastPoint = nextPt

        local nextRoll = mathUtils.Lerp(startRoll, tData.nBank, accumArcLength / tData.nLength)
        local ypr = CameraUtils.YPRFromDir(lastVelocity:Normalised()):WithZ(nextRoll)
        lastTransform = lastTransform:WithPos(nextPt):WithOr(Quaternion.FromYawPitchRoll(ypr))
    end

    logger:Info("Done.")

    local finalPt = lastTransform:GetPos() - lastTransform:ToWorldDir(Datastore.heartlineOffset)
    local finalYpr = lastTransform:GetOr():ToYawPitchRoll()

    return api.track.CreateJoinPoint(
        finalPt,
        finalYpr,
        0
    )
end

return FvdMode
