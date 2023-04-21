# Be sure to restart your server when you modify this file.
#
# # Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'
#
# # Add additional assets to the asset load path
# # Rails.application.config.assets.paths << Emoji.images_path
#
# # Precompile additional assets.
# # application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
# # Rails.application.config.assets.precompile += %w( search.js )


Rails.application.config.assets.precompile += ['*.png', '*.gif', '*.jpg', '*.eot', '*.ttf', '*.woff', '*.woff2', '*.svg']

path = 'app/assets/stylesheets'
lpath = path.size + 1
Dir.glob("#{Nimbus::ModulosCliGlob}/#{path}/**/*.{css,scss,erb}").each {|d|
  Rails.application.config.assets.precompile += [d[d.index(path)+lpath..d.index('.', d.rindex('/'))] + 'css']
}

path = 'app/assets/javascripts'
lpath = path.size + 1
Dir.glob("#{Nimbus::ModulosCliGlob}/#{path}/**/*.{js,cofee,erb}").each {|d|
  Rails.application.config.assets.precompile += [d[d.index(path)+lpath..d.index('.', d.rindex('/'))] + 'js']
}

path = 'app/assets/images'
lpath = path.size + 1
Dir.glob("#{Nimbus::ModulosCliGlob}/#{path}/**/*.*").each {|d|
  Rails.application.config.assets.precompile += [d[d.index(path)+lpath..-1]]
}

# Highcharts
Rails.application.config.assets.precompile += %w(hch.js)

# Temas y módulos de Highcharts
Rails.application.config.assets.precompile += Dir.glob('modulos/nimbus-core/vendor/assets/javascripts/hch/{modules,themes}/*').map{|f| f[f.index('hch')..-1]}

# Quill (rich editor)
Rails.application.config.assets.precompile += %w(quill/nim_quill.js quill/nim_quill.css)

# nimFirma (signature_pad)
Rails.application.config.assets.precompile += %w(nimFirma/nimFirma.js)