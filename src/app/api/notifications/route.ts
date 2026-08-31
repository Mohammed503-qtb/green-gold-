// GET /api/notifications?audience=ADMIN — آخر 30 إشعارًا (للإدارة)
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { fail, ok, requireStaff } from "@/lib/server";

export async function GET(req: NextRequest) {
  try {
    await requireStaff(req);
    const audience = req.nextUrl.searchParams.get("audience") ?? "ADMIN";
    const notifications = await db.notification.findMany({
      where: { audience: audience === "CUSTOMER" ? "CUSTOMER" : "ADMIN" },
      orderBy: { createdAt: "desc" },
      take: 30,
    });
    return ok({
      notifications: notifications.map((n) => ({
        id: n.id,
        audience: n.audience,
        title: n.title,
        body: n.body,
        orderCode: n.orderCode,
        read: n.read,
        createdAt: n.createdAt.toISOString(),
      })),
    });
  } catch (e) {
    return fail(e);
  }
}
