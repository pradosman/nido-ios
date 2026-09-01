import {
  createLocalJWKSet,
  createRemoteJWKSet,
  jwtVerify,
  type JSONWebKeySet,
  type JWTVerifyGetKey,
} from "jose";

const APPLE_ISSUER = "https://appleid.apple.com";
const APPLE_JWKS_URL = new URL("https://appleid.apple.com/auth/keys");
const MAX_TOKEN_AGE_SECONDS = 600;

type AppleVerifierOptions = {
  audience: string;
  keySource?: JWTVerifyGetKey;
  jwks?: JSONWebKeySet;
  now?: () => Date;
  maxTokenAgeSeconds?: number;
};

export function createAppleIdentityVerifier(options: AppleVerifierOptions) {
  const audience = options.audience.trim();
  if (!audience) throw new Error("Apple audience is required");
  const keySource = options.keySource
    ?? (options.jwks ? createLocalJWKSet(options.jwks) : createRemoteJWKSet(APPLE_JWKS_URL));
  const now = options.now ?? (() => new Date());
  const maxTokenAgeSeconds = options.maxTokenAgeSeconds ?? MAX_TOKEN_AGE_SECONDS;

  return async (identityToken: string, expectedNonce: string) => {
    if (!identityToken || !/^[a-f0-9]{64}$/i.test(expectedNonce)) {
      throw new Error("Invalid Apple token input");
    }
    const currentDate = now();
    const { payload } = await jwtVerify(identityToken, keySource, {
      algorithms: ["RS256"],
      issuer: APPLE_ISSUER,
      audience,
      currentDate,
      maxTokenAge: `${maxTokenAgeSeconds}s`,
    });
    const issuedAt = payload.iat;
    const currentSeconds = Math.floor(currentDate.getTime() / 1000);
    if (
      typeof payload.sub !== "string"
      || payload.sub.length < 1
      || payload.sub.length > 255
      || payload.nonce !== expectedNonce
      || payload.aud !== audience
      || typeof issuedAt !== "number"
      || typeof payload.exp !== "number"
      || issuedAt > currentSeconds + 30
      || currentSeconds - issuedAt > maxTokenAgeSeconds
      || payload.exp > currentSeconds + maxTokenAgeSeconds
    ) {
      throw new Error("Invalid Apple identity claims");
    }
    return { subject: payload.sub };
  };
}
