local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local PlayerManager = require(script.Parent.PlayerManager)
local PlotManager = require(script.Parent.PlotManager)
local Economy = require(script.Parent.Economy)
local BagManager = require(script.Parent.BagManager)

local DropboxManager = {}

local playerDropboxes: { [number]: BasePart } = {}

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local updateCoinsRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_COINS) :: RemoteEvent
local updateBagRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_BAG) :: RemoteEvent
local depositBagRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.DEPOSIT_BAG) :: RemoteEvent

function DropboxManager.InitDropbox(player: Player)
	local plotModel = PlotManager.GetPlayerPlot(player)
	if not plotModel then
		warn(`[DropboxManager] No plot found for {player.Name}`)
		return
	end

	local dropboxPart = plotModel:FindFirstChild("Dropbox")
	if not dropboxPart or not dropboxPart:IsA("BasePart") then
		warn(`[DropboxManager] No Dropbox part found in plot for {player.Name}`)
		return
	end

	playerDropboxes[player.UserId] = dropboxPart
end

function DropboxManager.ProcessDeposit(player: Player): (boolean, number)
	local userId = player.UserId

	local data = PlayerManager.GetData(userId)
	if not data then
		return false, 0
	end

	local bagContents = BagManager.GetBagContents(player)
	if #bagContents == 0 then
		return false, 0
	end

	local totalEarned = 0

	for _, vial in bagContents do
		local success, earned = Economy.ProcessSell(userId, 1, vial.rarity, vial.emotion, vial.monsterLevel, vial.monsterStars)

		if success then
			totalEarned += earned
		end
	end

	BagManager.ClearBag(player)

	local updatedData = PlayerManager.GetData(userId)

	if updatedData then
		updateCoinsRemote:FireClient(player, updatedData.coins)
	end

	local bagTier = (updatedData and updatedData.bagTier) or data.bagTier
	local bagDef = Constants.BAG_TIERS[bagTier]

	updateBagRemote:FireClient(player, {
		tier = bagTier,
		capacity = bagDef and bagDef.capacity or 0,
		currentCount = 0,
	})

	depositBagRemote:FireClient(player, totalEarned, #bagContents)

	return true, totalEarned
end

function DropboxManager.GetDropboxPosition(player: Player): Vector3?
	local dropboxPart = playerDropboxes[player.UserId]
	if not dropboxPart then
		return nil
	end
	return dropboxPart.Position
end

function DropboxManager.CleanupDropbox(player: Player)
	playerDropboxes[player.UserId] = nil
end

return DropboxManager
