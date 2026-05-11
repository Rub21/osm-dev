# Generate OAuth access tokens for the dev users created by setup_users.rb.
# Writes a JSON mapping {username => token} to /docker/scripts/.tokens.json.

require "json"

usernames = [ENV["ADMIN_USER"], "mapper1", "mapper2", "mapper3"].compact

# Wipe out any previous osm-dev test apps and their tokens, then sync the
# auto-increment sequences (out of sync after restore_db loads a SQL backup)
old_apps = Doorkeeper::Application.where("name LIKE ?", "osm-dev test%")
Doorkeeper::AccessToken.where(:application_id => old_apps.ids).destroy_all
old_apps.destroy_all
ActiveRecord::Base.connection.reset_pk_sequence!("oauth_applications")
ActiveRecord::Base.connection.reset_pk_sequence!("oauth_access_tokens")

tokens = {}

usernames.each do |name|
  user = User.find_by(:display_name => name)
  next if user.nil?

  app_name = "osm-dev test #{name}"

  app = Oauth2Application.create!(:name => app_name,
                                  :redirect_uri => "urn:ietf:wg:oauth:2.0:oob",
                                  :confidential => true,
                                  :scopes => "read_prefs write_gpx",
                                  :owner_type => "User",
                                  :owner_id => user.id)

  token = Doorkeeper::AccessToken.create!(:application => app,
                                          :resource_owner_id => user.id,
                                          :scopes => "read_prefs write_gpx")

  tokens[name] = token.token
end

File.write("/docker/scripts/.tokens.json", JSON.pretty_generate(tokens))
puts "OAuth tokens written to /docker/scripts/.tokens.json (#{tokens.keys.join(', ')})"
