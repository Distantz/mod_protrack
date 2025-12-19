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
---@diagnostic disable-next-line: undefined-field
local api = global.api
local pairs = global.pairs
local coroutine = global.coroutine
local require = global.require
local mathUtils = require("Common.mathUtils")

---@diagnostic disable-next-line: deprecated
local module = global.module

local Mutators = require("Environment.ModuleMutators")
local Vector3 = require("Vector3")
local HookManager = require("forgeutils.hookmanager")
local Utils = require("protrack.utils")
local FvdMode = require("protrack.modes.fvdmode")
local AdvMoveMode = require("protrack.modes.advancedmovemode")
local Gizmo = require("protrack.displaygizmo")
local Cam = require("protrack.cam")
local Datastore = require("protrack.datastore")
local FrictionHelper = require("database.frictionhelper")
local InputEventHandler = require("Components.Input.InputEventHandler")
local logger = require("forgeutils.logger").Get("ProTrackManager")
local ForceOverlay = require("protrack.ui.forceoverlay")
local UnitConversion = require("Helpers.UnitConversion")
--/ Main class definition
---@class protrackManager
local protrackManager = module(..., Mutators.Manager())
protrackManager.simulationTime = 0
---@type TrackEditMode?
protrackManager.trackEditMode = nil
protrackManager.editingTrackEnd = false
protrackManager.inCamera = false
protrackManager.cameraIsHeartlineMode = false
protrackManager.inputEventHandler = nil
protrackManager.line = nil

---@type WorldAPIs_InputManager
protrackManager.inputManagerAPI = nil
protrackManager.tWorldAPIs = nil

protrackManager.gizmoInitCoroutine = nil
protrackManager.overlayUI = nil

---@type FrictionValues
protrackManager.frictionValues = nil

protrackManager.context = nil
protrackManager.trackMode = 0
protrackManager.newTrackModeRequest = 0
protrackManager.playingInDir = 0
protrackManager.draggableWidget = nil
protrackManager.staticSelf = nil

local NORMAL_TRACKMODE = 0
local FVD_TRACKMODE = 1
local ADVMOVE_TRACKMODE = 2

---Sets a value, while also setting to the datastore
---@param name any
---@param value any
local function SetVariableWithDatastore(name, value)
    protrackManager[name] = value
    api.ui2.SetDataStoreElement(protrackManager.context, name, value)
end

function protrackManager.SetupHooks()
    logger:Info("Setup FU hooks")
    HookManager:AddHook(
        "UI.CoasterWidgetsUI",
        "SetWidgets",
        function(originalMethod, slf, _tItems)
            if protrackManager.staticSelf.trackEditMode == nil or not protrackManager.staticSelf.editingTrackEnd then
                originalMethod(slf, _tItems)
                return
            end

            if (protrackManager.staticSelf.trackMode == FVD_TRACKMODE) and Datastore.HasData() then -- forcelock, remove 1 and 3
                _tItems[1] = {}
                _tItems[3] = {}
            elseif (protrackManager.staticSelf.trackMode == ADVMOVE_TRACKMODE) then -- Advanced widget, remove all
                _tItems[1] = {}
                _tItems[2] = {}
                _tItems[3] = {}
                _tItems[4] = {}
            end
            originalMethod(slf, _tItems)
        end
    )

    -- Setup hook for the build end point
    HookManager:AddHook(
        "Editors.Track.TrackEditValues",
        "StaticBuildEndPoint",
        function(originalMethod, startT, tData)
            if (protrackManager.staticSelf.trackMode == FVD_TRACKMODE) then
                return FvdMode.StaticBuildEndPoint_Hook(originalMethod, startT, tData)
            elseif (protrackManager.staticSelf.trackMode == ADVMOVE_TRACKMODE) then
                return AdvMoveMode.StaticBuildEndPoint_Hook(originalMethod, startT, tData)
            end
            return originalMethod(startT, tData)
        end
    )

    HookManager:AddHook(
        "Editors.Track.TrackEditMode",
        "TransitionIn",
        function(originalMethod, slf, _startTrack, _startSelection, _bDontRequestTrainRespawn)
            originalMethod(slf, _startTrack, _startSelection, _bDontRequestTrainRespawn)
            protrackManager.staticSelf:StartEditMode(slf)
        end
    )

    HookManager:AddHook(
        "Editors.Track.TrackEditMode",
        "TransitionOut",
        function(originalMethod, slf)
            originalMethod(slf)
            protrackManager.staticSelf:EndEditMode()
        end
    )

    HookManager:AddHook(
        "Editors.Track.TrackEditSelection",
        "CommitPreview",
        function(originalMethod, slf)
            local ret = originalMethod(slf)
            protrackManager.staticSelf:NewWalk()
            return ret
        end
    )

    logger:Info("Done")
