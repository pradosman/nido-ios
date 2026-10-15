import { importPKCS8, SignJWT } from "jose";

type IdentityVerifier = (token: string, nonce: string) => Promise<{ subject: string }>;
type Options = {
  clientID: string;
  teamID: string;
  keyID: string;
  privateKey: string;
  verifyIdentity: IdentityVerifier;
  fetch?: typeof globalThis.fetch;
};

// Identity tokens and Nido session tokens are never valid substitutes for the
// Apple access/refresh token returned by this single-use code exchange.
export function createAppleTokenRevoker(options: Options) {
  const send = options.fetch ?? globalThis.fetch;
  return async (authorizationCode: string, expectedSubject: string, nonce: string) => {
    try {
      const now = Math.floor(Date.now() / 1_000);
      const key = await importPKCS8(options.privateKey.replace(/\\n/g, "\n"), "ES256");
      const secret = await new SignJWT({})
        .setProtectedHeader({ alg: "ES256", kid: options.keyID })
        .setIssuer(options.teamID).setSubject(options.clientID)
        .setAudience("https://appleid.apple.com").setIssuedAt(now).setExpirationTime(now + 300)
        .sign(key);
      const post = (path: string, fields: Record<string, string>) => send(`https://appleid.apple.com/auth/${path}`, {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ client_id: options.clientID, client_secret: secret, ...fields }),
        signal: AbortSignal.timeout(10_000),
        redirect: "error",
      });
      const exchange = await post("token", { code: authorizationCode, grant_type: "authorization_code" });
      if (exchange.status !== 200) throw new Error();
      const body = await exchange.json();
      if (typeof body?.id_token !== "string" || body.id_token.length > 16_384) throw new Error();
      const identity = await options.verifyIdentity(body.id_token, nonce);
      if (identity.subject !== expectedSubject) throw new Error();
      const tokenType = typeof body.refresh_token === "string" && body.refresh_token.length > 0
        ? "refresh_token" : "access_token";
      const token = body[tokenType];
      if (typeof token !== "string" || !token || token.length > 16_384) throw new Error();
      const revocation = await post("revoke", { token, token_type_hint: tokenType });
      if (revocation.status !== 200) throw new Error();
    } catch {
      // Never propagate private keys, codes, tokens or Apple's response bodies.
      throw new Error("Unable to revoke Apple authorization");
    }
  };
}
