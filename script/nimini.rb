# Aplicar tareas de inicialización definidas en ini.yml (en el home de la gestión/cliente)
yml = "#{::Nimbus::GestionPath}ini.yml"
if File.exist?(yml)
begin
  debug = ENV['NIMBUS_DEBUG'].to_i
  sto = STDOUT.clone
  ste = STDERR.clone
  STDOUT.reopen(IO::NULL) if debug < 3
  STDERR.reopen(IO::NULL) if debug < 2
  ActiveRecord::Base.logger.level = Logger::INFO if debug < 3

  # Obtener bloqueo exclusivo para que no se ejecuten nunca en paralelo varias instancias de este
  # programa (fundamentalmente por los efectos secundarios de rodar assets:precompile en paralelo)
  flock = File.open('/tmp/_nimbus_proxy', 'w')
  flock.flock(File::LOCK_EX)

  ini = YAML.load(ERB.new(File.read(yml)).result).deep_symbolize_keys

  pinta = ->(txt) {
    sto.print "[#{ENV['NIMBUS_CLI']}] " if ENV['NIMBUS_MULTI'] && ENV['NIMBUS_CLI']
    sto.puts txt
    sto.flush
  }

  task = ->(hsh, tipo) {
    hsh[tipo].delete_if {|t|
      pinta["\e[0;105m\e[97m #{t[0, 50]} \e[0m"]
      tipo == :rake ? Rake::Task[t].invoke : eval(t)
      STDOUT.flush
      STDERR.flush
      true
    }
    hsh.delete(tipo)
  }

  env = Rails.env.to_sym

  # Ejecutar tareas rake
  if ini[:rake] || ini.dig(env, :rake)
    Rails.application.load_tasks
    task.call(ini, :rake) if ini[:rake]
    task.call(ini[env], :rake) if ini.dig(env, :rake)
  end

  # Ejecutar tareas exe
  task.call(ini, :exe) if ini[:exe]
  task.call(ini[env], :exe) if ini.dig(env, :exe)

  ini.delete(env) if ini[env] && ini[env].empty? 

  pinta["\e[0;105m\e[97m Inicialización finalizada con éxito \e[0m"]
rescue Exception => e
  e.message.each_line {|l| pinta[" #{l}"]}
  e.backtrace.each{|l| pinta[" #{l}"]} if debug > 0
  pinta["\e[0;101m\e[97m ¡¡Server abortado!! \e[0m"]
  exit
ensure
  STDOUT.reopen(sto) if debug < 3
  STDERR.reopen(ste) if debug < 2
  ini.empty? ? File.delete(yml) : File.write(yml, ini.to_yaml)
  flock.close # Al cerrar el fichero se libera el bloqueo
end
end
exec("EAGER_LOAD=#{Rails.env == 'production'} " + ARGV.join(' '))
