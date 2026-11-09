# ACMagnet — TikTok LIVE

Backend and Roblox sources for MAGNET LAB, place `113965026399564`.

## Current setup

**Deployed:** `https://acmagnet.aclassstore.com` via named Cloudflare tunnel `ac-magnet` on `gamestore-vps`. Application `/var/www/acMagnet`, localhost port `3211`, PM2 processes `ac-magnet-bridge` and `ac-magnet-tunnel`, saved for restart. Studio LiveConfig points to this permanent URL. Public health check, authenticated session API and actual public TikTok LIVE connection passed from the VPS. Studio Assistant HTTPS access is verified after the owner added the domain to the allowlist.

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

The installed connector is `tiktok-live-connector@2.5.0`. **Extended gift-catalog fetching is disabled:** enabling it requests arbitrary URL signing, which returned a Business-plan error during initial investigation. The normal LIVE connection works without a key in the verified environment; both direct connector and deployed session API connected to `natthapornsrichinwinit1` on 2026-11-09. Do not enable extended catalog fetching just to receive gifts. The connector still uses its upstream signing provider for WebSocket setup and may have changing availability/quotas. If a future deployment requires an eligible provider key, configure `SIGN_API_KEY` in the server .env and restart Node; never put it in client scripts. The game shows `SIGNING_REQUIRED` when applicable. No paid plan was purchased.

### Gift mapping

Defaults come from `data/game-gifts.json`, a four-record subset of the owner's supplied `tiktok_gifts.json`. `GIFT_IDS` in .env is an optional override. Both local and VPS initial one-gift overrides were removed to activate the database mappings. Unknown gifts do not create blocks. The authenticated `GET /session/gifts` endpoint lists gift IDs/names observed during that session without fetching the premium extended catalog; polling includes an unmapped counter. Never infer a tier from total coins: 100 roses remain 100 Rose gifts.

| Database name | Gift ID | Coins | Game action |
| --- | --- | --- | --- |
| Rose | 5655 | 1 | Rose: +10 blocks |
| Rosa | 8913 | 10 | Roses: +100 blocks |
| Perfume | 5658 | 20 | Perfume: freeze 10s |
| Mishka Bear | 5566 | 100 | Bear: +1000 blocks |

Mishka Bear was chosen for the existing “อุ้มใจหมี” slot based on its bear name and 100-coin price; other 100-coin gifts such as Hand Heart are not treated as Bear. This mapping follows the owner's database snapshot; future TikTok regional catalogs may change.

Current game rules: Rose +10 blocks, Roses +100, Perfume freezes 10s per unit, Bear +1000. Streak gifts are accepted at repeatEnd and use repeatCount. Large quantities are split according to queue capacity and retried with stable chunk IDs.

Likes: every 50 likes from the same sender creates 10 blocks with that sender's pixel profile, using action `Likes`. Counts use the raw connector packet's `count`, never the stream-wide `total`. Remainders carry over (120 likes = 20 blocks and 20 likes remaining). Duplicate message IDs are ignored. Progress survives automatic socket retries within a session and resets on a new Connect session. Up to 10,000 recent senders and 100,000 like receipt IDs are retained per session. TikTok may omit like packets on busy streams; only received packets can be counted. Studio gateway verification confirmed exactly +10 blocks and duplicate suppression; the UI displays the rule.

## Access and lifecycle

Studio users can control connections. In published places, personal-place creator, private-server owner, and IDs explicitly listed in **LiveConfig.OperatorUserIds** can connect. For group-owned public places populate this server-only operator list. Gift-test permissions remain controlled by the existing game Config.

Each Roblox server has a random session token. Backend endpoints require both `X-Magnet-Key` and `X-Magnet-Session`. Session queue is in RAM, retains 2000 events, and reports cursor gaps/dropped events; deduplication has a one-hour retention. Sessions expire 120s after polling stops. Up to 8 sessions per local bridge. Reconnect uses bounded exponential backoff. Gifts awaiting images are drained before end-of-stream terminal status. Restarting Node loses sessions and queues; reconnect in-game.

## Portrait limits

Profiles are center-cropped to 32×32, packed as 1024 RGB integers (legacy 16×16 payloads are also accepted), validated by Roblox, and replicated once per profile rather than on every block. Download failure uses the existing portrait fallback. Up to 256 distinct profile images are retained per Roblox server; additional profiles fall back. EditableImage creation and display were verified in Edit mode. Published experience image API eligibility/settings and actual client performance still require published testing. If EditableImage is unavailable, a run-length GUI fallback is capped at 16 simultaneously drawn profile blocks to avoid hundreds of thousands of GUI objects. Profile content is external user imagery; deployment must apply the creator's moderation policy.

## Verification

```powershell
npm.cmd test
npm.cmd audit --omit=dev
node --env-file=.env bridge/probe-live.mjs channel_handle
node --env-file=.env bridge/smoke.mjs https://acmagnet.aclassstore.com channel_handle
```

Automated tests cover raw v3 and older connector payloads, streak totals, unsafe input, cursor replay/overflow, 32×32 RGB packing, allowed avatar hosts, authentication, session isolation, stream-end draining and signing rejection. Studio checks compile installed scripts, exercise pixel creation/cleanup, Bear quantity chunking, and cancellation during name filtering.

Verified 2026-11-09: 15 Node tests pass locally and on VPS, npm audit reports 0 vulnerabilities. Offline Studio Playtest with HTTP adapter disabled accepted a synthetic gift; client reported HUD=true, connectionUI=true, 96 profile blocks and 0 fallback renderers. Output contained only the normal ready message. Stopped Playtest and re-enabled HTTP adapter afterward. This was a generated test portrait, not a received LIVE gift. After disabling extended catalog fetching, both a VPS connector probe and the deployed authenticated HTTPS session API connected to the public channel `natthapornsrichinwinit1` with status LIVE. The smoke test confirmed unauthenticated requests return 401, then disconnected its test session. Follow-up Studio verification: HTTPS health returned ok=true; actual in-game Connect reached LIVE for natthapornsrichinwinit1, Disconnect returned DISCONNECTED, and Reconnect reached LIVE again. Client UI showed the live state and Output contained only the normal ready message. No actual gift arrived during this observation (0 sender portraits, Dropped=0, Unmapped=0), so real LIVE gift-to-block acceptance and published behavior remain unverified.

For hosting, the Dockerfile listens on 0.0.0.0:8787; supply MAGNET_KEY, GIFT_IDS and optional SIGN_API_KEY as host-managed environment variables. Put HTTPS in front and configure LiveConfig accordingly. The container was not built or deployed in this task.

Profile fix verified: real raw v3 users can contain only avatarThumb.urlList; avatarLarge/avatarMedium may both be absent. The normalizer now falls back to avatarThumb. A live @slap.a receipt from min44607 produced 256 pixel values and 10 drawn profile blocks before the clarity upgrade. The subsequent 32x32 conversion produced 1024 values and 148 distinct colors from a real TikTok CDN sample; the client renderer accepts both resolutions. The backend and Studio renderer are updated to32x32.
