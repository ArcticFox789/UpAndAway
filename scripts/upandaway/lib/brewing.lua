---
-- Defines the brewing logic API.
--
-- @class module
-- @name upandaway.lib.brewing
--

--@@ENVIRONMENT BOOTUP
local _modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )
module( ..., require(_modname .. '.booter') )
--@@END ENVIRONMENT BOOTUP


local Lambda = wickerrequire 'paradigms.functional'
local Logic = wickerrequire 'paradigms.logic'

local Pred = wickerrequire 'lib.predicates'

local Debuggable = wickerrequire 'adjectives.debuggable'

local table = wickerrequire 'utils.table'


local function myassert(level, test, msg_format, ...)
	if not test then
		return error(msg_format:format(...), level + 1)
	end
end


--[[
-- Each recipe test takes as parameters:
-- + The ingredient list.
-- + The stewer entity.
--]]
Condition = Class(function(self, fn)
	myassert(2, Lambda.IsFunctional(fn), "Function expected as 'fn' parameter.")
	self.fn = fn
end)

Pred.IsBrewingCondition = Pred.IsInstanceOf(Condition)
local IsCondition = Pred.IsBrewingCondition

local function to_condition(x)
	if IsCondition(x) then
		return x
	else
		return Condition(x)
	end
end

function Condition:__call(ings, kettle, dude)
	return self.fn(ings, kettle, dude)
end

function Condition.Similar(A, B)
	return to_condition(A).fn == to_condition(B).fn
end

Condition.__eq = Condition.Similar

function Condition.__add(A, B)
	return Condition( Lambda.And(to_condition(A).fn, to_condition(B).fn) )
end

function Condition.__div(A, B)
	return Condition( Lambda.Or(to_condition(A).fn, to_condition(B).fn) )
end

function Condition:__unm()
	return Condition( Lambda.Not(self.fn) )
end

function Condition.__pow(A, B)
	return Condition( Lambda.Xor(A.fn, B.fn) )
end


--[[
-- Acts on elements instead of the full ingredient list.
--
-- Count marks how many elements must pass the test.
--]]
AtomicCondition = Class(Condition, function(self, fn, count)
	myassert(2, Lambda.IsFunctional(fn), "Function expected as 'fn' parameter.")

	count = count or 1
	myassert(2, Pred.IsNumber(count), "Number or nil expected as 'count' parameter.")

	self.count = count
	self.basic_fn = fn

	Condition._ctor(self, function(ings, kettle, dude)
		local n = self.count
		local fn = self.basic_fn
		for _, I in ipairs(ings) do
			if fn(I, kettle, dude) then
				n = n - 1
				if n <= 0 then break end
			end
		end
		return n <= 0
	end)
end)

Pred.IsAtomicBrewingCondition = Pred.IsInstanceOf(AtomicCondition)
local IsAtomicCondition = Pred.IsAtomicBrewingCondition

function AtomicCondition.Similar(A, B)
	return IsAtomicCondition(A) and IsAtomicCondition(B) and A.basic_fn == B.basic_fn
end

function AtomicCondition.__eq(A, B)
	return AtomicCondition.Similar(A, B) and A.count == B.count
end

function AtomicCondition.__mul(k, A)
	if Pred.IsNumber(A) then
		k, A = A, k
	else
		myassert(2, Pred.IsNumber(k), "Number expected as factor.")
	end
	return AtomicCondition(A.basic_fn, k*A.count)
end


local IsPrefab = (function()
	--[[
	-- This check is just to avoid errors if used at worldgen.
	--]]
	if not Pred.PrefabExists then
		return Lambda.Constant( Lambda.False )
	end

	local cache = setmetatable({}, {__mode = "v"})

	return function(prefabname)
		if not (Pred.IsString(prefabname) and Pred.PrefabExists(prefabname)) then
			return error("'"..tostring(prefabname).."' is not a valid prefab.", 3)
		end

		if not cache[prefabname] then
			cache[prefabname] = function(inst)
				return inst.prefab == prefabname
			end
		end
		return cache[prefabname]
	end
end)()

