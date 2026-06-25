# Generate OAuth access tokens for the dev users created by setup_users.rb.
# Writes a JSON mapping {username => token} to /docker/scripts/.tokens.json.

require "json"

slug = ENV["INSTANCE_SLUG"] || "default"
tokens_file = "/docker/scripts/.tokens-#{slug}.json"

usernames = [ENV["ADMIN_USER"], "Rub21", "mapper1", "mapper2", "mapper3"].compact

# Full set of OSM OAuth scopes (no wildcard exists; list them all explicitly)
scopes = "read_prefs write_prefs write_diary write_api read_gpx write_gpx " \
         "write_notes write_redactions read_email consume_messages send_messages openid"

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
                                  :scopes => scopes,
                                  :owner_type => "User",
                                  :owner_id => user.id)

  token = Doorkeeper::AccessToken.create!(:application => app,
                                          :resource_owner_id => user.id,
                                          :scopes => scopes)

  tokens[name] = token.token
end

File.write(tokens_file, JSON.pretty_generate(tokens))
puts "OAuth tokens written to #{tokens_file} (#{tokens.keys.join(', ')})"
