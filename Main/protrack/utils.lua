local global = _G
---@type Api
local api = global.api
local pairs = global.pairs
local require = global.require
local logger = require("forgeutils.logger").Get("ProTrackUtil")
local Vector3 = require("Vector3")

local Utils = {}

function Utils.GetFirstCarTrackLocAndSpeed(rideID)
    local worldAPI = api.world.GetWorldAPIs()

    local tTrains = worldAPI.trackedrides:GetAllTrainsOnTrackedRide(rideID)

    if tTrains == nil or #tTrains < 1 then
        return nil, nil
    end

    local trainID = tTrains[1]
    if trainID ~= nil and trainID ~= 0 then
        local tCars = worldAPI.trackedrides:GetCarsInTrain(trainID)
        if tCars ~= nil then
            for _, nCar in ipairs(tCars) do
                if nCar ~= api.entity.NullEntityID and worldAPI.trackedrides:GetCarIsOnTrack(nCar) and worldAPI.trackedrides:GetCarTrackSpeed(nCar) ~= nil then
                    local speed = worldAPI.trackedrides:GetCarTrackSpeed(nCar)
                    local trackLocation = worldAPI.trackedrides:GetCarFrontTrackLocation_Display(nCar)
                    return trackLocation, speed
                end
            end
        end
    end

    return nil, nil
end

function Utils.WalkTrack(trackLoc, initSpeed, timestep)
    -- God save our souls
    local curSpeed = initSpeed
    local dataPts = {}
    local minWalkDist = 0.01
    local gravity = 9.81
    local lastTransform = trackLoc:GetLocationTransform()
    local lastPosition = lastTransform:GetPos()
    local lastVelo = lastTransform:GetF() * curSpeed

    while (curSpeed > 0) do
        local distStepForward = curSpeed * timestep
        -- logger:Info("Stepping with speed: " .. global.tostring(curSpeed))

        trackLoc:MoveLocation(distStepForward)
        local transform = trackLoc:GetLocationTransform()

        if transform == nil then
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
        curSpeed = curSpeed + slopeAccel * timestep                                -- integrate over timestep

        -- Calculate local acceleration, which is the velocity induced acceleration + the gravity acceleration.
        local actualAccelWS = -((thisVelo - lastVelo) / timestep) - Vector3.YAxis * gravity
        local localAccelG = -transform:ToLocalDir(actualAccelWS) / gravity

        dataPts[#dataPts + 1] = localAccelG
        lastPosition = thisPosition
        lastVelo = thisVelo

        -- logger:Info("Reloop.")
    end

    return dataPts
end

return Utils
