BindGlobal()


-- An array of functions.
--
-- It is a table, so you add/remove functions like you would to a (array-like)
-- table (e.g., table.insert, table.remove).
--
-- It can be called like a function (which results in it calling every
-- function in it passing the arguments given to it).
local FunctionQueue = wickerrequire 'gadgets.functionqueue'


local CFG = TheMod:GetConfig()

local assets=
{
	Asset("ANIM", "anim/sheep_baby_build.zip"),
	Asset("ANIM", "anim/sheep_electric.zip"),	

	Asset("ANIM", "anim/beefalo_basic.zip"),
	Asset("ANIM", "anim/beefalo_actions.zip"),
	Asset("SOUND", "sound/beefalo.fsb"),
	Asset("SOUND", "sound/project_bank00.fsb"),
	Asset("SOUND", "sound/sheep_bank01.fsb"),		
}

local prefabs =
{
	"meat",
	"skyflower",
	"cloud_cotton",
}

local loot = {"meat","meat","cloud_cotton","cloud_cotton"}

local sounds = 
{
	walk = "dontstarve/beefalo/walk",
	grunt = "dontstarve/beefalo/curious",
	yell = "dontstarve/beefalo/yell",
	swish = "dontstarve/beefalo/tail_swish",
	curious = "dontstarve/beefalo/curious",
	angry = "dontstarve/beefalo/angry",
}

local function GetStatus(inst)
	return inst.components.staticchargeable:IsCharged() and "RAM" or "SHEEP"
end


local retarget_fns = {}

function retarget_fns.RAM(inst)
	local newtarget = FindEntity(inst, CFG.RAM.TARGET_DIST, function(guy)
		return (guy:HasTag("character") or guy:HasTag("monster"))
			and not (inst.components.follower and inst.components.follower.leader == guy)
			and not guy:HasTag("sheep")
			and inst.components.combat:CanTarget(guy)
	end)
	return newtarget
end

local function Retarget(inst)
	local fn = retarget_fns[GetStatus(inst)]
	return fn and fn(inst)
end


local function KeepTarget(inst, target)
	local maxdist = assert( CFG[GetStatus(inst)].CHASE_DIST )

	if inst.components.herdmember then
		local herd = inst.components.herdmember:GetHerd()
		if herd then
			return distsq( Point( herd.Transform:GetWorldPosition() ), inst:GetPosition() ) < maxdist*maxdist
		end
	end

	return true
end

local function OnNewTarget(inst, data)
	if inst.components.follower and data and data.target and data.target == inst.components.follower.leader then
		inst.components.follower:SetLeader(nil)
	end
end

local function OnAttacked(inst, data)
	inst.components.combat:SetTarget(data.attacker)
	inst.components.combat:ShareTarget(data.attacker, 30, function(dude)
		return dude:HasTag("sheep") and not dude:HasTag("player") and not dude.components.health:IsDead()
	end, 5)
end


local function dostaticsparks_at(pt)
	local spark = SpawnPrefab("sparks_fx")
	spark.Transform:SetPosition(pt:Get())
	spark.Transform:SetScale(0.9, 0.5, 0.5)
	return spark
end

local function dostaticsparks(inst)
	local radius = 2*(inst.Physics and inst.Physics:GetRadius() or 1)

	local theta = 2*math.pi*math.random()
	local phi = math.pi*math.random()

	local cosphi, sinphi = math.cos(phi), math.sin(phi)

	return dostaticsparks_at( inst:GetPosition() + Vector3( radius*math.cos(theta)*sinphi, 1 + radius*cosphi, radius*math.sin(theta)*sinphi ) )
end


local function set_electricsheep(inst)
	if inst.undolist then
		inst:undolist()
	end
	inst.undolist = FunctionQueue()

	inst:AddTag("electric_sheep")	
	table.insert(inst.undolist, function(inst)
		inst:RemoveTag("electric_sheep")
	end)

	inst.DynamicShadow:SetSize(3, 2)
	
	inst.Transform:SetScale(0.65, 0.75, 0.65)
	
	inst.AnimState:SetBuild("sheep_baby_build")
	inst.AnimState:PlayAnimation("idle_loop", true)

	
	--inst.components.beard.bits = 3
	--inst.components.beard.daysgrowth = hair_growth_days + 1 
	--inst.components.beard.onreset = function() inst.sg:GoToState("shaved") end
	
	inst.components.combat:SetDefaultDamage(CFG.SHEEP.DAMAGE)
	 
	inst.components.health:SetMaxHealth(CFG.SHEEP.HEALTH)

	inst.components.lootdropper:SetLoot(loot)
	--inst.components.lootdropper:AddChanceLoot("cotton", 0.70)

	inst.components.periodicspawner:Stop()
	inst.components.periodicspawner:SetRandomTimes(20, 100)
	inst.components.periodicspawner:SetDensityInRange(10, 1)
	inst.components.periodicspawner:SetMinimumSpacing(10)
	inst.components.periodicspawner:Start()
	
	inst.components.sleeper:SetResistance(2)
	
	local brain = require "brains/sheepbrain"
	inst:SetBrain(brain)   
end

