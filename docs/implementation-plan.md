# TikTok LIVE integration — 2026-11-09

User authorized a new backend and integration into the existing place, with 16×16 sender profile portraits.

Architecture: Node HTTP session bridge + tiktok-live-connector + sharp; server-only authenticated polling; existing SubmitGift gateway; shared portrait registry and client pixel renderer. Preserve current gift effects. Stable gift IDs and streak quantities, never total coin tier inference. Session TTL, bounded replay queue, explicit overflow reporting. Secrets stay in server-only config and ignored local .env.

1. Test normalization, final streak quantities, deduplication, cursor replay, overflow, portrait conversion and HTTP authentication.
2. Implement bridge and image downloader with bounded HTTPS CDN fetches and image cache.
3. Back up Studio scripts and export sources; add server connection adapter and client controls/pixel rendering.
4. Run backend tests and Studio integration with synthetic gifts, then leave real LIVE validation pending channel input.

Deployment: local bridge plus temporary cloudflared HTTPS for this machine. Permanent hosting remains a separate operational step. Do not publish the place automatically. Portraits use a shared EditableImage when available, with a bounded GUI fallback; measure actual behavior in Studio. Profile content moderation and published image API eligibility remain production validation items.
