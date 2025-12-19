----
--- ~~copied~~ Based off Parker's PC:CC UI implimentation and TooMuchScaling ~ Coppertine
----
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
---@class ForceOverlay
local ForceOverlay      = module(..., Object.subclass(GamefaceUIWrapper))
local ObjectNew         = ForceOverlay.new

function ForceOverlay:new(_fnOnReadyCallback)
	logger:Info("New ForceOverlay")
	local oNewForceOverlay = ObjectNew(ForceOverlay)
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
	logger:Info("Attempting to Init Overlay UI")
	oNewForceOverlay:Init(tInitSettings)
	return oNewForceOverlay
end

-- Button responders

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
	self:AddEventListener("ProtrackHeartlineChanged", 1, _callback, _self)
end

function ForceOverlay:AddListener_VertGValueChanged(_callback, _self)
	---@diagnostic disable-next-line: undefined-field
	self:AddEventListener("ProtrackVertGChanged", 1, _callback, _self)
end

function ForceOverlay:AddListener_LatGValueChanged(_callback, _self)
	---@diagnostic disable-next-line: undefined-field
	self:AddEventListener("ProtrackLatGChanged", 1, _callback, _self)
end

function ForceOverlay:AddListener_TrackModeChanged(_callback, _self)
	---@diagnostic disable-next-line: undefined-field
	self:AddEventListener("ProtrackTrackModeChanged", 1, _callback, _self)
end

function ForceOverlay:AddListener_HeartlineCamChanged(_callback, _self)
	---@diagnostic disable-next-line: undefined-field
	self:AddEventListener("ProtrackHeartlineCamChanged", 1, _callback, _self)
end

function ForceOverlay:AddListener_TimeChanged(_callback, _self)
	---@diagnostic disable-next-line: undefined-field
	self:AddEventListener("Protrack_TimeChanged", 1, _callback, _self)
end

function ForceOverlay:AddListener_PlayChanged(_callback, _self)
	---@diagnostic disable-next-line: undefined-field
	self:AddEventListener("Protrack_PlayChanged", 1, _callback, _self)
end

function ForceOverlay:Show()
	logger:Info("Showing Overlay")
	---@diagnostic disable-next-line: undefined-field
	self:TriggerEventAtNextAdvance("Show")
end

function ForceOverlay:Hide()
	logger:Info("Hiding Overlay")
	---@diagnostic disable-next-line: undefined-field
	self:TriggerEventAtNextAdvance("Hide")
end
