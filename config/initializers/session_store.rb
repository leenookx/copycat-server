# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_copycat-server_session',
  :secret      => 'd4ba2598fc9c213cca434d80c28be413a2e449d9f71c98e988c8e09d5c1958195d64d959a8927c2121ef1b04593614c58310a3ad836dc2f9c6375bebf794dbd5'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
