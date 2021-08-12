local script, from, to = table.unpack(args)
local path = require("path")
local common = require(path.resolve(path.dirname(table.remove(args, 1)), "..", "common.lua"))
from, to = common.unparse(from), common.unparse(to)

local src = common.layouts.bruh
local dst = common.layouts.S

local src2 = {w = src.w, h = src.h}
for i,v in ipairs(src) do src2[v] = i end

local composition = {
	[-1] = function() return "-size 32x32 xc:#00000000" end,
	[0]  = function() return "-size 32x32 xc:#00000000" end,
}

local function get(from, src, i)
	if src[i] then
		-- exact match
		local x = (src[i]  -1)%src.w
		local y = (src[i]-x-1)/src.w
		return from .. "[32x32+" .. x*32 .. "+" .. y*32 .. "]"
	elseif composition[i] then
		return composition[i](from, src, i)
	else
		error("Unable to find or create tile " .. i)
	end
end

local dst2 = {w = dst.w, h = dst.h}
for i,v in ipairs(dst) do
	dst2[i] = get(from, src2, v)
end

os.execute(table.concat({
	"magick montage",
	"-background none",
	"-tile " .. dst2.w .. "x" .. dst2.h,
	"-geometry +0+0",
	table.concat(dst2, " "),
	common.unparse(to),
}, " "))

--[[ do return end ----------------------------------------

local foo = {}
for i = 0,15 do
	local j = 0
	if i&1 ~= 0 then j = j + 2 end
	if i&2 ~= 0 then j = j + 8 end
	if i&4 ~= 0 then j = j + 32 end
	if i&8 ~= 0 then j = j + 128 end
	table.insert(foo, j)
end
print(table.concat(foo, ", "))

local foo = {}
for i = 0,15 do
	local j = 0
	if i&1 ~= 0 then j = j + 1 end
	if i&2 ~= 0 then j = j + 4 end
	if i&4 ~= 0 then j = j + 16 end
	if i&8 ~= 0 then j = j + 64 end
	table.insert(foo, j)
end
print(table.concat(foo, ", "))
]]
