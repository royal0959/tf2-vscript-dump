# tf2-vscript-dump
A rogues gallery of personal vscript projects

# Index
* ``cowmangler charge shot override`` - Replaces cowmangler charge-shot with short circuit ball, can be modified to use other projectiles
* ``red sniper laser`` - Spawns a wrangler laser for red snipers when aiming (both bots & players, can be edited to only apply to bots)
* ``damageable projectile shield`` - Makes projectile shields lose duration upon blocking damage & show damage number when damaging projectile shield
* ``rocket penetration`` - Allows rockets (including cowmangler charge shot) to penetrate enemies, dealing damage each time
* ``drop red cash`` - All bots drop red money on dead as if they were killed by a sniper rifle
* ``rescue ranger heal player`` - Rescue ranger bolts heal teammates on hit, consuming metal the same way it does when healing buildings
* ``hell's retriever`` - A personal project to recreate the Hell's Retriever throwable from call of duty zombie map Mob of The Dead. Replaces flying guillotine with a projectile that
  - Locks onto at most 10 nearby enemies and move toward them one by one, dealing damage to each target once on collision. Goes through walls
  - Holding out the weapon charges it for increased damage, each charge level plays a particle effect below your feet, up to 3 charge levels (to simulate the original weapon's hold to charge mechanic)
  - Disables natural recharge meter while projectile is out (to simulate being locked to 1 projectile)
  - Spins in the air (for visual)
  - Returns to thrower after reaching enemy cap or found no enemy in range
  - Holds onto any credits it goes near and brings it back to thrower (to simulate the original Hell's Retriever ability to collect powerups)
* ``knockback rage override`` - Overrides vanilla knockback rage behavior