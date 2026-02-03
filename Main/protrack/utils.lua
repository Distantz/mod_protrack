local global                    = _G
---@type Api
---@diagnostic disable-next-line: undefined-field
local api                       = global.api
local pairs                     = global.pairs
local require                   = global.require
local logger                    = require("forgeutils.logger").Get("ProTrackUtil", "INFO")
local Vector3                   = require("Vector3")
local TransformQ                = require("TransformQ")
local Quaternion                = require("Quaternion")

---@class TrackOrigin
---@field transform any The transform of the middle of the train.
---@field gforce any The local G Force of the middle of the train.
---@field speed number The speed of the train at the front bogie.
---@field trainLength number The train length in metres.
---@field camOffset any The local camera offset from the first bogie to the front bumper camera.

local Utils                     = {}
Utils.CAM_OFFSET_FORWARD_ADJUST = 0.75

---Returns a crude upper bound on train size
---@param worldApi WorldAPIs
---@param trainType string
---@param targetNumCars integer
---@return number
local function getUpperBoundOfTrainSize(worldApi, trainType, targetNumCars)
    local currentNumCars = 0
    local length = 0
    while (currentNumCars ~= targetNumCars) do
        currentNumCars = worldApi.trackedrides:LimitNumberOfCarsByTrainLength(trainType, targetNumCars, length)
        length = length + 5
    end
    return length
end


---Returns a reasonably accurate lower bound on train size
---@param worldApi WorldAPIs
---@param trainType string
---@param targetNumCars integer
---@param startingLength number
---@return number
local function getLowerBoundOfTrainSize(worldApi, trainType, targetNumCars, startingLength)
    local currentNumCars = targetNumCars
    local length = startingLength
    while (targetNumCars == currentNumCars) do
        length = length - 0.1
        currentNumCars = worldApi.trackedrides:LimitNumberOfCarsByTrainLength(trainType, currentNumCars, length)
    end
    return length
end