end

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
    protrackManager.staticSelf = self
end

--
-- @Brief Activate function for this manager
--
-- Activate is called after all the Managers of this environment have been initialised,
-- and it is safe to assume that access to the rest of the game managers is guaranteed to
-- work.
--
function protrackManager.Activate(self)
    -- Activate datastore context, this is essential for UI integration
    protrackManager.context = api.ui2.GetDataStoreContext("ProTrack")

    -- Our entry point simply calls inject on the submode override file:
    logger:Info("Completing spawns...")
    Cam.GetPreviewCameraEntity()
    logger:Info("Finished Camera")

    self.gizmoInitCoroutine = Gizmo.InitGizmo()
    local line = require("protrack.displayline")
    self.line = line:new()
    FvdMode.line = line:new()
    logger:Info("Finished Lines")

    logger:Info("Done gizmo setup")
    logger:Info("Initialising UI")
    SetVariableWithDatastore(false, "cameraIsHeartlineMode")

    Datastore.heartlineOffset = Vector3.Zero
    ---@type ForceOverlay
    protrackManager.overlayUI = ForceOverlay:new(
        function()
            logger:Info("UI is setup and ready")

            -- Button listeners

            protrackManager.overlayUI:AddListener_ReanchorRequested(
                function()
                    self:NewTrainPosition()
                end,
                nil
            )

            protrackManager.overlayUI:AddListener_ResimulateRequested(
                function()
                    self:NewWalk()
                end,
                nil
            )

            protrackManager.overlayUI:AddListener_ChangeCamModeRequested(
                function()
                    if not self.inCamera then
                        self:StartTrackCamera()
                    else
                        self:StopTrackCamera()
                    end
                end,
                nil
            )

            protrackManager.overlayUI:AddListener_PlayChanged(
                function(newDir)
                    SetVariableWithDatastore("playingInDir", newDir)
                end,
                nil
            )

            -- Value listeners

            protrackManager.overlayUI:AddListener_HeartlineValueChanged(
                function(newVal)
                    Datastore.heartlineOffset = Vector3:new(0, newVal, 0)
                    self:NewWalk()
                    self:SetTrackBuilderDirty()
                end,
                nil
            );

            protrackManager.overlayUI:AddListener_PosGValueChanged(
                function(newVal)
                    FvdMode.posG = newVal
                    self:SetTrackBuilderDirty()
                end,
                nil
            );

            protrackManager.overlayUI:AddListener_LatGValueChanged(
                function(newVal)
                    FvdMode.latG = newVal
                    self:SetTrackBuilderDirty()
                end,
                nil
            );

            protrackManager.overlayUI:AddListener_TrackModeChanged(
                function(newTrackMode)
                    -- Call is delayed like this to exit
                    -- the UI thread.
                    self.newTrackModeRequest = newTrackMode
                    -- self:SwitchTrackMode(newTrackMode)
                end,
                nil
            );

            protrackManager.overlayUI:AddListener_HeartlineCamChanged(
                function(heartlineCamMode)
                    SetVariableWithDatastore("cameraIsHeartlineMode", heartlineCamMode)
                end,
                nil
            );

            protrackManager.overlayUI:AddListener_TimeChanged(
                function(newTime)
                    self.simulationTime = newTime * Datastore.GetTimeLength()
                end,
                nil
            );
        end
    )
end

