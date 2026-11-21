# Tikkies integration

AC Magnet can receive its existing native game events from Tikkies. The in-game TikTok connector remains available; a shared arena accepts one active connector owner at a time.

## Player flow

1. Update Tikkies and join AC Magnet with the purchased Roblox account.
2. Open Our Game → AC Magnet → Actions. Select that Roblox account if the purchase contains several accounts.
3. Connect the TikTok channel in Tikkies and enable the game's LIVE actions.
4. Use store defaults or choose another viewer trigger and match it to a game event. Tests work without a TikTok LIVE connection.

Names and portraits follow the triggering viewer. The existing native block, gacha and portrait systems render the results. Manual tests use a test identity and do not claim real-follow rewards.

## Operators

- The Tikkies backend authenticates the desktop device, checks current store entitlement and resolves purchased Roblox usernames. It derives the queue scope; the desktop cannot choose another customer's scope.
- `MAGNET_TIKKIES_KEY` is a separate service credential shared only by the auth backend and Magnet bridge. `MAGNET_KEY` stays in server-only Roblox `LiveConfig` and the Magnet service.
- Keep `runtime/tikkies.sqlite` across deployments. The queue uses WAL and synchronous FULL; never copy a live SQLite database without a consistent backup procedure.
- Pausing or leaving the room preserves paid pending work. Manual tests expire after 60 seconds. Portrait conversion runs separately so it does not delay gameplay.
- Acknowledgments remove durable deliveries only after the native processor accepts them. Stable receipt IDs suppress ambiguous network retries. Room generation fences reject old acknowledgments.
- The native game retains accepted block/gacha state in memory. This integration does not promise atomic exactly-once execution across a Roblox server crash.
- When every portrait slot is in use, gameplay continues with a fallback face; completed, unreferenced portraits are recycled first.

The Studio installer supports dry run and creates script backups before changing narrow integration hooks. It preserves personal wins, the saved native TikTok username, existing clients and rendering modules. Never put credentials in replicated scripts.

## Validation

Run `npm test` for the bridge queue, isolation, limits, portraits and replay checks. Run the `tests/studio/tikkies-*-qa.luau` suites with the official Luau CLI and the Studio live QA against the target place. The Tikkies repository also contains `scripts/ac-magnet-e2e.cjs`, which drives the actual HTTP service with two isolated owners and rooms.

Production integration tests must use `test: true`, stable IDs and a retained test binding. Release the binding when finished. Do not fabricate customer purchases or alter payment data.
