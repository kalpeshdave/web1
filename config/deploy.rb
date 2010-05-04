set :application, 'webiva'
set :repository,  "git://github.com/kalpeshdave/Web1.git"

set :scm, :git
set :deploy_via, :checkout
set :git_shallow_clone, 1
set :deploy_to, "/root/git/web1/"
default_run_options[:pty] = true
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

role :web, "mongrel"                          # Your HTTP server, Apache/etc
role :app, "mongrel"                          # This may be the same as your `Web` server
role :db,  "127.0.0.1:3000", :primary => true # This is where Rails migrations will run
role :db,  "your slave db-server here"

#set :user, "root"
set :branch, "master"

# If you are using Passenger mod_rails uncomment this:
# if you're still using the script/reapear helper you will need
# these http://github.com/rails/irs_process_scripts

# namespace :deploy do
#   task :start do ; end
#   task :stop do ; end
#   task :restart, :roles => :app, :except => { :no_release => true } do
#     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
#   end
# end
