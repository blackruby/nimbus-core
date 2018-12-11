
namespace :nimbus do
  desc 'Vacía las tablas temporales de la base de datos'
  task :vaciadbtmp => :environment do |task|
      tablas = sql_exe(%q(
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE' AND table_name LIKE 'tmp%' OR table_name LIKE '%_tmp%'
      )).values.flatten.join(',')

      sql_exe "TRUNCATE #{tablas} RESTART IDENTITY" unless tablas.blank?
  end
end
