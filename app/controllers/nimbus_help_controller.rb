class NimbusHelpController < ApplicationController
  def index
    unless @usu.codigo == 'admin'
      render file: '/public/401.html', status: 401, layout: false
      return
    end

    @cap = {}

    procesa_file('Controladores', 'app/controllers/application_controller.rb')
    procesa_file('GI', 'app/controllers/gi_controller.rb')
  end

  def procesa_file(cap, fi)
    @cap[cap] = {}

    met = nil
    File.readlines('modulos/nimbus-core/' + fi).each {|l|
      l.strip!
      if l.starts_with?('##nim-doc')
        h = eval(l[10..-1])
        @cap[cap][h[:sec]] ||= []
        @cap[cap][h[:sec]] << [h[:met], '']
        met = @cap[cap][h[:sec]][-1][1]
      else
        next unless met

        l.starts_with?('##') ? met = nil : met << "#{l[(l[0] == '#' ? 1 : 0)..-1]}\n"
      end
    }
  end
end
