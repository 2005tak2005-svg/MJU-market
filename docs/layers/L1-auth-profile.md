# Layer 1 — Authentication & User Profiles

> schema/RLS → `../SCHEMA.md` · สถานะ → `../STATUS.md` · ตรวจ → `../checks/L1.sql`

## 🎯 เป้าหมาย

ผู้ใช้สมัคร/ล็อกอินด้วย `@mju.ac.th` ได้ ข้อมูลโปรไฟล์ถูกต้อง และเป็นฐานให้ RLS ของทุกตารางอื่นอ้าง `auth.uid()` ได้

> 🔄 **2026-08-09 — รีเซ็ตโปรเจกต์ FlutterFlow เป็น "MJU-Market-v2"** (`m-j-u-market-v2-0xhjhg`) ดู `../DECISIONS.md` **D-16** — Supabase เชื่อมโปรเจกต์เดิม (`rooydbxgcsybyanwsewv`) ไม่เปลี่ยน

## 🧩 ขั้นตอน Supabase ที่เหลือ

**✅ ปิดแล้ว 2026-08-09 — เส้นทาง `full_name`/`phone` รันสำเร็จผ่านแอปจริง**
สมัครด้วย `mju6577778888@mju.ac.th` ผ่าน Sign Up page จริง ได้ `full_name = 'ทดสอบ ผ่านแอป'`, `phone = '0812345678'`, `student_id = '6577778888'` (derive อัตโนมัติ), `role = 'user'` ครบทุกช่อง ยืนยันด้วย SQL ตรงหลังสมัคร

**ทำแล้ว:** คอลัมน์ครบ (`role`/`student_id`/`phone`/`bio` + constraints) · RLS ของ `"Profile"` มีอยู่แล้วจริง **ไม่ต้องเขียนใหม่** · view `public_profiles` สร้างแล้ว · **trigger auto-insert Profile (P-01) apply แล้ว** · **server-side validate โดเมน `@mju.ac.th` (P-02) apply แล้ว** — รวมอยู่ใน `handle_new_user()` ตัวเดียวกัน ดู `../SCHEMA.md`

**🔴 พบใหม่ระหว่างทำ — DSL/SDK ของ FlutterFlow AI มีบั๊ก/กับดัก 3 ตัว ไม่ใช่เรื่อง schema แต่กระทบวิธีเขียน Action Flow ทุก layer ถัดไป** ดู `../PATTERNS.md` **PT-09** (custom action argument เสีย) **PT-10** (`PostgresQuery` type เป็น list เสมอ, `FieldAccess` ดึงฟิลด์เดียวไม่ได้) และ **PT-11** (แทนที่ built-in auth action ด้วย custom action ต้อง sync `AppStateNotifier` เอง เพราะ auth stream ของแอปถูก debounce ไว้)

## 🚧 เคลียร์ก่อนกดใน FlutterFlow

| # | เรื่อง | สถานะ |
|---|---|---|
| 1 | **เปิด "Confirm email" อยู่ไหม** | ✅ **ตอบแล้ว 2026-08-09 — เปิดอยู่จริง** ยืนยันด้วยการสมัครจริงแล้ว login ทันทีเจอ "Email not confirmed" ตรง ๆ จาก Supabase · **แต่ทางรับมือยังไม่ตัดสินใจ** ดู `../DECISIONS.md` **D-17** (2 ทางเลือก) และ 🔴 งานค้างท้ายไฟล์นี้ |
| 2 | **ยังไม่มี admin ในระบบ** | ✅ **ปิดแล้ว** — `mju6577778888@mju.ac.th` ตั้งเป็น `role='admin'` แล้วตาม D-02 (2026-08-09) |
| 3 | **ห้ามเทสด้วย 4 บัญชีเดิม (v1)** | ⚠️ **ไม่เกี่ยวแล้ว** — v2 เป็นโปรเจกต์ใหม่ (D-16) ทดสอบสมัคร**บัญชีที่ 5** สำเร็จจริงผ่านแอปแล้ว (`mju6577778888@mju.ac.th`) |
| 4 | **FlutterFlow CLI / MCP** | ✅ **มีแล้ว ใช้งานได้** (`flutterflow ai run/validate/inspect/status` + MCP) — กฎข้อ 3 ตรวจได้เต็มรูปแบบแล้ว |

## 🎨 ขั้นตอน FlutterFlow

