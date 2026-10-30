-- Renders .aseprite sources to PNG for tools/export_art.py, which runs it as
--
--   aseprite -b --script-param jobs=<jobs.tsv> --script tools/export_art.lua
--
-- Each jobs line is "<source>\t<output base>". A one-frame source becomes
-- <base>.png; a multi-frame source becomes <base>-Sheet.png, a horizontal
-- strip of every frame. Only visible layers are drawn, so hiding a layer is
-- how a source keeps work-in-progress out of the game. Prints one line per job:
-- "ok\t<source>\t<png written>" or "error\t<source>\t<reason>".
local jobs = app.params["jobs"]
assert(jobs, "pass --script-param jobs=<file>")

local function render(src, base)
  local spr = app.open(src)
  if not spr then error("could not open") end
  local w, h, n = spr.width, spr.height, #spr.frames
  local out = Image(w * n, h, ColorMode.RGB)
  for f = 1, n do
    local frame = Image(w, h, ColorMode.RGB)
    frame:drawSprite(spr, f)
    out:drawImage(frame, Point((f - 1) * w, 0))
  end
  spr:close()
  local path = base .. ((n > 1) and "-Sheet.png" or ".png")
  out:saveAs(path)
  return path
end

for line in io.lines(jobs) do
  local src, base = line:match("^(.-)\t(.*)$")
  if src then
    local ok, result = pcall(render, src, base)
    print((ok and "ok" or "error") .. "\t" .. src .. "\t" .. tostring(result))
  end
end