function protrackManager.ZeroData(self)
    self:ClearWalkerOrigin()
    self.newTrackModeRequest = 0
    self.trackEditMode = nil
    self.editingTrackEnd = false
    self.simulationTime = 0
    self.tWorldAPIs = nil
    self.inputManagerAPI = nil
    Datastore.tDatapoints = nil

    -- Datastore updates
    SetVariableWithDatastore("playingInDir", 0)
    SetVariableWithDatastore("trackMode", 0)
end

function protrackManager.StartEditMode(self, trackEditMode)
    logger:Info("Starting edit mode!")

    self:ZeroData()

    ---@type TrackEditMode
    self.trackEditMode = trackEditMode
    self.tWorldAPIs = api.world.GetWorldAPIs()
    self.inputManagerAPI = self.tWorldAPIs.InputManager

    local trackEntity = self.trackEditMode.tActiveData:GetTrackEntity()
    Datastore.trackEntityTransform = api.transform.GetTransform(trackEntity)

    ---@diagnostic disable-next-line: assign-type-mismatch
    self.frictionValues = FrictionHelper.GetFrictionValues(api.track.GetTrackHolder(trackEntity))

    -- Our api doesn't contain this (defined by object base) so we need a pragma
    ---@diagnostic disable-next-line: undefined-field
    self.inputEventHandler = InputEventHandler:new()
    self.inputEventHandler:Init()

    self.inputEventHandler:AddKeyPressedEvent(
        "RotateObject",
        function()
            self:NewTrainPosition()
            return true
        end
    )

    self.inputEventHandler:AddKeyPressedEvent(
        "AdvancedMove",
        function()
            if self.trackMode == ADVMOVE_TRACKMODE then
                AdvMoveMode.SwitchTransformMode()
            else
                self:NewWalk()
            end

            return true
        end
    )

    self.inputEventHandler:AddKeyPressedEvent(
        "ScaleObject",
        function()
            logger:Info("Toggle ride camera!")
            if not self.inCamera then
                self:StartTrackCamera()
            else
                self:StopTrackCamera()
            end
            return true
        end
    )

    self.inputEventHandler:AddKeyPressedEvent(
        "ToggleAlignToSurface",
        function()
            logger:Info("Toggle camera mode!")
            SetVariableWithDatastore("cameraIsHeartlineMode", not self.cameraIsHeartlineMode)
            return true
        end
    )

    logger:Info("Spawning draggable widget")
    local DraggableWidgets = require("Editors.Scenery.Utils.DraggableWidgets")
    self.draggableWidget = DraggableWidgets:new()
    logger:Info("Finished Draggable Widget")

    self.draggableWidget:BindButtonHandlers(
        function()
            -- Confirm (unused)
        end,
        function()
            -- Cancel (unused)
        end,
        function()
            -- Move button (unused)
        end,
        function()
            -- Toggle mode
            AdvMoveMode.SwitchTransformMode()
            protrackManager.staticSelf:SetTrackBuilderDirty()
        end,
        function()
            -- Toggle transform space
            AdvMoveMode.SwitchTransformSpace()
            protrackManager.staticSelf:SetTrackBuilderDirty()
        end
    )

    protrackManager.overlayUI:Show()
end

function protrackManager.EndEditMode(self)
    self:ZeroData()
    protrackManager.overlayUI:Hide()
    self.draggableWidget = nil
end

function protrackManager.SwitchTrackMode(self, newTrackMode)
    self:EndTrackEdit()
    SetVariableWithDatastore("trackMode", newTrackMode)
    self:StartTrackEdit()
    self:SetTrackBuilderDirty()
end

function protrackManager.StartTrackEdit(self)
    logger:Info("Start edit for mode: " .. global.tostring(self.trackMode))

    if self.trackMode == ADVMOVE_TRACKMODE then
        AdvMoveMode.StartEdit(self.draggableWidget, Datastore.trackEntityTransform)
    end
end

function protrackManager.EndTrackEdit(self)
    logger:Info("End edit for mode: " .. global.tostring(self.trackMode))

    if self.trackMode == FVD_TRACKMODE then
        FvdMode.EndEdit()
    elseif self.trackMode == ADVMOVE_TRACKMODE then
        AdvMoveMode.EndEdit()
    end
