local global     = _G
---@type Api
---@diagnostic disable-next-line: undefined-field
local api        = global.api
local pairs      = global.pairs
local require    = global.require
local logger     = require("forgeutils.logger").Get("ProTrackGizmo")
local Vector3    = require("Vector3")
local Quaternion = require("Quaternion")
local Utils      = require("protrack.utils")
local TransformQ = require("TransformQ")
local mathUtils  = require("Common.mathUtils")


local Gizmo       = {}
Gizmo.Position_ID = nil
Gizmo.VertG_ID    = nil
Gizmo.LatG_ID     = nil
Gizmo.LongG_ID    = nil
Gizmo.Visible     = false

function Gizmo.InitGizmo()
    logger:Info("InitGizmo")

    -- Don't respawn if it exists
    if Gizmo.VertG_ID ~= nil then
        return
    end

    local token = api.entity.CreateRequestCompletionToken()
    Gizmo.Position_ID = api.entity.InstantiatePrefab(
        "scenerygizmopivoton",
        nil,
        token,
        TransformQ.Identity
    )

    Gizmo.VertG_ID = api.entity.InstantiatePrefab(
        "SceneryGizmo3AxisTranslateYOn",
        nil,
        token,
        TransformQ.Identity
    )
    Gizmo.LatG_ID = api.entity.InstantiatePrefab(
        "SceneryGizmo3AxisTranslateXOn",
        nil,
        token,
        TransformQ.Identity
    )
    Gizmo.LongG_ID = api.entity.InstantiatePrefab(
        "SceneryGizmo3AxisTranslateZOn",
        nil,
        token,
        TransformQ.Identity
    )

    Gizmo.Visible = true
    Gizmo.SetVisible(false)
end

function Gizmo.SetGizmoWithGScale(gizmo, worldTransform, invertAxisRotMethod, gScale)
    api.transform.SetPosition(gizmo, worldTransform:GetPos())

    local orientation = worldTransform:GetOr()
    if mathUtils.Sign(gScale) < 0 then
        -- flip 180 deg
        orientation = orientation[invertAxisRotMethod](orientation, math.pi)
    end

    api.transform.SetOrientation(gizmo, orientation)
    api.transform.SetScale(gizmo, math.abs(gScale))
end

function Gizmo.SetVisible(visible)
    logger:Info("Set Visible")
    if Gizmo.Visible == visible then
        logger:Info("Early return")
        return
    end

    logger:Info("Setting gizmo to visible: ")
    logger:Info(global.tostring(visible))
    --api.model.SetHidden(Gizmo.VertG_ID, visible)
    --api.model.SetHidden(Gizmo.LatG_ID, visible)
    --api.model.SetHidden(Gizmo.LongG_ID, visible)
    Gizmo.Visible = visible
end

function Gizmo.SetData(transformWorld, gForceVecLocal)
    if Gizmo.VertG_ID == nil then
        return
    end

    if gForceVecLocal == nil then
        return
    end

    -- idk why but in "understanding" vertical g should be inverted
    -- because i guess a negative acceleration makes less sense in our ref frame?
    api.transform.SetTransform(Gizmo.Position_ID, transformWorld)
    Gizmo.SetGizmoWithGScale(Gizmo.VertG_ID, transformWorld, "RotatedAroundR", -gForceVecLocal:GetY())
    Gizmo.SetGizmoWithGScale(Gizmo.LatG_ID, transformWorld, "RotatedAroundU", gForceVecLocal:GetX())
    Gizmo.SetGizmoWithGScale(Gizmo.LongG_ID, transformWorld, "RotatedAroundU", gForceVecLocal:GetZ())

    logger:Info(global.tostring(gForceVecLocal))

    -- Set mags of all based on vec data
end

return Gizmo
