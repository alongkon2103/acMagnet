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

## Connecting another API game

Configure the product in Aclassstore with API mode, protocol `roblox-interactive-v1`, its Roblox place IDs and optional universe ID. Add each case-sensitive API command in the product's event editor and publish its Actions. Commands must match `^[A-Za-z][A-Za-z0-9_.:-]{0,79}$`; adding a label or command in the shop does not create gameplay code. An empty command list is valid while a new game is being prepared.

The authenticated admin connection setup supplies the product's map credential. Keep that plaintext credential only in the game's server-only configuration; do not put it in replicated scripts, client attributes, logs or source control. The shop derives a separate credential per product. The trusted Tikkies backend retrieves only its SHA-256 hash through the private entitled configuration endpoint and registers the current product configuration when binding. The bridge persists this registry so maps can authenticate after a relay restart. The first successful trusted bind must occur before a new map can register.

Set these fields on the server-only `LiveConfig` table when using the standard receiver:

```luau
return {
 BridgeUrl = "https://YOUR-RELAY-HOST", -- operator-managed relay
 BridgeKey = "YOUR-PRODUCT-MAP-CREDENTIAL", -- admin setup, server only
 TikkiesGameId = "YOUR-STORE-PRODUCT-ID",
}
```

`TikkiesBridge.server.luau` passes `TikkiesGameId` to `TikkiesRoomClient.new({gameId=...})`. The room client adds `X-Tikkies-Game` to every room registration, JSON event poll and room leave. The request wrapper adds `X-Magnet-Key` and the server-generated `X-Magnet-Session`; the legacy header names remain the transport contract for every game. ACK arrays, binding UUID and generation stay in the JSON POST body because Roblox rejects `[` in custom header values. Omit `TikkiesGameId` only for the existing Magnet receiver.

A developer must integrate `TikkiesRoomClient` and `LiveDeliveryPump` with the new game's actual server handlers once. The tracked `TikkiesBridge.server.luau` is Magnet's adapter: replace its `BlackHole.LiveState` diagnostics target and `TikTokBridge.TikkiesGateway` hook with that game's equivalents. Register handlers by the exact published command string (for example `handlers["Meteor.Burst:V2"]`), then have the hook support:

- `status`: report whether the native connector is busy.
- `begin(ownerRobloxId, channel, session, bindingId)`: verify the owner is present, reserve the game authority and return true only when ready.
- `submit(session, event)`: reject stale sessions, dispatch `event.effect` to the registered handler, and handle `kind="Portrait"` through the game's portrait cache. Preserve `event.quantity` (1–10,000), sender identity, `test` and stable receipt IDs. Return true only after accepting the work durably enough for the game's delivery semantics; return false for temporary backpressure so the relay can retry.
- `end(session)`: fence and release that session without clearing its accepted receipt history or another session's work.

Namespace handler deduplication/progress by the stable binding ID and event ID, retaining it across transport generation changes on the same game server. Individual handlers must resume partial quantity batches without awarding already completed units twice. The shared pump handles bounded concurrency and only ACKs accepted submissions; it cannot supply a game's missing handlers. Magnet's existing `TikkiesDispatch` and gameplay handlers remain specific to Magnet.

## Relay service contract and compatibility

Every trusted `/tikkies/service/{bind,status,events,release}` POST includes `gameId` alongside its existing subject/binding scope. Bind additionally includes `game: {placeIds, universeId, commands, credentialHash}`. Place/universe IDs are positive decimal strings, `universeId` may be null, commands are unique exact identifiers, and `credentialHash` is a 64-character SHA-256 hex digest. It may be null only for legacy Magnet. These fields come from the authenticated shop endpoint, never from the desktop. Service responses and map responses omit configuration and credential hashes.

An events POST may additionally include trusted `replayOnlyIds: string[]`, a unique subset of the batch's receipt IDs. The auth backend derives this list from its latest published command proof when an old outbox command has been removed. A listed ID succeeds only when its exact fingerprint already exists in that product's binding; it can never enqueue new work, including when the relay's cached catalog still contains the command. Conflicting payloads return `RECEIPT_CONFLICT`; missing receipts return `INVALID_EFFECT`. Map clients cannot supply this service-only field.

The trusted events POST may supply `commands: string[]` from the backend's current private published proof. It must contain at most 200 unique exact command identifiers; an empty list is valid. This list authorizes new receipts for that request only, so newly published commands work on an active binding immediately. It never updates the shared game registry: another user's older proof cannot change other bindings' authorization. Omitting the field retains the registered catalog for legacy callers. `replayOnlyIds` still forbids new intake regardless of the supplied command list, while exact persisted duplicates remain confirmable after removal. Map polls cannot supply either field.

Rooms, room ownership and account/channel bindings are scoped by product. A matching Roblox owner in another product's room cannot receive or reserve this product's queue, even when two products reuse the same room UUID. A configuration update immediately replaces that product's command membership and credential hash. Changing its place/universe identity disconnects the old registrations until their maps register against the new identity. Already accepted durable events remain available for replay. An exact stored receipt retry is still acknowledged after a command is removed; it enqueues nothing. A new receipt using the removed command is rejected, and a changed payload for the old receipt ID remains a conflict.

Missing `gameId` or `X-Tikkies-Game` identifies only AC Magnet (`ce4eb329-7ae9-43d4-bf6a-cfde0fe3cee7`), seeded with its existing place `113965026399564`, universe `10775380860` and 17 commands. `MAGNET_KEY` continues to authenticate only this product; it cannot authenticate a new game. Existing callers may keep their legacy fields and GET polls. A new game's map key is checked against its registered hash and cannot register or poll another product.

On first startup with a pre-product database, the relay migrates legacy room/binding scope to Magnet. SQLite requires a transactional parent-table rebuild to replace the old global uniqueness constraints; binding IDs, sequences, generations, event payloads, receipt fingerprints and portrait jobs are preserved, and child foreign keys are checked before committing. Retain a consistent backup before rollout. New schemas are intended for the upgraded relay; an old binary does not understand product scopes. The existing queue/portrait limits, test expiry, quantity handling and generation-fenced ACK rules still apply.

## Validation

Run `npm test` for the bridge queue, isolation, limits, portraits and replay checks. Run the `tests/studio/tikkies-*-qa.luau` suites with the official Luau CLI and the Studio live QA against the target place. The Tikkies repository also contains `scripts/ac-magnet-e2e.cjs`, which drives the actual HTTP service with two isolated owners and rooms.

Production integration tests must use `test: true`, stable IDs and a retained test binding. Release the binding when finished. Do not fabricate customer purchases or alter payment data.
