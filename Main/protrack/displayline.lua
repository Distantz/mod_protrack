local global     = _G
---@type Api
---@diagnostic disable-next-line: undefined-field
local api        = global.api
local pairs      = global.pairs
local table      = require("Common.tableplus")
local Utils      = require("protrack.utils")
local coroutine  = global.coroutine
local require    = global.require
local logger     = require("forgeutils.logger").Get("ProTrackHeartline")
local TransformQ = require("TransformQ")
local mathUtils  = require("Common.mathUtils")

local Line       = {}
Line.volumesAPI  = nil
Line.guiShape    = nil
Line.guiDrawing  = nil
Line.tPoints     = {}

function Line.InitLine()
    logger:Info("InitLine")
    Line.volumesAPI = api.world.GetWorldAPIs().volumes
    Line.guiShape = Line.volumesAPI:CreateDrawingShape()
    Line.guiDrawing = Line.volumesAPI:AllocDrawingID(Line.guiShape)
    Line.guiVisual = 6
end

function Line.SetPoints(tPoints)
    Line.tPoints = tPoints
end

function Line.DrawPoints()
    Line.ClearPoints()
    Line.volumesAPI:BeginDrawing(Line.guiShape, Line.guiDrawing)
    for i = 2, #Line.tPoints do
        local vStart, vEnd = Line.tPoints[i - 1], Line.tPoints[i]
        Line.volumesAPI:AddDrawingLine(Line.guiShape, vStart, vEnd, Line.guiVisual)
    end
    Line.volumesAPI:EndDrawing(Line.guiShape, Line.guiDrawing)
end

function Line.ClearPoints()
    Line.volumesAPI:EraseDrawing(Line.guiShape, Line.guiDrawing)
end

return Line
