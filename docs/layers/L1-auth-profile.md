# Layer 1 — Authentication & User Profiles

> schema/RLS → `../SCHEMA.md` · สถานะ → `../STATUS.md` · ตรวจ → `../checks/L1.sql`

## 🎯 เป้าหมาย

ผู้ใช้สมัคร/ล็อกอินด้วย `@mju.ac.th` ได้ ข้อมูลโปรไฟล์ถูกต้อง และเป็นฐานให้ RLS ของทุกตารางอื่นอ้าง `auth.uid()` ได้

## 🧩 ขั้นตอน Supabase ที่เหลือ

- [ ] **สร้าง trigger auto-insert Profile** (`PROPOSED_SQL.md` P-01) 🔥 คิวถัดไป
- [ ] ตัดสินใจว่าจะทำ server-side validate โดเมน `@mju.ac.th` ไหม (P-02)

**ทำแล้ว:** คอลัมน์ครบ (`role`/`student_id`/`phone` + constraints) · RLS ของ `"Profile"` มีอยู่แล้วจริง **ไม่ต้องเขียนใหม่** · view `public_profiles` สร้างแล้ว

## 🎨 ขั้นตอน FlutterFlow

1. **หน้า Sign Up** — ฟอร์ม email / password / full_name / `student_id` / `phone` + validate suffix `@mju.ac.th` ก่อน submit
2. **Action Flow ตอน submit** — Supabase Auth → Sign Up
   ⚠️ trigger P-01 สร้างให้แค่ `id`/`email`/`role` **ไม่รู้ค่า `student_id`/`phone`** → ต้องมี Action ต่อ **Update Row** `"Profile"` ใส่ 2 ค่านั้นเพิ่ม
3. **หน้า Log In** — ใช้ **PT-07** (role-based navigation) ใน `../PATTERNS.md`
4. **หน้า Edit Profile** — Backend Query อ่าน/เขียน `"Profile"` ของ `auth.uid()` แก้ `full_name` / `avatar_url` / `student_id` / `phone`
5. **App State** — `currentUserId` (จาก Auth), `currentUserRole` (จาก `Profile.role`)

## 🧪 Definition of Done

- [ ] สมัครด้วยอีเมลนอกโดเมน `@mju.ac.th` ถูกปฏิเสธ (อย่างน้อยฝั่ง client)
- [ ] สมัครสำเร็จ → มี row ใน `"Profile"` อัตโนมัติ พร้อม `role = 'user'`
- [ ] สมัครด้วย `student_id` ที่ไม่ใช่ตัวเลข 10 หลัก หรือซ้ำกับคนอื่น → ถูกปฏิเสธที่ระดับ DB
- [ ] login แล้วแก้โปรไฟล์คนอื่นไม่ได้ / เปลี่ยน `role` ตัวเองไม่ได้
- [ ] `role = admin` → ไป `HomeAdmin`, `role = user` → ไป `home` ถูกทุกครั้ง
- [ ] + DoD ร่วมใน `CLAUDE.md`

## ❓ ค้างอยู่

- จะทำ role-based redirect ซ้ำที่หน้า Splash/Initial (auto-login) ด้วยไหม
- จะทำ server-side domain validation (P-02) จริงไหม
