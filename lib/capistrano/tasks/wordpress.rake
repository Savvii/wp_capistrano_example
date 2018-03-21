namespace :wordpress do

  # Check local git ahead of origin
  desc 'Make sure there is something to deploy, force deploy with "-s check_pushed_state=false"'
  task :check_revision do
    if fetch(:check_pushed_state, 'true')
      unless `git rev-parse #{fetch(:branch)}` == `git rev-parse origin/#{fetch(:branch)}`
          puts ''
          puts " \033[1;33m**************************************************\033[0m"
          puts " \033[1;33m* WARNING: #{fetch(:branch)} is not the same as origin/#{fetch(:branch)}\033[0m"
          puts " \033[1;33m**************************************************\033[0m"
          puts ''
          exit
      end
    end
  end
  before 'deploy', 'wordpress:check_revision'

  desc 'Clear caches'
  task :clear_caches do
    on roles(:app) do
      # Clear OPCache
      execute :touch, "#{fetch(:deploy_to)}/php-fpm.service"

      within current_path do
        # Clear WP-cache
        execute :wp, :cache, :flush
        # Clear Varnish
        execute :wp, :eval, '"do_action( \'savvii_cache_flush\' );"'
      end
    end
  end
  after 'deploy:published', 'wordpress:clear_caches'
end
