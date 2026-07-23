local Services = game.ServerScriptService.Services

for _, module in ipairs(Services:GetDescendants()) do
	if module:IsA("ModuleScript") then
		require(module)
	end
end