-- whichtiles.lua <inthis> <these>
-- inthis    path to image to annotate
-- these     path to image to look for pieces of in inthis

-- NB! does naive shell execution

-- future: get a layout from common.lua and emit a new layout
-- with known tiles in their right places and unknowns marked with e.g. X1, X2...
-- so they stand out in a syntax highlighter

local script = table.remove(args, 1) -- yes, unpack is a thing too
local inthis = table.remove(args, 1)
local these  = table.remove(args, 1)

local w = 32
local h = 32
local stride = 4
local depth = 8
local size = w * h * stride * depth/8

local mapinthis = {}
local file = io.popen(table.concat({
	"magick",
	"-depth", depth,
	inthis,
	" -crop", w .. "x" .. h,
	"-append",
	"RGBA:-",
}, " "))

for tile in function() return file:read(size) end do
	mapinthis[tile] = true
end
file:close()

local file = io.popen(table.concat({
	"magick",
	"-depth", depth,
	these,
	" -crop", w .. "x" .. h,
	"-append",
	"RGBA:-",
}, " "))

local many = 0

for tile in function() return file:read(size) end do
	if mapinthis[tile] then
		many = many + 1
	end
end
file:close()

print(many .. " matches found")
