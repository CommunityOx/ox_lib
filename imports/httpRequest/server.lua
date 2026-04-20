local authorizedMethods = {
    ['GET'] = true,
    ['POST'] = true,
    ['PUT'] = true,
    ['DELETE'] = true,
    ['PATCH'] = true,
}

---@async
---@param url string
---@param method? "GET" | "POST" | "PUT" | "DELETE" | "PATCH"
---@param data? string
---@param headers? table
---@param options? table
---@return table | boolean
function lib.httpRequest(url, method, data, headers, options)
    method = method or "GET"
    headers = headers or {}
    options = options or {}

    if not authorizedMethods[method] then
        lib.print.error(('Invalid HTTP method "%s"'):format(method))
        return false
    end

    local p = promise.new()
    PerformHttpRequest(url, function(status, body, responseHeaders, errorData)
        p:resolve({
            status = status,
            body = body,
            headers = responseHeaders,
            error = errorData,
        })
    end, method, data, headers, options)

    Citizen.Await(p)
    return p.value
end

return lib.httpRequest
