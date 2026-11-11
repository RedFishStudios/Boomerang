--!strict
-- Ribbon renderer for FanTrails: draws a style's ribbon layers along a trail's recent path as chains of
-- camera-facing Beams (one Beam per path segment, per layer), so the ribbon reads from overhead and the side, keeps
-- normal depth (hidden behind walls), and never spins with the fan.
--
-- A layer is a stripe of the ribbon (see the `Layers` list in each style). Each point of the path carries `f`: 0 at
-- the fan, 1 at the trail's full length behind it. Layers can cover part of that range (`Range`), sit off-centre
-- (`Offset`, in ribbon widths, + is the camera's right of the path), ripple their width (`Wave`), sway sideways
-- (`Wiggle`) and fan out towards the tail (`Spread`, used for the Phoenix's feather tips).

local Ribbon = {}

-- Curved, seamless beams (see Ribbon.draw). Set SMOOTH = false to fall back to straight segments.
Ribbon.SMOOTH = true
Ribbon.CURVE_SEGMENTS = 4

export type ColorKey = { number | Color3 } -- { f, Color3 }
export type Layer = {
	Name: string,
	Width: number, -- times the style's Width
	Colors: { ColorKey }, -- along the trail: f = 0 at the fan to 1 at the tail
	Transparency: { number }?, -- { at the fan, at the tail }; defaults to the style's
	TransparencyPower: number?, -- how quickly it fades along the trail (1 = linear)
	Range: { number }?, -- { from f, to f }; the layer only covers this part of the trail
	Taper: number?, -- width falls off as (1 - u) ^ Taper over the layer's range (0 = constant, default 0.45)
	Offset: number?, -- sideways, in ribbon widths at that point (+ = right as seen from the camera)
	Spread: number?, -- extra sideways offset reached at the end of the range, in style widths (feather tips)
	Wave: { number }?, -- { amplitude (fraction of width), cycles per fan span travelled, speed (cycles/s), phase }
	Wiggle: { number }?, -- { amplitude (ribbon widths), cycles per span, speed (cycles/s), phase }
	Glow: number?, -- Beam.LightEmission; keep low (restrained glow)
	ZOffset: number?, -- draw order between layers (higher draws on top)
}

export type PathPoint = { pos: Vector3, dist: number, f: number }

type LayerPool = { attachments: { Attachment }, beams: { Beam } }
export type Renderer = { folder: Instance, anchor: BasePart, pools: { LayerPool }, depth: number, layerStep: number }

local function colorAt(keys: { ColorKey }, f: number): Color3
	local first = keys[1]
	if f <= (first[1] :: number) then
		return first[2] :: Color3
	end
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		local fa, fb = a[1] :: number, b[1] :: number
		if f <= fb then
			local u = if fb > fa then (f - fa) / (fb - fa) else 0
			return (a[2] :: Color3):Lerp(b[2] :: Color3, u)
		end
	end
	return keys[#keys][2] :: Color3
end
Ribbon.colorAt = colorAt

-- `span` sets the depth offsets: the ribbon is drawn slightly behind the fan (as seen from the camera) so the fan
-- keeps its silhouette at the front, and layers are stacked by a small step in draw order.
function Ribbon.new(folder: Instance, layerCount: number, span: number): Renderer
	-- Attachments live in an invisible anchored part at the world origin, so their positions are world positions.
	local anchor = Instance.new("Part")
	anchor.Name = "RibbonAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.05, 0.05, 0.05)
	anchor.CFrame = CFrame.new()
	anchor.Parent = folder
	local pools = {}
	for i = 1, layerCount do
		pools[i] = { attachments = {}, beams = {} }
	end
	return { folder = folder, anchor = anchor, pools = pools, depth = -0.07 * span, layerStep = 0.012 * span }
end

local function ensure(renderer: Renderer, pool: LayerPool, count: number, layer: Layer)
	while #pool.attachments < count do
		local a = Instance.new("Attachment")
		a.Parent = renderer.anchor
		table.insert(pool.attachments, a)
	end
	while #pool.beams < count - 1 do
		local i = #pool.beams + 1
		local b = Instance.new("Beam")
		b.Name = layer.Name
		b.FaceCamera = true
		b.Segments = Ribbon.CURVE_SEGMENTS
		b.LightInfluence = 0
		b.LightEmission = layer.Glow or 0
		b.ZOffset = renderer.depth + (layer.ZOffset or 0) * renderer.layerStep
		b.Attachment0 = pool.attachments[i]
		b.Attachment1 = pool.attachments[i + 1]
		b.Enabled = false
		b.Parent = renderer.anchor
		table.insert(pool.beams, b)
	end
end

-- The part of the path inside [from, to] (in f), with exact end points interpolated at the range's edges.
local function clip(points: { PathPoint }, from: number, to: number): { PathPoint }
	if from <= 0 and to >= 1 then
		return points
	end
	local out = {}
	for i, p in points do
		local inside = p.f >= from and p.f <= to
		local prev = points[i - 1]
		if prev then
			for _, edge in { from, to } do
				if (prev.f < edge and p.f > edge) or (prev.f > edge and p.f < edge) then
					local u = (edge - prev.f) / (p.f - prev.f)
					table.insert(out, {
						pos = prev.pos:Lerp(p.pos, u),
						dist = prev.dist + (p.dist - prev.dist) * u,
						f = edge,
					})
				end
			end
		end
		if inside then
			table.insert(out, p)
		end
	end
	table.sort(out, function(a, b)
		return a.f < b.f
	end)
	return out
end

-- The sideways direction at each point: across the path as seen from the camera.
function Ribbon.sides(points: { PathPoint }, cameraPos: Vector3): { Vector3 }
	local sides = {}
	local last = Vector3.xAxis
	for i, p in points do
		local a = points[math.max(i - 1, 1)].pos
		local b = points[math.min(i + 1, #points)].pos
		local tangent = a - b -- towards the fan
		local side = if tangent.Magnitude > 1e-4 then tangent.Unit:Cross((cameraPos - p.pos).Unit) else last
		if side.Magnitude > 1e-4 then
			side = side.Unit
			last = side
		else
			side = last
		end
		sides[i] = side
	end
	return sides
end

-- Draw every layer along `points` (fan first). `width` is the style's ribbon width in studs, `span` the fan's
-- tip-to-tip length, `fade` 0..1 extra fade for the whole trail (after the fan stops).
function Ribbon.draw(
	renderer: Renderer,
	layers: { Layer },
	points: { PathPoint },
	style: { Transparency: { number }, TransparencyPower: number? },
	width: number,
	span: number,
	now: number,
	cameraPos: Vector3,
	fade: number
)
	for li, layer in layers do
		local pool = renderer.pools[li]
		local range = layer.Range or { 0, 1 }
		local pts = if #points >= 2 then clip(points, range[1], range[2]) else {}
		local n = #pts
		if n >= 2 then
			ensure(renderer, pool, n, layer)
			local sides = Ribbon.sides(pts, cameraPos)
			local trans = layer.Transparency or style.Transparency
			local tpow = layer.TransparencyPower or style.TransparencyPower or 1
			local widths, alphas, colors, places = table.create(n), table.create(n), table.create(n), table.create(n)
			local rangeLen = math.max(range[2] - range[1], 1e-3)
			for i, p in pts do
				local u = math.clamp((p.f - range[1]) / rangeLen, 0, 1)
				local w = width * layer.Width * (1 - u) ^ (layer.Taper or 0.45)
				local steady = w -- offsets use the width before the ripple, so rippling never moves a layer sideways
				local travelled = p.dist / span
				if layer.Wave then
					local wv = layer.Wave
					w *= 1 + wv[1] * math.sin(2 * math.pi * (travelled * wv[2] - now * wv[3]) + (wv[4] or 0))
				end
				local offset = (layer.Offset or 0) * steady + (layer.Spread or 0) * width * u
				if layer.Wiggle then
					local wg = layer.Wiggle
					offset += wg[1] * width * math.sin(2 * math.pi * (travelled * wg[2] - now * wg[3]) + (wg[4] or 0)) * math.min(
						p.f * 6,
						1
					) -- pinned at the fan, free further back
				end
				places[i] = p.pos + sides[i] * offset
				widths[i] = math.max(w, 0)
				local t = trans[1] + (trans[2] - trans[1]) * math.clamp(p.f, 0, 1) ^ tpow
				alphas[i] = 1 - (1 - t) * (1 - fade)
				colors[i] = colorAt(layer.Colors, p.f)
			end
			-- Each attachment points its X axis along the ribbon (away from the fan) and every beam is a short curve whose
			-- ends follow those axes (CurveSize0/1), so neighbouring beams meet with the same direction and width line:
			-- a seamless ribbon instead of a sawtooth of straight pieces on tight curves.
			for i = 1, n do
				local ahead = places[math.max(i - 1, 1)]
				local behind = places[math.min(i + 1, n)]
				local tangent = behind - ahead
				tangent = if tangent.Magnitude > 1e-4 then tangent.Unit else Vector3.zAxis
				local up = Vector3.yAxis - tangent * tangent.Y
				up = if up.Magnitude > 1e-3 then up.Unit else Vector3.new(1, 0, 0):Cross(tangent).Unit
				pool.attachments[i].CFrame = CFrame.fromMatrix(places[i], tangent, up)
			end
			for i = 1, n - 1 do
				local b = pool.beams[i]
				local third = (places[i + 1] - places[i]).Magnitude / 3
				b.CurveSize0 = if Ribbon.SMOOTH then third else 0
				b.CurveSize1 = if Ribbon.SMOOTH then third else 0
				b.Width0 = widths[i]
				b.Width1 = widths[i + 1]
				b.Transparency = NumberSequence.new(alphas[i], alphas[i + 1])
				b.Color = ColorSequence.new(colors[i], colors[i + 1])
				b.Enabled = true
			end
			for i = n, #pool.beams do
				pool.beams[i].Enabled = false
			end
		else
			for _, b in pool.beams do
				b.Enabled = false
			end
		end
	end
end

function Ribbon.hide(renderer: Renderer)
	for _, pool in renderer.pools do
		for _, b in pool.beams do
			b.Enabled = false
		end
	end
end

return Ribbon