end

function protrackManager.SetTrackBuilderDirty(self)
    if (self.trackEditMode ~= nil and self.trackEditMode.tActiveData ~= nil) then
        self.trackEditMode.tActiveData.bEditValuesDirty = true
        self.trackEditMode.trackHandles:SetTrackWidgetsFromEditValues() -- refresh ui widgets
    end
end

function protrackManager.NewTrainPosition(self)
    logger:Info("NewTrainPosition()")
    local trackEntity = self.trackEditMode.tActiveData:GetTrackEntity()

    -- Early exit
    Datastore.trackWalkerOrigin = Utils.GetFirstCarData(trackEntity)
    if Datastore.trackWalkerOrigin == nil then
        return
    end

    if mathUtils.ApproxEquals(Datastore.trackWalkerOrigin.speed, 0) then
        return
    end

    -- set dt to 0 since we are moving refpoint
    self.simulationTime = 0
    self:NewWalk()
    self:SetTrackBuilderDirty()
end

function protrackManager.ClearWalkerOrigin(self)
    Datastore.trackWalkerOrigin = nil
    self.line:ClearPoints()
    Gizmo.SetMarkerGizmosVisible(false)
    Gizmo.SetTrackGizmosVisible(false)
    self:StopTrackCamera()

    -- Datastore
    api.ui2.SetDataStoreElement(protrackManager.context, "hasData", false)
end

function protrackManager.NewWalk(self)
    Datastore.tDatapoints = nil

    if not Utils.IsTrackOriginValid(Datastore.trackWalkerOrigin) then
        logger:Info("Invalid!")
        self:ClearWalkerOrigin()
        return
    end

    Datastore.tDatapoints = Utils.WalkTrack(
        Datastore.trackWalkerOrigin,
        self.frictionValues,
        Datastore.heartlineOffset,
        Datastore.tSimulationDelta
    )

    -- if nil, our point is BS.
    -- Need to clear everything

    if not Datastore.HasData() then
        self:ClearWalkerOrigin()
        return
    end

    -- Set points
    local tPoints = {}
    for i, datapoint in global.ipairs(Datastore.tDatapoints) do
        tPoints[i] = Datastore.trackEntityTransform:ToWorldPos(
            datapoint.transform:GetPos() +
            datapoint.transform:ToWorldDir(Datastore.heartlineOffset)
        )
    end
    self.line:SetPoints(tPoints)

    if self.inCamera then
        self.line:ClearPoints()
    else
        self.line:DrawPoints()
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
        self.line:ClearPoints()
        Gizmo.SetMarkerGizmosVisible(false)
        Cam.StartRideCamera()
        self.inCamera = true
    end

    api.ui2.SetDataStoreElement(protrackManager.context, "inCamera", self.inCamera)
end

