local HEAL_METAL_CONSUMPTION_RATIO = 4 // consume X metals for each health point healed
local HEAL_AMOUNT_MAX = 60

::RescueRangerHealOnHit  <- {
	FindBolt = function(owner) {
		for (local entity; entity = Entities.FindByClassnameWithin(entity, "tf_projectile_arrow", owner.GetOrigin(), 100);) {
			if (entity.GetOwner() != owner) {
				continue
			}

			entity.ValidateScriptScope()
			if ("chosenAsHealBolt" in entity.GetScriptScope()) {
				continue
			}

			entity.GetScriptScope().chosenAsHealBolt <- true
			return entity
		}

		return null
	}

	HealTarget = function (target) {
		local owner = self.GetOwner()

		local primaryWeapon

		for (local i = 0; i < 8; i++) {
			local weapon = NetProps.GetPropEntityArray(owner, "m_hMyWeapons", i)
			if (weapon == null || weapon.IsMeleeWeapon())
				continue;

			if (weapon.GetSlot() !=  0)
				continue

			primaryWeapon = weapon
		}

		local metal = NetProps.GetPropIntArray(owner, "m_iAmmo", 3)

		local healAmount = HEAL_AMOUNT_MAX

		local maxPossibleMetalConsumption = floor(HEAL_AMOUNT_MAX / HEAL_METAL_CONSUMPTION_RATIO)
		if (maxPossibleMetalConsumption > metal)
		{
			healAmount = metal * HEAL_METAL_CONSUMPTION_RATIO
		}

		local currentHealth = target.GetHealth()
		local maxHealth = target.GetMaxHealth()

		if (currentHealth + healAmount > maxHealth)
		{
			healAmount = maxHealth - currentHealth
			if (healAmount < 0)
				healAmount = 0
		}

		local metalConsumption = floor(healAmount / HEAL_METAL_CONSUMPTION_RATIO)
		metal -= metalConsumption

		if (metal < 0)
			metal = 0
		NetProps.SetPropIntArray(owner, "m_iAmmo", metal, 3)

		if (healAmount > 0)
		{
			target.TakeDamageEx(self, owner, primaryWeapon, Vector(0, 0, 0), owner.GetOrigin(), -healAmount, Constants.FDmgType.DMG_BULLET)
		}

		NetProps.SetPropString(self, "m_iszScriptThinkFunction", "")
		// self.Kill()
	}

	BoltThink = function() {
		local owner = self.GetOwner()

		local MASK_PLAYERSOLID = 33636363

		local owner = self.GetOwner()

		local origin = self.GetOrigin()

		traceTable <- {
			start = lastProjectileOrigin,
			end = origin + (self.GetForwardVector() * 1000)
			ignore = owner
			mask = MASK_PLAYERSOLID
		}

		TraceLineEx(traceTable)

		lastProjectileOrigin = origin

		if (!traceTable.hit)
			return -1

		if (!traceTable.enthit)
			return -1

		if (!traceTable.enthit.IsPlayer())
			return -1

		if (traceTable.enthit.GetTeam() != owner.GetTeam())
			return -1

		HealTarget(traceTable.enthit)

		// for (local player; player = Entities.FindByClassnameWithin(player, "player", self.GetOrigin(), 100);) {
		// 	if (player == owner)
		// 		continue

		// 	if (player.GetTeam() != owner.GetTeam())
		// 		continue

		// 	HealTarget(player)
		// 	break
		// }

		return -1
	}

	ApplyBoltHealOnHit = function(owner, bolt) {
		bolt.ValidateScriptScope()
		local boltScope = bolt.GetScriptScope()
		boltScope.isHealPlayerBolt <- true
		boltScope.lastProjectileOrigin <- bolt.GetOrigin()

		boltScope.HealTarget <- HealTarget
		boltScope.BoltThink <- BoltThink

		boltScope.ApplyThink <- function () {
			AddThinkToEnt(bolt, "BoltThink")
		}

		EntFireByHandle(bolt, "CallScriptFunction", "ApplyThink", 0.015, null, null)
	}

	OnShot = function(owner) {
		local bolt = FindBolt(owner)

		if (!bolt) {
			return
		}

		ApplyBoltHealOnHit(owner, bolt)
	}

	CheckWeaponFire = function() {
		local fire_time = NetProps.GetPropFloat(self, "m_flLastFireTime")
		if (fire_time > last_fire_time) {
			local owner = self.GetOwner()
			if (owner) {
				OnShot(owner)
			}

			last_fire_time = fire_time
		}
		return -1
	}

	OnScriptHook_OnTakeDamage = function(params) {
		local entity = params.const_entity
		if (!entity.IsPlayer())
			return

		local inflictor = params.inflictor

		inflictor.ValidateScriptScope()
		local inflictorScope = inflictor.GetScriptScope()

		if (!("isHealPlayerBolt" in inflictorScope))
			return

		if (params.damage > 0)
			return

		local damage = params.damage

		params.damage -= 1
		params.force_friendly_fire = true

	 	local playerManager = Entities.FindByClassname(null, "tf_player_manager")

		local healerUserid = NetProps.GetPropIntArray(playerManager, "m_iUserID", params.attacker.entindex())
		local patientUserid = NetProps.GetPropIntArray(playerManager, "m_iUserID", entity.entindex())

		SendGlobalGameEvent("player_healed",  {
			amount = -damage,
			healer = healerUserid,
			patient = patientUserid,
			priority = 1
		})
	}

	PlayerSpawn = function(player) {
		for (local i = 0; i < 8; i++) {
			local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
			if (weapon == null || weapon.IsMeleeWeapon())
				continue

			if (weapon.GetClassname() != "tf_weapon_shotgun_building_rescue")
				continue

			weapon.ValidateScriptScope();
			local weaponScriptScope = weapon.GetScriptScope()
			weaponScriptScope.last_fire_time <- 0.0

			weaponScriptScope.CheckWeaponFire <- CheckWeaponFire
			weaponScriptScope.FindBolt <- FindBolt
			weaponScriptScope.ApplyBoltHealOnHit <- ApplyBoltHealOnHit
			weaponScriptScope.OnShot <- OnShot

			weaponScriptScope.HealTarget <- HealTarget
			weaponScriptScope.BoltThink <- BoltThink

			AddThinkToEnt(weapon, "CheckWeaponFire")
		}
	}

	Cleanup = function() {
		delete::RescueRangerHealOnHit
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
		RescueRangerHealOnHit.PlayerSpawn(player)

__CollectGameEventCallbacks(RescueRangerHealOnHit)