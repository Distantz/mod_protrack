-----------------------------------------------------------------------
--/  @file    Monolophosaurus_01.lua
--/  @author  Yourself
--/  @version 1.0
--/
--/  @brief  Defines an ACSE prefab
--/
--/  @see    https://github.com/OpenNaja/ACSE
-----------------------------------------------------------------------
local global            = _G
local api               = global.api
local require           = global.require
local pairs             = global.pairs
local ipairs            = global.ipairs
local Vector2           = require("Vector2")
local Vector3           = require("Vector3")

local prefab            = {}

prefab.GetRoot          = function()
    return
    {
        Components = {
            Transform = {},
            Model = {
                ModelName = 'gizmo_protrack_marker'
            }
        },
    }
end

prefab.GetFlattenedRoot = function()
    local tPrefab = api.entity.CompilePrefab(prefab.GetRoot(), 'prefab_protrack_markergizmo')
    return api.entity.FindPrefab('prefab_protrack_markergizmo')
end

return prefab