> 🔴 **`student_id` ห้ามเขียนจากฝั่ง client เด็ดขาด** — trigger `handle_new_user()` derive ค่านี้จากอีเมลให้อยู่แล้ว
> และ CHECK `profile_student_id_matches_email` บังคับให้ `student_id` ตรงกับอีเมลเสมอ
> ยิงค่าไปเองเมื่อไหร่ = constraint violation ทันที (ดู D-10)
> **ห้ามมีช่อง `student_id` ในฟอร์ม Sign Up และในฟอร์ม Edit Profile**

1. **✅ หน้า `SignUp`** — ฟอร์ม email / password / full_name / `phone` + validate โดเมนฝั่ง client (regex `^[^@]+@mju\.ac\.th$`) ก่อน submit — **ทำแล้ว**
   🔴 **ห้าม validate ด้วย "ลงท้ายด้วย `@mju.ac.th`" เฉย ๆ** — `hacker@evil.com@mju.ac.th` ลงท้ายถูกจริง (ดู D-10 หัวข้อช่องโหว่)
   ❌ ไม่มีช่อง `student_id` — ตามสเปคเดิม
   **ต่างจากสเปคเดิมที่ร่างไว้ตรงนี้:** built-in action "Supabase Auth → Sign Up" **ส่ง user meta data ไม่ได้จริง** (ไม่มี field ให้ผูกเลยในเวอร์ชัน SDK นี้) จึงใช้ **custom action `SignUpWithProfile`** (0 argument, อ่านค่าจาก App State แล้วเรียก `Supabase.instance.client.auth.signUp(..., data: {...})` ตรง ๆ) แทน — ดูสาเหตุเต็มที่ `../PATTERNS.md` **PT-09**
   สมัครสำเร็จ → snackbar "สมัครสมาชิกสำเร็จ" → Navigate ไป `Login` (มีลิงก์ "ยังไม่มีบัญชี? สมัครสมาชิก" ย้อนกลับด้วย)
   🔴 **งานค้าง (D-17):** ตอนนี้ไม่มีการบอกผู้ใช้เลยว่าต้องไปยืนยันอีเมลก่อนถึงจะ login ได้ — ดู 🔴 ท้ายไฟล์
2. **✅ Action Flow ตอน submit** — เรียก `SignUpWithProfile` (ไม่ใช่ built-in Sign Up action ตามเหตุผลข้อ 1) แล้วเช็ค return value ว่างหรือไม่ว่างเพื่อรู้ผลสำเร็จ/error
   - trigger สร้างแถวใน `"Profile"` ให้ครบ `id`/`email`/`full_name`/`role`/`student_id`/`phone` ในคราวเดียว — **ยืนยันด้วยการสมัครจริงแล้ว**
   - 🔴 **validate โดเมน `@mju.ac.th` ฝั่ง client ก่อน submit เสมอ — บังคับ** เหตุผลเดิม (error จาก server อ่านไม่ได้ ดู `../SCHEMA.md` หัวข้อ P-02)
3. **✅ หน้า `Login`** — email/password → `LoginEmailPassword` → custom action `IsCurrentUserAdmin` (0 argument, query `"Profile".role` ตรง ๆ คืน `bool`) → Navigate `HomeAdmin`/`Home`
   **ต่างจาก PT-07 เดิมที่ร่างไว้ (Backend Query + Conditional เทียบ string):** `PostgresQuery` + `FieldAccess` ดึงฟิลด์เดียวจากแถวเดียวไม่ได้จริงในเวอร์ชัน SDK นี้ (compile error) จึงใช้ custom action แทน — เหตุผลเต็มที่ `../PATTERNS.md` **PT-10** (PT-07 เองก็แก้ไขให้ตรงกับของจริงแล้ว)
   ยืนยันด้วย server timestamp จริง (`auth.users.last_sign_in_at`) ว่าทั้ง 2 เส้นทางทำงาน: user → `Home`, admin → `HomeAdmin`
   🔴 **งานค้าง (D-17):** login ด้วยบัญชีที่ยังไม่ยืนยันอีเมล **ไม่ถูกดักเลย** — ผู้ใช้จะเห็น error ดิบจาก Supabase ("Email not confirmed") ตรง ๆ
