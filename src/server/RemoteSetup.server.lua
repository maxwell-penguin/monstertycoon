local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

local eventCount = 0
for _, name in RemoteEvents.EVENTS do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	eventCount += 1
end

local functionCount = 0
for _, name in RemoteEvents.FUNCTIONS do
	local remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = name
	remoteFunction.Parent = remotesFolder
	functionCount += 1
end

print(`Remotes initialized: {eventCount} events, {functionCount} functions`)
