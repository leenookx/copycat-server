# This controller handles the login/logout function of the site.  
class SessionsController < ApplicationController
  # Be sure to include AuthenticationSystem in Application Controller instead
  include AuthenticatedSystem

  layout 'application'

  before_filter :login_required, :only => :destroy
  before_filter :not_logged_in_required, :only => [:new, :create]

  # render new.rhtml
  def new
  end

  def create
    logout_keeping_session!
    user = User.authenticate(params[:login], params[:password])
    if user
      # Protects against session fixation attacks, causes request forgery
      # protection if user resubmits an earlier form using back
      # button. Uncomment if you understand the tradeoffs.
      # reset_session
      self.current_user = user
      new_cookie_flag = (params[:remember_me] == "1")
      handle_remember_cookie! new_cookie_flag
      redirect_back_or_default('/')
      flash[:notice] = "Logged in successfully"
    else
      note_failed_signin
      @login       = params[:login]
      @remember_me = params[:remember_me]
      render :action => 'new'
    end
  end

  def destroy
    logout_killing_session!
    self.current_user.forget_me if logged_in?
    cookies.delete :auth_token
    reset_session
    flash[:notice] = "You have been logged out."
    redirect_back_or_default('/')
  end

protected

  # Track failed login attempts
  def note_failed_signin
    flash[:error] = "Couldn't log you in as '#{params[:login]}'"
    logger.warn "Failed login for '#{params[:login]}' from #{request.remote_ip} at #{Time.now.utc}"
  end

  def password_authentication(login, password)
    user = User.authenticate(login, password)
    if user == nil 
      failed_login("Your username or password is incorrect.")
    elsif user.activated_at.blank?   
      failed_login("Your account is not active, please check your email for the activation code.")
    elsif user.enabled == false 
      failed_login("Your account has been disabled.")
    else
      self.current_user = user
      successful_login
    end
  end
  
private 
  
  def failed_login(message)
    flash.now[:error] = message
    render :action => 'new'
  end

  def successful_login
    if params[:remember_me] == "1"
      self.current_user.remember_me
      cookies[:auth_token] = { :value => self.current_user.remember_token , :expires => self.current_user.remember_token_expires_at }
    end
      flash[:notice] = "Logged in successfully"
      return_to = session[:return_to]
      if return_to.nil?
        redirect_to user_path(self.current_user)
      else
          redirect_to return_to
      end
  end
end
