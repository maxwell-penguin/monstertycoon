local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ScreenEffects = {}

local gui = Instance.new("ScreenGui")
gui.Name = "ScreenEffectsGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = playerGui

local function fullScreenFlash(color: Color3, startTransparency: number, duration: number)
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = startTransparency
	flash.BorderSizePixel = 0
	flash.Parent = gui

	local tween = TweenService:Create(flash, TweenInfo.new(duration), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		flash:Destroy()
	end)
end

local function edgeVignette(color: Color3, duration: number)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 20
	stroke.Color = color
	stroke.Transparency = 0
	stroke.Parent = frame

	local tween = TweenService:Create(stroke, TweenInfo.new(duration), { Transparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		frame:Destroy()
	end)
end

function ScreenEffects.CoinFlash(_amount: number)
	local flash = Instance.new("ImageLabel")
	flash.Size = UDim2.fromScale(1, 1)
	flash.Image = ""
	flash.ImageTransparency = 1
	flash.BackgroundColor3 = Color3.fromRGB(255, 210, 60)
	flash.BackgroundTransparency = 0.6
	flash.BorderSizePixel = 0
	flash.Parent = gui

	local tween = TweenService:Create(flash, TweenInfo.new(0.15), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		flash:Destroy()
	end)
end

function ScreenEffects.SuffixFlash(newSuffix: string)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(0, 200, 0, 200)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(255, 210, 60)
	label.TextScaled = true
	label.Text = newSuffix
	label.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Scale = 2.0
	scale.Parent = label

	TweenService:Create(scale, TweenInfo.new(0.5), { Scale = 1.0 }):Play()

	local fadeTween = TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 })
	fadeTween:Play()
	fadeTween.Completed:Connect(function()
		label:Destroy()
	end)
end

function ScreenEffects.RarityFlash(rarity: string)
	if rarity == "Common" then
		return
	elseif rarity == "Uncommon" then
		fullScreenFlash(Color3.fromRGB(100, 150, 255), 0.85, 0.1)
	elseif rarity == "Rare" then
		edgeVignette(Color3.fromRGB(80, 220, 100), 0.3)
	elseif rarity == "Epic" then
		fullScreenFlash(Color3.fromRGB(160, 60, 220), 0.4, 0.3)
	elseif rarity == "Legendary" then
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = Color3.new(0, 0, 0)
		flash.BackgroundTransparency = 1
		flash.BorderSizePixel = 0
		flash.Parent = gui

		local darken = TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 0.2 })
		darken:Play()
		darken.Completed:Connect(function()
			local brighten = TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
			brighten:Play()
			brighten.Completed:Connect(function()
				flash:Destroy()
			end)
		end)
	elseif rarity == "Mythic" then
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = Color3.new(0, 0, 0)
		flash.BackgroundTransparency = 0
		flash.BorderSizePixel = 0
		flash.Parent = gui

		task.delay(0.3, function()
			flash.BackgroundColor3 = Color3.new(1, 1, 1)
			task.wait()
			local fadeOut = TweenService:Create(flash, TweenInfo.new(0.1), { BackgroundTransparency = 1 })
			fadeOut:Play()
			fadeOut.Completed:Connect(function()
				flash:Destroy()
			end)
		end)
	end
end

function ScreenEffects.BoostFlash(elementColor: Color3)
	local flash = Instance.new("ImageLabel")
	flash.Size = UDim2.fromScale(1, 1)
	flash.Image = ""
	flash.ImageTransparency = 1
	flash.BackgroundColor3 = elementColor
	flash.BackgroundTransparency = 0
	flash.BorderSizePixel = 0
	flash.Parent = gui

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	gradient.Parent = flash

	local tween = TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		flash:Destroy()
	end)
end

shared.ScreenEffects = ScreenEffects
