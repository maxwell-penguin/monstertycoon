local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local BoostState = require(ReplicatedStorage.BoostState)
local PlayerManager = require(script.Parent.PlayerManager)
local BagManager = require(script.Parent.BagManager)
local RollManager = require(script.Parent.RollManager)

-- Shared (not local to this module) because the client-built Shop Panel needs the
-- same numeric IDs to fire PROMPT_PURCHASE with. Placeholder 0s until publishing;
-- see the comment in Constants.lua.
local GAMEPASS_IDS = Constants.GAMEPASS_IDS
local PRODUCT_IDS = Constants.PRODUCT_IDS

local LUCK_BOOST_DURATION = 900
local SERVER_BOOST_MULTIPLIER = 1.5
local SERVER_BOOST_DURATION = 600
local SPEED_BOOTS_WALK_SPEED = 21

local INCOME_TIER_ORDER = { "Income2x", "Income3x", "Income5x", "Income7x", "Income10x" }
local INCOME_MULTIPLIERS = { Income2x = 2, Income3x = 3, Income5x = 5, Income7x = 7, Income10x = 10 }

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local setWalkSpeedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SET_WALK_SPEED) :: RemoteEvent
local luckBoostActiveRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.LUCK_BOOST_ACTIVE) :: RemoteEvent
local playerDataLoadedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PLAYER_DATA_LOADED) :: RemoteEvent

local processedReceiptsStore = DataStoreService:GetDataStore("ProcessedReceipts")

-- Session-only, not persisted -- matches spec's "timed flag in player state" (the
-- actual +50% odds effect is a stub for now; only the flag + remote exist here).
local luckBoostExpiry: { [number]: number } = {}

local MonetizationManager = {}

local function isValueInTable(value: any, tbl: { [string]: number }): boolean
	for _, id in tbl do
		if id == value then
			return true
		end
	end
	return false
end

function MonetizationManager.IsValidGamepassId(id: number): boolean
	return isValueInTable(id, GAMEPASS_IDS)
end

function MonetizationManager.IsValidProductId(id: number): boolean
	return isValueInTable(id, PRODUCT_IDS)
end

-- Re-fires the same full-snapshot channel DataStore.server.lua uses on initial
-- login, so the client's ownedGamepasses/coins/etc. stay current after
-- CheckGamepasses finishes (it runs after PLAYER_DATA_LOADED already fired once)
-- or after a live purchase grants something mid-session.
local function syncPlayerDataToClient(player: Player)
	local data = PlayerManager.GetData(player.UserId)
	if data then
		playerDataLoadedRemote:FireClient(player, data)
	end
end

-- "Never stack them, only the highest applies": re-checks ownership of all five
-- income gamepasses (ascending order) and keeps overwriting, so the last owned
-- one found is the highest -- correct regardless of which single gamepass
-- triggered this (initial scan or a single live purchase).
local function applyHighestIncomeMultiplier(player: Player)
	local userId = player.UserId
	local highest = 1

	for _, name in INCOME_TIER_ORDER do
		local gamepassId = GAMEPASS_IDS[name]
		local success, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(userId, gamepassId)
		end)
		if success and owns then
			highest = INCOME_MULTIPLIERS[name]
		end
	end

	PlayerManager.SetData(userId, "incomeMultiplier", highest)
end

function MonetizationManager.ApplyGamepassEffect(player: Player, gamepassName: string)
	local userId = player.UserId

	if gamepassName == "InfiniteBag" then
		BagManager.GrantBagTier(player, 6)
	elseif gamepassName == "VoidCarrier" then
		BagManager.GrantBagTier(player, 5)
	elseif gamepassName == "SpeedBoots" then
		setWalkSpeedRemote:FireClient(player, SPEED_BOOTS_WALK_SPEED)
	elseif gamepassName == "BoostInsider" then
		PlayerManager.SetData(userId, "hasBoostInsider", true)
	elseif gamepassName == "ExtraPlot" then
		warn("[MonetizationManager] ExtraPlot not yet implemented")
	elseif INCOME_MULTIPLIERS[gamepassName] then
		applyHighestIncomeMultiplier(player)
	end
end

local function grantLuckBoost(player: Player)
	local userId = player.UserId
	local expiresAt = os.time() + LUCK_BOOST_DURATION
	luckBoostExpiry[userId] = expiresAt

	luckBoostActiveRemote:FireClient(player, { hasLuckBoost = true, luckBoostExpiry = expiresAt })

	task.delay(LUCK_BOOST_DURATION, function()
		if luckBoostExpiry[userId] ~= expiresAt then
			return
		end

		luckBoostExpiry[userId] = nil

		local stillPlaying = Players:GetPlayerByUserId(userId)
		if stillPlaying then
			luckBoostActiveRemote:FireClient(stillPlaying, { hasLuckBoost = false, luckBoostExpiry = 0 })
		end
	end)
