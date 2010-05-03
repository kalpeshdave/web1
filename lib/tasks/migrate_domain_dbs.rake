namespace "cms" do 
	desc "Migrate domain databases"
	task :migrate_domain_dbs => [:environment] do |t|
	
    require 'active_record/schema_dumper'
    require 'logger'
    
    version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
    
    if ENV['DOMAIN_ID']
     domains = [ Domain.find(:first,:conditions => [ 'domain_type = "domain" AND `database` != "" AND `status`="initialized" AND id=?',ENV['DOMAIN_ID']]) ]
    else
      domains = Domain.find(:all,:conditions => 'domain_type = "domain" AND `database` != "" AND `status`="initialized"').collect { |dmn| dmn.attributes }
    end
    
    
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    domains.each do |dmn|
      print('Migrating Domain Db: ' + dmn['name'].to_s)
    
      db_file = YAML.load_file("#{RAILS_ROOT}/config/sites/#{dmn['database']}.yml")
      ActiveRecord::Base.establish_connection(db_file['migrator'])
      DomainModel.establish_connection(db_file['migrator'])
      ActiveRecord::Migrator.migrate("#{RAILS_ROOT}/db/migrate/",version)
    end 
    
  end

end
