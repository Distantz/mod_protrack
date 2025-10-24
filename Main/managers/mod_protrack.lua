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

protrackManager.overlayUI = nil

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
    Gizmo.InitGizmo()
    Gizmo.SetVisible(false)
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

    logger:Info("Inserted hooks")
end

function protrackManager.ZeroData(self)
    self:StopTrackCamera()
    --Gizmo.SetVisible(false)
    self.trackEditMode = nil
    self.dt = 0
    self.tWorldAPIs = nil
    self.inputManagerAPI = nil
    Datastore.tDatapoints = nil
    Datastore.trackEntityTransform = nil
    Datastore.trackWalkerTransform = nil
    Datastore.trackWalkerSpeed = nil
end

function protrackManager.StartEditMode(self, trackEditMode)
    logger:Info("Starting edit mode!")
    --- TODO: Add Ui initialisation here

    self:ZeroData()

    logger:Info("Zeroed")
    self.trackEditMode = trackEditMode
    self.tWorldAPIs = api.world.GetWorldAPIs()
    self.inputManagerAPI = self.tWorldAPIs.InputManager

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
    Datastore.trackWalkerTransform, Datastore.trackWalkerSpeed = Utils.GetFirstCarTrackLocAndSpeed(trackEntity)
    self:NewWalk()
end

function protrackManager.NewWalk(self)
    logger:Info("NewWalk()")
    if Datastore.trackWalkerTransform == nil then
        return
    end

    if Datastore.trackWalkerSpeed == nil then
        return
    end

    Datastore.tDatapoints = Utils.WalkTrack(
        Datastore.trackWalkerTransform,
        Datastore.trackWalkerSpeed,
        Datastore.tSimulationDelta
    )
end

function protrackManager.StartTrackCamera(self)
    if Datastore.tDatapoints == nil then
        return
    end

    if not self.inCamera then
        Cam.StartRideCamera()
        --- TODO: Add force ui show here
        protrackManager.overlayUI:Show()
        self.inCamera = true
    end
end

function protrackManager.StopTrackCamera(self)
    if self.inCamera then
        Cam.StopRideCamera()
        --- TODO: Add force ui hide here
        protrackManager.overlayUI:Hide()
        self.inCamera = false
    end
end

function protrackManager.Advance(self, deltaTime)
    if self.inputEventHandler == nil or self.inputManagerAPI == nil then
        return
    end

    self.inputEventHandler:CheckEvents()

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

    if Datastore.tDatapoints ~= nil and #Datastore.tDatapoints > 0 then
        local timestep = api.time.GetDeltaTimeUnscaled()
        self.dt = self.dt + timestep * direction

        -- clamp dt to make it stay in bounds
        self.dt = mathUtils.Clamp(self.dt, 0, Datastore.GetTimeLength())

        local pt = Datastore.SampleDatapointAtTime(self.dt)
        local wsTrans = Datastore.trackEntityTransform:ToWorld(pt.transform)
        api.transform.SetPosition(Cam.PreviewCameraEntity, wsTrans:GetPos())
        api.transform.SetOrientation(Cam.PreviewCameraEntity, wsTrans:GetOr())
        Gizmo.SetData(wsTrans, pt.g)
    end
end

--/ Validate class methods and interfaces, the game needs
--/ to validate the Manager conform to the module requirements.
Mutators.VerifyManagerModule(protrackManager)
