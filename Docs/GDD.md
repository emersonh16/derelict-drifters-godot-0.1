# Derelict Drifters – Project State

## Engine & Version

* Godot 4.5.1
* 2D project using **fake isometric** (visual skew, not true iso math)

## High-Level Vision

Derelict Drifters is a roguelike exploration game about piloting a **walking tank / mobile refuge** (a drifter) through a world consumed by miasma.

Core vibes:

* Moebius-inspired
* Chunky, readable silhouettes
* Fog, light, and information are core mechanics

## Current Core Rules (Locked In)

* World logic stays **normal 2D**
* Isometric look is achieved via **sprite scale and offsets**, not coordinate transforms
* Y-sorting is used for depth against walls
* Visual systems come before gameplay systems

## Scene / Node Structure (Current)

```
World
 ├─ Ground (TileMapLayer)
 ├─ Walls  (TileMapLayer, Y-sorted)
 ├─ Player (CharacterBody2D)
 │   ├─ Sprite2D
 │   ├─ Beam (Node2D)
 │   │   ├─ Polygon2D (cone)
 │   │   └─ Circle (Node2D using _draw for light source)
 │   └─ Camera2D
 └─ Miasma
     └─ MiasmaTiles (TileMapLayer)
```

## Player

* Sprite size target: **64×64**
* Visual mass ~48×48
* Sprite offset upward (~-16 to -20 Y) to avoid ground clipping
* Movement:

  * WASD + Arrow keys
  * Diagonals allowed

## Camera

* Camera2D locked to Player
* No smoothing yet

## Beam System (In Progress)

**Purpose:** Light / fog interaction, not primarily a weapon.

Current state:

* Beam rotates toward mouse
* Rotation pivot correctly set at cone tip (0,0)
* Cone drawn with Polygon2D
* Circular light source drawn via `_draw()` using `draw_circle()`
* Isometric illusion via vertical scale (Y ≈ 0.5)

Planned:

* Beam size / focus adjustable via mouse wheel
* Cone morphs smoothly (wide → narrow → laser)
* Alpha / falloff by distance

## Miasma System (Planned, Not Implemented Yet)

* Separate **high-resolution grid** (smaller than ground tiles)
* Visual overlay, not terrain
* Cleared only by beam
* Regrows over time using probabilistic rules
* Exists primarily around camera/player, not infinite map

## Important Design Constraints

* Short, incremental steps
* Prefer visual feedback before rules
* Avoid premature abstraction
* One behavior at a time

## AI Collaboration Rules

* Short answers preferred
* Step-by-step Godot guidance
* No refactors unless explicitly requested
* Teach Godot concepts as we go

## What Is Working Right Now

* Player movement
* Camera follow
* Y-sorting against walls
* Beam rotation with correct pivot

## What Is Explicitly Shelved

* Miasma gameplay rules
* Collisions
* Combat/damage
* Optimization

---

Last updated: early Godot beam prototype phase
