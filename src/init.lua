--!optimize 2
--!native
--[[
	Signal- (aka SignalMinus)
	Developed and made by JDJDMNNEN aka delphin4ik. (Huge thanks to BlueCritical)
	Distributed under MIT license.
	v1.0
	
	Also thanks to LemonSignal and GoodSignal. The Signal module is heavily based off of them.
	
	Fires Oldest-First, Latest-Last
	
	API:
	local Signal = require(PathToSignalModule)
	
	local newSignal = Signal() or Signal.new() :: Signal.Signal<string>
	
	local connection = newSignal:Connect(function(a0:string)
		print("Hello Signal-! ", a0)
	end)
	
	newSignal:Fire("You too!") -> "Hello Signal-! You too!"
	
	connection:Disconnect() or connection:Destroy()
	
	Short Docs:
	
	To create a new Signal, either call the Module, or use the .new() function. You can specify types in the constructor function.
	
	[Required Module].Is() - Returns a boolean. If true, the object is likely a signal.
	
	Signal:Len() - Returns the number of connected connections.
	
	Signal:Fire() - Dispatches the connections. Yield-Safe.
	Signal:FireDeferred() - Same as Fire, but deferred.
	
	Signal:Connect() - New Connection.
	Signal:ConnectPriority() - New Connection, but it is always appended to the start, meaning it will be fired first unless you override it.
	Signal:Once() - Same as Connect, but auto-disconnects on the first fire.
	Signal:Wait() - Yields until the signal is fired, after that either passes the values specified by the Fire, or a string as a return on error.
	
	Signal:GetConnections() - Returns all the connected connetions.
	
	Signal:Destroy() - Destroys the signal.
	Signal:DisconnectAll() - Disconnect everything. Ignores RBXScriptConnections if you used Wrap to create the signal.
	
	All of the Connection functions except Wait return a ConnectionLike class.
	
	ConnectionLike:Disconnect() - Disconnects the connection.
	ConnectionLike:Reconnect() - Reconnects the connection, appending it to the end.
	ConnectionLike:Destroy() - Same as Disconnect, but disables reconnects.
	ConnectionLike.Connected - Treat this as read-only, but don't mess with it as it is not. Determines if the function is Connected.
]]

const Wake_Waiters_On_Signal_Destroy = true

local UNIVERSAL_MARKER = {}

local SignalClass = {}
SignalClass.__index = SignalClass

local function Constructor<T...>(...:T...): Signal<T...>
	return setmetatable({_head = false, _destroyed = false, _tail = false, _rbxCon = false, _len = 0, _marker = UNIVERSAL_MARKER}, SignalClass)
end

export type Signal<Params...> = {
	Fire: typeof(
		function(SignalClass:Signal<Params...>, ... : Params...): () end
	),
	Destroy: typeof(
		function(SignalClass:Signal<Params...>): () end
	), 
	Connect: typeof(
		function(SignalClass:Signal<Params...>,Connection:(Params...)->()) : ConnectionLike end
	),
	ConnectPriority: typeof(
		function(SignalClass:Signal<Params...>,Connection:(Params...)->()) : ConnectionLike end
	),
	FireDeferred: typeof(
		function(SignalClass:Signal<Params...>, ... : Params...) : () end
	), 
	Once: typeof(
		function(SignalClass:Signal<Params...>,Connection:(Params...)->()): ConnectionLike end
	),
	Wait: typeof(
		function(SignalClass:Signal<Params...>): Params... end
	),
	DisconnectAll: typeof(
		function(SignalClass:Signal<Params...>): () end
	),
	GetConnections: typeof(
		function(SignalClass:Signal<Params...>): {ConnectionLike} end
	),
	Len: typeof(
		function(SignalClass:Signal<Params...>): number end
	),
}

export type ConnectionLike = {
	Connected:boolean,
	Disconnect: (self:ConnectionLike) -> (),
	Reconnect: (self:ConnectionLike) -> (),
	Destroy: (self:ConnectionLike) -> (),
}

local freeRunnerThread: thread?
local freeThreads: { thread } = {}

