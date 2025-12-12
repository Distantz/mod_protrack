local global  = _G
---@type Api
---@diagnostic disable-next-line: undefined-field
local api     = global.api
local require = global.require

local Line    = {}
Line.__index  = Line

function Line.new()
    local self      = global.setmetatable({}, Line)
    self.volumesAPI = nil
    self.guiShape   = nil
    self.guiDrawing = nil
    self.guiVisual  = 6
    self.tPoints    = {}
    self.volumesAPI = api.world.GetWorldAPIs().volumes
    self.guiShape   = self.volumesAPI:CreateDrawingShape()
    self.guiDrawing = self.volumesAPI:AllocDrawingID(self.guiShape)
    return self
end

function Line:SetPoints(tPoints)
    self.tPoints = tPoints
end

function Line:DrawPoints()
    self:ClearPoints()
    self.volumesAPI:BeginDrawing(self.guiShape, self.guiDrawing)

    for i = 2, #self.tPoints do
        local vStart = self.tPoints[i - 1]
        local vEnd   = self.tPoints[i]
        self.volumesAPI:AddDrawingLine(self.guiShape, vStart, vEnd, self.guiVisual)
    end

    self.volumesAPI:EndDrawing(self.guiShape, self.guiDrawing)
end

function Line:ClearPoints()
    self.volumesAPI:EraseDrawing(self.guiShape, self.guiDrawing)
end

return Line