local function set_stormram(inst)
	if inst.undolist then
		inst:undolist()
	end
	inst.undolist = FunctionQueue()

	inst:AddTag("storm_ram")
	inst:AddTag("largecreature")
	inst:AddTag("hostile")
	table.insert(inst.undolist, function(inst)
		inst:RemoveTag("storm_ram")
		inst:RemoveTag("largecreature")
		inst:RemoveTag("hostile")
	end)
	
	--[[
	inst.Light:Enable(true)
	table.insert(inst.undolist, function(inst)
		inst.Light:Enable(false)
	end)
	]]--
		
	inst.DynamicShadow:SetSize(6, 2)
	
	inst.Transform:SetScale(1, 1, 1)	

	inst.AnimState:SetBuild("sheep_electric")
	inst.AnimState:PlayAnimation("idle_loop", true)
	

	inst.components.combat:SetDefaultDamage(CFG.RAM.DAMAGE)
	
	inst.components.health:SetMaxHealth(CFG.RAM.HEALTH)

	inst.components.lootdropper:SetLoot(loot)
	--inst.components.lootdropper:AddChanceLoot("cotton", 0.33)
	
	inst.components.follower.maxfollowtime = TUNING.BEEFALO_FOLLOW_TIME
	inst.components.follower.canaccepttarget = false

	inst.components.periodicspawner:Stop()
	inst.components.periodicspawner:SetRandomTimes(40, 60)
	inst.components.periodicspawner:SetDensityInRange(20, 2)
	inst.components.periodicspawner:SetMinimumSpacing(8)
	inst.components.periodicspawner:Start()
	
	inst.components.sleeper:SetResistance(4)
	
	local brain = require "brains/rambrain"
	inst:SetBrain(brain)


	;(function(delay)
		local task_creator
		local task

		local function fx_chain(inst)
			if not inst:IsAsleep() then
				dostaticsparks(inst)
				task = inst:DoTaskInTime(delay, fx_chain)
			else
				task = inst:DoTaskInTime(5, fx_chain)
			end
		end

		task_creator = inst:DoTaskInTime(4*delay*math.random(), function(inst)
			task = inst:DoTaskInTime(0, fx_chain)
			task_creator = nil
		end)
		table.insert(inst.undolist, function()
			if task_creator then
				task_creator:Cancel()
			end
			if task then
				task:Cancel()
			end
		end)
	end)(1/2)
end


local function fn()
	local inst = CreateEntity()
	inst:AddTag("sheep")

	local trans = inst.entity:AddTransform()
	trans:SetFourFaced()

	local sound = inst.entity:AddSoundEmitter()
	inst.sounds = sounds

	local shadow = inst.entity:AddDynamicShadow()

	local anim = inst.entity:AddAnimState()
	anim:SetBank("beefalo")
	--;(function(color) anim:SetMultColour(color, color, color, 1) end)(0.3 + 0.3*math.random())
	
	--[[
	local light = inst.entity:AddLight()
	light:SetRadius(2)
	light:SetFalloff(1)
	light:SetIntensity(.9)
	light:SetColour(235/255,121/255,12/255)	
	light:Enable(false)
	]]--

	MakeCharacterPhysics(inst, 100, .5)
	

	inst:AddTag("animal")
	inst:AddTag("beefalo")
	
	inst:AddComponent("eater")	
	inst.components.eater:SetVegetarian()	

	--inst:AddComponent("beard")
	--local hair_growth_days = 3	
	
	inst:AddComponent("combat")	
	inst.components.combat.hiteffectsymbol = "beefalo_body"
	inst.components.combat:SetRetargetFunction(1, Retarget)
	inst.components.combat:SetKeepTargetFunction(KeepTarget)

	
	inst:AddComponent("health")	
	
	inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus

	inst:AddComponent("knownlocations")
	inst:AddComponent("herdmember")
	
	inst:AddComponent("leader")

	inst:AddComponent("follower")

	inst:AddComponent("periodicspawner")
	inst.components.periodicspawner:SetPrefab("skyflower")	

	MakeLargeBurnableCharacter(inst, "beefalo_body")
	MakeLargeFreezableCharacter(inst, "beefalo_body")
	
	inst:AddComponent("locomotor")	
	inst.components.locomotor.walkspeed = 2
	inst.components.locomotor.runspeed = 7
	
	inst:AddComponent("lootdropper")
	
	inst:AddComponent("sleeper")	
	
	inst:SetStateGraph("SGSheep")
	
	inst:AddComponent("staticchargeable")
	inst.components.staticchargeable:SetOnChargeFn(set_stormram)
	inst.components.staticchargeable:SetOnUnchargeFn(set_electricsheep)
	inst.components.staticchargeable:SetOnChargeDelay(CFG.SHEEP.CHARGE_DELAY)
	inst.components.staticchargeable:SetOnUnchargeDelay(CFG.SHEEP.UNCHARGE_DELAY)


	set_electricsheep(inst)


	inst:ListenForEvent("newcombattarget", OnNewTarget)
	inst:ListenForEvent("attacked", OnAttacked)
	

	return inst	
end

return Prefab( "cloudrealm/animals/sheep", fn, assets, prefabs)
