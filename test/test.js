import { app, cloudronCli, goto, setupBrowser, takeScreenshot, teardownBrowser } from '@cloudron/charlie';
import assert from 'node:assert/strict';

/* global it, describe, before, after, afterEach */

describe('Application life cycle test', function () {
    const BSO_ID = 'charlie-' + Math.floor((Math.random() * 1000) + 1);

    before(setupBrowser);
    after(teardownBrowser);

    afterEach(async function () {
        await takeScreenshot(this.currentTest);
    });

    async function checkHeartbeat() {
        const response = await fetch(`https://${app.fqdn}/__heartbeat__`);
        assert.equal(response.status, 200);
        assert.equal((await response.json()).database, 'Ok');
    }

    async function checkTokenserverNeedsAuth() {
        const response = await fetch(`https://${app.fqdn}/1.0/sync/1.5`);
        assert.equal(response.status, 401);
    }

    function checkNode() {
        assert.equal(cloudronCli.postgresql('SELECT string_agg(node, \',\') FROM nodes').trim(), `https://${app.fqdn}`);
    }

    function addRecord() {
        cloudronCli.postgresql(`INSERT INTO user_collections (user_id, collection_id, modified) VALUES (1, 1, now()) ON CONFLICT DO NOTHING;
            INSERT INTO bsos (user_id, collection_id, bso_id, payload, modified, expiry) VALUES (1, 1, '${BSO_ID}', '{}', now(), now() + interval '30 days')`);
    }

    function checkRecord() {
        assert.equal(cloudronCli.postgresql(`SELECT bso_id FROM bsos WHERE bso_id = '${BSO_ID}'`).trim(), BSO_ID);
    }

    async function checkApiDocs() {
        await goto(`https://${app.fqdn}/swagger-ui/`, 'Syncstorage-rs API');
    }

    it('install app', cloudronCli.install);
    it('is healthy', checkHeartbeat);
    it('tokenserver needs auth', checkTokenserverNeedsAuth);
    it('has node for app domain', checkNode);
    it('can show api docs', checkApiDocs);
    it('can add record', addRecord);
    it('can run purge task', () => cloudronCli.exec('/app/pkg/purge.sh'));
    it('keeps unexpired record', checkRecord);

    it('restart app', cloudronCli.restart);
    it('is healthy', checkHeartbeat);
    it('keeps record', checkRecord);

    it('backup app', cloudronCli.createBackup);
    it('restore app', cloudronCli.restoreFromLatestBackup);
    it('is healthy', checkHeartbeat);
    it('keeps record', checkRecord);

    it('move to different location', cloudronCli.changeLocation);
    it('is healthy', checkHeartbeat);
    it('has node for new domain', checkNode);
    it('keeps record', checkRecord);

    it('uninstall app', cloudronCli.uninstall);
});
