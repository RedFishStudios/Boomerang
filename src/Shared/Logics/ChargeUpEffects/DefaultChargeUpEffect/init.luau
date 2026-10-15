--[[
	DefaultChargeUpEffect

	Description:
	Charge up effect `DefaultChargeUpEffect` (see Shared/Referential/ChargeUpEffects): shows the default arrow while the player charges a throw.
	Its arrow template is the Model parented to this module. The effect id is the name of this module; the effect is
	started with `apply` when a player begins charging and ended with the handle's `remove` when they stop
	(see ChargeUpEffectLibrary.ChargeUpEffectLogic for the contract).
]]

local DefaultChargeUpEffect = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChargeUpEffectLibrary = require(ReplicatedStorage.Shared.Library.ChargeUpEffectLibrary)
local ArrowEffect = require(script.Parent.ArrowEffect)

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function DefaultChargeUpEffect.apply(player: Player, _character: Model): ChargeUpEffectLibrary.ChargeUpEffectHandle
	local template = script:FindFirstChildWhichIsA("Model")
	assert(template, "DefaultChargeUpEffect: missing arrow template Model under the module")
	return ArrowEffect.apply(template, player)
end

return DefaultChargeUpEffect :: ChargeUpEffectLibrary.ChargeUpEffectLogic
