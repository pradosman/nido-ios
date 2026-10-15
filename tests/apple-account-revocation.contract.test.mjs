import assert from "node:assert/strict";
import test from "node:test";
import { createTestDatabase } from "../db/testing.ts";
import { hashAccessToken } from "../app/api/nido/auth.ts";
import { createOpaqueAppleChallenge } from "../app/api/nido/apple-challenge.ts";
import * as account from "../app/api/nido/auth/account/route.ts";

const secret = "revocation-test-challenge-secret-32-bytes";
async function fixture(run) {
  const db = await createTestDatabase();
  const token = "revocation-token-" + "x".repeat(40);
  await db.client.query("INSERT INTO users (id, apple_subject) VALUES ('revoke-user', 'apple-user')");
  await db.client.query("INSERT INTO auth_sessions (id,user_id,token_hash,expires_at) VALUES ('revoke-session','revoke-user',$1,$2)", [await hashAccessToken(token), new Date(Date.now()+600_000)]);
  const events = [];
  const handler = account.createAccountDeletionHandler({
    challengeSecret: secret,
    verifyIdentity: async token => { if (token === "bad") throw Error(); return { subject: token }; },
    revokeAuthorization: async (code, subject, nonce) => { events.push({ code, subject, nonce }); if(code === "failure") throw Error("upstream secret must not leak"); },
  });
  async function request(body, selectedHandler=handler) {
    return selectedHandler(new Request("http://nido.test/api/nido/auth/account", {method:"DELETE",headers:{authorization:`Bearer ${token}`,"content-type":"application/json"},body:JSON.stringify(body)}));
  }
  async function proof(overrides={}) {
    const challenge=await createOpaqueAppleChallenge(secret);
    return { challengeID:challenge.challengeID,identityToken:"apple-user",authorizationCode:"one-use-code",...overrides };
  }
  const users=async()=>Number((await db.client.query("SELECT count(*) AS count FROM users")).rows[0].count);
  try { await run({...db,events,handler,request,proof,users}); } finally { await db.close(); }
}
test("DELETE rejects missing, invalid and other-user Apple proof without revoke or deletion", async()=>fixture(async f=>{
  for(const [body,status] of [[{},400],[await f.proof({identityToken:"bad"}),401],[await f.proof({identityToken:"other-user"}),403]]) {
    const response=await f.request(body);assert.equal(response.status,status);assert.equal(await f.users(),1);assert.equal(f.events.length,0);
  }
}));
test("DELETE consumes fresh proof once before revocation and deletes after success",async()=>fixture(async f=>{
  const body=await f.proof();const response=await f.request(body);
  assert.equal(response.status,200);assert.deepEqual(await response.json(),{deleted:true});assert.equal(await f.users(),0);
  assert.deepEqual(f.events.map(e=>[e.code,e.subject]),[["one-use-code","apple-user"]]);assert.match(f.events[0].nonce,/^[a-f0-9]{64}$/);
}));
test("expired and previously consumed sign-in challenges cannot authorize deletion",async()=>fixture(async f=>{
  const expired=await createOpaqueAppleChallenge(secret,Date.now()-300_001);
  assert.equal((await f.request({challengeID:expired.challengeID,identityToken:"apple-user",authorizationCode:"code"})).status,401);
  const challenge=await createOpaqueAppleChallenge(secret);
  const id=JSON.parse(Buffer.from(challenge.challengeID.split('.')[0],'base64url').toString()).id;
  await f.client.query("INSERT INTO auth_challenges (id,nonce_hash,expires_at,consumed_at) VALUES ($1,$2,$3,$4)",[id,challenge.nonceHash,new Date(challenge.expiresAt),new Date()]);
  assert.equal((await f.request({challengeID:challenge.challengeID,identityToken:"apple-user",authorizationCode:"code"})).status,401);
  assert.equal(await f.users(),1);assert.equal(f.events.length,0);
}));
test("concurrent use of one deletion proof invokes Apple only once",async()=>fixture(async f=>{
  const body=await f.proof();const responses=await Promise.all([f.request(body),f.request(body)]);
  assert.deepEqual(responses.map(r=>r.status).sort(),[200,401]);assert.equal(f.events.length,1);assert.equal(await f.users(),0);
}));
test("Apple failure preserves account and replay is rejected; fresh proof can retry",async()=>fixture(async f=>{
  const failedProof=await f.proof({authorizationCode:"failure"});const failed=await f.request(failedProof);
  assert.equal(failed.status,502);assert.doesNotMatch(await failed.text(),/secret/);assert.equal(await f.users(),1);
  assert.equal((await f.request(failedProof)).status,401);assert.equal(f.events.length,1);
  assert.equal((await f.request(await f.proof())).status,200);assert.equal(await f.users(),0);
}));
test("missing server configuration fails closed",async()=>fixture(async f=>{
  const before={...process.env};for(const key of ['NIDO_APPLE_TEAM_ID','NIDO_APPLE_KEY_ID','NIDO_APPLE_PRIVATE_KEY'])delete process.env[key];
  try { assert.equal((await f.request(await f.proof(),account.DELETE)).status,503);assert.equal(await f.users(),1); } finally { Object.assign(process.env,before); }
}));
test("database failure after Apple success reports failure and fresh proof permits retry",async()=>fixture(async f=>{
  await f.client.query("CREATE FUNCTION fail_delete() RETURNS trigger AS $$ BEGIN RAISE EXCEPTION 'injected'; END; $$ LANGUAGE plpgsql");
  await f.client.query("CREATE TRIGGER fail_delete BEFORE DELETE ON users FOR EACH ROW EXECUTE FUNCTION fail_delete()");
  const response=await f.request(await f.proof());assert.equal(response.status,500);assert.deepEqual(await response.json(),{error:"Unable to delete the account"});assert.equal(await f.users(),1);assert.equal(f.events.length,1);
  await f.client.query("DROP TRIGGER fail_delete ON users");assert.equal((await f.request(await f.proof())).status,200);
}));
