BindGlobal()


local Lambda = wickerrequire 'paradigms.functional'

local Game = wickerrequire 'utils.game'


require "prefabutil"


local basic_assets=
{
	Asset("ANIM", "anim/cook_pot.zip"),
	Asset("ANIM", "anim/cook_pot_food.zip"),
}


local basic_prefabs = {}


local function BuildKettlePrefab()
	local Brewing = modrequire 'lib.brewing'
	local BrewingRecipeBook = modrequire 'resources.brewing_recipebook'


	local assets = basic_assets
	local prefabs = _G.JoinArrays(basic_prefabs, {"kettle_item", "wetgoop"})
	Lambda.CompactlyMapInto(Brewing.Recipe.GetProduct, prefabs, BrewingRecipeBook:Recipes())


	local slotpos = {
		Vector3(0,64+32+8+4,0), 
		Vector3(0,32+4,0),
		Vector3(0,-(32+4),0), 
		Vector3(0,-(64+32+8+4),0)
	}

	local widgetbuttoninfo = {
		text = "Brew",
		position = Vector3(0, -165, 0),
		fn = function(inst)
			inst.components.brewer:StartBrewing( GetPlayer() )	
		end,
		
		validfn = function(inst)
			return inst.components.brewer:CanBrew()
		end,
	}

	local function itemtest(inst, item, slot)
		return (item.components.edible and item.components.edible.foodtype ~= "MEAT") or item:HasTag("tea_leaf")
	end

	--anim and sound callbacks

	local function startbrewfn(inst)
		inst.AnimState:PlayAnimation("cooking_loop", true)
		--play a looping sound
		inst.SoundEmitter:KillSound("snd")
		inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot_rattle", "snd")
		inst.Light:Enable(true)
	end


	local function onopen(inst)
		inst.AnimState:PlayAnimation("cooking_pre_loop", true)
		inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot_open", "open")
		inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot", "snd")
	end

	local function onclose(inst)
		if not inst.components.brewer.cooking then
			inst.AnimState:PlayAnimation("idle_empty")
			inst.SoundEmitter:KillSound("snd")
		end
		inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot_close", "close")
	end

	local function donebrewfn(inst)
		inst.AnimState:PlayAnimation("cooking_pst")
		inst.AnimState:PushAnimation("idle_full")
		inst.AnimState:OverrideSymbol("swap_cooked", "cook_pot_food", inst.components.brewer.product)
		
		inst.SoundEmitter:KillSound("snd")
		inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot_finish", "snd")
		inst.Light:Enable(false)
		--play a one-off sound
	end

	local function continuedonefn(inst)
		inst.AnimState:PlayAnimation("idle_full")
		--inst.AnimState:OverrideSymbol("swap_cooked", "cook_pot_food", inst.components.brewer.product)
	end

	local function continuebrewfn(inst)
		inst.AnimState:PlayAnimation("cooking_loop", true)
		--play a looping sound
		inst.Light:Enable(true)

		inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot_rattle", "snd")
	end

	local function harvestfn(inst)
		inst.AnimState:PlayAnimation("idle_empty")
	end

	local function onwithdrawfn(inst)
		return SpawnPrefab("kettle_item")
	end

	local function onwithdraw_handler(inst, data)
		if inst.components.brewer and inst.components.brewer:IsBrewing() then
			Game.Move( SpawnPrefab("wetgoop"), inst:GetPosition() + Point(0, 2, 0) )
		end
	end

	local function getstatus(inst)
		if inst.components.brewer.cooking then
			return "BREWING"
		elseif inst.components.brewer.done then
			return "DONE"
		else
			return "EMPTY"
		end
	end

	local function onfar(inst)
		inst.components.container:Close()
	end

	local function onbuilt(inst)
		inst.AnimState:PlayAnimation("place")
		inst.AnimState:PushAnimation("idle_empty")
	end


	local function fn()
		local inst = CreateEntity()

		inst:AddTag("structure")


		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddSoundEmitter()
		
		inst.AnimState:SetBank("cook_pot")
		inst.AnimState:SetBuild("cook_pot")
		inst.AnimState:PlayAnimation("idle_empty")

		MakeObstaclePhysics(inst, .5)
		
		local minimap = inst.entity:AddMiniMapEntity()
		minimap:SetIcon( "cookpot.png" )
		
		local light = inst.entity:AddLight()
		light:Enable(false)
		light:SetRadius(.6)
		light:SetFalloff(1)
		light:SetIntensity(.5)
		light:SetColour(235/255,62/255,12/255)


		inst:AddComponent("brewer")
		do
			local brewer = inst.components.brewer

			brewer:SetRecipeBook(BrewingRecipeBook)
			brewer.onstartbrewing = startbrewfn
			brewer.oncontinuebrewing = continuebrewfn
			brewer.oncontinuedone = continuedonefn
			brewer.ondonebrewing = donebrewfn
			brewer.onharvest = harvestfn
		end
		
		inst:AddComponent("withdrawable")
		do
			local withdrawable = inst.components.withdrawable

			withdrawable:SetOnWithdrawFn(onwithdrawfn)

			inst:ListenForEvent("onwithdraw", onwithdraw_handler)
		end
		
		inst:AddComponent("container")
		do
			local container = inst.components.container

			container.itemtestfn = itemtest
			container:SetNumSlots(4)
			container.widgetslotpos = slotpos
			container.widgetanimbank = "ui_cookpot_1x4"
			container.widgetanimbuild = "ui_cookpot_1x4"
			container.widgetpos = Vector3(200,0,0)
			container.side_align_tip = 100
			container.widgetbuttoninfo = widgetbuttoninfo
			container.acceptsstacks = false

			container.onopenfn = onopen
			container.onclosefn = onclose
		end


		inst:AddComponent("inspectable")
		do
			inst.components.inspectable.getstatus = getstatus
		end


		inst:AddComponent("playerprox")
		do
			local playerprox = inst.components.playerprox

			playerprox:SetDist(3,5)
			playerprox:SetOnPlayerFar(onfar)
		end

   		inst.entity:AddMiniMapEntity()
    	inst.MiniMapEntity:SetIcon("kettle.tex") 

		--MakeSnowCovered(inst, .01)    
		inst:ListenForEvent("onbuilt", onbuilt)
		return inst
	end

	return Prefab( "common/kettle", fn, assets, prefabs)
