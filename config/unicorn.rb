worker_processes 1

listen 3833 

preload_app true

timeout 30

pid               '/var/www/apps/redmine/tmp/pids/unicorn.pid'
stderr_path       '/var/www/apps/redmine/log/unicorn.error.log'
stdout_path       '/var/www/apps/redmine/log/unicorn.out.log'
working_directory '/var/www/apps/redmine'
