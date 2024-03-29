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

-- returns specific bits of a char
local function qne(i) return bit.bor(bit.band(i, 3), bit.band(i, 128)) end -- 8, 1, 2
local function qse(i) return bit.band(i, 14)  end -- 2, 3, 4
local function qsw(i) return bit.band(i, 56)  end -- 4, 5, 6
local function qnw(i) return bit.band(i, 224) end -- 6, 7, 8

-- montages an array of tiles with append and without magick montage
-- modifies tbl in-place
local function montage(tbl, width, height)
	local ipos = width * height - width + 1
	local opos = width * height - width + height + 1
	while ipos >= 1 do
		table.move(tbl, ipos, ipos + width - 1, opos)
		tbl[opos - 1] = "+append ) ("
		ipos = ipos - width
		opos = opos - width - 1
	end
	tbl[1] = "("
	table.insert(tbl, "+append ) -append")
	return tbl
end

-- Generic conversion function
function common.convert(split, fromtag, totag)
	-- get layouts
	local src = assert(common.layouts[fromtag], "Unknown tag " .. fromtag)
	local dst = assert(common.layouts[totag]  , "Unknown tag " .. totag)
	
	local conv = {
		w = src.w,
		h = src.h,
		file = common.unparse(split.nameext),
		get = common.get, -- method
		q = {},
	}
	local rope = {} -- list of imagemagick operations, each of which generates a tile
	
	-- pre-chew information about source
	for i,v in ipairs(src) do
		conv[v] = i
		-- mark a quarter as available
		local ne, se, sw, nw = qne(v), qse(v), qsw(v), qnw(v)
		conv.q[ne] = v
		conv.q[se] = v
		conv.q[sw] = v
		conv.q[nw] = v
	end
	conv.q[0] = nil
	-- for i,v in ipairs(conv.q) do for k,v in pairs(v) do print(i, k, v) end end
	
	-- map output tiles to tiles from input
	for i,v in ipairs(dst) do rope[i] = conv:get(v) end
	
	-- build output filename
	local outpath = common.unparse(split.name .. (totag == "" and "" or ("_" .. totag)) .. split.ext)
	
	-- build command
	local command = table.concat({
		"cd " .. split.dir .. " & ", -- cd to image (for shorter command line)
		"magick",
		"-size 32x32",
		"-background #00000000",
		table.concat(montage(rope, dst.w, dst.h), " "),
		"-strip", -- strip unnecessary png chunks
		"png32:" .. outpath, -- output
	}, " ")
	
	p(command, #command)
	
	-- run
	local success, reason, exitcode = os.execute(command)
	
	if not success then
		print("Unable to convert " .. fromtag .. " to " .. totag)
		io.read()
	end
	
	return outpath
end

--------------------------------------------------------------------------------
--                                Tile composition
--------------------------------------------------------------------------------

-- index to position
local function xy(src, i)
	local x = (src[i]  -1)%src.w
	return x, (src[i]-x-1)/src.w
end

-- geometry expression to x, y, w, h
-- must be a full geometry
local function parseGeometry(geometry)
	local w, h, x, y = geometry:match("(%d+)x(%d+)([+-]%d+)([+-]%d+)")
	if not w then error("Not a fully formed geometry: " .. geometry, 2) end
	return tonumber(x), tonumber(y), tonumber(w), tonumber(h)
end

local function makeGeometry(x, y, w, h)
	return
		((w and h)
			and w .. "x" .. h
			or  "") ..
		((x and y)
			and (x < 0 and x or "+" .. x) .. (y < 0 and y or "+" .. y)
			or  "")
end

-- blank tile
local function empty() return "xc:#00000000" end

-- error tile
local function errtile() return "xc:#ff0000ff" end

local function getquarter(src, i, x, y)
	if i == 0 then
		return empty() .. "[16x16+0+0]"
	end
	
	if src[i] then
		local xx, yy = xy(src, i)
		return src.file .. "[" .. makeGeometry(x+xx*32, y+yy*32, 16, 16) .. "]"
	end
	
	if common.composition[i] then
		return table.concat({
			"(",
				common.composition[i](src, i),
				"-crop " .. makeGeometry(x, y, 16, 16),
				"+repage",
				"-flatten",
			")",
		}, " ")
		
	else
		return
	end
end

-- form a tile from quarters of other readily available tiles
local function quart(src, i)
	local ne, se, sw, nw = qne(i), qse(i), qsw(i), qnw(i)
	ne, se, sw, nw = -- fill empty tiles with empty parts of adjacent quarters of the same tile
		-- src.q[ne] or (src.q[se] and qne(src.q[se]) == 0 and src.q[se]) or (src.q[nw] and qne(src.q[nw]) == 0 and src.q[nw]) or 0,
		-- src.q[se] or (src.q[sw] and qse(src.q[sw]) == 0 and src.q[sw]) or (src.q[ne] and qse(src.q[ne]) == 0 and src.q[ne]) or 0,
		-- src.q[sw] or (src.q[nw] and qsw(src.q[nw]) == 0 and src.q[nw]) or (src.q[se] and qsw(src.q[se]) == 0 and src.q[se]) or 0,
		-- src.q[nw] or (src.q[ne] and qnw(src.q[ne]) == 0 and src.q[ne]) or (src.q[sw] and qnw(src.q[sw]) == 0 and src.q[sw]) or 0
		src.q[ne] or 0,
		src.q[se] or 0,
		src.q[sw] or 0,
		src.q[nw] or 0
	
	if not (ne == 0 and se == 0 and sw == 0 and nw == 0) then
		return table.concat({
			"(", table.concat(montage({
				getquarter(src, nw, 0 , 0 ),
				getquarter(src, ne, 16, 0 ),
				getquarter(src, sw, 0 , 16),
				getquarter(src, se, 16, 16),
			}, 2, 2), " "), ")",
		}, " ")
	end
	
	return
end

-- get a tile by id
local function get(src, i, geometry)
	if src[i] then
		-- exact match
		local xx, yy = xy(src, i)
		if geometry then
			local x, y, w, h = parseGeometry(geometry)
			return src.file .. "[" .. makeGeometry(x+xx*32, y+yy*32, w, h) .. "]"
		else
			return src.file .. "[" .. makeGeometry(xx*32, yy*32, 32, 32) .. "]"
		end
	end
	
	local q = quart(src, i)
	if q then return q end
	
	if common.composition[i] then
		if geometry then
			return table.concat({
				"(",
					common.composition[i](src, i),
					"-crop ", geometry,
					"+repage",
					"-flatten",
				")",
			}, " ")
		else
			return common.composition[i](src, i)
		end
	end
	
	return
end

-- overlay many tiles verbatim
local function combine(...)
	local args = {...}
	return function(src, i)
		local args2 = {}
		for i,v in ipairs(args) do
			args2[i] = get(src, v)
			if args2[i] == nil then return end
		end
		return "( " .. table.concat(args2, " ") .. " +repage -flatten )"
	end
end

-- attempt different operations until one succeeds
local function alternate(...)
	local args = {...}
	return function(src, i)
		for _, operation in ipairs(args) do
			local result = operation(src, i)
			if result then return result end
		end
	end
end

-- clip a part out of a tile
local function clip(geometry, tile)
	tile = tile or -1
	return function(src, i)
		return table.concat({
			"( ",
				get(src, tile, geometry),
				"-flatten",
			")",
		}, " ")
	end
end

-- like get() but always returns *something*
function common.get(...)
	return get(...) or errtile()
end

common.composition = {
	[ -1] = empty, -- solid tile
	[  0] = empty, -- blank tile
	-- --[=[
	-- the compass direction refers to which directions are solid
	-- corners      nw sw se ne
	[  1] = --[[   (          1),]] clip("15x15+17+0"),
	[  5] = combine(       4 ,1),
	[  4] = --[[   (       4   ),]] clip("15x15+17+17"),
	[ 20] = combine(   16 ,4   ),
	[ 21] = combine(   16 ,4 ,1),
	[ 17] = combine(   16    ,1),
	[ 16] = --[[   (   16      ),]] clip("15x15+0+17"),
	[ 80] = combine(64,16      ),
	[ 81] = combine(64,16    ,1),
	[ 85] = combine(64,16 ,4 ,1),
	[ 84] = combine(64,16 ,4   ),
	[ 68] = combine(64    ,4   ),
	[ 69] = combine(64    ,4 ,1),
	[ 65] = combine(64       ,1),
	[ 64] = --[[   (64         ),]] clip("15x15+0+0"),
	-- edges are combined in this order for favorable overlaps
	-- edges         s   w   n e
	[  7] = --[[   (           7),]] clip("15x32+17+0"),
	[ 31] = combine(28        ,7),
	[ 28] = --[[   (28          ),]] clip("32x15+0+17"),
	[124] = combine(28,112      ),
	[127] = combine(28,112    ,7),
	[119] = combine(   112    ,7),
	[112] = --[[   (   112      ),]] clip("15x32+0+0"),
	[241] = combine(   112,193  ),
	[247] = combine(   112,193,7),
	[255] = combine(28,112,193,7),
	[253] = combine(28,112,193  ),
	[221] = combine(28    ,193  ),
	[223] = combine(28    ,193,7),
	[199] = combine(       193,7),
	[193] = --[[   (       193  ),]] clip("32x15+0+0"),
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
	-- ]=]
}

common.layouts = {
	[""] = { -- single tile
		w = 1, h = 1,
		-1,
	}, dot = {
		w = 4, h = 3,
		4,  28,  16, -1,
		7, 255, 112,  0,
		1, 193,  64,  0,
	}, dothash = {
		w = 6, h = 3,
		4,  28,  16,  31, 127, 124,
		7, -1, 112, 223, 255, 253,
		1, 193,  64, 199, 247, 241,
	}, dagger = { -- rearranged dothash without loose ends
		w = 6, h = 3,
		4,  31, 127, 124,  28,  16,
		7, -1, 255, 253, 223, 112,
		1, 199, 247, 241, 193,  64,
	}, bruh = { -- rearranged S without loose ends
		w = 7, h = 5,
		255, 253, 81, 193, 69, 223,  -1,
		247, 241, 68,  20, 17, 199,  0,
		 85,  80,  1,  65, 64,   5,  0,
		119, 112,  4,  28, 16,   7,  0,
		127, 124, 21, 221, 84,  31,  0,
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
