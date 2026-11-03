# Project Lumina — Avatar Framework Architecture
## Lumina Avatar Compatibility Specification (LACS), v0.1 — Working Draft

**Status:** Architecture working draft; design decisions and proposed implementation details are explicitly distinguished below.  
**Date:** November 3, 2026  
**Project:** Project Lumina  
**Target engine:** Godot 4.x (final supported minor version to be selected during prototype validation)  
**Purpose:** Establish a durable, modular technical foundation for Lumina's player-facing avatar customization system.

> **North star:** Build a sophisticated, intuitive, Godot-native avatar framework that lets players create individualized characters without needing technical knowledge. Standardize character compatibility and data contracts early, while retaining freedom to revise unproven implementation choices after prototypes.

---

## 1. Executive Summary

Lumina will implement its own avatar framework rather than tightly coupling character customization to player movement, multiplayer logic, or a third-party hosted avatar service. The framework is a **foundational subsystem** of Lumina, designed to be sufficiently modular that it could be reused in unrelated Godot projects later. External distribution or monetization is **not a development objective of this specification**.

The framework will construct and customize characters from standardized, compatible assets: a reference skeleton, skinned body meshes, morph targets, hairstyles, clothing, accessories, and materials. Player appearance will be represented by versioned data, not solely by a baked 3D file.

**Crucial confirmed constraint:** Avatar customization will **not offer skeletal-proportion controls**. For the initial humanoid family, height, limb lengths, torso length, skeletal hierarchy, and bone rest proportions are fixed. Player-facing body and facial controls operate on **surface geometry (blend shapes / morph targets)** and material or equipment choices. Skeletal animation continues to operate on the consistent reference rig.

The highest-risk technical area is compatible clothing deformation across changing body contours. We will validate body-and-garment morphs before building a large wardrobe or polishing the avatar UI.

---

## 2. Decision Register

### 2.1 Confirmed project decisions

| ID | Decision | Implication |
|---|---|---|
| D-01 | **Godot is Lumina's chosen engine**, barring a major blocker. | Target Godot-native scenes, resources, animation, scripting, and editor tools. |
| D-02 | The avatar framework is a **modular foundational subsystem**. | No hard dependency on Lumina's networking, account service, or movement controller. |
| D-03 | Players will **not change skeleton or proportions**: height, limb lengths, torso length, and analogous skeletal values remain fixed. | Do not provide bone-length or skeletal-scaling UI. Use morph targets for allowed visual changes. |
| D-04 | Character creation must be **player-facing and visually intuitive**. | Players never need scripts, modeling tools, or technical configuration. |
| D-05 | A single, consistent reference skeleton is the initial humanoid compatibility target. | Establish shared rigging and animations for the initial character family. |
| D-06 | **Direct WASD avatar movement** is mandatory for Lumina. | Gameplay movement stays outside the avatar framework but must work with its animation interface. |
| D-07 | MakeHuman/MPFB is an **initial asset-pipeline candidate**, not a mandatory runtime dependency. | Use Blender to prepare compatible assets; validate export behavior before adoption. |
| D-08 | Configura is a **reference/prototype candidate**, not a committed core dependency. | Study its editor, UI generation, mesh swapping, morph control, and state model. |
| D-09 | Design for independent operation without a hosted third-party avatar API. | Runtime generation/customization should work with our own assets and tools. |
| D-10 | Potential future SDK reuse is desirable, but **commercialization is out of scope** for present decisions. | Keep stable boundaries without delaying Lumina to create a general-purpose commercial product. |

### 2.2 Proposals awaiting prototype validation

- Use a **T-pose canonical reference rig** if it maps cleanly to Godot's humanoid retargeting workflow. Validate against an A-pose alternative before freezing the rest pose.
- Start with **one humanoid body family** and one fixed reference height. Other families or fixed-size character classes are a future design decision, not implied by initial support.
- Use **blend shapes** for player-visible facial and body-contour customization; avoid runtime bone-proportion modification.
- Prepare matched body/garment morphs **offline**, with skinning to the same skeleton.
- Prefer **GLB/glTF** as the asset exchange format between Blender and Godot, subject to validation of shape keys, skeletons, normals, materials, and animations.
- Represent saved appearance using stable IDs and a **versioned, portable record**, with JSON for an initial interchange format.
- Treat real-time simulated clothing and hair as optional future enhancements, not baseline requirements.

