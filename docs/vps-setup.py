"""Run on the authorized VPS after uploading this release. Never prints secrets."""
from pathlib import Path
import json

root=Path('/var/www/acMagnet')
envpath=root/'.env'
lines=envpath.read_text().splitlines()
values={k:v for line in lines if '=' in line for k,v in [line.split('=',1)]}
values['PORT']='3211'
values['HOST']='127.0.0.1'
# Reuse the same owner's existing provider subscription, never its game bridge key.
previous=Path('/var/www/acFame/bridge/.env')
if previous.exists():
    for line in previous.read_text().splitlines():
        if line.startswith('SIGN_API_KEY='):
            value=line.split('=',1)[1].strip().strip('\"').strip("'")
            if value: values['SIGN_API_KEY']=value
envpath.write_text('\n'.join(k+'='+v for k,v in values.items())+'\n')
envpath.chmod(0o600)
tunnel=Path.home()/'.cloudflared'/'ac-magnet.yml'
tunnel.write_text('''tunnel: 25d6acad-d56e-472c-b26e-6902e0298016
credentials-file: /home/alongkon/.cloudflared/25d6acad-d56e-472c-b26e-6902e0298016.json
ingress:
  - hostname: acmagnet.aclassstore.com
    service: http://127.0.0.1:3211
  - service: http_status:404
''')
tunnel.chmod(0o600)
apps={'apps':[
    {'name':'ac-magnet-bridge','cwd':str(root),'script':str(root/'bridge/server.mjs'),'interpreter':'node','node_args':'--env-file='+str(envpath),'max_memory_restart':'256M','time':True},
    {'name':'ac-magnet-tunnel','script':'/usr/local/bin/cloudflared','interpreter':'none','args':['tunnel','--config',str(tunnel),'run','ac-magnet'],'time':True},
]}
(root/'ecosystem.config.cjs').write_text('module.exports='+json.dumps(apps,indent=2)+';\n')
print(json.dumps({'configured':True,'signingKeyAvailable':bool(values.get('SIGN_API_KEY'))}))
