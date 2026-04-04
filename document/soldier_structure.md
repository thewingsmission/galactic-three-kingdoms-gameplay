# Soldier object — design structure

This document describes the **intended hierarchy** for one deployable soldier unit: a **container transform** (position, rotation, scale) with grouped visuals for core body, contact, attack, detection, and hub.

---

## Hierarchy (tree)

Direct children of **Soldier container** are ordered **back-to-front** for display: **earlier** siblings are drawn **below** (behind); **later** siblings are drawn **above** (in front). Match this order in the engine when paint order follows the document.

```
Soldier container
├── Core body container
│   ├── Core body image component 1 (static or movable)
│   ├── Core body image component 2 (static or movable)
│   ├── …
│   ├── Core body image component N (static or movable)
│   └── Contact zone image
├── Attack body container
│   ├── Attack body image component 1 (static or movable)
│   │   ├── Attack particle effect (optional)
│   │   └── Attack zone image (optional)
│   ├── Attack body image component 2 (static or movable)
│   │   ├── Attack particle effect (optional)
│   │   └── Attack zone image (optional)
│   ├── …
│   └── Attack body image component N (static or movable)
│       ├── Attack particle effect (optional)
│       └── Attack zone image (optional)
├── Detection zone image
└── Center dot image
```

---

## Example: Gilded Bastion

Legendary design **Gilded Bastion** (`gilded_bastion_cat`) in the same hierarchy. Core numbering follows silhouette → face details → contact. **Attack** uses two components: the **underlay probe rod** (forward probe motion) and the **crown triangle** with optional **crown flames** and strike reach as children of the crown.

```
Soldier container
├── Core body container
│   ├── Core body image component 1 (static — tower upper hull)
│   ├── Core body image component 2 (static — tower base hull)
│   ├── Core body image component 3 (movable — left wing)
│   ├── Core body image component 4 (movable — right wing)
│   ├── Core body image component 5 (static — upper face octagon)
│   ├── Core body image component 6 (static — lower face octagon)
│   ├── Core body image component 7 (movable — left ear)
│   ├── Core body image component 8 (movable — right ear)
│   ├── Core body image component 9 (static — face stroke)
│   ├── Core body image component 10 (static — face stroke)
│   ├── Core body image component 11 (static — face stroke)
│   ├── Core body image component 12 (static — face stroke)
│   ├── Core body image component 13 (static — left eye)
│   ├── Core body image component 14 (static — right eye)
│   ├── Core body image component 15 (static — mouth fill)
│   ├── Core body image component 16 (static — mouth outline)
│   ├── Core body image component 17 (static — left side vertical)
│   ├── Core body image component 18 (static — right side vertical)
│   └── Contact zone image
├── Attack body container
│   ├── Attack body image component 1 (movable — underlay probe rod)
│   └── Attack body image component 2 (movable — crown triangle)
│       ├── Attack particle effect (optional — crown flames while probe active)
│       └── Attack zone image (optional — crown strike reach disk)
├── Detection zone image
└── Center dot image
```

---

## Node reference

### Soldier container

- **Role:** One deployable unit in the world.
- **Transform:** Position, rotation, and scale represent the soldier as a whole.
- **Convention:** Child nodes are authored in **local space** of this container. The container **origin** is the soldier anchor (e.g. cohort / physics attachment point).

### Core body container

- **Role:** Main silhouette and stable body presentation.
- **Children:**
  - **Core body image components (1…N):** Drawable layers (hull, limbs, details). Each may be **static** or **movable** (animation / procedural motion). Order **within** this container is also back-to-front unless overridden.
  - **Contact zone image:** Defines the **contact / collision footprint** (body contact with the world or other units). May be a visible outline or an **invisible** hull; either way it is the authoritative footprint for that container. Listed **after** the drawable core components in the tree.

### Attack body container

- **Role:** Strike and threat presentation, separable from the core so it can animate or toggle independently.
- **Children:**
  - **Attack body image components (1…N):** Drawable pieces (weapons, crown, etc.). Each may be **static** or **movable**.
  - **Per component (optional):**
    - **Attack particle effect:** VFX bound to that component.
    - **Attack zone image:** Visual for that component’s **strike reach** (arc, cone, disk, etc.).

### Detection zone image

- **Role:** Visual for **awareness / acquisition** range (typically larger than contact).
- **Placement:** Direct child of **Soldier container**, **after** core and attack containers, **before** center dot.

### Center dot image

- **Role:** Small **hub** marker for alignment (facing pivot, range ruler, UI / debug).
- **Placement:** **Last** direct child of **Soldier container** so it draws **on top** of core, attack, and detection when paint order matches this document.
- **Position:** Often at local `(0, 0)`; may be **offset** in model space per design (e.g. hub for range UI not at geometric centroid).

---

## Design intent (summary)

| Group | Question it answers |
|--------|---------------------|
| **Soldier container** | Where is the unit, how is it oriented, how is it scaled? |
| **Core body container** | What does the main body look like, and what is its contact footprint? |
| **Attack body container** | What appears or moves when threatening, with optional FX and per-part reach? |
| **Detection zone image** | How far can the unit notice targets? |
| **Center dot image** | Where is the exact anchor / hub on that transform (including optional offset)? |

---

## Scope

This file specifies **target structure** for authoring and engine integration. It does not fully describe the current Flutter / Flame implementation; the **Gilded Bastion** example maps the catalog design to this tree for authoring alignment.
