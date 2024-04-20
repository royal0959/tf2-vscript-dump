local MASK_PLAYERSOLID = 33636363

local DAMAGE = 150
local SEEKING_RANGE = 5000
local MAX_HIT_TARGETS = 10
local MONEY_COLLECTION_RANGE = 1000
local TURN_POWER = 0.75 // 0-1
local TIME_BEFORE_RECALL = 0.4 // send projectile back to player after this many seconds passed without a target
local BASE_LAUNCHER_RECHARGE_TIME = 5.5

local MAX_CHARGE_TIME = 3
local MAX_CHARGE_DAMAGE_BONUS = 150

local PATTACH_ABSORIGIN_FOLLOW = 1
local SF_TRIGGER_ALLOW_ALL = 64

FakeCleaverMaker <- Entities.CreateByClassname("tf_weapon_rocketlauncher")
NetProps.SetPropInt(FakeCleaverMaker, "m_AttributeManager.m_Item.m_iItemDefinitionIndex", 18) // https://wiki.alliedmods.net/Team_Fortress_2_Item_Definition_Indexes
NetProps.SetPropBool(FakeCleaverMaker, "m_AttributeManager.m_Item.m_bInitialized", true)
Entities.DispatchSpawn(FakeCleaverMaker)
FakeCleaverMaker.AddAttribute("crit mod disabled hidden", 1, -1)
FakeCleaverMaker.SetClip1(-1)

