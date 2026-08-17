# Layer 8 — Admin Dashboard

> schema → `../SCHEMA.md` · ตรวจ → `../checks/L8.sql`
> **สถานะ: 🟨 เริ่มแล้ว 2026-08-14 — `HomeAdmin` ผูกข้อมูลจริง approve/reject ใช้งานได้ · `admin_sales_by_seller` ปิดช่องโหว่แล้ว (D-33, 2026-08-17)**

## 🎯 เป้าหมาย

Admin จัดการผู้ใช้ / สินค้า / รายงาน / หมวดหมู่ ได้ครบ ผู้ใช้ทั่วไปเข้าไม่ได้ **แม้จะยิง API ตรง**

## 🧩 Supabase — ทำแล้วบางส่วน

`admin_dashboard_stats` (จำนวนผู้ใช้/สินค้ารอตรวจ/รายงานค้าง) + `admin_sales_by_seller` (ยอดขายต่อ seller, gate ด้วย `private.is_admin()` ในตัว view เอง — D-33) · trigger `enforce_moderation_admin_only` (D-23) กัน non-admin แก้ `moderation_status`/`rejection_reason` — ยืนยัน live ว่าบล็อกจริง

**ยังไม่ทำ:** RLS admin-only เต็มรูปแบบ (`products` ยัง allow-all นอกเหนือ 2 คอลัมน์ moderation ที่ trigger กันไว้ — non-owner ยัง UPDATE/DELETE คอลัมน์อื่น เช่น ราคา/รูป/ชื่อ ของสินค้าคนอื่นได้อยู่) · `"CAT"` CRUD ผ่าน UI (ตอนนี้ seed ด้วยมือ, ไม่มี UNIQUE บน `name`) · หน้าจัดการ role แทนการรัน SQL มือ (D-02 บอกว่ายังไม่ทำเฟสนี้)

## 🎨 FlutterFlow — ทำแล้ว

`HomeAdmin` ผูก `admin_dashboard_stats`/`admin_sales_by_seller` จริง · ปุ่ม approve/reject ใช้งานได้ (update + refetch ถูกต้อง) · Drawer nav ไป `chatList`/`ReportsFeedback`

**ยังไม่ทำ:** หน้า `Inspect` แยก (คิวรออยู่ใน `HomeAdmin` เอง มีปุ่มอนุมัติ/ปฏิเสธแล้ว) · `"CAT"` CRUD UI

## 🧪 Definition of Done

- [x] Admin เห็น/จัดการสินค้ารอตรวจได้ (approve/reject) — ทดสอบผ่านแอปจริงแล้ว
- [ ] **user ทั่วไปเข้า route หรือยิง query ของ admin ไม่ได้ แม้จะยิง Supabase API ตรง ๆ** — ปิดแล้วเฉพาะ 2 คอลัมน์ moderation (D-23) + `admin_sales_by_seller` (D-33) `products` คอลัมน์อื่นยังไม่ปิด (D-03)
- [x] user ทั่วไปเปลี่ยน `role` ตัวเองไม่ได้ — ยืนยันซ้ำจริง (`db-verifier`, self-escalate → 42501)
- [ ] + DoD ร่วมใน `CLAUDE.md`
