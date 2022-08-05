class Tema < ActiveRecord::Base
  @propiedades = {
    codigo: {manti: 10, pk: true, may: true, req: true},
    descripcion: {manti: 50},
    usuario_id: {},
    privado: {},
    params: {},
  }
  
  serialize :params

  def self.scs_default
    h = {}
    File.readlines('modulos/nimbus-core/vendor/assets/stylesheets/_nimbus_theme.scss').each {|l|
      next unless l.strip!.to_s.starts_with?('--')

      l = l.split(':')
      h[l[0]] = l[1].strip.chomp.chop
    }
    h.merge!(Nimbus::Config[:tema]) if Nimbus::Config[:tema]
    h
  end
  
  belongs_to :usuario, :class_name => 'Usuario'
end
