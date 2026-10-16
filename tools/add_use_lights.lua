-- Adds Bump-style use indicator lights to a single-frame 24x24 tile.
--
--   aseprite -b Assets/Textures/Tiles/<Colour>Tiles/<name>.aseprite \
--     --script-param uses=<1-3> \
--     --script-param sheet=$PWD/Assets/Textures/Tiles/<Colour>Tiles/<name>-Sheet.png \
--     --script tools/add_use_lights.lua
--
-- Rewrites the .aseprite in place as uses+1 frames and exports the horizontal
-- -Sheet.png. Frame k has k lit lights, because Tile shows frame
-- uses_remaining. The slots are carved into the right edge of the lower panel,
-- 2x2 each, stacked up from the bottom with a 1px border between them, using
-- the tile's own outline colour, so every colour of tile matches Bump.
local n = tonumber(app.params["uses"])
local sheet = app.params["sheet"]
local spr = app.activeSprite
assert(n and n >= 1 and n <= 3, "uses must be 1-3; there is room for three lights")
assert(#spr.frames == 1, "expected a single-frame tile")
assert(#spr.layers == 1, "flatten the tile to one layer first")
local layer = spr.layers[1]
local base = Image(spr.spec)
base:drawSprite(spr, 1)
local border = base:getPixel(22, 15)
local unlit = app.pixelColor.rgba(0x07, 0x03, 0x26, 255)
local lit = app.pixelColor.rgba(0xce, 0xf0, 0xf1, 255)
for f = 0, n do
  local frame = (f == 0) and spr.frames[1] or spr:newEmptyFrame()
  local img = base:clone()
  for k = 1, n do
    local top = 20 - 3 * (k - 1)
    img:drawPixel(20, top - 1, border); img:drawPixel(21, top - 1, border)
    for y = top, top + 1 do
      img:drawPixel(19, y, border)
      local c = (k <= f) and lit or unlit
      img:drawPixel(20, y, c); img:drawPixel(21, y, c)
    end
  end
  img:drawPixel(20, 22, border)
  local cel = layer:cel(frame)
  if cel then cel.image = img; cel.position = Point(0, 0) else spr:newCel(layer, frame, img, Point(0, 0)) end
end
spr:saveAs(spr.filename)
app.command.ExportSpriteSheet{ ui=false, type=SpriteSheetType.HORIZONTAL, textureFilename=sheet }
print("ok frames=" .. #spr.frames)
