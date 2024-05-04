const ANGLE_INTERVAL = 5

::ArrowMastery <- {
	OnShot = function(owner) {
		local ammo = NetProps.GetPropIntArray(owner, "m_iAmmo", 1)
		foreach(bow in extraBows) {
			// set up stuff needed to ensure the weapon always fires
			NetProps.SetPropFloat(bow, "m_flChargeBeginTime", lastChargeTime)
			NetProps.SetPropFloat(bow, "m_flNextPrimaryAttack", 0)
			NetProps.SetPropEntity(bow, "m_hOwner", owner);

			bow.PrimaryAttack()
		}
		NetProps.SetPropIntArray(owner, "m_iAmmo", ammo, 1)

		local realArrow
		for (local projectile; projectile = Entities.FindByClassnameWithin(projectile, "tf_projectile_arrow", owner.GetOrigin(), 100);) {
			if (projectile.GetOwner() != owner)
				continue


			local launcher = NetProps.GetPropEntity(projectile, "m_hLauncher")
			if (launcher != self)
				continue

			realArrow = projectile
			break
		}

		if (realArrow == null)
		{
			return
		}

		local arrowCountPositive = 0
		local arrowCountNegative = 0

		local negativeAngle = false
		for (local projectile; projectile = Entities.FindByClassnameWithin(projectile, "tf_projectile_arrow", owner.GetOrigin(), 100);) {
			if (projectile.GetOwner() != owner)
				continue

			if (projectile == realArrow)
				continue

			local forwardVector = realArrow.GetForwardVector()
			local speed = realArrow.GetAbsVelocity().Norm()

			local direction = forwardVector
			direction.Norm()

			local negativeMult = negativeAngle ? -1 : 1

			local angleMult = 1
			if (negativeAngle)
				angleMult = arrowCountNegative + 1
			else
				angleMult = arrowCountPositive + 1

			local angle = VectorAngles(direction) + QAngle(0, ANGLE_INTERVAL * angleMult * negativeMult , 0)
			local velocity = angle.Forward() * speed

			projectile.SetLocalAngles(angle)
			projectile.SetAbsVelocity(velocity)

			if (negativeAngle)
				arrowCountNegative++
			else
				arrowCountPositive++

			negativeAngle = !negativeAngle
		}
	}

	CheckWeaponFire = function() {
		local lastCharge = NetProps.GetPropFloat(self, "m_flChargeBeginTime")
		if (lastCharge != 0)
			lastChargeTime = lastCharge

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

	PlayerSpawn = function(player) {
		for (local i = 0; i < 8; i++) {
			local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
			if (weapon == null || weapon.IsMeleeWeapon())
				continue;

			if (weapon.GetClassname() != "tf_weapon_compound_bow")
				continue

			weapon.ValidateScriptScope()
			weapon.GetScriptScope().last_fire_time <- 0.0
			weapon.GetScriptScope().lastChargeTime <- false
			weapon.GetScriptScope().extraBows <- []

			weapon.GetScriptScope().VectorAngles <- function(forward)
			{
				local yaw, pitch
				if ( forward.y == 0.0 && forward.x == 0.0 ) {
					yaw = 0.0
					if (forward.z > 0.0)
						pitch = 270.0
					else
						pitch = 90.0
				}
				else {
					yaw = (atan2(forward.y, forward.x) * 180.0 / PI)
					if (yaw < 0.0)
						yaw += 360.0
					pitch = (atan2(-forward.z, forward.Length2D()) * 180.0 / PI)
					if (pitch < 0.0)
						pitch += 360.0
				}

				return QAngle(pitch, yaw, 0.0)
			}

			for (i = 0; i < 4; i++)
			{
				ExtraBow <- Entities.CreateByClassname("tf_weapon_crossbow")
				NetProps.SetPropInt(ExtraBow, "m_AttributeManager.m_Item.m_iItemDefinitionIndex", 305) // https://wiki.alliedmods.net/Team_Fortress_2_Item_Definition_Indexes
				NetProps.SetPropBool(ExtraBow, "m_AttributeManager.m_Item.m_bInitialized", true)
				Entities.DispatchSpawn(ExtraBow)
				ExtraBow.AddAttribute("crit mod disabled hidden", 1, -1)
				ExtraBow.AddAttribute("override projectile type", 8, -1) // huntsman arrow
				// ExtraBow.AddAttribute("centerfire projectile", 1, -1)

				ExtraBow.SetClip1(-1)
				ExtraBow.SetOwner(player)

				weapon.GetScriptScope().extraBows.append(ExtraBow)
			}

			weapon.GetScriptScope().OnShot <- OnShot
			weapon.GetScriptScope().CheckWeaponFire <- CheckWeaponFire
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