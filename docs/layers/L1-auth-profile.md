# Layer 1 — Authentication & User Profiles

> schema/RLS → `../SCHEMA.md` · สถานะ → `../STATUS.md` · ตรวจ → `../checks/L1.sql`

## 🎯 เป้าหมาย

ผู้ใช้สมัคร/ล็อกอินด้วย `@mju.ac.th` ได้ ข้อมูลโปรไฟล์ถูกต้อง และเป็นฐานให้ RLS ของทุกตารางอื่นอ้าง `auth.uid()` ได้

## 🧩 ขั้นตอน Supabase ที่เหลือ

**🟨 เหลืออย่างเดียว: เส้นทาง `full_name` ยังไม่เคยรันสำเร็จ** — `handle_new_user()` อ่านจาก `raw_user_meta_data->>'full_name'` แต่ user 4 คนที่ทดสอบสมัครผ่าน Dashboard ซึ่งส่ง metadata ไม่ได้ ชื่อในตารางตอนนี้เป็นค่าเติมมือ
→ ปิดได้เมื่อสมัครผ่านหน้า FlutterFlow Sign Up ที่ส่ง `full_name` แล้วเห็นชื่อโผล่เอง (ผลตรวจ: `../VERIFICATION.md` V-02 ข้อ 5)

**ทำแล้ว:** คอลัมน์ครบ (`role`/`student_id`/`phone`/`bio` + constraints) · RLS ของ `"Profile"` มีอยู่แล้วจริง **ไม่ต้องเขียนใหม่** · view `public_profiles` สร้างแล้ว · **trigger auto-insert Profile (P-01) apply แล้ว** · **server-side validate โดเมน `@mju.ac.th` (P-02) apply แล้ว** — รวมอยู่ใน `handle_new_user()` ตัวเดียวกัน ดู `../SCHEMA.md`

## 🚧 เคลียร์ก่อนกดใน FlutterFlow (ตรวจแล้ว 2026-08-08)

| # | เรื่อง | สถานะ |
|---|---|---|
| 1 | **เปิด "Confirm email" อยู่ไหม** (Dashboard → Auth → Email) | ❓ ตรวจจาก DB ไม่ได้ **ต้องเปิดดูเอง** — ถ้าเปิดอยู่ สมัครเสร็จจะยังไม่มี session → **PT-07 query `role` ไม่ได้** · จะรับมือยังไงยัง**ไม่ได้ตกลง** ดู ❓ ค้างอยู่ ท้ายไฟล์ |
| 2 | **ยังไม่มี admin ในระบบเลย (0 คน)** | ต้องตั้งด้วยมือตาม **D-02** ก่อน ไม่งั้นสาขา `role == "admin"` ของ PT-07 เทสไม่ได้ |
| 3 | **ห้ามเทสด้วย 4 บัญชีเดิม** | `full_name` ของทั้ง 4 คน**ถูกเติมมือไปแล้ว** เทสแล้วจะเห็นชื่อขึ้นแล้วนึกว่าผ่าน — ต้องสมัคร**บัญชีที่ 5 ใหม่เอี่ยม** (อีเมลซ้ำไม่ได้ ติด `Profile_email_key`) |
| 4 | **FlutterFlow CLI / MCP** | ❌ ยังไม่มีในเครื่อง (`flutterflow` not found · ไม่มี `FLUTTERFLOW_API_TOKEN` · ไม่มี `.mcp.json`) → Claude **inspect ชื่อจริงในโปรเจกต์ไม่ได้** กฎข้อ 3 ต้องตรวจด้วยตาไปก่อน และ `ui-checker` ยังใช้ไม่ได้ 🔴 token ห้าม commit |

## 🎨 ขั้นตอน FlutterFlow

> 🔴 **`student_id` ห้ามเขียนจากฝั่ง client เด็ดขาด** — trigger `handle_new_user()` derive ค่านี้จากอีเมลให้อยู่แล้ว
> และ CHECK `profile_student_id_matches_email` บังคับให้ `student_id` ตรงกับอีเมลเสมอ
> ยิงค่าไปเองเมื่อไหร่ = constraint violation ทันที (ดู D-10)
> **ห้ามมีช่อง `student_id` ในฟอร์ม Sign Up และในฟอร์ม Edit Profile**

1. **หน้า Sign Up** — ฟอร์ม email / password / full_name / `phone` + validate อีเมลก่อน submit
   🔴 **ห้าม validate ด้วย "ลงท้ายด้วย `@mju.ac.th`" เฉย ๆ** — `hacker@evil.com@mju.ac.th` ลงท้ายถูกจริง
   ใช้ regex เต็ม `^[^@]+@mju\.ac\.th$` ให้ตรงกับที่ DB บังคับ (ดู D-10 หัวข้อช่องโหว่)
   ❌ **ไม่มีช่อง `student_id`** — ถ้าอยากโชว์ให้ผู้ใช้เห็น ให้แสดงเป็น read-only หลังสมัครเสร็จ
