# Layer 7 — Reviews & Reports

> schema → `../SCHEMA.md` · ตรวจ → `../checks/L7.sql`
> **สถานะ: 🟨 `reports` RLS+constraint+UI ใช้งานจริงแล้ว (D-24) + `is_read` (D-31) — เนื้อหาหลักทดสอบผ่านแอปจริงแล้ว (pete, 2026-08-15) จุดแดงยังไม่เทส (D-32) | `reviews` ยังไม่เริ่ม**

## 🎯 เป้าหมาย

ผู้ใช้รีพอร์ตสินค้า(/ผู้ใช้)ที่ไม่เหมาะสมได้ และให้คะแนนผู้ขายหลังธุรกรรมเสร็จได้

## 🧩 Supabase — `reports` ทำแล้ว (D-24), `reviews` ยังไม่เริ่ม

`reports` (`reporter_id`/`reported_product_id`/`reason`/`status`/`is_read`) + RLS จริง (insert ทุก authenticated, select เจ้าของ+admin) + CHECK `status` + unique partial index กันรายงานซ้ำตอนยัง pending + FK `reported_product_id` เป็น `ON DELETE SET NULL` — รายละเอียดคอลัมน์เต็ม `../SCHEMA.md`

**ยังไม่ทำ:** `reviews` table ทั้งตาราง (ยังไม่เริ่มคุย DDL) · รองรับรีพอร์ต "ผู้ใช้" (`reported_user_id`, P-09 ยังไม่ตอบรับ)

## 🎨 FlutterFlow — ทำแล้ว

`ReportProductSheet` (ปุ่ม Report บน `ProductDetails` → insert `reports`) · `ReportsFeedback` (list สำหรับแอดมิน, เดิมชื่อ "Reports" — pete rename ตรงใน editor 2026-08-17, ตรวจแล้วไม่มีจุดอ้างชื่อเก่าหลงเหลือ) · `ReportDetail` · จุดแดง unread ผูก `is_read` (D-31) — **มีบั๊กเดียวกับ L4/L6: ไม่หายทันทีตอนกลับมาหน้าเดิม (D-32)**

**ยังไม่ทำ:** หน้า Rate Seller / review UI ทั้งหมด (รอ `reviews` table + Layer 5)

## 🧪 Definition of Done

- [x] รีพอร์ตบันทึกจริง และ user ทั่วไปอ่านรีพอร์ตของคนอื่นไม่ได้ — ทดสอบ non-admin จริงแล้ว
- [x] admin เห็นรีพอร์ตทั้งหมด — ทดสอบผ่านแอปจริงแล้ว (pete, 2026-08-15)
- [ ] รีวิวซ้ำสินค้าเดิมไม่ได้ — `reviews` ยังไม่มีตาราง
- [ ] rating นอกช่วง 1-5 ถูกปฏิเสธที่ระดับ DB — `reviews` ยังไม่มีตาราง
- [ ] จุดแดง unread หายทันทีตอนแตะ — มีบั๊ก stale-state (D-32) ยังไม่แก้
- [ ] + DoD ร่วมใน `CLAUDE.md`

## ❓ ค้างอยู่

- รองรับรีพอร์ตผู้ใช้ไหม (P-09)
- `reviews` ใช้ RLS allow-all หรือ restrictive — ยังไม่เริ่มคุย
