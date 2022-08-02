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

Dir.glob('{modulos,clientes}/*/app/assets/stylesheets/**/*.{css,scss,erb}').each {|d|
  f = d.split('/')[5..-1].join('/')
  f = f[0..f.index('.')] + 'css'
  Rails.application.config.assets.precompile += [f]
}
Dir.glob('{modulos,clientes}/*/app/assets/javascripts/**/*.{js,coffee,erb}').each {|d|
  f = d.split('/')[5..-1].join('/')
  f = f[0..f.index('.')] + 'js'
  Rails.application.config.assets.precompile += [f]
}
Dir.glob('{modulos,clientes}/*/app/assets/images/**/*').each {|d|
  f = d.split('/')[5..-1].join('/')
  Rails.application.config.assets.precompile += [f]
}

Dir.glob('app/assets/stylesheets/**/*.{css,scss,erb}').each {|d|
  f = d.split('/')[3..-1].join('/')
  f = f[0..f.index('.')] + 'css'
  Rails.application.config.assets.precompile += [f]
}
Dir.glob('app/assets/javascripts/**/*.{js,coffee,erb}').each {|d|
  f = d.split('/')[3..-1].join('/')
  f = f[0..f.index('.')] + 'js'
  Rails.application.config.assets.precompile += [f]
}
Dir.glob('app/assets/images/**/*').each {|d|
  f = d.split('/')[3..-1].join('/')
  Rails.application.config.assets.precompile += [f]
}

# Temas y módulos de Highcharts
Rails.application.config.assets.precompile += Dir.glob('modulos/nimbus-core/vendor/assets/javascripts/hch/{modules,themes}/*').map{|f| f[f.index('hch')..-1]}

# Quill (rich editor)
Rails.application.config.assets.precompile += %w(quill/nim_quill.js quill/nim_quill.css)

# nimFirma (signature_pad)
Rails.application.config.assets.precompile += %w(nimFirma/nimFirma.js)