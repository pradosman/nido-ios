import { getDb } from "../../../../db";
import { profiles } from "../../../../db/schema";

export async function PUT(request: Request) {
  try {
    const body = await request.json() as { caregiverName?: string; babyName?: string; birthDate?: string };
    const caregiverName = body.caregiverName?.trim() ?? "";
    const babyName = body.babyName?.trim() ?? "";
    const birthDate = body.birthDate ?? "";
    if (!caregiverName || !babyName || !/^\d{4}-\d{2}-\d{2}$/.test(birthDate)) {
      return Response.json({ error: "Completa todos los datos" }, { status: 400 });
    }
    const db = getDb();
    const [profile] = await db.insert(profiles).values({ id: 1, caregiverName, babyName, birthDate })
      .onConflictDoUpdate({ target: profiles.id, set: { caregiverName, babyName, birthDate, updatedAt: new Date().toISOString() } })
      .returning();
    return Response.json({ profile });
  } catch (error) {
    const message = error instanceof Error ? error.message : "No se pudo guardar el perfil";
    return Response.json({ error: message }, { status: 500 });
  }
}
