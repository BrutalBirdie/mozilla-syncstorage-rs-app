# Firefox Sync Server for Cloudron

[![release](https://github.com/BrutalBirdie/mozilla-syncstorage-rs-app/actions/workflows/release.yml/badge.svg)](https://github.com/BrutalBirdie/mozilla-syncstorage-rs-app/actions/workflows/release.yml)

[syncstorage-rs](https://github.com/mozilla-services/syncstorage-rs) packaged for Cloudron. Store your Firefox Sync data on your own server while signing in with your Mozilla account.

* Syncstorage and Tokenserver in one app, backed by the Cloudron PostgreSQL addon
* Data is included in Cloudron backups
* Expired records are purged daily

## Install

In Cloudron, open 'Add custom app' and enter `https://raw.githubusercontent.com/BrutalBirdie/mozilla-syncstorage-rs-app/main/CloudronVersions.json`.

## Connect Firefox

Do this before signing in to your Mozilla account. Replace `sync.example.com` with your app domain.

* **Desktop**: in `about:config` set `identity.sync.tokenserver.uri` to `https://sync.example.com/1.0/sync/1.5` and restart Firefox.
* **Android**: **Settings → About Firefox**, tap the logo five times, then **Settings → Sync Debug → Custom Sync server**: `https://sync.example.com/1.0/sync/1.5`.

Check `about:sync-log` on desktop if syncing does not start.

To stop other Mozilla accounts from using your server once your devices are connected, set `SYNC_TOKENSERVER__ALLOW_NEW_USERS=false` in `/app/data/env.sh` and restart the app.

Changes per version are in the [releases](https://github.com/BrutalBirdie/mozilla-syncstorage-rs-app/releases).
