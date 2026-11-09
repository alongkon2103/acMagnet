# Magnet settings and soft capture sound

User asks for a smooth radius slider, optional range ring and pleasant capture sound. Extend the existing generated gear menu with Magnet/LIVE tabs; do not add permanent HUD panels.

Room radius is server-authoritative, adjustable by the same operators who control LIVE, bounded 4–24 studs, default9. Radius is shared for fairness; ring visibility and sound preferences are local, default ring hidden and sound on. Only the room lifetime is requested, no DataStore persistence.

Ring: 48 local non-colliding segments on the arena floor, exponential radius smoothing and fade on/off; no animation work while hidden. Slider sends bounded/coalesced requests, mouse and touch supported. Sound: soft short capture accent, pitch variation, low volume, max4 voices and a minimum inter-onset interval. Trigger for the local player's completed captures only; a batch is not dozens of simultaneous sounds.

Checks: finite/range/permission behavior, slider and reset, ring diameter agrees with server radius, hide/fade, UI tab and mobile fit, loaded/playable sound, capped playback, previous15 Node tests. No game publishing.
