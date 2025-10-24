local global = _G
---@type Api
local api = global.api
local pairs = global.pairs
local require = global.require
local logger = require("forgeutils.logger").Get("ProTrackUtil")
local Vector3 = require("Vector3")
local TransformQ = require("TransformQ")
local Quaternion = require("Quaternion")

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

function Utils.TrackTransformToTransformQ(trackTransform)
    local transform = trackTransform:GetLocationTransform()
    local rotation = Quaternion.FromYawPitchRoll(transform:GetRotation():ToYawPitchRoll())
    return TransformQ.FromOrPos(rotation, transform:GetPos())
end

function Utils.WalkTrack(trackLoc, initSpeed, timestep)
    -- Use a different walker,
    -- to prevent polluting the other one.
    local copyLocation = trackLoc:CopyLocation()

    -- God save our souls
    local curSpeed = initSpeed
    local dataPts = {}
    local minWalkDist = 0.01
    local gravity = 9.81
    local friction = 0.974 ^ timestep
    local lastTransform = trackLoc:GetLocationTransform()
    local lastPosition = lastTransform:GetPos()
    local lastVelo = lastTransform:GetF() * curSpeed

    while (curSpeed > 0) do
        local distStepForward = curSpeed * timestep
        -- logger:Info("Stepping with speed: " .. global.tostring(curSpeed))

        copyLocation:MoveLocation(distStepForward)
        local transform = Utils.TrackTransformToTransformQ(copyLocation)

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

    return dataPts
end

-- printTable: prints any Lua value (table, userdata, primitive)
-- All standard library calls are prefixed with `global`.
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
