::RedSniperLaser <- 
{
	SNIPER_CLASSNAME = "tf_weapon_sniperrifle"
	RED_TEAM = 2
	TFCond_Slowed = 0

	MakeLaserEnts = function(player)
	{
		local laser = SpawnEntityFromTable("info_particle_system", {
			// name = format("le_laser_%s", params.userid.tostring())
			targetname = "le_laser"
			effect_name = "laser_sight_beam"
			start_active = 1
			flag_as_weather = 0
		})

		local pointer = SpawnEntityFromTable("info_particle_system", {
			targetname = "le_laser_pointer"
			effect_name = "laser_sight_beam"
		})
		local color = SpawnEntityFromTable("info_particle_system", {
			targetname = "le_laser_color"
			effect_name = "laser_sight_beam"
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

		local scriptScope = self.GetScriptScope()
		scriptScope.laser <- laser
		scriptScope.pointer <- pointer
		scriptScope.color <- color
	}

	HideLaser = function()
	{
		if (!laser.IsValid())
			return

		EntFireByHandle(laser, "Stop", "", -1, null, null)
		laser.SetAbsOrigin(pointer.GetOrigin())
	}

	ShowLaser = function(owner)
	{
		traceTable <- {
			start = owner.EyePosition(),
			end = owner.EyePosition() + (owner.EyeAngles().Forward() * 32768.0)
			ignore = owner
		}

		local traceSucces = TraceLineEx(traceTable)

		if (!traceTable.hit)
			return

		local hitPos = traceTable.pos

		laser.SetAbsOrigin(owner.EyePosition())
		pointer.SetAbsOrigin(hitPos)

		// laser.Start()
		EntFireByHandle(laser, "Start", "", -1, null, null)
	}

	CheckAiming = function()
	{
		local owner = self.GetOwner()

		if (!laser || !laser.IsValid())
			MakeLaserEnts(owner)

		if (owner)
		{
			if (owner.InCond(TFCond_Slowed))
				ShowLaser(owner)
			else
				HideLaser()

		}
		return -1
	}

	PlayerSpawn = function(player)
	{

		if (player.GetTeam() != RED_TEAM)
			return
		
		for (local i = 0; i < 8; i++)
		{
			local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
			if (weapon == null || weapon.IsMeleeWeapon())
				continue;

			if (weapon.GetClassname() != SNIPER_CLASSNAME)
				continue
				
			weapon.ValidateScriptScope()

			local scriptScope = weapon.GetScriptScope()

			scriptScope.TFCond_Slowed <- TFCond_Slowed

			scriptScope.laser <- false
			scriptScope.pointer <- false
			scriptScope.color <- false

			scriptScope.MakeLaserEnts <- MakeLaserEnts
			scriptScope.CheckAiming <- CheckAiming
			scriptScope.ShowLaser <- ShowLaser
			scriptScope.HideLaser <- HideLaser

			AddThinkToEnt(weapon, "CheckAiming")
		}
	}

	LaserCleanup = function()
	{
		printl("cleaning up leftover lasers")

		for (local entity; entity = Entities.FindByName(entity, "le_laser");)
		{
			local pointer = entity.GetScriptScope().Pointer

			printl(entity)
			printl(pointer)

			if (pointer && pointer.IsValid())
			{
				pointer.SetAbsOrigin(Vector(0, -100000, 0))
				entity.SetAbsOrigin(pointer.GetOrigin())

			}

			EntFireByHandle(entity, "Stop", "", -1, null, null)

			// NetProps.SetPropString(entity, "m_iClassname", "info_particle_system")
			// EntFireByHandle(entity, "Kill", "", 1, null, null)
		}

		for (local entity; entity = Entities.FindByName(entity, "le_laser_pointer");)
		{
			// NetProps.SetPropString(entity, "m_iClassname", "info_particle_system")
			// entity.SetAbsOrigin(Vector(0, -100000, 0))
			// EntFireByHandle(entity, "Kill", "", 1, null, null)
		}

		EntFire("le_laser*", "Kill", 1)


		delete ::RedSniperLaser
	}

	// OnGameEvent_mvm_reset_stats = function(_)
	// {
	// 	LaserCleanup()
	// }

	OnGameEvent_recalculate_holidays = function(_) 
	{
		if (GetRoundState() != 3) return
		LaserCleanup()
	}
	OnGameEvent_mvm_wave_complete = function(_) 
	{ 
		LaserCleanup()
	}

	function OnGameEvent_player_spawn(params)
	{
		local player = GetPlayerFromUserID(params.userid);
		if (!player)
			return;

		PlayerSpawn(player)
	}
}


// spoof a player spawn when the wave initializes
for (local i = 1, player; i <= MaxClients(); i++)
	if (player = PlayerInstanceFromIndex(i), player)
		RedSniperLaser.PlayerSpawn(player)

__CollectGameEventCallbacks(RedSniperLaser)