local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local BoostState = require(ReplicatedStorage.BoostState)

local WARNING_DURATION = 60
local INIT_DELAY = 5

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local boostWarningRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BOOST_WARNING) :: RemoteEvent
local boostStartedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BOOST_STARTED) :: RemoteEvent
local boostEndedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BOOST_ENDED) :: RemoteEvent

local function fireAll(remote: RemoteEvent, payload: any?)
	for _, player in Players:GetPlayers() do
		remote:FireClient(player, payload)
	end
end

local function fisherYatesShuffle(list: { any }): { any }
	local shuffled = table.clone(list)
	for i = #shuffled, 2, -1 do
		local j = math.random(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	return shuffled
end

local deck: { { emotion: string, duration: number, multiplier: number } } = {}
local deckIndex = 0

local function nextFromDeck()
	if deckIndex >= #deck then
		deck = fisherYatesShuffle(Constants.BOOST_ROTATION)
		deckIndex = 0
	end
	deckIndex += 1
	return deck[deckIndex]
end

local function waitForBoostToExpire()
	while not BoostState.IsExpired() do
		task.wait(1)
	end
end

local function runStandardBoost()
	local entry = nextFromDeck()

	fireAll(boostWarningRemote, {
		nextEmotion = entry.emotion,
		nextMultiplier = entry.multiplier,
		warningDuration = WARNING_DURATION,
	})
	task.wait(WARNING_DURATION)

	BoostState.SetBoost(entry.emotion, entry.multiplier, entry.duration)
	fireAll(boostStartedRemote, {
		emotion = entry.emotion,
		multiplier = entry.multiplier,
		durationSeconds = entry.duration,
	})

	waitForBoostToExpire()

	BoostState.ClearBoost()
	fireAll(boostEndedRemote, nil)
end

local function runVoidStorm()
	local def = Constants.SPECIAL_BOOSTS.VoidStorm

	BoostState.SetBoost(def.emotion, def.multiplier, def.duration)
	fireAll(boostStartedRemote, {
		emotion = def.emotion,
		multiplier = def.multiplier,
		durationSeconds = def.duration,
		displayName = def.displayName,
	})

	waitForBoostToExpire()

	BoostState.ClearBoost()
	fireAll(boostEndedRemote, nil)
end

local function runDoubleSurge()
	local def = Constants.SPECIAL_BOOSTS.DoubleSurge
	local picked = fisherYatesShuffle(Constants.BOOST_ROTATION)
	local chosenEmotions = { picked[1].emotion, picked[2].emotion }

	BoostState.SetBoost("", def.multiplier, def.duration, chosenEmotions)
	fireAll(boostStartedRemote, {
		emotions = chosenEmotions,
		multiplier = def.multiplier,
		durationSeconds = def.duration,
		displayName = def.displayName,
	})

	waitForBoostToExpire()

	BoostState.ClearBoost()
	fireAll(boostEndedRemote, nil)
end

local function runMysterySurge()
	local def = Constants.SPECIAL_BOOSTS.MysterySurge
	local picked = fisherYatesShuffle(Constants.BOOST_ROTATION)
	local realEmotion = picked[1].emotion

	BoostState.SetBoost("Mystery", def.multiplier, def.duration, nil, realEmotion)
	fireAll(boostStartedRemote, {
		emotion = "Mystery",
		multiplier = def.multiplier,
		durationSeconds = def.duration,
		displayName = def.displayName,
	})

	waitForBoostToExpire()

	BoostState.ClearBoost()
	fireAll(boostEndedRemote, nil)
end

local SPECIAL_BOOST_RUNNERS = { runVoidStorm, runDoubleSurge, runMysterySurge }

local function runSpecialBoost()
	local runner = SPECIAL_BOOST_RUNNERS[math.random(1, #SPECIAL_BOOST_RUNNERS)]
	runner()
end

local function runRotation()
	while true do
		runStandardBoost()

		if math.random() < Constants.SPECIAL_BOOST_CHANCE then
			runSpecialBoost()
		end
	end
end

task.spawn(function()
	task.wait(INIT_DELAY)
	runRotation()
end)
