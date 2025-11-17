local global              = _G
---@type Api
---@diagnostic disable-next-line: undefined-field
local api                 = global.api
local pairs               = global.pairs
local table               = require("Common.tableplus")
local coroutine           = global.coroutine
local require             = global.require
local logger              = require("forgeutils.logger").Get("ProTrackGizmo")
local TransformQ          = require("TransformQ")
local mathUtils           = require("Common.mathUtils")

local Gizmo               = {}
Gizmo.Marker_ID           = nil
Gizmo.VertG_ID            = nil
Gizmo.LatG_ID             = nil
Gizmo.Reference_ID        = nil
Gizmo.EndPos_ID           = nil

Gizmo.Visible             = true
Gizmo.MarkerVisible       = true

-- Gizmo marker vars
Gizmo.MarkerTransformWS   = nil
Gizmo.MarkerGForce        = nil

-- Gizmo reference vars
Gizmo.StartPosTransformWS = nil
Gizmo.EndPosTransformWS   = nil

function Gizmo.InitGizmo()
    logger:Info("InitGizmo")
    Gizmo.Visible = true
    Gizmo.MarkerVisible = true

    local token = api.entity.CreateRequestCompletionToken()

    Gizmo.Marker_ID = Gizmo.SpawnGizmo(
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

    logger:Info("Finished Init Gizmo.")

    -- Return gizmo init coroutine to run
    return coroutine.create(function()
        -- Wait for request
        while token and not api.entity.HaveRequestsCompleted(token) do
            coroutine.yield(false)
        end

        return true
    end)
end

function Gizmo.SpawnGizmo(gizmoName, token)
    return api.entity.InstantiatePrefab(
        gizmoName,
        nil,
        token,
        TransformQ.Identity
    )
end

function Gizmo.PutAxisGizmo(gizmo, transform, axisScale, invertAxisRotMethod)
    api.transform.SetPosition(gizmo, transform:GetPos())
    local orientation = transform:GetOr()
    if mathUtils.Sign(axisScale) < 0 then
        -- flip 180 deg
        orientation = orientation[invertAxisRotMethod](orientation, math.pi)
    end
    api.transform.SetOrientation(gizmo, orientation)
    api.transform.SetScale(gizmo, math.abs(axisScale))
end

function Gizmo.PutGizmoAtTransform(gizmo, transform, visible)
    if visible ~= nil and visible and transform ~= nil then
        api.transform.SetTransform(gizmo, table.copy(transform))
        -- not the same thing for some god damn reason.
        api.transform.SetScale(gizmo, 1)
    else
        -- set scale to 0 to hide
        api.transform.SetScale(gizmo, 0)
    end
end

function Gizmo.SetTrackGizmosVisible(visible)
    if Gizmo.Visible == visible then
        return
    end

    Gizmo.Visible = visible
    Gizmo.RegenerateGizmo()
end

function Gizmo.SetMarkerGizmosVisible(visible)
    if Gizmo.MarkerVisible == visible then
        return
    end

    Gizmo.MarkerVisible = true
    Gizmo.RegenerateMarkerGizmos()
end

function Gizmo.SetMarkerData(markerTransform, gForceVecLocal)
    Gizmo.MarkerTransformWS = table.copy(markerTransform)
    Gizmo.MarkerGForce = table.copy(gForceVecLocal)
    Gizmo.RegenerateMarkerGizmos()
end

function Gizmo.SetStartEndMarkers(startPosition, endPosition)
    Gizmo.StartPosTransformWS = table.copy(startPosition)
    Gizmo.EndPosTransformWS = table.copy(endPosition)
    Gizmo.RegenerateGizmo()
end

function Gizmo.RegenerateGizmo()
    Gizmo.PutGizmoAtTransform(Gizmo.Reference_ID, Gizmo.StartPosTransformWS, Gizmo.Visible)
    Gizmo.PutGizmoAtTransform(Gizmo.EndPos_ID, Gizmo.EndPosTransformWS, Gizmo.Visible)

    -- Set marker and G-Force position gizmos.
    Gizmo.RegenerateMarkerGizmos()
end

function Gizmo.RegenerateMarkerGizmos()
    local displayMarker = Gizmo.Visible and Gizmo.MarkerVisible

    Gizmo.PutGizmoAtTransform(Gizmo.Marker_ID, Gizmo.MarkerTransformWS, displayMarker)
    if displayMarker and Gizmo.MarkerGForce ~= nil then
        Gizmo.PutAxisGizmo(Gizmo.VertG_ID, Gizmo.MarkerTransformWS, -Gizmo.MarkerGForce:GetY(), "RotatedAroundR")
        Gizmo.PutAxisGizmo(Gizmo.LatG_ID, Gizmo.MarkerTransformWS, Gizmo.MarkerGForce:GetX(), "RotatedAroundU")
    else
        Gizmo.PutGizmoAtTransform(Gizmo.VertG_ID, Gizmo.MarkerTransformWS, false)
        Gizmo.PutGizmoAtTransform(Gizmo.LatG_ID, Gizmo.MarkerTransformWS, false)
    end
end

return Gizmo
