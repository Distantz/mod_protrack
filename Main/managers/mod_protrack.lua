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

local TrackPointGizmo = require("protrack.gizmo.trackpointgizmo")
local TrackReferenceGizmo = require("protrack.gizmo.trackreferencegizmo")

local Cam = require("protrack.cam")
local Datastore = require("protrack.datastore")
local FrictionHelper = require("database.frictionhelper")
local InputEventHandler = require("Components.Input.InputEventHandler")
local UIWrapper = require("protrack.ui.protrackuiwrapper")
local UnitConversion = require("Helpers.UnitConversion")

local logger = require("forgeutils.logger").Get("ProTrackManager", "INFO")

--/ Main class definition
---@class protrackManager
local protrackManager = module(..., Mutators.Manager())

---@type protrack.ui.ProtrackUIWrapper
protrackManager.uiWrapper = nil

-- Main variables

protrackManager.simulationTime = 0
---@type TrackEditMode?
protrackManager.trackEditMode = nil
protrackManager.editingTrackEnd = false
protrackManager.inputEventHandler = nil
protrackManager.line = nil

---@type WorldAPIs_InputManager
protrackManager.inputManagerAPI = nil
protrackManager.tWorldAPIs = nil

---@type FrictionValues
protrackManager.frictionValues = nil

-- Gizmo

---@type DraggableWidgets
protrackManager.draggableWidget = nil
---@type protrack.gizmo.TrackReferenceGizmo
protrackManager.referencePointGizmo = nil
---@type protrack.gizmo.TrackPointGizmo[]
protrackManager.followerGizmos = nil
protrackManager.distances = {}

protrackManager.staticSelf = nil

