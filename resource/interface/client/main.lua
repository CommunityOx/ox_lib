--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

---@alias IconProp 'fas' | 'far' | 'fal' | 'fat' | 'fad' | 'fab' | 'fak' | 'fass'

local keepInput = IsNuiFocusKeepingInput()

function lib.setNuiFocus(allowInput, disableCursor)
    keepInput = IsNuiFocusKeepingInput()
    SetNuiFocus(true, not disableCursor)
    SetNuiFocusKeepInput(allowInput)
end

function lib.resetNuiFocus()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(keepInput)
end

function lib.closeAllNui(except)
    if except ~= 'context' and lib.getOpenContextMenu() then
        lib.hideContext(false)
    end
    if except ~= 'menu' and lib.getOpenMenu() then
        lib.hideMenu(false)
    end
    if except ~= 'input' then
        lib.closeInputDialog()
    end
    if except ~= 'alert' then
        lib.closeAlertDialog()
    end
    if except ~= 'radial' then
        lib.hideRadial()
    end
end
