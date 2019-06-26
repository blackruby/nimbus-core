class UsuariosMailer < ActionMailer::Base
  def new_password(usu, pass)
    @user = usu
    @pass = pass
    mail(to: usu.email, subject: 'Acceso Nimbus')
  end
end