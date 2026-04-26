-- Recursive *.test.lua discovery from `ox_test_dir` manifest entries, plus
-- single-file register().

local TEST_FILE_PATTERN <const> = '%.test%.lua$'

local M = {}

---Discover and load test files. Reads `ox_test_dir` metadata entries from the
---resource and recursively scans each declared directory for `*.test.lua`.
---@param resource? string defaults to the calling resource
---@return integer count number of test files successfully loaded
function M.discover(resource)
    resource = resource or GetCurrentResourceName()

    local state = GetResourceState(resource)
    if state == 'missing' or state == 'unknown' then
        lib.print.error(('resource %q is %s, copy it into resources/ and `ensure` it first'):format(resource, state))
        return 0
    end
    if state ~= 'started' then
        lib.print.warn(('resource %q state is %q (not started), run `ensure %s` first'):format(resource, state, resource))
        return 0
    end

    local dirCount = GetNumResourceMetadata(resource, 'ox_test_dir') or 0
    if dirCount == 0 then
        lib.print.warn(('resource %q declares no `ox_test_dir` entries in fxmanifest'):format(resource))
        return 0
    end

    local loaded = 0
    for i = 0, dirCount - 1 do
        local dir = GetResourceMetadata(resource, 'ox_test_dir', i)
        if dir then
            local files = lib.getFilesInDirectory(('@%s/%s'):format(resource, dir), TEST_FILE_PATTERN, true)
            print(('^5[ox_lib:test]^7 scanning %s/%s, %d *.test.lua file(s) found'):format(resource, dir, #files))
            for j = 1, #files do
                local relPath = ('%s/%s'):format(dir, files[j])
                local file = LoadResourceFile(resource, relPath)
                if file then
                    local chunk, err = load(file, ('@@%s/%s'):format(resource, relPath), 't', _ENV)
                    if chunk then
                        local ok, runErr = pcall(chunk)
                        if ok then
                            loaded = loaded + 1
                        else
                            lib.print.error(('error registering %s/%s: %s'):format(resource, relPath, runErr))
                        end
                    else
                        lib.print.error(('failed to compile %s/%s: %s'):format(resource, relPath, err))
                    end
                end
            end
        end
    end
    return loaded
end

---Load a single test file. Path can be `tests/foo.test.lua` (current resource)
---or `@resource/tests/foo.test.lua` (cross-resource). Loaded raw via
---LoadResourceFile rather than lib.load because lib.load treats `.` as a Lua
---module separator and would mangle the `.lua` extension.
---@param path string
function M.register(path)
    if type(path) ~= 'string' then error("register(path): path must be a string", 2) end
    local resource, relPath = path:match('^@([^/]+)/(.+)$')
    if not resource then
        resource = cache.resource
        relPath = path
    end
    local file = LoadResourceFile(resource, relPath)
    if not file then error(("test file '%s' not found"):format(path), 2) end
    local chunk, err = load(file, ('@@%s/%s'):format(resource, relPath), 't', _ENV)
    if not chunk then error(("failed to compile '%s': %s"):format(path, err), 2) end
    chunk()
end

return M
