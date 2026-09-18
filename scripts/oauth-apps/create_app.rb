# Create the OAuth 2 applications of this instance and save their credentials.
#
#   apps.json (this folder)            what we want: name -> redirect_uri, scopes
#   /tokens/<slug>-apps.json           what exists: same entries plus client_id and client_secret
#                                      (./.tokens/<slug>-apps.json on the host, gitignored)
#
# Without APP_NAME it creates every app of apps.json that is not in the tokens
# file yet, so it is safe to run on every start. With APP_NAME it creates (or
# replaces, with a new secret) that one app; SCOPES and REDIRECT_URI override
# apps.json. Secrets are stored hashed, so they are only readable at creation.

require "json"

slug = ENV["INSTANCE_SLUG"] || "osmdev"
wanted_file = File.join(__dir__, "apps.json")
apps_file = "/tokens/#{slug}-apps.json"
owner_name = ENV["APP_OWNER"].presence || ENV["ADMIN_USER"].presence || "admin"

owner = User.find_by(:display_name => owner_name)
abort "owner user '#{owner_name}' not found" if owner.nil?

wanted = File.exist?(wanted_file) ? JSON.parse(File.read(wanted_file)) : {}
apps = File.exist?(apps_file) ? JSON.parse(File.read(apps_file)) : {}

def create_app(name, redirect_uri, scopes, owner)
  full_name = "osm-dev app #{name}"

  Oauth2Application.where(:name => full_name).find_each do |old|
    Doorkeeper::AccessToken.where(:application_id => old.id).destroy_all
    old.destroy
  end

  app = Oauth2Application.create!(:name => full_name,
                                  :redirect_uri => redirect_uri,
                                  :confidential => true,
                                  :scopes => scopes,
                                  :owner => owner)

  { "client_id" => app.uid,
    "client_secret" => app.plaintext_secret,
    "redirect_uri" => redirect_uri,
    "scopes" => scopes }
end

name = ENV["APP_NAME"].to_s.strip

if name.empty?
  # Every start: create what is missing, keep the rest as it is.
  missing = wanted.keys - apps.keys
  missing.each do |app_name|
    spec = wanted[app_name]
    apps[app_name] = create_app(app_name, spec["redirect_uri"], spec["scopes"], owner)
    puts "created OAuth app '#{app_name}'"
  end
  puts "OAuth apps up to date (#{apps.keys.join(', ')})" if missing.empty?
else
  spec = wanted[name] || {}
  redirect_uri = ENV["REDIRECT_URI"].presence || spec["redirect_uri"] || "urn:ietf:wg:oauth:2.0:oob"
  scopes = ENV["SCOPES"].presence || spec["scopes"] || "read_prefs write_gpx read_gpx"
  replaced = apps.key?(name)
  apps[name] = create_app(name, redirect_uri, scopes, owner)
  puts "#{replaced ? 'replaced' : 'created'} OAuth app '#{name}'"
  apps[name].each { |k, v| puts "#{k.upcase}=#{v}" }
end

File.write(apps_file, JSON.pretty_generate(apps))
puts "saved in #{apps_file}"
