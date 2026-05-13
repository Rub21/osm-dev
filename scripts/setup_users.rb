# Create dev users: admin (from env vars) and a few regular mappers for testing.
# For existing users (from restored backups), refresh their terms and status
# so dev tests can run without the "Contributor terms" prompt.

def upsert_user(name, password, roles)
  existing = User.find_by(:display_name => name)

  if existing
    existing.update!(:terms_seen => true, :terms_agreed => Time.now.utc)
    existing.activate! unless existing.active?
    puts "setup_users: '#{name}' refreshed (terms accepted, active)"
    return
  end

  u = User.new(:email => "#{name}@example.org", :display_name => name)
  u.pass_crypt = password
  u.pass_crypt_confirmation = password
  u.terms_seen = true
  u.terms_agreed = Time.now.utc
  u.save!
  u.activate!
  roles.each { |role| u.roles.create(:role => role, :granter_id => u.id) }

  puts "setup_users: '#{name}' created (roles: #{roles.any? ? roles.join(', ') : 'none'})"
end

# Admin user from env vars
admin_name = ENV["ADMIN_USER"]
admin_password = ENV["ADMIN_PASSWORD"]
if admin_name && !admin_name.empty? && admin_password && !admin_password.empty?
  upsert_user(admin_name, admin_password, %w[moderator administrator])
else
  warn "setup_users: ADMIN_USER or ADMIN_PASSWORD not set, skipping admin"
end

# Regular mappers for testing (no roles)
%w[mapper1 mapper2 mapper3].each do |name|
  upsert_user(name, "12345678", [])
end
