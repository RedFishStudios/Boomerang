--[[
	RedChargeUpEffect

	Description:
	Charge up effect `RedChargeUpEffect` (see Shared/Referential/ChargeUpEffects): shows a red arrow while the player charges a throw.
	Its arrow template is the Model parented to this module. The effect id is the name of this module; the effect is
	started with `apply` when a player begins charging and ended with the handle's `remove` when they stop
	(see ChargeUpEffectLibrary.ChargeUpEffectLogic for the contract).
]]

local RedChargeUpEffect = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChargeUpEffectLibrary = require(ReplicatedStorage.Shared.Library.ChargeUpEffectLibrary)
local ArrowEffect = require(script.Parent.ArrowEffect)

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function RedChargeUpEffect.apply(player: Player, _character: Model): ChargeUpEffectLibrary.ChargeUpEffectHandle
	local template = script:FindFirstChildWhichIsA("Model")
	assert(template, "RedChargeUpEffect: missing arrow template Model under the module")
	return ArrowEffect.apply(template, player)
end

return RedChargeUpEffect :: ChargeUpEffectLibrary.ChargeUpEffectLogic