end

local function grantMergeBoost(player: Player)
	local userId = player.UserId
	local data = PlayerManager.GetData(userId)
	local current = (data and data.freeMerges) or 0
	PlayerManager.SetData(userId, "freeMerges", current + 5)
end

local function grantServerBoost(_player: Player)
	BoostState.SetServerMultiplier(SERVER_BOOST_MULTIPLIER, SERVER_BOOST_DURATION)
end

local function grantRareEgg(player: Player)
	RollManager.PerformPremiumRoll(player, "Rare", true)
end

local function grantEpicEgg(player: Player)
	RollManager.PerformPremiumRoll(player, "Epic", true)
end

local function grantLegendaryEgg(player: Player)
	RollManager.PerformPremiumRoll(player, "Legendary", true)
end

local function grantMythicEgg(player: Player)
	RollManager.PerformPremiumRoll(player, "Mythic", true)
end

local function grantStarterPack(player: Player)
	MonetizationManager.ApplyGamepassEffect(player, "InfiniteBag")
	grantLuckBoost(player)
	grantRareEgg(player)
end

local function grantVoidPack(player: Player)
	grantEpicEgg(player)
	grantLuckBoost(player)
	MonetizationManager.ApplyGamepassEffect(player, "SpeedBoots")
end

-- Keyed by product ID. With today's placeholder IDs (all 0) this table can only
-- ever hold one live entry -- expected per spec, not a bug: a real receipt would
-- never arrive with ProductId=0, so this path is dormant until real IDs land.
local PRODUCT_HANDLERS: { [number]: (Player) -> () } = {
	[PRODUCT_IDS.LuckBoost] = grantLuckBoost,
	[PRODUCT_IDS.MergeBoost] = grantMergeBoost,
	[PRODUCT_IDS.ServerBoost] = grantServerBoost,
	[PRODUCT_IDS.RareEgg] = grantRareEgg,
	[PRODUCT_IDS.EpicEgg] = grantEpicEgg,
	[PRODUCT_IDS.LegendaryEgg] = grantLegendaryEgg,
	[PRODUCT_IDS.MythicEgg] = grantMythicEgg,
	[PRODUCT_IDS.StarterPack] = grantStarterPack,
	[PRODUCT_IDS.VoidPack] = grantVoidPack,
}

local function getProcessedReceiptsKey(userId: number): string
	return "ProcessedReceipts_" .. userId
end

local function isReceiptProcessed(userId: number, purchaseId: string): boolean
	local key = getProcessedReceiptsKey(userId)
	local success, result = pcall(function()
		return processedReceiptsStore:GetAsync(key)
	end)

	if success and typeof(result) == "table" then
		return result[purchaseId] == true
	end

	return false
end

local function markReceiptProcessed(userId: number, purchaseId: string)
	local key = getProcessedReceiptsKey(userId)
	pcall(function()
		processedReceiptsStore:UpdateAsync(key, function(existing)
			existing = existing or {}
			existing[purchaseId] = true
			return existing
		end)
	end)
end

local function processReceiptInternal(receiptInfo: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = receiptInfo.PurchaseId

	if isReceiptProcessed(player.UserId, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local handler = PRODUCT_HANDLERS[receiptInfo.ProductId]
	if handler then
		handler(player)
		syncPlayerDataToClient(player)
	end

	markReceiptProcessed(player.UserId, purchaseId)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationManager.ProcessReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local success, result = pcall(processReceiptInternal, receiptInfo)

	if success then
		return result :: Enum.ProductPurchaseDecision
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function MonetizationManager.CheckGamepasses(player: Player)
	local userId = player.UserId
	local owned: { [string]: boolean } = {}

	for name, gamepassId in GAMEPASS_IDS do
		local success, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(userId, gamepassId)
		end)

		if success and owns then
			owned[name] = true
			MonetizationManager.ApplyGamepassEffect(player, name)
		end
	end

	PlayerManager.SetData(userId, "ownedGamepasses", owned)
	syncPlayerDataToClient(player)
end

function MonetizationManager.InitMonetization()
	MarketplaceService.ProcessReceipt = MonetizationManager.ProcessReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, gamepassId: number, wasPurchased: boolean)
			if not wasPurchased then
				return
			end

			for name, id in GAMEPASS_IDS do
				if id == gamepassId then
					MonetizationManager.ApplyGamepassEffect(player, name)

					local data = PlayerManager.GetData(player.UserId)
					local owned = (data and data.ownedGamepasses) or {}
					owned[name] = true
					PlayerManager.SetData(player.UserId, "ownedGamepasses", owned)

					syncPlayerDataToClient(player)
					break
				end
			end
		end
	)
end

return MonetizationManager
