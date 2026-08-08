# Layer 1 — Authentication & User Profiles

> schema/RLS → `../SCHEMA.md` · สถานะ → `../STATUS.md` · ตรวจ → `../checks/L1.sql`

## 🎯 เป้าหมาย

ผู้ใช้สมัคร/ล็อกอินด้วย `@mju.ac.th` ได้ ข้อมูลโปรไฟล์ถูกต้อง และเป็นฐานให้ RLS ของทุกตารางอื่นอ้าง `auth.uid()` ได้

## 🧩 ขั้นตอน Supabase ที่เหลือ

**🟨 เหลืออย่างเดียว: เส้นทาง `full_name` ยังไม่เคยรันสำเร็จ** — `handle_new_user()` อ่านจาก `raw_user_meta_data->>'full_name'` แต่ user 4 คนที่ทดสอบสมัครผ่าน Dashboard ซึ่งส่ง metadata ไม่ได้ ชื่อในตารางตอนนี้เป็นค่าเติมมือ
→ ปิดได้เมื่อสมัครผ่านหน้า FlutterFlow Sign Up ที่ส่ง `full_name` แล้วเห็นชื่อโผล่เอง (ผลตรวจ: `../VERIFICATION.md` V-02 ข้อ 5)

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
   - 🔴 **validate โดเมน `@mju.ac.th` ฝั่ง client ให้ผ่านก่อน submit เสมอ — บังคับ ไม่ใช่ทางเลือก**
     trigger ปฏิเสธได้จริงก็จริง แต่ error ที่กลับมาถึง client คือ **HTTP 500 body ว่าง** (`Failed to create user: {}`)
     ข้อความ `Only @mju.ac.th email addresses are allowed` ถูกกลบหายไประหว่างทาง (ดู `../SCHEMA.md` หัวข้อ P-02)
     → เอามาโชว์ผู้ใช้ไม่ได้เลย ถ้าไม่ validate ฝั่ง client ผู้ใช้จะเจอ error ปริศนาแล้วไปต่อไม่ถูก
3. **หน้า Log In** — ใช้ **PT-07** (role-based navigation) ใน `../PATTERNS.md`
4. **หน้า Edit Profile** — Backend Query อ่าน/เขียน `"Profile"` ของ `auth.uid()` แก้ได้แค่ `full_name` / `avatar_url` / `phone` / `bio`
   ❌ **`student_id` และ `role` แก้ไม่ได้** — `with_check` ของ policy บล็อกไว้ทั้งคู่ ใส่ลง Update Row เมื่อไหร่ทั้ง statement fail
5. **App State** — `currentUserId` (จาก Auth), `currentUserRole` (จาก `Profile.role`)

## 🧪 Definition of Done

**ฝั่ง Supabase — ✅ ข้อด้านล่างผ่านครบ (ผลเต็ม: `../VERIFICATION.md` V-02 / V-04)**
**แต่ L1 ยังไม่ปิด 🟨** — เส้นทาง `full_name` ของ trigger ตรวจได้เฉพาะฝั่ง FlutterFlow (ข้อแรกของหัวข้อถัดไป) ซึ่งยังไม่เคยรัน

- [x] สมัครด้วยอีเมลนอกโดเมน `@mju.ac.th` ถูกปฏิเสธที่ระดับ DB — ยืนยันจาก auth log (`P0001`)
- [x] สมัครสำเร็จ → มี row ใน `"Profile"` อัตโนมัติ พร้อม `role = 'user'`
- [x] อีเมล `mju<10หลัก>@mju.ac.th` → `student_id` derive อัตโนมัติถูกต้อง (รวมเคสตัวใหญ่)
- [x] อีเมล `@mju.ac.th` ที่ไม่ใช่รูปแบบนั้น (บุคลากร) → สมัครผ่าน และ `student_id` เป็น NULL
- [x] แก้โปรไฟล์คนอื่นไม่ได้ / เปลี่ยน `role` ตัวเองไม่ได้ / เปลี่ยน `student_id` ตัวเองไม่ได้ — ทดสอบด้วย user ธรรมดาจริง
- [x] `checks/L1.sql` ผ่านครบทุกข้อ

**ฝั่ง FlutterFlow — ยังไม่เริ่ม**

- [ ] `full_name` **ไม่เป็น NULL** หลังสมัครผ่านแอปจริง (ต้องส่งใน user meta data — ตอนนี้ 4 คนที่สร้างผ่าน Dashboard เป็น NULL หมด ต้องเทสซ้ำผ่านแอป)
- [ ] validate โดเมนฝั่ง client แล้วขึ้นข้อความที่ผู้ใช้เข้าใจ (server ส่งกลับแค่ 500 เปล่า)
- [ ] `role = admin` → ไป `HomeAdmin`, `role = user` → ไป `home` ถูกทุกครั้ง
- [ ] `role = admin` → ไป `HomeAdmin`, `role = user` → ไป `home` ถูกทุกครั้ง
- [ ] + DoD ร่วมใน `CLAUDE.md`

## 🧪 บัญชีทดสอบที่มีอยู่ (2026-08-07)

| อีเมล | `student_id` | ใช้ทำอะไร |
|---|---|---|
| `mju6512345678@mju.ac.th` | `6512345678` | เจ้าของข้อมูลตอนเทส RLS |
| `mju6598765432@mju.ac.th` | `6598765432` | **user ธรรมดาที่ไม่ใช่เจ้าของ** — ใช้เป็น UID ใน `checks/_common.sql` [C8] |
| `somchai.j@mju.ac.th` | `NULL` | เคสบุคลากร |
| `mju6511112222@mju.ac.th` | `6511112222` | สำรอง |

`full_name` เป็นชื่อปลอมที่เติมด้วยมือทีหลัง ทั้ง 4 คนยังเป็น `role = 'user'` — **ยังไม่มี admin ในระบบเลย** ต้องตั้งด้วยมือตาม D-02 ก่อนเทส L8

## ❓ ค้างอยู่

- จะทำ role-based redirect ซ้ำที่หน้า Splash/Initial (auto-login) ด้วยไหม
- 🔴 **รูปแบบอีเมลจริงของแม่โจ้เป็นยังไง** — CHECK ปัจจุบันรับเฉพาะ `mju<10หลัก>@mju.ac.th` ถ้าของจริงไม่ตรงรูปแบบนี้ นักศึกษาจะไม่มี `student_id` เลยสักคน (pete กำลังเช็ค — ดู D-10)
- `handle_new_user()` ยังไม่มี `ON CONFLICT` — ถ้าแถวใน `"Profile"` มีอยู่แล้วจะ error ทั้งรายการ ต้องกันไหม