4. **🟨 หน้า `ProfileUser` — ทำแล้ว 2026-08-14 (แทนแผน "Edit Profile" เดิม)** — แสดง avatar/ชื่อ/อีเมลของ user ที่ล็อกอิน + เปลี่ยนชื่อ + เปลี่ยนรูปโปรไฟล์ + Log Out
   **วิธีผูกข้อมูล: page-level Backend Query** บน Scaffold (`Scaffold_8myjbpxe`) — `"Profile"` filter `id = SUPABASE_AUTH_USER.USER_ID`, `isSingleRow` + **`hideOnEmpty = true`** (ดู PT-14 ข้อ 1) แล้ว bind widget ตรง ๆ ด้วย `POSTGRES_QUERY` + `accessPostgresRowField` **ไม่ใช้ ListView/page state**
   - visibility ของทุก field ใช้ `EXISTS_AND_NON_EMPTY` / `DOES_NOT_EXIST_OR_IS_EMPTY` (**ห้ามใช้ `EQUAL_TO ''`** — ดู PT-14 ข้อ 2)
   - อัปรูป → bucket `avatars` path `<currentUserId>/<ไฟล์>` (PT-08) **ต้องตั้ง `maxResolution` + `imageQuality`** ไม่งั้นโดน 413 (PT-14 ข้อ 3)
   - ทดสอบผ่านแอปจริงแล้ว: แสดงข้อมูลถูก · เปลี่ยนชื่อ/รูปได้ · Log Out ออกจริง
   - ⬜ ยังไม่ได้ทำ: แก้ `phone` / `bio`
   ❌ **`student_id` และ `role` แก้ไม่ได้** — `with_check` ของ policy บล็อกไว้ทั้งคู่

5. **App State (ของจริงใน v2 ตอนนี้):** `email` / `password` / `fullName` / `phone` (ใช้ตอน Sign Up) — **ยังไม่มี** `currentUserId` / `currentUserRole` ระดับ app ตามที่ร่างไว้เดิม เพราะ role check ย้ายไปอยู่ใน custom action `IsCurrentUserAdmin` แทน (ดูข้อ 3) ถ้า layer หลังต้องใช้ `currentUserRole` ที่ระดับ app ต้องเพิ่มเอง

## ✅ ปิดแล้ว — 2 บัญชี `auth.users` ไม่มีแถวใน `"Profile"` (D-32, 2026-08-17 → ปิด 2026-08-24)

`handle_new_user()` ไม่ทำงาน/fail เงียบสำหรับ `mju6606105382@mju.ac.th` และ `mju6606105386@mju.ac.th` — ไม่พบ UNIQUE ชนกันที่ `email`/`student_id` สาเหตุจาก DB อย่างเดียวหาไม่เจอ (root cause เดิมยังไม่ทราบแน่ชัด แต่ไม่เกิดซ้ำในรอบทดสอบล่าสุด — เฝ้าดูต่อถ้าเกิดซ้ำกับบัญชีใหม่)
✅ **`mju6606105382` แก้แล้ว 2026-08-17** — ลบบัญชีเก่าทิ้ง สมัครใหม่สะอาดผ่าน flow ปกติ (D-34) ได้ `"Profile"` ครบถูกต้อง ไม่เจอบั๊กซ้ำ
✅ **`mju6606105386@mju.ac.th` ลบทิ้งแล้ว (pete ยืนยัน 2026-08-24)** — สมัครไม่สำเร็จตั้งแต่ 2026-08-13 (ไม่เคยยืนยันอีเมล ไม่มี `"Profile"`) ลบตรงจาก `auth.users` (cascade ไป `auth.identities`)

## ✅ Confirm Email (D-20 → D-34) ปลดล็อกแล้ว 2026-08-17

**เดิม (D-19/D-20):** ลิงก์ยืนยัน → ใช้ไม่ได้เพราะ Microsoft Safe Links ดึง token ทิ้งก่อน → เปลี่ยนเป็น OTP → OTP ผ่าน custom SMTP (Gmail ส่วนตัว) ก็ไปไม่ถึงกล่อง `@mju.ac.th` เลย (Microsoft Zero-hour Auto Purge, ไม่มี sending reputation กับ tenant) — ค้างตรงนี้ตั้งแต่ 2026-08-10

