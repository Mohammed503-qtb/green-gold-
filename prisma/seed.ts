// ============================================================
// GREEN GOLD | ذهب أخضر — Seed بيانات حية واقعية
// تشغيل: cd /home/z/my-project && bun prisma/seed.ts
// ============================================================
import { PrismaClient } from "@prisma/client";

const db = new PrismaClient();

const mins = (n: number) => new Date(Date.now() - n * 60_000);
const hours = (n: number) => new Date(Date.now() - n * 3_600_000);

const IMG = [
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/9e9a4cad3809.jpg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/56859543d015.jpg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/6720e2b28f1b.jpg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/cabcea51aa00.jpg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/c5b1b967ffa2.jpg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/55c1a989e6e1.jpg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/69dddb97d7fe.jpg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/19c16478e457.jpg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/9135347cec04.jpeg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/d63c956225cb.jpg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/265eb76b3cf2.jpg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/eff5da3d7d60.jpg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/9d855a09ddfe.jpg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/681cc4fa2794.jpg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/1d98631a4fa0.jpg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/a72bb3fca964.jpeg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/894584cedce8.jpg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/f2206204b50e.jpg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/f2d57b8a27e5.jpg",
  "https://z-cdn.chatglm.cn/image-search-mcp/images-ppt/0d25cdeee700.jpg",
];

