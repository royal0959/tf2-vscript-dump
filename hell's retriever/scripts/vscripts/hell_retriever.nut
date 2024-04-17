local MASK_PLAYERSOLID = 33636363

local SEEKING_RANGE = 500
local PROJECTILE_SPEED = 10
local TURN_POWER = 500


::HellRetriever <- {
	FindCleaver = function(owner) {
		local entity = null
		for (local entity; entity = Entities.FindByClassnameWithin(entity, "tf_projectile_*", owner.GetOrigin(), 1000);) {
			printl(entity)
			if (entity.GetOwner() != owner) {
				continue
			}
			// if (NetProps.GetPropEntity(entity, "m_hThrower") != owner) {
			// 	continue
			// }

			entity.ValidateScriptScope()
			if ("chosenAsHellRetriever" in entity.GetScriptScope())
				continue

			entity.GetScriptScope().chosenAsHellRetriever <- true

			return entity
		}

		return null
	}

	CleaverThink = function() {
		if (!currentTarget)
			currentTarget = FindTarget()

		if (!currentTarget)
			return

		FaceTarget()

		local origin = self.GetOrigin()

		traceTable <- {
			start = lastProjectileOrigin,
			end = origin
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

		if (traceTable.enhit != currentTarget)
			return -1

		HitTarget()

		return -1
	}

	ApplyMovementLogic = function(owner, cleaver) {
		cleaver.SetSolid(Constants.ESolidType.SOLID_NONE)

		cleaver.ValidateScriptScope()
		local cleaverScope = cleaver.GetScriptScope()

		cleaverScope.lastProjectileOrigin <- cleaver.GetOrigin()
		cleaverScope.collidedTargets <- []
		cleaverScope.currentTarget <- null
		cleaverScope.penetrationCount <- 0
		cleaverScope.owner <- owner
		cleaverScope.CleaverThink <- CleaverThink

		cleaverScope.FindTarget <- function()
		{
			local origin = self.GetOrigin()

			local closestTarget = null
			local closestDistance = 9999999999
			for (local entity; entity = Entities.FindByClassnameWithin(entity, "player", self.GetOrigin(), SEEKING_RANGE);)
			{
				if (entity.GetTeam() == owner.GetTeam())
					continue

				if (collidedTargets.find(entity) != null)
					continue

				local distance = (entity.GetOrigin() - origin).Length()

				if (distance > closestDistance)
					continue

				closestTarget = entity
				closestDistance = distance
			}

			printl(closestDistance)
			printl(closestTarget)

			return closestTarget
		}

		cleaverScope.VectorAngles <- function(forward)
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

		cleaverScope.FaceTarget <- function () {
			local desired_dir = currentTarget.EyePosition() - self.GetOrigin()

			desired_dir.Norm()

			local forwardVector = self.GetForwardVector()
			local direction = forwardVector + (desired_dir - forwardVector) * TURN_POWER
			direction.Norm()

			local angle = VectorAngles(direction)
			local velocity = angle.Forward() * PROJECTILE_SPEED

			self.SetAbsVelocity(velocity)
			self.SetLocalAngles(angle)
		}

		cleaverScope.HitTarget <- function () {
			// do damage here

			collidedTargets.append(currentTarget)
			currentTarget = null
		}

		cleaverScope.ApplyThink <- function() {
			AddThinkToEnt(cleaver, "CleaverThink")
		}

		EntFireByHandle(cleaver, "CallScriptFunction", "ApplyThink", 0.015, null, null)
	}

	OnShot = function() {
		printl("finding")
		local owner = self.GetOwner()
		local cleaver = FindCleaver(owner)

		printl(cleaver)

		if (!cleaver) {
			return
		}

		ApplyMovementLogic(owner, cleaver)
	}

	CheckWeaponFire = function() {
		local fire_time = NetProps.GetPropFloat(self, "m_flLastFireTime")
		if (fire_time > last_fire_time) {
			local owner = self.GetOwner()
			if (owner) {
				// OnShot()
				EntFireByHandle(self, "CallScriptFunction", "OnShot", 0.1, null, null)
			}

			last_fire_time = fire_time
		}
		return -1
	}


	PlayerSpawn = function(player) {
		for (local i = 0; i < 8; i++) {
			local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
			if (weapon == null)
				continue

			// if (weapon.GetClassname() != "tf_weapon_cleaver")
			// 	continue

			weapon.ValidateScriptScope();
			local weaponScriptScope = weapon.GetScriptScope()
			weaponScriptScope.last_fire_time <- 0.0

			weaponScriptScope.CheckWeaponFire <- CheckWeaponFire
			weaponScriptScope.FindCleaver <- FindCleaver
			weaponScriptScope.ApplyMovementLogic <- ApplyMovementLogic
			weaponScriptScope.OnShot <- OnShot

			weaponScriptScope.CleaverThink <- CleaverThink

			AddThinkToEnt(weapon, "CheckWeaponFire")
		}
	}

	Cleanup = function() {
		delete::HellRetriever
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
		HellRetriever.PlayerSpawn(player)

__CollectGameEventCallbacks(HellRetriever)