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

	FindRocket = function(owner) {
		local entity = null
		for (local entity; entity = Entities.FindByClassnameWithin(entity, "tf_projectile_*", owner.GetOrigin(), 100);) {
			if (entity.GetOwner() != owner) {
				continue
			}

			return entity
		}

		return null
	}

	DetonateRocket = function () {
		local owner = self.GetOwner()

		NetProps.SetPropBool(StickyMaker, "m_bCrits", NetProps.GetPropBool(self, "m_bCritical"))

		StickyMaker.SetAbsOrigin(self.GetOrigin())
		StickyMaker.SetTeam(owner.GetTeam())
		StickyMaker.SetOwner(owner)

		StickyMaker.ValidateScriptScope()
		StickyMaker.GetScriptScope().rocket <- self
		StickyMaker.GetScriptScope().SetProjectileOwnerAndDetonate <- function () {
			for (local entity; entity = Entities.FindByClassnameWithin(entity, "tf_projectile_pipe", self.GetOrigin(), 10);) {
				if (entity.GetOwner() != null) {
					continue
				}

				entity.ValidateScriptScope()
				entity.GetScriptScope().isPenetrateMimicRocket <- true
				entity.GetScriptScope().originalRocket <- rocket
				entity.GetScriptScope().penetrationCount <- (rocket.GetScriptScope().penetrationCount - 1)

				// NetProps.SetPropString(entity, "m_iClassname", rocket.GetClassname())
				NetProps.SetPropEntity(entity, "m_hLauncher", NetProps.GetPropEntity(rocket, "m_hLauncher"))

				entity.SetOwner(owner)
				break
			}

			EntFireByHandle(self, "DetonateStickies", null, -1, null, null)
		}

		EntFireByHandle(StickyMaker, "FireOnce", null, -1, null, null)
		EntFireByHandle(StickyMaker, "CallScriptFunction", "SetProjectileOwnerAndDetonate", 0.1, null, null)
	}

	RocketThink = function() {
		local MASK_SOLID_BRUSHONLY = 16395

		local origin = self.GetOrigin()

		traceTableWorldSpawn <- {
			start = lastRocketOrigin,
			end = origin + (self.GetForwardVector() * 200)
			mask = MASK_SOLID_BRUSHONLY
			ignore = self.GetOwner()
		}

		TraceLineEx(traceTableWorldSpawn)

		if (traceTableWorldSpawn.hit && traceTableWorldSpawn.enthit)
		{
			// local className = traceTableWorldSpawn.enthit.GetClassname()

			// printl(traceTableWorldSpawn.enthit.GetClassname())

			// if (className == "worldspawn" || className == "func_brush")
			// {
			self.SetSolid(Constants.ESolidType.SOLID_BBOX)
			NetProps.SetPropString(self, "m_iszScriptThinkFunction", "")
			return -1
			// }
		}


		traceTable <- {
			start = lastRocketOrigin,
			end = origin
			ignore = self.GetOwner()
		}

		TraceLineEx(traceTable)

		lastRocketOrigin = origin

		if (!traceTable.hit)
			return -1

		if (!traceTable.enthit)
			return -1

		if (collidedTargets.find(traceTable.enthit) != null)
			return -1

		collidedTargets.append(traceTable.enthit)
		penetrationCount++

		DetonateRocket()

		return -1
	}

	ApplyPenetrationToRocket = function(owner, rocket) {
		rocket.SetSolid(Constants.ESolidType.SOLID_NONE)

		rocket.ValidateScriptScope()
		local rocketScope = rocket.GetScriptScope()
		rocketScope.lastRocketOrigin <- rocket.GetOrigin()

		rocketScope.collidedTargets <- []
		rocketScope.penetrationCount <- 0
		rocketScope.StickyMaker <- StickyMaker
		rocketScope.DetonateRocket <- DetonateRocket
		rocketScope.RocketThink <- RocketThink

		rocketScope.ApplyThink <- function () {
			AddThinkToEnt(rocket, "RocketThink")
		}

		EntFireByHandle(rocket, "CallScriptFunction", "ApplyThink", 0.015, null, null)
		// AddThinkToEnt(rocket, "RocketThink")
	}

	OnShot = function(owner) {
		local rocket = FindRocket(owner)

		if (!rocket) {
			return
		}

		ApplyPenetrationToRocket(owner, rocket)
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

		local inflictorStr
		if (params.inflictor)
			inflictorStr = params.inflictor.tostring()
		else
			inflictorStr = "null"

		local weaponStr
		if (params.weapon)
			weaponStr = params.weapon.tostring()
		else
			weaponStr = "null"

		local attackerStr
		if (params.attacker)
			attackerStr = params.attacker.tostring()
		else
			attackerStr = "null"

		printl(format("Inflictor: %s; Weapon: %s; Attacker: %s", inflictorStr, weaponStr, params.attacker.tostring()))

		inflictor.ValidateScriptScope()
		local inflictorScope = inflictor.GetScriptScope()

		if (!("isPenetrateMimicRocket" in inflictorScope))
			return

		params.inflictor = inflictorScope.originalRocket // set default kill icon to launcher's killicon
		params.player_penetration_count = inflictorScope.penetrationCount // change killicon to penetrate after rocket has penetrated at least 1 enemy
	}

	PlayerSpawn = function(player) {
		for (local i = 0; i < 8; i++) {
			local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
			if (weapon == null || weapon.IsMeleeWeapon())
				continue;

			if (ROCKET_LAUNCHER_CLASSNAMES.find(weapon.GetClassname()) == null)
				continue

			weapon.ValidateScriptScope();
			local weaponScriptScope = weapon.GetScriptScope()
			weaponScriptScope.last_fire_time <- 0.0

			weaponScriptScope.CheckWeaponFire <- CheckWeaponFire
			weaponScriptScope.FindRocket <- FindRocket
			weaponScriptScope.ApplyPenetrationToRocket <- ApplyPenetrationToRocket
			weaponScriptScope.StickyMaker <- StickyMaker
			weaponScriptScope.OnShot <- OnShot

			weaponScriptScope.DetonateRocket <- DetonateRocket
			weaponScriptScope.RocketThink <- RocketThink

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