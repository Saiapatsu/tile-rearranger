local script, from, to = table.unpack(args)
local path = require("path")
local common = require(path.resolve(path.dirname(table.remove(args, 1)), "..", "common.lua"))

local stride = 6
local src = {
	170, 138, 69,   8, 21, 168,
	 42,  10, 17,  80, 68,  40,
	 85,  65,  4,   5,  1,  20,
	 34,   2, 16, 128, 64,  32,
	162, 130, 84, 136, 81, 160,
}

local w = 16
local h = 2
local dst = {
	0, 2, 8, 10, 32, 34, 40, 42, 128, 130, 136, 138, 160, 162, 168, 170,
	0, 1, 4,  5, 16, 17, 20, 21,  64,  65,  68,  69,  80,  81,  84,  85,
}

local src2 = {}
for i,v in ipairs(src) do
	local x = (i  -1)%stride
	local y = (i-x-1)/stride
	src2[v] = common.unparse(from) .. "[32x32+" .. x*32 .. "+" .. y*32 .. "]"
end
src2[0] = "-size 32x32 xc:#00000000"

for i,v in ipairs(dst) do
	dst[i] = assert(src2[v], tostring(v))
end

os.execute(table.concat({
	"magick montage",
	"-background none",
	"-tile " .. w .. "x" .. h,
	"-geometry +0+0",
	table.concat(dst, " "),
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
