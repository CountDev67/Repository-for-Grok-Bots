--!strict
-- Tiny signal. Works in Roblox and in Lune tests (no BindableEvent).
-- Listeners run synchronously and are isolated with pcall.

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

function Signal.new()
	return setmetatable({
		_listeners = {} :: { { callback: (...any) -> (), connection: Connection } },
	}, Signal)
end

function Signal:Connect(callback: (...any) -> ()): Connection
	local connection: Connection = { Connected = true } :: any
	function connection.Disconnect(conn: Connection)
		conn.Connected = false
	end
	table.insert(self._listeners, { callback = callback, connection = connection })
	return connection
end

function Signal:Fire(...)
	local index = 1
	while index <= #self._listeners do
		local entry = self._listeners[index]
		if entry.connection.Connected then
			local ok, err = pcall(entry.callback, ...)
			if not ok then
				warn("[Signal] " .. tostring(err))
			end
			index += 1
		else
			table.remove(self._listeners, index)
		end
	end
end

return Signal
