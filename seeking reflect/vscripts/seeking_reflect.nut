::ReflectSeekOriginalShooter <- {
	function ApplyHoming(projectile, target)
	{
		projectile.ValidateScriptScope()
		local scope = projectile.GetScriptScope()

		scope.target <- target

		scope.VectorAngles <- function(forward) {
			local yaw, pitch

			if (forward.y == 0.0 && forward.x == 0.0) {
				yaw = 0.0

				if (forward.z > 0.0)
					pitch = 270.0
				else
					pitch = 90.0
			}
			else {
				yaw = atan2(forward.y, forward.x) * 180.0 / PI

				if (yaw < 0.0)
					yaw += 360.0

				pitch = atan2(-forward.z, forward.Length2D()) * 180.0 / PI

				if (pitch < 0.0)
					pitch += 360.0
			}

			return QAngle(pitch, yaw, 0.0)
		}

		scope.ReflectHomingThink <- function() {
			if (!self.IsValid())
				return

			if (!target || !target.IsAlive())
				return -1

			local goalDirection = target.EyePosition() - self.GetOrigin()

			local speed = self.GetAbsVelocity().Length()
			goalDirection.Norm()

			local currentForward = self.GetForwardVector()

			local turnPower = 0.75

			local newDirection = currentForward + (goalDirection - currentForward) * turnPower
			newDirection.Norm()

			local angle = VectorAngles(newDirection)

			self.SetAbsVelocity(angle.Forward() * speed)
			self.SetLocalAngles(angle)

			return -1
		}

		scope.ApplyThink <- function() {
			// for popext which breaks AddThinkToEnt for projectiles
			local AddThinkSafe = @(ent, func) "_AddThinkToEnt" in ROOT ? ROOT._AddThinkToEnt(ent, func) : ROOT.AddThinkToEnt(ent, func)
			AddThinkSafe(projectile, "ReflectHomingThink")
		}

		EntFireByHandle(projectile, "CallScriptFunction", "ApplyThink", 0.015, null, null)
	}

	function OnGameEvent_object_deflected(params) {
		local player = GetPlayerFromUserID(params.userid)

		if (player == null || !player.IsValid())
			return

		if (player.GetPlayerClass() != Constants.ETFClass.TF_CLASS_PYRO)
			return

		local originalOwner = GetPlayerFromUserID(params.ownerid)

		if (originalOwner == null || !originalOwner.IsValid())
			return

		local projectile = EntIndexToHScript(params.object_entindex)

		if (projectile == null || !projectile.IsValid())
			return

		ApplyHoming(projectile, originalOwner)
	}
}

__CollectGameEventCallbacks(ReflectSeekOriginalShooter)