**Status terminology:** _Confirmed_ = a user-approved product constraint. _Proposed_ = a chosen working hypothesis. _Unverified_ = must be demonstrated in a test project.

---

## 3. Architecture Principles

1. **Separate definition, appearance, and instance.** An avatar definition states what can exist; appearance state describes player choices; an avatar instance is the live skinned and animated scene.
2. **Fixed-proportion humanoid rig.** Geometry may change within approved ranges; required skeletal geometry, proportions, hierarchy, and reference height do not change from player-facing customization.
3. **Data-driven assets.** New approved hairstyles, clothes, and materials should be registerable without changing the core runtime logic.
4. **Replaceable UI.** Customization controls are generated from schemas or use a stable core API, so the visual editor can evolve without invalidating saved characters.
5. **Offline preparation, efficient runtime.** Do computationally expensive fitting and authoring in Blender/tools where practical; keep live avatar assembly predictable.
6. **Network independence.** The avatar framework neither owns player movement nor requires a particular account or multiplayer backend.
7. **Compatibility by contract.** A validator, not artist guesswork, determines whether a new asset matches the approved rig, slot, and morph standards.
8. **Version for continuity.** Appearance records and asset definitions need stable identifiers and explicit migration rules.
9. **Accessible creator UX.** Complexity belongs in the content pipeline and framework, not in a player's character-creation experience.
10. **Test before freezing.** Document the intended standard early; only freeze the parts shown to work under representative deformation, animation, and performance tests.

---

## 4. Proposed Framework Boundary

```text
Lumina game layer (external)
  Account service / inventory / multiplayer / world logic / WASD movement
                              |
                   narrow documented API
                              |
Lumina Avatar Framework (Godot addon)
  Avatar factory and live instance controller
  Appearance state and serialization
  Body and facial morph controller
  Equipment / clothing / accessories / material controller
  Animation-facing skeleton and expression interfaces
  Avatar creator UI (replaceable)
  Asset registry and compatibility validation
                              |
Approved asset library
  Reference rig + base meshes + prepared garments + hair + materials
                              ^
                   offline authoring/import
                              |
               Blender / MPFB / optional tools
```

### 4.1 Primary components

**AvatarDefinition:** Identifies body family, rig version, supported morphs, clothing slots, material parameters, permissible ranges, and defaults.

**AvatarAppearance:** Contains only the player's choices: selected morph weights, material/color values, equipped asset IDs, and schema/definition versions.

**AvatarFactory:** Creates a valid live avatar from a definition and an appearance record.

**AvatarInstance:** Applies appearance to a live Godot scene and exposes a stable animation-friendly character object.

**MorphController:** Applies approved blend shapes, including any corrective shapes needed for combinations. Facial identity controls are distinct from expression/viseme controls.

**EquipmentController:** Swaps compatible skinned clothing, hair, and rigid attachments; tracks compatibility, garment layers, and body region coverage.

**AssetRegistry:** Resolves stable IDs to approved, versioned assets and their metadata. Does not trust arbitrary client-provided file paths.

**AppearanceSerializer:** Validates, saves, loads, and migrates portable appearance data.

**CreatorUI:** A player-facing editable presentation of supported choices. It must not own the canonical appearance or geometry implementation.

**Animation interface:** Makes the standard skeleton and expression channels accessible to Lumina's external locomotion, gesture, and interaction animation systems.

### 4.2 Conceptual appearance record

```json
{
  "schema_version": 1,
  "avatar_definition": "lumina_human_v1",
  "rig_id": "lumina_humanoid_v1",
  "morphs": {
    "body_fullness": 0.45,
    "muscularity": 0.65,
    "waist_width": 0.42,
    "jaw_width": 0.37
  },
  "materials": {
    "skin_tone": "#B87953",
    "hair_color": "#38291F"
  },
  "equipment": {
    "hair": "hair_012",
    "top": "shirt_004",
    "bottom": "trousers_009"
  }
}
```

