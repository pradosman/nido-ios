import assert from "node:assert/strict";
import test from "node:test";
import { generateKeyPair, exportPKCS8, jwtVerify } from "jose";
import { createAppleTokenRevoker } from "../app/api/nido/apple-token-revocation.ts";

async function fixture(responses, verifyIdentity=async()=>({subject:"apple-user"})) {
 const {privateKey,publicKey}=await generateKeyPair("ES256",{extractable:true});const requests=[];
 const revoker=createAppleTokenRevoker({clientID:"com.example.Nido",teamID:"TEAM123456",keyID:"KEY1234567",privateKey:await exportPKCS8(privateKey),verifyIdentity,fetch:async(url,init)=>{requests.push({url:String(url),init});const response=responses.shift();if(response instanceof Error)throw response;return response;}});
 return {revoke:revoker,requests,publicKey};
}
test("exchanges code and revokes refresh token with verifiable ES256 client secret",async()=>{
 const f=await fixture([Response.json({id_token:"returned-identity",refresh_token:"refresh-secret"}),new Response(null,{status:200})]);
 await f.revoke("code-secret","apple-user","a".repeat(64));assert.deepEqual(f.requests.map(x=>x.url),["https://appleid.apple.com/auth/token","https://appleid.apple.com/auth/revoke"]);
 const exchange=new URLSearchParams(f.requests[0].init.body);assert.equal(exchange.get("code"),"code-secret");assert.equal(exchange.get("grant_type"),"authorization_code");assert.equal(exchange.get("client_id"),"com.example.Nido");
 const {payload,protectedHeader}=await jwtVerify(exchange.get("client_secret"),f.publicKey,{issuer:"TEAM123456",audience:"https://appleid.apple.com",subject:"com.example.Nido",algorithms:["ES256"]});assert.equal(protectedHeader.kid,"KEY1234567");assert.ok(payload.exp-payload.iat<=300);
 const revoke=new URLSearchParams(f.requests[1].init.body);assert.equal(revoke.get("token"),"refresh-secret");assert.equal(revoke.get("token_type_hint"),"refresh_token");assert.equal(f.requests[1].init.headers["content-type"],"application/x-www-form-urlencoded");
});
test("access token fallback is valid, but absent or mismatched identity never revokes",async()=>{
 const good=await fixture([Response.json({id_token:"id",access_token:"access"}),new Response(null,{status:200})]);await good.revoke("code","apple-user","a".repeat(64));assert.equal(new URLSearchParams(good.requests[1].init.body).get("token_type_hint"),"access_token");
 for(const body of [{id_token:"id"},{refresh_token:"refresh"},{id_token:"id",refresh_token:"refresh"}]){
 const f=await fixture([Response.json(body)],async()=>({subject:"someone-else"}));await assert.rejects(f.revoke("code","apple-user","a".repeat(64)));assert.equal(f.requests.length,1);
 }
});
test("exchange and revocation errors never report success or leak Apple response/token",async()=>{
 for(const responses of [[new Response("sensitive-upstream",{status:400})],[new Error("sensitive-upstream")],[Response.json({id_token:"id",refresh_token:"sensitive-token"}),new Response("sensitive-upstream",{status:500})]]){
  const f=await fixture(responses);await assert.rejects(f.revoke("sensitive-code","apple-user","a".repeat(64)),error=>!String(error).includes("sensitive"));
 }
});
