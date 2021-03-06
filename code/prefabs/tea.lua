BindGlobal()


local Configurable = wickerrequire 'adjectives.configurable'

local MakeBeverage = pkgrequire 'common.hotbeverage'

local cfg = Configurable("HOTBEVERAGE", "TEA")


--[[
-- Basic tea data, as used by MakeBeverage.
--]]
local basic_tea_data = {
	bank = "food",

	perish_time = cfg:GetConfig("PERISH_TIME"),
	heat_capacity = cfg:GetConfig("HEAT_CAPACITY"),
}

--[[
-- Specific tea data.
--]]
local tea_data = {
	greentea = MergeMaps(basic_tea_data, {
		name = "greentea",

		assets = {
			Asset("ANIM", "anim/cook_pot_food.zip"),
		},

		build = "cook_pot_food",
		anim = "fruitmedley",
		inventory_atlas = "images/inventoryimages/greentea.xml",

		health = TUNING.HEALING_SMALL,
		sanity = TUNING.SANITY_TINY,

		temperature = 80,
	}),

	blacktea = MergeMaps(basic_tea_data, {
		assets = {
			Asset("ANIM", "anim/cook_pot_food.zip"),
		},

		build = "cook_pot_food",
		anim = "fruitmedley",
		inventory_atlas = "images/inventoryimages/blacktea.xml",

		health = TUNING.HEALING_TINY,
		sanity = TUNING.SANITY_SMALL,

		temperature = 100,
	}),
}


local basic_teas = (function()
	local ret = {}
	for k in pairs(tea_data) do
		table.insert(ret, k)
	end
	return ret
end)()


for _, tea in ipairs(basic_teas) do
	local sweet_tea = "sweet_"..tea
	tea_data[sweet_tea] = MergeMaps(tea_data[tea], {
		hunger = TUNING.CALORIES_SMALL,
	})
	if STRINGS.NAMES[tea:upper()] then
		STRINGS.NAMES[sweet_tea:upper()] = "Sweet "..STRINGS.NAMES[tea:upper()]
	end
end


local tea_prefabs = {}
for tea, data in pairs(tea_data) do
	table.insert(tea_prefabs, MakeBeverage(tea, data))
end

return tea_prefabs
