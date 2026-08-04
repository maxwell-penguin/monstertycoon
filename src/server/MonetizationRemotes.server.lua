local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local MonetizationManager = require(script.Parent.MonetizationManager)
local RateLimiter = require(script.Parent.RateLimiter)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local promptPurchaseRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PROMPT_PURCHASE) :: RemoteEvent

local promptLimiter = RateLimiter.CreateLimiter(1, 5)

promptPurchaseRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	local userId = player.UserId
	RateLimiter.TrackRemoteCall(userId)

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

	if not promptLimiter:Check(userId) then
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

	if purchaseType == "gamepass" then
		MarketplaceService:PromptGamePassPurchase(player, productId)
	else
		MarketplaceService:PromptProductPurchase(player, productId)
	end
end)
