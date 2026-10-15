import { createOpaqueAppleChallenge } from "../../app/api/nido/apple-challenge.ts";
import { createAccountDeletionHandler } from "../../app/api/nido/auth/account/route.ts";

const secret = "account-deletion-fixture-secret-32-bytes";
export const accountDeletionHandler = createAccountDeletionHandler({
  challengeSecret: secret,
  verifyIdentity: async token => ({ subject: token }),
  revokeAuthorization: async () => {},
});
// Transport-only provider for existing database deletion fixtures. The dedicated
// revocation contracts assert proof rejection, provider calls and real JWT claims.
export async function appleDeletionProof(subject) {
  const challenge = await createOpaqueAppleChallenge(secret);
  return { challengeID: challenge.challengeID, identityToken: subject, authorizationCode: "fixture-code" };
}
