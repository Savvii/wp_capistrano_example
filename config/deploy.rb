# Config valid for current version and patch releases of Capistrano
lock '~> 3.10.1'

# Repository settings
set :application, 'my_wp_site'
set :repo_url, 'git@github.com:savvii/wp_capistrano_example.git'
set :branch, :master

# Capistrano settings
set :log_level, :info
set :keep_releases, 5
set :use_sudo, false
set :ssh_options, { forward_agent: true }

# Shared files and directories
append :linked_files, 'wp-config.php'
append :linked_dirs, 'wp-content/uploads'
