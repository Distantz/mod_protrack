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

local Vector3 = require("Vector3")
local Quaternion = require("Quaternion")
local Utils = require("protrack.utils")
local Datastore = require("protrack.datastore")
local logger = require("forgeutils.logger").Get("FvdMode")
local mathUtils = require("Common.mathUtils")

--/ Main class definition
---@class FvdMode
local FvdMode = {}
FvdMode.forceLockVertG = 0
FvdMode.forceLockLatG = 0
FvdMode.line = nil
FvdMode.g = 9.81
FvdMode.gravity = Vector3:new(0, -1, 0)

---@class FvdPoint
---@field pos any Coaster-space position.
---@field rot any Coaster-space orientation.
---@field velo number Velocity.
---@field heartVelo number Heartline velocity.
---@field heartDistance number Heartline distance travelled, in M.

function FvdMode.EndEdit()
    if (FvdMode.line) then
        FvdMode.line:ClearPoints()
    end
end

---Returns a new point
---@param position any Coaster-space position.
---@param rotation any Coaster-space orientation.
---@param velocity number Velocity.
---@param heartlineVelocity number Heartline velocity.
---@param heartlineDistance number Centerline distance travelled, in M.
---@return FvdPoint point Point
function FvdMode.GetPoint(position, rotation, velocity, heartlineVelocity, heartlineDistance)
    return {
        pos = position,
        rot = rotation,
        velo = velocity,
        heartVelo = heartlineVelocity,
        heartDistance = heartlineDistance
    }
end

--- Steps a point forward in time by timeStep
---@param lastPoint FvdPoint The last point to build off
---@param userG any User acceleration desired in Vector3 form, in G.
---@param rollDelta number The roll delta to use while stepping. In rads / m.
---@param heartlineOffset number The heartline offset in M.
---@param timeStep number The timestep to use
function FvdMode.StepPoint(lastPoint, userG, rollDelta, heartlineOffset, timeStep)
    ---
    --- Just want to shout out the implementation I used as a reference here:
    --- Large shoutout to IndividualKex on GitHub:
    --- https://github.com/IndividualKex/KexEdit
    --- Which itself is a heavily referenced implementation from OpenFVD by altlenny:
    --- https://github.com/altlenny/openFVD
    --- We build on the shoulders of giants in the coaster community. Thank you for your hard work.
    ---

    local prevVertDir = lastPoint.rot:GetU()
    local prevLatDir = lastPoint.rot:GetR()

    local forceVec =
        userG:GetX() * prevLatDir
        + userG:GetY() * prevVertDir
        + FvdMode.gravity

    local vertAccel = -Vector3.Dot(forceVec, prevVertDir) * FvdMode.g
    local latAccel = -Vector3.Dot(forceVec, prevLatDir) * FvdMode.g
    local frwAccel = Vector3.Dot(forceVec, lastPoint.rot:GetF()) * FvdMode.g

    local latQuat = Quaternion.FromAxisAngle(prevVertDir, (-latAccel / lastPoint.heartVelo) / (1.0 / timeStep))

    local newForward = Utils.MultQuaternionVector(
        Utils.MultQuaternion(
            Quaternion.FromAxisAngle(prevLatDir, (vertAccel / lastPoint.heartVelo) / (1.0 / timeStep)),
            latQuat
        ),
        lastPoint.rot:GetF()
    )

    local newRight = Utils.MultQuaternionVector(latQuat, lastPoint.rot:GetR())
    local newUp = Vector3.Cross(newForward, newRight)

    local halfVeloStep = (lastPoint.velo * 0.5 * timeStep)

    local newPosition =
        lastPoint.pos + newForward * halfVeloStep
        + lastPoint.rot:GetF() * halfVeloStep
        + (lastPoint.pos - lastPoint.rot:GetU() * heartlineOffset)
        - (lastPoint.pos - newUp * heartlineOffset)

    local distTravelled = Vector3.Length(newPosition - lastPoint.pos)
    local rollAngle = distTravelled * rollDelta

    local rollQuat = Quaternion.FromAxisAngle(newForward, rollAngle)
    local rolledRight = (Utils.MultQuaternionVector(rollQuat, newRight)):Normalised()

    local heartlineVelocity = distTravelled / timeStep
    local nextVelocity = lastPoint.velo + (frwAccel * timeStep)
    if mathUtils.ApproxEquals(heartlineVelocity, 0) then
        heartlineVelocity = lastPoint.velo
    end

    local pt = FvdMode.GetPoint(
        newPosition,
        Quaternion.FromFR(newForward, rolledRight),
        nextVelocity,
        heartlineVelocity,
        distTravelled + lastPoint.heartDistance
    )

    return pt
end

function FvdMode.StaticBuildEndPoint_Hook(originalMethod, startT, tData)
    if not Datastore.HasData() or Vector3.Length(startT:GetPos() - Datastore.datapoints[#Datastore.datapoints].measurements[1].transform:GetPos()) > 0.02 then
        return originalMethod(startT, tData)
    end

    local userAccel = Vector3:new(FvdMode.forceLockLatG, FvdMode.forceLockVertG, 0) -- local-space target accel

    logger:Info("Using acceleration: " .. global.tostring(userAccel))

    local lastDatapoint = Datastore.datapoints[#Datastore.datapoints]
    local heartline = Datastore.heartlineOffset:GetY()

    -- Get last point
    local point = FvdMode.GetPoint(
        lastDatapoint.transform:GetPos() + lastDatapoint.transform:GetOr():GetU() * heartline,
        lastDatapoint.transform:GetOr(),
        lastDatapoint.speed,
        lastDatapoint.speed,
        0
    )

    local dt = 0.01

    local rollDeltaPerM = (tData.nBank - startT:GetBank()) / tData.nLength
    local iter = 0

    local tPoints = {}
    while point.heartDistance < tData.nLength and iter < 8192 do
        tPoints[#tPoints + 1] = Datastore.trackEntityTransform:ToWorldPos(point.pos)

        -- Get delta based on the last velocity
        point = FvdMode.StepPoint(
            point,
            userAccel,
            rollDeltaPerM,
            Datastore.heartlineOffset:GetY(),
            dt
        )
        iter = iter + 1
    end

    local distanceOvershoot = point.heartDistance - tData.nLength

    point.rot = Utils.MultQuaternion(
        point.rot,
        Quaternion.FromAxisAngle(Vector3.ZAxis, -rollDeltaPerM * distanceOvershoot)
    )

    tPoints[#tPoints + 1] = Datastore.trackEntityTransform:ToWorldPos(point.pos)
    FvdMode.line:SetPoints(tPoints)
    FvdMode.line:DrawPoints()

    return api.track.CreateJoinPoint(
        point.pos - point.rot:GetU() * heartline,
        point.rot:ToYawPitchRoll(),
        0
    )
end

return FvdMode
