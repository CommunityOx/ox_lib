--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

---@class DuiProperties
---@field url string
---@field width number
---@field height number
---@field debug? boolean

---@class Dui : OxClass
---@field private private { id: string, debug: boolean, slotIndex: number }
---@field url string
---@field duiObject number
---@field duiHandle string
---@field txdObject number
---@field dictName string
---@field txtName string
lib.dui = lib.class('Dui')

---@type table<string, Dui>
local duis = {}

local currentId = 0

-- Pool configuration
local POOL_SIZE = 50
local POOL_TXD_NAME = "ox_lib_dui_pool"
local poolTxd = nil
---@type table<number, { used: boolean, txdObject: number|nil, version: number }>
local textureSlots = {}

local function initPool()
    if poolTxd then return end
    poolTxd = CreateRuntimeTxd(POOL_TXD_NAME)
    for i = 1, POOL_SIZE do
        textureSlots[i] = { used = false, txdObject = nil, version = 0 }
    end
end

---@return number|nil slotIndex
local function acquireSlot()
    initPool()
    for i = 1, POOL_SIZE do
        if not textureSlots[i].used then
            textureSlots[i].used = true
            textureSlots[i].version = textureSlots[i].version + 1
            return i
        end
    end
    return nil
end

---@param slotIndex number
local function releaseSlot(slotIndex)
    if slotIndex and textureSlots[slotIndex] then
        textureSlots[slotIndex].used = false
    end
end

---@param slotIndex number
---@param version number
---@return string
local function getSlotTextureName(slotIndex, version)
    return ("ox_lib_dui_txt_%d_v%d"):format(slotIndex, version)
end

---@param data DuiProperties
function lib.dui:constructor(data)
    local slotIndex = acquireSlot()
    if not slotIndex then
        error(("No available texture slots in pool (max %d)"):format(POOL_SIZE))
    end

    local time = GetGameTimer()
    local id = ("%s_%s_%s"):format(cache.resource, time, currentId)
    currentId = currentId + 1

    local txtName = getSlotTextureName(slotIndex, textureSlots[slotIndex].version)
    local duiObject = CreateDui(data.url, data.width, data.height)
    local duiHandle = GetDuiHandle(duiObject)
    local txdObject = CreateRuntimeTextureFromDuiHandle(poolTxd, txtName, duiHandle)

    textureSlots[slotIndex].txdObject = txdObject

    self.private.id = id
    self.private.debug = data.debug or false
    self.private.slotIndex = slotIndex
    self.url = data.url
    self.duiObject = duiObject
    self.duiHandle = duiHandle
    self.txdObject = txdObject
    self.dictName = POOL_TXD_NAME
    self.txtName = txtName
    duis[id] = self

    if self.private.debug then
        print(('Dui %s created (slot %d)'):format(id, slotIndex))
    end
end

function lib.dui:remove()
    SetDuiUrl(self.duiObject, 'about:blank')
    DestroyDui(self.duiObject)
    releaseSlot(self.private.slotIndex)
    duis[self.private.id] = nil

    if self.private.debug then
        print(('Dui %s removed (slot %d released)'):format(self.private.id, self.private.slotIndex))
    end
end

---@param url string
function lib.dui:setUrl(url)
    self.url = url
    SetDuiUrl(self.duiObject, url)

    if self.private.debug then
        print(('Dui %s url set to %s'):format(self.private.id, url))
    end
end

---@param message table
function lib.dui:sendMessage(message)
    SendDuiMessage(self.duiObject, json.encode(message))

    if self.private.debug then
        print(('Dui %s message sent with data :'):format(self.private.id), json.encode(message, { indent = true }))
    end
end

---@param x number
---@param y number
function lib.dui:sendMouseMove(x, y)
    SendDuiMouseMove(self.duiObject, x, y)
end

---@param button 'left' | 'middle' | 'right'
function lib.dui:sendMouseDown(button)
    SendDuiMouseDown(self.duiObject, button)
end

---@param button 'left' | 'middle' | 'right'
function lib.dui:sendMouseUp(button)
    SendDuiMouseUp(self.duiObject, button)
end

---@param deltaX number
---@param deltaY number
function lib.dui:sendMouseWheel(deltaX, deltaY)
    SendDuiMouseWheel(self.duiObject, deltaY, deltaX)
end

AddEventHandler('onResourceStop', function(resourceName)
    if cache.resource ~= resourceName then return end

    for _, dui in pairs(duis) do
        dui:remove()
    end
end)

return lib.dui
