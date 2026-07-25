local Logger = {}
Logger.__index = Logger

Logger.Level = {
	Debug = 10,
	Info = 20,
	Warn = 30,
	Error = 40,
}

function Logger.New(scope, minLevel)
	return setmetatable({
		_scope = scope,
		_minLevel = minLevel or Logger.Level.Info,
	}, Logger)
end

function Logger:SetLevel(level)
	self._minLevel = level
end

function Logger:_write(level, methodName, message, ...)
	if level < self._minLevel then
		return
	end

	local output = if select("#", ...) > 0 then string.format(message, ...) else tostring(message)
	local line = string.format("[%s] %s", self._scope, output)

	if methodName == "warn" then
		warn(line)
	elseif methodName == "error" then
		error(line, 3)
	else
		print(line)
	end
end

function Logger:Debug(message, ...)
	self:_write(Logger.Level.Debug, "print", message, ...)
end

function Logger:Info(message, ...)
	self:_write(Logger.Level.Info, "print", message, ...)
end

function Logger:Warn(message, ...)
	self:_write(Logger.Level.Warn, "warn", message, ...)
end

function Logger:Error(message, ...)
	self:_write(Logger.Level.Error, "error", message, ...)
end

return Logger
