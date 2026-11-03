--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Notify = {}

local remote: RemoteEvent? = nil

function Notify.Start()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local event = Instance.new("RemoteEvent")
	event.Name = "Notify"
	event.Parent = folder
	remote = event
end

function Notify.Say(player: Player, message: string)
	if remote then
		remote:FireClient(player, message)
	end
end

return Notify
