local global                 = _G
local coroutine              = global.coroutine
local setmetatable           = global.setmetatable
local Vector3                = require("Vector3")
local GizmoUtils             = require("protrack.gizmo.utils")
---@type Api
---@diagnostic disable-next-line: undefined-field
local api                    = global.api
local TransformQ             = require("TransformQ")

---@class protrack.gizmo.TrackPointGizmo
---@field visible boolean Whether the gizmo is visible.
---@field originId integer The gizmo origin ID.
---@field vertGId integer The gizmo origin ID.
---@field latGId integer The gizmo origin ID.
---@field transform any The gizmo transform in world space.
---@field gForceVector any The gizmo g-force vector in local-space to the gizmo.
local TrackPointGizmoClass   = {}
TrackPointGizmoClass.__index = TrackPointGizmoClass

--- Creates a new Track Point Gizmo
--- Note: this method should be called within a coroutine that can yield.
function TrackPointGizmoClass.new()
    local self = setmetatable({}, TrackPointGizmoClass)

    -- Init markers
    local token = api.entity.CreateRequestCompletionToken()
    self.originId = GizmoUtils.SpawnEntity(
        "prefab_protrack_markergizmo",
        token
    )
    self.vertGId = GizmoUtils.SpawnEntity(
        "SceneryGizmo3AxisTranslateYOn",
        token
    )
    self.latGId = GizmoUtils.SpawnEntity(
        "SceneryGizmo3AxisTranslateXOn",
        token
    )
    while not api.entity.HaveRequestsCompleted(token) do
        coroutine.yield()
    end

    self.transform = TransformQ.Identity
    self.visible = true
    self.gForceVector = Vector3.Zero

    return self
end

--- Shuts down the Track Point Gizmo
function TrackPointGizmoClass:Shutdown()
    api.entity.DestroyEntity(self.originId)
    api.entity.DestroyEntity(self.vertGId)
    api.entity.DestroyEntity(self.latGId)
end

--- Updates a Gforce gizmo.
---@param gizmoId any
---@param axisScale number
---@param invertAxisRotMethodName string
function TrackPointGizmoClass:UpdateGForceGizmo(gizmoId, axisScale, invertAxisRotMethodName)
    api.transform.SetPosition(gizmoId, self.transform:GetPos())

    if not self.visible then
        -- set scale to 0 to hide
        api.transform.SetScale(gizmoId, 0)
        return
    end

    local orientation = self.transform:GetOr()
    if axisScale < 0 then
        orientation = orientation[invertAxisRotMethodName](orientation, math.pi) -- flip 180 deg
    end
    api.transform.SetOrientation(gizmoId, orientation)
    api.transform.SetScale(gizmoId, global.math.abs(axisScale))
end

--- Updates the gizmo objects
function TrackPointGizmoClass:UpdateGizmos()
    GizmoUtils.SetGizmoState(self.originId, self.transform, self.visible)
    self:UpdateGForceGizmo(self.vertGId, -self.gForceVector:GetY(), "RotatedAroundR")
    self:UpdateGForceGizmo(self.latGId, self.gForceVector:GetX(), "RotatedAroundU")
end

--- Sets the visibility of the gizmo
--- @param visible boolean
function TrackPointGizmoClass:SetVisible(visible)
    self.visible = visible
    self:UpdateGizmos()
end

---Sets the transform of the gizmo
---@param transform any
function TrackPointGizmoClass:SetTransform(transform)
    self.transform = transform
    self:UpdateGizmos()
end

---Sets the g force vector of the gizmo
---@param gForceVector any
function TrackPointGizmoClass:SetGForce(gForceVector)
    self.gForceVector = gForceVector
    self:UpdateGizmos()
end

return TrackPointGizmoClass
