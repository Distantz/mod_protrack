local global = _G
---@type Api
---@diagnostic disable-next-line: undefined-field
local api = global.api
local pairs = global.pairs
local require = global.require
local logger = require("forgeutils.logger").Get("ProTrackDatastore", "INFO")
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

---@class IndexData
---@field fromIdx integer The from index
---@field toIdx integer The to index
---@field fractional number The fractional (0 - 1) between from and to

--- Returns time data from a float index.
---@param floatIndex number The float index (0 to n)
---@return IndexData timeData
function Datastore.GetIndexDataFromFloatIndex(floatIndex)
    local numPts = #Datastore.datapoints
    local floor = global.math.floor(floatIndex)
    local fractionalLerp = floatIndex - floor

    local fromIdx = global.math.min(floor + 1, numPts)
    local toIdx = global.math.min(fromIdx + 1, numPts)

    ---@type IndexData
    return {
        fromIdx = fromIdx,
        toIdx = toIdx,
        fractional = fractionalLerp
    }
end

--- Samples a datapoint.
--- Will interpolate between datapoints between float indexes.
---@param time IndexData
---@param offsetId integer The offset id.
---@return TrackMeasurement | nil
function Datastore.GetInterpolatedTrackMeasurementAtIndexData(time, offsetId)
    if not Datastore.HasData() then
        logger:Error("GetInterpolatedTrackMeasurementAtTime requires datastore to have data! See Datastore.HasData().")
        return nil
    end

    -- Get points
    local fromPt = Datastore.datapoints[time.fromIdx].measurements[offsetId]
    local toPt = Datastore.datapoints[time.toIdx].measurements[offsetId]

    -- Construct new PT with slerping.
    local lerpPos = mathUtils.Lerp(
        fromPt.transform:GetPos(),
        toPt.transform:GetPos(),
        time.fractional
    )
    local lerpOr = Quaternion.SLerp(
        fromPt.transform:GetOr(),
        toPt.transform:GetOr(),
        time.fractional
    )
    local lerpG = mathUtils.Lerp(
        fromPt.g,
        toPt.g,
        time.fractional
    )

    ---@type TrackMeasurement
    return {
        g = lerpG,
        transform = TransformQ.FromOrPos(lerpOr, lerpPos),
    }
end

--- Samples a velocity.
--- Will interpolate between datapoints between float indexes.
---@param time IndexData
---@return number velocity
function Datastore.GetInterpolatedSpeedAtIndexData(time)
    return mathUtils.Lerp(
        Datastore.datapoints[time.fromIdx].originVelocity,
        Datastore.datapoints[time.toIdx].originVelocity,
        time.fractional
    )
end

--- Samples a datapoint at a float index.
--- Will interpolate between datapoints between float indexes.
---@param floatIndex number
---@return TrainMeasurement | nil
function Datastore.SampleDatasetAtFloatIndex(floatIndex)
    if not Datastore.HasData() then
        logger:Error("SampleDatasetAtFloatIndex requires datastore to have data! See Datastore.HasData().")
        return nil
    end

    local indexData = Datastore.GetIndexDataFromFloatIndex(floatIndex)
    local fromPt = Datastore.datapoints[indexData.fromIdx]

    local trackMeasurements = {}
    for i, _ in global.ipairs(fromPt.measurements) do
        trackMeasurements[i] = Datastore.GetInterpolatedTrackMeasurementAtIndexData(indexData, i)
    end

    ---@type TrainMeasurement
    return {
        originVelocity = Datastore.GetInterpolatedSpeedAtIndexData(indexData),
        measurements = trackMeasurements
    }
end

--- Samples a datapoint at a time.
--- Will interpolate between datapoints between float indexes.
---@param time number
---@return TrainMeasurement | nil
function Datastore.SampleDatapointAtTime(time)
    return Datastore.SampleDatapointAtFloatIndex(Datastore.GetFloatIndexForTime(time))
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
