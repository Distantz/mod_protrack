local global = _G
---@type Api
local api = global.api
local pairs = global.pairs
local require = global.require
local logger = require("forgeutils.logger").Get("ProTrackUtil")
local Vector3 = require("Vector3")
local TransformQ = require("TransformQ")
local Quaternion = require("Quaternion")

---@class TrackOrigin
---@field transform any
---@field gforce any
---@field speed any

local Utils = {}

--- Returns the current track origin data of a ride.
---@param rideID table The entity ID of the ride.
---@return TrackOrigin?
function Utils.GetFirstCarData(rideID)
    local worldAPI = api.world.GetWorldAPIs()

    local tTrains = worldAPI.trackedrides:GetAllTrainsOnTrackedRide(rideID)

    if tTrains == nil or #tTrains < 1 then
        return nil
    end

    local trainID = tTrains[1]
    if trainID ~= nil and trainID ~= 0 then
        local tCars = worldAPI.trackedrides:GetCarsInTrain(trainID)
        if tCars ~= nil then
            for _, nCar in ipairs(tCars) do
                if nCar ~= api.entity.NullEntityID and worldAPI.trackedrides:GetCarIsOnTrack(nCar) and worldAPI.trackedrides:GetCarTrackSpeed(nCar) ~= nil then
                    local speed = worldAPI.trackedrides:GetCarTrackSpeed(nCar)
                    local gforce = worldAPI.trackedrides:GetCarLocalAcceleration(nCar)
                    local trackLocation = worldAPI.trackedrides:GetCarFrontTrackLocation_Display(nCar)
                    return {
                        transform = trackLocation,
                        speed = speed,
                        gforce = gforce
                    }
                end
            end
        end
    end

    return nil
end

--- Converts a TrackTransform (from the TrackLib) to a TransformQ.
---@param trackTransform any
---@return any
function Utils.TrackTransformToTransformQ(trackTransform)
    local transform = trackTransform:GetLocationTransform()
    local rotation = Quaternion.FromYawPitchRoll(transform:GetRotation():ToYawPitchRoll())
    return TransformQ.FromOrPos(rotation, transform:GetPos())
end

--- Walks the track. Returns datapoints.
---@param trackOriginData TrackOrigin The origin to walk from.
---@param timestep number The timestep of the simulation.
---@return TrackMeasurement[]?
function Utils.WalkTrack(trackOriginData, timestep)
    if trackOriginData == nil then
        logger:Info("Exit! Starting point is invalid. Origin is nil.")
        return nil
    end

    -- Use a different walker,
    -- to prevent polluting the other one.
    local copyLocation = trackOriginData.transform:CopyLocation()
    if copyLocation == nil then
        logger:Info("Exit! Starting point is invalid. Copy of track transform failed.")
        return nil
    end

    local lastTransform = copyLocation:GetLocationTransform()
    if lastTransform == nil then
        logger:Info("Exit! Starting point is invalid. GetLocationTransform failed.")
        return nil
    end

    if trackOriginData.speed == nil then
        logger:Info("Exit! Starting point is invalid. Initial speed was nil.")
        return nil
    end

    if trackOriginData.gforce == nil then
        logger:Info("Exit! Starting point is invalid. Initial GForce was nil.")
        return nil
    end

    -- God save our souls
    local curSpeed = trackOriginData.speed
    local minWalkDist = 0.01
    local gravity = 9.81
    local friction = 0.974 ^ timestep
    local lastPosition = lastTransform:GetPos()
    local lastVelo = lastTransform:GetF() * curSpeed

    local dataPts = {}

    do
        local lastTransformQ = Utils.TrackTransformToTransformQ(copyLocation)
        dataPts[1] = {
            g = (trackOriginData.gforce) / gravity + lastTransformQ:ToLocalDir(Vector3.YAxis),
            transform = lastTransformQ,
        }
    end

    while (curSpeed > 0) do
        local distStepForward = curSpeed * timestep

        copyLocation:MoveLocation(distStepForward)
        local transform = Utils.TrackTransformToTransformQ(copyLocation)

        if lastTransform == nil or transform == nil then
            logger:Info("Exit! Transform was null")
            break
        end

        local thisPosition = transform:GetPos()
        local thisVelo = transform:GetF() * curSpeed
        local posDifference = thisPosition - lastPosition
        if Vector3.Length(posDifference) < minWalkDist then
            logger:Info("Exit! Didn't walk enough!")
            break
        end

        -- Calculate speed
        local slopeAccel = gravity * Vector3.Dot(-Vector3.YAxis, transform:GetF()) -- m/s²
        curSpeed = (curSpeed + slopeAccel * timestep) * friction                   -- integrate over timestep

        -- Calculate local acceleration, which is the velocity induced acceleration + the gravity acceleration.
        local actualAccelWS = -((thisVelo - lastVelo) / timestep) - Vector3.YAxis * gravity
        local localAccelG = -transform:ToLocalDir(actualAccelWS) / gravity

        dataPts[#dataPts + 1] = {
            g = localAccelG,
            transform = transform,
        }
        lastPosition = thisPosition
        lastVelo = thisVelo

        -- logger:Info("Reloop.")
    end
    logger:Info("Finished walk, with " .. global.tostring(#dataPts) .. " points.")

    return dataPts
end

--- Prints any Lua table.
---@param value any
function Utils.PrintTable(value)
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

return Utils
