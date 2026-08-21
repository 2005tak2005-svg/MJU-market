# Layer 8 — Admin Dashboard

> schema → `../SCHEMA.md` · ตรวจ → `../checks/L8.sql`
> **สถานะ: 🟨 เริ่มแล้ว 2026-08-14 — `HomeAdmin` ผูกข้อมูลจริง approve/reject ใช้งานได้ · `admin_sales_by_seller` ปิดช่องโหว่แล้ว (D-33) · ระบบ ban user ครบทั้ง DB+UI แล้ว (D-52, 2026-08-21) รอทดสอบผ่านแอปจริง**

## 🎯 เป้าหมาย

Admin จัดการผู้ใช้ / สินค้า / รายงาน / หมวดหมู่ ได้ครบ ผู้ใช้ทั่วไปเข้าไม่ได้ **แม้จะยิง API ตรง**

## 🧩 Supabase — ทำแล้วบางส่วน

`admin_dashboard_stats` (จำนวนผู้ใช้/สินค้ารอตรวจ/รายงานค้าง) + `admin_sales_by_seller` (ยอดขายต่อ seller, gate ด้วย `private.is_admin()` ในตัว view เอง — D-33) · trigger `enforce_moderation_admin_only` (D-23) กัน non-admin แก้ `moderation_status`/`rejection_reason` — ยืนยัน live ว่าบล็อกจริง

**ระบบ ban user — ฝั่ง Supabase ปิดแล้ว (D-52, 2026-08-21)** soft ban บังคับที่ RLS จริง ไม่ใช่แค่ UI:
`"Profile"` +`ban_reason`/`banned_at`/`banned_by` · helper `private.is_banned`/`is_user_banned`/`chat_has_admin` · trigger `enforce_ban_admin_only` (ปิดช่องปลดแบนตัวเองที่ `with_check` เดิมล็อกไม่ถึง) · **5 RESTRICTIVE policy** บน `products`(insert/update/delete)/`reports`(insert)/`chat_message`(insert) · `products_review_view` ซ่อนประกาศผู้ถูกแบนจากคนอื่น · `admin_users_view` ใหม่ (gate ในตัว) · RPC `admin_set_user_ban` = ทางเดียวที่เขียน `is_banned` ได้ · ช่องอุทธรณ์ยังเปิด (แชทกับแอดมินได้) — ทดสอบ impersonation ครบ 3 บทบาทแล้ว

**ยังไม่ทำ:** RLS admin-only เต็มรูปแบบ (`products` ยัง allow-all นอกเหนือ 2 คอลัมน์ moderation + มิติ ban ที่ D-52 ปิด — non-owner ยัง UPDATE/DELETE ราคา/รูป/ชื่อ ของสินค้าคนอื่นได้อยู่) · `"CAT"` CRUD ผ่าน UI (ตอนนี้ seed ด้วยมือ, ไม่มี UNIQUE บน `name`) · หน้าจัดการ role แทนการรัน SQL มือ (D-02 บอกว่ายังไม่ทำเฟสนี้)

## 🎨 FlutterFlow — ทำแล้ว

`HomeAdmin` ผูก `admin_dashboard_stats`/`admin_sales_by_seller` จริง · ปุ่ม approve/reject ใช้งานได้ (update + refetch ถูกต้อง) · Drawer nav ไป `chatList`/`ReportsFeedback`

**ระบบ ban — UI ครบแล้ว (D-52 Phase B–D, 2026-08-21):** หน้า `ManageUsers` (ListView ผูก `admin_users_view` · ปุ่ม Ban/Unban สลับด้วย `visible:` จาก computed boolean · ปุ่มรีเฟรชระดับหน้า จำเป็นเพราะ PT-29 §1) · component `BanUserSheet` ใช้ซ้ำได้ 2 ทางเข้า (ไม่มี params — เป้าหมายเดินทางผ่าน App State) · ปุ่ม "ระงับผู้ขายรายนี้" บน `ReportDetail` · popup `BannedNoticeDialog` บน `Home` (เหตุผล + สิ่งที่ทำไม่ได้ + ปุ่มติดต่อแอดมิน + ปิดได้) · เมนู "ผู้ใช้งาน" บน `HomeAdmin` ต่อสายแล้ว

**ยังไม่ทำ:** หน้า `Inspect` แยก (คิวรออยู่ใน `HomeAdmin` เอง มีปุ่มอนุมัติ/ปฏิเสธแล้ว) · `"CAT"` CRUD UI
> 📌 เมนู "ผู้ใช้งาน" ใน sidebar ของ `HomeAdmin` (`Container_hm29v9qs`) เคย render อยู่แต่ไม่มี action เลยตั้งแต่ import template — ต่อ `Navigate(ManageUsers)` ผ่าน `page.ensureActions` แล้ว (D-52) · เมนูอีก 3 ตัวข้างเคียง (`Container_r5vbmzah` Dashboard / `Container_sy9a9rqk` สินค้ารอตรวจ / `Container_sqntfu80` รายงาน) **ยังไม่มี action เหมือนกัน** ถ้าจะต่อใช้วิธีเดียวกัน

## 🧪 Definition of Done

- [x] Admin เห็น/จัดการสินค้ารอตรวจได้ (approve/reject) — ทดสอบผ่านแอปจริงแล้ว
- [ ] **user ทั่วไปเข้า route หรือยิง query ของ admin ไม่ได้ แม้จะยิง Supabase API ตรง ๆ** — ปิดแล้วเฉพาะ 2 คอลัมน์ moderation (D-23) + `admin_sales_by_seller` (D-33) `products` คอลัมน์อื่นยังไม่ปิด (D-03)
- [x] user ทั่วไปเปลี่ยน `role` ตัวเองไม่ได้ — ยืนยันซ้ำจริง (`db-verifier`, self-escalate → 42501)
- [x] **ผู้ถูกแบนปลดแบนตัวเองไม่ได้ + ลงประกาศ/แชท/รายงานไม่ได้ แม้ยิง API ตรง** (D-52) — impersonation test ครบ 3 บทบาท
- [x] **แอดมินกดแบน/ปลดแบนผ่าน UI ได้** (D-52 Phase B–D) — ยืนยันจาก `generated_code/` + `dart analyze` custom action สะอาด · 🔴 **ยังไม่ทดสอบผ่านแอปจริงโดย pete**
- [ ] + DoD ร่วมใน `CLAUDE.md`