function protrackManager.StopTrackCamera(self)
    if self.inCamera then
        self.line:DrawPoints()
        Gizmo.SetTrackGizmosVisible(true)
        Gizmo.SetMarkerGizmosVisible(true)
        Cam.StopRideCamera()
        self.inCamera = false
    end

    api.ui2.SetDataStoreElement(protrackManager.context, "inCamera", self.inCamera)
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

    -- Check if UI thread has demanded that we switch track modes
    if (self.newTrackModeRequest ~= self.trackMode) then
        self:SwitchTrackMode(self.newTrackModeRequest)
        self.newTrackModeRequest = self.trackMode
    end

    -- Check selection
    local newEndEdit = self.trackEditMode.tActiveData:IsAddingAfterSelection()
    if (newEndEdit ~= self.editingTrackEnd) then
        self.editingTrackEnd = newEndEdit
        if self.editingTrackEnd then
            self:StartTrackEdit()
        else
            self:EndTrackEdit()
        end
    end

    -- If we are in advanced move mode, tick it.
    if (self.trackMode == ADVMOVE_TRACKMODE) then
        local tMouseInput = (self.trackEditMode.inputManager):GetMouseInput()
        local tGamepadAxisInput = (self.trackEditMode.inputManager):GetGamepadAxisData()
        if AdvMoveMode.Advance(deltaTime, tMouseInput, tGamepadAxisInput) then
            self:SetTrackBuilderDirty()
        end
    end

    -- If a change has happened, we want to know!
    if (self.trackEditMode:HasRequestedChange()) then
        self:NewWalk()
    end

    -- Work out direction
    local direction = 0
    if (self.inputManagerAPI:GetKeyDown("DecreaseBrushIntensity")) then
        direction = direction - 1
    end
    if (self.inputManagerAPI:GetKeyDown("IncreaseBrushIntensity")) then
        direction = direction + 1
    end

    -- If keybinds are not held, respect the playingDir
    if (direction == 0) then
        direction = self.playingInDir
    end

    -- Set gizmo visiblity
    --Gizmo.Visible(not self.inCamera)

    local hasData = Datastore.HasData()
    api.ui2.SetDataStoreElement(protrackManager.context, "hasData", hasData)

    if hasData then
        if Datastore.trackWalkerOrigin == nil or Datastore.trackEntityTransform == nil then
            self:ClearWalkerOrigin()
            return
        end

        local timestep = api.time.GetDeltaTimeUnscaled()
        self.simulationTime = self.simulationTime + timestep * direction

        -- clamp dt to make it stay in bounds
        self.simulationTime = mathUtils.Clamp(self.simulationTime, 0, Datastore.GetTimeLength())

        -- Set datastore
        api.ui2.SetDataStoreElement(protrackManager.context, "time", self.simulationTime / Datastore.GetTimeLength())

        local pt = Datastore.SampleDatapointAtTime(self.simulationTime)
        if pt == nil then
            return
        end

        local wsTrans = Datastore.trackEntityTransform:ToWorld(pt.transform)
        local wsCamOffset = wsTrans:ToWorldDir(Datastore.trackWalkerOrigin.camOffset)
        local wsHeartlineOffset = wsTrans:ToWorldDir(Datastore.heartlineOffset)

        -- Pick between both heartline and standard viewing
        local wsCamOffsetUsed = wsCamOffset
        if self.cameraIsHeartlineMode then
            wsCamOffsetUsed = wsHeartlineOffset
        end

        ---@diagnostic disable-next-line: param-type-mismatch
        api.transform.SetPosition(Cam.PreviewCameraEntity, wsTrans:GetPos() + wsCamOffsetUsed)
        api.transform.SetOrientation(Cam.PreviewCameraEntity, wsTrans:GetOr())

        Gizmo.SetMarkerData(wsTrans:WithPos(wsTrans:GetPos() + wsHeartlineOffset), pt.g)

        --  logger:Info("getting datapoints")
        local indexDatapoint = Datastore.GetFloorIndexForTime(self.simulationTime)

        local numDatapoints = Datastore.GetNumDatapoints()

        -- logger:Info(table.tostring(indexDatapoint) ..
        --     "/" .. table.tostring(numDatapoints) .. " | " .. table.tostring(pt.g:GetY()) ..
        --     "," .. table.tostring(pt.g:GetX()))
        -- logger:Info("Sending current keyframe")
        api.ui2.SetDataStoreElement(protrackManager.context, "currKeyframe", indexDatapoint)
        -- logger:Info("Sending keyframe count")
        api.ui2.SetDataStoreElement(protrackManager.context, "keyframeCount", numDatapoints)
        -- logger:Info("Sending vertical gforce")
        api.ui2.SetDataStoreElement(protrackManager.context, "vertGForce", pt.g:GetY())
        -- logger:Info("Sending lateral gforce")
        api.ui2.SetDataStoreElement(protrackManager.context, "latGForce", pt.g:GetX())
        --logger:Info("Sending speed")
        api.ui2.SetDataStoreElement(protrackManager.context, "speed",
            UnitConversion.Speed_ToUserPref(pt.speed, UnitConversion.Speed_MS))
    end
end

--/ Validate class methods and interfaces, the game needs
--/ to validate the Manager conform to the module requirements.
Mutators.VerifyManagerModule(protrackManager)
