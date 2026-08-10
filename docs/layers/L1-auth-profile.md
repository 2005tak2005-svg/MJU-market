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
4. **⬜ หน้า Edit Profile — ยังไม่ได้ทำ** — Backend Query อ่าน/เขียน `"Profile"` ของ `auth.uid()` แก้ได้แค่ `full_name` / `avatar_url` / `phone` / `bio`
   ❌ **`student_id` และ `role` แก้ไม่ได้** — `with_check` ของ policy บล็อกไว้ทั้งคู่ ใส่ลง Update Row เมื่อไหร่ทั้ง statement fail
   - **อัปรูปโปรไฟล์** → bucket **`avatars`** (public · 2 MB · jpeg/png/webp) path `<currentUserId>/<ชื่อไฟล์>` — ใช้ **PT-08** ท่าเดียวกับรูปสินค้า ต่างแค่ชื่อ bucket
   - เอา URL ที่ได้ไปใส่ `avatar_url` ใน Update Row เดียวกับ `full_name`/`phone`/`bio`
   - ⚠️ เปลี่ยนรูปแล้ว**ไฟล์เก่าไม่ถูกลบ** — `avatar_url` เป็นแค่ text ไม่ผูกกับไฟล์จริง (หนี้ใน D-15)
5. **App State (ของจริงใน v2 ตอนนี้):** `email` / `password` / `fullName` / `phone` (ใช้ตอน Sign Up) — **ยังไม่มี** `currentUserId` / `currentUserRole` ระดับ app ตามที่ร่างไว้เดิม เพราะ role check ย้ายไปอยู่ใน custom action `IsCurrentUserAdmin` แทน (ดูข้อ 3) ถ้า layer หลังต้องใช้ `currentUserRole` ที่ระดับ app ต้องเพิ่มเอง

## 🔴 งานค้าง — Confirm Email (D-20) หยุดไว้ชั่วคราว 2026-08-10 ต้องแก้ email deliverability ก่อนถึงจะปิด L1 ฝั่ง FlutterFlow ได้

> 🟡 **สถานะ: หยุดงานนี้ไว้ตรงนี้ ย้ายไปทำ L2/L4 ก่อน** — ไม่ใช่ปิดเรื่องนี้ทิ้ง แค่ไม่ใช่คิวด่วนแล้วเพราะติดปัญหาที่แก้จาก Supabase/FlutterFlow config ไม่ได้ตรง ๆ อ่าน `../DECISIONS.md` **D-20** ให้ครบก่อนแตะเรื่องนี้ต่อ