2. **Action Flow ตอน submit** — Supabase Auth → Sign Up **แล้วจบ ไม่ต้องมี Action ที่สอง**
   - ส่ง **user meta data 2 key: `full_name` และ `phone`** (สะกดเป๊ะ ๆ ทั้งคู่ — กฎข้อ 3)
     trigger อ่านจาก `raw_user_meta_data->>'...'` **สะกดผิดจะไม่ error แค่ได้ NULL เงียบ ๆ**
   - trigger สร้างแถวใน `"Profile"` ให้ครบ `id`/`email`/`full_name`/`role`/`student_id`/`phone` ในคราวเดียว
   - ❌ **ห้ามมี Action "Update Row" ตามหลังเพื่อใส่ `phone`** — ถ้าเปิด Confirm email ไว้จะยังไม่มี session แล้ว update ล้มเงียบ (เหตุผลเต็ม: **D-14**)
   - 🔴 **validate โดเมน `@mju.ac.th` ฝั่ง client ให้ผ่านก่อน submit เสมอ — บังคับ ไม่ใช่ทางเลือก**
     trigger ปฏิเสธได้จริงก็จริง แต่ error ที่กลับมาถึง client คือ **HTTP 500 body ว่าง** (`Failed to create user: {}`)
     ข้อความ `Only @mju.ac.th email addresses are allowed` ถูกกลบหายไประหว่างทาง (ดู `../SCHEMA.md` หัวข้อ P-02)
     → เอามาโชว์ผู้ใช้ไม่ได้เลย ถ้าไม่ validate ฝั่ง client ผู้ใช้จะเจอ error ปริศนาแล้วไปต่อไม่ถูก
3. **หน้า Log In** — ใช้ **PT-07** (role-based navigation) ใน `../PATTERNS.md`
4. **หน้า Edit Profile** — Backend Query อ่าน/เขียน `"Profile"` ของ `auth.uid()` แก้ได้แค่ `full_name` / `avatar_url` / `phone` / `bio`
   ❌ **`student_id` และ `role` แก้ไม่ได้** — `with_check` ของ policy บล็อกไว้ทั้งคู่ ใส่ลง Update Row เมื่อไหร่ทั้ง statement fail
   - **อัปรูปโปรไฟล์** → bucket **`avatars`** (public · 2 MB · jpeg/png/webp) path `<currentUserId>/<ชื่อไฟล์>` — ใช้ **PT-08** ท่าเดียวกับรูปสินค้า ต่างแค่ชื่อ bucket
   - เอา URL ที่ได้ไปใส่ `avatar_url` ใน Update Row เดียวกับ `full_name`/`phone`/`bio`
   - ⚠️ เปลี่ยนรูปแล้ว**ไฟล์เก่าไม่ถูกลบ** — `avatar_url` เป็นแค่ text ไม่ผูกกับไฟล์จริง (หนี้ใน D-15)
5. **App State** — `currentUserId` (จาก Auth), `currentUserRole` (จาก `Profile.role`)

## 🧪 Definition of Done

**ฝั่ง Supabase — ✅ ข้อด้านล่างผ่านครบ (ผลเต็ม: `../VERIFICATION.md` V-02 / V-04)**
**แต่ L1 ยังไม่ปิด 🟨** — เส้นทาง `full_name` ของ trigger ตรวจได้เฉพาะฝั่ง FlutterFlow (ข้อแรกของหัวข้อถัดไป) ซึ่งยังไม่เคยรัน

- [x] สมัครด้วยอีเมลนอกโดเมน `@mju.ac.th` ถูกปฏิเสธที่ระดับ DB — ยืนยันจาก auth log (`P0001`)
- [x] อีเมล `@` ซ้อน (`hacker@evil.com@mju.ac.th`) ถูกปฏิเสธ — เคสที่ regex เดิมปล่อยผ่าน (V-09)
- [x] `"Profile".email` ถูก normalize เป็นตัวเล็กเสมอ แม้ผู้ใช้พิมพ์ตัวใหญ่ (V-09)
- [x] สมัครสำเร็จ → มี row ใน `"Profile"` อัตโนมัติ พร้อม `role = 'user'`
- [x] อีเมล `mju<10หลัก>@mju.ac.th` → `student_id` derive อัตโนมัติถูกต้อง (รวมเคสตัวใหญ่)
- [x] อีเมล `@mju.ac.th` ที่ไม่ใช่รูปแบบนั้น (บุคลากร) → สมัครผ่าน และ `student_id` เป็น NULL
- [x] แก้โปรไฟล์คนอื่นไม่ได้ / เปลี่ยน `role` ตัวเองไม่ได้ / เปลี่ยน `student_id` ตัวเองไม่ได้ — ทดสอบด้วย user ธรรมดาจริง
- [x] `checks/L1.sql` ผ่านครบทุกข้อ