async function main() {
  console.log("🌱 بدء تهيئة بيانات ذهب أخضر...");

  // ── تنظيف (بترتيب يحترم المفاتيح الأجنبية) ──
  await db.notification.deleteMany();
  await db.auditLog.deleteMany();
  await db.review.deleteMany();
  await db.deliveryOrder.deleteMany();
  await db.payment.deleteMany();
  await db.inventoryReservation.deleteMany();
  await db.inventoryMovement.deleteMany();
  await db.orderStatusHistory.deleteMany();
  await db.orderItem.deleteMany();
  await db.order.deleteMany();
  await db.address.deleteMany();
  await db.customer.deleteMany();
  await db.paymentMethod.deleteMany();
  await db.batchQuality.deleteMany();
  await db.batchMedia.deleteMany();
  await db.productBatch.deleteMany();
  await db.product.deleteMany();
  await db.deliveryZone.deleteMany();
  await db.staffUser.deleteMany();
  await db.setting.deleteMany();

  // ── الموظفون ──
  await db.staffUser.createMany({
    data: [
      { name: "المالك", pin: "1234", role: "OWNER" },
      { name: "أبو عبدالله", pin: "2345", role: "MANAGER" },
      { name: "سالم", pin: "3456", role: "STAFF" },
      { name: "فهد", pin: "4567", role: "DELIVERY" },
    ],
  });

  // ── المناطق ──
  const [crater, muala, mansoura, tawahi, shaikman] = await Promise.all(
    [
      { name: "كريتر", fee: 800 },
      { name: "المعلا", fee: 1000 },
      { name: "المنصورة / الشعبات", fee: 1200 },
      { name: "التواهي", fee: 1500 },
      { name: "شيخ عثمان", fee: 1000 },
    ].map((z) => db.deliveryZone.create({ data: z }))
  );

  // ── طرق الدفع ──
  const bank = await db.paymentMethod.create({
    data: {
      name: "تحويل بنكي — بنك الكريمي",
      type: "BANK",
      accountName: "ذهب أخضر للتجارة",
      institution: "بنك الكريمي",
      accountNumber: "4123885",
      instructions: "حوّل المبلغ ثم أرفق رقم العملية أو صورة الإشعار.",
      sort: 1,
    },
  });
  const wallet = await db.paymentMethod.create({
    data: {
      name: "محفظة جوالي",
      type: "WALLET",
      accountName: "ذهب أخضر",
      institution: "جوالي",
      accountNumber: "0712345678",
      instructions: "حوّل عبر محفظة جوالي ثم أدخل رقم العملية.",
      sort: 2,
    },
  });
  await db.paymentMethod.create({
    data: {
      name: "الدفع عند الاستلام",
      type: "COD",
      instructions: "ادفع نقدًا للمندوب عند الاستلام — لا حاجة لإثبات الآن.",
      sort: 3,
    },
  });

  // ── المنتجات ──
  const [haraz, hamadi, ansi, jabal, waila] = await Promise.all(
    [
      { name: "حراز", origin: "حراز — إب" },
      { name: "حمادي", origin: "حمادي — ذمار" },
      { name: "العنسي", origin: "العنسي — وصابين" },
      { name: "جبل أرحب", origin: "جبل أرحب — صنعاء" },
      { name: "ويلة", origin: "ويلة — بني ضبيان" },
    ].map((p) => db.product.create({ data: p }))
  );

  // ── الدفعات (10 نشطة + مخفية + نافدة) ──
  const ymd = (() => {
    const d = new Date();
    return `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, "0")}${String(d.getDate()).padStart(2, "0")}`;
  })();
  const seq = { HZ: 0, HM: 0, AN: 0, JA: 0, WL: 0 };
  const code = (prefix: keyof typeof seq) =>
    `${prefix}-${ymd}-${String(++seq[prefix]).padStart(2, "0")}`;

  interface BatchSpec {
    product: typeof haraz;
    prefix: keyof typeof seq;
    grade: string;
    price: number;
    totalQty: number;
    imgs: string[];
    quality?: [number, number, number, number];
    desc: string;
    capturedAt: Date;
    status?: string;
    soldQty?: number;
  }

  const specs: BatchSpec[] = [
    { product: haraz, prefix: "HZ", grade: "PREMIUM", price: 15000, totalQty: 20, imgs: [IMG[0], IMG[1]], quality: [9, 9, 8, 9], desc: "حراز فاخر درجة أولى — حزم كبيرة ونضارة عالية، مصوّر لحظة وصوله من المزرعة.", capturedAt: mins(75) },
    { product: haraz, prefix: "HZ", grade: "EXCELLENT", price: 11000, totalQty: 30, imgs: [IMG[2], IMG[3]], quality: [8, 7, 8, 8], desc: "حراز ممتاز — توازن ممتاز بين السعر والجودة.", capturedAt: mins(70) },
    { product: hamadi, prefix: "HM", grade: "PREMIUM", price: 14000, totalQty: 15, imgs: [IMG[4], IMG[5]], quality: [9, 8, 9, 8], desc: "حمادي فاخر — كثافة عالية وأوراق صغيرة.", capturedAt: mins(60) },
    { product: hamadi, prefix: "HM", grade: "EXCELLENT", price: 9500, totalQty: 35, imgs: [IMG[6], IMG[7]], quality: [7, 8, 7, 8], desc: "حمادي ممتاز — خيار يومي موثوق.", capturedAt: mins(55) },
    { product: ansi, prefix: "AN", grade: "EXCELLENT", price: 8000, totalQty: 40, imgs: [IMG[8], IMG[9]], quality: [8, 7, 7, 7], desc: "عنسي ممتاز — من وصابين، طعم معتدل.", capturedAt: mins(50) },
    { product: ansi, prefix: "AN", grade: "ECONOMIC", price: 4500, totalQty: 45, imgs: [IMG[10], IMG[11]], quality: [6, 6, 7, 6], desc: "عنسي اقتصادي — أفضل قيمة مقابل السعر.", capturedAt: mins(45) },
    { product: jabal, prefix: "JA", grade: "EXCELLENT", price: 9000, totalQty: 25, imgs: [IMG[12], IMG[13]], quality: [8, 8, 7, 8], desc: "جبل أرحب ممتاز — طازج من مزارع أرحب.", capturedAt: hours(26) },
    { product: jabal, prefix: "JA", grade: "ECONOMIC", price: 5000, totalQty: 30, imgs: [IMG[14], IMG[15]], quality: [6, 5, 6, 6], desc: "جبل أرحب اقتصادي — مناسب للاستهلاك اليومي.", capturedAt: hours(26) },
    { product: waila, prefix: "WL", grade: "PREMIUM", price: 12000, totalQty: 4, imgs: [IMG[16], IMG[17]], quality: [9, 9, 9, 9], desc: "ويلة فاخر — كمية محدودة جدًا، حجز سريع.", capturedAt: mins(40) },
    { product: waila, prefix: "WL", grade: "ECONOMIC", price: 3000, totalQty: 28, imgs: [IMG[18], IMG[19]], quality: [5, 6, 5, 6], desc: "ويلة اقتصادي — للعزايم اليومية.", capturedAt: hours(25) },
    { product: hamadi, prefix: "HM", grade: "ECONOMIC", price: 4000, totalQty: 10, imgs: [IMG[3], IMG[14]], quality: [5, 5, 6, 5], desc: "حمادي اقتصادي — دفعة قيد المراجعة (مخفية مؤقتًا).", capturedAt: hours(24), status: "HIDDEN" },
    { product: waila, prefix: "WL", grade: "EXCELLENT", price: 7000, totalQty: 3, imgs: [IMG[19], IMG[16]], quality: [7, 8, 7, 8], desc: "ويلة ممتاز — نفدت بالكامل خلال ساعة.", capturedAt: hours(27), status: "SOLD_OUT" },
  ];

  const batches: Record<string, { id: string; code: string; name: string; grade: string; price: number; img: string }> = {};
  for (const s of specs) {
    const batchCode = code(s.prefix);
    const created = await db.productBatch.create({
      data: {
        batchCode,
        productId: s.product.id,
        grade: s.grade,
        price: s.price,
        totalQty: s.totalQty,
        soldQty: s.soldQty ?? 0,
        status: s.status ?? "ACTIVE",
        capturedAt: s.capturedAt,
        description: s.desc,
        createdAt: s.capturedAt,
        updatedAt: s.capturedAt,
      },
    });
    await db.batchMedia.createMany({
      data: s.imgs.map((url, i) => ({
        batchId: created.id,
        url,
        type: "IMAGE",
        isMain: i === 0,
        sort: i,
      })),
    });
    if (s.quality) {
      await db.batchQuality.create({
        data: {
          batchId: created.id,
          freshness: s.quality[0],
          density: s.quality[1],
          fullness: s.quality[2],
          appearance: s.quality[3],
        },
      });
    }
    await db.inventoryMovement.create({
      data: {
        batchId: created.id,
        qty: s.totalQty,
        type: "ADD",
        note: `إدخال الدفعة ${batchCode}`,
        actor: "المالك",
        createdAt: s.capturedAt,
      },
    });
    batches[batchCode] = {
      id: created.id,
      code: batchCode,
      name: s.product.name,
      grade: s.grade,
      price: s.price,
      img: s.imgs[0],
    };
  }
  const B = Object.values(batches);
  // B[0]=HZ-PREMIUM, B[1]=HZ-EXCELLENT, B[2]=HM-PREMIUM, B[3]=HM-EXCELLENT,
  // B[4]=AN-EXCELLENT, B[5]=AN-ECONOMIC, B[6]=JA-EXCELLENT, B[7]=JA-ECONOMIC,
  // B[8]=WL-PREMIUM(qty4), B[9]=WL-ECONOMIC, B[10]=HM-HIDDEN, B[11]=WL-SOLDOUT

  // ── العملاء ──
  const [ahmed, mohammed, abdullah, sami, waleed] = await Promise.all([
    { name: "أحمد المقطري", phone: "770011223" },
    { name: "محمد الشميري", phone: "770044455" },
    { name: "عبدالله باشا", phone: "770077788" },
    { name: "سامي الحكيمي", phone: "770033344" },
    { name: "وليد الصبري", phone: "770055566" },
  ].map((c) => db.customer.create({ data: c })));
  await db.address.create({
    data: {
      customerId: ahmed.id,
      label: "المنزل",
      zoneId: crater.id,
      addressText: "كريتر — جار المؤتمر، عمارة النور، الدور الثاني",
      notes: "اتصل قبل الوصول",
    },
  });
  await db.address.create({
    data: {
      customerId: mohammed.id,
      label: "العمل",
      zoneId: muala.id,
      addressText: "المعلا — شارع الستين، مقابل صيدلية الشفاء",
    },
  });

  const bankSnapshot = JSON.stringify({
    id: bank.id, name: bank.name, type: "BANK",
    accountName: bank.accountName, institution: bank.institution, accountNumber: bank.accountNumber,
  });
  const walletSnapshot = JSON.stringify({
    id: wallet.id, name: wallet.name, type: "WALLET",
    accountName: wallet.accountName, institution: wallet.institution, accountNumber: wallet.accountNumber,
  });

  // مُنشئ طلبات تجريبية متسقة مع معادلات المخزون
  async function seedOrder(opts: {
    code: string;
    customer: typeof ahmed;
    batch: (typeof B)[number];
    qty: number;
    zone: typeof crater;
    addressText: string;
    createdAt: Date;
    note?: string;
    history: { to: string; actor: string; note?: string; at: Date }[];
    payment: {
      status: string;
      snapshot?: string;
      methodId?: string;
      ref?: string;
      proof?: string;
      submittedAt?: Date;
      verifiedAt?: Date;
      verifiedBy?: string;
      rejectReason?: string;
    };
    reservation: { status: string; expiresAt: Date };
    delivery?: {
      status: string; driver: string; otp: string;
      assignedAt?: Date; deliveredAt?: Date; otpVerifiedAt?: Date; createdAt: Date;
    };
    movements?: { type: string; qty: number; at: Date; actor: string }[];
    cancelRelease?: boolean;
  }) {
    const { customer, batch, qty, zone } = opts;
    const itemsTotal = batch.price * qty;
    const total = itemsTotal + zone.fee;
    const order = await db.order.create({
      data: {
        orderCode: opts.code,
        customerId: customer.id,
        status: opts.history[opts.history.length - 1].to,
        itemsTotal,
        deliveryFee: zone.fee,
        total,
        zoneId: zone.id,
        addressText: opts.addressText,
        customerName: customer.name,
        phone: customer.phone,
        note: opts.note ?? null,
        createdAt: opts.createdAt,
        updatedAt: opts.history[opts.history.length - 1].at,
      },
    });
    await db.orderItem.create({
      data: {
        orderId: order.id,
        batchId: batch.id,
        productName: batch.name,
        batchCode: batch.code,
        grade: batch.grade,
        unitPrice: batch.price,
        qty,
        lineTotal: itemsTotal,
        mainImage: batch.img,
      },
    });
    for (const h of opts.history) {
      await db.orderStatusHistory.create({
        data: {
          orderId: order.id,
          fromStatus: null,
          toStatus: h.to,
          actor: h.actor,
          note: h.note ?? null,
          createdAt: h.at,
        },
      });
    }
    // تصحيح fromStatus لتسلسل حقيقي
    const all = await db.orderStatusHistory.findMany({
      where: { orderId: order.id },
      orderBy: { createdAt: "asc" },
    });
    for (let i = 1; i < all.length; i++) {
      await db.orderStatusHistory.update({
        where: { id: all[i].id },
        data: { fromStatus: all[i - 1].toStatus },
      });
    }
    await db.payment.create({
      data: {
        orderId: order.id,
        methodId: opts.payment.methodId ?? null,
        methodSnapshot: opts.payment.snapshot ?? "{}",
        amount: total,
        status: opts.payment.status,
        transactionRef: opts.payment.ref ?? null,
        proofUrl: opts.payment.proof ?? null,
        submittedAt: opts.payment.submittedAt ?? null,
        verifiedAt: opts.payment.verifiedAt ?? null,
        verifiedBy: opts.payment.verifiedBy ?? null,
        rejectReason: opts.payment.rejectReason ?? null,
        createdAt: opts.createdAt,
      },
    });
    await db.inventoryReservation.create({
      data: {
        batchId: batch.id,
        orderId: order.id,
        qty,
        status: opts.reservation.status,
        expiresAt: opts.reservation.expiresAt,
        createdAt: opts.createdAt,
      },
    });
    // محاسبة المخزون: محجوز ما دام الحجز نشطًا، مبيع عند الاستهلاك
    if (opts.reservation.status === "ACTIVE") {
      await db.productBatch.update({
        where: { id: batch.id },
        data: { reservedQty: { increment: qty } },
      });
    } else if (opts.reservation.status === "CONSUMED") {
      await db.productBatch.update({
        where: { id: batch.id },
        data: { soldQty: { increment: qty } },
      });
    }
    if (opts.delivery) {
      await db.deliveryOrder.create({
        data: {
          orderId: order.id,
          status: opts.delivery.status,
          driverName: opts.delivery.driver,
          otp: opts.delivery.otp,
          assignedAt: opts.delivery.assignedAt ?? null,
          deliveredAt: opts.delivery.deliveredAt ?? null,
          otpVerifiedAt: opts.delivery.otpVerifiedAt ?? null,
          createdAt: opts.delivery.createdAt,
        },
      });
    }
    for (const m of opts.movements ?? []) {
      await db.inventoryMovement.create({
        data: {
          batchId: batch.id,
          qty: m.qty,
          type: m.type,
          orderId: order.id,
          note: `طلب ${opts.code}`,
          actor: m.actor,
          createdAt: m.at,
        },
      });
    }
    return order;
  }

  // ── الطلبات التجريبية السبعة ──

  // 1) أحمد — بانتظار الدفع (حجز نشط 30 دقيقة)
  const o1 = await seedOrder({
    code: "ZG-731204",
    customer: ahmed,
    batch: B[0],
    qty: 1,
    zone: crater,
    addressText: "كريتر — جار المؤتمر، عمارة النور، الدور الثاني",
    createdAt: mins(12),
    note: "الاتصال قبل الوصول بربع ساعة",
    history: [{ to: "PENDING_PAYMENT", actor: "CUSTOMER", note: "تم إنشاء الطلب", at: mins(12) }],
    payment: { status: "UNPAID" },
    reservation: { status: "ACTIVE", expiresAt: mins(-18) },
    movements: [{ type: "RESERVE", qty: -1, at: mins(12), actor: "CUSTOMER" }],
  });

  // 2) محمد — إثبات دفع بانتظار التحقق
  const o2 = await seedOrder({
    code: "ZG-582917",
    customer: mohammed,
    batch: B[3],
    qty: 2,
    zone: muala,
    addressText: "المعلا — شارع الستين، مقابل صيدلية الشفاء",
    createdAt: mins(40),
    history: [
      { to: "PENDING_PAYMENT", actor: "CUSTOMER", note: "تم إنشاء الطلب", at: mins(40) },
      { to: "PAYMENT_SUBMITTED", actor: "CUSTOMER", note: "إثبات دفع عبر تحويل بنكي", at: mins(15) },
    ],
    payment: {
      status: "PENDING_VERIFICATION",
      snapshot: bankSnapshot,
      methodId: bank.id,
      ref: "TRX-88214",
      proof: IMG[5],
      submittedAt: mins(15),
    },
    reservation: { status: "ACTIVE", expiresAt: mins(-15) },
    movements: [{ type: "RESERVE", qty: -2, at: mins(40), actor: "CUSTOMER" }],
  });

  // 3) عبدالله — مؤكد (مدفوع ومتحقق) → soldQty=1 لدفعة ويلة فاخر (المتاح 3)
  const o3 = await seedOrder({
    code: "ZG-905833",
    customer: abdullah,
    batch: B[8],
    qty: 1,
    zone: tawahi,
    addressText: "التواهي — جولة سالمين، بناية البحري",
    createdAt: hours(2),
    history: [
      { to: "PENDING_PAYMENT", actor: "CUSTOMER", note: "تم إنشاء الطلب", at: hours(2) },
      { to: "PAYMENT_SUBMITTED", actor: "CUSTOMER", note: "إثبات دفع عبر محفظة جوالي", at: hours(2) },
      { to: "CONFIRMED", actor: "أبو عبدالله", note: "تم التحقق من الدفع وتأكيد الطلب", at: hours(1.5) },
    ],
    payment: {
      status: "PAID",
      snapshot: walletSnapshot,
      methodId: wallet.id,
      ref: "JW-55671",
      submittedAt: hours(2),
      verifiedAt: hours(1.5),
      verifiedBy: "أبو عبدالله",
    },
    reservation: { status: "CONSUMED", expiresAt: hours(2) },
    movements: [
      { type: "RESERVE", qty: -1, at: hours(2), actor: "CUSTOMER" },
      { type: "SOLD", qty: 1, at: hours(1.5), actor: "أبو عبدالله" },
    ],
  });

  // 4) سامي — جاري التجهيز
  await seedOrder({
    code: "ZG-114672",
    customer: sami,
    batch: B[4],
    qty: 2,
    zone: mansoura,
    addressText: "المنصورة — الشعبات، جار مستشفى النقيب",
    createdAt: hours(3),
    history: [
      { to: "PENDING_PAYMENT", actor: "CUSTOMER", note: "تم إنشاء الطلب", at: hours(3) },
      { to: "PAYMENT_SUBMITTED", actor: "CUSTOMER", note: "إثبات دفع عبر تحويل بنكي", at: hours(3) },
      { to: "CONFIRMED", actor: "أبو عبدالله", note: "تم التحقق من الدفع وتأكيد الطلب", at: hours(2.5) },
      { to: "PREPARING", actor: "سالم", note: "بدء تجهيز الحزم", at: hours(2) },
    ],
    payment: {
      status: "PAID",
      snapshot: bankSnapshot,
      methodId: bank.id,
      ref: "TRX-77103",
      submittedAt: hours(3),
      verifiedAt: hours(2.5),
      verifiedBy: "أبو عبدالله",
    },
    reservation: { status: "CONSUMED", expiresAt: hours(3) },
    movements: [
      { type: "RESERVE", qty: -2, at: hours(3), actor: "CUSTOMER" },
      { type: "SOLD", qty: 2, at: hours(2.5), actor: "أبو عبدالله" },
    ],
  });

  // 5) وليد — خرج للتوصيل مع OTP
  const o5 = await seedOrder({
    code: "ZG-640458",
    customer: waleed,
    batch: B[1],
    qty: 1,
    zone: shaikman,
    addressText: "شيخ عثمان — جولة الأربعين، قرب مدرسة الأمل",
    createdAt: hours(4),
    note: "الرقم في الطابق الثالث",
    history: [
      { to: "PENDING_PAYMENT", actor: "CUSTOMER", note: "تم إنشاء الطلب", at: hours(4) },
      { to: "PAYMENT_SUBMITTED", actor: "CUSTOMER", note: "الدفع عند الاستلام", at: hours(4) },
      { to: "CONFIRMED", actor: "أبو عبدالله", note: "تم التحقق واعتماد الدفع عند الاستلام", at: hours(3.5) },
      { to: "PREPARING", actor: "سالم", note: "بدء تجهيز الحزم", at: hours(3) },
      { to: "READY_FOR_DELIVERY", actor: "سالم", note: "الطلب جاهز", at: hours(2.5) },
      { to: "OUT_FOR_DELIVERY", actor: "فهد", note: "خرج مع السائق فهد", at: hours(2) },
    ],
    payment: {
      status: "PAID",
      snapshot: JSON.stringify({ id: null, name: "الدفع عند الاستلام", type: "COD" }),
      submittedAt: hours(4),
      verifiedAt: hours(3.5),
      verifiedBy: "أبو عبدالله",
    },
    reservation: { status: "CONSUMED", expiresAt: hours(4) },
    delivery: {
      status: "OUT_FOR_DELIVERY",
      driver: "فهد",
      otp: "4821",
      assignedAt: hours(2.2),
      createdAt: hours(2.5),
    },
    movements: [
      { type: "RESERVE", qty: -1, at: hours(4), actor: "CUSTOMER" },
      { type: "SOLD", qty: 1, at: hours(3.5), actor: "أبو عبدالله" },
    ],
  });

  // 6) أحمد (عميل متكرر) — تم التسليم + تقييم (استهلك آخر دفعة ويلة ممتاز → نافدة)
  const o6 = await seedOrder({
    code: "ZG-318729",
    customer: ahmed,
    batch: B[11],
    qty: 3,
    zone: crater,
    addressText: "كريتر — جار المؤتمر، عمارة النور، الدور الثاني",
    createdAt: hours(27),
    history: [
      { to: "PENDING_PAYMENT", actor: "CUSTOMER", note: "تم إنشاء الطلب", at: hours(27) },
      { to: "PAYMENT_SUBMITTED", actor: "CUSTOMER", note: "إثبات دفع عبر محفظة جوالي", at: hours(27) },
      { to: "CONFIRMED", actor: "أبو عبدالله", note: "تم التحقق من الدفع وتأكيد الطلب", at: hours(26.5) },
      { to: "PREPARING", actor: "سالم", note: "بدء تجهيز الحزم", at: hours(26) },
      { to: "READY_FOR_DELIVERY", actor: "سالم", note: "الطلب جاهز", at: hours(25.5) },
      { to: "OUT_FOR_DELIVERY", actor: "فهد", note: "خرج مع السائق فهد", at: hours(25) },
      { to: "DELIVERED", actor: "فهد", note: "تم التسليم والتحقق من الرمز", at: hours(24.5) },
    ],
    payment: {
      status: "PAID",
      snapshot: walletSnapshot,
      methodId: wallet.id,
      ref: "JW-48112",
      submittedAt: hours(27),
      verifiedAt: hours(26.5),
      verifiedBy: "أبو عبدالله",
    },
    reservation: { status: "CONSUMED", expiresAt: hours(27) },
    delivery: {
      status: "DELIVERED",
      driver: "فهد",
      otp: "1394",
      assignedAt: hours(25.2),
      deliveredAt: hours(24.5),
      otpVerifiedAt: hours(24.5),
      createdAt: hours(25.5),
    },
    movements: [
      { type: "RESERVE", qty: -3, at: hours(27), actor: "CUSTOMER" },
      { type: "SOLD", qty: 3, at: hours(26.5), actor: "أبو عبدالله" },
    ],
  });
  await db.review.create({
    data: {
      orderId: o6.id,
      customerId: ahmed.id,
      batchId: B[11].id,
      rating: 5,
      smiley: "LOVE",
      matchedPhotos: true,
      comment: "قات نظيف ومطابق للصور تمامًا، وصل طازج والتوصيل كان أسرع من المتوقع. ثاني مرة أطلب وما خيّب.",
      createdAt: hours(24),
    },
  });

  // 7) محمد — ملغي (حجز مُحرر)
  const o7 = await seedOrder({
    code: "ZG-204951",
    customer: mohammed,
    batch: B[7],
    qty: 1,
    zone: muala,
    addressText: "المعلا — حي الرباط، جار جامع الرحمن",
    createdAt: hours(5),
    history: [
      { to: "PENDING_PAYMENT", actor: "CUSTOMER", note: "تم إنشاء الطلب", at: hours(5) },
      { to: "CANCELLED", actor: "سالم", note: "إلغاء بناءً على طلب العميل", at: hours(4.5) },
    ],
    payment: { status: "UNPAID" },
    reservation: { status: "RELEASED", expiresAt: hours(4.5) },
    movements: [
      { type: "RESERVE", qty: -1, at: hours(5), actor: "CUSTOMER" },
      { type: "CANCEL", qty: -1, at: hours(4.5), actor: "سالم" },
    ],
  });
  // cancelledQty لدفعة جبل أرحب اقتصادي
  await db.productBatch.update({
    where: { id: B[7].id },
    data: { cancelledQty: 1 },
  });

  // ── الإشعارات ──
  await db.notification.createMany({
    data: [
      { audience: "ADMIN", title: "طلب جديد", body: `طلب جديد ZG-731204 من أحمد المقطري بقيمة 15800 ريال — بانتظار الدفع.`, orderCode: "ZG-731204", createdAt: mins(12) },
      { audience: "ADMIN", title: "إثبات دفع بانتظار التحقق", body: `الطلب ZG-582917 من محمد الشميري — بانتظار تحقق الإدارة (مرجع: TRX-88214).`, orderCode: "ZG-582917", createdAt: mins(15) },
      { audience: "CUSTOMER", title: "تم تأكيد الدفع ✅", body: "تم تأكيد دفع الطلب ZG-905833 وسيبدأ التجهيز قريبًا. شكرًا لثقتك بذهب أخضر 🌿", orderCode: "ZG-905833", createdAt: hours(1.5) },
      { audience: "CUSTOMER", title: "طلبك في الطريق 🚚", body: "خرج الطلب ZG-640458 للتوصيل. رمز التسليم: 4821 — سلّمه للسائق عند الاستلام.", orderCode: "ZG-640458", createdAt: hours(2) },
      { audience: "ADMIN", title: "مخزون منخفض", body: `تبقت 3 حزم فقط من الدفعة ${B[8].code} (${B[8].name} فاخر).`, createdAt: hours(1.5) },
      { audience: "ADMIN", title: "انتهت الدفعة", body: `نفدت الكمية المتاحة للدفعة ${B[11].code} وحُوّلت تلقائيًا إلى "نافدة".`, createdAt: hours(26.5) },
      { audience: "ADMIN", title: "تقييم جديد", body: "قيّم أحمد المقطري الطلب ZG-318729 بـ 5/5.", orderCode: "ZG-318729", createdAt: hours(24) },
    ],
  });

  // ── سجل التدقيق ──
  await db.auditLog.createMany({
    data: [
      { actorName: "أبو عبدالله", actorRole: "MANAGER", action: "PAYMENT_VERIFIED", entityType: "PAYMENT", entityId: o3.id, before: JSON.stringify({ status: "PENDING_VERIFICATION" }), after: JSON.stringify({ status: "PAID", amount: 13500 }), createdAt: hours(1.5) },
      { actorName: "أبو عبدالله", actorRole: "MANAGER", action: "PAYMENT_VERIFIED", entityType: "PAYMENT", entityId: o5.id, before: JSON.stringify({ status: "PENDING_VERIFICATION" }), after: JSON.stringify({ status: "PAID", amount: 12000 }), createdAt: hours(3.5) },
      { actorName: "سالم", actorRole: "STAFF", action: "ORDER_CANCEL", entityType: "ORDER", entityId: o7.id, before: JSON.stringify({ status: "PENDING_PAYMENT" }), after: JSON.stringify({ status: "CANCELLED" }), createdAt: hours(4.5) },
      { actorName: "المالك", actorRole: "OWNER", action: "PRICE_CHANGED", entityType: "BATCH", entityId: B[5].id, before: JSON.stringify({ price: 5000 }), after: JSON.stringify({ price: 4500 }), createdAt: hours(20) },
      { actorName: "المالك", actorRole: "OWNER", action: "BATCH_CREATED", entityType: "BATCH", entityId: B[0].id, before: null, after: JSON.stringify({ batchCode: B[0].code, totalQty: 20, price: 15000 }), createdAt: mins(75) },
    ],
  });

  // ── الإعدادات ──
  await db.setting.createMany({
    data: [
      { key: "storeName", value: "ذهب أخضر" },
      { key: "whatsapp", value: "967771234567" },
    ],
  });

  console.log("✅ تم — 12 دفعة، 7 طلبات بحالات متنوعة، 4 موظفين، 5 مناطق، 3 طرق دفع");
}

main()
  .catch((e) => {
    console.error("❌ فشل الـ Seed:", e);
    process.exit(1);
  })
  .finally(() => db.$disconnect());
