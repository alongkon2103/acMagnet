# Consistent toy block contact shadows

User reports some blocks have shadows and others lose them at far zoom. All checked blocks had CastShadow=true; Soft/PrioritizeLightingQuality and level21 were already enabled. A temporary Realistic lighting A/B still showed the discontinuity. Tiny block shadows depend on renderer distance/quality, while large scene shadows remain visible.

Use one shared64px analytic RGBA contact-mask asset and a transparent non-colliding client plane per block. Disable only the blocks' native shadow casting to avoid doubling. Keep the approved world lighting and environment shadows. Reuse a bounded part pool; update only spawning/captured/reflowing blocks through the existing BulkMoveTo arrays. Floor position follows arena scale; shadow expands/fades with airborne height, shrink and capture fade. Clear/reuse shadow handles on removal.

Checks: actual near/far visuals; one shadow per block; both grounded and airborne/capture math; scale100/150/200%; removal/reuse without strays; shared texture approved and loaded; maximum-display frame-time run. Preserve current Studio zoom/HUD code with narrow edits and leave the user's modified Blender file untouched. No place publishing.

Completed: approved mask118876461475845; floor/capture math passed;495/495 normal count;1600/1600 at2.5× with matched normal-client-context A/B59.54FPS on/60.14off.35 capture removals cleaned all matching shadows and10 subsequent additions reused10 parts. Scale100/200% producedY0.218/.418. Temporary test script removed; no substantive review findings. Full evidence and caveats are in assets/shadows/README.md.
