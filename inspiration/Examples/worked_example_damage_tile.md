# Worked Example: "Cannon" — Deal Die-Value Damage to a Random Enemy

This is a complete walkthrough of authoring one tile using the new system,
from empty files to a working, modifier-responsive tile.

---

## What the tile does

> "When activated with a die, deal damage equal to the die's face value to a
> random enemy. If the player has a Double Damage upgrade, the damage is doubled."

---

## Step 1 — Create the EffectData resources

You need two EffectData resources in sequence:
1. **Target a random enemy** (sets `context.targets`)
2. **Deal damage equal to the die value** (reads `context.targets` + `inherit_die_amount`)

### EffectData #1 — Targeting

Right-click in FileSystem → **New Resource** → select `EffectData` → save as:
`Source/Content/EffectsV2/Data/cannon_target_random_enemy.tres`

Set in the inspector:
```
category : 0        (TARGETING)
subtype  : 2        (TARGET_RANDOM_ENEMY — see EffectEnums.TargetingSubtype)
```
All other fields: leave at defaults (they are ignored by TargetRandomEnemyHandler).

---

### EffectData #2 — Damage

Right-click → **New Resource** → `EffectData` → save as:
`Source/Content/EffectsV2/Data/cannon_deal_damage.tres`

Set in the inspector:
```
category           : 1     (ATTRIBUTE_CHANGE)
subtype            : 0     (DAMAGE — see EffectEnums.AttributeChangeSubtype)
amount             : 0     (ignored because inherit_die_amount = true)
inherit_die_amount : true  (use the die's face value as the damage amount)
```

---

## Step 2 — Create the EffectChainV2 resource

Right-click → **New Resource** → `EffectChainV2` → save as:
`Source/Content/EffectsV2/Chains/cannon_chain.tres`

In the inspector, open the `effects` array and add two entries:
```
effects[0] : cannon_target_random_enemy.tres
effects[1] : cannon_deal_damage.tres
```

Order matters. Targeting always comes before attribute changes.

---

## Step 3 — Set up the TileResource

Open (or create) your Cannon tile resource:
`Source/Content/Tiles/TileResources/cannon.tres`

In the inspector:
```
tile_name              : "Cannon"
activation_description : "Deal [die] damage to a random enemy."
effect_chain_v2        : cannon_chain.tres    ← point to the v2 chain
effect_chain           : (leave empty, or keep old one during migration)
```

---

## Step 4 — What happens at runtime

When the player drops a die showing 4 onto the Cannon tile:

```
Tile.activate(die)
  │
  ├── Builds EffectContext:
  │     actor         = Globals.player
  │     effect_source = self (the Cannon tile node)
  │     activator_die = die  (value = 4)
  │
  ├── Calls cannon_chain.play(context, scenario_engine)
  │     │
  │     ├── TargetRandomEnemyHandler.apply(...)
  │     │     → context.targets = [some_random_enemy]
  │     │
  │     └── DealDamageHandler.apply(...)
  │           → base_amount = die.value = 4  (inherit_die_amount = true)
  │           → creates DamageEvent { actor=player, targets=[enemy], amount=4 }
  │           → engine.enqueue_event(damage_event)
  │
  └── Calls await scenario_engine.process_events()
        │
        ├── Pops DamageEvent
        │
        ├── Before-hooks:
        │     DoubleDamageModifier.on_before_event(damage_event, engine)
        │       → damage_event.amount = 4 * 2 = 8   ← modifier doubled it!
        │
        ├── DamageEvent.resolve(engine)
        │     → spawns particles at enemy (blue/red based on shields vs HP)
        │     → Events.player_attacked_ship.emit(enemy, faction)
        │     → Globals.state_manager.state = IN_COMBAT
        │     → enemy.health.take_damage(8)
        │
        └── After-hooks:
              ShieldOnDamageModifier.on_after_event(damage_event, engine)
                → engine.enqueue_event(ShieldEvent { targets=[player], amount=1 })
              (loop continues → processes the ShieldEvent next)
```

---

## Step 5 — How to add the DoubleDamage upgrade

In your upgrade/reward system, when the player picks up "Double Damage":

```gdscript
# In whatever manages upgrade pickup:
var mod := DoubleDamageModifier.new()
player.active_modifiers.append(mod)  # store in player so it persists between scenarios
```

Then in ScenarioEngine setup (wherever you create the engine):

```gdscript
var engine := ScenarioEngine.new()
add_child(engine)

for mod: Modifier in Globals.player.active_modifiers:
    engine.add_modifier(mod)
```

The engine is recreated each scenario. Modifiers are loaded onto it fresh each time
from the player's persistent modifier list. When the scenario ends, `engine.queue_free()`
and the modifiers (which are RefCounted) are automatically cleaned up.

---

## Common mistakes to avoid

| Mistake | Fix |
|---|---|
| Targeting after damage | Always put targeting EffectData before attribute change EffectData |
| Forgetting `await process_events()` | Without the await, events enqueue but never resolve before the next frame |
| Using `amount` instead of `inherit_die_amount` for die-scaling tiles | Set `inherit_die_amount = true`, leave `amount = 0` |
| Calling `process_events()` twice | The re-entrancy guard makes the second call a no-op. You only need one `await` per activation. |
| Targeting handlers that return null | If `Globals.enemy_manager.get_alive_enemies()` returns empty, DealDamageHandler's `if context.targets.is_empty(): return` guard prevents a crash. |
