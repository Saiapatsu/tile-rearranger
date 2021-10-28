# tile-rearranger

Tools in Lua for rearranging tilesets.

Right now, they are specifically suited for manipulating Crossfire's smoothing maps.  
In addition, they assume that the tiles are 32x32.

There are example arrangements of smoothing edges in `example/`.  
The blob arrangement is from cr31.

The scripts were made for Windows and `luvit`, which has batteries that vanilla `lua` doesn't.  
You might have to turn that `p()` into `print()`.

## Usage

Drag and drop images onto any of the `to-*.lua` scripts and converted images will appear in the same directory.

* Start by converting your image to the `dot` layout.
* Modify it so that it resembles the `dot` example.
* Afterward, convert to `S`, which can be included in the game.
* The `bruh` layout contains the same tiles as `S`, but has more connections.
* The `blob` layout will show all possible edge/corner configurations, but not all possible connections - I haven't bothered looking for such a layout yet.
