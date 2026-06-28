--!strict
--[[
  MathUtil.lua
  Utilitarios matematicos compartilhados entre server e client.
  Funcoes:
    clamp(value, min, max) -> number
    lerp(a, b, t) -> number
    distance(a: Vector3, b: Vector3) -> number
    randomRange(min, max) -> number
    direction(from: Vector3, to: Vector3) -> Vector3
]]

local MathUtil = {}

--[[
  Limita um valor entre min e max.
]]
function MathUtil.clamp(value: number, min: number, max: number): number
	if value < min then
		return min
	elseif value > max then
		return max
	end
	return value
end

--[[
  Interpolacao linear entre a e b.
  t=0 retorna a, t=1 retorna b.
]]
function MathUtil.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

--[[
  Distancia euclidiana entre dois pontos Vector3.
]]
function MathUtil.distance(a: Vector3, b: Vector3): number
	return (b - a).Magnitude
end

--[[
  Numero aleatorio entre min e max (inclusivo para inteiros,
  aproximado para floats).
]]
function MathUtil.randomRange(min: number, max: number): number
	return min + math.random() * (max - min)
end

--[[
  Retorna o vetor unitario de direcao de from ate to.
]]
function MathUtil.direction(from: Vector3, to: Vector3): Vector3
	return (to - from).Unit
end

--[[
  Verifica se dois vetores estao a uma distancia menor ou igual a radius.
]]
function MathUtil.isInRadius(a: Vector3, b: Vector3, radius: number): boolean
	return (b - a).Magnitude <= radius
end

return MathUtil
