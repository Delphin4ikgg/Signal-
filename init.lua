--!native
--!optimize 2
--[[
	Signal- (aka SignalMinus)
	Developed and made by JDJDMNNEN aka delphin4ik. (Huge thanks to BlueCritical)
	Distributed under MIT license.
]]

local SignalClass = {}
SignalClass.__index = SignalClass

local function Constructor<Params...>(...: Params...): SignalMinus<Params...>
	return setmetatable({_head = false, _destroyed = false, _tail = false, _rbxCon = false}, SignalClass)
end

export type ConnectionLike = {
	Connected:boolean,
	Disconnect: (self:ConnectionLike) -> (),
	Reconnect: (self:ConnectionLike) -> ()
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

local function runCallback(callback, thread, ...)
	callback(...)
	table.insert(freeThreads, thread)
end

local function yielder()
	while true do
		runCallback(coroutine.yield())
	end
end

local ConnectionLikeClass = {}
ConnectionLikeClass.__index = ConnectionLikeClass

function ConnectionLikeClass.new<T...>(Signal:SignalMinus<T...>, fn:(T...) -> ()): ConnectionLike
	return setmetatable({
		Connected = true,
		_signal = Signal,
		_function = fn,
		_next = false,
		_waitingThread = nil,
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
		error("Signal-: Signal has been destroyed!")
		return 
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

function SignalClass:Destroy(): ()
	self._destroyed = true
	
	local currentSignal = self._head
	local nextSignal
	
	if self._rbxCon then
		self._rbxCon:Disconnect()
	end
	
	while currentSignal do
		if currentSignal._waitingThread then
			task.spawn(currentSignal._waitingThread)
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
		error("Signal-: Signal has been destroyed!")
		return 
	end
	
	if self._rbxCon then
		self._rbxCon:Disconnect()
	end

	local currentSignal = self._head
	
	while currentSignal do
		currentSignal.Connected = false
		currentSignal = currentSignal._next
	end
	
	self._head = false
	self._tail = false
end

function SignalClass:Fire<T...>(...:T...): ()
	if self._destroyed then 
		error("Signal-: Signal has been destroyed!")
		return 
	end
	
	local currentConnection = self._head
	while currentConnection do
		local currentThread
		if currentConnection.Connected then
			if #freeThreads > 0 then
				currentThread = freeThreads[#freeThreads]
				freeThreads[#freeThreads] = nil
			else
				currentThread = coroutine.create(yielder)
				coroutine.resume(currentThread)
			end
			
			task.spawn(currentThread, currentConnection._function, ...)
			
		end
		currentConnection = currentConnection._next
	end
end

function SignalClass:FireDeferred<T...>(...:T...): ()
	if self._destroyed then 
		error("Signal-: Signal has been destroyed!")
		return 
	end

	task.defer(self.Fire, self, ...)
end

function SignalClass:Connect<T...>(fn:(T...) -> ()): ConnectionLike
	if self._destroyed then
		error("Signal-: Signal has been destroyed!")
		return 
	end
	
	local ConnectionLike = ConnectionLikeClass.new(self, fn)
	
	if self._tail then
		self._tail._next = ConnectionLike
		ConnectionLike._prev = self._tail
	else
		self._head = ConnectionLike
	end
	
	self._tail = ConnectionLike
	
	return ConnectionLike
end

function SignalClass:Once<T...>(fn:(T...) -> ()): ConnectionLike
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

local function wrap<T...>(InitialSignal:RBXScriptSignal): SignalMinus<T...>
	local newSignal: SignalMinus<T...> = Constructor()
	newSignal._rbxCon = InitialSignal:Connect(function(...) 
		newSignal:Fire(...)
	end)
	return newSignal
end

setmetatable(ConnectionLikeClass, {
	__index = function(_, key)
		error(`Signal- -> ConnectionLike: Attempted to read {key}. No such index exists.`)
	end,
	__newindex = function(_, key)
		error(`Signal- -> ConnectionLike: Attempted to write {key}. Request denied.`)
	end,
})

setmetatable(SignalClass, {
	__index = function(_, key)
		error(`Signal-: Attempted to read {key}. No such index exists.`)
	end,
	__newindex = function(_, key)
		error(`Signal-: Attempted to write {key}. Request denied.`)
	end,
})

return setmetatable({Wrap = wrap}, {__call = Constructor})