-- Not to be confused with the vanilla Ingredient class.
Ingredient = Class(AtomicCondition, function(self, prefab, count)
	AtomicCondition._ctor(self, IsPrefab(prefab), count)
end)


--[[
-- Not to be confused with the vanilla Recipe class.
-- ]]
Recipe = Class(Debuggable, function(self, name, condition, priority, brewing_time)
	Debuggable._ctor(self, "Brewing recipe "..name)
	self:SetConfigurationKey("BREWING_RECIPE")

	if not Pred.IsString(name) or (Pred.PrefabExists and not Pred.PrefabExists(name)) then
		return error("'"..tostring(name).."' is not a valid prefab.", 2)
	end

	priority = priority or 0
	myassert( 2, Pred.IsNumber(priority), "Number or nil expected as 'priority' parameter." )

	brewing_time = brewing_time or 1
	myassert( 2, Pred.IsNonNegativeNumber(brewing_time), "Non-negative number expected as 'brewing_time' parameter." )

	self.name = name
	self.condition = to_condition(condition)
	self.priority = priority
	self.brewing_time = brewing_time
end)

Pred.IsBrewingRecipe = Pred.IsInstanceOf(Recipe)
local IsRecipe = Pred.IsBrewingRecipe

local function recipe_check(self)
	if not IsRecipe(self) then
		return error( "Recipe object expected as 'self' parameter.", 3 )
	end
end

function Recipe:GetName()
	return self.name
end

Recipe.GetProduct = Recipe.GetName
Recipe.__tostring = Recipe.GetName

function Recipe:GetCondition()
	recipe_check(self)
	return self.condition
end

function Recipe:GetPriority()
	recipe_check(self)
	return self.priority
end

function Recipe:GetTime()
	recipe_check(self)
	return self.brewing_time
end
Recipe.GetBrewingTime = Recipe.GetTime

function Recipe:__call(ings, kettle, dude)
	if self.condition(ings, kettle, dude) then
		self:Say("PASSED")
		return self.name
	elseif self:Debug() then
		self:Say("FAILED")
	end
end


--[[
-- Receives a list of recipes as a table (the indexes don't need to be
-- numerical).
--]]
RecipeBook = Class(Debuggable, function(self, recipes)
	Debuggable._ctor(self, "Recipebook")
	self:SetConfigurationKey("BREWING_RECIPEBOOK")

	myassert( 2, Pred.IsTable(recipes) and not Pred.IsObject(recipes), "Table expected as 'recipes' parameter." )
	
	-- Slightly more robust error checking.
	if self:Debug() then
		local offender, offender_key = Lambda.Find( Lambda.Not( IsRecipe ), pairs(recipes) )
		if offender then
			return error(2, ("Table of recipes expected as 'recipes' parameter. Got %s on key %s."):format(tostring(offender), tostring(offender_key)))
		end
	end

	self.recipes = Lambda.CompactlyMap(Lambda.Identity, pairs(recipes))
	table.sort(self.recipes, function(a, b) return a.priority > b.priority end)
end)

Pred.IsBrewingRecipeBook = Pred.IsInstanceOf(RecipeBook)
local IsRecipeBook = Pred.IsBrewingRecipeBook

local function recipebook_check(self)
	if not IsRecipeBook(self) then
		return error( "RecipeBook object expected as 'self' parameter.", 3 )
	end
end

function RecipeBook:Recipes()
	recipebook_check(self)
	return table.ivalues(self.recipes)
end

function RecipeBook:__call(ings, kettle, dude)
	local candidates = Lambda.Fold(
		function(R, total)
			local head = total and total[1]

			if head and R.priority < head.priority then
				return total
			end

			if not R(ings, kettle, dude) then
				return total
			end

			if not total or R.priority > head.priority then
				return {R}
			else
				table.insert(total, R)
				return total
			end
		end,
		ipairs(self.recipes)
	)

	if candidates and #candidates > 0 then
		local choice = candidates[math.random(#candidates)]
		self:DebugSay("Found ", #candidates, " highest priority candidates, chose \"", choice, "\"")
		return choice
	elseif self:Debug() then
		self:Say("No candidates found.")
	end
end
