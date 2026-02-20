local global             = _G
local require            = global.require
local mathUtils          = require("Common.mathUtils")
local Quaternion         = require("Quaternion")
local TransformQ         = require("TransformQ")
local logger             = require("forgeutils.logger").Get("ProTrackDatastore", "INFO")

---@class protrack.data.RunDataContainer
local RunDataContainer   = {}
RunDataContainer.__index = RunDataContainer

---Creates a run data container
---@return protrack.data.RunDataContainer
function RunDataContainer.new()
    local self = global.setmetatable({}, RunDataContainer)
    self.trainMeasurements = {}
    self.cachedTrainMeasurement = nil
    self.cachedTrainMeasurementTime = nil
    self.simulationDelta = nil
    return self
end

---Sets the data within the container
---@param data TrainMeasurement[] The data
---@param simulationDelta number The simulation delta in seconds
function RunDataContainer:SetData(data, simulationDelta)
    self.trainMeasurements = data
    self.cachedTrainMeasurement = nil
    self.cachedTrainMeasurementTime = nil
    self.simulationDelta = simulationDelta
end

---Clears the data within the container
function RunDataContainer:ClearData()
    self.trainMeasurements = {}
    self.cachedTrainMeasurement = nil
    self.cachedTrainMeasurementTime = nil
end

---Returns whether the container has any data for display
---@return boolean
function RunDataContainer:HasData()
    return self.trainMeasurements ~= nil and #self.trainMeasurements >= 2
end

---Returns the timestamp for a float index
---@param floatIndex number
---@return number
function RunDataContainer:GetTimeForFloatIndex(floatIndex)
    return floatIndex * self.simulationDelta
end

---Returns the float index for a time
---@param time number
---@return number
function RunDataContainer:GetFloatIndexForTime(time)
    return time / self.simulationDelta
end

---Returns the floor of the float index for a time
---@param time number
---@return integer
function RunDataContainer:GetFloorIndexForTime(time)
    return global.math.floor(self:GetFloatIndexForTime(time))
end

---Returns index data from a float index
---@param floatIndex number
---@return IndexData
function RunDataContainer:GetIndexDataFromFloatIndex(floatIndex)
    local numPts = #self.trainMeasurements
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

---Returns an interpolated track measurement at the given index data
---@param indexData IndexData
---@param offsetId integer
---@return TrackMeasurement | nil
function RunDataContainer:GetInterpolatedTrackMeasurementAtIndexData(indexData, offsetId)
    if not self:HasData() then
        logger:Error("GetInterpolatedTrackMeasurementAtIndexData requires container to have data! See HasData().")
        return nil
    end

    local fromPt  = self.trainMeasurements[indexData.fromIdx].measurements[offsetId]
    local toPt    = self.trainMeasurements[indexData.toIdx].measurements[offsetId]

    local lerpPos = mathUtils.Lerp(
        fromPt.transform:GetPos(),
        toPt.transform:GetPos(),
        indexData.fractional
    )
    local lerpOr  = Quaternion.SLerp(
        fromPt.transform:GetOr(),
        toPt.transform:GetOr(),
        indexData.fractional
    )
    local lerpG   = mathUtils.Lerp(
        fromPt.g,
        toPt.g,
        indexData.fractional
    )

    ---@type TrackMeasurement
    return {
        g         = lerpG,
        transform = TransformQ.FromOrPos(lerpOr, lerpPos),
    }
end

---Returns an interpolated speed at the given index data
---@param indexData IndexData
---@return number
function RunDataContainer:GetInterpolatedSpeedAtIndexData(indexData)
    return mathUtils.Lerp(
        self.trainMeasurements[indexData.fromIdx].originVelocity,
        self.trainMeasurements[indexData.toIdx].originVelocity,
        indexData.fractional
    )
end

---Samples the dataset at a float index
---@param floatIndex number
---@return TrainMeasurement | nil
function RunDataContainer:SampleDatasetAtFloatIndex(floatIndex)
    if not self:HasData() then
        logger:Error("SampleDatasetAtFloatIndex requires container to have data! See HasData().")
        return nil
    end

    -- Use cache if possible. Prevents a lot of lookup and calculation.
    if self.cachedTrainMeasurementTime == floatIndex and self.cachedTrainMeasurement then
        return self.cachedTrainMeasurement
    end

    local indexData = self:GetIndexDataFromFloatIndex(floatIndex)
    local fromPt = self.trainMeasurements[indexData.fromIdx]

    local trackMeasurements = {}
    for i, _ in global.ipairs(fromPt.measurements) do
        trackMeasurements[i] = self:GetInterpolatedTrackMeasurementAtIndexData(indexData, i)
    end

    ---@type TrainMeasurement
    self.cachedTrainMeasurement = {
        originVelocity = self:GetInterpolatedSpeedAtIndexData(indexData),
        measurements   = trackMeasurements
    }
    self.cachedTrainMeasurementTime = floatIndex

    return self.cachedTrainMeasurement
end

---Samples the dataset at a time
---@param time number
---@return TrainMeasurement | nil
function RunDataContainer:SampleDatasetAtTime(time)
    return self:SampleDatasetAtFloatIndex(self:GetFloatIndexForTime(time))
end

---Returns the total time length of the container
---@return number
function RunDataContainer:GetTimeLength()
    return #self.trainMeasurements * self.simulationDelta
end

---Returns the number of datapoints in the container
---@return integer
function RunDataContainer:GetNumDatapoints()
    return #self.trainMeasurements
end

return RunDataContainer