This is a **proposed Lumina format**, not Ready Player Me's or Configura's native format. Only allow-listed asset IDs, recognized morph keys, and bounded values are accepted. Stored state must not depend on transient Godot node paths, editor array indices, or nonportable resource file paths.

---

## 5. LACS: Reference Skeleton and Rig Standard

### 5.1 Fixed structural contract

For the initial humanoid family, define and preserve:

- One reference skeleton asset with **known bone names, parent hierarchy, rest transforms, local axes, scale, and origin**.
- One canonical reference pose (to be verified: T-pose vs A-pose).
- **Fixed avatar height and bone lengths** for that family; no player controls for height, limb length, torso length, or analogous skeletal dimensions.
- Required locomotion and upper-body bones; a documented policy for optional accessory, hair, or facial bones.
- Standardized attachment locations for glasses, hats, jewelry, and held objects.
- Deterministic collision/body envelope definitions and camera framing for the supported character family.

**Fixed skeleton does not mean fixed surface silhouette.** Muscularity, body fullness, waist/hip contour, chest contour, facial shape, and other approved geometry changes may still be exposed if they do not alter skeletal length/proportion. Body shape limits must also account for joint bending and clothing fit.

Godot's `Skeleton3D` and humanoid retargeting facilities provide the technical basis. We must verify actual bone orientations and rest-pose matching, not only names.

### 5.2 Canonical skeleton artifact

Maintain a reference Blender file and a Godot-imported GLB test asset. Publish a rig manifest that records required bones, hierarchy, rest pose, coordinate system, units, root transform, attachment sockets, permitted optional bones, and compatibility version.

**Exit test:** At least two visibly different surface appearances, on the same reference skeleton, can share idle, walk, run, sit, and dance animation clips without per-avatar authored animation sets or unacceptable distortion.

---

## 6. LACS: Body and Facial Morphing

### 6.1 Runtime method

Prefer Godot `MeshInstance3D` blend shapes for approved player-visible body and face changes. Prepare shape keys in Blender/MPFB or another compatible authoring pipeline; import and validate their names and ranges.

Potential first body controls: body fullness, muscularity, shoulder contour, chest contour, waist contour, hips, arm/leg muscle definition. None may change bone length or character height.

Potential first face controls: jaw width, chin, cheeks, brow, eye shape, nose proportions, lips, and other surface geometry. Identity shapes should not conflict with expression shapes.

A **curated set** of morphs is preferable to exposing all MakeHuman modeling targets. The exact list and permissible ranges remain open pending extreme-combination and garment-fitting tests.

### 6.2 Constraints and compatibility

- A shared base mesh topology is needed wherever one set of morph deltas is expected to work.
- Every required morph key must have stable meaning across the supported body family and compliant garments.
- Facial identity, facial expression, and speech/viseme controls use separate logical channels.
- Individual morphs and **combinations of extreme values** must be tested at rest and during motion.
- Corrective morphs may be needed for combinations or high-bend poses; do not assume simple linear blending handles every case.
- Bounds, combinations, and interaction rules belong in `AvatarDefinition`, not hardcoded per UI screen.

**Exit test:** Dozens of generated appearances, including boundary combinations, retain intact surfaces, stable shading, working facial animation, and usable shared skeletal animations.

---

## 7. LACS: Clothing, Hair, and Accessories

### 7.1 Garment contract

Every skinned garment must declare:

- Compatible avatar body family, rig/skin binding, and skeleton version.
- Clothing slot (e.g., top, bottom, outerwear, footwear), optional layer, and compatibility exclusions.
- Matching body-contour morphs or a documented narrower supported shape range.
- Coverage metadata describing underlying body regions that should be hidden.
- Material controls, LOD variants, texture requirements, and ownership of surfaces.
- Stable asset ID and version.

Rigid accessories can attach to fixed sockets. Hair may be implemented initially as selected mesh scenes, with any secondary animation or physics deferred.

### 7.2 Preferred fitting approach

**Proposed:** use MPFB/MakeHuman-style garment fitting during authoring to produce matched garment morphs offline. Godot then applies the body and clothing morph weights together at runtime. This avoids requiring a general-purpose runtime auto-fitting solver in the MVP.

