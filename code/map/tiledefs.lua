

local new_tiles = TheMod:GetConfig("NEW_TILES")


--[[
-- Addition of custom tiles
--]]

for i, v in ipairs(new_tiles) do
	TheMod:AddTile(v:upper(), 64 + i, "" .. v .. "", {noise_texture = "noise_" .. v .. ".tex"}, {noise_texture = "mini_noise_" .. v .. ".tex"})
end
