local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local monsterCountdownRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.MONSTER_COUNTDOWN) :: RemoteEvent

local monsterModelsFolder = Workspace:WaitForChild("MonsterModels")

monsterCountdownRemote.OnClientEvent:Connect(function(slotIndex: number, secondsRemaining: number)
	local model = monsterModelsFolder:FindFirstChild(`Monster_{player.UserId}_{slotIndex}`) :: Model?
	if not model then
		return
	end

	local body = model.PrimaryPart
	if not body then
		return
	end

	local countdownTag = body:FindFirstChild("CountdownTag")
	local label = countdownTag and countdownTag:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = `💧 {math.max(secondsRemaining, 0)}s`
	end
end)
