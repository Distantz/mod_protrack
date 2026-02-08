local global            = _G
---@type Api
---@diagnostic disable-next-line: undefined-field
local api               = global.api
local require           = global.require

---@diagnostic disable-next-line: deprecated
local module            = global.module
local Object            = require("Common.object")
local GamefaceUIWrapper = require("UI.GamefaceUIWrapper")
local table             = require("Common.tableplus")
local logger            = require("forgeutils.logger").Get("ProTrackForceOverlay")
---@class protrack.ui.ProtrackUIWrapper : GamefaceUIWrapper
---@field mainContext table The main protrack datastore table
local ForceOverlay      = module(..., Object.subclass(GamefaceUIWrapper))
local constructor       = ForceOverlay.new

function ForceOverlay:new(_fnOnReadyCallback)
	---@type protrack.ui.ProtrackUIWrapper
	local slf = constructor(ForceOverlay)
	slf.mainContext = api.ui2.GetDataStoreContext("ProTrack")

	-- Set defaults
	slf.cameraIsHeartlineMode = false
	slf.inCamera = false
	slf.trackMode = 0
	slf.heartline = 0.0
	slf.forceLockVertG = 0.0
	slf.forceLockLatG = 0.0
	slf.playingInDir = 0
	slf.time = 0

	local tInitSettings = {
		sViewName = "ProTrackUI",
		sViewAddress = "coui://UIGameface/ProTrack_CamForceOverlay.html",
		bStartEnabled = true,
		fnOnReadyCallback = _fnOnReadyCallback,
		nViewDepth = 0,
		nViewHeight = 1920,
		nViewWidth = 1080,
		bRegisterWrapper = true
	}
	slf:Init(tInitSettings)
	return slf
end

--#region Property getters/setters

---@param value boolean
function ForceOverlay:Set_CameraIsHeartlineMode(value)
	self.cameraIsHeartlineMode = value
	api.ui2.SetDataStoreElement(self.mainContext, "cameraIsHeartlineMode", value)
end

---@return boolean
function ForceOverlay:Get_CameraIsHeartlineMode()
	return self.cameraIsHeartlineMode
end

---@param value boolean
function ForceOverlay:Set_InCamera(value)
	self.inCamera = value
	api.ui2.SetDataStoreElement(self.mainContext, "inCamera", value)
end

---@return boolean
function ForceOverlay:Get_InCamera()
	return self.inCamera
end

---@param value integer
function ForceOverlay:Set_TrackMode(value)
	self.trackMode = value
	api.ui2.SetDataStoreElement(self.mainContext, "trackMode", value)
end

---@return integer
function ForceOverlay:Get_TrackMode()
	return self.trackMode
end

---@param value number
function ForceOverlay:Set_Heartline(value)
	self.heartline = value
	api.ui2.SetDataStoreElement(self.mainContext, "heartline", value)
end

---@return number
function ForceOverlay:Get_Heartline()
	return self.heartline
end

---@param value number
function ForceOverlay:Set_ForceLockVertG(value)
	self.forceLockVertG = value
	api.ui2.SetDataStoreElement(self.mainContext, "forceLockVertG", value)
end

---@return number
function ForceOverlay:Get_ForceLockVertG()
	return self.forceLockVertG
end

---@param value number
function ForceOverlay:Set_ForceLockLatG(value)
	self.forceLockLatG = value
	api.ui2.SetDataStoreElement(self.mainContext, "forceLockLatG", value)
end

---@return number
function ForceOverlay:Get_ForceLockLatG()
	return self.forceLockLatG
end

---@param value integer
function ForceOverlay:Set_PlayingInDir(value)
	self.playingInDir = value
	api.ui2.SetDataStoreElement(self.mainContext, "playingInDir", value)
end

---@return integer
function ForceOverlay:Get_PlayingInDir()
	return self.playingInDir
end

---@param value integer
function ForceOverlay:Set_Time(value)
	self.time = value
	api.ui2.SetDataStoreElement(self.mainContext, "time", value)
end

---@return integer
function ForceOverlay:Get_Time()
	return self.time
end

--#endregion

-- #region Button responders

function ForceOverlay:AddListener_ReanchorRequested(_callback, _self)
	---@diagnostic disable-next-line: undefined-field
	self:AddEventListener("Protrack_ReanchorRequested", 1, _callback, _self)
end

function ForceOverlay:AddListener_ResimulateRequested(_callback, _self)
	---@diagnostic disable-next-line: undefined-field
	self:AddEventListener("Protrack_ResimulateRequested", 1, _callback, _self)
end

function ForceOverlay:AddListener_ChangeCamModeRequested(_callback, _self)
	---@diagnostic disable-next-line: undefined-field
	self:AddEventListener("Protrack_ChangeCamModeRequested", 1, _callback, _self)
end

-- Value change listeners

function ForceOverlay:AddListener_HeartlineValueChanged(_callback, _self)
	---@diagnostic disable-next-line: undefined-field
	self:AddEventListener("Protrack_HeartlineChanged", 1, _callback, _self)
end

function ForceOverlay:AddListener_VertGValueChanged(_callback, _self)
	---@diagnostic disable-next-line: undefined-field
	self:AddEventListener("Protrack_VertGChanged", 1, _callback, _self)
end

function ForceOverlay:AddListener_LatGValueChanged(_callback, _self)
	---@diagnostic disable-next-line: undefined-field
	self:AddEventListener("Protrack_LatGChanged", 1, _callback, _self)
end

function ForceOverlay:AddListener_TrackModeChanged(_callback, _self)
	---@diagnostic disable-next-line: undefined-field
	self:AddEventListener("Protrack_TrackModeChanged", 1, _callback, _self)
end

function ForceOverlay:AddListener_HeartlineCamChanged(_callback, _self)
	---@diagnostic disable-next-line: undefined-field
	self:AddEventListener("Protrack_HeartlineCamChanged", 1, _callback, _self)
end

function ForceOverlay:AddListener_TimeChanged(_callback, _self)
	---@diagnostic disable-next-line: undefined-field
	self:AddEventListener("Protrack_TimeChanged", 1, _callback, _self)
end

function ForceOverlay:AddListener_PlayChanged(_callback, _self)
	---@diagnostic disable-next-line: undefined-field
	self:AddEventListener("Protrack_PlayChanged", 1, _callback, _self)
end

function ForceOverlay:TriggerShow()
	logger:Info("Showing Overlay")
	---@diagnostic disable-next-line: undefined-field
	self:TriggerEventAtNextAdvance("Show")
end

function ForceOverlay:TriggerHide()
	logger:Info("Hiding Overlay")
	---@diagnostic disable-next-line: undefined-field
	self:TriggerEventAtNextAdvance("Hide")
end

-- #endregion

return ForceOverlay
