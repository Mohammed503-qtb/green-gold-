// GET /api/admin/audit — آخر 100 سجل تدقيق (OWNER/MANAGER)
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { fail, ok, requireStaff } from "@/lib/server";

export async function GET(req: NextRequest) {
  try {
    await requireStaff(req, "viewAudit");
    const logs = await db.auditLog.findMany({
      orderBy: { createdAt: "desc" },
      take: 100,
    });
    return ok({
      logs: logs.map((l) => ({
        id: l.id,
        actorName: l.actorName,
        actorRole: l.actorRole,
        action: l.action,
        entityType: l.entityType,
        entityId: l.entityId,
        before: l.before,
        after: l.after,
        createdAt: l.createdAt.toISOString(),
      })),
    });
  } catch (e) {
    return fail(e);
  }
}