**ลิงก์ (D-19) สร้างเสร็จแล้วแต่ใช้งานจริงไม่ได้** — Microsoft 365 Education Safe Links ของ tenant มหาลัยดึงลิงก์ยืนยันไปสแกน/ใช้ token ทิ้งอัตโนมัติก่อนผู้ใช้จะกด (ยืนยันด้วย WHOIS ของ IP ที่ยิง `/verify` เจอ `mnt-by: MICROSOFT-MAINT` + `/verify` คืน `400: Invalid email verification type` เร็ว ~17 วินาทีหลังสมัครทุกครั้ง) — ปัญหาเชิงโครงสร้าง ไม่ใช่ตั้งค่าผิด ดู `../DECISIONS.md` **D-19**/**D-20**

**เปลี่ยนกลับเป็น OTP (D-20) — สร้างเสร็จแล้ว 2026-08-09 (ยืนยันจาก generated code จริง, กับดัก build ดู `PATTERNS.md` PT-11) แต่ทดสอบจริงแล้วติด email deliverability:**

- [x] หน้า/ข้อความหลังสมัครสำเร็จบอกผู้ใช้ให้ไปกดยืนยันในอีเมลก่อน — snackbar ปุ่ม `SignUpButton` ยืนยันจาก `generated_code/lib/pages/sign_up/sign_up_widget.dart` แล้ว
- [x] ดักเคส login แล้วเจอ "email not confirmed" ที่ปุ่ม `Login` — custom action `LoginWithEmailPassword` (0 arg ตาม PT-09) แทน built-in `LoginEmailPassword` — ยืนยันข้อความจริงจาก Supabase ตรง ๆ ด้วย curl
- [x] **แก้กับดัก PT-11:** custom action sync `AppStateNotifier.instance.update(...)` เอง เพราะ auth stream ของแอปถูก debounce ไว้ — ยืนยันจาก generated code
- [x] **สร้างหน้า `ConfirmEmail` + custom action `VerifyOtp`/`ResendSignupOtp`** — ยืนยันจาก `generated_code/lib/confirm_email/confirm_email_widget.dart` ว่าตรงกับที่ตั้งใจเป๊ะ (ปุ่มยืนยันเรียก `verifyOtp()` แล้ว route ตาม `isCurrentUserAdmin`, ปุ่ม resend เรียก `resendSignupOtp()`)
- [x] **แก้ email template "Confirm signup"** ให้โชว์ `{{ .Token }}` เป็นตัวเลขล้วน ไม่ใช่ลิงก์ — เจอ syntax bug ระหว่างแก้ (`href={{ .Token }}"` ขาด quote เปิด ทำให้ Supabase render template fail ตอนสมัครจริง, error `unexpected_failure`) แก้แล้วโดยตัด `<a href>` ออกทั้งหมด
- [x] ยืนยันแล้วว่า Supabase **ส่งอีเมลออกจริง** — `POST /signup` status 200, เจอเมลจริงใน Gmail "ส่งแล้ว" (Sent) พร้อมรหัส OTP จริง (เช่น `80240827`)
- [ ] 🔴 **บล็อกอยู่ตรงนี้: อีเมล OTP ไปไม่ถึงกล่องผู้รับ `@mju.ac.th` เลย** — เช็คครบ 4 จุดแล้วไม่เจอ: ไม่อยู่ Inbox, ไม่อยู่ Junk, ไม่มี bounce-back กลับ Gmail, ไม่อยู่ Microsoft 365 Defender quarantine — เข้าข่าย **Zero-hour Auto Purge (ZAP)** เพราะ custom SMTP (Gmail ส่วนตัว) ไม่มี sending reputation กับ tenant นี้มาก่อนเลย รายละเอียดเต็ม `../DECISIONS.md` **D-20**
- [ ] **ยังไม่ได้ลอง:** ปิด custom SMTP ชั่วคราว กลับไปใช้ default mailer ของ Supabase เทส 1 รอบ เพื่อแยกว่าปัญหาอยู่ที่ Gmail relay เจาะจง หรือ tenant บล็อกอีเมลลักษณะนี้ทั้งหมด
- [ ] **ยังไม่ทดสอบ end-to-end ผ่านแอปจริงเลยสักครั้ง** เพราะไม่เคยมี OTP ไปถึงผู้ทดสอบ — ต้องแก้ deliverability ก่อนถึงจะเทสต่อได้
- [ ] **บัญชีทดสอบ `mju6577778888@mju.ac.th` ยังไม่ถูกล้าง** — ตาม D-17 ต้องล้างแล้วเทสสมัคร+ยืนยัน+login ใหม่ผ่าน flow จริงทั้งเส้น ก่อนปิด L1 ได้เต็มตัว
- [ ] 🔴 **ไม่มีบัญชีทดสอบสดพร้อมใช้แล้ว** — `mju6500000099@mju.ac.th` (บัญชีที่เคยเตรียมไว้เทส confirm flow) **ถูกลบไปแล้ว 2026-08-10** พร้อมบัญชีทดสอบเก่าอีก 3 บัญชี (`mju6500000101`, `mju6606105382`, `mju6606105383`) เพื่อเคลียร์ข้อมูลค้างระหว่างเทส D-19/D-20 — ต้องสมัครใหม่เมื่อกลับมาทำต่อ

**คำแนะนำระหว่างพัก:** ใช้ `mju6577778888@mju.ac.th` (admin, `email_confirmed_at` patch ด้วย SQL ไว้แล้ว เข้า Home/HomeAdmin ได้จริง) ทดสอบ layer อื่น — **ห้ามใช้บัญชีนี้เทส confirm-email เอง** สภาพถูกลัดผ่านไปแล้ว

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

**ฝั่ง FlutterFlow — 🟨 ผ่านบางส่วน ยังปิด L1 ไม่ได้**

- [x] `full_name` **และ `phone`** ไม่เป็น NULL หลังสมัคร**บัญชีใหม่**ผ่านแอปจริง — ยืนยันแล้ว 2026-08-09 (`mju6577778888@mju.ac.th`)
- [x] validate โดเมนฝั่ง client แล้วขึ้นข้อความที่ผู้ใช้เข้าใจ — ทำใน `SignUpWithProfile` แล้ว
- [x] `role = admin` → ไป `HomeAdmin`, `role = user` → ไป `Home` ถูกทุกครั้ง — ยืนยันด้วย `auth.users.last_sign_in_at` จริงทั้ง 2 เส้นทาง 2026-08-09
- [ ] กรอกช่องเบอร์เป็นช่องว่างล้วนแล้วสมัคร → `phone` ต้องเป็น `NULL` ไม่ใช่ `''` — ยังไม่ได้เทสเคสนี้ผ่านแอปจริง (trigger รองรับแล้วตาม D-14 แต่ path ผ่าน UI ยังไม่เทส)
- [ ] อัปรูปโปรไฟล์เข้า `avatars` แล้วรูปโผล่จริงจาก public URL — Edit Profile ยังไม่ได้สร้าง
- [x] **สมัครเสร็จบอกผู้ใช้ให้ไปยืนยันอีเมล + login ก่อนยืนยันดักได้อย่างเข้าใจ** — โค้ดสร้างเสร็จแล้ว (ดูหัวข้อ "งานค้าง — Confirm Email" ด้านบน) แต่ยังไม่ผ่านการทดสอบ end-to-end จริงสักครั้งเพราะติด email deliverability (D-20) — **บล็อกการปิด L1 อยู่ ถูกพักไว้ 2026-08-10 ไปทำ layer อื่นก่อน**
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

🔴 **บัญชีทดสอบสด 4 บัญชีที่ใช้เทส D-19/D-20 (`mju6500000099`, `mju6500000101`, `mju6606105382`, `mju6606105383` — ทุกตัว `@mju.ac.th`) ถูกลบทิ้งแล้ว 2026-08-10** เพื่อเคลียร์ข้อมูลค้าง (ลบ `"Profile"` ก่อนแล้วค่อยลบ `auth.users` เพราะ `Profile_id_fkey` ไม่มี `ON DELETE CASCADE`) — **ไม่มีบัญชีสดพร้อมใช้เทส confirm-email แล้ว ต้องสมัครใหม่เมื่อกลับมาทำ D-20 ต่อ** ดู `../DECISIONS.md` **D-20**

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
| `SignUp` · `Login` · `Home` · `HomeAdmin` · `ConfirmEmail` | ชื่อหน้า | `ConfirmEmail` ใหม่ 2026-08-09 (D-20, route `/confirm-email`) — 5 หน้าที่มีอยู่ใน v2 ตอนนี้ |
| `SignUpWithProfile` · `IsCurrentUserAdmin` · `LoginWithEmailPassword` · `VerifyOtp` · `ResendSignupOtp` | Custom Action | ทั้งหมดรับ 0 argument ตามเหตุผลใน PT-09 · `LoginWithEmailPassword` ใหม่ 2026-08-09 (D-17) แทนที่ built-in `LoginEmailPassword` — sync `AppStateNotifier` เอง ดู PT-11 · `VerifyOtp`/`ResendSignupOtp` ใหม่ 2026-08-09 (D-20) — `VerifyOtp` ก็ sync `AppStateNotifier` เองเหมือนกัน (PT-11 ใช้ซ้ำ) |
| `email` · `password` · `fullName` · `phone` · `loginEmail` · `loginPassword` · `otpCode` | App State | `loginEmail`/`loginPassword` ใหม่ 2026-08-09 — ย้ายจาก Page State ของ `Login` มาเป็น App State เพราะ `LoginWithEmailPassword` (custom action 0 arg) อ่านได้แค่ App State ตาม PT-09 · `otpCode` ใหม่ 2026-08-09 (D-20) — อ่านโดย `VerifyOtp` |

🔴 **Page State `loginEmail`/`loginPassword` เดิมของ `Login`** (คนละตัวกับ App State ชื่อเดียวกันด้านบน) **ยังคงมีอยู่ในโปรเจกต์แต่ไม่มีอะไรเขียนเข้าไปแล้ว** — เป็น dead state ค้างจากก่อนแก้ D-17 ยังไม่ได้ลบ (ความเสี่ยงต่ำ ไม่กระทบการทำงาน แค่รก)

**ชื่อของ L2 ขึ้นไปที่เคยร่างไว้ (`home` lowercase, `MyPost`, `Inspect`, `AddProduct`, `currentUserId`, `currentUserRole`, `uploadedImageUrls`) เป็นชื่อจาก v1 (archived) ทั้งหมด — ยังไม่มีใน v2 เลยสักตัว** ต้องตั้งใหม่ตอนเริ่ม L2 ตามกติกาใน D-16 (PascalCase, ไม่มีเว้นวรรค) ห้ามสมมติว่ายังใช้ชื่อเดิมได้
