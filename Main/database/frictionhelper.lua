local global = _G
---@type Api
---@diagnostic disable-next-line: undefined-field
local api = global.api

local table = global.table
local DBUtil = require("forgeutils.internal.database.databaseutils")
local Utils = require("protrack.utils")
local logger = require("forgeutils.logger").Get("FrictionHelper")

local FrictionHelper = {}

---@class FrictionValues
---@field staticFriction number Static friction.
---@field airResistance number Air resistance.
---@field dynamicFriction number Dynamic friction.
---@field frictionMultiplier number Friction multiplier.

function FrictionHelper.Bind()
    logger:Info("Binding FrictionHelper")
    DBUtil.BindPreparedStatement("TrackedRideCars", "protrack_friction")
end

--- Returns the friction values for a trackHolder
---@param trackHolder table
---@return FrictionValues?
function FrictionHelper.GetFrictionValues(trackHolder)
    logger:Info("Getting Friction Values:")

    local _, frictionMultiplier = api.track.GetFrictionMultiplier(trackHolder)

    local tRes = DBUtil.ExecuteQuery(
        "TrackedRideCars",
        "ProTrack_GetFrictionForTrain",
        { api.track.GetTrainType(trackHolder) },
        1
    )

    if tRes ~= nil then
        local row = tRes[1]

        return {
            staticFriction = row[1],
            airResistance = row[2],
            dynamicFriction = row[3],
            frictionMultiplier = frictionMultiplier
        }
    end

    return nil
end

return FrictionHelper