MPFB's MHCLO fitting data is worth evaluating, but **it has not been proven** that its output automatically translates into clean, reusable Godot garment blend shapes. Treat this as the first major technical experiment.

Potential strategies if the prototype fails: (a) generate more careful garment-specific corrective morphs; (b) constrain the supported body-morph range; (c) use limited prepared garment variants; (d) investigate a more sophisticated fitting tool only if needed.

### 7.3 Clothing acceptance matrix

Test a fitted T-shirt, trousers, and a loose jacket across: default and boundary body shapes; simultaneous changes to chest/waist/hips/fullness/muscularity; idle/walk/run/sit/dance; garment layering; transitions between worn items.

Pass criteria are visually acceptable skin contact, limited clipping, no obvious floating or twisting, consistent animation skinning, and no missing body coverage after equip/unequip.

**Do not build a large wardrobe until this pipeline passes.**

---

## 8. Animation and Interaction Architecture

### 8.1 Separate responsibilities

- **Lumina's movement controller:** handles WASD input, physics, camera movement, networking/authoritative movement, and world position.
- **Avatar animation controller:** consumes states or commands from gameplay and performs idle, walk, run, gesture, sit, dance, expression, and synchronized-interaction playback.
- **Avatar visual instance:** renders the skeleton, morphs, garments, materials, and accessories.

This separation allows the visual framework to function in unrelated Godot projects without inheriting Lumina-specific movement or networking behavior.

For initial implementation, prefer **in-place locomotion** controlled by the external WASD controller, subject to testing. Use Godot `AnimationTree` and other built-in animation facilities for blending; additive/layered expression and gestures may be phased in.

### 8.2 Fixed skeleton benefits and limitations

Fixing height and limb lengths reduces animation retargeting variation, collision differences, and multi-avatar alignment problems. It **does not entirely eliminate** potential mesh distortion, joint weighting problems, garment clipping, or pose-specific interaction offsets. We still need technical tests.

If proportional rig changes are ever supported for a different future avatar family, that would require a new explicit compatibility proposal—not an accidental feature added through morphology UI.

**Exit test:** Shared locomotion and gestures work across approved appearances; walking-to-sitting transitions remain stable; two avatars can perform a representative synchronized interaction with acceptable alignment.

---

## 9. Authoring and Import Pipeline

### 9.1 Initial candidate pipeline

1. Create the reference human and candidate rig in **MakeHuman/MPFB + Blender**.
2. Validate and, if needed, adapt the rig to Lumina's canonical rest pose.
3. Select and produce a compact list of runtime body and facial morphs.
4. Produce a small test wardrobe and corresponding garment morphs.
5. Set up materials, sockets, region-coverage metadata, and asset IDs.
6. Export to **GLB/glTF**, preserving required skinning and shape keys.
7. Import into **Godot**; run structural and visual validation.
8. Package compliant character assets separately from the core addon.

Use MPFB as an authoring dependency only. The runtime should not need Python, Blender, MakeHuman, an external generator, or a hosted API.

### 9.2 Configura evaluation

Use Configura's MIT-licensed Godot implementation as a **prototype/reference** for generating UI from character options, swapping meshes, applying blend shapes, changing colors, and managing `CharacterState`. Test it with our own character assets. Reuse or fork only after validating the maintainability and fit with our stable data/asset contracts.

Do **not** make Configura's native `.tres` save format the permanent, portable record.

### 9.3 License and provenance controls

MakeHuman's **core graphical assets** are generally CC0; program source and third-party downloaded content can have **different** licenses. MPFB tool code is not automatically the license of its exported assets. Configura's source includes an MIT license. Record license, author, source, version, and redistribution permissions for every included asset and tool-derived component. Review individual clothing/hair packs before bundling them.

---

## 10. Persistence, Networking, and Independence

- Save portable, versioned avatar appearance data and stable asset IDs.
- Keep mutable identity, ownership, permissions, and account profile outside the framework core.
- A server can validate allow-listed assets, unlocks, and morph bounds before accepting authoritative appearance changes.
- Multiplayer clients can reconstruct avatars from shared appearance records and locally cached approved assets; movements and animations are synchronized separately.
- When an asset is unavailable or obsolete, apply predictable fallback/default behavior and explicit schema migrations.
- Do not require third-party avatar hosting or player-authored scripts to generate or view an avatar.

