// GET /api/checkout-data — المناطق وطرق الدفع ومعلومات المتجر
import { db } from "@/lib/db";
import { fail, getPublicSettings, ok, releaseExpiredReservations } from "@/lib/server";
import type { PaymentType } from "@/lib/contracts";

export async function GET() {
  try {
    await releaseExpiredReservations();
    const [zones, methods, settings] = await Promise.all([
      db.deliveryZone.findMany({ where: { active: true }, orderBy: { fee: "asc" } }),
      db.paymentMethod.findMany({ where: { active: true }, orderBy: { sort: "asc" } }),
      getPublicSettings(),
    ]);
    return ok({
      zones: zones.map((z) => ({ id: z.id, name: z.name, fee: z.fee })),
      methods: methods.map((m) => ({
        id: m.id,
        name: m.name,
        type: m.type as PaymentType,
        accountName: m.accountName,
        institution: m.institution,
        accountNumber: m.accountNumber,
        instructions: m.instructions,
      })),
      storeName: settings.storeName,
      whatsapp: settings.whatsapp,
    });
  } catch (e) {
    return fail(e);
  }
}