local NORMAL_TRACKMODE = 0
local FVD_TRACKMODE = 1
local ADVMOVE_TRACKMODE = 2

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

            if (protrackManager.staticSelf.uiWrapper:Get_TrackMode() == FVD_TRACKMODE) and Datastore.HasData() then -- forcelock, remove 1 and 3
                _tItems[1] = {}
                _tItems[3] = {}
            elseif (protrackManager.staticSelf.uiWrapper:Get_TrackMode() == ADVMOVE_TRACKMODE) then -- Advanced widget, remove all
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
            if (protrackManager.staticSelf.uiWrapper:Get_TrackMode() == FVD_TRACKMODE) then
                return FvdMode.StaticBuildEndPoint_Hook(originalMethod, startT, tData)
            elseif (protrackManager.staticSelf.uiWrapper:Get_TrackMode() == ADVMOVE_TRACKMODE) then
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
        "Shutdown",
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
    -- Our entry point simply calls inject on the submode override file:
    logger:Info("Completing spawns...")
    Cam.GetPreviewCameraEntity()
    logger:Info("Finished Camera")

    local line = require("protrack.gizmo.displayline")
    self.line = line:new()
    FvdMode.line = line:new()

    logger:Info("Initialising UI")

    Datastore.heartlineOffset = Vector3.Zero
    protrackManager.uiWrapper = UIWrapper:new(
        function()
            logger:Info("UI is setup and ready")

            -- Button listeners

            protrackManager.uiWrapper:AddListener_ReanchorRequested(
                function()
                    self:NewTrainPosition()
                end,
                nil
            )

            protrackManager.uiWrapper:AddListener_ResimulateRequested(
                function()
                    self:NewWalk()
                end,
                nil
            )

            protrackManager.uiWrapper:AddListener_ChangeCamModeRequested(
                function()
                    if not protrackManager.uiWrapper:Get_InCamera() then
                        self:StartTrackCamera()
                    else
                        self:StopTrackCamera()
                    end
                end,
                nil
            )

            protrackManager.uiWrapper:AddListener_PlayChanged(
                function(newDir)
                    protrackManager.uiWrapper:Set_PlayingInDir(newDir)
                end,
                nil
            )

            -- Value listeners

            protrackManager.uiWrapper:AddListener_HeartlineValueChanged(
                function(newVal)
                    protrackManager.uiWrapper:Set_Heartline(newVal)
                    Datastore.heartlineOffset = Vector3:new(0, newVal, 0)
                    self:NewWalk()
                    self:SetTrackBuilderDirty()
                end,
                nil
            );

            protrackManager.uiWrapper:AddListener_VertGValueChanged(
                function(newVal)
                    protrackManager.uiWrapper:Set_ForceLockVertG(newVal)
                    self:SetTrackBuilderDirty()
                end,
                nil
            );

            protrackManager.uiWrapper:AddListener_LatGValueChanged(
                function(newVal)
                    protrackManager.uiWrapper:Set_ForceLockLatG(newVal)
                    self:SetTrackBuilderDirty()
                end,
                nil
            );

            protrackManager.uiWrapper:AddListener_TrackModeChanged(
                function(newTrackMode)
                    -- Call is delayed like this to exit
                    -- the UI thread.
                    self:SwitchTrackMode(newTrackMode)
                end,
                nil
            );

            protrackManager.uiWrapper:AddListener_HeartlineCamChanged(
                function(heartlineCamMode)
                    protrackManager.uiWrapper:Set_CameraIsHeartlineMode(heartlineCamMode)
                end,
                nil
            );

            protrackManager.uiWrapper:AddListener_TimeChanged(
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
    self.editingTrackEnd = false
    self.simulationTime = 0
    self.tWorldAPIs = nil
    self.inputManagerAPI = nil
    Datastore.datapoints = nil

    -- Datastore updates
    protrackManager.uiWrapper:Set_PlayingInDir(0)
    protrackManager.uiWrapper:Set_TrackMode(0)
    protrackManager.uiWrapper:Set_ForceLockVertG(1)
    protrackManager.uiWrapper:Set_ForceLockLatG(0)
end

function protrackManager.StartEditMode(self, trackEditMode)
    logger:Info("Starting edit mode!")

    -- Reset data
    logger:Info("Resetting data")
    self:ZeroData()
    logger:Info("Done")

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
            if self.uiWrapper:Get_TrackMode() == ADVMOVE_TRACKMODE and self.editingTrackEnd then
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
            if not protrackManager.uiWrapper:Get_InCamera() then
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
            protrackManager.uiWrapper:Set_CameraIsHeartlineMode(
                not protrackManager.uiWrapper:Get_CameraIsHeartlineMode()
            )
            return true
        end
    )

    logger:Info("Spawning draggable widget")
    local DraggableWidgets = require("Editors.Scenery.Utils.DraggableWidgets")
    self.draggableWidget = DraggableWidgets:new()
    logger:Info("Finished Draggable Widget")

    logger:Info("Spawning world-space gizmos")

    self.followerGizmos = {
        [1] = TrackPointGizmo.new(),
        [2] = TrackPointGizmo.new(),
        [3] = TrackPointGizmo.new(),
    }
    for _, gizmo in global.ipairs(self.followerGizmos) do
        gizmo:SetVisible(false)
    end

    self.referencePointGizmo = TrackReferenceGizmo.new()
    self.referencePointGizmo:SetVisible(false)
    logger:Info("Finished world-space gizmos")

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
    protrackManager.uiWrapper:TriggerShow()
end

local function shutdownGizmo(gizmo)
    if gizmo ~= nil then
        gizmo:Shutdown()
    end
end

function protrackManager.EndEditMode(self)
    self:ZeroData()
    protrackManager.uiWrapper:TriggerHide()

    shutdownGizmo(self.draggableWidget)
    shutdownGizmo(self.referencePointGizmo)

    self.draggableWidget = nil

    -- Shut down all gizmos
    for _, gizmo in global.ipairs(self.followerGizmos) do
        shutdownGizmo(gizmo)
    end
    logger:Info("Clearing gizmo")
    self.followerGizmos = nil
end

function protrackManager.SwitchTrackMode(self, newTrackMode)
    self:EndTrackEdit()
    protrackManager.uiWrapper:Set_TrackMode(newTrackMode)
    self:StartTrackEdit()
    self:SetTrackBuilderDirty()
end

function protrackManager.StartTrackEdit(self)
    local trackMode = self.uiWrapper:Get_TrackMode()
    if trackMode == FVD_TRACKMODE then
        FvdMode.StartEdit(self.uiWrapper)
    elseif trackMode == ADVMOVE_TRACKMODE then
        AdvMoveMode.StartEdit(self.draggableWidget, Datastore.trackEntityTransform)
    end
end

function protrackManager.EndTrackEdit(self)
    local trackMode = self.uiWrapper:Get_TrackMode()
    if trackMode == FVD_TRACKMODE then
        FvdMode.EndEdit()
    elseif trackMode == ADVMOVE_TRACKMODE then
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
    self.uiWrapper:ClearAllTrainData()
    self.distances = nil
    self.line:ClearPoints()
    if self.referencePointGizmo ~= nil then
        self.referencePointGizmo:SetVisible(false)
    end
    if self.followerGizmos ~= nil then
        for _, gizmo in global.ipairs(self.followerGizmos) do
            gizmo:SetVisible(false)
        end
    end
    self:StopTrackCamera()
end

function protrackManager.NewWalk(self)
    Datastore.datapoints = nil
    if not Utils.IsTrackOriginValid(Datastore.trackWalkerOrigin) then
        logger:Info("Invalid!")
        self:ClearWalkerOrigin()
        return
    end

    local halfLength = Datastore.trackWalkerOrigin.trainLength / 2.0
    self.distances = {
        [1] = halfLength,
        [2] = -halfLength
    }

    Datastore.datapoints = Utils.WalkTrack(
        Datastore.trackWalkerOrigin,
        self.distances,
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

    logger:Info("Line?")
    -- Set points
    local tPoints = {}
    for i, datapoint in global.ipairs(Datastore.datapoints) do
        tPoints[i] = Datastore.trackEntityTransform:ToWorldPos(
            datapoint.measurements[1].transform:GetPos() +
            datapoint.measurements[1].transform:ToWorldDir(Datastore.heartlineOffset)
        )
    end
    self.line:SetPoints(tPoints)

    if protrackManager.uiWrapper:Get_InCamera() then
        self.line:ClearPoints()
    else
        self.line:DrawPoints()
    end

    -- Turn it on
    for _, gizmo in global.ipairs(self.followerGizmos) do
        gizmo:SetVisible(true)
    end
    self.referencePointGizmo:SetVisible(not protrackManager.uiWrapper:Get_InCamera())

    self.referencePointGizmo:SetRefPointTransform(
        Datastore.trackEntityTransform:ToWorld(Utils.TrackTransformToTransformQ(Datastore.trackWalkerOrigin.transform))
    )
    self.referencePointGizmo:SetEndPointTransform(
        Datastore.trackEntityTransform:ToWorld(Datastore.datapoints[#Datastore.datapoints].measurements[1].transform)
    )

    logger:Info("NewWalk over.")
end

function protrackManager.StartTrackCamera(self)
    if Datastore.datapoints == nil then
        return
    end

    if not protrackManager.uiWrapper:Get_InCamera() then
        self.line:ClearPoints()
        for _, gizmo in global.ipairs(self.followerGizmos) do
            gizmo:SetVisible(false)
        end
        Cam.StartRideCamera()
        protrackManager.uiWrapper:Set_InCamera(true)
    end
end

function protrackManager.StopTrackCamera(self)
    if protrackManager.uiWrapper:Get_InCamera() then
        self.line:DrawPoints()
        for _, gizmo in global.ipairs(self.followerGizmos) do
            gizmo:SetVisible(true)
        end
        self.referencePointGizmo:SetVisible(true)
        Cam.StopRideCamera()
        self.uiWrapper:Set_InCamera(false)
    end
end

function protrackManager.Advance(self, deltaTime)
    if self.inputEventHandler == nil or self.inputManagerAPI == nil then
        return
    end

    self.inputEventHandler:CheckEvents()

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
    if (self.uiWrapper:Get_TrackMode() == ADVMOVE_TRACKMODE) then
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
        direction = self.uiWrapper:Get_PlayingInDir()
    end

    -- Set gizmo visiblity
    --Gizmo.Visible(not self.inCamera)

    local hasData = Datastore.HasData()
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
        self.uiWrapper:Set_Time(self.simulationTime / Datastore.GetTimeLength())

        local trainMeasurement = Datastore.SampleDatapointAtTime(self.simulationTime)

        -- Clear data if none
        if trainMeasurement == nil then
            self.uiWrapper:ClearAllTrainData()
            return
        end

        self:UpdateUserInterfaceFromData(trainMeasurement, self.simulationTime)
    end
end

--- Sets UI and Gizmo data based on measurements
---@param trainMeasurement TrainMeasurement
---@param simulationTime number
function protrackManager:UpdateUserInterfaceFromData(trainMeasurement, simulationTime)
    --- Helper func
    ---@param index integer The gizmo index
    ---@param data TrackMeasurement
    ---@param gizmo protrack.gizmo.TrackPointGizmo The gizmo
    local function setGizmoData(index, data, gizmo)
        if data == nil then
            return
        end

        local wsTrans = Datastore.trackEntityTransform:ToWorld(data.transform)
        local wsCamOffset = wsTrans:ToWorldDir(Datastore.trackWalkerOrigin.camOffset)
        local wsHeartlineOffset = wsTrans:ToWorldDir(Datastore.heartlineOffset)

        gizmo:SetTransform(
            wsTrans:WithPos(wsTrans:GetPos() + wsHeartlineOffset)
        )
        gizmo:SetGForce(
            data.g
        )

        -- Only set camera data from first track follower
        if index ~= 1 then
            return
        end

        -- Pick between both heartline and standard viewing
        local wsCamOffsetUsed = wsCamOffset
        if self.uiWrapper:Get_CameraIsHeartlineMode() then
            wsCamOffsetUsed = wsHeartlineOffset
        end

        ---@diagnostic disable-next-line: param-type-mismatch
        api.transform.SetPosition(Cam.PreviewCameraEntity, wsTrans:GetPos() + wsCamOffsetUsed)
        api.transform.SetOrientation(Cam.PreviewCameraEntity, wsTrans:GetOr())
    end

    for i, gizmo in global.ipairs(self.followerGizmos) do
        setGizmoData(i, trainMeasurement.measurements[i], gizmo)
    end

    self.uiWrapper:SetTrainData(
        trainMeasurement,
        Datastore.GetFloorIndexForTime(simulationTime),
        #Datastore.datapoints,
        Datastore.trackEntityTransform,
        Datastore.heartlineOffset
    )
end

--/ Validate class methods and interfaces, the game needs
--/ to validate the Manager conform to the module requirements.
Mutators.VerifyManagerModule(protrackManager)