**ตอนนี้ (D-34):** เลิกส่งตรงถึง student ทั้งหมด เปลี่ยนเป็น Supabase Auth Send Email Hook → Edge Function `send-otp-email` → Resend API → ส่งเข้า **admin inbox เดียว** ให้แอดมิน relay รหัสออกนอกระบบเอง — **ยืนยัน end-to-end สำเร็จผ่านแอปจริงแล้ว** (`mju6606105382@mju.ac.th`, 2026-08-17) `"Profile"` ถูกสร้างถูกต้องครบ รายละเอียด+กับดักตอนเซ็ต (secrets/Resend sandbox/rate limit) → `../DECISIONS.md` **D-34**

**หนี้ที่เหลือก่อน production:** manual relay ไม่ scale (ต้อง verify domain จริงที่ Resend แล้วเปลี่ยนให้ส่งตรงถึง student) · rate limit email ปรับเป็น 30/ชม. ชั่วคราวตอนดีบัก ต้องหรี่ก่อนขึ้นจริง

**หน้า/action ที่สร้างไว้ตั้งแต่ D-20 ใช้งานได้จริงแล้ว:** หน้า `ConfirmEmail` + custom action `VerifyOtp`/`ResendSignupOtp`, `LoginWithEmailPassword` ดักเคส "email not confirmed", email content ส่ง `{{ .Token }}` เป็นตัวเลข — ไม่ต้องแก้อะไรฝั่ง FlutterFlow ปัญหาทั้งหมดอยู่ฝั่ง Supabase Auth config

**ระหว่างที่ยังไม่ verify domain Resend:** ใช้ `mju6577778888@mju.ac.th` (admin, `email_confirmed_at` patch ด้วย SQL, login ได้จริง) ทดสอบ layer อื่นที่ไม่เกี่ยว confirm-email ได้ตามเดิม

## 🧪 Definition of Done

**ฝั่ง Supabase — ✅ ข้อด้านล่างผ่านครบ (ผลเต็ม: `../VERIFICATION.md` V-02 / V-04)**

- [x] สมัครด้วยอีเมลนอกโดเมน `@mju.ac.th` ถูกปฏิเสธที่ระดับ DB — ยืนยันจาก auth log (`P0001`)
- [x] อีเมล `@` ซ้อน (`hacker@evil.com@mju.ac.th`) ถูกปฏิเสธ — เคสที่ regex เดิมปล่อยผ่าน (V-09)
- [x] `"Profile".email` ถูก normalize เป็นตัวเล็กเสมอ แม้ผู้ใช้พิมพ์ตัวใหญ่ (V-09)
- [x] สมัครสำเร็จ → มี row ใน `"Profile"` อัตโนมัติ พร้อม `role = 'user'`
- [x] อีเมล `mju<10หลัก>@mju.ac.th` → `student_id` derive อัตโนมัติถูกต้อง (รวมเคสตัวใหญ่)
- [x] อีเมล `@mju.ac.th` ที่ไม่ใช่รูปแบบนั้น (บุคลากร) → สมัครผ่าน และ `student_id` เป็น NULL
- [x] แก้โปรไฟล์คนอื่นไม่ได้ / เปลี่ยน `role` ตัวเองไม่ได้ / เปลี่ยน `student_id` ตัวเองไม่ได้ — ทดสอบด้วย user ธรรมดาจริง
- [x] `checks/L1.sql` ผ่านครบทุกข้อ

**ฝั่ง FlutterFlow — 🟨 ผ่านบางส่วน ยังปิด L1 ไม่ได้** (confirm-email ปลดล็อกแล้ว D-34 — ที่เหลือคือ `phone`/avatar 2 ข้อล่าง ไม่เกี่ยวกับ email)

