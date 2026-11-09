--[[
	RedChargeUpEffect

	Description:
	Charge up effect `RedChargeUpEffect` (see Shared/Referential/ChargeUpEffects): shows a red arrow while the player charges a throw.
	The arrow template is the Model parented to this module. The effect id is this module's name; `apply` starts it and the handle's `remove` ends it
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
