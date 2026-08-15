
--[[
	Signal- (aka SignalMinus)
	Developed and made by JDJDMNNEN aka delphin4ik. (Huge thanks to BlueCritical)
	Simple Signal Module.
	ConnectionLikes fire in order.
	Use :FireParallel() to fire ConnectionLikes out of order.
	Module has 2 Classes, SignalClass - Main Signal Class, ConnectionLike - Connection Class.
	SignalMinus is similar to RBXScriptSignal with it having simillar methods.
	Change ErrorHandlerFunction is the error handler function. Change it if you want to change the error handler.
	:Destroy() fully clears the Signal.
	:Fire() is the most memmory efficient than :FireParallel(), but the latter doesnt yeild.
	Distributed under MIT license.
]]

const ErrorHandlerFunction = function(ErrorMSG)
	warn(ErrorMSG)
end

local SignalClass = {}
SignalClass.__index = SignalClass

local Types = {
	Any = "" :: any,
	String = "" :: string,
	Number = 0 :: number,
	Boolean = true :: boolean,
	Instance = "" :: Instance,
	Color3 = "" :: Color3,
	ColorSequence = "" :: ColorSequence,
	BrickColor = "" :: BrickColor,
	Vector3 = "" :: Vector3,
	NumberRange = "" :: NumberRange,
	NumberSequence = "" :: NumberSequence,
	CFrame = "" :: CFrame,
	UDim2 = "" :: UDim2,
	UDim = "" :: UDim,
	Vector = "" :: vector,
	Vector2 = "" :: Vector2,
	ColorSequenceKeypoint = "" :: ColorSequenceKeypoint,
	Enum = "" :: Enum,
	Ray = "" :: Ray,
	Font = "" :: Font,
	Enums = "" :: Enums,
	TweenInfo = "" :: TweenInfo,
	Tween = "" :: Tween,
	Model = "" :: Model,
	Humanoid = "" :: Humanoid,
	Buffer = "" :: buffer,
	Table = {}
}

export type ConnectionLike = {
	Disconnect: (self:ConnectionLike) -> ()
}

export type SignalMinus<Params...> = {
	Len: number,
	Fire: typeof(
		function(SignalClass:SignalMinus<Params...>, ... : Params...): () end
	),
	Destroy: typeof(
		function(SignalClass:SignalMinus<Params...>): () end
	), 
	Connect: typeof(
		function(SignalClass:SignalMinus<Params...>,Connection:(Params...)->()) : ConnectionLike end
	), 
	FireParallel: typeof(
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
	Listeners: {[number]: (Params...) -> ()}
}

function SignalClass:Destroy(): ()
	table.clear(self)
end

function SignalClass:DisconnectAll(): ()
	table.clear(self.Listeners)
end

function SignalClass:Fire(...:any): ()
	local snapshot = table.clone(self.Listeners)
	for _, i in snapshot do
		xpcall(i, ErrorHandlerFunction,...)
	end
end

function SignalClass:Connect(fn:(...any) -> ()): ConnectionLike
	self.Len += 1
	local Len = self.Len
	local signals = self.Listeners
	local NewConnectionLike = {}
	signals[Len] = fn
	function NewConnectionLike:Disconnect(): ()
		signals[Len] = nil
	end
	return NewConnectionLike
end

function SignalClass:FireParallel(...:any): ()
	local snapshot = table.clone(self.Listeners)
	for _, i in snapshot do
		task.spawn(function(...)
			xpcall(i, ErrorHandlerFunction, ...)
		end, ...)
	end
end

function SignalClass:Once(fn:(...any) -> ()): ConnectionLike
	local NewConnectionLike
	NewConnectionLike = self:Connect(function(...)
		NewConnectionLike:Disconnect()
		fn(...)
	end)
	return NewConnectionLike
end

function SignalClass:Wait()
	local NewConnectionLike
	local Coroutine = coroutine.running()
	NewConnectionLike = self:Connect(function(...)
		NewConnectionLike:Disconnect()
		coroutine.resume(Coroutine, ...)
	end)
	return coroutine.yield(Coroutine)
end

local function Constructor<Params...>(_, ...: Params...): SignalMinus<Params...>
	local self = setmetatable({}, SignalClass)
	self.Listeners = {}
	self.Len = 0
	return self
end

return setmetatable(Types, {__call = Constructor})
