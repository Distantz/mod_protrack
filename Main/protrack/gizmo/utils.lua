local global     = _G
---@type Api
---@diagnostic disable-next-line: undefined-field
local api        = global.api
local require    = global.require
local TransformQ = require("TransformQ")

---@class protrack.gizmo.Utils
local Utils      = {}

--- Spawns an entity with a token.
--- @param gizmoPrefab string
--- @param token any
--- @return integer
function Utils.SpawnEntity(gizmoPrefab, token)
    ---@diagnostic disable-next-line: return-type-mismatch
    return api.entity.InstantiatePrefab(
        gizmoPrefab,
        nil,
        token,
        TransformQ.Identity
    )
end

---Sets a gizmo's state, including transform and visibility
---@param gizmoId integer
---@param transform any
---@param visible boolean
function Utils.SetGizmoState(gizmoId, transform, visible)
    if visible ~= nil and visible and transform ~= nil then
        api.transform.SetTransform(gizmoId, transform)
        api.transform.SetScale(gizmoId, 1) -- not the same thing for some god damn reason.
    else
        -- set scale to 0 to hide
        api.transform.SetScale(gizmoId, 0)
    end
end

return Utils
