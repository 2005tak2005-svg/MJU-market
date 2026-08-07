# Layer 1 — Authentication & User Profiles

> schema/RLS → `../SCHEMA.md` · สถานะ → `../STATUS.md` · ตรวจ → `../checks/L1.sql`

## 🎯 เป้าหมาย

ผู้ใช้สมัคร/ล็อกอินด้วย `@mju.ac.th` ได้ ข้อมูลโปรไฟล์ถูกต้อง และเป็นฐานให้ RLS ของทุกตารางอื่นอ้าง `auth.uid()` ได้

## 🧩 ขั้นตอน Supabase ที่เหลือ

- [ ] **ทดสอบ trigger `handle_new_user` กับการสมัครจริง** — โค้ดอยู่ใน DB แล้ว แต่ `auth.users` มี 0 แถว จึงยังไม่เคยรันสักครั้ง

**ทำแล้ว:** คอลัมน์ครบ (`role`/`student_id`/`phone`/`bio` + constraints) · RLS ของ `"Profile"` มีอยู่แล้วจริง **ไม่ต้องเขียนใหม่** · view `public_profiles` สร้างแล้ว · **trigger auto-insert Profile (P-01) apply แล้ว** · **server-side validate โดเมน `@mju.ac.th` (P-02) apply แล้ว** — รวมอยู่ใน `handle_new_user()` ตัวเดียวกัน ดู `../SCHEMA.md`

## 🎨 ขั้นตอน FlutterFlow

> 🔴 **`student_id` ห้ามเขียนจากฝั่ง client เด็ดขาด** — trigger `handle_new_user()` derive ค่านี้จากอีเมลให้อยู่แล้ว
> และ CHECK `profile_student_id_matches_email` บังคับให้ `student_id` ตรงกับอีเมลเสมอ
> ยิงค่าไปเองเมื่อไหร่ = constraint violation ทันที (ดู D-10)
> **ห้ามมีช่อง `student_id` ในฟอร์ม Sign Up และในฟอร์ม Edit Profile**

1. **หน้า Sign Up** — ฟอร์ม email / password / full_name / `phone` + validate suffix `@mju.ac.th` ก่อน submit
   ❌ **ไม่มีช่อง `student_id`** — ถ้าอยากโชว์ให้ผู้ใช้เห็น ให้แสดงเป็น read-only หลังสมัครเสร็จ
2. **Action Flow ตอน submit** — Supabase Auth → Sign Up
   - ต้องส่ง `full_name` ไปใน **user meta data** (key ชื่อ `full_name` เป๊ะ ๆ) — trigger อ่านจาก `raw_user_meta_data->>'full_name'` ไม่ส่งไป `full_name` จะเป็น NULL แล้วชื่อผู้ขายจะหายทั้งระบบ
   - trigger สร้างแถวใน `"Profile"` ให้ครบ `id`/`email`/`full_name`/`role`/`student_id` แล้ว
   - ⚠️ เหลือแค่ **`phone`** ที่ trigger ไม่รู้ → ต้องมี Action ต่อ **Update Row** ใส่ `phone` **อย่างเดียว**
   - ⚠️ อีเมลนอกโดเมน `@mju.ac.th` จะถูก trigger `raise exception` → Sign Up ล้มทั้งรายการ ต้องมี error handling แสดงข้อความให้ผู้ใช้เข้าใจ ไม่ใช่ปล่อย error ดิบ
3. **หน้า Log In** — ใช้ **PT-07** (role-based navigation) ใน `../PATTERNS.md`
4. **หน้า Edit Profile** — Backend Query อ่าน/เขียน `"Profile"` ของ `auth.uid()` แก้ได้แค่ `full_name` / `avatar_url` / `phone` / `bio`
   ❌ **`student_id` และ `role` แก้ไม่ได้** — `with_check` ของ policy บล็อกไว้ทั้งคู่ ใส่ลง Update Row เมื่อไหร่ทั้ง statement fail
5. **App State** — `currentUserId` (จาก Auth), `currentUserRole` (จาก `Profile.role`)

## 🧪 Definition of Done

- [ ] สมัครด้วยอีเมลนอกโดเมน `@mju.ac.th` ถูกปฏิเสธ **ทั้งฝั่ง client และฝั่ง DB** (trigger raise exception)
- [ ] สมัครสำเร็จ → มี row ใน `"Profile"` อัตโนมัติ พร้อม `role = 'user'` และ `full_name` **ไม่เป็น NULL**
- [ ] อีเมล `mju<10หลัก>@mju.ac.th` → `student_id` ถูก derive อัตโนมัติตรงกับเลขในอีเมล
- [ ] อีเมล `@mju.ac.th` ที่ไม่ใช่รูปแบบนั้น (บุคลากร) → สมัครผ่าน และ `student_id` เป็น NULL
- [ ] login แล้วแก้โปรไฟล์คนอื่นไม่ได้ / เปลี่ยน `role` ตัวเองไม่ได้ / เปลี่ยน `student_id` ตัวเองไม่ได้
- [ ] `role = admin` → ไป `HomeAdmin`, `role = user` → ไป `home` ถูกทุกครั้ง
- [ ] + DoD ร่วมใน `CLAUDE.md`

## ❓ ค้างอยู่

- จะทำ role-based redirect ซ้ำที่หน้า Splash/Initial (auto-login) ด้วยไหม
- 🔴 **รูปแบบอีเมลจริงของแม่โจ้เป็นยังไง** — CHECK ปัจจุบันรับเฉพาะ `mju<10หลัก>@mju.ac.th` ถ้าของจริงไม่ตรงรูปแบบนี้ นักศึกษาจะไม่มี `student_id` เลยสักคน (pete กำลังเช็ค — ดู D-10)
- `handle_new_user()` ยังไม่มี `ON CONFLICT` — ถ้าแถวใน `"Profile"` มีอยู่แล้วจะ error ทั้งรายการ ต้องกันไหม
