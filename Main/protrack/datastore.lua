local global = _G
---@type Api
local api = global.api
local pairs = global.pairs
local require = global.require
local logger = require("forgeutils.logger").Get("ProTrackDatastore")
local mathUtils = require("Common.mathUtils")
local Quaternion = require("Quaternion")
local TransformQ = require("TransformQ")

local Datastore = {}
Datastore.tSimulationDelta = 0.1

Datastore.tDatapoints = {}
Datastore.trackEntityTransform = nil
Datastore.trackWalkerOrigin = nil

function Datastore.HasData()
    return Datastore.tDatapoints ~= nil and #Datastore.tDatapoints >= 2
end

function Datastore.SampleDatapointAtTime(time)
    if not Datastore.HasData() then
        logger:Error("SampleDatapointAtTime requires datastore to have data! See Datastore.HasData().")
        return nil
    end

    -- clamp time
    if (time < 0) then
        time = 0
    end

    local numPts = #Datastore.tDatapoints

    -- Convert into 0 -> 1 range
    local floatIndex = time / Datastore.tSimulationDelta

    local floor = global.math.floor(floatIndex)
    local fractionalLerp = floatIndex - floor

    local fromIdx = global.math.min(floor + 1, numPts)
    local toIdx = global.math.min(fromIdx + 1, numPts)

    -- Get points
    local fromPt = Datastore.tDatapoints[fromIdx]
    local toPt = Datastore.tDatapoints[toIdx]

    -- Construct new PT with slerping.

    local lerpPos = mathUtils.Lerp(fromPt.transform:GetPos(), toPt.transform:GetPos(), fractionalLerp)
    local lerpOr = Quaternion.SLerp(fromPt.transform:GetOr(), toPt.transform:GetOr(), fractionalLerp)
    local lerpG = mathUtils.Lerp(fromPt.g, toPt.g, fractionalLerp)

    return {
        g = lerpG,
        transform = TransformQ.FromOrPos(lerpOr, lerpPos)
    }
end

function Datastore.GetTimeLength()
    return #Datastore.tDatapoints * Datastore.tSimulationDelta
end

return Datastore
