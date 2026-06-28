--!strict
--[[
  Signal.lua
  Implementacao simples do padrao Observer (Pub/Sub).
  Usado para comunicacao desacoplada entre servicos do servidor
  e entre modulos do cliente.
  Inspirado em: GoodSignal (Roblox community pattern)

  Metodos:
    Signal.new() -> Signal
    signal:Connect(callback) -> Connection
    signal:Fire(...)
    signal:Wait() -> ...args
    connection:Disconnect()
    signal:Destroy()
]]

-- Tipo interno para conexao (retornado por Connect)
local Connection = {}
Connection.__index = Connection

function Connection.new(signal: {}, callback: (...any) -> ())
	local self = setmetatable({}, Connection)
	self._signal = signal
	self._callback = callback
	self._connected = true
	return self
end

function Connection:Disconnect()
	if not self._connected then
		return
	end
	self._connected = false
	local listeners = self._signal._listeners
	for i = #listeners, 1, -1 do
		if listeners[i] == self._callback then
			table.remove(listeners, i)
			break
		end
	end
end

-- Tipo Signal
local Signal = {}
Signal.__index = Signal

--[[
  Cria um novo sinal (canal de comunicacao pub/sub).
]]
function Signal.new(): {}
	local self = setmetatable({}, Signal)
	self._listeners = {}
	self._onceListeners = {}
	self._waitQueue = {}
	return self
end

--[[
  Registra um listener permanente.
  Retorna um objeto Connection com metodo :Disconnect().
]]
function Signal:Connect(callback: (...any) -> ()): Connection
	table.insert(self._listeners, callback)
	return Connection.new(self, callback)
end

--[[
  Dispara o sinal, chamando todos os listeners com os argumentos.
  Usa task.spawn para que um listener nao bloqueie os outros.
]]
function Signal:Fire(...: any): ()
	local args = table.pack(...)

	-- Listeners permanentes
	for _, callback in ipairs(self._listeners) do
		task.spawn(callback, table.unpack(args))
	end

	-- Listeners de uma vez (Once)
	for _, callback in ipairs(self._onceListeners) do
		task.spawn(callback, table.unpack(args))
	end
	table.clear(self._onceListeners)

	-- Fila de Wait
	local waitQueue = self._waitQueue
	if #waitQueue > 0 then
		table.clear(self._waitQueue)
		for _, waiting in ipairs(waitQueue) do
			task.spawn(waiting, table.unpack(args))
		end
	end
end

--[[
  Registra um listener que dispara apenas UMA vez,
  depois e removido automaticamente.
]]
function Signal:Once(callback: (...any) -> ()): ()
	table.insert(self._onceListeners, callback)
end

--[[
  Aguarda o proximo disparo do sinal e retorna os argumentos.
  Util para logica sequencial: local args = signal:Wait()
]]
function Signal:Wait(): ...any
	local thread = coroutine.running()
	table.insert(self._waitQueue, function(...: any)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

--[[
  Remove todos os listeners e limpa o sinal.
  Chamar quando o servico/modulo for destruido.
]]
function Signal:Destroy(): ()
	table.clear(self._listeners)
	table.clear(self._onceListeners)
	table.clear(self._waitQueue)
end

return Signal
