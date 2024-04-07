::ChargeShotOverride <- {

	COWMANGLER_CLASS_NAME = "tf_weapon_particle_cannon"

	CircuitBallMaker <- Entities.CreateByClassname("tf_weapon_mechanical_arm")
	NetProps.SetPropInt(CircuitBallMaker, "m_AttributeManager.m_Item.m_iItemDefinitionIndex", 528) // https://wiki.alliedmods.net/Team_Fortress_2_Item_Definition_Indexes
	NetProps.SetPropBool(CircuitBallMaker, "m_AttributeManager.m_Item.m_bInitialized", true)
	Entities.DispatchSpawn(CircuitBallMaker)
	CircuitBallMaker.SetClip1(-1)

	FindChargeShot = function(owner)
	{
		local entity = null
		while (entity = Entities.FindByClassnameWithin(entity, "tf_projectile_energy_ball", owner.GetOrigin(), 100))
		{
			if (entity.GetOwner() != owner)
			{
				continue
			}

			if (NetProps.GetPropInt(entity, "m_bChargedShot") == 0)
			{
				continue
			}

			return entity
		}

		return null
	}

	OverrideChargeShot = function(owner, chargeShot)
	{
		chargeShot.Kill()

		// preserve old charge meter and ammo count
		local charge = NetProps.GetPropFloat(owner, "m_Shared.m_flItemChargeMeter");
		local ammo = NetProps.GetPropIntArray(owner, "m_iAmmo", 1);
		local metal = NetProps.GetPropIntArray(owner, "m_iAmmo", 3);
		
		// set up stuff needed to ensure the weapon always fires
		NetProps.SetPropIntArray(owner, "m_iAmmo", 99, 1);
		NetProps.SetPropIntArray(owner, "m_iAmmo", 200, 3);
		NetProps.SetPropFloat(owner, "m_Shared.m_flItemChargeMeter", 100.0);
		NetProps.SetPropBool(owner, "m_bLagCompensation", false);
		NetProps.SetPropFloat(CircuitBallMaker, "m_flNextPrimaryAttack", 0);
		NetProps.SetPropEntity(CircuitBallMaker, "m_hOwner", owner);

		CircuitBallMaker.SecondaryAttack();
		
		// revert changes
		NetProps.SetPropBool(owner, "m_bLagCompensation", true);
		NetProps.SetPropIntArray(owner, "m_iAmmo", ammo, 1);
		NetProps.SetPropIntArray(owner, "m_iAmmo", metal, 3);
		NetProps.SetPropFloat(owner, "m_Shared.m_flItemChargeMeter", charge);
	}

	OnShot = function(owner)
	{
		local chargeShot = FindChargeShot(owner)

		if (!chargeShot)
		{
			return
		}

		OverrideChargeShot(owner, chargeShot)
	}

	CheckWeaponFire = function()
	{
		local fire_time = NetProps.GetPropFloat(self, "m_flLastFireTime")
		if (fire_time > last_fire_time)
		{		
			local owner = self.GetOwner()
			if (owner)
			{
				OnShot(owner)
			}
			
			last_fire_time = fire_time
		}
		return -1
	}

	PlayerSpawn = function(player)
	{
		for (local i = 0; i < 8; i++)
		{
			local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
			if (weapon == null || weapon.IsMeleeWeapon())
				continue;

			if (weapon.GetClassname() != COWMANGLER_CLASS_NAME)
				continue
				
			weapon.ValidateScriptScope();
			weapon.GetScriptScope().last_fire_time <- 0.0

			weapon.GetScriptScope().CheckWeaponFire <- CheckWeaponFire
			weapon.GetScriptScope().FindChargeShot <- FindChargeShot
			weapon.GetScriptScope().OverrideChargeShot <- OverrideChargeShot
			weapon.GetScriptScope().CircuitBallMaker <- CircuitBallMaker
			weapon.GetScriptScope().OnShot <- OnShot

			AddThinkToEnt(weapon, "CheckWeaponFire")
		}
	}

	Cleanup = function()
	{
		delete ::MyNamespace
	}
	
	OnGameEvent_recalculate_holidays = function(_)
	{
		if (GetRoundState() != 3) return
		Cleanup()
	}

	OnGameEvent_mvm_wave_complete = function(_)
	{
		Cleanup() 
	}

	OnGameEvent_player_spawn = function(params)
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
		ChargeShotOverride.PlayerSpawn(player)
	
__CollectGameEventCallbacks(ChargeShotOverride)