StickyMaker <- SpawnEntityFromTable("tf_point_weapon_mimic", {
	TeamNum = 2,
	WeaponType = 3, // sticky
	Damage = 70,
	Crits = false,
	SplashRadius = 146,
	SpeedMax = 0,
	SpeedMin = 0,
})

::RocketPenetration <- {

	ROCKET_LAUNCHER_CLASSNAMES = [
		"tf_weapon_rocketlauncher",
		"tf_weapon_rocketlauncher_airstrike",
		"tf_weapon_rocketlauncher_directhit",
		"tf_weapon_particle_cannon",
	]

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
		// local newHealth = target.GetHealth() + 60

		// local maxHealth = target.GetMaxHealth()
		// if (newHealth > maxHealth)
		// 	newHealth = maxHealth

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

		local healAmount = 60

		local currentHealth = target.GetHealth()
		local maxHealth = target.GetMaxHealth()

		if (currentHealth + healAmount > maxHealth)
		{
			healAmount = maxHealth - currentHealth
			if (healAmount < 0)
				healAmount = 0
		}

		if (healAmount > 0)
		{
			target.TakeDamageEx(self, owner, primaryWeapon, Vector(0, 0, 0), owner.GetOrigin(), -healAmount, Constants.FDmgType.DMG_BULLET)
		}


		NetProps.SetPropString(self, "m_iszScriptThinkFunction", "")
		self.Kill()
	}

	BoltThink = function() {
		local owner = self.GetOwner()

		for (local player; player = Entities.FindByClassnameWithin(player, "player", self.GetOrigin(), 100);) {
			if (player == owner)
				continue

			if (player.GetTeam() != owner.GetTeam())
				continue

			HealTarget(player)
			break
		}

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

		// params.damage = -params.damage
		params.force_friendly_fire = true

	 	local playerManager = Entities.FindByClassname(null, "tf_player_manager")

		local healerUserid = NetProps.GetPropIntArray(playerManager, "m_iUserID", params.attacker.entindex())
		local patientUserid = NetProps.GetPropIntArray(playerManager, "m_iUserID", entity.entindex())

		SendGlobalGameEvent("player_healed",  {
			amount = -params.damage,
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
		delete::RocketPenetration
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

RocketPenetration.StickyMaker <- StickyMaker

// spoof a player spawn when the wave initializes
for (local i = 1, player; i <= MaxClients(); i++)
	if (player = PlayerInstanceFromIndex(i), player)
		RocketPenetration.PlayerSpawn(player)

__CollectGameEventCallbacks(RocketPenetration)