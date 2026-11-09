# Smooth arena size implementation plan

**Goal:** Operators resize the actual circular playing field smoothly from 100–200%, while magnet reach stays 9 studs.

**Architecture:** One validated server room transition stores scale and server timestamp atomically. A shared math module evaluates its eased scale. Server collision geometry and gameplay bounds use that scale; clients animate a visual-only arena model locally. Blocks keep canonical positions and expand with the field; captures freeze their starting position. Existing generated gear popup gains one compact size slider.

**Scope decisions:** Use the existing room operator permissions and session lifetime. The user's follow-up sets the default to150%, range100–200%, one-second cubic easing, coalesce requests. Uniform scaling keeps the circular stage and decorations coherent; collision and visual groups are separated to avoid replicating1200 moving decorative parts. Keep camera distance, block size, magnet size/reach, LIVE integration, sound and ring preferences intact. No publishing.

- [x] Add and run a failing pure Luau check for finite/clamp validation and continuous/reversible easing. Implement ArenaMath and repeat.
- [x] Back up the Studio arena, prepare visual/collision models with origin pivots, export the Edit-time setup script. Add server-authorized transitions and local scene animation. Wire fixed original-radius block coordinates and moving bounds through shared scale.
- [x] Add mouse/touch slider and reset in MagnetOptions; cancel tweens on drag, preserve final input, use existing popup sizing and permissions.
- [x] Compile/install, playtest minimum/maximum, mid-transition reversal, server validation, block containment, collision alignment, fixed magnet reach, toggles, mobile fit and frame times during resize. Run existing Node suite; request one source review. Fix substantive issues.
- [x] Record evidence, commit/push and sync source to VPS without restarting backend. Leave Studio ready to try.

Potential edge cases: active captures during scale reversal; frozen gameplay and settled blocks; shrinking while a player is on the edge; late join/pending visual creation; hidden popup during a touch drag. Validate these alongside gameplay checks.

Runtime ruling: contracting collision walls and server correction fought client-owned characters, especially with Studio background throttling. Use a broad supporting floor, disable wall contact during movement, carry/clamp edge players locally and retain a server bound based on the transition start until contraction settles. The outward-input review finding was reproduced and fixed; real held-D testing ended inside the final boundary. Full evidence is in README.
