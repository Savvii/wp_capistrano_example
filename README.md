# Git deployments at Savvii

## Getting started

For this guide we will assume the site you want to have versioned and deployed is located in the directory `~/wordpress/my_wp_site`.

As deployment tool we'll be using [Capistrano](http://capistranorb.com/). This requires Ruby 2.0 or newer to be installed on your system. You can install Ruby [directly](https://www.ruby-lang.org/en/documentation/installation/) or using tools as [rbenv](https://github.com/rbenv/rbenv) or [RVM](https://rvm.io/).

> If you have your a code base that is already versioned you can skip ahead to "[Cleaning your code base](#cleaning-your-code-base)".

### Making your code base versioned

For an existing code base, you can initialize git in that code base using:

```
git init
```

After git is initialized you can create a remove repository at one of the big providers like [GitHub](https://github.com/), [BitBucket](https://bitbucket.org/product), [GitLab](https://about.gitlab.com/) or create a privately hosted git server. When you've created a repository you can add it to the repository as `origin` using:

```
git remote add origin git@github.com:savvii/wp_capistrano_example.git`
```

Please follow the guidelines in "[Cleaning your code base](#cleaning-your-code-base)" and "[Setting up git specific files](#setting-up-git-specific-files)" before the first commits. After you've finished these instructions you're ready to start commiting your code base.

### Cleaning your code base

When you use versioning for a code base, it is discouraged to commit credentials in them. So we need to be sure `wp-config.php` is not under version control. You can check if `wp-config.php` is under version control using the following command:

```
git ls-files | grep wp-config.php
```

If this commands has a result it means you have `wp-config.php` under version control. To remove sensitive data from your repository you can follow [a guide made by GitHub](https://help.github.com/articles/removing-sensitive-data-from-a-repository/).

#### Static assets in the uploads directory and cache files

Static assets in the uploads directory (`wp-content/uploads/`), to be named `uploads` from now, and cache files are preferable not commited to a repository as they make deploying slow because all these files need to be downloaded for every release. Uploads can be shared between releases on a server using a shared folder that is symlinked in each release. In "[Configuring the deployment](#configuring-the-deployment)" we will configure this. Cache files should not be shared between releases as a new release most likely means you want to clean the cache.

Before you remove the files mentioned above from your repository **make sure you have a copy of them outside your repository so you won't lose them**.

### Add Capistrano as deployment tool

As we will use Capistrano as our deployment tool we need to [install it](http://capistranorb.com/documentation/getting-started/installation/) first:

```
gem install capistrano
```

After we've installed Capistrano we need to prepare our project to use Capistrano, or as they say it, we need to "Capify" our project:

```
cap install
```

This creates the files and directories for a Capistrano-enabled project with two stages, `production` and `staging`:

```
|- Capfile
|- config/
|  |- deploy/
|  |  |- production.rb
|  |  \- staging.rb
|  \- deploy.rb
\- lib/
   \- capistrano/
      \- tasks/
```

For this guide we will only use the `production` stage, so the file `config/deploy/staging.rb` can be removed.

### Setting up git specific files

To keep a clean repository and a clean deployment we want to configure which files need to be versioned and which need to be checked out for a new deployment. To configure this we will configure `.gitignore` and `.gitattributes`.

#### Configuring .gitignore

We can use [git ignore](https://git-scm.com/docs/gitignore) to tell git which files need to be ignored for versioning. Do note that files already in versioning won't be ignored even if they match the patterns in `.gitignore`.

As we do not want platform related files we'll add them to be ignored:

```
# Platform related ignores
*~
.DS_Store
.svn
.cvs
*.bak
*.swp
Thumbs.db
```

As we're not interested in versioning the log that Capistrano produces we'll exclude that as well:

```
# Capistrano
log/capistrano.log
```

Then there are WordPress specific files and directories we want to ignore because they contain sensitive information or contain a lot of files and need to be shared between deployments using a shared folder that is symlinked:

```
# Credentials, uploads and cache
wp-config.php
wp-content/uploads/
wp-content/blogs.dir/
wp-content/upgrade/*
wp-content/cache/*
```

If you do not want WordPress core to be versioned you can add these lines to the `.gitignore` as well:

```
# WordPress Core (version 4 or higher)
/index.php
/license.txt
/readme.html
/wp-activate.php
/wp-blog-header.php
/wp-comments-post.php
/wp-config-sample.php
/wp-cron.php
/wp-links-opml.php
/wp-load.php
/wp-login.php
/wp-mail.php
/wp-settings.php
/wp-signup.php
/wp-trackback.php
/xmlrpc.php
/wp-admin
/wp-includes
/wp-content/index.php
/wp-content/themes/index.php
/wp-content/plugins/index.php
```

Resulting in [this .gitconfig](https://github.com/Savvii/wp_capistrano_example/blob/master/.gitignore).

#### Configuring .gitattributes

When a checkout is done on the server for deployment, we can use
[git attributes](https://git-scm.com/book/en/v2/Customizing-Git-Git-Attributes)
to let git know which files should not be placed on the server. For example,
the configuration for the deployment tool should not be on the server.

The `.gitattributes` for our project can be configured as follows:

```
/lib              export-ignore
/config           export-ignore
Capfile           export-ignore
.gitattributes    export-ignore
.gitignore        export-ignore
```

Resulting in [this .gitattributes](https://github.com/Savvii/wp_capistrano_example/blob/master/.gitattributes).

### Configuring Capistrano

#### Configuring Capfile

Capistrano can be configured for many SCMs like git, svn, hg. For our project
we only need the git plugin.

Our minimal `Capfile` looks as follows:
```ruby
# Load DSL and set up stages
require 'capistrano/setup'

# Include default deployment tasks
require 'capistrano/deploy'

# Load the SCM git plugin:
require 'capistrano/scm/git'
install_plugin Capistrano::SCM::Git

# Load custom tasks from `lib/capistrano/tasks` if you have any defined
Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }
```

Resulting in [this Capfile](https://github.com/Savvii/wp_capistrano_example/blob/master/Capfile).

#### Configuring the deployment

In `deploy.rb` we configure how we want to deploy our wordpress site. We'll discuss each part of the configuration.

As of Capistrano 3.8.0 and higher a [lock is set at the top of deploy.rb](http://capistranorb.com/documentation/getting-started/version-locking/). The reasoning behind this is that Capistrano could behave unexpectedly on systems when multiple developers needed to deploy but did not have the same Capistrano version on their machine. To prevent this unexpected behaviour the lock was added to let Capistrano check if you have the required version to perform the deployment.

```ruby
# Config valid for current version and patch releases of Capistrano
lock '~> 3.10.1'
```

Next we configure the repository. The name of our repo is `my_wp_site`, so we use that as application name. As default, we use the master branch to deploy from.

```ruby
# Repository settings
set :application, 'my_wp_site'
set :repo_url, 'git@github.com:savvii/wp_capistrano_example.git'
set :branch, :master
```

Then we configure options for Capistrano. We want to have some logging, but not too verbose. We want to limit the number of releases we want keep on the server. As we won't need sudo we will disable it. Additionally we set `forward_agent` so we can use ssh to do a git checkout.

```ruby
# Capistrano settings
set :log_level, :info
set :keep_releases, 5
set :use_sudo, false
set :ssh_options, { forward_agent: true }
```

Next we add the linked files and linked directories. For example the `wp-config.php` and `wp-content/uploads` need to be shared between releases.

```ruby
# Shared files and directories
append :linked_files, 'wp-config.php'
append :linked_dirs, 'wp-content/uploads'
```

Resulting in [this deploy.rb](https://github.com/Savvii/wp_capistrano_example/blob/master/config/deploy.rb).

#### Configuring the production stage

In this file we add the settings to which server we want to deploy, as who we want to deploy and to which folder we want to deploy. For this example we have the username `comexa-stageable` and the base directory `/var/www/comexa-stageable`, then we can configure the production stage as follows:

```ruby
server 'comexa-stageable.savviihq.com', user: 'comexa-stageable', roles: %w{app}
set :deploy_to, '/var/www/comexa-stageable/wordpress'
```

Resulting in [this production.rb](https://github.com/Savvii/wp_capistrano_example/blob/master/config/deploy/production.rb).

#### Preparing the first release

For the first release we need to check if we have access to the repository and if shared files and directories exist. We can check if the server is ready for a release with the following command:

```
cap production deploy:check
```

This checks if a checkout can be made, if files and directories that need to be shared exist. For example, the following error can be shown:

```
00:03 deploy:check:linked_files
      ERROR linked file /var/www/comexa-stageable/wordpress/shared/wp-config.php does not exist on comexa-stageable.savviihq.com
```

This means the shared file `wp-config.php` has not been made on the server yet. You can copy this from the existing site using the following command on the server:

```
cp /var/www/comexa-stageable/wordpress/current/wp-config.php /var/www/comexa-stageable/wordpress/shared/
```

When `deploy:check` runs, it also creates the directories that will be shared between releases as defined in "Configuring the deployment". For us this means that we have a shared folder where we can place our uploads in. When you have an existing site on the server you can copy these files using the following command on the server:

```
mv /var/www/comexa-stageable/wordpress/current/wordpress/current/wp-content/uploads /var/www/comexa-stageable/wordpress/shared/wp-content/
```

Or when you need to upload them from your local machine to the server you can use (from your machine):

```
rsync --archive --progress --stats --verbose wp-content/uploads/ comexa-stageable@comexa-stageable.savviihq.com:/var/www/comexa-stageable/wordpress/shared/wp-content/uploads/
```

When you've created the shared `wp-config.php` and moved/uploaded your uploads the command `deploy:check` should give no errors. Your repository is now almost ready for the first release. The last action we need to do is move the current directory and make a symlink of it. That can be done on the server using the following command:

```
mv /var/www/comexa-stageable/wordpress/current /var/www/comexa-stageable/wordpress/remove_me_after_first_release && ln -s /var/www/comexa-stageable/wordpress/remove_me_after_first_release /var/www/comexa-stageable/wordpress/current
```

After we've made a symlink of the current directory we can start the first release on our local machine:

```
cap production deploy
```

## Deploying to Savvii

If you've completed the steps mentioned above and the first release is made next releases can be done using:

```
cap production deploy
```

## Additional tasks

We can expand the actions around releases with tasks. The following tasks can be placed in the file `lib/capistrano/tasks/wordpress.rake` inside a namespace block. The file with namespace but without tasks looks as follows:

```ruby
namespace :wordpress do
  # Add tasks here
end
```

An example [`wordpress.rake` is provided](https://github.com/Savvii/wp_capistrano_example/blob/master/lib/capistrano/tasks/wordpress.rake) with the tasks mentioned below.

### Prevent deploy when local branch not in sync with remote

When you deploy a release to the server it will take the last version available from the branch and remote configured in `deploy.rb` under `:branch` and `:repo_url`. When you've made changes locally but did not push them to the remote they will not be released. You can instruct Capistrano to stop a release when the local and remote branch are out of sync using the following task (it assumed the remote is named `:origin`):

```ruby
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
```

### Empty various caches after a release is made

After a release there are various caches that need / can be cleared. Capistrano can perform this cleanup when a release is made using the following task:

```ruby
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
```
