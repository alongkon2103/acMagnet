# Soft block contact shadow

`contact-shadow.png` is a shared 64×64 transparent mask computed from an opacity formula. Run `node assets/shadows/generate-contact-shadow.mjs` after installing the existing project dependencies to regenerate it.

Uploaded once as approved Image asset **118876461475845**, owned by group **973060360**. `src/BlockShadows.luau` uses this URI for every block; install the module in ReplicatedStorage.BlackHole. The client acquires/releases pooled transparent, anchored, non-colliding decal planes and moves active shadows through its existing BulkMoveTo batch. Native block CastShadow is disabled to avoid doubling; world/character shadows and the approved lighting stay unchanged.

The shadow tracks arena floor height and gently broadens/fades with block height and capture shrink/fade. Settled blocks add no per-frame shadow work. Shared mask, bounded pool and existing hidden-face portrait culling are retained.

Verification on 2026-11-09: texture fetch succeeded; 495 blocks matched 495 shadows. Arena sizes 100/200% produced shadow plane center Y values 0.218/0.418. A true LocalScript-context test displayed 1,600 blocks and 1,600 shadows at 2.5× zoom: 60-frame median 59.54 FPS with shadows, 60.14 FPS with them hidden; p95 was about 18.1 ms in both phases. Results are desktop observations, not a device-independent guarantee. Cleanup returned 495/495. Capturing 35 blocks returned 460/460, with minimum shadow width 0.6498 and fade reaching 1; the next 10 test blocks reused 10 released shadow parts and returned 470/470. No strays. The synthetic test script was removed from the place.

`tests/studio/contact-shadow-qa.client.luau` is an optional temporary LocalScript graphics/lifecycle harness. Use a normal client script because command-bar/plugin requires have a separate module cache. It also restores a temporarily hidden shadow root on failure. Original user HUD/zoom source is preserved under ServerStorage.BeforeContactShadows_20261109. No place publishing was performed.
