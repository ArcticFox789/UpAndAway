BindGlobal()

local assets =
{
	Asset("ANIM", "anim/cloudbush.zip"),
}

local prefabs = 
{
    "cloud_cotton",
}

local function GetStatus(inst)
	if inst.components.pickable and inst.components.pickable:CanBePicked() then
		return cloud_bush
	else 
		return picked
	end
end

local function ontransplantfn(inst)
	inst.components.pickable:MakeEmpty()
end

local function dig_up(inst, chopper)
	if inst.components.pickable and inst.components.pickable:CanBePicked() then
		inst.components.lootdropper:SpawnLootPrefab("cloud_cotton")
	end
	--local bush = inst.components.lootdropper:SpawnLootPrefab("dug_marsh_bush")
	inst:Remove()
end

local function onpickedfn(inst, picker)
	--inst.AnimState:PlayAnimation("picking") 
	print("onpickedfn")
	inst.AnimState:PlayAnimation("berries_picked")
	
	if picker.components.combat then
        picker.components.combat:GetAttacked(nil, 2)
	end

	if inst.components.pickable:IsBarren() then
		inst.AnimState:PushAnimation("berries_picked")
		print("IsBarren")
	end	
end

local function makeemptyfn(inst)
	--inst.AnimState:PlayAnimation("empty", true) 
end

local function makebarrenfn(inst)
	--inst.AnimState:PlayAnimation("berries")
end

local function onunchargedfn(inst)
	inst:RemoveComponent("pickable")

	local anim = inst.AnimState
	anim:PlayAnimation("berriesmore", true)
	anim:PushAnimation("berries", true)
	anim:PushAnimation("idle", true)
	anim:PlayAnimation("idle_dead", true)
end

local function onchargedfn(inst)
	inst.AnimState:PlayAnimation("berriesmost", true) 

    inst:AddComponent("pickable")
    inst.components.pickable.picksound = "dontstarve/wilson/harvest_sticks"
    inst.components.pickable:SetUp("candy_fruit", TUNING.MARSHBUSH_REGROW_TIME, 2)
	inst.components.pickable.onregenfn = onchargedfn
	inst.components.pickable.onpickedfn = onpickedfn
	inst.components.pickable.makebarrenfn = makebarrenfn
    inst.components.pickable.makeemptyfn = makeemptyfn
end

local function fn(Sim)
	local inst = CreateEntity()
	local trans = inst.entity:AddTransform()
	local anim = inst.entity:AddAnimState()

    anim:SetBank("berrybush")
    anim:SetBuild("cloudbush")	
    anim:SetTime(math.random()*2)

    local color = 0.5 + math.random() * 0.5
    anim:SetMultColour(color, color, color, 1)
	
	--inst.components.pickable.ontransplantfn = ontransplantfn

	inst:AddComponent("lootdropper")
	
	inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.DIG)
    inst.components.workable:SetOnFinishCallback(dig_up)
    inst.components.workable:SetWorkLeft(1)
    
    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

	inst:AddComponent("staticchargeable")
	inst.components.staticchargeable:SetChargedFn(onchargedfn)
	inst.components.staticchargeable:SetUnchargedFn(onunchargedfn)

    inst.entity:AddMiniMapEntity()
    inst.MiniMapEntity:SetIcon("cloud_bush.tex")

    MakeLargeBurnable(inst)
    MakeLargePropagator(inst)

	onunchargedfn(inst)

    return inst
end

return Prefab( "cloudrealm/objects/cloud_bush", fn, assets, prefabs) 
