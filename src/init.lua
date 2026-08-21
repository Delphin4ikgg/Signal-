--!native
--!optimize 2
--[[
	Signal- (aka SignalMinus)
	Developed and made by JDJDMNNEN aka delphin4ik. (Huge thanks to BlueCritical)
	Distributed under MIT license.
	
	Also thanks to LemonSignal and GoodSignal. He Signal module is heavily based off of them.
]]

local SignalClass = {}
SignalClass.__index = SignalClass

local function Constructor<Params...>(_, ...: Params...): SignalMinus<Params...>
	return setmetatable({_head = false, _destroyed = false, _tail = false, _rbxCon = false}, SignalClass)
end

export type ConnectionLike = {
	Connected:boolean,
	Disconnect: (self:ConnectionLike) -> (),
	Reconnect: (self:ConnectionLike) -> (),
	Destroy: (self:ConnectionLike) -> (),
}

export type SignalMinus<Params...> = {
	Fire: typeof(
		function(SignalClass:SignalMinus<Params...>, ... : Params...): () end
	),
	Destroy: typeof(
		function(SignalClass:SignalMinus<Params...>): () end
	), 
	Connect: typeof(
		function(SignalClass:SignalMinus<Params...>,Connection:(Params...)->()) : ConnectionLike end
	), 
	FireDeferred: typeof(
		function(SignalClass:SignalMinus<Params...>, ... : Params...) : () end
	), 
	Once: typeof(
		function(SignalClass:SignalMinus<Params...>,Connection:(Params...)->()): ConnectionLike end
	),
	Wait: typeof(
		function(SignalClass:SignalMinus<Params...>): Params... end
	),
	DisconnectAll: typeof(
		function(SignalClass:SignalMinus<Params...>): () end
	),
}

local freeThreads: { thread } = {}
-- Coroutine Magic sounds funny thats why its named like that
local function coroutineMagic(callback, ...)
	callback(...)
	local now = coroutine.running()
	table.insert(freeThreads, now)
end

local function Yield()
	while true do
		coroutineMagic(coroutine.yield())
	end
end

local ConnectionLikeClass = {}
ConnectionLikeClass.__index = ConnectionLikeClass
-- An evil wizard that creates a new "carcas" for his EVIL ConnectionLike!
local function newConnection<T...>(Signal:SignalMinus<T...>, fn:(T...) -> ()): ConnectionLike
	return setmetatable({
		Connected = true,
		_signal = Signal,
		_function = fn,
		_next = false,
		_waitingThread = false,
		_prev = false,
	}, ConnectionLikeClass)
end

function ConnectionLikeClass:Disconnect()
	if not self.Connected then return end
	local signal = self._signal
	
	self.Connected = false
	
	local next = self._next
	local prev = self._prev
	
	if next then next._prev = prev end
	if prev then prev._next = next end
	
	if signal._head == self then signal._head = next end
	if signal._tail == self then signal._tail = prev end
end

function ConnectionLikeClass:Reconnect()
	if not self._signal or self._signal._destroyed then 
		error("Signal-: Signal has been destroyed!", 2)
	end
	
	if self.Connected then
		return
	end
	
	self.Connected = true
	
	local signal = self._signal
	
	if signal._tail then
		signal._tail._next = self
		self._prev = signal._tail
	else
		signal._head = self
		self._prev = false
	end
	
	self._next = false
	self._signal._tail = self
end
-- Alias for :Disconnect()
ConnectionLikeClass.Destroy = ConnectionLikeClass.Disconnect

function SignalClass:Destroy(): ()
	self._destroyed = true
	
	local currentSignal = self._head
	local nextSignal
	
	if self._rbxCon then
		self._rbxCon:Disconnect()
	end
	
	self._rbxCon = nil
	
	while currentSignal do
		if currentSignal._waitingThread then
			task.spawn(currentSignal._waitingThread, "Signal-: Signal was destroyed.")
		end
		
		nextSignal = currentSignal._next
		
		currentSignal.Connected = false
		currentSignal._function = nil
		currentSignal._signal = nil
		
		currentSignal = nextSignal
	end
	
	self._head = nil
	self._tail = nil
