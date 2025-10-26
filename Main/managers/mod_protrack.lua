-----------------------------------------------------------------------
--/  @file    Managers.SceneryLineManager.lua
--/  @author  Inaki
--/  @version 1.0
--/
--/  @brief  Boilerplate template for a park manager script
--/  @see    https://github.com/OpenNaja/ACSE
-----------------------------------------------------------------------
local global = _G
---@type Api
local api = global.api
local pairs = global.pairs
local coroutine = global.coroutine
local require = global.require
local mathUtils = require "Common.mathUtils"

---@diagnostic disable-next-line: deprecated
local module = global.module

local Object = require("Common.object")
local Mutators = require("Environment.ModuleMutators")
local Vector3 = require("Vector3")
local Utils = require("protrack.utils")
local Gizmo = require("protrack.displaygizmo")
local Cam = require("protrack.cam")
local Datastore = require("protrack.datastore")
local FrictionHelper = require("database.frictionhelper")
local InputEventHandler = require("Components.Input.InputEventHandler")
local logger = require("forgeutils.logger").Get("ProTrackManager")

--/ Main class definition
---@class protrackManager
local protrackManager = module(..., Mutators.Manager())
protrackManager.dt = 0
protrackManager.trackEditMode = nil
protrackManager.inCamera = false
protrackManager.inputEventHandler = nil

---@type WorldAPIs_InputManager
protrackManager.inputManagerAPI = nil
protrackManager.tWorldAPIs = nil

protrackManager.gizmoInitCoroutine = nil

---@type FrictionValues
protrackManager.frictionValues = nil

--
-- @Brief Init function for this manager
-- @param _tProperties  a table with initialization data for all the managers.
-- @param _tEnvironment a reference to the current Environment
--
-- The Init function is the first function of the manager being called by the game.
-- This function is used to initialize all the custom data required, however at this
-- stage the rest of the managers might not be available.
--
function protrackManager.Init(self, _tProperties, _tEnvironment)
    logger:Info("Init")
end

--
-- @Brief Activate function for this manager
--
-- Activate is called after all the Managers of this environment have been initialised,
-- and it is safe to assume that access to the rest of the game managers is guaranteed to
-- work.
--
function protrackManager.Activate(self)
    -- Our entry point simply calls inject on the submode override file:
    logger:Info("Injecting...")
    Cam.GetPreviewCameraEntity()
    self.gizmoInitCoroutine = Gizmo.InitGizmo()
    logger:Info("Done gizmo setup")

    local trackEditMode = require("Editors.Track.TrackEditMode")
    local baseTransitionIn = trackEditMode.TransitionIn
    trackEditMode.TransitionIn = function(slf, _startTrack, _startSelection, _bDontRequestTrainRespawn)
        baseTransitionIn(slf, _startTrack, _startSelection, _bDontRequestTrainRespawn)
        self:StartEditMode(slf)
    end

    local baseTransitionOut = trackEditMode.TransitionOut
    trackEditMode.TransitionOut = function(slf)
        baseTransitionOut(slf)
        self:EndEditMode()
    end

    local trackEditSelection = require("Editors.Track.TrackEditSelection")
    local baseCommitPreview = trackEditSelection.CommitPreview
    trackEditSelection.CommitPreview = function(slf)
        local ret = baseCommitPreview(slf)
        self:NewWalk()
        return ret
    end

    logger:Info("Inserted hooks")
end

function protrackManager.ZeroData(self)
    Gizmo.SetMarkerGizmosVisible(false)
    Gizmo.SetTrackGizmosVisible(false)
    self:StopTrackCamera()
    --Gizmo.SetVisible(false)
    self.trackEditMode = nil
    self.dt = 0
    self.tWorldAPIs = nil
    self.inputManagerAPI = nil
    Datastore.tDatapoints = nil
    Datastore.trackWalkerOrigin = nil
end

function protrackManager.StartEditMode(self, trackEditMode)
    logger:Info("Starting edit mode!")
    self:ZeroData()

    logger:Info("Zeroed")
    self.trackEditMode = trackEditMode
    self.tWorldAPIs = api.world.GetWorldAPIs()
    self.inputManagerAPI = self.tWorldAPIs.InputManager

    local trackEntity = self.trackEditMode.tActiveData:GetTrackEntity()

    ---@diagnostic disable-next-line: assign-type-mismatch
    self.frictionValues = FrictionHelper.GetFrictionValues(api.track.GetTrackHolder(trackEntity))
    Utils.PrintTable(self.frictionValues)

    -- Our api doesn't contain this (defined by object base) so we need a pragma
    ---@diagnostic disable-next-line: undefined-field
    self.inputEventHandler = InputEventHandler:new()
    self.inputEventHandler:Init()

    self.inputEventHandler:AddKeyPressedEvent("RotateObject", function()
        self:NewTrainPosition()
        return true
    end)

    self.inputEventHandler:AddKeyPressedEvent("AdvancedMove", function()
        self:NewWalk()
        return true
    end)

    self.inputEventHandler:AddKeyPressedEvent("ScaleObject", function()
        -- function num : 0_4_4 , upvalues : self
        logger:Info("Toggle ride camera!")

        if not self.inCamera then
            self:StartTrackCamera()
        else
            self:StopTrackCamera()
        end
        return true
    end)
