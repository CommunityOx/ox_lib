--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

lib.cron = {}

---@alias Date { year: number, month: number, day: number, hour: number, min: number, sec: number, wday: number, yday: number, isdst: boolean }
---@type Date
local currentDate = {}

setmetatable(currentDate, {
    __index = function(self, index)
        local newDate = os.date('*t') --[[@as Date]]
        for k, v in pairs(newDate) do
            self[k] = v
        end
        SetTimeout(1000, function() table.wipe(self) end)
        return self[index]
    end
})

---@class OxTaskProperties
---@field minute? number|string|function
---@field hour? number|string|function
---@field day? number|string|function
---@field month? number|string|function
---@field year? number|string|function
---@field weekday? number|string|function
---@field job fun(task: OxTask, date: osdate)
---@field isActive boolean
---@field id number
---@field debug? boolean
---@field lastRun? number
---@field maxDelay? number Maximum allowed delay in seconds before skipping (0 to disable)

---@class OxTask : OxTaskProperties
---@field expression string
---@field private scheduleTask fun(self: OxTask): boolean?
local OxTask = {}
OxTask.__index = OxTask

local validRanges = {
    min = { min = 0, max = 59 },
    hour = { min = 0, max = 23 },
    day = { min = 1, max = 31 },
    month = { min = 1, max = 12 },
    wday = { min = 0, max = 7 },
}


local weekdayMap = {
    sun = 1,
    mon = 2,
    tue = 3,
    wed = 4,
    thu = 5,
    fri = 6,
    sat = 7,
}

local monthMap = {
    jan = 1, feb = 2, mar = 3, apr = 4,
    may = 5, jun = 6, jul = 7, aug = 8,
    sep = 9, oct = 10, nov = 11, dec = 12
}

---Returns the last day of the specified month
---@param month number
---@param year? number
---@return number
local function getMaxDaysInMonth(month, year)
    return os.date('*t', os.time({ year = year or currentDate.year, month = month + 1, day = 0 })).day --[[@as number]]
end

---@param value string|number
---@param unit string
---@return boolean
local function isValueInRange(value, unit)
    local range = validRanges[unit]
    if not range then return true end
    return value >= range.min and value <= range.max
end

