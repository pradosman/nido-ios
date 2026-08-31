export async function GET() {
  return Response.json({ canCreateHousehold: true, canJoinWithInvitation: true });
}
