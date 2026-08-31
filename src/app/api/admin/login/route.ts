// POST /api/admin/login — تسجيل دخول الموظف بالـ PIN
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, fail, ok } from "@/lib/server";

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json().catch(() => null)) as { pin?: string } | null;
    const pin = (body?.pin ?? "").trim();
    if (!pin) throw new ApiError("أدخل رمز PIN", 400);
    const staff = await db.staffUser.findFirst({ where: { pin, active: true } });
    if (!staff) throw new ApiError("PIN غير صحيح", 401);
    return ok({ name: staff.name, role: staff.role });
  } catch (e) {
    return fail(e);
  }
}
