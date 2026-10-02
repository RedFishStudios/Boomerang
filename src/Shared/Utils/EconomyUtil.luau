local EconomyUtil = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

--- Formats a Currency price for display ("Free" for 0).
function EconomyUtil.getPriceDisplayString(price: number): string
	if price <= 0 then
		return "Free"
	end

	return GeneralUtil.formatNumber(price)
end

return EconomyUtil
