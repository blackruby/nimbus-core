if ARGV.size != 1
  puts 'Sintaxis: ruby genmodulo.rb <modulo>' if ARGV.size != 1
  exit
end

mod = ARGV[0]

Dir.mkdir(mod)

Dir.mkdir("#{mod}/app")

Dir.mkdir("#{mod}/app/models")
File.write("#{mod}/app/models/#{mod}.rb",
  "module #{mod.capitalize}
  def self.table_name_prefix
    '#{mod}_'
  end
end
")

Dir.mkdir("#{mod}/app/models/#{mod}")
File.write("#{mod}/app/models/#{mod}/.keep", '')

Dir.mkdir("#{mod}/app/controllers")
Dir.mkdir("#{mod}/app/controllers/#{mod}")
File.write("#{mod}/app/controllers/#{mod}/.keep", '')

Dir.mkdir("#{mod}/config")
File.write("#{mod}/config/routes.rb",
  "modulo = '#{mod}'\n\n" + %q(Rails.application.routes.draw do
  [].each{|c|
    get "#{modulo}/#{c}" => "#{modulo}/#{c}#index"
    get "#{modulo}/#{c}/new" => "#{modulo}/#{c}#new"
    get "#{modulo}/#{c}/:id/edit" => "#{modulo}/#{c}#edit"
    ['validar', 'validar_cell', 'list', 'grabar', 'borrar', 'fon_server'].each {|m|
      post "#{modulo}/#{c}/#{m}" => "#{modulo}/#{c}##{m}"
    }
  }
end
))

Dir.mkdir("#{mod}/db")
Dir.mkdir("#{mod}/db/migrate")
File.write("#{mod}/db/migrate/.keep", '')

Dir.mkdir("#{mod}/esquemas")
File.write("#{mod}/esquemas/.keep", '')
