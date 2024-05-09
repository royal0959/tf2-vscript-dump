local damageNumberHolder = SpawnEntityFromTable("obj_sentrygun", {
	teamnum = 3
})

damageNumberHolder.ValidateScriptScope()
damageNumberHolder.GetScriptScope().FullHealth <-  function() {
	EntFireByHandle(damageNumberHolder, "SetHealth", "100000000", 0, null, null)
}
damageNumberHolder.GetScriptScope().PutAway <- function () {
	damageNumberHolder.SetAbsOrigin(Vector(0, -100000, 0))
}

damageNumberHolder.GetScriptScope().FullHealth()
damageNumberHolder.GetScriptScope().PutAway()
damageNumberHolder.DisableDraw()
damageNumberHolder.AddEFlags(Constants.FEntityEFlags.EFL_NO_THINK_FUNCTION)
damageNumberHolder.SetSolid(Constants.ESolidType.SOLID_NONE)

::DamageableProjectileShield <- {
	DAMAGE_MULT = 0.02 // remember that shield takes full rampup damage regardless of distance
	MIN_DAMAGE_METER = 25 // damage cannot bring shield below this threshold. put at 0 to disable this grace period

	// MEDIGUN_CLASSNAME = "tf_weapon_medigun"
	PROJECTILE_SHIELD_CLASSNAME = "entity_medigun_shield"

	loadedProjectileShields = {}

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

	// PlayerSpawn = function(player) {
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
		// NetProps.SetPropFloat(player, "m_Shared.m_flRageMeter", 100)
	// }

	OnScriptHook_OnTakeDamage = function(params) {
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

		// if (fullDamage > params.max_damage)
		// 	fullDamage = params.max_damage

		if (fullDamage > 10000000)
			fullDamage = 10000000

		if (fullDamage <= 0)
			return

		rageMeter = rageMeter - (fullDamage * DAMAGE_MULT)
		if (rageMeter < MIN_DAMAGE_METER)
			rageMeter = MIN_DAMAGE_METER

		if (params.attacker) {
			damageNumberHolder.SetAbsOrigin(entity.GetOrigin() + Vector(0, 0, 15))
			damageNumberHolder.SetTeam(owner.GetTeam())

			damageNumberHolder.TakeDamage(fullDamage, params.damage_type, params.attacker)

			EntFireByHandle(damageNumberHolder, "CallScriptFunction", "FullHealth", -1, null, null)
			EntFireByHandle(damageNumberHolder, "CallScriptFunction", "PutAway", 0.015, null, null)
		}

		// make shield flicker
		NetProps.SetPropFloat(owner, "m_Shared.m_flRageMeter", rageMeter)
		// EntFireByHandle(entity, "Color", "150 0 100", -1, null, null)
		EntFireByHandle(entity, "Color", "100 100 100", -1, null, null)

		entity.ValidateScriptScope()
		local entityScope =  entity.GetScriptScope()
		if (!("shieldFuncsLoaded" in entityScope))
		{
			entityScope.shieldFuncsLoaded <- true
			entityScope.timerId <- "-1"

			entityScope.RestoreColor <- function(inputTimerId) {
				local strTimerId = inputTimerId.tostring()

				if (strTimerId != timerId)
					return

				EntFireByHandle(entity, "Color", "255 255 255", -1, null, null)
			}
		}

		local id = Time()
		local strId = id.tostring()
		entityScope.timerId = strId
		// EntFireByHandle(entity, "Color", "255 255 255", 0.5, null, null)
		// EntFireByHandle(entity, "CallScriptFunction", "RestoreColor", 0.3, null, null)

		local restoreColorFuncStr = format("RestoreColor(%s)", strId)
		EntFireByHandle(entity, "RunScriptCode", restoreColorFuncStr, 0.1, null, null)
	}

	Cleanup = function() {
		delete::DamageableProjectileShield
	}

	OnGameEvent_recalculate_holidays = function(_) {
		if (GetRoundState() != 3) return
		Cleanup()
	}

	OnGameEvent_mvm_wave_complete = function(_) {
		Cleanup()
	}

	// OnGameEvent_player_spawn = function(params) {
	// 	local player = GetPlayerFromUserID(params.userid);
	// 	if (!player)
	// 		return;

	// 	PlayerSpawn(player)
	// }
}

DamageableProjectileShield.damageNumberHolder <- damageNumberHolder

// for (local i = 1, player; i <= MaxClients(); i++)
// 	if (player = PlayerInstanceFromIndex(i), player)
// 		DamageableProjectileShield.PlayerSpawn(player)

__CollectGameEventCallbacks(DamageableProjectileShield)