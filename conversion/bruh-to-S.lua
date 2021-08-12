local script, from, to = table.unpack(args)
local path = require("path")
local common = require(path.resolve(path.dirname(table.remove(args, 1)), "..", "common.lua"))

local src = common.layouts.bruh
local dst = common.layouts.S

local src2 = {}
for i,v in ipairs(src) do
	local x = (i  -1)%src.w
	local y = (i-x-1)/src.w
	src2[v] = common.unparse(from) .. "[32x32+" .. x*32 .. "+" .. y*32 .. "]"
end
src2[0] = "-size 32x32 xc:#00000000"

for i,v in ipairs(dst) do
	dst[i] = assert(src2[v], tostring(v))
end

os.execute(table.concat({
	"magick montage",
	"-background none",
	"-tile " .. dst.w .. "x" .. dst.h,
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
