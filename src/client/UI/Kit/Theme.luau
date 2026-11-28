--!strict
-- Theme: the colours, fonts and spacing every screen uses (ADR 0007). Changing the look of all UI is editing this file.
--
-- State owned: none. Read-only data.
--
-- Usage:
--     frame.BackgroundColor3 = Theme.colors.panel

local Theme = table.freeze({
	colors = table.freeze({
		panel = Color3.fromHex("#1E252C"),
		text = Color3.fromHex("#F2F4F5"),
		mutedText = Color3.fromHex("#AAB4BC"),
		button = Color3.fromHex("#3C8D5A"),
		buttonText = Color3.fromHex("#FFFFFF"),
		signText = Color3.fromHex("#FFFFFF"),
	}),
	fonts = table.freeze({
		body = Enum.Font.Gotham,
		heading = Enum.Font.GothamBold,
	}),
	transparency = table.freeze({
		panel = 0.15,
	}),
	cornerRadius = UDim.new(0, 8),
	padding = UDim.new(0, 10),
	-- Text never shrinks below or grows beyond these, in pixels, however big the screen.
	textSize = table.freeze({ min = 12, max = 28 }),
})

return Theme
