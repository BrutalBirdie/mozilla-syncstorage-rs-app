This app has no web interface. Point Firefox at it **before** signing in to your Mozilla account:

* **Desktop**: open `about:config`, set `identity.sync.tokenserver.uri` to `$CLOUDRON-APP-ORIGIN/1.0/sync/1.5` and restart Firefox.
* **Android**: open **Settings → About Firefox**, tap the logo five times, go back to **Settings → Sync Debug** and set **Custom Sync server** to `$CLOUDRON-APP-ORIGIN/1.0/sync/1.5`.

If you are already signed in, sign out, change the setting and sign in again.

Anyone with a Mozilla account who knows this URL can store data here. After your devices are connected, set `SYNC_TOKENSERVER__ALLOW_NEW_USERS=false` in `/app/data/env.sh` with the File Manager and restart the app.
