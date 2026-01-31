local global                = _G
local coroutine             = global.coroutine
local setmetatable          = global.setmetatable
local GizmoUtils            = require("protrack.gizmo.utils")
---@type Api
---@diagnostic disable-next-line: undefined-field
local api                   = global.api
local TransformQ            = require("TransformQ")

---@class protrack.gizmo.TrackReferenceGizmo
---@field visible boolean Whether the gizmo is visible.
---@field refPointId integer The reference point gizmo ID.
---@field endPointId integer The end point gizmo ID.
---@field refPointtransform any The reference point transform in world space.
---@field endPointtransform any The end point transform in world space.
local TrackReferenceGizmo   = {}
TrackReferenceGizmo.__index = TrackReferenceGizmo

--- Creates a new Track Point Gizmo
--- Note: this method should be called within a coroutine that can yield.
function TrackReferenceGizmo.new()
    local self = setmetatable({}, TrackReferenceGizmo)

    -- Init markers
    local token = api.entity.CreateRequestCompletionToken()

    self.refPointId = GizmoUtils.SpawnEntity(
        "prefab_protrack_referencepoint",
        token
    )
    self.endPointId = GizmoUtils.SpawnEntity(
        "prefab_protrack_endpoint",
        token
    )
    while not api.entity.HaveRequestsCompleted(token) do
        coroutine.yield()
    end

    self.refPointtransform = TransformQ.Identity
    self.endPointtransform = TransformQ.Identity
    self.visible = true

    return self
end

--- Shuts down the Track Point Gizmo
function TrackReferenceGizmo:Shutdown()
    api.entity.DestroyEntity(self.refPointId)
    api.entity.DestroyEntity(self.endPointId)
end

--- Updates the gizmo objects
function TrackReferenceGizmo:UpdateGizmos()
    GizmoUtils.SetGizmoState(self.refPointId, self.refPointtransform, self.visible)
    GizmoUtils.SetGizmoState(self.endPointId, self.endPointtransform, self.visible)
end

--- Sets the visibility of the gizmo
--- @param visible boolean
function TrackReferenceGizmo:SetVisible(visible)
    self.visible = visible
    self:UpdateGizmos()
end

---Sets the transform of the reference point gizmo
---@param transform any
function TrackReferenceGizmo:SetRefPointTransform(transform)
    self.refPointtransform = transform
    self:UpdateGizmos()
end

---Sets the transform of the end point gizmo
---@param transform any
function TrackReferenceGizmo:SetEndPointTransform(transform)
    self.endPointtransform = transform
    self:UpdateGizmos()
end

return TrackReferenceGizmo
