import { createOpaqueAppleChallenge } from "../../../apple-challenge.ts";
import { appleAudience, authBucketSecret } from "../../../runtime-config.ts";

export async function POST() {
  try {
    const audience = appleAudience();
    const secret = authBucketSecret();
    if (!audience || !secret) {
      return Response.json({ error: "Apple authentication is unavailable" }, { status: 503 });
    }
    const challenge = await createOpaqueAppleChallenge(secret);
    return Response.json({
      challengeID: challenge.challengeID,
      nonce: challenge.nonce,
      expiresAt: new Date(challenge.expiresAt).toISOString(),
    }, { status: 201 });
  } catch {
    return Response.json({ error: "Unable to issue an authentication challenge" }, { status: 500 });
  }
}
