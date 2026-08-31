# syntax=docker/dockerfile:1
# ============================================================
# ذهب أخضر — صورة إنتاج الباكند (Next.js standalone + Prisma)
# بناء: docker build -t greengold .
# تشغيل: docker run -p 3000:3000 -v gg-data:/app/db greengold
# ============================================================

# ─── المرحلة 1: التثبيت والبناء ───
FROM oven/bun:1 AS builder
WORKDIR /app

# تثبيت الحزم (طبقة مخبأة)
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

# نسخ المشروع وتوليد عميل Prisma
COPY . .
RUN bunx prisma generate

# بناء الإنتاج (standalone)
ENV NEXT_TELEMETRY_DISABLED=1
RUN bun run build

# ─── المرحلة 2: التشغيل ───
FROM node:22-bookworm-slim AS runner
WORKDIR /app

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    DATABASE_URL=file:/app/db/custom.db \
    PORT=3000 \
    HOSTNAME=0.0.0.0

# مستخدم غير جذر
RUN groupadd -g 1001 nodejs && useradd -u 1001 -g nodejs -m nextjs

# مخرجات البناء المستقلة
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

# عميل Prisma + واجهة السطر (لإنشاء/تحديث الجداول عند الإقلاع)
COPY --from=builder --chown=nextjs:nodejs /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder --chown=nextjs:nodejs /app/node_modules/prisma ./node_modules/prisma
COPY --from=builder --chown=nextjs:nodejs /app/node_modules/@prisma ./node_modules/@prisma
COPY --from=builder --chown=nextjs:nodejs /app/prisma ./prisma

# مجلد قاعدة البيانات الدائم
RUN mkdir -p /app/db && chown -R nextjs:nodejs /app/db
VOLUME /app/db

USER nextjs
EXPOSE 3000

# 1) مزامنة الجداول (آمنة ومتكررة — لا تفعل شيئًا إن كانت محدّثة)
# 2) تشغيل الخادم
COPY --chown=nextjs:nodejs docker-entrypoint.sh ./docker-entrypoint.sh
RUN chmod +x ./docker-entrypoint.sh
ENTRYPOINT ["./docker-entrypoint.sh"]
