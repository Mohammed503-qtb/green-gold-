// GET /api/settings/public — إعدادات المتجر العامة
import { fail, getPublicSettings, ok } from "@/lib/server";

export async function GET() {
  try {
    const settings = await getPublicSettings();
    return ok(settings);
  } catch (e) {
    return fail(e);
  }
}
