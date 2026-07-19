--[[
	Signal- (aka SignalMinus)
	Developed and made by JDJDMNNEN aka delphin4ik.
	Simple Signal Module.
	ConnectionLikes fire in order.
	Module has 2 Classes, SignalClass - Main Signal Class, ConnectionLike - Connection Class.
	SignalMinus is similar to RBXScriptSignal with it having simillar methods. (Lacks :ConnectParallel() and :Wait())
	Distributed under MIT license
]]
local SignalClass = {}
SignalClass.__index = SignalClass

export type ConnectionLike = {
	Disconnect: typeof(
		function(self:ConnectionLike): () end
	)
}

export type SignalMinus<Params...> = {
	Fire: typeof(
		function(SignalClass:SignalMinus<Params...>, ... : Params...): () end
	),
	Destroy: typeof(
		function(SignalClass:SignalMinus<Params...>): () end
	), 
	Connect: typeof(
		function(SignalClass:SignalMinus<Params...>,Connection:(Params...)->ConnectionLike) : ConnectionLike end
	), 
	Once: typeof(
		function(SignalClass:SignalMinus<Params...>,Connection:(Params...)->ConnectionLike): ConnectionLike end
	),
	Listeners: {[number]: (SignalMinus<Params...>) -> ()}
}
function SignalClass:Destroy(): ()
	table.clear(self.Listeners)
end
function SignalClass:Fire(...:any): ()
	local snapshot = table.clone(self.Listeners)
	for _, i in snapshot do
		local suc, err = pcall(i, ...)
	end
end
function SignalClass:Connect(fn:(...any) -> ()): ConnectionLike
	table.insert(self.Listeners, fn)
	local signals = self.Listeners
	local NewConnectionLike = {}
	function NewConnectionLike:Disconnect(): ()
		local index = table.find(signals, fn)
		if index then table.remove(signals, index) end
	end
	return NewConnectionLike
end
function SignalClass:Once(fn:(...any) -> ()): ConnectionLike
	local NewConnectionLike
	NewConnectionLike = self:Connect(function(...)
		NewConnectionLike:Disconnect()
		fn(...)
	end)
	return NewConnectionLike
end

return function()
	local self = setmetatable({}, SignalClass)
	self.Listeners = {}
	return self
end :: SignalMinus<>