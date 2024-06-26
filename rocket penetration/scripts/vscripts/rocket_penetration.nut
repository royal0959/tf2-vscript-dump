::RocketPenetration <- {

	ROCKET_LAUNCHER_CLASSNAMES = [
		"tf_weapon_rocketlauncher",
		"tf_weapon_rocketlauncher_airstrike",
		"tf_weapon_rocketlauncher_directhit",
		"tf_weapon_particle_cannon",
	]


	RevertLauncherTempChanges = function(launcher) {
		local owner = launcher.GetOwner()

		launcher.RemoveAttribute("crit mod disabled hidden")

		local previousData = launcher.GetScriptScope().previousData

		local rocket = previousData.rocket

		// revert changes
		launcher.GetScriptScope().forceAttacking = false
		launcher.GetScriptScope().waitingForNextShot = false

		if (launcher.GetClassname() != "tf_weapon_particle_cannon")
			launcher.SetClip1(previousData.clip)

		// NetProps.SetPropBool(owner, "m_bLagCompensation", true)
		NetProps.SetPropFloat(launcher, "m_flNextPrimaryAttack", previousData.nextAttack)
		NetProps.SetPropFloat(launcher, "m_flEnergy", previousData.energy)
		NetProps.SetPropFloat(launcher, "m_flLastFireTime", previousData.lastFire)
		NetProps.SetPropFloat(owner, "m_Shared.m_flItemChargeMeter", previousData.charge)

		for (local entity; entity = Entities.FindByClassnameWithin(entity, "tf_projectile_*", owner.GetOrigin(), 100);) {
			if (entity.GetOwner() != owner) {
				continue
			}

			if ("isCustomRocket" in entity.GetScriptScope())
				continue

			if ("isPenetrateMimicRocket" in entity.GetScriptScope())
				continue

			NetProps.SetPropBool(self, "m_bCritical", NetProps.GetPropBool(rocket, "m_bCritical"))
			entity.SetAbsOrigin(rocket.GetOrigin())

			entity.ValidateScriptScope()
			entity.GetScriptScope().penetrationCount <- (rocket.GetScriptScope().penetrationCount - 1)
			entity.GetScriptScope().originalRocket <- rocket
			entity.GetScriptScope().isPenetrateMimicRocket <- true

			break
		}
	}

	FindRocket = function(owner) {
		local entity = null
		for (local entity; entity = Entities.FindByClassnameWithin(entity, "tf_projectile_*", owner.GetOrigin(), 100);) {
			if (entity.GetOwner() != owner) {
				continue
			}

			entity.ValidateScriptScope()
			if ("chosenAsPenetrationRocket" in entity.GetScriptScope())
				continue

			entity.GetScriptScope().chosenAsPenetrationRocket <- true

			return entity
		}

		return null
	}

	DetonateRocket = function() {
		local owner = self.GetOwner()

		// NetProps.SetPropBool(StickyMaker, "m_bCrits", NetProps.GetPropBool(self, "m_bCritical"))

		// StickyMaker.SetAbsOrigin(self.GetOrigin())
		// StickyMaker.SetTeam(owner.GetTeam())
		// StickyMaker.SetOwner(owner)

		// StickyMaker.ValidateScriptScope()
		// StickyMaker.GetScriptScope().rocket <- self
		// StickyMaker.GetScriptScope().SetProjectileOwnerAndDetonate <- function () {
		// 	for (local entity; entity = Entities.FindByClassnameWithin(entity, "tf_projectile_pipe", self.GetOrigin(), 10);) {
		// 		if (entity.GetOwner() != null) {
		// 			continue
		// 		}

		// 		entity.ValidateScriptScope()
		// 		entity.GetScriptScope().isPenetrateMimicRocket <- true
		// 		entity.GetScriptScope().originalRocket <- rocket
		// 		entity.GetScriptScope().penetrationCount <- (rocket.GetScriptScope().penetrationCount - 1)

		// 		// NetProps.SetPropString(entity, "m_iClassname", rocket.GetClassname())
		// 		NetProps.SetPropEntity(entity, "m_hLauncher", NetProps.GetPropEntity(rocket, "m_hLauncher"))

		// 		entity.SetOwner(owner)
		// 		break
		// 	}

		// 	EntFireByHandle(self, "DetonateStickies", null, -1, null, null)
		// }

		// EntFireByHandle(StickyMaker, "FireOnce", null, -1, null, null)
		// EntFireByHandle(StickyMaker, "CallScriptFunction", "SetProjectileOwnerAndDetonate", 0.1, null, null)

		local launcher = NetProps.GetPropEntity(self, "m_hLauncher")
		local launcherScope = launcher.GetScriptScope()

		// local charge = NetProps.GetPropFloat(owner, "m_Shared.m_flItemChargeMeter")
		// local nextAttack = NetProps.GetPropFloat(launcher, "m_flNextPrimaryAttack")
		// local lastFire = NetProps.GetPropFloat(launcher, "m_flLastFireTime")
		// local clip = launcher.Clip1()
		// local energy = NetProps.GetPropFloat(launcher, "m_flEnergy")

		launcherScope.previousData <- {
			rocket = self,
			charge = NetProps.GetPropFloat(owner, "m_Shared.m_flItemChargeMeter"),
			nextAttack = NetProps.GetPropFloat(launcher, "m_flNextPrimaryAttack"),
			lastFire = NetProps.GetPropFloat(launcher, "m_flLastFireTime"),
			clip = launcher.Clip1(),
			energy = NetProps.GetPropFloat(launcher, "m_flEnergy")
		}

		launcher.GetScriptScope().forceAttacking = true

		if (launcher.GetClassname() != "tf_weapon_particle_cannon")
			launcher.SetClip1(99)

		NetProps.SetPropFloat(owner, "m_Shared.m_flItemChargeMeter", 100.0)
		// NetProps.SetPropBool(owner, "m_bLagCompensation", false)
		NetProps.SetPropFloat(launcher, "m_flNextPrimaryAttack", 0)
		NetProps.SetPropFloat(launcher, "m_flEnergy", 100)

		launcher.AddAttribute("crit mod disabled hidden", 1, -1)

		if (NetProps.GetPropBool(self, "m_bChargedShot")) {
			launcher.GetScriptScope().waitingForNextShot = true
			launcher.SecondaryAttack()
			NetProps.SetPropFloat(launcher, "m_flChargeBeginTime", NetProps.GetPropFloat(launcher, "m_flChargeBeginTime") - 2.0)
		} else {
			launcher.PrimaryAttack()
			RevertLauncherTempChanges(launcher)

			// launcher.RemoveAttribute("crit mod disabled hidden")

			// // revert changes
			// launcher.GetScriptScope().forceAttacking = false

			// launcher.SetClip1(clip)
			// NetProps.SetPropBool(owner, "m_bLagCompensation", true)
			// NetProps.SetPropFloat(launcher, "m_flNextPrimaryAttack", nextAttack)
			// NetProps.SetPropFloat(launcher, "m_flEnergy", energy)
			// NetProps.SetPropFloat(launcher, "m_flLastFireTime", lastFire)
			// NetProps.SetPropFloat(owner, "m_Shared.m_flItemChargeMeter", charge)

			// for (local entity; entity = Entities.FindByClassnameWithin(entity, "tf_projectile_*", owner.GetOrigin(), 100);) {
			// 	if (entity.GetOwner() != owner) {
			// 		continue
			// 	}

			// 	if ("isCustomRocket" in entity.GetScriptScope())
			// 		continue

			// 	NetProps.SetPropBool(self, "m_bCritical", NetProps.GetPropBool(self, "m_bCritical"))
			// 	entity.SetAbsOrigin(self.GetOrigin())

			// 	entity.ValidateScriptScope()
			// 	entity.GetScriptScope().isPenetrateMimicRocket <- true
			// 	entity.GetScriptScope().originalRocket <- self
			// 	entity.GetScriptScope().penetrationCount <- (self.GetScriptScope().penetrationCount - 1)

			// 	break
			// }
		}
	}

	RocketThink = function() {
		local MASK_SOLID_BRUSHONLY = 16395

		local origin = self.GetOrigin()

		traceTableWorldSpawn <- {
			start = lastRocketOrigin,
			end = origin + (self.GetForwardVector() * 50)
			mask = MASK_SOLID_BRUSHONLY
			ignore = self.GetOwner()
		}

		TraceLineEx(traceTableWorldSpawn)

		if (traceTableWorldSpawn.hit && traceTableWorldSpawn.enthit) {
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

		// arrow free penetration through allies without detonating
		if (traceTable.enthit.GetTeam() != self.GetOwner().GetTeam()) {
			penetrationCount++
			DetonateRocket()
		}

		return -1
	}

	ApplyPenetrationToRocket = function(owner, rocket) {
		rocket.SetSolid(Constants.ESolidType.SOLID_NONE)

		rocket.ValidateScriptScope()
		local rocketScope = rocket.GetScriptScope()
		rocketScope.isCustomRocket <- true
		rocketScope.lastRocketOrigin <- rocket.GetOrigin()

		rocketScope.collidedTargets <- []
		rocketScope.penetrationCount <- 0
		rocketScope.DetonateRocket <- DetonateRocket
		rocketScope.RocketThink <- RocketThink
		rocketScope.RevertLauncherTempChanges <- RevertLauncherTempChanges

		rocketScope.ApplyThink <-  function() {
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

		if (waitingForNextShot)
		{
			RevertLauncherTempChanges(self)
			return
		}

		ApplyPenetrationToRocket(owner, rocket)
	}

	CheckWeaponFire = function() {
		local fire_time = NetProps.GetPropFloat(self, "m_flLastFireTime")
		if (fire_time > last_fire_time && !(forceAttacking && !waitingForNextShot)) {
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

		if (!("isPenetrateMimicRocket" in inflictorScope))
			return

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
			weaponScriptScope.forceAttacking <- false
			weaponScriptScope.waitingForNextShot <- false

			weaponScriptScope.CheckWeaponFire <- CheckWeaponFire
			weaponScriptScope.FindRocket <- FindRocket
			weaponScriptScope.ApplyPenetrationToRocket <- ApplyPenetrationToRocket
			weaponScriptScope.OnShot <- OnShot

			weaponScriptScope.DetonateRocket <- DetonateRocket
			weaponScriptScope.RocketThink <- RocketThink
			weaponScriptScope.RevertLauncherTempChanges <- RevertLauncherTempChanges

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

// spoof a player spawn when the wave initializes
for (local i = 1, player; i <= MaxClients(); i++)
	if (player = PlayerInstanceFromIndex(i), player)
		RocketPenetration.PlayerSpawn(player)

__CollectGameEventCallbacks(RocketPenetration)