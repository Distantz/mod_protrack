local global = _G
---@type Api
---@diagnostic disable-next-line: undefined-field
local api = global.api
local pairs = global.pairs
local require = global.require
local logger = require("forgeutils.logger").Get("ProTrackCam")
local Vector3 = require("Vector3")
local TransformQ = require("TransformQ")

local Cam = {}
Cam.PreviewCameraEntity = nil
Cam.LastModeName = nil
Cam.LastConfig = nil

function Cam.GetPreviewCameraEntity()
    if (Cam.PreviewCameraEntity == nil) then
        local token = api.entity.CreateRequestCompletionToken()
        logger:Info("Spawning new preview camera.")
        ---@diagnostic disable-next-line: param-type-mismatch
        Cam.PreviewCameraEntity = api.entity.InstantiatePrefab("AttachPoint", nil, token, TransformQ.Identity)
    end
    return Cam.PreviewCameraEntity
end

function Cam.StartRideCamera()
    local cameraModeManager = api.world.GetWorldAPIs().CameraModeManager
    Cam.LastModeName = cameraModeManager:GetCurrentModeName(api.camera.GetMainCameraID())
    Cam.LastConfig = cameraModeManager:GetConfig()

    local attachID = Cam.GetPreviewCameraEntity()
    local tInitData = {
        targetEntityID = attachID,
        FOV = 55,
        bLookAheadEffect = false
    }
    api.world.GetWorldAPIs().CameraModeManager:RequestMode("FirstPersonRide", tInitData)
end

function Cam.StopRideCamera()
    api.world.GetWorldAPIs().CameraModeManager:RequestDefaultMode()
end

return Cam;
