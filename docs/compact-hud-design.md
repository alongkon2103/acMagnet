# Compact image-based HUD

User requested removal of the large game heading, movement instructions, constant idle status and oversized control panels. Keep only a 280×57 score plaque, tiny menu buttons and short contextual feedback. Connection controls and test gifts are collapsed by default and mutually exclusive. Portrait gameplay and backend behavior stay unchanged.

Use a genuinely generated transparent PNG atlas in assets/ui/toylab-hud-v1.png: ivory enamel, muted sage and thin copper edges. Dynamic text stays native for sharp numbers/localization. Atlas artwork has no baked labels. Rectangles are measured from alpha bounds; assets uploaded to the experience's owning group.

Verification: compile Lua sources; verify image loads; default panels hidden; no heading/movement instructions or permanent idle status; open/close both panels, connection remains functional; desktop and narrow viewport layout checks. Keep active LIVE configuration server-only. Do not publish the place automatically.