end


local function BuildKettleItemPrefab()
	local assets = basic_assets
	local prefabs = _G.JoinArrays(basic_prefabs, {"kettle"})

	local function ondeploy(inst, pt, deployer)
		local kettle = SpawnPrefab("kettle")
		if kettle then
			kettle.Physics:Teleport( pt:Get() )
		end
		inst:Remove()
	end

	local function fn()
		local inst = CreateEntity()


		inst:AddTag("portable_structure")


		inst.entity:AddTransform()
		local anim = inst.entity:AddAnimState()
		MakeInventoryPhysics(inst)

		anim:SetBank("marble")
		anim:SetBuild("void_placeholder")
		anim:PlayAnimation("anim")


		inst:AddComponent("inspectable")
		
		inst:AddComponent("inventoryitem")
		do
			inst.components.inventoryitem.atlasname = "images/inventoryimages/kettle_item.xml"
		end

		inst:AddComponent("deployable")
		do
			local deployable = inst.components.deployable

			deployable.ondeploy = ondeploy
			--deployable.test = nil
			deployable.min_spacing = 2
			deployable.placer = "kettle_placer"
		end


		return inst
	end


	return Prefab( "common/kettle_item", fn, assets, prefabs)
end


return {
	BuildKettlePrefab(),
	BuildKettleItemPrefab(),
	MakePlacer( "common/kettle_placer", "cook_pot", "cook_pot", "idle_empty" ),
}
