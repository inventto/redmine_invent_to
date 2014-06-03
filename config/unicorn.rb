worker_processes 1

listen 3833

preload_app true

timeout 30

pid               '/home/lucas/inventto/redmine.invent.to/tmp/pids/unicorn.pid'
stderr_path       '/home/lucas/inventto/redmine.invent.to/log/unicorn.error.log'
stdout_path       '/home/lucas/inventto/redmine.invent.to/log/unicorn.out.log'
working_directory '/home/lucas/inventto/redmine.invent.to'
