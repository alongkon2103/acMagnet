"""Remove only the initial provisional one-gift override on this deployment."""
from pathlib import Path
import json
p=Path('/var/www/acMagnet/.env')
lines=p.read_text().splitlines()
for line in lines:
    if line.startswith('GIFT_IDS='):
        assert json.loads(line.split('=',1)[1])=={'5655':'Rose'}, 'Custom mapping exists: review manually'
p.write_text('\n'.join(line for line in lines if not line.startswith('GIFT_IDS='))+'\n')
p.chmod(0o600)
print('Activated four database-backed gift mappings')
