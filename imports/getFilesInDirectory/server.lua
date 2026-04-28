--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

---List files in a directory inside a resource. Returns paths relative to
---`path` so each entry can be appended back to it for further use.
---
---@param path string  resource-relative path, optionally `@resource/subdir` for cross-resource
---@param pattern string  Lua pattern matched against each returned path
---@param recursive? boolean  walk subdirectories (default false)
---@return string[] files
---@return integer fileCount
function lib.getFilesInDirectory(path, pattern, recursive)
    local resource = cache.resource

    if path:find('^@') then
        resource = path:gsub('^@(.-)/.+', '%1')
        path = path:sub(#resource + 3)
    end

    -- os.getenv('OS') isn't reliable across all FXServer environments. The
    -- resource path itself tells us: drive letter or backslash means Windows.
    local rawPath = GetResourcePath(resource)
    local windows = rawPath:find('\\', 1, true) ~= nil or rawPath:match('^%a:') ~= nil
    local resourcePath = rawPath:gsub('\\', '/'):gsub('//', '/')
    local relRoot = path:gsub('\\', '/'):gsub('/$', ''):gsub('^/', '')
    local fullDir = ('%s/%s'):format(resourcePath, relRoot):gsub('//', '/'):gsub('/$', '')

    local cmd
    if recursive then
        if windows then
            cmd = ('dir "%s" /b /s /a-d 2>&1'):format(fullDir:gsub('/', '\\'))
        else
            cmd = ('find "%s" -type f 2>&1'):format(fullDir)
        end
    else
        if windows then
            cmd = ('dir "%s" /b 2>&1'):format(fullDir:gsub('/', '\\'))
        else
            cmd = ('ls "%s" 2>&1'):format(fullDir)
        end
    end

    local pipe = io.popen(cmd)
    if not pipe then return {}, 0 end

    local files = {}
    local fileCount = 0
    local prefix = fullDir .. '/'

    for line in pipe:lines() do
        -- Windows io.popen leaves trailing \r, which breaks end-of-string patterns.
        line = line:gsub('[\r\n]+$', '')
        if line ~= '' and line ~= '.' and line ~= '..' then
            local normalized = line:gsub('\\', '/')
            -- Some shells return full paths (Windows `dir /s`, unix `find`),
            -- others return bare filenames. Slash presence tells us which.
            local rel
            if normalized:find('/', 1, true) then
                rel = normalized:sub(#prefix + 1)
                if rel:sub(1, 1) == '/' then rel = rel:sub(2) end
            else
                rel = normalized
            end
            if rel ~= '' and rel:match(pattern) then
                fileCount = fileCount + 1
                files[fileCount] = rel
            end
        end
    end

    pipe:close()
    return files, fileCount
end

return lib.getFilesInDirectory