local function run(fn, ...)
	freeRunnerThread = nil
	fn(...)
	
	local runner = coroutine.running()
	
	if freeRunnerThread then
		freeThreads[#freeThreads + 1] = runner
	else
		freeRunnerThread = runner
	end
end

local function Yield()
	while true do
		run(coroutine.yield())
	end
end

local ConnectionLikeClass = {}
ConnectionLikeClass.__index = ConnectionLikeClass
-- An evil wizard that creates a new "carcas" for his EVIL ConnectionLike!
local function newConnection<T...>(Signal:Signal<T...>, fn:(T...) -> ()): ConnectionLike
	return setmetatable({
		Connected = true,
		_signal = Signal,
		_function = fn,
		_next = false,
		_waitingThread = false,
		_prev = false,
		_destroyed = false
	}, ConnectionLikeClass)
end

function ConnectionLikeClass:Disconnect()
	if not self.Connected then return end
	
	self.Connected = false
	local signal = self._signal

	local next = self._next
	local prev = self._prev

	if next then next._prev = prev end
	if prev then prev._next = next end

	if signal._head == self then signal._head = next end
	if signal._tail == self then signal._tail = prev end

	signal._len -= 1
end

function ConnectionLikeClass:Reconnect()
	if not self._signal or self._signal._destroyed or self._destroyed then 
		error("Signal- -> ConnectionLike: Signal has been destroyed!", 2)
	end

	if self.Connected then
		return
	end

	self.Connected = true

	local signal = self._signal

	if signal._tail then
		self._prev = signal._tail
		signal._tail._next = self
	else
		signal._head = self
		self._prev = false
	end

	signal._tail = self
	self._next = false

	signal._len += 1
end

function ConnectionLikeClass:Destroy(): ()
	self._destroyed = true

	self:Disconnect()
end

if Wake_Waiters_On_Signal_Destroy then 
	SignalClass.DisconnectAll = function(self:Signal<...any>): ()
		if self._destroyed then 
			error("Signal-: Signal has been destroyed!", 2)
		end

		local currentSignal = self._head
		
		while currentSignal do
			if currentSignal._waitingThread then
				task.spawn(currentSignal._waitingThread, "Signal-: Signal was destroyed.")
			end
			currentSignal:Disconnect()
			currentSignal = currentSignal._next
		end

		self._head = false
		self._tail = false

		self._len = 0
	end
	SignalClass.Destroy = function(self:Signal<...any>): ()
		self._destroyed = true

		local currentSignal = self._head

		if self._rbxCon then
			self._rbxCon:Disconnect()
		end

		self._rbxCon = false

		self._head = nil
		self._tail = nil

		while currentSignal do
			if currentSignal._waitingThread then
				task.spawn(currentSignal._waitingThread, "Signal-: Signal was destroyed.")
			end

			currentSignal.Connected = false
			currentSignal._function = nil
			currentSignal._signal = nil

			currentSignal = currentSignal._next
		end

		self._len = 0
	end
else
	SignalClass.DisconnectAll = function(self:Signal<...any>): ()
		if self._destroyed then 
			error("Signal-: Signal has been destroyed!", 2)
		end

		local currentSignal = self._head

		while currentSignal do
			currentSignal:Disconnect()
			currentSignal = currentSignal._next
		end

		self._head = false
		self._tail = false

		self._len = 0
	end
	SignalClass.Destroy = function(self:Signal<...any>): ()
		self._destroyed = true

		local currentSignal = self._head

		if self._rbxCon then
			self._rbxCon:Disconnect()
		end

		self._rbxCon = false

		self._head = nil
		self._tail = nil

		while currentSignal do
			currentSignal.Connected = false
			currentSignal._function = nil
			currentSignal._signal = nil

			currentSignal = currentSignal._next
		end

		self._len = 0
	end
end

function SignalClass:Fire(...): ()
	if self._destroyed then 
		error("Signal-: Signal has been destroyed!", 2)
	end

	local currentConnection: ConnectionLike? = self._head
	local currentThread: thread
	local currentFunction: typeof(function() end)
	local len: number
	const _stopMarker: ConnectionLike? = self._tail

	while currentConnection do
		if currentConnection.Connected then
			currentThread = freeRunnerThread
			currentFunction = currentConnection._function
			
			if currentThread then
				freeRunnerThread = nil
			else
				len = #freeThreads
				
				if len > 0 then
					currentThread = freeThreads[len]
					freeThreads[len] = nil
				else
					currentThread = coroutine.create(Yield)
					coroutine.resume(currentThread)
				end
			end
			
			task.spawn(currentThread, currentFunction, ...)
		end
		if currentConnection == _stopMarker then break end
		currentConnection = currentConnection._next
	end
end

function SignalClass:GetConnections(): {ConnectionLike}
	if self._destroyed then 
		error("Signal-: Signal has been destroyed!", 2)
	end

	local currentConnection = self._head

	local returntable = {}

	while currentConnection do
		if currentConnection.Connected then
			returntable[#returntable + 1] = currentConnection
		end
		currentConnection = currentConnection._next
	end

	return returntable
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

	self._len += 1

	return ConnectionLike
end

function SignalClass:ConnectPriority(fn:(...any) -> ()): ConnectionLike
	if self._destroyed then
		error("Signal-: Signal has been destroyed!", 2)
		return 
	end

	local ConnectionLike = newConnection(self, fn)

	if self._head then
		self._head._prev = ConnectionLike
		ConnectionLike._next = self._head
		self._head = ConnectionLike
	else
		self._head = ConnectionLike
		self._tail = ConnectionLike
	end

	self._len += 1

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

local function wrap<T...>(InitialSignal:RBXScriptSignal): Signal<T...>
	local newSignal = Constructor()
	newSignal._rbxCon = InitialSignal:Connect(function(...) 
		newSignal:Fire(...)
	end)
	return newSignal
end

function SignalClass:Len()
	return self._len
end

local function is(obj:any)
	return type(obj) == "table" and rawget(obj, "_marker") == UNIVERSAL_MARKER
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

return setmetatable({Wrap = wrap, new = Constructor, Is = is}, {__call = function<T...>(_, ...:T...): Signal<T...>
	return Constructor(...)
end,})
