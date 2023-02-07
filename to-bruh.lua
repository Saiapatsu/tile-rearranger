local common = require("./common")
local toWhat = table.remove(args, 1):match(".*%-(.*)%.lua$")
for _,target in ipairs(args) do
	local split = common.split(target)
	local success, outpath = pcall(common.convert, split, split.tag, toWhat)
	print(success, outpath)
end