**ฝั่ง FlutterFlow — ยังไม่เริ่ม**

- [ ] `full_name` **และ `phone`** ไม่เป็น NULL หลังสมัคร**บัญชีใหม่**ผ่านแอปจริง (ทั้งคู่มาจาก user meta data — D-14)
- [ ] กรอกช่องเบอร์เป็นช่องว่างล้วนแล้วสมัคร → `phone` ต้องเป็น `NULL` ไม่ใช่ `''`
- [ ] อัปรูปโปรไฟล์เข้า `avatars` แล้วรูปโผล่จริงจาก public URL ที่เก็บใน `avatar_url`
- [ ] validate โดเมนฝั่ง client แล้วขึ้นข้อความที่ผู้ใช้เข้าใจ (server ส่งกลับแค่ 500 เปล่า)
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
- ~~รูปแบบอีเมลจริงของแม่โจ้เป็นยังไง~~ ✅ **pete ยืนยันแล้ว 2026-08-08: `mju<10หลัก>@mju.ac.th`** ตรงกับ constraint เดิมพอดี ไม่ต้องแก้ (ปิดใน D-10)
- `handle_new_user()` ยังไม่มี `ON CONFLICT` — ถ้าแถวใน `"Profile"` มีอยู่แล้วจะ error ทั้งรายการ ต้องกันไหม

### ค้างเพิ่มจากรอบวางแผน 2026-08-08 — 🚧 ทั้งหมดนี้ยังไม่ตกลง

- **ถ้า Confirm email เปิดอยู่ จะให้ Sign Up จบยังไง** — ข้อเสนอของ Claude (ยังไม่ตอบรับ) คือพาไปหน้าแจ้ง "ไปยืนยันอีเมลก่อน" แล้วให้ PT-07 ทำงานตอน Log In แทน
  ทางเลือกอื่นที่ยังไม่ได้ชั่งน้ำหนัก: ปิด Confirm email ไปเลย (สมัครง่ายขึ้น แต่ใครก็พิมพ์อีเมล `@mju.ac.th` ของคนอื่นได้ — **การยืนยันตัวตนด้วยอีเมลมหาลัยจะไม่เหลือความหมาย**)
- **`avatar_url` ไม่ผูกกับไฟล์จริงใน bucket** — เปลี่ยนรูปแล้วไฟล์เก่าค้าง / ลบไฟล์แล้วคอลัมน์ยังชี้ URL เดิม (รูปแตก) จะแก้ทางไหนยังไม่เลือก ดู **P-12**
- **จะเพิ่ม unique index บน `lower(email)` ไหม** — ดู **P-11** (ตอนนี้ trigger กันให้อยู่แล้ว จึงยังไม่เร่ง)
- **ตั้งใครเป็น admin คนแรก** — ต้องมีก่อนถึงจะเทสสาขา `role == "admin"` ของ PT-07 ได้ (D-02 ตั้งด้วยมือ)

## 🔤 ชื่อที่ยังไม่ยืนยันกับโปรเจกต์จริง

🔴 **[ยังไม่ยืนยันชื่อ]** — Claude **inspect โปรเจกต์ FlutterFlow ไม่ได้** (ไม่มี CLI/token ดูตารางเคลียร์ก่อนกด ข้อ 4) ชื่อด้านล่างจึงเป็นชื่อที่**เอกสารเขียนไว้ ยังไม่เคยเทียบกับของจริง** — ห้ามถือเป็นความจริงจนกว่าจะเปิดโปรเจกต์ดู แล้วค่อยลบเครื่องหมายนี้ทีละรายการ

| ที่ใช้ในเอกสาร | ประเภท |
|---|---|
| `home` · `HomeAdmin` | ชื่อหน้า (PT-07) |
| `MyPost` · `Inspect` · `AddProduct` | ชื่อหน้า (L2) |
| หน้า Sign Up · หน้า Log In · หน้า Edit Profile | **ยังไม่มีชื่อเลย** — เอกสารเรียกเป็นภาษาไทย ยังไม่ได้ตั้งชื่อจริง |
| `currentUserId` · `currentUserRole` | App State |
| `uploadedImageUrls` | Page State (PT-08) |

> ⚠️ กฎข้อ 3 ใน `CLAUDE.md` บังคับให้ชื่อตรงกัน 3 จุด — ตราบใดที่ยังตรวจฝั่ง FlutterFlow ไม่ได้ **กฎข้อนี้ยังตรวจได้แค่ครึ่งเดียว**
