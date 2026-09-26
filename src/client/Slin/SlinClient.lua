local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SlinNet = require(ReplicatedStorage.Shared.Slin.SlinNet)

local SlinClient = {
	Controllers = {},
	_started = false,
	_startedControllers = {}
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

function SlinClient.CreateController(definition)
	assert(type(definition) == "table", "CreateController expects a table")
	assert(type(definition.Name) == "string", "Controller requires a Name")

	SlinClient.Controllers[definition.Name] = definition
	return definition
end

function SlinClient.GetController(name)
	return SlinClient.Controllers[name]
end

function SlinClient.WaitForController(name, timeout)
	local startedAt = os.clock()
	timeout = timeout or 10
	
	while not SlinClient.Controllers[name] do
		if os.clock() - startedAt > timeout then
			error(("Controller %s was not registered after %d seconds"):format(name, timeout), 2)
		end
		task.wait()
	end
	
	return SlinClient.Controllers[name]
end

function SlinClient.GetService(name)
	local remoteFunction = SlinNet.Function("Service_" .. name)

	return setmetatable({}, {
		__index = function(_, methodName)
			return function(_, ...)
				return remoteFunction:InvokeServer(methodName, ...)
			end
		end,
	})
end

function SlinClient.LoadControllers(folder)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ModuleScript") then
			require(child)
		elseif child:IsA("Folder") then
			SlinClient.LoadControllers(child)
		end
	end
end

function SlinClient.Start()
	if SlinClient._started then
		return
	end

	SlinClient._started = true

	SlinNet.Event("ClientReady"):FireServer()

	local controllers = {}

	for _, controller in pairs(SlinClient.Controllers) do
		table.insert(controllers, controller)
	end

	sortModules(controllers)

	for _, controller in ipairs(controllers) do
		if type(controller.SlinInit) == "function" then
			controller:SlinInit()
		end
		SlinClient._startedControllers[controller.Name] = true
	end

	for _, controller in ipairs(controllers) do
		if type(controller.SlinStart) == "function" then
			task.spawn(function()
				controller:SlinStart()
			end)
		end
	end
end

function SlinClient.GetLocalPlayer()
	return Players.LocalPlayer
end

return SlinClient
