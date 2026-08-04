local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local MonetizationManager = require(script.Parent.MonetizationManager)

local RATE_LIMIT_WINDOW = 5

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local promptPurchaseRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PROMPT_PURCHASE) :: RemoteEvent

local lastPromptTime: { [number]: number } = {}

promptPurchaseRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local purchaseType = payload.purchaseType
	local productId = payload.productId

	if purchaseType ~= "gamepass" and purchaseType ~= "product" then
		return
	end

	if typeof(productId) ~= "number" then
		return
	end

	local userId = player.UserId
	local now = os.clock()
	local last = lastPromptTime[userId]
	if last and (now - last) < RATE_LIMIT_WINDOW then
		return
	end

	-- Never trust productId from the client beyond confirming it's a real
	-- configured gamepass/product ID.
	local isValidId
	if purchaseType == "gamepass" then
		isValidId = MonetizationManager.IsValidGamepassId(productId)
	else
		isValidId = MonetizationManager.IsValidProductId(productId)
	end

	if not isValidId then
		warn(`[MonetizationRemotes] Rejected unknown {purchaseType} id {productId} from user {userId}`)
		return
	end

	lastPromptTime[userId] = now

	if purchaseType == "gamepass" then
		MarketplaceService:PromptGamePassPurchase(player, productId)
	else
		MarketplaceService:PromptProductPurchase(player, productId)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastPromptTime[player.UserId] = nil
end)
