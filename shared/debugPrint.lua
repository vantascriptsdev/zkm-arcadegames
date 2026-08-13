local Config = lib.require "config"

---@param level 'info' | 'warn' | 'error' | 'verbose' | 'debug'
---@param ... any
return function(level, ...)
    if not Config.debug then return end
    local printModule = lib.print
    if not printModule[level] then error(("Invalid 'level' specified in debugPrint"):format(level)) end

    printModule[level](...)
end