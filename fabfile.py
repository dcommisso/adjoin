from fabric.api import run,local,put,cd,hide,show,env

# configurazione credenziali generiche
env.user = 'root'
env.password = 'password'
env.abort_on_prompts = True
env.warn_only = 1

with open('hosts', 'r') as f:
   for line in f:
      env.hosts.append(line)

def join():
   data = local("date +%Y%m%d%H%M%S", capture=True)
   work_dir = "/tmp/" + data
   run("mkdir %s" % work_dir)
   local("tar czf autojoin.tgz ./join.exp ./start.sh")
   with cd(work_dir):
      put('./autojoin.tgz', 'autojoin.tgz')
      run('tar xzf autojoin.tgz')
      run('./start.sh')
   run("rm -Rf %s" % work_dir)
   local("rm -f ./autojoin.tgz")
