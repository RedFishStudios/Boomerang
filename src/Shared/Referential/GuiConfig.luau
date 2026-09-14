--[[

   GENERAL GUI DETAILS/SCOPE
   This game has a cartoon-themed gui display
   - Colors should be bright and eye-catching
   - Text should be of a rounded, cartoon-like font that is clearly readable
   - Visible frames should have rounded corners, generally having a 'child-safe' feel

]]

local GuiConfig = {}

-- [string]: Color3 with commonly used gui colors for the purpose of consistent theming
GuiConfig.GuiColors = {
	PanelBackground = Color3.fromRGB(45, 32, 74),
	Primary = Color3.fromRGB(255, 125, 233),
	Secondary = Color3.fromRGB(101, 224, 255),
	Accent = Color3.fromRGB(255, 214, 89),
	Success = Color3.fromRGB(133, 255, 163),
	Danger = Color3.fromRGB(255, 111, 111),
	White = Color3.fromRGB(255, 255, 255),
	Black = Color3.fromRGB(0, 0, 0),
	TitleText = Color3.fromRGB(249, 255, 222),
	ExitIcon = Color3.fromRGB(57, 5, 29),
}

-- [string]: UIStroke colors differ by context (panel outlines read darker/muted vs. crisp near-black text outlines)
GuiConfig.StrokeColors = {
	Panel = Color3.fromRGB(34, 84, 88),
	Text = Color3.fromRGB(14, 35, 36),
}

-- [string]: Font face with commonly used gui fonts -- the title uses a distinct display font from body/button text
GuiConfig.Fonts = {
	Title = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular),
	Body = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold),
	Icon = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold),
}

-- [string]: ColorSequence + rotation pairs for the UIGradients layered over panel/button backgrounds
GuiConfig.Gradients = {
	Panel = {
		Rotation = 90,
		ColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(67, 255, 186)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(51, 177, 135)),
		}),
	},
	Exit = {
		Rotation = 90,
		ColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 38, 168)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(208, 31, 137)),
		}),
	},
	Primary = {
		Rotation = 90,
		ColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 172, 251)),
			ColorSequenceKeypoint.new(0.505, Color3.fromRGB(255, 125, 233)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(214, 101, 208)),
		}),
	},
	Secondary = {
		Rotation = 90,
		ColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(148, 253, 255)),
			ColorSequenceKeypoint.new(0.505, Color3.fromRGB(0, 255, 238)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 209, 209)),
		}),
	},
}

-- UDim2 scale used for UICorner radii to keep rounded-corner sizing consistent across gui panels/buttons
GuiConfig.CornerRadius = {
	Panel = UDim.new(0.08, 0),
	Button = UDim.new(0.18, 0),
	Badge = UDim.new(1, 0),
}

-- Standard UIStroke thickness (pixels) for outlined text/frames
GuiConfig.StrokeThickness = 2

return GuiConfig