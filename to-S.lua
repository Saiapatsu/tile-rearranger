local path = require("path")
local script = table.remove(args, 1)
local common = require(path.resolve(path.dirname(script), "common.lua")) -- ignore "current directory"

local toWhat = script:match(".*%-(.*)%.lua$")
for _,target in ipairs(args) do
	local split = common.split(target)
	
	local success, err = pcall(common.convert, split, split.tag, toWhat)
	print(success, err)
end
