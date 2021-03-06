BindGlobal()

local assets =
{
	Asset("ANIM", "anim/void_placeholder.zip"),
}

local function fn(Sim)
	local inst = CreateEntity()
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("marble")
	inst.AnimState:SetBuild("void_placeholder")
	inst.AnimState:PlayAnimation("anim")

	inst:AddComponent("stackable")
	inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

	inst:AddComponent("inspectable")

	inst:AddComponent("inventoryitem")

	inst:AddTag("coral")

	inst:AddComponent("tradable")

	return inst
end

return Prefab ("common/inventory/cloud_coral_fragment", fn, assets) 