- [x] `full_name` **และ `phone`** ไม่เป็น NULL หลังสมัคร**บัญชีใหม่**ผ่านแอปจริง — ยืนยันแล้ว 2026-08-09 (`mju6577778888@mju.ac.th`)
- [x] validate โดเมนฝั่ง client แล้วขึ้นข้อความที่ผู้ใช้เข้าใจ — ทำใน `SignUpWithProfile` แล้ว
- [x] `role = admin` → ไป `HomeAdmin`, `role = user` → ไป `Home` ถูกทุกครั้ง — ยืนยันด้วย `auth.users.last_sign_in_at` จริงทั้ง 2 เส้นทาง 2026-08-09
- [ ] กรอกช่องเบอร์เป็นช่องว่างล้วนแล้วสมัคร → `phone` ต้องเป็น `NULL` ไม่ใช่ `''` — ยังไม่ได้เทสเคสนี้ผ่านแอปจริง (trigger รองรับแล้วตาม D-14 แต่ path ผ่าน UI ยังไม่เทส)
- [ ] อัปรูปโปรไฟล์เข้า `avatars` แล้วรูปโผล่จริงจาก public URL — Edit Profile ยังไม่ได้สร้าง
- [x] **สมัครเสร็จบอกผู้ใช้ให้ไปยืนยันอีเมล + login ก่อนยืนยันดักได้อย่างเข้าใจ** — ✅ **ทดสอบ end-to-end ผ่านแอปจริงสำเร็จแล้ว 2026-08-17** (`mju6606105382@mju.ac.th`, ผ่าน admin-relay ตาม D-34) — ดูหัวข้อ "Confirm Email (D-20 → D-34) ปลดล็อกแล้ว" ด้านบน
- [ ] + DoD ร่วมใน `CLAUDE.md`

## 🧪 บัญชีทดสอบที่มีอยู่ (อัปเดต 2026-08-09)

| อีเมล | `student_id` | `role` | ใช้ทำอะไร |
|---|---|---|---|
| `mju6512345678@mju.ac.th` | `6512345678` | `user` | เจ้าของข้อมูลตอนเทส RLS · 🔴 **`encrypted_password` ถูกเขียนทับด้วย SQL 2026-08-09** เพื่อเทส Test Pilot — รหัสเดิม (ถ้ามี) ใช้ไม่ได้แล้ว รายละเอียด `../STATUS.md` หนี้ทางเทคนิค |
| `mju6598765432@mju.ac.th` | `6598765432` | `user` | **user ธรรมดาที่ไม่ใช่เจ้าของ** — ใช้เป็น UID ใน `checks/_common.sql` [C8] · ใช้ยืนยัน user-path login → `Home` สำเร็จ 2026-08-09 |
| `somchai.j@mju.ac.th` | `NULL` | `user` | เคสบุคลากร |
| `mju6511112222@mju.ac.th` | `6511112222` | `user` | สำรอง |
| `mju6577778888@mju.ac.th` | `6577778888` | **`admin`** | สร้างผ่านแอปจริง 2026-08-09 (`full_name`/`phone` มาจาก meta data จริง) ตั้งเป็น admin ตาม D-02 เพื่อเทส `HomeAdmin` · 🔴 **`email_confirmed_at` ถูก patch ด้วย SQL** — บัญชีนี้ไม่เคยผ่านขั้นตอนยืนยันอีเมลจริงเลย ยังไม่ได้ล้าง (ดู "งานค้าง — Confirm Email" ด้านบน) · **ใช้บัญชีนี้เทส layer อื่นได้เลยระหว่างพักงาน L1** เพราะ login เข้า Home/HomeAdmin ได้จริง — ห้ามใช้เทส confirm-email เอง |

`full_name` ของ 4 บัญชีแรกยังเป็นชื่อปลอมที่เติมด้วยมือ (มาจากรอบทดสอบผ่าน Dashboard เมื่อ 2026-08-07) — คนละเรื่องกับ `mju6577778888` ที่ชื่อมาจาก meta data จริง

บัญชีทดสอบสดชุดแรกที่ใช้เทส D-19/D-20 (`mju6500000099`, `mju6500000101`, `mju6606105382` เดิม, `mju6606105383`) ถูกลบทิ้งไปเมื่อ 2026-08-10 — **`mju6606105382@mju.ac.th` ถูกสมัครใหม่และใช้เทส confirm-email สำเร็จอีกครั้งแล้วเมื่อ 2026-08-17** (D-34) ปัจจุบันเป็นบัญชี user ปกติที่ยืนยันอีเมลแล้ว ใช้แอปได้จริง

## ❓ ค้างอยู่

