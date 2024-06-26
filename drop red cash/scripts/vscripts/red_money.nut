const TF_POWERUP_LIFETIME = 30
const MASK_SOLID_BRUSHONLY = 16395

::RedMoney <- {
	CollectPack = function() {
		local pack = self

		if (!pack.IsValid())
			return

		if (NetProps.GetPropBool(pack, "m_bDistributed"))
			return

		local packClassName = pack.GetClassname()
		local origin = pack.GetScriptScope().RealOrigin
		local owner = NetProps.GetPropEntity(pack, "m_hOwnerEntity")
		local modelPath = pack.GetModelName()

		local objectiveResource = Entities.FindByClassname(null, "tf_objective_resource")

		local moneyBefore = NetProps.GetPropInt(objectiveResource, "m_nMvMWorldMoney")
		pack.Kill()
		local moneyAfter = NetProps.GetPropInt(objectiveResource, "m_nMvMWorldMoney")

		local packPrice = moneyBefore - moneyAfter

		local mvmStats = Entities.FindByClassname(null, "tf_mann_vs_machine_stats")

		NetProps.SetPropInt(mvmStats, "m_currentWaveStats.nCreditsAcquired", NetProps.GetPropInt(mvmStats, "m_currentWaveStats.nCreditsAcquired") + packPrice)

		for (local i = 1, player; i <= MaxClients(); i++)
			if (player = PlayerInstanceFromIndex(i), player && !IsPlayerABot(player))
				player.AddCurrency(packPrice)

		// spawn a worthless currencypack which can be collected by a scout for overheal
		local fakePack = Entities.CreateByClassname("item_currencypack_custom")
		NetProps.SetPropBool(fakePack, "m_bDistributed", true)
		NetProps.SetPropEntity(fakePack, "m_hOwnerEntity", owner)
		fakePack.DispatchSpawn()
		fakePack.SetModel(modelPath)
		fakePack.SetAbsOrigin(origin)

		// position to ground, as fake pack won't have any velocity
		traceWorld <- {
			start = origin,
			end = origin - Vector(0, 0, 50000)
			mask = MASK_SOLID_BRUSHONLY
		}

		TraceLineEx(traceWorld)

		if (traceWorld.hit)
		{
			fakePack.SetAbsOrigin(traceWorld.pos + Vector(0, 0, 5))
		}
		else
			fakePack.SetAbsOrigin(origin)

		fakePack.ValidateScriptScope()
		fakePack.GetScriptScope().despawnTime <- Time() + TF_POWERUP_LIFETIME
		fakePack.GetScriptScope().DespawnThink <- function () {
			if (Time() < despawnTime)
				return

			fakePack.Kill()
		}

		AddThinkToEnt(fakePack, "DespawnThink")

	}

	OnGameEvent_player_death = function(params) {
		local player = GetPlayerFromUserID(params.userid)

		// bots only drop item_currencypack_custom, but all other pack classes are supported just in case
		for (local entity; entity = Entities.FindByClassnameWithin(entity, "item_currencypack_*", player.GetOrigin(), 100);) {
			entity.ValidateScriptScope()
			local scriptScope = entity.GetScriptScope()
			scriptScope.RealOrigin <- entity.GetOrigin()
			scriptScope.CollectPack <- CollectPack

			entity.SetAbsOrigin(Vector(-1000000, -1000000, -1000000))
			EntFireByHandle(entity, "CallScriptFunction", "CollectPack", 0, null, null)
			// scriptScope.CollectPack()
		}
	}

	Cleanup = function() {
		delete::RedMoney
	}

	OnGameEvent_recalculate_holidays = function(_) {
		if (GetRoundState() != 3) return
		Cleanup()
	}

	OnGameEvent_mvm_wave_complete = function(_) {
		Cleanup()
	}
}

__CollectGameEventCallbacks(RedMoney)