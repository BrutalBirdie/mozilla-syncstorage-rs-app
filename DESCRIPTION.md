Mozilla's Sync Storage server (syncstorage-rs) lets you store your Firefox Sync data on your own server. Bookmarks, history, passwords, open tabs, add-ons and preferences are encrypted in the browser before they are uploaded, so the server never sees them in plain text.

Sign-in still uses your Mozilla account. Only the storage of the encrypted sync data moves to your Cloudron.

### Features

* Sync for Firefox desktop and Firefox for Android
* Includes the Tokenserver that hands out storage credentials after Mozilla account sign-in
* Data is stored in PostgreSQL and included in Cloudron backups
* Option to block new accounts once your own devices are connected
