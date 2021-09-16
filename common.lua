local path = require("path")
local common = {}

--------------------------------------------------------------------------------
--                            Shell execution-related
--------------------------------------------------------------------------------

-- function unparse(str)
-- Fortifies str against Windows cmd followed by CommandLineToArgvW
-- cmd processes redirections and environment substitution whereas
-- CommandLineToArgvW and parse_cmdline split the string into arguments
-- Quotes, if necessary, will be placed around the string, not inside
function common.unparse(str)
	-- escape quotes and their leading backslashes
	str = str:gsub([[(\*)"]], [[%1%1\"]])
	
	-- surround in quotes, escape trailing backslashes
	-- bug: trailing or leading quotes in source string may form double quotes
	str = '"' .. str:gsub([[(\*)$]], [[%1%1"]])
	
	-- escape cmd characters
	str = str:gsub('[()<>^&|%!"\n]', "^%0")
	
	return str
	
	--[[
	-- right now, this function is defensive and makes super ugly strings
	
	os.execute and its ilk will execute something with cmd
	cmd will preprocess specific characters, split into commands etc.
	after this, it will execute programs with the resulting command lines
	programs themselves are responsible for splitting their args,
	generally using CommandLineToArgvW or parse_cmdline. they behave thus:
	quote toggles space parsing instead of "delimiting" anything, and
	backslashes are literal except when they're followed by a quote,
	in which case they escape each other and may escape the quote
	
	some programs do not use these functions to process arguments
	
	batch will mangle percents (and bangs if in delayed expansion mode),
	but that's out of the scope of this function
	
	https://docs.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way
	http://www.windowsinspired.com/understanding-the-command-line-string-and-arguments-received-by-a-windows-program/
	http://www.windowsinspired.com/how-a-windows-programs-splits-its-command-line-into-individual-arguments/
	
	]]
end
-- Copied on 20210916

--------------------------------------------------------------------------------
--                              Filename management
--------------------------------------------------------------------------------

--[[
common.split(C:\Smoothing\fly_shop_empty_dot.base.111.png) = {
	href    = C:\Smoothing\fly_shop_empty_dot.base.111.png
	dir     = C:\Smoothing
	nameext = fly_shop_empty_dot.base.111.png
	nametag = fly_shop_empty_dot
	name    = fly_shop_empty
	tag     =                dot
	ext     =                   .base.111.png
	
	tag will be one of those described in common.layouts
}
]]
function common.split(target)
	local split = {}
	split.href = target
	split.dir = path.dirname(target)
	split.nameext = path.basename(target)
	split.nametag, split.ext = split.nameext:match("([^.]*)(%..*)")
	split.name, split.tag = split.nametag:match("(.*)_(.*)")
	if split.name == nil then split.name, split.tag = split.nametag, "" end
	
	if common.layouts[split.tag] == nil then
		split.name, split.tag = split.name .. "_" .. split.tag, ""
	end
	
	return split
end

--------------------------------------------------------------------------------
--                                  Conversion
--------------------------------------------------------------------------------

-- Generic conversion function
function common.convert(split, fromtag, totag)
	-- get layouts
	local src = assert(common.layouts[fromtag], "Unknown tag " .. fromtag)
	local dst = assert(common.layouts[totag]  , "Unknown tag " .. totag)
	
	local invsrc = {w = src.w, h = src.h} -- inverse of src
	for i,v in ipairs(src) do invsrc[v] = i end
	
	local rope = {} -- list of imagemagick operations, each generating a tile of dst
	for i,v in ipairs(dst) do rope[i] = common.get(common.unparse(split.nameext), invsrc, v) end
	
	-- output name
	local outname = split.name .. (totag == "" and "" or ("_" .. totag)) .. split.ext
	
	-- build montage command
	local command = table.concat({
		"cd " .. split.dir .. " & ",         -- cd to image (for shorter command line)
		"magick montage",                    -- arrange tiles in a grid
		"-tile " .. dst.w .. "x" .. dst.h,   -- grid size is w*h
		"-size 32x32",
		"-background none",                  -- transparent background
		"-geometry +0+0",                    -- no space between tiles
		table.concat(rope, " "),
		"-strip",                            -- strip unnecessary png chunks
		common.unparse(outname),             -- output
	}, " ")
	
	p(command, #command)
	
	-- run
	local success, reason, exitcode = os.execute(command)
	
	if not success then
		print("Unable to convert " .. fromtag .. " to " .. totag)
		io.read()
	end
end

--------------------------------------------------------------------------------
--                                Tile composition
--------------------------------------------------------------------------------

-- blank tile
local function empty() return "xc:#00000000" end

-- clip a part out of a solid tile
local function clip(geometry)
	return function(from, src, i)
		return table.concat({"(", -- separate stack from the other images
			common.get(from, src, -1), -- solid tile
			"-crop " .. geometry, -- leave only the specified area. the
			--                        "virtual canvas" position remains!
			empty(), -- a transparent image the size of one tile
			"-flatten", -- flatten into one tile-sized layer with the tile
			--            in the right spot
		")"}, " ")
	end
end

-- overlay many tiles
local function combine(...)
	local args = {...}
	return function(from, src, i)
		local args2 = {}
		for i,v in ipairs(args) do
			args2[i] = common.get(from, src, v)
		end
		return "( " .. table.concat(args2, " ") .. " +repage -flatten )"
	end
end

common.composition = {
	[ -1] = empty, -- solid tile
	[  0] = empty, -- blank tile
	-- the compass direction refers to which directions are solid
	-- corners      nw sw se ne
	[  1] = --[[   (          1),]] clip("15x15+17+0"),
	[  4] = --[[   (       4   ),]] clip("15x15+17+17"),
	[  5] = combine(       4 ,1),
	[ 16] = --[[   (   16      ),]] clip("15x15+0+17"),
	[ 17] = combine(   16    ,1),
	[ 20] = combine(   16 ,4   ),
	[ 21] = combine(   16 ,4 ,1),
	[ 64] = --[[   (64         ),]] clip("15x15+0+0"),
	[ 65] = combine(64       ,1),
	[ 68] = combine(64    ,4   ),
	[ 69] = combine(64    ,4 ,1),
	[ 80] = combine(64,16      ),
	[ 81] = combine(64,16    ,1),
	[ 84] = combine(64,16 ,4   ),
	[ 85] = combine(64,16 ,4 ,1),
	-- edges         s   w   n e
	[  7] = --[[   (           7),]] clip("15x32+17+0"),
	[ 28] = --[[   (28          ),]] clip("32x15+0+17"),
	[ 31] = combine(28        ,7),
	[112] = --[[   (   112      ),]] clip("15x32+0+0"),
	[119] = combine(   112    ,7),
	[124] = combine(28,112      ),
	[127] = combine(28,112    ,7),
	[193] = --[[   (       193  ),]] clip("32x15+0+0"),
	[199] = combine(       193,7),
	[221] = combine(28    ,193  ),
	[223] = combine(28    ,193,7),
	[241] = combine(   112,193  ),
	[247] = combine(   112,193,7),
	[253] = combine(28,112,193  ),
	[255] = combine(28,112,193,7),
	-- combined
	[ 23] = combine(  7, 16),
	[ 71] = combine(  7, 64),
	[ 87] = combine(  7, 80),
	[ 29] = combine( 28,  1),
	[ 92] = combine( 28, 64),
	[ 93] = combine( 28, 65),
	[113] = combine(112,  1),
	[116] = combine(112,  4),
	[117] = combine(112,  5),
	[197] = combine(193,  4),
	[209] = combine(193, 16),
	[213] = combine(193, 20),
	[125] = combine(124,  1),
	[245] = combine(241,  4),
	[215] = combine(199, 16),
	[ 95] = combine( 31, 64),
}

function common.get(from, src, i)
	if src[i] then
		-- exact match
		local x = (src[i]  -1)%src.w
		local y = (src[i]-x-1)/src.w
		return from .. "[32x32+" .. x*32 .. "+" .. y*32 .. "]"
		
	elseif common.composition[i] then
		return common.composition[i](from, src, i)
		
	else
		-- error("Unable to find or create tile " .. i)
		return "xc:#ff0000ff"
	end
end

common.layouts = {
	[""] = { -- single tile
		w = 1, h = 1,
		-1,
	}, dot = {
		w = 3, h = 3,
		4,  28,  16,
		7,  -1, 112,
		1, 193,  64,
	}, dothash = {
		w = 6, h = 3,
		4,  28,  16,  31, 127, 124,
		7,  -1, 112, 223, 255, 253,
		1, 193,  64, 199, 247, 241,
	}, dagger = { -- rearranged dothash without loose ends
		w = 6, h = 3,
		4,  31, 127, 124,  28,  16,
		7,  -1, 255, 253, 223, 112,
		1, 199, 247, 241, 193,  64,
	}, bruh = { -- rearranged S without loose ends
		w = 6, h = 5,
		255, 253, 81, 193, 69, 223,
		247, 241, 68,  20, 17, 199,
		 85,  80,  1,  65, 64,   5,
		119, 112,  4,  28, 16,   7,
		127, 124, 21, 221, 84,  31,
	}, S = {
		w = 16, h = 2,
		-1, 112, 193, 241, 7, 119, 199, 247, 28, 124, 221, 253, 31, 127, 223, 255,
		 0,  64,   1,  65, 4,  68,   5,  69, 16,  80,  17,  81, 20,  84,  21,  85,
	}, blob = { -- cr31 blob
		w = 7, h = 7,
		255, 253, 209, 193, 197, 215,  -1,
		247, 245,  84,  16,   7, 117, 223,
		113,  69,  85,  92,  17,  65, 199,
		112,   1,  71, 241,  64,   4,  23,
		116,  28,  21,  80,   0,   5,  87,
		125, 213,  81,  68,  20,  31, 119,
		 -1, 127, 124,  29,  93, 221,  95,
	--[[ }, blob = { -- wall blob
		w = 7, h = 7,
		  0,   2,  46,  62,  58,  40,   0,
		  8,  10, 171, 239, 248, 138,  32,
		142, 186, 170, 163, 238, 190,  56,
		143, 254, 184,  14, 191, 251, 232,
		139, 227, 234, 175, 255, 250, 168,
		130,  42, 174, 187, 235, 224, 136,
		  0, 128, 131, 226, 162,  34, 160,
		]]
	},
}

--[[
-- fix spaces
([^\n, ]+)( +)
$2$1

-- dilate orthogonals
dofunc(function(text)
	return text:gsub("%d+", function(x)
		return x | dilate(x & 170)
	end)
end)

-- fix numbering mistake
dofunc(function(text)
	return text:gsub("%d+", function(x)
		local edges = (x & 170)
		local corners = (x & ~dilate(edges))
		return bitroll(corners, 2) | dilate(bitroll(edges, 4))
	end)
end)

-- convert misaligned cr31 wall blob to aligned edge blob
dofunc(function(text)
	return text:gsub("%d+", function(x)
		return bitroll(~x & 255, 1)
	end)
end)

-- construct an image with id labels over each tile
local layout = { -- cr31 blob
		w = 7, h = 7,
		255, 253, 209, 193, 197, 215,  -1,
		247, 245,  84,  16,   7, 117, 223,
		113,  69,  85,  92,  17,  65, 199,
		112,   1,  71, 241,  64,   4,  23,
		116,  28,  21,  80,   0,   5,  87,
		125, 213,  81,  68,  20,  31, 119,
		 -1, 127, 124,  29,  93, 221,  95,
}
for k,v in ipairs(layout) do
	layout[k] = "label:" .. v
end
for i = layout.h-1, 1, -1 do
	table.insert(layout, i * layout.w + 1, "+append ) (")
end
print(table.concat({
	"magick",
	"-size 32x32",
	"-background none",
	"-gravity center -pointsize 10 -fill white -font Arial +antialias",
	"( " .. table.concat(layout, " ") .. " +append )",
	"-append",
	"out.png",
}, " "))

]]

--------------------------------------------------------------------------------
--                                    Export
--------------------------------------------------------------------------------

return common
