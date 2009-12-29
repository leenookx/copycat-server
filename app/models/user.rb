require 'digest/sha1'

class User < ActiveRecord::Base
  include Authentication
  include Authentication::ByPassword
  include Authentication::ByCookieToken

  # Virtual attribute for the unencrypted password
  attr_accessor :password

  validates_presence_of     :login
  validates_length_of       :login,    :within => 3..40
  validates_uniqueness_of   :login
  validates_format_of       :login,    :with => Authentication.login_regex, :message => Authentication.bad_login_message

  validates_format_of       :name,     :with => Authentication.name_regex,  :message => Authentication.bad_name_message, :allow_nil => true
  validates_length_of       :name,     :maximum => 100

  validates_presence_of     :email
  validates_length_of       :email,    :within => 6..100 #r@a.wk
  validates_uniqueness_of   :email
  validates_format_of       :email,    :with => Authentication.email_regex, :message => Authentication.bad_email_message

  validates_presence_of     :password, :if => :password_required?
  validates_presence_of     :password_confirmation, :if => :password_required?
  validates_length_of       :password, :within => 4..40, :if => :password_required?
  validates_confirmation_of :password, :if => :password_required

  before_create :make_activation_code 

  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :login, :email, :name, :password, :password_confirmation

  has_many :permissions
  has_many :roles, :through => :permissions

  before_save :encrypt_password
  before_create :make_activation_code

  class ActivationCodeNotFound < StandardError; end
  class AlreadyActivated < StandardError
    attr_reader :user, :message;

    def initialize(user, message=nil)
      @message, @user = message, user
    end
  end

  # Finds the user with the corresponding activation code, activates their
  # account and returns the user.
  #
  # Raises:
  #   +User::ActivationCodeNotFound+ if there is no user with the 
  #      corresponding activation code.
  #   +User::AlreadyActivated+ if the user with the corresponding
  #      activation code has already activated their account.
  def self.find_and_activate!(activation_code)
    raise ArgumentError if activation_code.nil?

    user = find_by_activation_code(activation_code)
    raise ActivationCodeNotFound if !user
    raise AlreadyActivated.new(user) if user.active?

    user.send(:activate!)

    return user
  end

  def active?
    # the presence of an activation date means they have activated
    !activated_at.nil?
  end

  # Returns true if the user has just been activated.
  def pending?
    @activated
  end

  # Authenticate a user by their login name and unencrypted password.
  # Returns the user or nil.
  def self.authenticate(login, password)
    u = find :first, :conditions => ['login = ?', login]
    u && u.authenticated?(password) ? u : nil
  end

  # Encrypts some data with the salt
  def self.encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end

  # Encrypts the password with the user salt
  def encrypt(password)
    self.class.encrypt(password, salt)
  end

  def authenticated?(password)
    crypted_password == encrypt(password)
  end

  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at
  end

  # These create and unset the fields required for remembering user
  # between browser closures.
  def remember_me
    remember_me_for 2.weeks
  end

  def remember_me_for(time)
    remember_me_until time.from_now.utc
  end

  def remember_me_until(time)
    self.remember_token_expires_at = time
    self.remember_token = encrypt("#{email}--#{remember_token_expires_at}")
    save(false)
  end

  def forget_me
    self.remember_me_token_expires_as = nil
    self.remember_token = nil
    save(false)
  end

  def forgot_password
    @forgotten_password = true
    self.make_password_reset_code
  end

  def reset_password
    # First update the password_reset_code before setting the
    # reset_password flag to avoid duplicate email notifications.
    update_attribute(:password_reset_code, nil)
    @reset_password = true
  end

  # Used in user_observer
  def recently_forgot_password?
    @forgotten_password
  end

  def recently_reset_password?
    @reset_password
  end

  def recently_activated?
    @activated
  end

  def self.find_for_forget(email)
    find :first, :conditions => ['email = ? and activated_at IS NOT NULL', email]
  end

  def has_role?(rolename)
    self.roles.find_by_rolename(rolename) ? true : false
  end

protected

  # before filter
  def encrypt_password
    return if password.blank?
    
    self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
    self.crypted_password = encrypt(password)
  end

  def password_required?
    crypted_password.blank? || !password.blank?
  end

  def make_activation_code
    self.activation_code = Digest::SHA1.hexdigest(Time.now.to_s.split(//).sort_by {rand}.join)
  end

  def make_password_reset_code
    self.password_reset_code = Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
  end

private

  # Activates the user in the database.
  def activate!
    @activated = true
    self.activated_at = Time.now.utc
    self.activation_code = nil
    save(false)
  end

  def active?
    # the existence of an activation code means they have not activated yet
    activation_code.nil?
  end
end
