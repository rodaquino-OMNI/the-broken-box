--!strict
--[[
  RemoteEventUtils.lua
  Helpers para encontrar/criar RemoteEvents de forma segura
  e envia-los para clientes com filtros.
  Compartilhado via ReplicatedStorage.

  Funcoes:
    findRemoteEvent(parent, name) -> RemoteEvent?
    createRemoteEvent(parent, name) -> RemoteEvent
    fireAll(remoteEvent, messageType, data)
    firePlayer(remoteEvent, player, messageType, data)
    fireAllExcept(remoteEvent, exceptPlayer, messageType, data)
    filterByIsA(parent, className) -> table
]]

local Players = game:GetService("Players")

local RemoteEventUtils = {}

--[[
  Procura um RemoteEvent pelo nome no parent.
  Retorna nil se nao encontrar.
]]
function RemoteEventUtils.findRemoteEvent(parent: Instance, name: string): RemoteEvent?
	local obj = parent:FindFirstChild(name)
	if obj and obj:IsA("RemoteEvent") then
		return obj
	end
	return nil
end

--[[
  Cria um RemoteEvent no parent especificado.
  Se ja existir (e for RemoteEvent), retorna o existente.
]]
function RemoteEventUtils.createRemoteEvent(parent: Instance, name: string): RemoteEvent
	local existing = RemoteEventUtils.findRemoteEvent(parent, name)
	if existing then
		return existing
	end

	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = name
	remoteEvent.Parent = parent
	return remoteEvent
end

--[[
  Filtra os filhos de um parent que sejam do tipo className.
  Ex.: filterByIsA(replicatedStorage.Events, "RemoteEvent")
]]
function RemoteEventUtils.filterByIsA(parent: Instance, className: string): {RemoteEvent}
	local result = {}
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA(className) then
			table.insert(result, child)
		end
	end
	return result
end

--[[
  Envia um RemoteEvent para todos os clientes.
  messageType: string que identifica o tipo de mensagem.
  data: table com os dados da mensagem.
]]
function RemoteEventUtils.fireAll(remoteEvent: RemoteEvent, messageType: string, data: {any}): ()
	local message = { type = messageType, data = data }
	remoteEvent:FireAllClients(message)
end

--[[
  Envia um RemoteEvent para um jogador especifico.
]]
function RemoteEventUtils.firePlayer(remoteEvent: RemoteEvent, player: Player, messageType: string, data: {any}): ()
	local message = { type = messageType, data = data }
	remoteEvent:FireClient(player, message)
end

--[[
  Envia um RemoteEvent para todos os clientes EXCETO um jogador.
  Util para enviar estado para todos menos o causador da acao.
]]
function RemoteEventUtils.fireAllExcept(remoteEvent: RemoteEvent, exceptPlayer: Player, messageType: string, data: {any}): ()
	local message = { type = messageType, data = data }
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= exceptPlayer then
			remoteEvent:FireClient(player, message)
		end
	end
end

--[[
  Envia um RemoteEvent filtrado por uma condicao customizada.
  filterFn recebe um Player e retorna true se deve receber a mensagem.
]]
function RemoteEventUtils.fireFiltered(
	remoteEvent: RemoteEvent,
	filterFn: (Player) -> boolean,
	messageType: string,
	data: {any}
): ()
	local message = { type = messageType, data = data }
	for _, player in ipairs(Players:GetPlayers()) do
		if filterFn(player) then
			remoteEvent:FireClient(player, message)
		end
	end
end

return RemoteEventUtils
