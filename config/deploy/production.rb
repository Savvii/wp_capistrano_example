
# Production server
server 'comexa-stageable.savviihq.com', user: 'comexa-stageable', roles: %w{app}
set :deploy_to, '/var/www/comexa-stageable/wordpress'
