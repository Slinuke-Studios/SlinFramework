local ClientDataService = require(game.ReplicatedStorage.Clients.Data_CLIENT)

ClientDataService:Init()

if not ClientDataService:WaitUntilLoaded(30) then
	error("Failed to load player data")
end

print("Client data loaded") 