#!/usr/bin/env puma

ruta = Nimbus::LogPath

environment ENV['RAILS_ENV'] || 'development'
pidfile "#{ruta}/puma.pid"
state_path "#{ruta}/puma.state"
threads Nimbus::Config[:puma][:min_threads], Nimbus::Config[:puma][:max_threads]
workers Nimbus::Config[:puma][:workers]

if ENV['RAILS_ENV'] == 'development' || ENV['NIMBUS_LOCAL'] == 'true'
  bind 'tcp://0.0.0.0:3000'
else
  if Nimbus::Config[:puma][:bind]
    bind Nimbus::Config[:puma][:bind]
  else
    bind "tcp://0.0.0.0:#{Nimbus::Config[:puma][:port]}"
  end
  #bind "ssl://0.0.0.0:#{Nimbus::Config[:puma][:port]}?key=path_to_key&cert=path_to_cert"
end

#preload_app!

# Parece que poniendo esto a false se arreglan problemas de concurrencia cuando un worker
# está busy y encola nuevos request no cediéndolos a otros workers libres.
#queue_requests false

if ENV['RAILS_ENV'] == 'production' && ENV['NIMBUS_LOCAL'] != 'true'
  log_formatter do |str|
    res = ''
    res << "[#{Time.now.strftime '%d-%m %H:%M'}] " unless ENV['NIMBUS_INIT'] 
    res << '[Puma] '
    res << "[#{ENV['NIMBUS_CLI']}] " if ENV['NIMBUS_MULTI']
    res << str
  end
end
