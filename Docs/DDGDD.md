---

# **DERELICT DRIFTERS — ARCHITECTURE (FIELD MANUAL)**

## **PURPOSE & SCOPE**

This document defines the **architectural invariants and system boundaries** for the current Godot build of *Derelict Drifters*.  
Its goal is to preserve **60 FPS**, **clarity**, and **extensibility** while the game grows.

This is **not** a feature list or implementation guide.  
It describes *what must remain true*, even as code changes.

Primary audience:

* The project author  
* AI collaborators assisting with coding and refactors

---

## **0\. LAW SECTION (NON-NEGOTIABLES)**

These are constraints, not preferences.

* **60 FPS is mandatory**  
  Any system that cannot guarantee this must degrade gracefully or be capped.  
* **Single source of gameplay truth**  
  No duplicated state. No “visual truth.” No shadow copies.  
* **Isometric space is visual only**  
  Gameplay never reasons in iso space. Iso math is one-way.  
* **No nested loops in hot paths**  
  Especially not frame × tile × effect.  
  If work scales with world size, it is wrong.  
* **Work is queued, capped, and amortized**  
  Expensive logic is spread across frames under strict budgets.  
* **Immediate feel beats immediate truth**  
  Visuals may lead gameplay by a few frames if needed.

If a future change violates one of these, the change is wrong—even if it “works.”

---

## **STRUCTURE MAP — CURRENT GODOT BUILD (AUTHORITATIVE)**

### **World Root**

**`world.tscn`** — *Frame owner & composition root*

Owns:

* Update order  
* Scene graph  
* System references

Contains:

* Ground TileMapLayer (64×32)  
* Miasma TileMapLayer (16×8)  
* Player  
* Beam nodes  
* Camera

Rules:

* No gameplay logic  
* No iso math  
* Orchestration only

---

### **Player**

**`player-movement.gd`** — *Input → intent*

Owns:

* Movement input  
* Focus  
* Aim direction (top-down)

Does not:

* Clear miasma  
* Know about iso  
* Mutate world state

Outputs:

* Beam intent (direction, strength, mode)

---

### **Beam System (Intent \+ Visuals)**

* **`beambubble.gd`** — Bubble intent \+ visual  
* **`beamcone.gd`** — Cone intent \+ visual  
* **`beamlaser.gd`** — Laser intent \+ visual

Shared rules:

* Operate in top-down space  
* Generate clear requests  
* May draw immediately  
* Never mutate miasma directly

They describe **what should be cleared**, not **how much work happens**.

---

### **Miasma System**

**`miasma.gd`** — *Single source of truth*

Owns:

* Binary fog state  
* Cleared tiles  
* Frontier / regrow logic  
* Per-frame budgets  
* Clear / regrow queues

Does not:

* Know about beams  
* Know about iso  
* Care how visuals look

Accepts:

* World-space clear requests

Outputs:

* Logical fog state  
* TileMapLayer updates (projection only)

---

### **Rendering / Iso**

*(Utility layer)* — *Projection only*

Rules:

* Top-down → iso conversion  
* Draw-time only  
* Stateless

No system may:

* Query iso for logic  
* Store iso positions as truth

---

## **DATA FLOW (ONE GLANCE)**

Input  
 → Player (intent)  
 → Beam (requests)  
 → Miasma (truth \+ budgets)  
 → TileMapLayer (projection)  
 → Iso draw

---

## **1\. AUTHORITATIVE SPACES**

* **Gameplay Space (Truth)**  
  Top-down world space.  
  All decisions happen here.  
* **Miasma Space**  
  16×8 tile coordinates.  
  Binary fog / clear state.  
* **Visual Space**  
  Isometric projection (64×32 ground).  
  Rendering only.

Rule: **Gameplay → Miasma → Visual. Never reversed.**

---

## **2\. SOURCE OF TRUTH**

* Miasma has **one logical model**  
* TileMapLayer is **not** the truth  
* If a tile is clear, it must be clear in the model first

TileMapLayers are expensive and unsuitable as logic brains.  
Treating them as truth causes desync and frame drops.

---

## **3\. FRAME LIFECYCLE**

1. **Input & Intent**  
   Player input, beam mode, light requests  
2. **Gameplay Logic (Top-Down)**  
   Movement, aim math  
   No iso math allowed  
3. **Miasma Ops (Budgeted)**  
   Process queued clear / regrow  
   Enforce per-frame caps  
4. **Visual Projection**  
   Convert to iso  
   Prepare draw data  
5. **Draw**  
   Ground → miasma → beam visuals

Visuals may lead logic slightly.  
This is intentional.

---

## **4\. MIASMA SYSTEM CONTRACT**

* Binary fog state  
* Frontier-based regrowth  
* No full-grid scans  
* All work spatially bounded and capped

Invariant: **Miasma cost per frame is bounded, regardless of world size.**

---

## **5\. BEAM → MIASMA INTERFACE**

* Beams **request**, never mutate  
* Requests are world-space shapes  
* Miasma decides how much work happens

This keeps beams responsive and enables future light sources.

---

## **6\. PERFORMANCE BUDGETING**

* Fixed per-frame caps  
* Queued work  
* Excess rolls over  
* Budgets scale with viewport, not world

Visual smoothness may mask logical delay.

---

## **7\. ISOMETRIC RULES**

* Iso is visual only  
* One-way transform  
* Applied late

If iso affects gameplay, architecture has failed.

---

## **8\. GLOBALS POLICY**

Allowed:

* Pure math helpers  
* Constants  
* Stateless utilities

Forbidden:

* Mutable gameplay state  
* Miasma truth  
* Player state

Globals may simplify, not decide.

---

## **9\. EXTENSION GUARANTEES**

Guaranteed support:

* Multiple light sources  
* New beam shapes  
* Visual upgrades  
* Larger worlds

Guaranteed preservation:

* 60 FPS  
* Single source of truth  
* Budgeted workload

---

## **10\. FAILURE MODES**

* FPS dips → budget violation  
* Beam misalignment → space contamination  
* Jittery clearing → queue starvation  
* Logic ≠ visuals → iso leak

---

# **AI COLLABORATION RULES (ONBOARDING SUMMARY)**

**For AI assisting on this project:**

* Treat this document as authoritative.  
* Never introduce:  
  * duplicate gameplay state  
  * iso-space logic  
  * unbounded loops  
* Prefer:  
  * queues  
  * budgets  
  * small, local changes  
* When unsure:  
  * ask before refactoring  
  * do not “clean up” architecture  
* Code changes should:  
  * respect the Structure Map  
  * modify one system at a time  
  * preserve intent → truth → projection flow

If a suggestion violates the Law Section, discard it.

---