::HellRetriever <- {
	FindCleaver = function(owner) {
		for (local entity; entity = Entities.FindByClassnameWithin(entity, "tf_projectile_cleaver", owner.GetOrigin(), 100);) {
			if (NetProps.GetPropEntity(entity, "m_hThrower") != owner) {
				continue
			}

			entity.ValidateScriptScope()
			if ("chosenAsHellRetriever" in entity.GetScriptScope())
				continue

			entity.GetScriptScope().chosenAsHellRetriever <- true

			return entity
		}

		return null
	}

	CleaverThink = function() {
		if (!stoppedCooldown)
		{
			stoppedCooldown = true
			cooldownTime = NetProps.GetPropFloat(realLauncher, "m_flEffectBarRegenTime") - Time() + 0.2
		}

		NetProps.SetPropFloat(realLauncher, "m_flEffectBarRegenTime", Time() + cooldownTime)
		self.SetCollisionGroup(Constants.ECollisionGroup.COLLISION_GROUP_VEHICLE_CLIP)

		propPitch += 20
		projectileProp.SetAbsAngles(QAngle(propPitch, 0, 0))

		for (local entity; entity = Entities.FindByClassnameWithin(entity, "item_currencypack_*", owner.GetOrigin(), MONEY_COLLECTION_RANGE);)
		{
			if (attachedMoney.find(entity) != null)
				continue

			attachedMoney.append(entity)
		}

		foreach(moneyPack in attachedMoney)
		{
			if (!moneyPack.IsValid())
				continue

			moneyPack.SetAbsOrigin(self.GetOrigin())
		}

		if (!currentTarget)
			currentTarget = FindTarget()

		local returnToPlayer = false

		if (targetsCount > MAX_HIT_TARGETS)
			returnToPlayer = true
		else if (!currentTarget)
		{
			timeWithoutTargetInRange += FrameTime()

			if (timeWithoutTargetInRange >= TIME_BEFORE_RECALL)
				returnToPlayer = true
		}

		if (returnToPlayer)
			currentTarget = owner

		local origin = self.GetOrigin()

		if (!currentTarget)
		{
			lastProjectileOrigin = origin
			return -1
		}

		FaceTarget()

		traceTable <- {
			start = lastProjectileOrigin,
			end = origin
			mask = MASK_PLAYERSOLID
		}

		TraceLineEx(traceTable)

		lastProjectileOrigin = origin

		if (!traceTable.hit)
			return -1

		local entHit = traceTable.enthit

		if (!entHit)
			return -1

		if (!entHit.IsPlayer())
			return -1

		if (entHit != currentTarget)
			return -1

		if (entHit != owner)
			HitTarget()
		else
			self.Kill()

		return -1
	}

	ApplyMovementLogic = function(owner, cleaver, launcher) {
		cleaver.SetMoveType(Constants.EMoveType.MOVETYPE_NOCLIP,  Constants.EMoveCollide.MOVECOLLIDE_DEFAULT)

		cleaver.ValidateScriptScope()
		local cleaverScope = cleaver.GetScriptScope()

		cleaverScope.realLauncher <- launcher

		cleaverScope.stoppedCooldown <- false
		cleaverScope.cooldownTime <- 0
		cleaverScope.charge <- launcher.GetScriptScope().currentCharge
		cleaverScope.lastProjectileOrigin <- cleaver.GetOrigin()
		cleaverScope.collidedTargets <- []
		cleaverScope.attachedMoney <- []
		cleaverScope.currentTarget <- null
		cleaverScope.targetsCount <- 0
		cleaverScope.owner <- owner

		cleaverScope.timeWithoutTargetInRange <- 0
		cleaverScope.propPitch <- 0

		cleaverScope.CleaverThink <- CleaverThink

		cleaverScope.FindTarget <- function()
		{
			local origin = self.GetOrigin()

			local closestTarget = null
			local closestDistance = 1e30
			for (local entity; entity = Entities.FindByClassnameWithin(entity, "player", self.GetOrigin(), SEEKING_RANGE);)
			{
				if (NetProps.GetPropInt(entity, "m_lifeState") != 0)
					continue

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

			if (!closestTarget)
				return

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
			local goalDirection = currentTarget.EyePosition() - self.GetOrigin()
			local speed = self.GetAbsVelocity().Norm()
			goalDirection.Norm()

			local forwardVector = self.GetForwardVector()
			local direction = forwardVector + (goalDirection - forwardVector) * TURN_POWER
			direction.Norm()

			local angle = VectorAngles(direction)
			local velocity = angle.Forward() * speed

			self.SetAbsVelocity(velocity)
			self.SetLocalAngles(angle)
		}

		cleaverScope.HitTarget <- function () {
			local damage = DAMAGE + (MAX_CHARGE_DAMAGE_BONUS * charge)

			currentTarget.TakeDamageEx(self, owner, realLauncher, Vector(0, 0, 0), owner.GetOrigin(), damage, Constants.FDmgType.DMG_CLUB)

			collidedTargets.append(currentTarget)
			targetsCount++
			currentTarget = null
		}

		cleaverScope.ApplyThink <- function() {
			AddThinkToEnt(cleaver, "CleaverThink")
		}

		EntFireByHandle(cleaver, "CallScriptFunction", "ApplyThink", 0.015, null, null)
	}

	OnShot = function() {
		local owner = self.GetOwner()
		local cleaver = FindCleaver(owner)

		if (!cleaver) {
			return
		}

		cleaver.Kill()

		local charge = NetProps.GetPropFloat(owner, "m_Shared.m_flItemChargeMeter");
		local ammo = NetProps.GetPropIntArray(owner, "m_iAmmo", 1);
		// set up stuff needed to ensure the weapon always fires
		NetProps.SetPropIntArray(owner, "m_iAmmo", 99, 1)
		NetProps.SetPropFloat(owner, "m_Shared.m_flItemChargeMeter", 100.0)
		NetProps.SetPropBool(owner, "m_bLagCompensation", false)
		NetProps.SetPropFloat(FakeCleaverMaker, "m_flNextPrimaryAttack", 0)
		NetProps.SetPropEntity(FakeCleaverMaker, "m_hOwner", owner)

		FakeCleaverMaker.PrimaryAttack()
		FakeCleaverMaker.StopSound("Weapon_RPG.Single") // doesn't work

		// revert changes
		NetProps.SetPropBool(owner, "m_bLagCompensation", true)
		NetProps.SetPropIntArray(owner, "m_iAmmo", ammo, 1)
		NetProps.SetPropFloat(owner, "m_Shared.m_flItemChargeMeter", charge)

		local fakeProjectile

		for (local entity; entity = Entities.FindByClassnameWithin(entity, "tf_projectile_rocket", owner.GetOrigin(), 100);) {
			local owner = entity.GetOwner()

			if (owner != owner) {
				continue
			}

			entity.ValidateScriptScope()
			if ("chosenAsFakeCleaver" in entity.GetScriptScope())
				continue

			entity.GetScriptScope().chosenAsFakeCleaver <- true

			fakeProjectile = entity
		}

		EntFireByHandle(fakeProjectile, "DispatchEffect", "ParticleEffectStop", -1, null, null)
		NetProps.SetPropString(fakeProjectile, "m_iClassname", "tf_weapon_cleaver")

		local particle = SpawnEntityFromTable("trigger_particle", {
			particle_name = "eyeboss_projectile",
			attachment_type = PATTACH_ABSORIGIN_FOLLOW,
			spawnflags = SF_TRIGGER_ALLOW_ALL
		})
		EntFireByHandle(particle, "StartTouch", "!activator", -1, fakeProjectile, fakeProjectile)
		EntFireByHandle(particle, "Kill", "", -1, null, null)

		fakeProjectile.SetModelSimple("models/empty.mdl")

		local projectileProp = SpawnEntityFromTable("prop_dynamic", {
			model = "models/workshop_partner/weapons/c_models/c_sd_cleaver/c_sd_cleaver.mdl",
			solid = 0,
		})
		projectileProp.SetAbsOrigin(fakeProjectile.GetOrigin())
		EntFireByHandle(projectileProp, "SetParent", "!activator", -1, fakeProjectile, fakeProjectile)

		fakeProjectile.GetScriptScope().projectileProp <- projectileProp

		ApplyMovementLogic(owner, fakeProjectile, self)
	}

	LauncherThink = function() {
		local owner = self.GetOwner()

		// check weapon fire
		local fire_time = NetProps.GetPropFloat(self, "m_flLastFireTime")
		if (fire_time > last_fire_time) {
			if (owner) {
				// OnShot()
				EntFireByHandle(self, "CallScriptFunction", "OnShot", 0.1, null, null)
			}

			last_fire_time = fire_time
		}

		// apply charge
		if (owner.GetActiveWeapon() == self)
		{
			if (currentCharge < MAX_CHARGE_TIME)
			{
				currentCharge += FrameTime()
				if (currentCharge > MAX_CHARGE_TIME)
					currentCharge = MAX_CHARGE_TIME

				if (currentChargeTier == 1 && currentCharge >= MAX_CHARGE_TIME * 0.33)
				{
					PlayChargeTierChangeEffect()
					currentChargeTier++
				}
				else if (currentChargeTier == 2 && currentCharge >= MAX_CHARGE_TIME * 0.66)
				{
					PlayChargeTierChangeEffect()
					currentChargeTier++
				}
				else if (currentChargeTier == 3 && currentCharge >= MAX_CHARGE_TIME)
				{
					PlayChargeTierChangeEffect()
					currentChargeTier++
				}
			}
			else
			{
				owner.AddCondEx(33, 0.03, owner)
			}
		}
		else
		{
			currentCharge = 0
			currentChargeTier = 1
		}

		return -1
	}


	PlayerSpawn = function(player) {
		for (local i = 0; i < 8; i++) {
			local weapon = NetProps.GetPropEntityArray(player, "m_hMyWeapons", i)
			if (weapon == null)
				continue

			if (weapon.GetClassname() != "tf_weapon_cleaver")
				continue

			weapon.ValidateScriptScope();
			local weaponScriptScope = weapon.GetScriptScope()
			weaponScriptScope.last_fire_time <- 0.0
			weaponScriptScope.currentCharge <- 0.0
			weaponScriptScope.currentChargeTier <- 1

			weaponScriptScope.PlayChargeTierChangeEffect <- function () {
				player.AddCondEx(20, 0.2, player)
			}

			weaponScriptScope.LauncherThink <- LauncherThink
			weaponScriptScope.FindCleaver <- FindCleaver
			weaponScriptScope.ApplyMovementLogic <- ApplyMovementLogic
			weaponScriptScope.OnShot <- OnShot
			weaponScriptScope.FakeCleaverMaker <- FakeCleaverMaker

			weaponScriptScope.CleaverThink <- CleaverThink

			AddThinkToEnt(weapon, "LauncherThink")
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

HellRetriever.FakeCleaverMaker <- FakeCleaverMaker

// spoof a player spawn when the wave initializes
for (local i = 1, player; i <= MaxClients(); i++)
	if (player = PlayerInstanceFromIndex(i), player)
		HellRetriever.PlayerSpawn(player)

__CollectGameEventCallbacks(HellRetriever)