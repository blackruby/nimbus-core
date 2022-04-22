class UsuariosMailer < ActionMailer::Base
  def new_password(usu, pass)
    @user = usu
    @pass = pass
    mail(to: usu.email, subject: 'Acceso Nimbus')
  end

  def send_pin(usu, pin)
    @user = usu
    @pin = pin
    mail(to: usu.email, subject: 'Pin Acceso Nimbus')
  end
end