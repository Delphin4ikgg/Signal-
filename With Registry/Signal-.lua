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

local Signals = {} :: {[string]: SignalMinus<>}
local SignalModule = {}

-- Creates a new SignalMinus, or returns an already existing one.
function SignalModule.Signal(Name:string): SignalMinus<>
	if Signals[Name] then return Signals[Name] end
	local self = setmetatable({}, SignalClass)
	self.Name = Name
	self.Listeners = {}
	Signals[Name] = self
	return self
end
function Signal:Destroy(): ()
	Signals[self.Name] = nil
	table.clear(self.Listeners)
end
function Signal:Fire(...:any): ()
	local snapshot = table.clone(self.Listeners)
	for _, i in snapshot do
		local suc, err = pcall(i, ...)
		if not suc then
			warn(string.format("Function failed! Error: '%s' Callback ↓↓↓", err)) 
			warn(i)
		end
	end
end
function Signal:Connect(fn:(...any) -> ()): ConnectionLike
	table.insert(self.Listeners, fn)
	local signals = self.Listeners
	local NewConnectionLike = {}
	function NewConnectionLike:Disconnect(): ()
		local index = table.find(signals, fn)
		if index then table.remove(signals, index) end
	end
	return NewConnectionLike
end
function Signal:Once(fn:(...any) -> ()): ConnectionLike
	local NewConnectionLike
	NewConnectionLike = self:Connect(function(...)
		NewConnectionLike:Disconnect()
		fn(...)
	end)
	return NewConnectionLike
end
-- Fires the specified SignalMinus, pcalling the function specified when creating it. (Uses :Connect() method)
function SignalModule.Fire(Name:string, ...:any): ()
	if Signals[Name] then Signals[Name]:Fire(...) end
end
-- Destroys the specified SignalMinus, clearing it from the Registry.
function SignalModule.Destroy(Name:string): ()
	if Signals[Name] then Signals[Name]:Destroy() end
end
-- Connects to the specified SignalMinus.
function SignalModule.Connect(Name:string, fn:(...any) -> ()): ConnectionLike
	local ThisSignal = Signals[Name]
	if not ThisSignal then ThisSignal = SignalModule.Signal(Name) end
	return ThisSignal:Connect(fn)
end
-- Connects to the specified SignalMinus. Disconnects after the first fire.
function SignalModule.Once(Name:string, fn:(...any) -> ()): ConnectionLike
	local ThisSignal = Signals[Name]
	if not ThisSignal then ThisSignal = SignalModule.Signal(Name) end
	return ThisSignal:Once(fn)
end
return SignalModule