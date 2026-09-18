# OAuth apps

`apps.json` lists the OAuth 2 applications every instance should have (name, redirect URI, scopes). They are created on start, and `make apps` prints them with their client id and secret, same shape as `apps.json`:

```bash
make apps                      # local
make apps BRANCH=gpx-tracks    # server instance
```

The credentials live in `.tokens/<slug>-apps.json` (gitignored). Secrets are stored hashed in the database, so that file is the only place to read them.

One-off app, or a new secret for an existing one:

```bash
make app NAME=josm                                                     # from apps.json, new secret
make app NAME=tmp SCOPES="read_gpx" REDIRECT=urn:ietf:wg:oauth:2.0:oob # not in apps.json
```

The owner is the admin user, so any scope is allowed: `read_prefs write_prefs write_diary write_api write_changeset_comments read_gpx write_gpx write_notes write_redactions write_blocks consume_messages send_messages openid`.
