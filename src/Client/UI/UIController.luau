-- NOTE: THIS IS NOW FUNCTIONAL AND ITS USE SHOULD BE UNIVERSALIZED

local UIController = {}

local UIModules = {}

export type UiType =
	  "Primary"   -- Full screen
	| "Secondary" -- Full screen but only accessible from within other full-screen UIs
	| "Hover"     -- Internal UI which hovers over other UI, such as small secondary internal menus
   | "Popup"     -- Small-scale UI which appears over other UI; similar to Hover but doesn't typically conflict with Hover-type UIs
	| "HUD"       -- UI which is almost constantly visible on the screen
	| "Dynamic"   -- Exempt from expected module values/functions; manages UI functionality in some other way

export type UIModule = {
	Type: UiType,
	Rendered: boolean?,
	open: (any, any, any)->any,
	close: (any)->any,
	[any]: any
}

local GuiModules = script.Parent.Gui

--------------------------------------------------------------------------------------------------------------------------------------------------
-- Private functions

-- // Begin and start a UI module
local function start(n, m)
	if m.start then
		m.start()
	end
end

--------------------------------------------------------------------------------------------------------------------------------------------------
-- Public functions

function UIController.get(moduleName: string): UIModule
	if not UIModules[moduleName] then
		repeat
			print("[👨‍💻] : UIController : Awaiting " .. moduleName, UIModules)
			if GuiModules:FindFirstChild(moduleName) and not UIModules[moduleName] then
				warn(`Module {moduleName} was being waited for despite existing`)
				UIModules[moduleName] = require(GuiModules:FindFirstChild(moduleName))
			end
			task.wait(.01)
		until UIModules[moduleName]
	end
	return UIModules[moduleName]
end

-- Close all UIs of a Type
function UIController.closeAll(uiType: UiType, Instant: boolean?)
	for i, m in pairs(UIModules) do
		if m.Open and m.Type == uiType then
			m.close(Instant)
		end
	end
end

-- // Returns true if any menu of the specified types are open
function UIController.inMenuOfType(types: {UiType})
	for i, m in pairs(UIModules) do
		if m.Open then
			for i, uiType in pairs(types) do
				if m.Type == uiType then
					return true
				end
			end
		end
	end
	return false
end

-- // Easy UI toggle access
function UIController.toggleUI(uiName: string, toggle: boolean, ...)
	if toggle then
		UIModules[uiName].open(...)
	else
		UIModules[uiName].close(...)
	end
end

--------------------------------------------------------------------------------------------------------------------------------------------------

function UIController.init()
	for _, c in pairs(GuiModules:GetChildren()) do
		if c:IsA("ModuleScript") then
			UIModules[c.Name] = require(c)
		elseif c:IsA("Folder") then
			for _, cc in pairs(c:GetChildren()) do
				if cc:IsA("ModuleScript") then
					UIModules[c.Name] = require(cc)
				end
			end
		end
	end
	
	GuiModules.ChildAdded:Connect(function(c)
		if c:IsA("ModuleScript") then
			UIModules[c.Name] = require(c)
			start(c.Name, UIModules[c.Name])
		end	
	end)
end

function UIController.start()
	for n, m in pairs(UIModules) do
		start(n, m)
	end
end

return UIController