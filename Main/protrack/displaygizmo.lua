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


local Gizmo         = {}
Gizmo.Position_ID   = nil
Gizmo.VertG_ID      = nil
Gizmo.LatG_ID       = nil
Gizmo.LongG_ID      = nil
Gizmo.Reference_ID  = nil
Gizmo.EndPos_ID     = nil
Gizmo.Visible       = true
Gizmo.MarkerVisible = true

function Gizmo.InitGizmo()
    logger:Info("InitGizmo")

    -- Don't respawn if it exists
    if Gizmo.VertG_ID ~= nil then
        return
    end

    local token = api.entity.CreateRequestCompletionToken()

    Gizmo.Position_ID = Gizmo.SpawnGizmo(
        "prefab_protrack_markergizmo",
        token
    )

    Gizmo.Reference_ID = Gizmo.SpawnGizmo(
        "prefab_protrack_referencepoint",
        token
    )

    Gizmo.EndPos_ID = Gizmo.SpawnGizmo(
        "prefab_protrack_endpoint",
        token
    )

    Gizmo.VertG_ID = Gizmo.SpawnGizmo(
        "SceneryGizmo3AxisTranslateYOn",
        token
    )

    Gizmo.LatG_ID = Gizmo.SpawnGizmo(
        "SceneryGizmo3AxisTranslateXOn",
        token
    )

    Gizmo.LongG_ID = Gizmo.SpawnGizmo(
        "SceneryGizmo3AxisTranslateZOn",
        token
    )

    Gizmo.SetVisible(false)
end

function Gizmo.SpawnGizmo(gizmoName, token)
    return api.entity.InstantiatePrefab(
        gizmoName,
        nil,
        token,
        TransformQ.Identity
    )
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
    Gizmo.SetMarkerVisible(visible)
    if Gizmo.Visible == visible then
        return
    end

    Gizmo.Visible = visible

    local scaleVisible = Gizmo.Visible and 1.0 or 0.0
    api.transform.SetScale(Gizmo.Position_ID, scaleVisible)
    api.transform.SetScale(Gizmo.Reference_ID, scaleVisible)
    api.transform.SetScale(Gizmo.EndPos_ID, scaleVisible)
end

function Gizmo.SetMarkerVisible(visible)
    if Gizmo.MarkerVisible == visible then
        return
    end

    Gizmo.MarkerVisible = visible
    local scaleVisible = visible and 1.0 or 0.0
    api.transform.SetScale(Gizmo.VertG_ID, scaleVisible)
    api.transform.SetScale(Gizmo.LatG_ID, scaleVisible)
    api.transform.SetScale(Gizmo.LongG_ID, scaleVisible)
end

function Gizmo.SetData(transformWorld, gForceVecLocal)
    if Gizmo.VertG_ID == nil then
        return
    end

    if gForceVecLocal == nil then
        return
    end

    if not Gizmo.MarkerVisible then
        return
    end

    -- idk why but in "understanding" vertical g should be inverted
    -- because i guess a negative acceleration makes less sense in our ref frame?
    api.transform.SetTransform(Gizmo.Position_ID, transformWorld)
    Gizmo.SetGizmoWithGScale(Gizmo.VertG_ID, transformWorld, "RotatedAroundR", -gForceVecLocal:GetY())
    Gizmo.SetGizmoWithGScale(Gizmo.LatG_ID, transformWorld, "RotatedAroundU", gForceVecLocal:GetX())
    Gizmo.SetGizmoWithGScale(Gizmo.LongG_ID, transformWorld, "RotatedAroundU", gForceVecLocal:GetZ())

    -- Set mags of all based on vec data
end

function Gizmo.SetMarkers(referenceTransformWorld, endTransformWorld)
    api.transform.SetTransform(Gizmo.Reference_ID, referenceTransformWorld)
    api.transform.SetTransform(Gizmo.EndPos_ID, endTransformWorld)
end

function Gizmo.UpdateVisibility()

end

return Gizmo
