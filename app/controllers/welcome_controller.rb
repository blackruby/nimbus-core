class WelcomeController < ApplicationController
  require 'bcrypt'

  skip_before_action :ini_controller, only: [:index, :login]

  def index
    if session[:uid]
      redirect_to '/menu' if session[:uid]
      return
    end
    I18n.locale = cookies[:locale] || session[:locale] || I18n.default_locale
  end

  def login
    usu = Usuario.find_by codigo: params[:usuario]
    if usu and usu.password_hash == BCrypt::Engine.hash_secret(params[:password], usu.password_salt)
      session[:uid] = usu.id
      session[:fec] = Time.now        #Fecha de creación
      session[:fem] = session[:fec]   #Fecha de modificación (último uso)
      cookies.permanent[:locale] = session[:locale] = I18n.locale_available?(usu.pref[:locale]) ? usu.pref[:locale] : I18n.default_locale
      redirect_to '/menu'
    else
      session[:uid] = nil
      render 'index'
    end
  end

  def logout
    session[:uid] = nil
    render :nothing => true
  end
end