- จะทำ role-based redirect ซ้ำที่หน้า Splash/Initial (auto-login) ด้วยไหม — ยังไม่มีหน้า Splash ใน v2
- `handle_new_user()` ยังไม่มี `ON CONFLICT` — ถ้าแถวใน `"Profile"` มีอยู่แล้วจะ error ทั้งรายการ ต้องกันไหม
- **Confirm Email รับมือยังไง** → ✅ ย้ายไปเป็นงานค้างชัดเจนที่ `../DECISIONS.md` **D-17** แล้ว ไม่ใช่คำถามลอย ๆ อีกต่อไป
- **`avatar_url` ไม่ผูกกับไฟล์จริงใน bucket** — เปลี่ยนรูปแล้วไฟล์เก่าค้าง / ลบไฟล์แล้วคอลัมน์ยังชี้ URL เดิม (รูปแตก) จะแก้ทางไหนยังไม่เลือก ดู **P-12**
- **จะเพิ่ม unique index บน `lower(email)` ไหม** — ดู **P-11** (ตอนนี้ trigger กันให้อยู่แล้ว จึงยังไม่เร่ง)

## 🔤 ชื่อที่ยืนยันกับโปรเจกต์จริงแล้ว (v2, อัปเดต 2026-08-09)

ตรวจผ่าน `flutterflow ai status` / `inspect` / generated code จริง — ไม่ใช่ชื่อที่เดาไว้อีกต่อไป

| ที่ใช้ในเอกสาร | ประเภท | หมายเหตุ |
|---|---|---|
| `SignUp` · `Login` · `Home` · `HomeAdmin` · `ConfirmEmail` · `ProfileUser` · `ProductDetails` · `addproduct` · `Mypost` | ชื่อหน้า | `ConfirmEmail` ใหม่ 2026-08-09 (D-20, route `/confirm-email`) · `ProfileUser`/`ProductDetails`/`Mypost` เพิ่ม 2026-08-14 — 9 หน้าที่มีอยู่ใน v2 ตอนนี้ |
| `ProfileUser` widget keys | Node key | `Scaffold_8myjbpxe` (page query) · `Container_vxr167r8` AvatarUploadTrigger · `Image_lt96pnt8` AvatarStoredImage · `Container_r0wbdujg` placeholder · `Text_wonqknhq` full_name · `Text_8jg3asd2` fallback ชื่อ · `Text_1x2wui64` email · `Container_twiyefr8` Edit Profile (toggle) · `Button_wbzo87yz` Log Out — 🔴 **อ้างด้วย key เสมอ ห้ามใช้ positional path** (PT-14 ข้อ 4) |
| `SignUpWithProfile` · `IsCurrentUserAdmin` · `LoginWithEmailPassword` · `VerifyOtp` · `ResendSignupOtp` | Custom Action | ทั้งหมดรับ 0 argument ตามเหตุผลใน PT-09 · `LoginWithEmailPassword` ใหม่ 2026-08-09 (D-17) แทนที่ built-in `LoginEmailPassword` — sync `AppStateNotifier` เอง ดู PT-11 · `VerifyOtp`/`ResendSignupOtp` ใหม่ 2026-08-09 (D-20) — `VerifyOtp` ก็ sync `AppStateNotifier` เองเหมือนกัน (PT-11 ใช้ซ้ำ) |
| `email` · `password` · `fullName` · `phone` · `loginEmail` · `loginPassword` · `otpCode` | App State | `loginEmail`/`loginPassword` ใหม่ 2026-08-09 — ย้ายจาก Page State ของ `Login` มาเป็น App State เพราะ `LoginWithEmailPassword` (custom action 0 arg) อ่านได้แค่ App State ตาม PT-09 · `otpCode` ใหม่ 2026-08-09 (D-20) — อ่านโดย `VerifyOtp` |

🔴 **Page State `loginEmail`/`loginPassword` เดิมของ `Login`** (คนละตัวกับ App State ชื่อเดียวกันด้านบน) **ยังคงมีอยู่ในโปรเจกต์แต่ไม่มีอะไรเขียนเข้าไปแล้ว** — เป็น dead state ค้างจากก่อนแก้ D-17 ยังไม่ได้ลบ (ความเสี่ยงต่ำ ไม่กระทบการทำงาน แค่รก)

**ชื่อของ L2 ที่เคยร่างไว้ (`MyPost`, `Inspect`) เป็นชื่อจาก v1 (archived) — ยังไม่มีใน v2** ต้องตั้งใหม่ตามกติกาใน D-16 (PascalCase, ไม่มีเว้นวรรค) ห้ามสมมติว่ายังใช้ชื่อเดิมได้ — `addproduct` (lowercase, ไม่ตรงกติกา D-16 แต่เป็นของจริงที่มีอยู่แล้ว) ผูก backend เสร็จแล้ว ดู `layers/L2-listings.md`
