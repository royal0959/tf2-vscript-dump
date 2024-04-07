local SNIPER_CLASSNAME = "tf_weapon_sniperrifle"
local TFCond_Slowed = 0

function HideLaser()
{
	if (!laser.IsValid())
		return

	EntFireByHandle(laser, "Stop", "", -1, null, null)
	laser.SetAbsOrigin(pointer.GetOrigin())
}

function ShowLaser(owner)
{
	traceTable <- {
		start = owner.EyePosition(),
		end = owner.EyePosition() + (owner.EyeAngles().Forward() * 32768.0)
		ignore = owner
	}

	local traceSucces = TraceLineEx(traceTable)


	if (!traceSucces)
		return

	if (!traceTable.hit)
		return

	local hitPos = traceTable.pos

	laser.SetAbsOrigin(owner.EyePosition())
	pointer.SetAbsOrigin(hitPos)

	// laser.Start()
	EntFireByHandle(laser, "Start", "", -1, null, null)
}

function CheckAiming()
{
	local owner = self.GetOwner()
	if (owner)
	{
		if (owner.InCond(TFCond_Slowed))
			ShowLaser(owner)
		else
			HideLaser()

	}
	return -1
}

function OnGameEvent_mvm_reset_stats(params)
{
	printl("cleaning up leftover lasers")

	local entity = null
	while (entity = Entities.FindByName(entity, "le_laser"))
	{
		printl(entity)
		// NetProps.SetPropString(entity, "m_iClassname", "info_particle_system")
		// EntFireByHandle(entity, "Stop", "", -1, null, null)
		// entity.SetAbsOrigin(Vector(0, -100000, 0))
		// entity.Kill()
		local pointer = entity.GetScriptScope().Pointer

		printl(pointer)
		if (pointer && pointer.IsValid())
		{
			entity.SetAbsOrigin(pointer.GetOrigin())
			EntFireByHandle(entity, "Stop", "", -1, null, null)

			// pointer.Kill()
		}

		// entity.Kill()
		EntFireByHandle(entity, "Kill", "", 1, null, null)
	}

	entity = null
	while (entity = Entities.FindByName(entity, "le_laser_pointer"))
	{
		printl(entity)
		NetProps.SetPropString(entity, "m_iClassname", "info_particle_system")
		entity.SetAbsOrigin(Vector(0, -100000, 0))
		// entity.Kill()
		EntFireByHandle(entity, "Kill", "", 1, null, null)
	}

	// entity = null
	// while (entity = Entities.FindByName(entity, "le_laser_color"))
	// {
	// 	printl(entity)
	// 	NetProps.SetPropString(entity, "m_iClassname", "info_particle_system")
	// 	entity.Kill()
	// }
}

function OnGameEvent_player_spawn(params)
{
	local player = GetPlayerFromUserID(params.userid);
	if (!player)
		return;
	
	for (local i = 0; i < 8; i++)
	{
		local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
		if (weapon == null || weapon.IsMeleeWeapon())
			continue;

		if (weapon.GetClassname() != SNIPER_CLASSNAME)
			continue
			
		local laser = SpawnEntityFromTable("info_particle_system", {
			// name = format("le_laser_%s", params.userid.tostring())
			targetname = "le_laser"
			effect_name = "laser_sight_beam"
			start_active = 1
			flag_as_weather = 0
		})

		local pointer = SpawnEntityFromTable("info_particle_system", {
			targetname = "le_laser_pointer"
		})
		local color = SpawnEntityFromTable("info_particle_system", {
			targetname = "le_laser_color"
		})

		laser.ValidateScriptScope()
		laser.GetScriptScope().Pointer <- pointer

		color.SetAbsOrigin(Vector(255, 0, 0))

		NetProps.SetPropEntityArray(laser, "m_hControlPointEnts", pointer, 0)
		NetProps.SetPropEntityArray(laser, "m_hControlPointEnts", color, 1)

		laser.SetOwner(player)
		pointer.SetOwner(player)
		color.SetOwner(player)

		NetProps.SetPropString(laser, "m_iClassname", "env_sprite")
		NetProps.SetPropString(pointer, "m_iClassname", "env_sprite")
		
		// laser.m_iClassname = "env_sprite"
		// pointer.m_iClassname = "env_sprite"


		weapon.ValidateScriptScope()

		local scriptScope = weapon.GetScriptScope()

		scriptScope.TFCond_Slowed <- TFCond_Slowed

		scriptScope.laser <- laser
		scriptScope.pointer <- pointer
		scriptScope.color <- color

		scriptScope.CheckAiming <- CheckAiming
		scriptScope.ShowLaser <- ShowLaser
		scriptScope.HideLaser <- HideLaser

		AddThinkToEnt(weapon, "CheckAiming")
	}
}

__CollectGameEventCallbacks(this);