end

function protrackManager.EndEditMode(self)
    self:ZeroData()
end

function protrackManager.NewTrainPosition(self)
    logger:Info("NewTrainPosition()")
    logger:Info("trying to get trackentity")
    local trackEntity = self.trackEditMode.tActiveData:GetTrackEntity()
    logger:Info("got it")
    Datastore.trackEntityTransform = api.transform.GetTransform(trackEntity)
    Datastore.trackWalkerOrigin = Utils.GetFirstCarData(trackEntity)
    self:NewWalk()
end

function protrackManager.ClearWalkerOrigin(self)
    Datastore.trackWalkerOrigin = nil
    Gizmo.SetMarkerGizmosVisible(false)
    Gizmo.SetTrackGizmosVisible(false)
    self:StopTrackCamera()
end

function protrackManager.NewWalk(self)
    logger:Info("NewWalk()")
    if Datastore.trackWalkerOrigin == nil then
        return
    end

    Datastore.tDatapoints = Utils.WalkTrack(
        Datastore.trackWalkerOrigin,
        self.frictionValues,
        Datastore.tSimulationDelta
    )

    -- if nil, our point is BS.
    -- Need to clear everything

    if not Datastore.HasData() then
        self:ClearWalkerOrigin()
        return
    end

    -- Turn it on
    Gizmo.SetMarkerGizmosVisible(true)
    Gizmo.SetTrackGizmosVisible(not self.inCamera)
    Gizmo.SetStartEndMarkers(
        Datastore.trackEntityTransform:ToWorld(
            Utils.TrackTransformToTransformQ(Datastore.trackWalkerOrigin.transform)
        ),
        Datastore.trackEntityTransform:ToWorld(Datastore.tDatapoints[#Datastore.tDatapoints].transform)
    )
end

function protrackManager.StartTrackCamera(self)
    if Datastore.tDatapoints == nil then
        return
    end

    if not self.inCamera then
        Gizmo.SetMarkerGizmosVisible(false)
        Cam.StartRideCamera()
        self.inCamera = true
    end
end

function protrackManager.StopTrackCamera(self)
    if self.inCamera then
        Gizmo.SetMarkerGizmosVisible(true)
        Cam.StopRideCamera()
        self.inCamera = false
    end
end

function protrackManager.Advance(self, deltaTime)
    -- Handle gizmo init.
    if self.gizmoInitCoroutine ~= nil then
        coroutine.resume(self.gizmoInitCoroutine)
        if coroutine.status(self.gizmoInitCoroutine) == "dead" then
            logger:Info("Regeneration complete")
            Gizmo.SetMarkerGizmosVisible(false)
            Gizmo.SetTrackGizmosVisible(false)
            self.gizmoInitCoroutine = nil
        end
    end

    if self.inputEventHandler == nil or self.inputManagerAPI == nil then
        return
    end

    self.inputEventHandler:CheckEvents()

    -- If a change has happened, we want to know!
    if (self.trackEditMode:HasRequestedChange()) then
        self:NewWalk()
    end

    -- Work out direction
    local direction = 0.0
    if (self.inputManagerAPI:GetKeyDown("DecreaseBrushIntensity")) then
        direction = direction - 1.0
    end
    if (self.inputManagerAPI:GetKeyDown("IncreaseBrushIntensity")) then
        direction = direction + 1.0
    end

    -- Set gizmo visiblity
    --Gizmo.Visible(not self.inCamera)

    if Datastore.HasData() then
        if Datastore.trackWalkerOrigin == nil or Datastore.trackEntityTransform == nil then
            self:ClearWalkerOrigin()
            return
        end

        local timestep = api.time.GetDeltaTimeUnscaled()
        self.dt = self.dt + timestep * direction

        -- clamp dt to make it stay in bounds
        self.dt = mathUtils.Clamp(self.dt, 0, Datastore.GetTimeLength())

        local pt = Datastore.SampleDatapointAtTime(self.dt)
        local wsTrans = Datastore.trackEntityTransform:ToWorld(pt.transform)
        local wsCamOffset = wsTrans:ToWorldDir(Datastore.trackWalkerOrigin.camOffset)
        api.transform.SetPosition(Cam.PreviewCameraEntity, wsTrans:GetPos() + wsCamOffset)
        api.transform.SetOrientation(Cam.PreviewCameraEntity, wsTrans:GetOr())

        Gizmo.SetMarkerData(wsTrans, pt.g)
    end
end

--/ Validate class methods and interfaces, the game needs
--/ to validate the Manager conform to the module requirements.
Mutators.VerifyManagerModule(protrackManager)
