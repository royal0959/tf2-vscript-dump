::DamageableProjectileShield <- {
	DAMAGE_MULT = 0.02 // remember that shield takes full rampup damage regardless of distance
	MIN_DAMAGE_METER = 25 // damage cannot bring shield below this threshold. put at 0 to disable this grace period

	// MEDIGUN_CLASSNAME = "tf_weapon_medigun"
	PROJECTILE_SHIELD_CLASSNAME = "entity_medigun_shield"

	// CheckRageUse = function()
	// {
	// 	local owner = self.GetOwner()
	// 	if (!owner)
	// 		return -1

	// 	// local rageMeter = NetProps.GetPropFloat(owner, "m_Shared.m_flRageMeter")
	// 	local rageDraining = NetProps.GetPropBool(owner, "m_Shared.m_bRageDraining")

	// 	// printl(rageDraining)

	// 	if (rageDraining != 0)
	// 		return -1

	// 	if (!current_shield)
	// 	{
	// 		for (local entity; entity = Entities.FindByClassname(entity, PROJECTILE_SHIELD_CLASSNAME);)
	// 		{
	// 			if (entity.GetOwner() != owner)
	// 				continue

	// 			current_shield = entity
	// 			break
	// 		}
	// 	}

	// 	if (!current_shield)
	// 		return -1

	// 	printl(current_shield)

	// 	return -1
	// }

	PlayerSpawn = function(player)
	{
		// for (local i = 0; i < 8; i++)
		// {
		// 	local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
		// 	if (weapon == null || weapon.IsMeleeWeapon())
		// 		continue;

		// 	if (weapon.GetClassname() != MEDIGUN_CLASSNAME)
		// 		continue
				
		// 	weapon.ValidateScriptScope();

		// 	local scriptScope = weapon.GetScriptScope()
		// 	scriptScope.current_shield <- false

		// 	scriptScope.CheckRageUse <- CheckRageUse

		// 	AddThinkToEnt(weapon, "CheckRageUse")
		// }

		// PLACEHOLDER
		NetProps.SetPropFloat(player, "m_Shared.m_flRageMeter", 100)
	}

	OnScriptHook_OnTakeDamage = function(params)
	{
		local entity = params.const_entity
		if (entity.IsPlayer())
			return
		
		if (entity.GetClassname() != PROJECTILE_SHIELD_CLASSNAME)
			return

		local owner = entity.GetOwner()
		if (!owner)
			return

		local rageMeter = NetProps.GetPropFloat(owner, "m_Shared.m_flRageMeter")

		if (rageMeter <= MIN_DAMAGE_METER)
			return

		local fullDamage = params.damage + params.damage_bonus

		if (fullDamage > params.max_damage)
			fullDamage = params.max_damage

		if (fullDamage <= 0)
			return

		rageMeter = rageMeter - (fullDamage * DAMAGE_MULT)
		if (rageMeter < MIN_DAMAGE_METER)
			rageMeter = MIN_DAMAGE_METER

		NetProps.SetPropFloat(owner, "m_Shared.m_flRageMeter", rageMeter)
		EntFireByHandle(entity, "Color", "175 0 100", -1, null, null)
		EntFireByHandle(entity, "Color", "255 255 255", 0.5, null, null)
	}

	Cleanup = function()
	{
		delete ::DamageableProjectileShield
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

for (local i = 1, player; i <= MaxClients(); i++)
	if (player = PlayerInstanceFromIndex(i), player)
		DamageableProjectileShield.PlayerSpawn(player)
	
__CollectGameEventCallbacks(DamageableProjectileShield)