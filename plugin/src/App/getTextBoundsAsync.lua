local TextService = game:GetService("TextService")

local Rojo = script:FindFirstAncestor("Rojo")
local Packages = Rojo.Packages

local Log = require(Packages.Log)

-- GetTextBoundsAsync waits for the font to load. In a heavy place the font
-- queues behind every other asset, and since this runs inside component
-- renders, a long wait stalls the whole plugin mount (toolbar and panel
-- included). Until a font family has loaded, wait at most MAX_WAIT once and
-- otherwise use a synchronous estimate.
local MAX_WAIT = 0.2
-- Built-in legacy font close to Montserrat's metrics, for the estimate
local FALLBACK_FONT = Enum.Font.GothamMedium

-- Font family -> "loading" | "ready"
local familyState: { [string]: string } = {}

local function estimateBounds(text: string, textSize: number, width: number): Vector2
	local ok, size =
		pcall(TextService.GetTextSize, TextService, text, textSize, FALLBACK_FONT, Vector2.new(width, math.huge))
	if not ok then
		return Vector2.zero
	end

	-- A little extra, since the estimate's font isn't the real one
	return Vector2.new(math.min(size.X * 1.05, width), size.Y)
end

local function getTextBoundsAsync(
	text: string,
	font: Font,
	textSize: number,
	width: number,
	richText: boolean?
): Vector2
	if type(text) ~= "string" then
		Log.warn(`Invalid text. Expected string, received {type(text)} instead`)
		return Vector2.zero
	end
	if #text >= 200_000 then
		Log.warn(`Invalid text. Exceeds the 199,999 character limit`)
		return Vector2.zero
	end

	local params = Instance.new("GetTextBoundsParams")
	params.Text = text
	params.Font = font
	params.Size = textSize
	params.Width = width
	params.RichText = not not richText

	local family = font.Family
	local state = familyState[family]

	if state == "ready" then
		local success, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
		if not success then
			Log.warn(`Failed to get text bounds: {bounds}`)
			return Vector2.zero
		end
		return bounds
	end

	if state == "loading" then
		-- Another call is already waiting on this font; don't stall again
		return estimateBounds(text, textSize, width)
	end

	familyState[family] = "loading"

	local done, success, bounds = false, false, nil
	task.spawn(function()
		success, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
		done = true
		-- Even on failure, stop estimating: the real call reports the error
		familyState[family] = "ready"
	end)

	local started = os.clock()
	while not done and os.clock() - started < MAX_WAIT do
		task.wait()
	end

	if not done then
		Log.trace("Font {} not loaded yet; estimating text bounds", family)
		return estimateBounds(text, textSize, width)
	end

	if not success then
		Log.warn(`Failed to get text bounds: {bounds}`)
		return Vector2.zero
	end

	return bounds
end

return getTextBoundsAsync