end

function SignalClass:DisconnectAll(): ()
	if self._destroyed then 
		error("Signal-: Signal has been destroyed!", 2)
	end
	
	if self._rbxCon then
		self._rbxCon:Disconnect()
	end
	self._rbxCon = false

	local currentSignal = self._head
	
	while currentSignal do
		if currentSignal._waitingThread then
			task.spawn(currentSignal._waitingThread, "Signal-: Signal was disconnected.")
		end
		currentSignal:Disconnect()
		currentSignal = currentSignal._next
	end
	
	self._head = false
	self._tail = false
end

function SignalClass:Fire(...): ()
	if self._destroyed then 
		error("Signal-: Signal has been destroyed!", 2)
	end
	
	local currentConnection = self._head
	local stopMarker = self._tail
	
	while currentConnection do
		local currentThread
		if currentConnection.Connected then
			if #freeThreads > 0 then
				currentThread = freeThreads[#freeThreads]
				freeThreads[#freeThreads] = nil
			else
				currentThread = coroutine.create(Yield)
				coroutine.resume(currentThread)
			end
			
			task.spawn(currentThread, currentConnection._function, ...)
			
		end
		if currentConnection == stopMarker then return end
		currentConnection = currentConnection._next
	end
end

function SignalClass:FireDeferred(...): ()
	if self._destroyed then 
		error("Signal-: Signal has been destroyed!", 2)
		return 
	end

	task.defer(self.Fire, self, ...)
end

function SignalClass:Connect(fn:(...any) -> ()): ConnectionLike
	if self._destroyed then
		error("Signal-: Signal has been destroyed!", 2)
		return 
	end
	
	local ConnectionLike = newConnection(self, fn)
	
	if self._tail then
		self._tail._next = ConnectionLike
		ConnectionLike._prev = self._tail
	else
		self._head = ConnectionLike
	end
	
	self._tail = ConnectionLike
	
	return ConnectionLike
end

function SignalClass:Once(fn:(...any) -> ()): ConnectionLike
	local NewConnectionLike
	
	NewConnectionLike = self:Connect(function(...)
		if NewConnectionLike.Connected then
			NewConnectionLike:Disconnect()
			fn(...)
		end
	end)
	
	return NewConnectionLike
end

function SignalClass:Wait()
	local NewConnectionLike
	local Coroutine = coroutine.running()
	
	NewConnectionLike = self:Connect(function(...)
		NewConnectionLike:Disconnect()
		if coroutine.status(Coroutine) == "suspended" then
			task.spawn(Coroutine, ...)
		end
	end)
	
	NewConnectionLike._waitingThread = Coroutine
	
	return coroutine.yield()
end

local function wrap(InitialSignal:RBXScriptSignal): SignalMinus<>
	local newSignal = Constructor()
	newSignal._rbxCon = InitialSignal:Connect(function(...) 
		newSignal:Fire(...)
	end)
	return newSignal
end

setmetatable(ConnectionLikeClass, {
	__index = function(_, key)
		error(`Signal- -> ConnectionLike: Attempted to read {key}. No such index exists.`, 2)
	end,
	__newindex = function(_, key)
		error(`Signal- -> ConnectionLike: Attempted to write {key}. Request denied.`, 2)
	end,
})

setmetatable(SignalClass, {
	__index = function(_, key)
		error(`Signal-: Attempted to read {key}. No such index exists.`, 2)
	end,
	__newindex = function(_, key)
		error(`Signal-: Attempted to write {key}. Request denied.`, 2)
	end,
})

return setmetatable({Wrap = wrap, new = Constructor}, {__call = Constructor})
