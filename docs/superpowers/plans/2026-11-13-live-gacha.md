# TikTok gifts into the existing F/G gacha

Goal: Heart Me (7934) queues Mixed (F); G.O.A.T. Busker (626064) queues Prank (G). Every accepted unit gets one existing roll and displays its sender's profile. Keyboard rolls display the Roblox player's profile. Preserve current odds, artwork, sounds, 2.4s roll and 2s result timing.

Architecture: extend the existing authenticated gift API and SubmitGift gateway. Paid and keyboard actions share one server queue. Keep server-selected rewards; clients only draw results. Carry the preassigned portrait ID through queued jobs and replace the badge image when asynchronous pixels arrive. Use the existing PixelPortrait shared image cache. Do not replace unrelated Studio scripts with older repository versions.

Alternatives: a separate LIVE-only gacha would duplicate odds/queue logic and drift from F/G; client-only rolls would bypass server authority. Reuse is the implementation choice, matching the requested existing controls.

## Constraints

- Both gift IDs come from the supplied database and screenshots; no matching by total coins.
- Preserve auth, protocol2 portrait delivery, streak deltas, replay suppression, access checks and personal WIN behavior.
- Queue accepts paid batches atomically, up to100 units, with a bounded50000-unit intake; animation timing never gates normal receipt processing. Free keyboard limits remain global128 / per-player32.
- Accepted paid jobs survive their triggering player's departure, matching other already accepted global gifts; free keyboard jobs retain their existing departure cleanup.
- Do not publish the Roblox place automatically. Deploy the backend to ssh gamestore-vps:/var/www/acMagnet after verification.
- Preserve the user-modified .blend file.

## Execution

- [x] Write and run failing backend regressions for7934/626064, streak deltas, replay and asynchronous portraits.
- [x] Extend backend gift whitelist/database; run full npm test.
- [x] Write/run the failing Studio gateway test for HeartMe/GoatBusker.
- [x] Add queue sender context and a shared enqueue helper in the current server. Route authenticated gifts with the LIVE owner's Roblox ID; retain F/G/H modes and permissions.
- [x] Add the profile badge, late portrait replacement and local Roblox thumbnail. Keep sender/name visible through rare reward results.
- [x] Patch Studio narrowly with backups; compile changed Luau. Test real gateway rolls, both Mixed outcomes, Prank-only, replay, batch/backpressure, F/G remote path and late profiles.
- [x] Review final diff. Deploy paired backend, verify auth/HTTPS and normal game connection. Document exact simulated versus real LIVE evidence.
- [x] Commit and push the final changes.

## Review focus

Replay after partial batch acceptance must not reroll accepted units; a full queue must return backpressure rather than drop paid gifts. A late portrait from one sender must not overwrite the next roll's sender. Untrusted clients must not supply reward amounts or impersonate a TikTok receipt. A missing picture must leave the reel playable. Current personal WIN/access systems and newer map/UI source must survive narrow edits.

Ruling: use a dedicated bounded paid intake, retaining free-control caps, because the original32-slot queue held later gifts/portraits behind minutes of animation. Keep receipt progress independently of one-hour gateway deduplication to prevent rerolls on long backlogs. Negotiate gacha/follow capabilities so the backend rollout cannot poison older game sessions.

Scope update requested during implementation: connector follow event grants10 profile blocks. Reuse the native FollowRewardGuard and existing +10 rule; add only missing backend normalization/subscription and the follow capability. Verified10 blocks/60 faces and duplicate suppression with an in-memory follow store. Final backend suite26/26, VPS26/26; Studio3 regression harnesses passed. HTTPS advertised all capabilities and normal game connection returned OFFLINE for min44607. No real donation/follow or place publish claimed.