A standalone framework should run inside a blank Godot project with sample assets and local persistence; Lumina's multiplayer integration is an optional adapter.

---

## 11. Performance Strategy

The avatar creator may use a high-quality close-up model; crowded venues need scalable representations. Build profiling in from the start rather than inventing triangle or draw-call budgets in advance.

Areas to measure:

- GPU and CPU frame time at **10, 25, and 50** visible customized avatars.
- Skinned mesh count, material and draw-call count, morph processing, animation cost.
- Memory and texture use across unique outfits and faces.
- Avatar load time, state-apply latency, asset-cache effectiveness.
- LOD behavior at camera distance and with many unique cosmetic combinations.

Candidate optimization techniques: mesh/texture LOD, selected material sharing, texture atlases where useful, body-region masking, limiting material transparency, reduced distant facial animation frequency, caching, and merging compatible meshes when performance evidence supports it.

**Performance pass criteria must be established against target Lumina hardware and scenes**, not assumed from a generic Godot benchmark.

---

## 12. Implementation Phases and Gates

### Phase 0 — Specification and validation harness
**Deliver:** LACS v0.1 draft, repository layout, asset manifest format, test scenes, baseline profiling procedure.  
**Gate:** Test conditions and supported/unverified assumptions are documented.

### Phase 1 — Canonical reference avatar
**Deliver:** One Blender reference rig, one imported Godot character, basic shared idle/walk/run/sit/dance, external WASD demonstration.  
**Gate:** Rig/rest-pose compatibility is stable; skeleton proportions remain fixed.

### Phase 2 — Morph and clothing proof of concept
**Deliver:** Several independent body/face morphs; three garments (fitted shirt, trousers, jacket); matched garment behavior across extreme morph combinations and animations.  
**Gate:** No unacceptable clipping, tearing, detachment, or animation breakage in the agreed test matrix. If this fails, revise the fitting strategy before expanding assets.

### Phase 3 — Modular runtime
**Deliver:** Data-driven definitions, asset registry, factory, morph/equipment controllers, appearance schema, local save/load, and a second independently prepared compatible asset.  
**Gate:** Identical appearance reconstructs from state, and the addon operates independently of Lumina game logic.

### Phase 4 — Player-facing creator
**Deliver:** Character preview, camera orbit/zoom, body/face sliders, colors, wardrobe, reset/randomize/presets, clear UX states.  
**Gate:** A nontechnical player can successfully create, save, and restore a distinctive avatar without needing instructions about technical 3D concepts.

### Phase 5 — Lumina integration and performance
**Deliver:** Spawn/reconstruct path, inventory/auth validation adapter, multiplayer appearance synchronization, benchmark scenes, asset validation and compatibility tests.  
**Gate:** Customized characters render and animate consistently for multiple players within measured performance budgets.

Each phase should reduce an identifiable risk. The intention is **not** to develop a generalized paid SDK before Lumina's needs are met.

---

## 13. Acceptance Tests and Definition of Done

| Area | Demonstration required |
|---|---|
| Fixed skeleton | No player setting changes rig height, bone length, or skeletal hierarchy. |
| Animation compatibility | Multiple distinct appearance morphs use the shared clips successfully. |
| Face vs expression | Identity morphs coexist with facial expressions and later visemes without corrupting one another. |
| Clothing | Selected garments track approved body-contour morphs in motion and preserve acceptable appearance. |
| Equipment | Swap/unequip hair, clothing, and accessories without stale geometry or broken materials. |
| Data portability | Save a versioned appearance record, close/restart, and reconstruct the same visible character. |
| Modularity | Instantiate the addon with sample assets in a new Godot project without Lumina dependencies. |
| Asset validation | Detect incompatible rig, unsupported morph, bad slot metadata, or version mismatch before use. |
| Multiplayer | A second client receives appearance data and reconstructs the authorized same character. |
| Performance | Representative 10/25/50-character scenarios meet explicitly recorded target-device budgets. |

Automate structural checks where possible; keep a visual regression set for morph extremes, clothing layers, and animated poses.

---

## 14. Key Risks and Mitigations

