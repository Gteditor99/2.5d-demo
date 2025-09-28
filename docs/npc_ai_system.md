# NPC Data & Enemy AI System

This document summarizes how the reusable NPC data resources, sprite assets, and enemy AI behaviors fit together. It explains how to extend the current setup with new enemy variants while keeping the logic easy to maintain.

## Overview

Enemies are authored through **`NPCData` resources** that bundle visuals, gameplay stats, and AI configuration in a single asset (`res://scripts/resources/NPC/npc_data.gd`). Each instance can describe a different variant of the same base enemy, allowing designers to reuse sprite sheets while tweaking gameplay.

At runtime the `EnemyAIController` (`res://scripts/components/ai/enemy_ai_controller.gd`) consumes the assigned NPC data to:

1. Instantiate a dedicated `EnemyAIBehavior` resource for the enemy.
2. Drive state transitions (Idle → Chase → Attack → Dead).
3. Forward animation hints (idle / walk / attack / hurt / death) to the enemy scene script.

The default behavior is `ChaseAttackAIBehavior` (`res://scripts/components/ai/chase_attack_ai_behavior.gd`), a simple chase-and-strike loop tuned via exported properties.

## Authoring NPCData resources

Key exported fields inside `NPCData`:

- **Identity** – `npc_type` (e.g. `"jy"`) plus `variant` (e.g. `"elite"`). The combination forms a unique identity key.
- **Visuals** – A `SpriteFrames` resource plus animation name overrides per AI state. Missing overrides fall back to `default_animation`.
- **Stats** – Core gameplay numbers (`max_health`, `move_speed`, `acceleration`, `friction`, `attack_damage`, `experience_reward`). Enemy scripts read these to configure health, movement, and rewards.
- **Behavior** – An `EnemyAIBehavior` resource reference and optional `behavior_overrides` dictionary for per-variant tweaks (e.g. increase `attack_range` for elites).
- **Metadata** – Optional tags and loot-table identifiers for downstream systems.

Example assets live in `res://resources/npcs/enemies/`:

- `jy_sprite_frames.tres` contains the shared animation frames.
- `jy_grunt.tres` and `jy_elite.tres` reuse those frames but override stats and AI properties to differentiate variants.

### Creating a new variant

1. Duplicate an existing `NPCData` resource or create a new one via **Inspector → Resource → New Resource → NPCData**.
2. Assign the shared `SpriteFrames` resource (or create a new one if the visuals differ).
3. Fill out stats, loot, and animation names as needed.
4. Reference an `EnemyAIBehavior` resource. Use `ChaseAttackAIBehavior` today, but any custom resource extending `EnemyAIBehavior` is supported.
5. Use the `behavior_overrides` dictionary for quick per-variant tuning. Key names must match exported properties on the behavior (e.g. `{ "detection_range": 18.0, "attack_cooldown": 0.9 }`).
6. Point the enemy scene or spawner script to the new NPC data asset.

## EnemyAIBehavior lifecycle

Behaviors extend `EnemyAIBehavior` and interact with `EnemyAIController` through three entry points:

| Method | Responsibility |
| --- | --- |
| `setup(controller)` | Initialize timers and choose the starting state. Called when the behavior resource is applied. |
| `physics_update(controller, delta)` | Execute per-frame logic. Query helpers such as `distance_to_player()`, `move_towards_player()`, and `request_attack()`. |
| `on_state_changed(controller, previous_state, new_state)` | React to transitions (e.g. reset cooldowns when returning to chase). |

Because `NPCData.instantiate_behavior()` duplicates the resource before applying overrides, each enemy receives an isolated behavior instance. This avoids shared state between enemies while letting designers reuse a single base resource.

## Best practices

- Keep behavior properties general-purpose (ranges, cooldowns, booleans) so variants only need to adjust values.
- Add new states or abilities inside bespoke behavior resources rather than hard-coding logic in the enemy scene.
- Prefer naming variants with `npc_type:variant` (`"jy:elite"`) to simplify lookup in spawner tables.
- When adding new animations, update the `SpriteFrames` resource first, then reference the names within NPC data.

This modular layout ensures new enemy types can be introduced by authoring data, not editing scripts, keeping AI maintenance straightforward even as the roster grows.
