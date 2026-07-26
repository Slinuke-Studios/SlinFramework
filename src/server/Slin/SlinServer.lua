local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlinNet = require(ReplicatedStorage.Slin.SlinNet)

local SlinServer = {
	Services = {},
	_started = false,
}

local function sortModules(modules)
	table.sort(modules, function(left, right)
		local leftPriority = left.Priority or 0
		local rightPriority = right.Priority or 0

		if leftPriority == rightPriority then
			return left.Name < right.Name
		end

		return leftPriority < rightPriority
	end)
end

function SlinServer.CreateService(definition)
	assert(type(definition) == "table", "CreateService expects a table")
	assert(type(definition.Name) == "string", "Service requires a Name")

	definition.Client = definition.Client or {}
	SlinServer.Services[definition.Name] = definition

	return definition
end

function SlinServer.GetService(name)
	return SlinServer.Services[name]
end

function SlinServer.LoadServices(folder)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ModuleScript") then
			require(child)
		end
	end
end

function SlinServer.Start()
	if SlinServer._started then
		return
	end

	SlinServer._started = true

	local services = {}

	for _, service in pairs(SlinServer.Services) do
		table.insert(services, service)
	end

	sortModules(services)

	for _, service in ipairs(services) do
		local remoteFunction = SlinNet.Function("Service_" .. service.Name)

		remoteFunction.OnServerInvoke = function(player, methodName, ...)
			if type(methodName) ~= "string" then
				return nil
			end

			local method = service.Client[methodName]

			if type(method) ~= "function" then
				warn(("[SlinServer] Missing client method %s.%s"):format(service.Name, methodName))
				return nil
			end

			return method(service.Client, player, ...)
		end
	end

	for _, service in ipairs(services) do
		if type(service.SlinInit) == "function" then
			service:SlinInit()
		end
	end

	for _, service in ipairs(services) do
		if type(service.SlinStart) == "function" then
			task.spawn(function()
				service:SlinStart()
			end)
		end
	end
end

return SlinServer