| Risk | Why it matters | Proposed mitigation |
|---|---|---|
| Garment/body morph mismatch | Clothing clips, floats, or tears at shape extremes. | Prove offline fitting + shared runtime morphs with a three-garment test before scaling wardrobe. |
| Incorrect canonical rig | Rework spreads to animation, clothing, and interactions. | Freeze rig only after retargeting and movement/interaction acceptance tests. |
| Uncontrolled morph combinations | Distorted geometry and materials. | Curate morph ranges, test boundary combinations, add corrective morphs or constraints. |
| Asset pipeline dependency | Missing or unusable exports prevent runtime customization. | Validate Blender → GLB → Godot morph and skeleton fidelity immediately. |
| Coupling to Configura or MPFB | Tool changes block the core system. | Maintain our own appearance schema and compatibility specification. |
| Performance at scale | Crowded social venues become unplayable. | Early multi-character benchmarks; LOD/caching strategy. |
| Stored-state drift | Patches cause saved avatars to look wrong or break. | Versioned schema, stable IDs, migration and fallback tests. |
| Licensing/provenance | Asset redistribution or code reuse may be restricted. | Record provenance; distinguish CC0 assets from GPL/AGPL tools and third-party packs. |

---

## 15. Open Questions / Research Backlog

These remain **undecided** and must be answered experimentally or by an explicit product decision:

1. Which exact MPFB rig, or adapted rig, is best aligned to Godot's humanoid retargeting profile?
2. Should the canonical rest pose be T-pose or A-pose after importing and testing representative animations?
3. What is the initial set of player-visible body and facial morphs, and which combinations are permitted?
4. Can MPFB's fitting data reliably generate matched garment shape keys for reusable runtime use? What custom Blender tooling would be required?
5. How should garment layering and underlying-body coverage work (hide masks, body-region removal, or another approach)?
6. Which facial expressions or viseme standards should be supported initially versus later?
7. Which editor responsibilities belong in a plugin versus an offline asset-preparation tool?
8. Will Configura's architecture save time in practice, or be easier to treat as reference material?
9. What rig, mesh, material, texture, and LOD budgets are realistic for Lumina's target hardware?
10. What is the precise schema migration policy if we evolve rigs, morph lists, or asset IDs?
11. How much validation can be automated during Godot import or Blender export?
12. How do we separate the first humanoid family from future distinct, fixed-proportion avatar families without implying that players can alter skeleton proportions?

---

## 16. Immediate Next Actions

1. Create a clean **avatar technical prototype** independent of the live Lumina game.
2. Select and document a provisional MPFB reference character and rig.
3. Import that character into Godot and verify skeletal animation, rest pose, and a handful of shape keys.
4. Prepare one skinned shirt and attempt matched body+garment morphs.
5. Add trousers and a jacket; run shape-extreme and animation tests.
6. Update this specification based on results, then implement the reusable runtime modules.

**First irreversible-decision rule:** Do not freeze the skeleton, morph catalog, or clothing interchange format merely because they work on one unanimated default character. Freeze only when the same foundation survives the agreed compatibility tests.

---

## 17. Reference Resources

These are sources/technologies to evaluate; listing them is not a commitment to use their code or APIs.

- [Godot documentation — importing 3D scenes](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/)
- [Godot documentation — skeletal animation and retargeting](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html)
- [Godot documentation — EditorPlugin](https://docs.godotengine.org/en/stable/classes/class_editorplugin.html)
- [MakeHuman Community](https://www.makehumancommunity.org/)
- [MPFB documentation](https://www.makehumancommunity.org/mpfb/docs/index.html)
- [MPFB export copy and morph options](https://static.makehumancommunity.org/mpfb/docs/exporting/export_copy.html)
- [Configura (Godot character creator framework)](https://github.com/Team-Figoose/Configura)

**Research status:** Architecture synthesis and source review; a combined MPFB → Godot → Configura prototype has **not** yet been run. Performance and garment fit remain unverified until tested.

---

*Document owner: Project Lumina. Proposed filename: `Avatar-Framework-Architecture-LACS-v0.1.md`. This working draft should be revised after each prototype gate, keeping confirmed decisions separate from testable hypotheses.*
