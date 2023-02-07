# tile-rearranger

Lua (Luvit) and ImageMagick scripts for rearranging Crossfire smoothing maps.  
They are meant for Windows and run shell commands in the Windows cmd syntax.

There are example arrangements of smoothing edges in `example/`.  
The blob arrangement is from cr31.

If you aren't aware of Luvit, bear in mind that Luvit provides a custom `require` which searches in `deps` and the libraries packaged into the executable, but not the current directory unless instructed to (with `./` or `../`). It falls back to Lua's `require`.  
Luvit comes with a lot of Node-inspired packages.

## Usage

Drag and drop images onto any of the `to-*.lua` scripts and converted images will appear in the same directory.

* Start by converting your image to the `dot` layout.
* Modify it so that it resembles the `dot` example.
* Afterward, convert to `S`, which can be included in the game.
* The `bruh` layout contains the same tiles as `S`, but has more connections.
* The `blob` layout will show all possible edge/corner configurations, but not all possible connections - I haven't bothered looking for such a layout yet.
