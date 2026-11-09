# ACMagnet — TikTok LIVE

Backend and Roblox sources for MAGNET LAB, place `113965026399564`.

## Current setup

**Deployed:** `https://acmagnet.aclassstore.com` via named Cloudflare tunnel `ac-magnet` on `gamestore-vps`. Application `/var/www/acMagnet`, localhost port `3211`, PM2 processes `ac-magnet-bridge` and `ac-magnet-tunnel`, saved for restart. Studio LiveConfig now points to this permanent URL. Public health check passed; backend tests also passed on the VPS. No signing key was configured in the existing reference backend, and the VPS LIVE probe hit the same signing-provider Business-plan requirement. The new domain still needs to be added to the Studio **Assistant** HTTP allowlist for MCP HTTP verification.

- `bridge/server.mjs`: authenticated session bridge on localhost:8787.
- `bridge/core.mjs`: gift ID mapping, streak normalization, deduplication, replay cursors.
- `bridge/avatar.mjs`: bounded TikTok CDN download, center crop to 16×16 RGB pixels.
- `src/TikTokBridge.server.luau`: operator-controlled HTTPS polling and delivery to SubmitGift.
- `src/PixelPortrait.luau`: one shared EditableImage per profile, pixelated top face on gift blocks.
- `src/TikTokControls.client.luau`: channel input, Connect/Disconnect, connection state.

Installed into the open Studio place with original scripts backed up in `ServerStorage.BeforeTikTok_20261109`. The game has **not** been published by this task. Source files here do not include the arena or tools; those remain in Studio. Local secret `.env` and the configured Studio `ServerScriptService.LiveConfig` must match. Never place LiveConfig in ReplicatedStorage.

## Start and configure

Requires Node 20+ and cloudflared for a local tunnel.

```powershell
npm.cmd ci
Copy-Item .env.example .env # only on first setup; preserve the generated local .env
# Set a random MAGNET_KEY of at least 32 characters in .env.
npm.cmd start
```

In a separate terminal:

```powershell
cloudflared tunnel --url http://127.0.0.1:8787 --no-autoupdate
```

Set the resulting HTTPS URL and matching key in **ServerScriptService.LiveConfig**. Update the Studio Assistant HTTP domain allowlist for MCP testing. Allow HTTP Requests is already enabled in this place. A quick tunnel changes address when restarted and requires this computer, Node, and cloudflared to remain running. Use a permanent HTTPS host for ongoing operation.

### TikTok signing provider

The installed connector is `tiktok-live-connector@2.5.0`. Its default signing provider rejected an actual connection probe with `SignatureMissingTokensError` / “This endpoint requires a Business plan.” No provider subscription or key was available, so live end-to-end acceptance remains unverified. Configure an eligible provider key as `SIGN_API_KEY` in the **local .env** and restart Node. Do not paste keys into chat or client scripts. The game shows `SIGNING_REQUIRED` for this failure. The connector is unofficial; receiving TikTok LIVE depends on upstream availability and provider access.

### Gift mapping

`GIFT_IDS` in `.env` maps real TikTok gift IDs to `Rose`, `Roses`, `Perfume`, or `Bear`. Only provisional Rose ID `5655` is configured. **Confirm this against the chosen LIVE catalog and add the other three IDs before live use.** Unknown gifts do not create blocks. The authenticated `GET /session/gifts` endpoint exposes the connector's available catalog after connection; polling includes an unmapped counter. Never infer a tier from total coins: 100 roses remain 100 Rose gifts.

Current game rules: Rose +10 blocks, Roses +100, Perfume freezes 10s per unit, Bear +1000. Streak gifts are accepted at repeatEnd and use repeatCount. Large quantities are split according to queue capacity and retried with stable chunk IDs.

## Access and lifecycle

Studio users can control connections. In published places, personal-place creator, private-server owner, and IDs explicitly listed in **LiveConfig.OperatorUserIds** can connect. For group-owned public places populate this server-only operator list. Gift-test permissions remain controlled by the existing game Config.

Each Roblox server has a random session token. Backend endpoints require both `X-Magnet-Key` and `X-Magnet-Session`. Session queue is in RAM, retains 2000 events, and reports cursor gaps/dropped events; deduplication has a one-hour retention. Sessions expire 120s after polling stops. Up to 8 sessions per local bridge. Reconnect uses bounded exponential backoff. Gifts awaiting images are drained before end-of-stream terminal status. Restarting Node loses sessions and queues; reconnect in-game.

## Portrait limits

Profiles are center-cropped to 16×16, packed as 256 RGB integers, validated by Roblox, and replicated once per profile rather than on every block. Download failure uses the existing portrait fallback. Up to 256 distinct profile images are retained per Roblox server; additional profiles fall back. EditableImage creation and display were verified in Edit mode. Published experience image API eligibility/settings and actual client performance still require published testing. If EditableImage is unavailable, a run-length GUI fallback is capped at 64 simultaneously drawn profile blocks to avoid hundreds of thousands of GUI objects. Profile content is external user imagery; deployment must apply the creator's moderation policy.

## Verification

```powershell
npm.cmd test
npm.cmd audit --omit=dev
node --env-file=.env bridge/probe-live.mjs channel_handle
node --env-file=.env bridge/smoke.mjs https://acmagnet.aclassstore.com channel_handle
```

Automated tests cover raw v3 and older connector payloads, streak totals, unsafe input, cursor replay/overflow, 16×16 RGB packing, allowed avatar hosts, authentication, session isolation, stream-end draining and signing rejection. Studio checks compile installed scripts, exercise pixel creation/cleanup, Bear quantity chunking, and cancellation during name filtering.

Verified 2026-11-09: 10 Node tests pass, npm audit reports 0 vulnerabilities. Offline Studio Playtest with HTTP adapter disabled accepted a synthetic gift; client reported HUD=true, connectionUI=true, 96 profile blocks and 0 fallback renderers. Output contained only the normal ready message. Stopped Playtest and re-enabled the HTTP adapter afterward. This was a generated test portrait, not a received LIVE profile. Actual TikTok probe: look.chan7 offline; natthapornsrichinwinit1 failed at signing provider with Business-plan requirement. Studio HTTPS probe was denied by Assistant domain allowlist; no workaround was used. End-to-end HTTP/LIVE receipts remain unverified.

For hosting, the Dockerfile listens on 0.0.0.0:8787; supply MAGNET_KEY, GIFT_IDS and optional SIGN_API_KEY as host-managed environment variables. Put HTTPS in front and configure LiveConfig accordingly. The container was not built or deployed in this task.