---@param value string
---@param unit string
---@return number|string|function|nil
local function parseCron(value, unit)
    if not value or value == '*' then return end

    if unit == 'day' and value:lower() == 'l' then
        return function(month, year)
            return getMaxDaysInMonth(month or currentDate.month, year or currentDate.year)
        end
    end

    local num = tonumber(value)
    if num then
        if not isValueInRange(num, unit) then
            error(("^1invalid cron expression. '%s' is out of range for %s^0"):format(value, unit), 3)
        end
        return num
    end

    if unit == 'wday' then
        local start, stop = value:match('(%a+)-(%a+)')
        if start and stop then
            start = weekdayMap[start:lower()]
            stop = weekdayMap[stop:lower()]
            if start and stop then
                if stop < start then stop = stop + 7 end
                return ('%d-%d'):format(start, stop)
            end
        end
        local day = weekdayMap[value:lower()]
        if day then return day end
    end

    if unit == 'month' then
        local months = {}
        for month in value:gmatch('[^,]+') do
            local monthNum = monthMap[month:lower()]
            if monthNum then
                months[#months + 1] = tostring(monthNum)
            end
        end
        if #months > 0 then
            return table.concat(months, ',')
        end
    end

    local stepMatch = value:match('^%*/(%d+)$')
    if stepMatch then
        local step = tonumber(stepMatch)
        if not step or step == 0 then
            error(("^1invalid cron expression. Step value cannot be %s^0"):format(step or 'nil'), 3)
        end
        return value
    end

    local start, stop = value:match('^(%d+)-(%d+)$')
    if start and stop then
        start, stop = tonumber(start), tonumber(stop)
        if not start or not stop or not isValueInRange(start, unit) or not isValueInRange(stop, unit) then
            error(("^1invalid cron expression. Range '%s' is invalid for %s^0"):format(value, unit), 3)
        end
        return value
    end

    local valid = true
    for item in value:gmatch('[^,]+') do
        local num = tonumber(item)
        if not num or not isValueInRange(num, unit) then
            valid = false
            break
        end
    end
    if valid then return value end

    error(("^1invalid cron expression. '%s' is not supported for %s^0"):format(value, unit), 3)
end


---Checks if a given value matches a cron field specification.
---@param field number|string|function|nil
---@param value number
---@param candidateMonth? number
---@param candidateYear? number
---@return boolean
local function matchesField(field, value, candidateMonth, candidateYear)
    if not field then return true end

    if type(field) == 'function' then
        return value == field(candidateMonth, candidateYear)
    end

    if type(field) == 'number' then
        return value == field
    end

    local step = field:match('^%*/(%d+)$')
    if step then
        return value % tonumber(step) == 0
    end

    local min, max = field:match('^(%d+)-(%d+)$')
    if min and max then
        min, max = tonumber(min), tonumber(max)
        if max >= min then
            return value >= min and value <= max
        else
            return value >= min or value <= max
        end
    end

    for item in field:gmatch('%d+') do
        if value == tonumber(item) then
            return true
        end
    end

    return false
end

---@return number?
function OxTask:getNextTime()
    if not self.isActive then return end

    local now = os.time()
    local startDate = os.date('*t', now) --[[@as Date]]
    startDate.sec = 0
    startDate.min = startDate.min + 1
    startDate = os.date('*t', os.time(startDate)) --[[@as Date]]

    for dayOffset = 0, 366 do
        local candidate

        if dayOffset == 0 then
            candidate = startDate
        else
            local t = os.time({ year = startDate.year, month = startDate.month, day = startDate.day, hour = 12 }) + dayOffset * 86400
            candidate = os.date('*t', t) --[[@as Date]]
        end

        if matchesField(self.month, candidate.month)
            and matchesField(self.day, candidate.day, candidate.month, candidate.year)
            and matchesField(self.weekday, candidate.wday)
        then
            local startHour = (dayOffset == 0) and startDate.hour or 0

            for h = startHour, 23 do
                if matchesField(self.hour, h) then
                    local startMin = (dayOffset == 0 and h == startDate.hour) and startDate.min or 0

                    for m = startMin, 59 do
                        if matchesField(self.minute, m) then
                            local nextTime = os.time({
                                year = candidate.year,
                                month = candidate.month,
                                day = candidate.day,
                                hour = h,
                                min = m,
                                sec = 0,
                            })

                            if self.lastRun and nextTime - self.lastRun < 60 then
                                if self.debug then
                                    lib.print.debug(('Preventing duplicate execution of task %s - Last run: %s, Next scheduled: %s'):format(
                                        self.id,
                                        os.date('%c', self.lastRun),
                                        os.date('%c', nextTime)
                                    ))
                                end
                            else
                                return nextTime
                            end
                        end
                    end
                end
            end
        end
    end
end

---@return number
function OxTask:getAbsoluteNextTime()
    return self:getNextTime() or os.time()
end

function OxTask:getTimeAsString(timestamp)
    return os.date('%A %H:%M, %d %B %Y', timestamp or self:getAbsoluteNextTime())
end

---@type OxTask[]
local tasks = {}

function OxTask:scheduleTask()
    local runAt = self:getNextTime()

    if not runAt then
        return self:stop('getNextTime returned no value', true)
    end

    local currentTime = os.time()
    local sleep = runAt - currentTime

    if sleep < 0 then
        if not self.maxDelay or -sleep > self.maxDelay then
            return self:stop(self.debug and ('scheduled time expired %s seconds ago'):format(-sleep), true)
        end

        if self.debug then
            lib.print.debug(('Task %s is %s seconds overdue, executing now due to maxDelay=%s'):format(
                self.id,
                -sleep,
                self.maxDelay
            ))
        end

        sleep = 0
    end

    local timeAsString = self:getTimeAsString(runAt)

    if self.debug then
        lib.print.debug(('(%s) task %s will run in %d seconds (%0.2f minutes / %0.2f hours)'):format(timeAsString, self.id, sleep,
            sleep / 60,
            sleep / 60 / 60))
    end

    if sleep > 0 then
        Wait(sleep * 1000)
    else
        Wait(0)
        return true
    end

    if self.isActive then
        if self.debug then
            lib.print.debug(('(%s) running task %s'):format(timeAsString, self.id))
        end

        Citizen.CreateThreadNow(function()
            self:job(currentDate)
            self.lastRun = os.time()
        end)

        return true
    end
end

function OxTask:run()
    if self.isActive then return end

    self.isActive = true
    self.manualStop = false

    CreateThread(function()
        while self:scheduleTask() do end
    end)
end

function OxTask:stop(msg, internal)
    self.isActive = false
    self.manualStop = not internal

    if self.debug then
        if msg then
            return lib.print.debug(('stopping task %s (%s)'):format(self.id, msg))
        end

        lib.print.debug(('stopping task %s'):format(self.id))
    end
end

function OxTask:destroy()
    self:stop()
    tasks[self.id] = nil
end

---@param expression string A cron expression such as `* * * * *` representing minute, hour, day, month, and day of the week.
---@param job fun(task: OxTask, date: osdate)
---@param options? { debug?: boolean }
---Creates a new [cronjob](https://en.wikipedia.org/wiki/Cron), scheduling a task to run at fixed times or intervals.
---Supports numbers, any value `*`, lists `1,2,3`, ranges `1-3`, and steps `*/4`.
---Day of the week is a range of `1-7` starting from Sunday and allows short-names (i.e. sun, mon, tue).
---@note maxDelay: Maximum allowed delay in seconds before skipping (0 to disable)
function lib.cron.new(expression, job, options)
    if not job or type(job) ~= 'function' then
        error(("expected job to have type 'function' (received %s)"):format(type(job)))
    end

    local minute, hour, day, month, weekday = string.strsplit(' ', string.lower(expression))
    ---@type OxTask
    local task = setmetatable(options or {}, OxTask)

    task.expression = expression
    task.minute = parseCron(minute, 'min')
    task.hour = parseCron(hour, 'hour')
    task.day = parseCron(day, 'day')
    task.month = parseCron(month, 'month')
    task.weekday = parseCron(weekday, 'wday')
    task.id = #tasks + 1
    task.job = job
    task.lastRun = nil
    task.maxDelay = task.maxDelay or 1
    tasks[task.id] = task
    task:run()

    return task
end

-- reschedule any dead tasks on a new day
lib.cron.new('0 0 * * *', function()
    for _, task in pairs(tasks) do
        if not task.isActive and not task.manualStop then
            task:run()
        end
    end
end)

return lib.cron
