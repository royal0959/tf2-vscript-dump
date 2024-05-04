const ANGLE_INTERVAL = 10

::ArrowMastery <- {
	FindProjectile = function(owner) {
		local entity = null
		while (entity = Entities.FindByClassnameWithin(entity, "tf_projectile_*", owner.GetOrigin(), 100)) {
			if (entity.GetOwner() != owner) {
				continue
			}

			return entity
		}

		return null
	}

	FireMasteryProjectiles = function(owner,  launcher) {
		// preserve old charge meter and ammo count
		local charge = NetProps.GetPropFloat(owner, "m_Shared.m_flItemChargeMeter")
		local clip1 = launcher.Clip1()
		local clip2 = launcher.Clip2()
		local ammo = NetProps.GetPropIntArray(owner, "m_iAmmo", 1)
		local metal = NetProps.GetPropIntArray(owner, "m_iAmmo", 3)
		local nextAttack =  NetProps.GetPropFloat(launcher, "m_flNextPrimaryAttack")

		// local eyeAngle = owner.EyeAngles()

		// TODO: cancel aim punch by changing m_VecPunchAngle

		launcher.GetScriptScope().previousData <- {
			projectile = self,
			eyeAngle = owner.EyeAngles(),
			lastEyeAngle = owner.EyeAngles(),
			origin = owner.GetOrigin(),
			lastOrigin = owner.GetOrigin(),
			charge = NetProps.GetPropFloat(owner, "m_Shared.m_flItemChargeMeter"),
			nextAttack = NetProps.GetPropFloat(launcher, "m_flNextPrimaryAttack"),
			lastFire = NetProps.GetPropFloat(launcher, "m_flLastFireTime"),
			clip = launcher.Clip1(),
		}
		launcher.GetScriptScope().forceFireNextFrameIndex = 36

		// set up stuff needed to ensure the weapon always fires
		// for (local i = 0; i < 1; i++)
		// {
			// EntFireByHandle(launcher, "CallScriptFunction", "FireWeapon", 0.1 * i, null, null)


			// launcher.SetClip1(100)
			// launcher.SetClip2(100)
			// NetProps.SetPropIntArray(owner, "m_iAmmo", 200, 3)
			// NetProps.SetPropFloat(owner, "m_Shared.m_flItemChargeMeter", 100.0)
			// NetProps.SetPropBool(owner, "m_bLagCompensation", false)
			// NetProps.SetPropFloat(launcher, "m_flNextPrimaryAttack", 0)

			// owner.SnapEyeAngles(eyeAngle + QAngle(0, 10 * (i + 1), 0))

			// // if (launcher.GetClassname() == "tf_weapon_compound_bow")
			// // {
			// // 	NetProps.SetPropFloat(launcher, "m_flChargeBeginTime", Time() - 10)
			// // 	EntFireByHandle(launcher, "FireWeapon", null, 0.1, null, null)
			// // }
			// NetProps.SetPropInt(owner, "m_nButtons", 0)
			// NetProps.SetPropInt(owner, "m_afButtonReleased", Constants.FButtons.IN_ATTACK)
			// NetProps.SetPropFloat(launcher, "m_flChargeBeginTime", Time() - 1)
			// NetProps.SetPropBool(launcher, "m_bNoFire", false)
			// NetProps.SetPropBool(launcher, "m_bInReload", false)


			// // launcher.PrimaryAttack()

			// // if (launcher.GetClassname() == "tf_weapon_compound_bow")
			// // {
			// // 	launcher.SetClip1(100)
			// // 	launcher.SetClip2(100)
			// // 	NetProps.SetPropIntArray(owner, "m_iAmmo", 200, 3)
			// // 	NetProps.SetPropFloat(owner, "m_Shared.m_flItemChargeMeter", 100.0)
			// // 	NetProps.SetPropBool(owner, "m_bLagCompensation", false)
			// // 	NetProps.SetPropFloat(launcher, "m_flNextPrimaryAttack", 0)
			// // 	NetProps.SetPropFloat(launcher, "m_flChargeBeginTime", Time())

			// // 	launcher.PrimaryAttack()
			// // }

			// // revert changes
			// NetProps.SetPropBool(owner, "m_bLagCompensation", true)
			// // launcher.SetClip1(clip1)
			// // launcher.SetClip2(clip2)
			// NetProps.SetPropIntArray(owner, "m_iAmmo", ammo, 1)
			// NetProps.SetPropIntArray(owner, "m_iAmmo", metal, 3)
			// NetProps.SetPropFloat(owner, "m_Shared.m_flItemChargeMeter", charge)
			// NetProps.SetPropFloat(launcher, "m_flNextPrimaryAttack", nextAttack)
		// }

		// owner.SnapEyeAngles(eyeAngle)
	}

	OnShot = function(owner) {
		local projectile = FindProjectile(owner)

		if (!projectile) {
			return
		}

		local launcher = NetProps.GetPropEntity(projectile, "m_hLauncher")
		FireMasteryProjectiles(owner, launcher)
	}

	CheckWeaponFire = function() {
		local lastCharge = NetProps.GetPropFloat(self, "m_flChargeBeginTime")
		if (lastCharge != 0)
			lastChargeTime = lastCharge

		local fire_time = NetProps.GetPropFloat(self, "m_flLastFireTime")
		if (fire_time > last_fire_time && !nextShotForced) {
			local owner = self.GetOwner()
			if (owner) {
				OnShot(owner)
			}

			last_fire_time = fire_time
		}

		if (nextShotForced)
		{
			nextShotForced = false

			local owner = self.GetOwner()
			local previousData = self.GetScriptScope().previousData

			// revert changes
			self.SetClip1(previousData.clip)

			// NetProps.SetPropBool(owner, "m_bLagCompensation", true)
			NetProps.SetPropFloat(self, "m_flNextPrimaryAttack", previousData.nextAttack)
			NetProps.SetPropFloat(self, "m_flLastFireTime", previousData.lastFire)
			NetProps.SetPropFloat(owner, "m_Shared.m_flItemChargeMeter", previousData.charge)

			owner.SnapEyeAngles(previousData.lastEyeAngle)
			// owner.SetAbsOrigin(previousData.lastOrigin)
		}

		return -1
	}

	PlayerSpawn = function(player) {
		player.ValidateScriptScope()
		player.GetScriptScope().bowWeapon <- null
		player.GetScriptScope().ThinkFunc <- function () {
			if (bowWeapon == null || !bowWeapon.IsValid())
				return -1

			local bowScope = bowWeapon.GetScriptScope()
			if (bowScope.forceFireNextFrameIndex <= 0)
				return -1

			local previousData = bowScope.previousData

			previousData.lastEyeAngle = self.EyeAngles()
			previousData.lastOrigin = self.GetOrigin()

			self.SnapEyeAngles(previousData.eyeAngle + QAngle(0, ANGLE_INTERVAL * bowScope.forceFireNextFrameIndex, 0))
			// self.SetAbsOrigin(previousData.origin)

			bowScope.nextShotForced = true

			bowWeapon.SetClip1(1)
			NetProps.SetPropFloat(bowWeapon, "m_flNextPrimaryAttack", 0)
			NetProps.SetPropFloat(bowWeapon, "m_flChargeBeginTime", bowScope.lastChargeTime)

			NetProps.SetPropInt(self, "m_nButtons", 0)
			NetProps.SetPropInt(self, "m_afButtonReleased", Constants.FButtons.IN_ATTACK)

			bowScope.forceFireNextFrameIndex -= 1
			// NetProps.SetPropFloat(self, "m_flChargeBeginTime", Time() - 1)

			return -1
		}
		AddThinkToEnt(player, "ThinkFunc")

		for (local i = 0; i < 8; i++) {
			local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
			if (weapon == null || weapon.IsMeleeWeapon())
				continue;


			weapon.ValidateScriptScope();
			weapon.GetScriptScope().last_fire_time <- 0.0

			// weapon.GetScriptScope().FireWeapon <- function() {
			// 	weapon.PrimaryAttack()
			// }
			weapon.GetScriptScope().forceFireNextFrameIndex <- 0
			weapon.GetScriptScope().nextShotForced <- false
			weapon.GetScriptScope().lastChargeTime <- false

			weapon.GetScriptScope().FireWeapon <- function() {
				local owner = self.GetOwner()

				local charge = NetProps.GetPropFloat(owner, "m_Shared.m_flItemChargeMeter")
				local clip1 = weapon.Clip1()
				local clip2 = weapon.Clip2()
				local ammo = NetProps.GetPropIntArray(owner, "m_iAmmo", 1)
				local metal = NetProps.GetPropIntArray(owner, "m_iAmmo", 3)
				local nextAttack =  NetProps.GetPropFloat(weapon, "m_flNextPrimaryAttack")

				weapon.SetClip1(100)
				weapon.SetClip2(100)
				NetProps.SetPropIntArray(owner, "m_iAmmo", 200, 3)
				NetProps.SetPropFloat(owner, "m_Shared.m_flItemChargeMeter", 100.0)
				NetProps.SetPropBool(owner, "m_bLagCompensation", false)
				NetProps.SetPropFloat(weapon, "m_flNextPrimaryAttack", 0)


				NetProps.SetPropFloat(weapon, "m_flChargeBeginTime", Time() - 1)
				NetProps.SetPropBool(weapon, "m_bNoFire", false)
				NetProps.SetPropBool(weapon, "m_bInReload", false)

				printl( NetProps.GetPropInt(owner, "m_nButtons"))
				weapon.PrimaryAttack()

				// revert changes
				NetProps.SetPropBool(owner, "m_bLagCompensation", true)
				weapon.SetClip1(clip1)
				weapon.SetClip2(clip2)
				NetProps.SetPropIntArray(owner, "m_iAmmo", ammo, 1)
				NetProps.SetPropIntArray(owner, "m_iAmmo", metal, 3)
				NetProps.SetPropFloat(owner, "m_Shared.m_flItemChargeMeter", charge)
				NetProps.SetPropFloat(weapon, "m_flNextPrimaryAttack", nextAttack)
			}
			weapon.GetScriptScope().CheckWeaponFire <- CheckWeaponFire
			weapon.GetScriptScope().FindProjectile <- FindProjectile
			weapon.GetScriptScope().FireMasteryProjectiles <- FireMasteryProjectiles
			weapon.GetScriptScope().OnShot <- OnShot

			if (weapon.GetClassname() == "tf_weapon_compound_bow")
				player.GetScriptScope().bowWeapon = weapon

			AddThinkToEnt(weapon, "CheckWeaponFire")
		}
	}

	Cleanup = function() {
		delete::ArrowMastery
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
		ArrowMastery.PlayerSpawn(player)

__CollectGameEventCallbacks(ArrowMastery)