#!/usr/bin/env bash
workdir=/app
set -x

echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h "$POSTGRES_HOST" -p 5432; do
  sleep 2
done


restore_db() {
  export PGPASSWORD="$POSTGRES_PASSWORD"
  export PAGER=cat
  curl -s -o backup.sql "$BACKUP_FILE_URL"
  psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f backup.sql
  rm backup.sql
}

setup_admin() {
  [ -z "$ADMIN_USER" ] || [ -z "$ADMIN_PASSWORD" ] && return
  bundle exec rails runner " \
    unless User.find_by(:display_name => '$ADMIN_USER')
      u = User.new(email: '$ADMIN_USER@example.org', display_name: '$ADMIN_USER')
      u.pass_crypt = '$ADMIN_PASSWORD'
      u.pass_crypt_confirmation = '$ADMIN_PASSWORD'
      u.save!
      u.activate!
      u.roles.create(:role => 'moderator', :granter_id => u.id)
      u.roles.create(:role => 'administrator', :granter_id => u.id)
      puts 'Admin user created!'
    end"
}

#### Setting up required credentials
echo $RAILS_CREDENTIALS_YML_ENC > config/credentials.yml.enc
echo $RAILS_MASTER_KEY > config/master.key
chmod 600 config/credentials.yml.enc config/master.key

bundle install

restore_db
bundle exec rails db:migrate --trace
setup_admin
bundle exec rails jobs:work &
bundle exec rails server -b 0.0.0.0 -p 3000
