local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local TIMEOUT = 10

local RemoteHandler = {}
local remotes: { [string]: Instance } = {}

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", TIMEOUT)
if not remotesFolder then
	error(`[RemoteHandler] Remotes folder not found within {TIMEOUT} seconds`)
end

for _, name in RemoteEvents.EVENTS do
	local remote = remotesFolder:WaitForChild(name, TIMEOUT)
	if not remote then
		error(`[RemoteHandler] RemoteEvent "{name}" not found within {TIMEOUT} seconds`)
	end
	remotes[name] = remote
end

for _, name in RemoteEvents.FUNCTIONS do
	local remote = remotesFolder:WaitForChild(name, TIMEOUT)
	if not remote then
		error(`[RemoteHandler] RemoteFunction "{name}" not found within {TIMEOUT} seconds`)
	end
	remotes[name] = remote
end

function RemoteHandler.Get(name: string): Instance
	return remotes[name]
end

-- shared: a LocalScript instance can't be require()'d, so this is how sibling client scripts reach Get()
shared.RemoteHandler = RemoteHandler

print("Remote handler ready")
