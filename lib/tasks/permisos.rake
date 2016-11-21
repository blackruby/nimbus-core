namespace :nimbus do
  desc 'Recalcular tabla de permisos por usuario/menu/empresa'
  task :permisos => :environment do |task|
    puts
    puts 'Calculando permisos...'
    puts
    puts 'Usuarios'
    puts '------------------------------------------------'
    menu = nil
    pf = nil
    Usuario.where('NOT admin').order(:codigo).each {|u|
      puts format '%-15.15s %s', u.codigo, u.nombre
      menu, pf = Usuario.calcula_permisos(u, menu, pf)
      u.save
    }
  end
end
