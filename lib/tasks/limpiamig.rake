namespace :nimbus do
  desc 'Borrar ids huérfanos en migraciones'
  task :limpiamig => :environment do |task|
      a = `rake db:migrate:status`
      ids = ''
      a.split("\n").each {|l|
        c = l.split(' ')
        ids << "'" + c[1] + "'," if c[2] and c[2].start_with?('*******')
      }

      ActiveRecord::Base.connection.execute('delete from schema_migrations where version in (' + ids.chop + ')') if ids != ''
  end
end
