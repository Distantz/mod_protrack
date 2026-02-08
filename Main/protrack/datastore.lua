local global = _G
---@type Api
---@diagnostic disable-next-line: undefined-field
local api = global.api
local pairs = global.pairs
local require = global.require
local logger = require("forgeutils.logger").Get("ProTrackDatastore")
local mathUtils = require("Common.mathUtils")
local Quaternion = require("Quaternion")
local Vector3 = require("Vector3")
local TransformQ = require("TransformQ")

local Datastore = {}
Datastore.tSimulationDelta = (1.0 / 30.0)

---@class TrackMeasurement
---@field g table
---@field transform table

---@class TrainMeasurement
---@field originVelocity number The main (origin) velocity.
---@field measurements TrackMeasurement[] Measurements.

---@type TrainMeasurement[]|nil
Datastore.datapoints = nil
Datastore.trackEntityTransform = nil
Datastore.trackWalkerOrigin = nil
Datastore.heartlineOffset = Vector3.Zero

--- Returns whether the datastore has any data for display
---@return boolean
function Datastore.HasData()
    return Datastore.datapoints ~= nil and #Datastore.datapoints >= 2
end

--- Returns the timestamp for an index, which can be fractional.
--- Indexes start at 1 and increase to the number of datapoints
---@param floatIndex number
---@return number
function Datastore.GetTimeForFloatIndex(floatIndex)
    return floatIndex * Datastore.tSimulationDelta
end

--- Returns the float index for a time, which can be fractional.
--- Indexes start at 1 and increase to the number of datapoints.
---@param time number
---@return number
function Datastore.GetFloatIndexForTime(time)
    return time / Datastore.tSimulationDelta
end

--- Returns the floor of the float index for a time.
--- Indexes start at 1 and increase to the number of datapoints.
---@param time number
---@return integer
function Datastore.GetFloorIndexForTime(time)
    return global.math.floor(Datastore.GetFloatIndexForTime(time))
end

--- Samples a datapoint at a float index.
--- Will interpolate between datapoints between float indexes.
---@param floatIndex number
---@param offsetId integer The offset id.
---@return TrackMeasurement|nil
function Datastore.SampleDatapointAtFloatIndex(floatIndex, offsetId)
    if not Datastore.HasData() then
        logger:Error("SampleDatapointAtTime requires datastore to have data! See Datastore.HasData().")
        return nil
    end

    local numPts = #Datastore.datapoints
    local floor = global.math.floor(floatIndex)
    local fractionalLerp = floatIndex - floor

    local fromIdx = global.math.min(floor + 1, numPts)
    local toIdx = global.math.min(fromIdx + 1, numPts)

    -- Get points
    local fromPt = Datastore.datapoints[fromIdx].measurements[offsetId]
    local toPt = Datastore.datapoints[toIdx].measurements[offsetId]

    -- Construct new PT with slerping.

    local lerpPos = mathUtils.Lerp(
        fromPt.transform:GetPos(),
        toPt.transform:GetPos(),
        fractionalLerp
    )
    local lerpOr = Quaternion.SLerp(
        fromPt.transform:GetOr(),
        toPt.transform:GetOr(),
        fractionalLerp
    )
    local lerpG = mathUtils.Lerp(
        fromPt.g,
        toPt.g,
        fractionalLerp
    )
    local lerpSpeed = mathUtils.Lerp(
        Datastore.datapoints[fromIdx].originVelocity,
        Datastore.datapoints[toIdx].originVelocity,
        fractionalLerp
    )

    return {
        g = lerpG,
        transform = TransformQ.FromOrPos(lerpOr, lerpPos),
        speed = lerpSpeed
    }
end

--- Samples a datapoint at a time.
--- Will interpolate between datapoints between float indexes.
---@param time number
---@param offsetId integer The offset id.
---@return TrackMeasurement|nil
function Datastore.SampleDatapointAtTime(time, offsetId)
    return Datastore.SampleDatapointAtFloatIndex(Datastore.GetFloatIndexForTime(time), offsetId)
end

---Returns the total time length of the datastore
---@return number
function Datastore.GetTimeLength()
    return #Datastore.datapoints * Datastore.tSimulationDelta
end

---Returns the number of datapoints in the datastore
---@return integer
function Datastore.GetNumDatapoints()
    return #Datastore.datapoints
end

return Datastore
