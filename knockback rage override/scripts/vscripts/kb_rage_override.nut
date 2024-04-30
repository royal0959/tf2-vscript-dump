::KnockbackRageOverride  <- {
	OnScriptHook_OnTakeDamage = function(params) {
		local entity = params.const_entity
		if (!entity.IsPlayer())
			return

		local attacker = params.attacker

		if (!attacker.IsRageDraining())
			return

		params.early_out = true

		local rageMeter = attacker.GetRageMeter()
		NetProps.SetPropBool(attacker, "m_Shared.m_bRageDraining", false)

		params.const_entity.TakeDamageCustom(params.inflictor, params.attacker, params.weapon, params.damage_force, params.damage_position, params.damage, params.damage_type, params.damage_stats)

		NetProps.SetPropBool(attacker, "m_Shared.m_bRageDraining", true)
		attacker.SetRageMeter(rageMeter)
	}

	PlayerSpawn = function(player) {
		// for (local i = 0; i < 8; i++) {
		// 	local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
		// 	if (weapon == null || weapon.IsMeleeWeapon())
		// 		continue

		// 	if (weapon.GetClassname() != "tf_weapon_shotgun_building_rescue")
		// 		continue

		// 	weapon.ValidateScriptScope();
		// 	local weaponScriptScope = weapon.GetScriptScope()
		// 	weaponScriptScope.last_fire_time <- 0.0

		// 	weaponScriptScope.CheckWeaponFire <- CheckWeaponFire
		// 	weaponScriptScope.FindBolt <- FindBolt
		// 	weaponScriptScope.ApplyBoltHealOnHit <- ApplyBoltHealOnHit
		// 	weaponScriptScope.OnShot <- OnShot

		// 	weaponScriptScope.HealTarget <- HealTarget
		// 	weaponScriptScope.BoltThink <- BoltThink

		// 	AddThinkToEnt(weapon, "CheckWeaponFire")
		// }
	}

	Cleanup = function() {
		delete::KnockbackRageOverride
	}

	OnGameEvent_recalculate_holidays = function(_) {
		if (GetRoundState() != 3) return
		Cleanup()
	}

	OnGameEvent_mvm_wave_complete = function(_) {
		Cleanup()
	}

	OnGameEvent_player_spawn = function(params) {
		local player = GetPlayerFromUserID(params.userid);
		if (!player)
			return;

		PlayerSpawn(player)
	}
}

// spoof a player spawn when the wave initializes
for (local i = 1, player; i <= MaxClients(); i++)
	if (player = PlayerInstanceFromIndex(i), player)
		KnockbackRageOverride.PlayerSpawn(player)

__CollectGameEventCallbacks(KnockbackRageOverride)