--- Returns the current track origin data of a ride.
---@param rideID table The entity ID of the ride.
---@return TrackOrigin?
function Utils.GetFirstCarData(rideID)
    local worldAPI = api.world.GetWorldAPIs()

    ---@diagnostic disable-next-line: undefined-field
    local tTrains = worldAPI.trackedrides:GetAllTrainsOnTrackedRide(rideID)
    if tTrains == nil or #tTrains < 1 then
        return nil
    end

    ---@diagnostic disable-next-line: param-type-mismatch
    local rideHolder = api.track.GetTrackHolder(rideID)

    local sTrainType = api.track.GetTrainType(rideHolder)
    local numTrainCars = api.track.GetNumCarsPerTrain(rideHolder)

    local upperBound = getUpperBoundOfTrainSize(worldAPI, sTrainType, numTrainCars)
    local lowerBound = getLowerBoundOfTrainSize(worldAPI, sTrainType, numTrainCars, upperBound)

    local stationUsableArea = api.track.GetMinAllowedUseableStationLength(rideHolder)
    local trainLength = lowerBound - stationUsableArea

    local trainID = tTrains[1]
    if trainID ~= nil and trainID ~= 0 then
        local tCars = worldAPI.trackedrides:GetCarsInTrain(trainID)
        if tCars ~= nil then
            -- Print for debugging
            local gForceAccum = Vector3.Zero
            local numCar = 0.0
            local speed = nil

            local trackTransforms = {}
            for _, nCar in ipairs(tCars) do
                ---@diagnostic disable-next-line: undefined-field
                if nCar ~= api.entity.NullEntityID and worldAPI.trackedrides:GetCarIsOnTrack(nCar) then
                    numCar = numCar + 1.0

                    -- get speed
                    if speed == nil and worldAPI.trackedrides:GetCarTrackSpeed(nCar) ~= nil then
                        speed = worldAPI.trackedrides:GetCarTrackSpeed(nCar)
                    end

                    -- Add track location
                    ---@diagnostic disable-next-line: param-type-mismatch, cast-local-type
                    trackTransforms[#trackTransforms + 1] = worldAPI.trackedrides:GetCarFrontTrackLocation_Display(nCar)
                    gForceAccum = worldAPI.trackedrides:GetCarLocalAcceleration(nCar)
                end
            end

            -- Protect if there are no transforms
            if #trackTransforms < 1 then
                return nil
            end

            local finGForce = gForceAccum / numCar

            local firstLocTrans = trackTransforms[1]:GetLocationTransform()
            if firstLocTrans == nil then
                return nil
            end

            -- Handle camera
            ---@diagnostic disable-next-line: param-type-mismatch
            local tAttachPoints = worldAPI.CameraAttachPoint:GetAllPointData(trainID, "TrackCarFrontBumperCamera")
            local localOffset = Vector3.Zero
            for _, tAttachData in pairs(tAttachPoints) do
                localOffset = api.transform.GetTransform(tAttachData.CameraAttachID):GetPos()
                if localOffset ~= nil then
                    goto continue
                end
            end
            ::continue::

            local moveBackward = (trainLength / 2.0) + Utils.CAM_OFFSET_FORWARD_ADJUST
            local clampedTrainLength = global.math.max(trainLength, Utils.CAM_OFFSET_FORWARD_ADJUST * 2)

            trackTransforms[1]:MoveLocation(-moveBackward)

            return {
                transform = trackTransforms[1],
                speed = speed,
                gforce = finGForce,
                camOffset = localOffset,
                trainLength = clampedTrainLength
            }
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

--- Returns the heartline position from a transform
---@param transform any
---@param localHeartline any
---@return any
function Utils.GetHeartlinePosition(transform, localHeartline)
    return transform:GetPos() + transform:ToWorldDir(localHeartline)
end

--- Determines if the track origin is valid
---@param trackOrigin TrackOrigin?
---@return boolean
function Utils.IsTrackOriginValid(trackOrigin)
    if trackOrigin == nil then
        return false
    end

    if trackOrigin.transform == nil then
        return false
    end
    if trackOrigin.camOffset == nil then
        return false
    end
    if trackOrigin.speed == nil then
        return false
    end
    if trackOrigin.gforce == nil then
        return false
    end
    if trackOrigin.transform:GetLocationTransform() == nil then
        return false
    end

    return true
end

--- Transforms a vector by a quaternion.
---@param q any The quaternion.
---@param v any The vector.
---@return any Vector The transformed vector.
function Utils.MultQuaternionVector(q, v)
    -- normalise quaternion
    q = q:Normalised()

    local qV = Vector3:new(q:GetX(), q:GetY(), q:GetZ())
    local qW = q:GetW()

    -- q * v (treat vector as quaternion with w = 0)
    local t = (qV * 2):Cross(v)
    local newV = v + (t * qW) + Vector3.Cross(qV, t)

    return Vector3:new(newV:GetX(), newV:GetY(), newV:GetZ())
end

--- Multiplies two quaternions.
---@param left any The lefthand side quaternion.
---@param right any The righthand side quaternion.
---@return any resultQuaternion The resulting quaternion.
function Utils.MultQuaternion(left, right)
    -- normalise
    left = left:Normalised()
    right = right:Normalised()

    local leftV = Vector3:new(left:GetX(), left:GetY(), left:GetZ())
    local rightV = Vector3:new(right:GetX(), right:GetY(), right:GetZ())
    local leftW = left:GetW()
    local rightW = right:GetW()

    local newW = (rightW * leftW) - Vector3.Dot(rightV, leftV)
    local newV = (rightW * leftV) + (leftW * rightV) + Vector3.Cross(leftV, rightV)
    return Quaternion.Identity:WithX(newV:GetX()):WithY(newV:GetY()):WithZ(newV:GetZ()):WithW(newW)
end

---@class TrackState
---@field heartlinePositionWs table The heartline position, in world space.
---@field heartlineVelocityWs table The heartline velocity, in world space.
---@field accelerationLs table The acceleration at the heartline, in local space.
---@field transformLs table The track transform of the state, in local space.

---@class TrainState
---@field originState TrackState The origin state.
---@field originVelocity number The origin velocity.
---@field followerStates {[number]: TrackState} The follower states.


---Converts a track state into a track measurement.
---@param trackState TrackState The track state
---@return TrackMeasurement
local function TrackStateToTrackMeasurement(trackState)
    ---@type TrackMeasurement
    return {
        g = trackState.accelerationLs,
        transform = trackState.transformLs
    }
end

---Converts a train state into a train measurement.
---@param trainState TrainState The train state
---@return TrainMeasurement
local function TrainStateToTrainMeasurement(trainState)
    local followerMeasurements = {}
    for followerDistance, followerState in global.pairs(trainState.followerStates) do
        followerMeasurements[followerDistance] = TrackStateToTrackMeasurement(followerState)
    end

    ---@type TrainMeasurement
    return {
        originMeasurement = TrackStateToTrackMeasurement(trainState.originState),
        originVelocity = trainState.originVelocity,
        followerMeasurements = followerMeasurements
    }
end

--- Returns the next heartline state
---@param lastState TrackState The last heartline state.
---@param newTrainOrigin any The new train origin.
---@param originOffset number The offset forward or backward from the origin.
---@param heartlineOffset any The heartline offset in local space.
---@param gravity number The gravity multiplier.
---@param timestep number The timestep.
---@return TrackState
local function GetNextTrackState(
    lastState,
    newTrainOrigin,
    originOffset,
    heartlineOffset,
    gravity,
    timestep
)
    -- Only move if not origin
    if (originOffset ~= 0) then
        newTrainOrigin:MoveLocation(originOffset)
    end

    local thisTransform = Utils.TrackTransformToTransformQ(newTrainOrigin)

    -- New heartline acceleration calc using finite difference method
    local thisHeartlinePosition = Utils.GetHeartlinePosition(thisTransform, heartlineOffset)
    local thisHeartlineVelocity = (thisHeartlinePosition - lastState.heartlinePositionWs) / timestep
    local actualAccelWS = -((thisHeartlineVelocity - lastState.heartlineVelocityWs) / timestep)
        - Vector3.YAxis * gravity

    -- Combined acceleration
    ---@diagnostic disable-next-line: assign-type-mismatch
    local thisAcceleration = -thisTransform:ToLocalDir(actualAccelWS) / gravity

    return {
        heartlinePositionWs = thisHeartlinePosition,
        heartlineVelocityWs = thisHeartlineVelocity,
        accelerationLs = thisAcceleration,
        transformLs = thisTransform
    }
end

--- Returns the next train state
---@param lastState TrainState The last train state.
---@param nextVelocity number The next velocity to use.
---@param trainOrigin any The new train origin.
---@param heartlineOffset any The heartline offset in local space.
---@param gravity number The gravity multiplier.
---@param timestep number The timestep.
---@return TrainState
local function StepTrainState(
    lastState,
    nextVelocity,
    trainOrigin,
    heartlineOffset,
    gravity,
    timestep
)
    -- Get next state
    local nextOriginState = GetNextTrackState(
        lastState.originState,
        trainOrigin,
        0,
        heartlineOffset,
        gravity,
        timestep
    )

    local nextFollowerOffsets = {}
    for followerDistance, lastFollowerState in global.pairs(lastState.followerStates) do
        nextFollowerOffsets[followerDistance] = GetNextTrackState(
            lastFollowerState,
            trainOrigin:CopyLocation(),
            followerDistance,
            heartlineOffset,
            gravity,
            timestep
        )
    end

    ---@type TrainState
    return {
        originState = nextOriginState,
        originVelocity = nextVelocity,
        followerStates = nextFollowerOffsets
    }
end

--- Returns a starting heartline state from initial data.
---@param trackOrigin table The track origin.
---@param startingVelocity number The starting velocity.
---@param startingAcceleration table The starting acceleration.
---@param originOffset number The offset forward or backward from the origin.
---@param heartlineOffset any The heartline offset.
local function GetStartingTrackState(
    trackOrigin,
    startingVelocity,
    startingAcceleration,
    originOffset,
    heartlineOffset
)
    if (originOffset ~= 0) then
        trackOrigin:MoveLocation(originOffset)
    end

    local thisTransform = Utils.TrackTransformToTransformQ(trackOrigin)

    ---@type TrackState
    return {
        accelerationLs = startingAcceleration,
        heartlinePositionWs = Utils.GetHeartlinePosition(thisTransform, heartlineOffset),
        heartlineVelocityWs = thisTransform:GetF() * startingVelocity,
        transformLs = thisTransform
    }
end

--- Returns a starting heartline state from initial data.
---@param trackOriginData TrackOrigin The track origin.
---@param heartlineOffset any The heartline offset.
---@return TrainState state The beginning train state.
local function GetStartingTrainState(
    trackOriginData,
    heartlineOffset
)
    -- Get next state
    local originState = GetStartingTrackState(
        trackOriginData.transform,
        trackOriginData.speed,
        trackOriginData.gforce,
        0,
        heartlineOffset
    )

    -- Decide what follower distances are picked for measurement here.
    local halfLength = trackOriginData.trainLength / 2.0
    local distances = {
        halfLength,
        -halfLength
    }

    local followerStates = {}
    for _, followerDistance in global.ipairs(distances) do
        followerStates[followerDistance] = GetStartingTrackState(
            trackOriginData.transform:CopyLocation(),
            trackOriginData.speed,
            trackOriginData.gforce,
            followerDistance,
            heartlineOffset
        )
    end

    ---@type TrainState
    return {
        originState = originState,
        followerStates = followerStates,
        originVelocity = trackOriginData.speed
    }
end

--- Steps the velocity.
---@param thisState TrainState The last train state.
---@param frictionValues FrictionValues The friction values.
---@param gravity number The gravity multiplier.
---@param timestep number The timestep.
---@return number velocity The next velocity.
local function StepVelocity(
    thisState,
    frictionValues,
    gravity,
    timestep
)
    -- Calculate speed
    local slopeAccel = gravity * Vector3.Dot(-Vector3.YAxis, thisState.originState.transformLs:GetF()) -- m/s²

    -- calculate friction deceleration
    -- m * a = 0.5 * p * v^2 * Cd * A
    -- a = (0.5 * p * v^2 * Cd * A) / m
    -- a = 0.5 * p * v^2 * frictionValues.airResistance
    -- a = 0.5 * 1.225 * v^2 * frictionValues.airResistance
    ---@diagnostic disable-next-line: undefined-field
    local gForceDragMultiplier = math.min(thisState.originState.accelerationLs:GetLength(), 1.0)
    local airResist = 0.5 * 1.225 * (thisState.originVelocity * thisState.originVelocity) * frictionValues.airResistance
    local finalFrictionAccel = (frictionValues.dynamicFriction * gForceDragMultiplier * gravity + airResist) *
        frictionValues.frictionMultiplier

    return (thisState.originVelocity + (slopeAccel - finalFrictionAccel) * timestep)
end

--- Steps the walker forward.
---@param lastState TrainState The last train state.
---@param trainOrigin any The new train origin.
---@param timestep number The timestep.
---@param minWalkDistance number The minimum distance to walk.
local function StepTrackWalker(
    lastState,
    trainOrigin,
    timestep,
    minWalkDistance
)
    -- move forward on speed by timestep
    local distStepForward = lastState.originVelocity * timestep
    trainOrigin:MoveLocation(distStepForward)
    local thisTransform = Utils.TrackTransformToTransformQ(trainOrigin)

    if lastState.originState.transformLs == nil or thisTransform == nil then
        logger:Info("Exit! Transform was null")
        return false
    end

    local thisPosition = thisTransform:GetPos()
    local posDifference = thisPosition - lastState.originState.transformLs:GetPos()
    if Vector3.Length(posDifference) < minWalkDistance then
        logger:Info("Exit! Didn't walk enough!")
        return false
    end

    return true
end

--- Walks the track. Returns datapoints.
---@param trackOriginData TrackOrigin The origin to walk from.
---@param frictionValues FrictionValues The friction values to use.
---@param heartlineOffset any The heartline offset.
---@param timestep number The timestep of the simulation.
---@return TrainMeasurement[]?
function Utils.WalkTrack(trackOriginData, frictionValues, heartlineOffset, timestep)
    if trackOriginData == nil then
        logger:Info("Exit! Starting point is invalid. Origin is nil.")
        return nil
    end

    if trackOriginData.transform == nil then
        logger:Info("Exit! Starting point is invalid. Origin transform is nil.")
        return nil
    end

    -- Use a different walker,
    -- to prevent polluting the other one.
    local copyLocation = trackOriginData.transform:CopyLocation()

    if copyLocation == nil then
        logger:Info("Exit! Starting point is invalid. Copy of track transform failed.")
        return nil
    end

    if Utils.TrackTransformToTransformQ(copyLocation) == nil then
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

    local minWalkDist = 0.002
    local gravity = 9.81

    local currentState = GetStartingTrainState(trackOriginData, heartlineOffset)
    ---@type TrainMeasurement[]
    local measurements = {}
    local trackOrigin = trackOriginData.transform

    while (currentState.originVelocity > 0) do
        -- Step speed.
        local nextVelocity = StepVelocity(currentState, frictionValues, gravity, timestep)
        if (nextVelocity < 0) then
            return measurements
        end

        -- Step walker.
        if not StepTrackWalker(currentState, trackOrigin, timestep, minWalkDist) then
            return measurements
        end

        -- Valid spot, record this point.
        measurements[#measurements + 1] = TrainStateToTrainMeasurement(currentState)

        -- And then set current state to the next velocity.
        currentState = StepTrainState(
            currentState,
            nextVelocity,
            trackOrigin,
            heartlineOffset,
            gravity,
            timestep
        )
    end
    return measurements
end

--- Prints any Lua table.
---@param value any
---@param maxIndent integer? max indent to print
function Utils.PrintTable(value, maxIndent)
    -- internal recursive printer
    local function printValue(v, indent, seen)
        indent = indent or 0
        seen = seen or {}

        if maxIndent ~= nil and indent > maxIndent * 2 then
            return
        end

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
