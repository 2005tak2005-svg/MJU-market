# DECISIONS.md — บันทึกการตัดสินใจ

> อ่านไฟล์นี้เมื่ออยากรู้ **"ทำไมถึงเป็นแบบนี้"** เท่านั้น — ไม่ต้องอ่านตอนลงมือทำงานปกติ
> ถ้ามีการตัดสินใจใหม่ ให้ต่อท้ายเป็น D-xx อันใหม่ ห้ามลบของเก่า

---

## D-01 — สร้าง view `public_profiles` แทนการแก้ RLS ของ `"Profile"` (2026-08-02)

**บริบท:** เอกสารเดิมเขียนผิดว่า `"Profile"` "ยังไม่มี policy = deny-all" ตรวจจริงแล้วพบว่า **มี policy อยู่แล้ว** (น่าจะมาจาก FlutterFlow Supabase RLS wizard) และออกแบบมาดี — กัน privilege escalation ด้วย `WITH CHECK` ที่ล็อกไม่ให้ user เปลี่ยน `role` ตัวเอง

**ปัญหาที่ตามมา:** user ทั่วไปเห็นได้แค่โปรไฟล์ตัวเอง → ทุก view ที่ join `"Profile"` เพื่อดึงชื่อ คืน NULL — กระทบ 3 view พร้อมกัน (`products_review_view`, `chat_summary`, `chat_messages_view`)

**ทางเลือกที่พิจารณา:** (ก) ผ่อน RLS ของ `"Profile"` ให้ทุกคน SELECT ได้ → เปิดเผย email/phone/student_id ด้วย ไม่เอา (ข) สร้าง view เปิดเผยเฉพาะ field ที่ปลอดภัย ✅

**ตัดสินใจ:** สร้าง `public_profiles` (id/full_name/avatar_url) โดย**ตั้งใจไม่ใส่** `security_invoker` เพื่อให้รันด้วยสิทธิ์ owner (`postgres` ที่มี `rolbypassrls = true` — ยืนยันด้วย query จริงแล้ว) แล้วให้ทั้ง 3 view join กับ view นี้แทน

**ผลข้างเคียงที่เจอระหว่างแก้:** ตาราง `"CAT"` ก็เปิด RLS แต่ไม่มี policy (deny-all) ทำให้ `category_name` เป็น NULL ด้วย → แก้โดยเพิ่ม allow-all เพราะเป็นแค่ lookup ไม่มีข้อมูลอ่อนไหว

**บทเรียน:** บั๊กชุดนี้รอดสายตามานานเพราะทดสอบด้วย admin อย่างเดียว → กลายเป็นกฎถาวรใน `CLAUDE.md` (DoD ร่วม ข้อ 2)

---

## D-02 — admin กำหนดด้วยมือเท่านั้น (2026-08-02)

สมัครใหม่ทุกคน default `role = 'user'` เสมอ การตั้ง admin ทำโดยรัน SQL ตรงใน Supabase dashboard:

```sql
UPDATE "Profile" SET role = 'admin' WHERE email = '...';
```

**เหตุผล:** ไม่มีปุ่มในแอปให้ตั้ง role = user ทั่วไปยกระดับตัวเองไม่ได้แม้จะยิง API ตรง (มี `WITH CHECK` ล็อกอีกชั้น)
**ในอนาคต:** ถ้ามี admin หลายคน ค่อยทำหน้าจัดการ role ใน Layer 8

---

## D-03 — ใช้ allow-all RLS ตอน prototype (2026-08-02)

`products` / `chat` / `chat_user` / `chat_message` ใช้ `FOR ALL TO authenticated USING (true) WITH CHECK (true)`

**เหตุผล:** ความเร็วตอน prototype — ตาม pattern ต้นแบบจากคลิปสอน FlutterFlow chat

**หนี้ที่รับไว้ (ต้องใช้คืนก่อน production):**
- authenticated user ทุกคนอ่าน/เขียนแชททุกห้องได้ → ต้องเปลี่ยนเป็น restrictive ตาม `chat_user` membership
- หน้า `Inspect` (admin) กันด้วย UI เท่านั้น (ซ่อน route ตาม `currentUserRole`) ไม่ใช่ RLS จริง — user ที่ยิง API ตรงยัง approve สินค้าได้

---

## D-04 — แยก `moderation_status` ออกจาก `status` (2026-08-02)

- `moderation_status` = สถานะตรวจสอบ (pending/approved/rejected) — Layer 2
- `status` = สถานะการขาย (available/reserved/sold) — Layer 5

**เหตุผล:** ถ้าใช้คอลัมน์เดียวกัน Layer 5 จะมาเขียนทับสถานะตรวจสอบ

---

## D-05 — `student_id` เป็นตัวเลข 10 หลัก unique (2026-08-02)

`varchar` + UNIQUE + `CHECK (student_id ~ '^[0-9]{10}$')` — รหัสผิดรูปแบบหรือซ้ำ insert ไม่ผ่านตั้งแต่ระดับ DB
`phone` เป็น free text ไม่มี unique/format (ตั้งใจ — เบอร์เปลี่ยนบ่อย และมีเบอร์ต่อประกาศแยกที่ `products.contact_phone` อยู่แล้ว)

---

## D-06 — บั๊ก `products.seller_id` default (2026-08-02)

เดิม default เป็น `gen_random_uuid()` (ผิด — สร้าง uuid มั่วที่ไม่ตรงกับใครเลย) แก้เป็น `auth.uid()` แล้ว

**แต่ยังคงกฎไว้:** FlutterFlow ต้องผูก `seller_id = currentUserId` เองใน Action Flow อยู่ดี ไม่พึ่ง default อย่างเดียว

---

## D-07 — `flutterflow ai` (MCP) เป็นทางหลัก, `export-code` เป็น fallback (2026-08-02)

- **`flutterflow ai`** — agent-native มี MCP server ในตัว คำสั่งที่ใช้ได้จริง: `status` / `inspect` / `validate` / `run`
  (`plan` / `trace` เป็นชื่อรุ่นเก่า เลิกใช้)
- **`export-code`** — ดึงโค้ดทางเดียว ใช้ดูโค้ด Flutter ดิบตอน debug เท่านั้น **ไม่ sync กลับ ห้าม edit แล้ว re-import**
- License: Business Source License 1.1 — ใช้ production ได้เฉพาะคู่กับ FlutterFlow ห้ามทำ low-code builder แข่ง
- ⚠️ ยังไม่ได้ทดสอบจริงว่า `run`/`validate` ครอบคลุม Action Flow ซับซ้อน/Realtime แค่ไหน

---

## D-08 — implementer เดียว + subagent ตรวจสอบ (แทน agent ต่อ layer)

**ทางเลือกที่ปฏิเสธ:** agent 1 ตัวต่อ 1 layer ทำขนานกัน

**เหตุผลที่ไม่เอา:**
- layer ไม่เป็นอิสระจริง — D-01 แก้ทีเดียวกระทบ L1/L2/L4 พร้อมกัน, `find_or_create_chat` ใช้ร่วม L2/L3/L4, `products` แชร์ระหว่าง L2/L5, L6 trigger บนตารางของ L2/L4
- state ที่แชร์มีชุดเดียว: Supabase project เดียว + FlutterFlow project เดียว ไม่มี branch แยกที่ merge ได้จริง
- งาน FlutterFlow ส่วนใหญ่ทำมือใน GUI — agent เป็นเจ้าของ layer ไม่ได้อยู่ดี

**ตัดสินใจ:** implementer ตัวเดียวไล่ L1→L8 + subagent read-only 3 ตัวไว้ตรวจ (ดู `AGENTS.md`)
**ข้อยกเว้นในอนาคต:** L6/L7/L8 เป็นตารางใหม่ที่ไม่ทับของเดิม พอ L1–L5 นิ่งแล้วค่อยพิจารณาแตกขนาน

> 📌 ไม่มี **D-09** — เลขข้ามไป ไม่ใช่เอกสารหาย

---

## D-10 — CHECK ผูก `student_id` เข้ากับ `email` (พบตอนตรวจ DB 2026-08-07)

**สถานะ: ✅ ปิดแล้ว 2026-08-08** — pete ยืนยันรูปแบบอีเมลจริงว่าตรงกับ constraint (รายละเอียดท้ายหัวข้อ)
เดิมบันทึกไว้เพราะ constraint นี้ apply อยู่ใน DB แล้วโดยไม่มีใครจดไว้

```sql
CONSTRAINT profile_student_id_matches_email CHECK (
  student_id IS NULL
  OR (email IS NOT NULL
      AND lower(email) = 'mju' || student_id || '@mju.ac.th')
)
```

คู่กับ `handle_new_user()` ที่ derive ค่าให้เอง:

```sql
derived_student_id := substring(new.email from '^mju([0-9]{10})@mju\.ac\.th$');
```

### ผลข้างเคียงที่ต้องรู้

1. **ใครที่อีเมลไม่ตรงรูปแบบ `mju<10หลัก>@mju.ac.th` จะมี `student_id` ไม่ได้เลย** — ตั้งเป็นค่าอื่นไม่ได้ ตั้งเองก็ไม่ได้ เหลือทางเดียวคือ NULL
   → กระทบบุคลากร/อาจารย์โดยตรง ซึ่งเป็นกลุ่มผู้ใช้ที่โปรเจกต์นี้ตั้งใจรองรับตั้งแต่ต้น
2. **`student_id` กลายเป็นข้อมูล derived ไม่ใช่ข้อมูลที่ผู้ใช้กรอก** — client เขียนไม่ได้เลย (ดู L1 ที่แก้ตามข้อนี้แล้ว)
3. **เปลี่ยนอีเมลทีหลังไม่ได้ถ้ามี `student_id` อยู่** — จะชน CHECK เว้นแต่เคลียร์ `student_id` เป็น NULL ก่อน
4. **ซ้อนทับกับ D-05** — D-05 บอกแค่ "ตัวเลข 10 หลัก unique" ตอนนี้เข้มกว่านั้นมาก ต้องอ่านคู่กัน
5. ~~`lower(email)` ใช้ตอนเทียบ แต่ `handle_new_user()` ไม่ได้ `lower()` ก่อน derive — อีเมลตัวใหญ่จะ derive ไม่ออก~~
   ✅ **ทดสอบแล้ว 2026-08-07 ไม่เป็นปัญหา** — สมัครด้วย `MJU6511112222@mju.ac.th` ได้ `student_id = '6511112222'` ถูกต้อง
   เพราะ Supabase normalize อีเมลเป็นตัวเล็กก่อนเก็บลง `auth.users` regex จึงเจอเสมอ
   ⚠️ **แต่นั่นคือพฤติกรรมของ GoTrue ไม่ใช่ของ Postgres** — เขียนลง `auth.users` ตรง ๆ (service_role / SQL) ไม่ผ่านการ normalize นั้น 2026-08-08 จึงย้ายมา `lower()` ใน trigger เองแทนที่จะพึ่ง GoTrue

### ✅ ส่วนที่ยืนยันด้วยการทดสอบจริงแล้ว (2026-08-07)

สมัคร user 4 คนผ่าน Dashboard แล้วได้ผลตามที่ constraint ตั้งใจทุกเคส:

| อีเมล | `student_id` |
|---|---|
| `mju6512345678@mju.ac.th` | `6512345678` |
| `somchai.j@mju.ac.th` (บุคลากร) | `NULL` — ยืนยันผลข้างเคียงข้อ 1 ว่าเกิดขึ้นจริง |
| `MJU6511112222@mju.ac.th` | `6511112222` |

และยืนยันผลข้างเคียงข้อ 2 แล้วเช่นกัน — user ธรรมดาพยายาม `UPDATE student_id` ตัวเองถูกปฏิเสธด้วย `42501`

### ✅ ปิดแล้ว 2026-08-08 — pete ยืนยันรูปแบบอีเมลจริง

**รูปแบบจริงของ ม.แม่โจ้ คือ `mju<10หลัก>@mju.ac.th`** ตรงกับที่ constraint เดาไว้พอดี
→ `profile_student_id_matches_email` และ `profile_student_id_format` **ถูกอยู่แล้ว ไม่ต้องแก้** และผลข้างเคียงข้อ 1 (บุคลากรไม่มี `student_id`) กลายเป็นพฤติกรรมที่ตั้งใจ ไม่ใช่ความเสี่ยงอีกต่อไป

**ตัดสินใจเพิ่ม 2 ข้อ:**

1. **trigger ยังรับทุกอีเมล `@mju.ac.th` ไม่บังคับ `mju<10หลัก>`** — เลือกทางนี้เพราะบุคลากร/อาจารย์เป็นกลุ่มผู้ใช้ที่โปรเจกต์ตั้งใจรองรับตั้งแต่ต้น (มี `somchai.j@mju.ac.th` อยู่ใน DB จริงแล้ว) ถ้าบังคับรูปแบบเต็มคนกลุ่มนี้จะสมัครไม่ได้เลย
   **ราคาที่จ่าย:** `student_id` เป็น NULL ได้ตลอดไป → ห้ามมีโค้ดไหนสมมติว่า `student_id` ไม่เป็น NULL
2. **normalize อีเมลเป็นตัวเล็กก่อนเก็บลง `"Profile"`** — กันเคสสมัครซ้ำด้วยอีเมลเดียวกันคนละตัวพิมพ์ ซึ่ง `Profile_email_key` (unique ธรรมดา ไม่ใช่ index บน `lower()`) จับไม่ได้

### 🔴 ช่องโหว่ที่ปิดไปพร้อมกัน — regex ไม่ anchor

regex เดิมในtrigger คือ `new.email !~ '@mju\.ac\.th$'` ซึ่งเช็คแค่ว่า**ลงท้าย**ด้วย `@mju.ac.th`

`hacker@evil.com@mju.ac.th` **ผ่านด่านนี้ได้** เพราะลงท้ายถูกจริง ๆ แล้วได้ Profile ในระบบทันที
แก้เป็น `^[^@]+@mju\.ac\.th$` — `[^@]+` บังคับให้มี `@` ตัวเดียวทั้งสตริง

พร้อมกันนั้นเพิ่ม CHECK `profile_email_domain` ที่ระดับตาราง เพราะเดิม**ไม่มี constraint ใดกันโดเมนเลย** มีแต่ trigger → เขียนผ่าน `service_role` หรือแก้แถวทีหลังใส่อีเมลโดเมนอะไรก็ได้

**บทเรียน:** regex ที่ anchor ข้างเดียวคือ validation ที่ดูเหมือนทำงาน — เทสด้วยอินพุตปกติจะผ่านหมด ต้องเทสด้วยอินพุตที่จงใจแหกถึงจะเห็น (ผลทดสอบ 4 เคส: `VERIFICATION.md` **V-09**)

---

## D-11 — ทำไมเอกสารถึงเคยเขียนผิด และแก้ครั้งใหญ่อะไรไปบ้าง (2026-08-07)

> ย้ายเรื่องเล่าส่วนนี้ออกจาก `SCHEMA.md` เมื่อ 2026-08-08 เพราะเป็น **ประวัติ ไม่ใช่ schema**
> ผลตรวจดิบที่ใช้ยืนยันอยู่ที่ `VERIFICATION.md` (V-01 … V-06)

### สิ่งที่เอกสารเดิมเขียนผิด แล้วตรวจกับ DB จริงจึงพบ

| จุด | เอกสารเดิมเขียนว่า | ของจริง |
|---|---|---|
| Trigger / Function | "ยังไม่มีเลย" | มี function **4 ตัว** + trigger **1 ตัว** apply อยู่แล้ว |
| P-01 / P-02 ใน `PROPOSED_SQL.md` | "ยังเป็นข้อเสนอ ยังไม่ apply" | apply ไปแล้วทั้งคู่ — รวมอยู่ใน `handle_new_user()` ตัวเดียวกัน |
| policy `Admins can view/update all profiles` | ใช้ `EXISTS (SELECT 1 FROM "Profile" ...)` inline | เรียก `private.is_admin()` (SECURITY DEFINER) |
| `with_check` ของ `Users can update own profile` | ล็อกแค่ `role` | ล็อกทั้ง `role` **และ** `student_id` |
| `student_id` ตอนสมัคร | "FlutterFlow ต้อง Update Row ใส่เอง" (หมายเหตุใน P-01) | trigger derive ให้เองจากอีเมล — **เขียนทับจะชน CHECK** `profile_student_id_matches_email` |

**ทำไมต้องใช้ `private.is_admin()` แทน `EXISTS` inline:** policy บน `"Profile"` ที่ query `"Profile"` เองทำให้เกิด infinite recursion — SECURITY DEFINER ตัดวงจรนั้น

### 🔴 ต้นเหตุที่ทำให้ทั้งหมดนี้รอดสายตา — `checks/_common.sql` [C7] กรอง `nspname = 'public'`

[C7] ("function ที่มีอยู่จริง") เขียน `WHERE nspname = 'public'` ซึ่ง**ตัดของสองกลุ่มทิ้งไปเงียบ ๆ**:

1. **function ใน schema `private`** — `is_admin()` / `current_profile_role()` / `current_profile_student_id()` อยู่ใน `private` ทั้งหมด (จงใจ ไม่ให้ expose ผ่าน PostgREST) จึงไม่โผล่ในผลเช็คเลย
2. **trigger บน `auth.users`** — `on_auth_user_created` ผูกกับตารางใน schema `auth` ไม่ใช่ `public`

เช็คจึงคืน "0 function, 0 trigger" อย่างมั่นใจ แล้วเอกสารก็จดตามนั้นว่า "ยังไม่มีเลย"

**แก้แล้ว:** [C7] ขยายเป็น `nspname IN ('public','private')` และแยก [C7b] สำหรับ trigger ที่กวาด schema `auth` ด้วย

**บทเรียนที่ต้องจำ:** เช็คที่คืน "ไม่มีอะไร" อันตรายกว่าเช็คที่ล้มเหลว — มันดูเหมือนผ่าน
เขียน query ตรวจสอบเมื่อไหร่ ให้ถามก่อนเสมอว่า **"scope ที่กรองไว้ ตัดอะไรทิ้งไปบ้าง"** ไม่ใช่แค่ "ผลลัพธ์ถูกไหม"
(บทเรียนคู่ขนานกับ D-01 ที่รอดสายตาเพราะทดสอบด้วย admin อย่างเดียว — คนละสาเหตุ แต่อาการเดียวกันคือ "ผ่านทั้งที่ผิด")

---

## D-12 — bucket `product-images` เป็น public + จำกัด 3 รูปที่ตาราง ไม่ใช่ที่ Storage (2026-08-08)

### ก. เลือก bucket แบบ **public**

| ทางเลือก | ผล |
|---|---|
| **public** ✅ | FlutterFlow เอา URL ยัดใส่ Image widget ได้ตรง ๆ · เก็บ URL ถาวรลง `image_urls` ได้ · เปิดทาง browse ก่อนล็อกอินไว้ล่วงหน้า |
| private | ต้องสร้าง signed URL ทุกจุดที่แสดงรูป (Browse/MyPost/Inspect/ProductDetail) และ URL มีวันหมดอายุ → **เก็บลง `image_urls` ตรง ๆ ไม่ได้** ต้อง gen ใหม่ทุกครั้ง |

**หนี้ที่รับไว้:** รูปของประกาศที่ `moderation_status` เป็น `pending`/`rejected` ก็เปิดดูได้ถ้ารู้ URL
ยอมรับได้เพราะ path เป็น `<uuid ผู้ขาย>/<ชื่อไฟล์>` เดาไม่ได้ และรูปสินค้าไม่ใช่ข้อมูลอ่อนไหว — แต่ **อย่าเอา bucket นี้ไปเก็บอย่างอื่น** (เช่นบัตรนักศึกษา/สลิปโอนเงิน) เด็ดขาด

### ข. path บังคับเป็น `<auth.uid()>/<ชื่อไฟล์>`

policy ทั้ง upload/update/delete ตัดสินสิทธิ์จาก `(storage.foldername(name))[1]` เทียบกับ `auth.uid()`
เป็นวิธีเดียวที่ทำให้ "ลบได้เฉพาะไฟล์ตัวเอง" เป็นจริงที่ระดับ DB — ไม่ใช่แค่ซ่อนปุ่มใน UI
🔴 FlutterFlow ตั้ง upload path ผิดเมื่อไหร่ = อัปไม่ผ่านทันที ไม่ใช่ fail เงียบ

### ค. "สูงสุด 3 รูป" บังคับที่ `products.image_urls` ไม่ใช่ที่ Storage policy

```sql
CHECK (image_urls IS NULL OR array_length(image_urls, 1) <= 3)
```

**ทำไมไม่บังคับที่ Storage:** policy บน `storage.objects` ทำงาน**ทีละไฟล์** จะนับว่าโฟลเดอร์นี้มีกี่ไฟล์แล้วต้อง `SELECT count(*)` ในทุก policy check — ช้า และผูกกับ product id ที่**ยังไม่มี**ตอนอัป (flow ใน L2 อัปรูปก่อน insert แถว)

**ผลที่ต้องยอมรับ:** อัปไฟล์ที่ 4 เข้า bucket ได้ แต่ผูกกับประกาศไม่ได้ → กลายเป็น **ไฟล์กำพร้า**
→ FlutterFlow ต้องจำกัดปุ่ม upload ที่ 3 รูปด้วย ไม่ใช่ปล่อยให้ไปตายที่ DB (ผู้ใช้จะเสียเน็ตอัปฟรี ๆ แล้วโดนปฏิเสธตอนกดบันทึก)
→ ยังไม่มีระบบเก็บกวาดไฟล์กำพร้า — บันทึกเป็นหนี้ไว้ใน `STATUS.md`

---

## D-13 — repo เป็น private (2026-08-08)

**เดิม `2005tak2005-svg/MJU-market` เป็น public** เปลี่ยนเป็น **private** แล้ว

**เหตุผล:** repo นี้เก็บเอกสารล้วน และเอกสารของเราจงใจเขียน**ช่องโหว่ที่ยังไม่ได้ปิด**ไว้ครบถ้วน — `DECISIONS.md` **D-03** (RLS allow-all ตอน prototype) · **D-12** (รูปของประกาศ pending/rejected เปิดดูได้ถ้ารู้ URL) · `STATUS.md` หัวข้อหนี้ทางเทคนิค · `PROPOSED_SQL.md` ที่บอกว่าอะไรยัง**ไม่**ถูกบังคับ

รวมกับ project ref `rooydbxgcsybyanwsewv` ที่อยู่ในเอกสาร = แผนที่บอกว่าจะยิงตรงไหน

**ยังไม่ใช่ความลับที่หลุดไปแล้ว:** ตอนเปลี่ยนมี **0 fork / 0 star** และไม่เคย commit secret (`service_role` key / `FLUTTERFLOW_API_TOKEN` / `.env` ถูก `.gitignore` กันไว้ ตรวจแล้ว)
🔴 **แต่ private ไม่ย้อนเวลา** — ถ้ามีใคร clone หรือ search engine index ไว้ระหว่างที่ public ของนั้นเก็บกลับไม่ได้ **การป้องกันจริงคือปิดช่องโหว่ ไม่ใช่ซ่อนเอกสาร** — ข้อนี้ไม่ทดแทนการปิด D-03

**ผลที่ตามมา:** เครื่องอื่นที่ `git clone` ต้อง auth แล้ว (`gh auth login` หรือ SSH key) — ถ้า `git pull` ขึ้น 404 ให้ดูข้อนี้ก่อน อย่าคิดว่า repo ถูกลบ

---

## D-14 — `phone` ไปทาง user meta data ไม่ใช่ Update Row ตามหลัง (2026-08-08)

**เดิมสเปค L1 เขียนไว้ 2 จังหวะ:** Sign Up → แล้วต่อ Action **Update Row** ใส่ `phone`

**ปัญหา 2 ข้อของทางเดิม:**

1. **ต้องมี session ถึงจะ update ได้** — RLS ของ `"Profile"` ให้แก้ได้เฉพาะแถวของ `auth.uid()` ถ้าโปรเจกต์เปิด **Confirm email** ไว้ สมัครเสร็จจะ**ยังไม่มี session** → Update Row ล้มทันที และผู้ใช้เสียเบอร์ไปเงียบ ๆ
2. **ไม่ atomic** — แอปดับ/เน็ตหลุดคั่นกลาง ได้ Profile ที่ไม่มีเบอร์ โดยไม่มีอะไรบอกว่าพลาด

**ตัดสินใจ:** ให้ `handle_new_user()` อ่าน `raw_user_meta_data->>'phone'` เองพร้อม `full_name`
เขียนครั้งเดียวใน transaction เดียวกับที่สร้างแถว — ทำงานได้แม้ยังไม่มี session

```sql
nullif(trim(new.raw_user_meta_data->>'phone'), '')
```

**`nullif(trim(...), '')` ทั้ง `full_name` และ `phone` จงใจ** — FlutterFlow ส่ง TextField ว่างมาเป็น `''` ไม่ใช่ `null` ถ้าไม่ดักไว้จะได้แถวที่ `phone = ''` ซึ่ง `IS NOT NULL` เป็นจริง แล้วทุกที่ที่เช็ค "กรอกเบอร์หรือยัง" จะตอบผิดหมด

**สิ่งที่ยังต้องทำที่ FlutterFlow:** key ต้องชื่อ `phone` เป๊ะ ๆ ใน user meta data (กฎข้อ 3) — สะกดผิดแล้วจะเงียบ ไม่ error แค่ได้ NULL
**ข้อจำกัดที่ยังอยู่:** เปลี่ยนเบอร์ทีหลังยังต้องผ่านหน้า Edit Profile ตามปกติ D-14 แก้แค่จังหวะสมัคร

---

## D-15 — bucket `avatars` แยกจาก `product-images` (2026-08-08)

**ทางเลือกที่ปฏิเสธ:** เอา avatar ยัดลง `product-images` แล้วแยกด้วยชื่อโฟลเดอร์

**เหตุผลที่แยก:**

- **ขนาดไฟล์ต่างกันคนละเรื่อง** — รูปสินค้า 5 MB สมเหตุผล แต่รูปโปรไฟล์ไม่ควรเกิน 2 MB `file_size_limit` ตั้งได้ทีละ bucket เท่านั้น ตั้งรวมกัน = ต้องใช้ค่าที่หลวมที่สุด
- **อายุข้อมูลต่างกัน** — รูปสินค้าลบพร้อมประกาศ รูปโปรไฟล์อยู่ตลอดอายุบัญชี ระบบเก็บกวาดไฟล์กำพร้า (หนี้ใน `STATUS.md`) จะเขียนคนละกติกา ปนกันแล้วเสี่ยงลบผิดตัว

**public เหมือนกัน** ด้วยเหตุผลเดียวกับ D-12 — `public_profiles.avatar_url` ถูกอ่านทุกหน้าจอ ถ้าเป็น private ต้องทำ signed URL ทุกจุดและ URL หมดอายุจึงเก็บลงคอลัมน์ไม่ได้
**path `<auth.uid()>/<ไฟล์>` เหมือนกัน** — เป็นทางเดียวที่ "ลบได้เฉพาะรูปตัวเอง" เป็นจริงที่ระดับ DB

🔴 **หนี้ที่รับไว้:** `avatar_url` เป็นแค่ text ไม่ผูกกับไฟล์จริง — เปลี่ยนรูปแล้วไฟล์เก่าค้าง และลบไฟล์แล้วคอลัมน์ยังชี้ URL เดิม (รูปแตก) ต้องจัดการพร้อมกับไฟล์กำพร้าของ `product-images`

---

## D-16 — รีเซ็ตโปรเจกต์ FlutterFlow: `MJU-market-v1-archive` → `MJU-Market-v2` (2026-08-09)

**บริบท:** โปรเจกต์ FlutterFlow เดิม (`m-j-umarket-l6wnty`) สะสมปัญหาการตั้งชื่อมานาน — มีเว้นวรรคในชื่อ (`"chat messages"`), หน้า auth ที่ดูซ้ำซ้อนกันเอง (`login` / `signIn` / `sucess`), component ชื่อตัวอักษรเดียว (`d`, `t`), และ Claude ตรวจสอบชื่อจริงฝั่ง FlutterFlow ไม่ได้มานานเพราะไม่มี CLI/token (บล็อกเก่าใน `STATUS.md` ข้อ 2 — **ปิดแล้ว**, ตอนนี้มี `flutterflow ai` CLI/MCP ใช้งานได้แล้ว)

**ตัดสินใจ:** สร้างโปรเจกต์ใหม่ทั้งหมด (`m-j-u-market-v2-0xhjhg`, ชื่อ "MJU-Market-v2") แทนที่จะไล่เก็บกวาดของเดิม แล้ว**เปลี่ยนชื่อโปรเจกต์เก่าเป็น "MJU-market-v1-archive"** (เก็บไว้ ไม่ลบ — เผื่อย้อนดู)

**กติกาการตั้งชื่อใหม่ (บังคับใช้กับ v2 ทั้งโปรเจกต์):** ชื่อหน้า/component = PascalCase, ชื่อ state = camelCase, **ห้ามมีเว้นวรรคในชื่อใด ๆ**

**ผลที่ตามมาที่ต้องรู้ก่อนทำ layer ถัดไป:** v2 ตอนนี้มีแค่หน้าของ L1 (`SignUp`, `Login`, `Home`, `HomeAdmin`) **งานฝั่ง FlutterFlow ของ v1 ในเลเยอร์ L2 ขึ้นไปทั้งหมดไม่ได้ย้ายมาด้วย** (`AddProduct`, `MyPost`, `Inspect`, หน้าแชท, component ต่าง ๆ) — ต้องสร้างใหม่ใน v2 ทั้งหมดตอนเริ่ม L2 ฝั่ง Supabase **ไม่เปลี่ยน** — ยัง connect โปรเจกต์เดิม (`rooydbxgcsybyanwsewv`) เหมือนกันทั้ง v1/v2

---

## D-17 — Confirm Email เปิดอยู่จริง — ตัดสินใจแล้ว: สร้าง flow ยืนยันอีเมลจริง (2026-08-09)

**สถานะเดิม:** `STATUS.md`/`layers/L1-auth-profile.md` เคยบันทึกไว้ว่า "ตรวจจาก DB ไม่ได้ ต้องเปิด Dashboard ดู" — ยังไม่มีใครเปิดดูจริง

**ยืนยันแล้วของจริง (ไม่ใช่การเดา):** สมัครผ่านแอปจริงสำเร็จ (สร้างแถว `"Profile"` ครบ) แล้วพยายาม login ทันที → Supabase Auth ตอบ error **"Email not confirmed"** ตรง ๆ — เป็น GoTrue เองที่ปฏิเสธ ไม่ใช่โค้ดฝั่งเรา

**ผลกระทบ: L1 ฝั่ง FlutterFlow ปิดไม่ได้จนกว่าจะมีทั้ง 2 อย่างนี้** (ไม่ใช่แค่หมายเหตุ — เป็นงานที่ยังไม่ได้ทำ ดู `STATUS.md` คิวถัดไป):

1. **หน้า/ข้อความหลังสมัครที่บอกผู้ใช้ให้ไปยืนยันอีเมลก่อน** — ตอนนี้ปุ่ม "สมัครสมาชิก" ขึ้น snackbar "สำเร็จ" แล้ว Navigate ไป Login ทันที ทำให้ผู้ใช้งงว่าทำไม login ไม่ได้
2. **จัดการเคส login แล้วเจอ "email not confirmed"** — ตอนนี้ปุ่ม Login ไม่ดักเคสนี้เลย ผู้ใช้จะเห็น error ดิบจาก Supabase ตรง ๆ

**ตัดสินใจแล้ว (pete, 2026-08-09): ทางเลือก (ก) สร้าง flow ยืนยันอีเมลจริง** — ไม่ปิด Confirm Email เพราะการยืนยันตัวตนผ่านอีเมล `@mju.ac.th` คือจุดประสงค์หลักของโปรเจกต์ ทางเลือก (ข) (ปิด Confirm Email ใน Dashboard) ตกไป

| ทางเลือก | ข้อดี | ข้อเสีย |
|---|---|---|
| **(ก) สร้าง flow ยืนยันอีเมลจริง ← เลือกทางนี้** | ยังพิสูจน์ตัวตนผ่านอีเมล `@mju.ac.th` จริง ตรงตามจุดประสงค์เดิมของโปรเจกต์ | ต้องทำหน้าแจ้งเตือน + ดัก error เฉพาะ + อาจต้องมีปุ่ม resend — งานเพิ่มอีกก้อน |
| ~~(ข) ปิด Confirm Email ใน Supabase Dashboard~~ (ตกไป) | สมัครเสร็จมี session ทันที ไม่ต้องมีหน้ายืนยันเลย ปิด L1 ได้เร็วที่สุด | **ใครก็สมัครด้วยอีเมล `@mju.ac.th` ของคนอื่นได้** — การยืนยันตัวตนผ่านอีเมลมหาลัยจะไม่เหลือความหมาย |

**ก่อนลงมือสร้าง flow:** ต้องตรวจ Site URL / Redirect URL ใน Supabase Dashboard (Authentication → URL Configuration) ของจริงก่อนว่าลิงก์ยืนยันในอีเมลกดแล้วพาไปที่ไหน (deep link เข้าแอปได้จริงไหม หรือไปหน้าเว็บกลาง) แล้วเสนอทางเลือกการออกแบบ flow ให้ pete เลือก — ยังไม่ลงมือสร้างอะไรจนกว่าจะตอบข้อนี้

**Testing workaround ที่ใช้อยู่ตอนนี้ (ไม่ใช่ทางแก้ถาวร):** SQL patch `auth.users.email_confirmed_at` ตรงบัญชีทดสอบเป็นรายตัว — ดูรายชื่อบัญชีที่โดน patch ใน `STATUS.md` หัวข้อหนี้ทางเทคนิค **ห้ามเข้าใจผิดว่านี่คือทางแก้จริง** — บัญชี `mju6577778888@mju.ac.th` ต้องล้างทิ้งแล้วเทสใหม่ผ่าน flow จริงตอนทำ D-17 เสร็จ

---

## D-18 — รูปแบบ flow ยืนยันอีเมล: OTP 6 หลัก แทนลิงก์ (2026-08-09)

> 🔴 **ถูกยกเลิกแล้ว 2026-08-09 เย็น → ดู D-19** — เจอว่าแก้ email template ต้องตั้ง custom SMTP ก่อนเสมอ (banner ใน Dashboard: "Set up custom SMTP to edit templates") ไม่ใช่ข้อจำกัดเฉพาะ Free plan แต่เป็นกติกาของ Supabase ทุก plan pete ไม่ต้องการตั้ง SMTP เพิ่ม จึงเปลี่ยนไปทางเลือก (2) แทน

**บริบท:** ต่อจาก D-17 — ก่อนออกแบบ flow ต้องตรวจ Site URL / Redirect URL ของจริงก่อนตามที่ D-17 กำหนดไว้

**ตรวจแล้ว (execute_sql + get_project ทาง MCP หา `auth.config` ไม่เจอ — ค่านี้ไม่ได้อยู่ใน Postgres schema เลย เป็น platform config ต้องดูจาก Dashboard เท่านั้น):**
pete เปิด Dashboard → Authentication → URL Configuration แล้วรายงานว่า
- **Site URL = `http://localhost:3000`** (ยังเป็นค่า default ไม่เคยตั้ง)
- **Redirect URLs allow list = ว่าง**

**ผลคือ:** ลิงก์ยืนยันตอนนี้กดแล้วพา user ไปที่ `localhost:3000` — หน้าเว็บตายบนมือถือ ไม่มีทางกลับเข้าแอป (ยืนยันปัญหาที่ D-17 สงสัยไว้ว่าอาจเป็นแบบนี้)

**ทางเลือกที่เสนอ:**

| ทางเลือก | ข้อดี | ข้อเสีย |
|---|---|---|
| (1) Deep link เข้าแอปจริง (ตั้ง custom URL scheme) | UX ดีที่สุด กดลิงก์แล้วเด้งกลับแอปทันที | ต้อง config ทั้ง Supabase + FlutterFlow และยังไม่เคยเช็คว่า FlutterFlow SDK รองรับ custom scheme deep link จริงไหม |
| (2) หน้าเว็บกลางง่าย ๆ ("ยืนยันแล้ว กลับไปเปิดแอป") | ทำเร็ว ไม่ต้องพิสูจน์ deep link | ต้องหาที่ host หน้าเว็บ, UX ขาดตอน 1 จังหวะ |
| **(3) เปลี่ยนเป็น OTP 6 หลักแทนลิงก์ ← เลือกทางนี้** | ไม่พึ่ง Site URL/Redirect URL เลย หลีกเลี่ยงปัญหานี้ทั้งหมด ไม่ต้องพิสูจน์ deep link | ต้องเปลี่ยน email template (`{{ .Token }}` แทน `{{ .ConfirmationURL }}`) + สร้างหน้า OTP input ใหม่ใน FlutterFlow |

**ตัดสินใจแล้ว (pete, 2026-08-09): ทางเลือก (3) OTP 6 หลัก**

**งานที่ต้องทำต่อ (ยังไม่ได้เริ่ม):**
- Supabase: แก้ email template "Confirm signup" ให้ใช้ `{{ .Token }}` แทนลิงก์
- FlutterFlow: สร้างหน้ารับ OTP หลังสมัคร (input 6 หลัก + ปุ่ม resend) เรียก `verifyOtp` (type: signup)
- Login: ยังต้องดักเคส "email not confirmed" เหมือนเดิมตามข้อ 2 ใน D-17 — เผื่อ user ปิดแอปก่อนกรอก OTP แล้วกลับมา login ทีหลัง
- บัญชีทดสอบ `mju6577778888@mju.ac.th` ที่ patch `email_confirmed_at` ด้วย SQL ต้องล้างแล้วเทสใหม่ผ่าน OTP flow จริงตามที่ D-17 ระบุไว้

---

## D-19 — เปลี่ยนจาก OTP กลับมาเป็นหน้าเว็บกลาง (D-18 ถูกยกเลิก) (2026-08-09)

**บริบท:** ลงมือทำ D-18 (OTP) จริง แล้วเจอ banner ในหน้า Authentication → Emails → Templates ของ Dashboard:
> "Set up custom SMTP to edit templates — Emails will be sent using the default templates. Set up custom SMTP to edit their subject and body."

แปลว่าการแก้ "Confirm signup" template ให้ใช้ `{{ .Token }}` **ต้องตั้ง custom SMTP ก่อนเสมอ** — เป็นกติกาของ Supabase ทุก plan ไม่ใช่ข้อจำกัดเฉพาะ Free plan (pete เคยเข้าใจว่าเป็นเพราะ Free plan — ไม่ถูกต้องเป๊ะ แต่ผลลัพธ์เหมือนกันคือทำไม่ได้โดยไม่ตั้ง SMTP เพิ่ม)

**ตัดสินใจแล้ว (pete, 2026-08-09): กลับไปใช้ทางเลือก (2) จาก D-18 — หน้าเว็บกลางง่าย ๆ** แทน OTP เพราะ pete ไม่ต้องการตั้ง custom SMTP เพิ่ม ("ไม่เน้นแฟนซี") ทางนี้ใช้ default email template เดิม (มี `{{ .ConfirmationURL }}`) ได้เลย ไม่ต้องแตะ template

**สิ่งที่ทำไปแล้วฝั่ง Supabase:**
- สร้าง bucket `static-pages` (public read, ไม่มี public insert — อัปโหลดได้เฉพาะทาง Dashboard) — ดู `SCHEMA.md`
- ⚠️ **พบกับดัก:** อัปโหลด `email-confirmed.html` ครั้งแรก → `pg_policies`/`storage.objects.metadata` บอกว่า `mimetype: text/html` ถูกต้อง แต่ตัว public URL จริง **เสิร์ฟเป็น `content-type: text/plain` เสมอ** (เช็คซ้ำ 3 ครั้งด้วย curl ยืนยันไม่ใช่ cache fluke) — Supabase Storage บังคับ downgrade `.html` เป็น text/plain โดยเจตนา (anti-XSS/phishing ป้องกันไม่ให้ใช้ subdomain `*.supabase.co` โฮสต์ HTML ที่ execute ได้) แก้ไม่ได้ด้วยการแก้ metadata → **เปลี่ยนไฟล์เป็น `email-confirmed.txt` (plain text ล้วน ไม่มี HTML tag)** แทน เพราะยังไงก็โดนเสิร์ฟเป็น text/plain อยู่ดี ให้เนื้อในเป็น text อ่านง่ายไปเลย — บันทึกกับดักนี้ไว้ใน `CLAUDE.md` แล้วกันเจอซ้ำ
- อัปโหลด `email-confirmed.txt` สำเร็จ verify แล้วด้วย curl: `content-type: text/plain`, body เป็นข้อความไทยล้วนไม่มี tag หลงเหลือ
- **pete ตั้ง Site URL ใน Authentication → URL Configuration สำเร็จแล้ว 2026-08-09** ชี้ไปที่ `https://rooydbxgcsybyanwsewv.supabase.co/storage/v1/object/public/static-pages/email-confirmed.txt`

**งานที่ต้องทำต่อ:**
- ยังไม่เคยทดสอบ end-to-end จริง (สมัครบัญชีใหม่ → เช็คว่าอีเมลที่ได้มีลิงก์ที่กดแล้วพาไปหน้านี้จริง) — แค่ตั้งค่าไว้ ยังไม่ได้พิสูจน์
- FlutterFlow: หน้า/ข้อความหลังสมัครที่บอกผู้ใช้ให้ไปยืนยันอีเมล (ข้อ 1 ใน D-17) + ดักเคส "email not confirmed" ที่ Login (ข้อ 2 ใน D-17)
- บัญชีทดสอบ `mju6577778888@mju.ac.th` ต้องล้างแล้วเทสใหม่ผ่าน flow จริงตามที่ D-17 ระบุไว้

---

## D-20 — OTP กลับมาอีกครั้ง (ยกเลิก D-19) เพราะ Microsoft Safe Links prefetch ลิงก์ยืนยัน แล้วหยุดงาน L1 ไว้ตรงนี้เพราะ deliverability ฝั่ง tenant (2026-08-09 → 2026-08-10)

**บริบท:** ทำตาม D-19 (หน้าเว็บกลาง + ลิงก์ยืนยัน) เสร็จแล้ว ตั้ง Site URL ชี้ไปที่ `email-confirmed.txt` ใน bucket `static-pages` ทดสอบสมัครจริงหลายรอบ

**พบว่า:** `auth.users.email_confirmed_at` ไม่เคยขยับเป็นค่าจริงเลย แม้จะ "กดยืนยัน" แล้วก็ตาม — `get_logs` (auth) โชว์ `GET /verify` คืน `400: Invalid email verification type` และเกิดขึ้นเร็วผิดปกติ **~17 วินาทีหลังสมัครทุกครั้ง** (เร็ว/สม่ำเสมอเกินกว่ามนุษย์จะเปิดอีเมลจริง) ตรวจ `whois` ของ IP ที่ยิง `/verify` พบ `mnt-by: MICROSOFT-MAINT` — สรุปได้ว่า **Microsoft 365 Education Safe Links / Defender for Office 365 ของ tenant มหาลัยดึงลิงก์ในอีเมลไปสแกนเองอัตโนมัติก่อนผู้ใช้จะกด** ทำให้ one-time token ถูกใช้ไปแล้วตั้งแต่ก่อนคนจะเห็นอีเมลด้วยซ้ำ

**ผลคือ: การยืนยันอีเมลแบบ "ลิงก์" ใช้กับโดเมนนี้ไม่ได้เลยในทางเทคนิค** ไม่ว่าจะ host หน้าเว็บกลางไว้ที่ไหนก็ตาม — ปัญหาไม่ได้อยู่ที่ D-19 เลือกผิด แต่อยู่ที่ "ลิงก์" เป็นกลไกที่ผิดตั้งแต่ต้นสำหรับผู้ใช้ที่อยู่หลัง Safe Links

**ตัดสินใจ (pete, 2026-08-09 ตอนเย็น): กลับไปทางเลือก (3) OTP จาก D-18** เพราะ OTP ไม่มีลิงก์ให้ Safe Links prefetch เลย — คราวนี้ยอมตั้ง custom SMTP แล้ว (เดิม D-19 หลีกเลี่ยงไว้เพราะ "ไม่เน้นแฟนซี" แต่สุดท้ายต้องตั้งอยู่ดีเพราะโดนบล็อกด้วย rate limit 2 อีเมล/ชั่วโมงของ default mailer ระหว่างเทสสมัครรัว ๆ) ใช้ Gmail ส่วนตัว + App Password เป็น custom SMTP provider

**สิ่งที่สร้างเสร็จแล้วฝั่ง FlutterFlow (2026-08-09, ยืนยันจาก generated code จริงแล้ว ไม่ใช่แค่ compile ผ่าน):**
- custom action `VerifyOtp` — เรียก `auth.verifyOTP(type: OtpType.signup)` sync `AppStateNotifier` เองตาม PT-11
- custom action `ResendSignupOtp` — เรียก `auth.resend(type: OtpType.signup)`
- หน้าใหม่ `ConfirmEmail` (route `/confirm-email`) — ช่องกรอกรหัส 6 หลัก + ปุ่ม "ยืนยัน" + ปุ่ม "ส่งรหัสใหม่อีกครั้ง"
- `SignUpButton` เปลี่ยนปลายทางจาก Navigate `Login` → Navigate `ConfirmEmail`
- App State ใหม่ `otpCode`
- แก้ email template "Confirm signup" ให้โชว์ `{{ .Token }}` เป็นตัวเลขข้อความล้วน (ไม่ใช่ลิงก์) — ระหว่างแก้เจอ syntax bug (`href={{ .Token }}"` ขาด quote เปิด) ทำให้ Supabase render template ไม่ผ่านเลยตอนสมัคร (`html/template: "\"" in unquoted attr`, error `unexpected_failure` ที่หน้าแอป) แก้แล้วโดยตัด `<a href>` ออกทั้งหมด เหลือแค่ตัวเลข OTP ในกรอบใหญ่ ๆ

**บล็อกใหม่ที่เจอระหว่างทดสอบ — เป็นเรื่อง deliverability ของอีเมล ไม่ใช่บั๊กโค้ดของเรา:**
สมัครสำเร็จ → auth log ยืนยัน `POST /signup` status 200 ไม่มี error → เช็ค Gmail โฟลเดอร์ "ส่งแล้ว" (Sent) เจอเมลจริงที่ส่งออกไปหา `mju6606105382@mju.ac.th` พร้อมรหัส OTP จริง (เช่น `80240827`) — **แต่อีเมลไม่เคยไปถึงกล่องผู้รับเลย**: ไม่อยู่ Inbox, ไม่อยู่ Junk, ไม่มี bounce-back กลับมาที่ Gmail (ต่างจากอีกบัญชีทดสอบ `mju6500000101@mju.ac.th` ที่ bounce ชัดเจนด้วย `550 5.4.1 Recipient address rejected: Access denied`), และไม่อยู่ใน Microsoft 365 Defender quarantine portal ด้วย

**ข้อสรุปที่เป็นไปได้มากที่สุด:** พฤติกรรมนี้ตรงกับ **Zero-hour Auto Purge (ZAP)** ของ Microsoft Defender — เมลถูกตอบรับ (accept) ไว้ช่วงหนึ่ง แต่ถูกดึงกลับไปลบทีหลังแบบเงียบ ๆ ตาม threat-intelligence ที่ประเมินใหม่ได้ ไม่แจ้งทั้งผู้ส่งและผู้รับ พบได้บ่อยกับ**ผู้ส่งหน้าใหม่ที่ไม่มี sending reputation กับ tenant นั้นมาก่อน** ซึ่งตรงกับ custom SMTP ที่เพิ่งตั้ง (Gmail ส่วนตัว) ที่ไม่เคยส่งเข้า tenant นี้มาก่อนเลย

**ยังไม่ได้ลอง (การทดลองถัดไปถ้ากลับมาทำต่อ):** ปิด custom SMTP ชั่วคราวแล้วทดสอบ 1 รอบด้วย mailer เริ่มต้นของ Supabase เอง เพื่อแยกว่าเป็นปัญหาที่ตัว Gmail relay เจาะจง หรือเป็นนโยบายที่ tenant บล็อกอีเมลลักษณะนี้ทั้งหมดไม่ว่าใครส่ง — Site URL/Redirect URL ไม่เกี่ยวแล้วเพราะ OTP ไม่มีลิงก์

**ตัดสินใจ (pete, 2026-08-10): หยุดงาน L1 confirm-email ไว้ตรงนี้ ย้ายไปทำ layer อื่นก่อน** เหตุผล: ปัญหาที่เจอเป็นเรื่อง deliverability ฝั่ง Microsoft tenant ซึ่งอยู่นอกเหนือสิ่งที่แก้ได้จาก config ของ Supabase/FlutterFlow ล้วน ๆ — ทางแก้จริงน่าจะต้องใช้เวลาสร้าง sending reputation, ให้ทีม IT ของมหาลัยช่วย whitelist, หรือเปลี่ยนไปใช้ transactional email provider ที่มีชื่อเสียงกับ Microsoft อยู่แล้ว (เช่น SendGrid/Postmark/Resend) แทน Gmail ส่วนตัว — ไม่ใช่สิ่งที่ลองผิดลองถูกต่อในเซสชันนี้ได้อีก

**ผลกระทบต่อ L1:** ฝั่ง FlutterFlow ของ Confirm Email flow **สร้างโค้ดเสร็จแล้วทั้งหมด** (หน้า `ConfirmEmail`, custom action `VerifyOtp`/`ResendSignupOtp`, ปุ่มต่าง ๆ ผูกถูกตามที่ตรวจจาก generated code จริง) **แต่ยังไม่เคยทดสอบ end-to-end สำเร็จแม้แต่ครั้งเดียว** เพราะไม่เคยมี OTP code ไปถึงผู้ทดสอบเลยสักครั้ง — L1 ฝั่ง FlutterFlow ยังคง 🟨 ค้างอยู่ที่ขั้นตอนนี้จนกว่าจะแก้ deliverability ได้

**เก็บกวาดที่ทำไปพร้อมกัน:** ลบบัญชีทดสอบเก่า 4 บัญชีที่ค้างจากรอบทดสอบ D-19/D-20 (`mju6500000099@mju.ac.th`, `mju6500000101@mju.ac.th`, `mju6606105382@mju.ac.th`, `mju6606105383@mju.ac.th`) — ลบ `"Profile"` ก่อนแล้วค่อยลบ `auth.users` (ต้องเรียงลำดับนี้เสมอเพราะ `Profile_id_fkey` ไม่มี `ON DELETE CASCADE`) เหลือบัญชี admin (`mju6577778888@mju.ac.th`) และบัญชีทดสอบ RLS เดิม 4 บัญชีไว้ตามเดิม ไม่แตะ

**คำแนะนำสำหรับ session ถัดไปที่ทำ layer อื่น:** ใช้ `mju6577778888@mju.ac.th` (admin, `email_confirmed_at` ถูก patch ด้วย SQL ไว้แล้วจาก D-17) ทดสอบ layer อื่นที่ต้อง login ได้ เพราะเป็นบัญชีเดียวตอนนี้ที่เข้า Home/HomeAdmin ได้จริงโดยไม่ติดปัญหา confirm-email — **ห้ามใช้บัญชีนี้เทสเรื่อง confirm-email เองอีก** (สภาพถูกลัดผ่านไปแล้ว ดู `STATUS.md` หนี้ทางเทคนิค)

---

## D-21 — สลับ Authentication backend: Firebase → Supabase (2026-08-14)

**อาการที่พาไปเจอ:** หน้า `ProfileUser` crash `Unexpected null value` แบบสุ่ม (เปิดครั้งแรกหลัง login ได้ แต่ reload/กลับเข้าหน้าใหม่แล้วพัง)

**ต้นเหตุ:** query ที่ filter ด้วย user ปัจจุบัน compile เป็น `currentUserUid` → อ่านจาก `currentUser` ของ FlutterFlow ซึ่งผูกกับ **Firebase** แต่**ไม่มีใคร login เข้า Firebase เลย** (การ login จริงวิ่งผ่าน Supabase ทั้งหมด) → `currentUserUid = ''` → หา `"Profile"` ไม่เจอ → force-unwrap พัง
**กระทบทั้งแอป** ไม่ใช่แค่หน้าเดียว — `storageFolderPath: currentUserUid` ของ `addproduct`/avatar ก็จะเขียนลงโฟลเดอร์ `''` ซึ่งผิด storage policy

**ตัดสินใจ:** เปลี่ยน backend เป็น Supabase (pete เลือก 2026-08-14) แทนการ (ก) แปะ null-guard กลบอาการ หรือ (ข) sync session เข้า `currentUser` เองด้วย custom code
เหตุผล: แก้ที่ต้นเหตุครั้งเดียว `currentUserUid` = Supabase uid ตรงกับ `"Profile".id` จริง — ทางเลือกอื่นเป็นการซ่อมอาการและยังทิ้ง upload path พังไว้

**ผลที่ตามมา:**
- โปรเจกต์ Firebase ที่ต่อไว้ก่อนหน้า (เพื่อปิด error "Firebase config files not uploaded") **ไม่จำเป็นอีกแล้ว** — เป็นการแก้ที่ปลายเหตุ
- reference ของ user ปัจจุบัน**ทั้งโปรเจกต์**ต้อง rewrite `FIREBASE_AUTH_USER` → `SUPABASE_AUTH_USER` พร้อมกันใน push เดียว ไม่งั้น validate ไม่ผ่าน (วิธี + กับดัก: `PATTERNS.md` **PT-13**)
- **`DISPLAY_NAME`/`PHOTO_URL` ไม่มีใน Supabase auth** → คำทักทายหน้า `Home` ถูก remap เป็น **อีเมล** — ✅ **pete ทดสอบแล้วรับได้ ถือเป็นพฤติกรรมที่ตั้งใจ ไม่ใช่งานค้าง** (ถ้าวันหลังอยากได้ `full_name` ผูก page-level query แบบ **PT-14**)
- ⚠️ **ยัง regression test ไม่ครบ** — ทดสอบจริงแค่ `ProfileUser` ส่วนสมัคร/OTP/role-routing/upload ยังไม่ได้ไล่ (อยู่ในคิว `STATUS.md` ข้อ 0)

---

## D-22 — `HomeAdmin`: reuse template shell แทน redesign, ตัดชาร์ต/activity ปลอมทิ้งแทนที่จะผูกข้อมูลหลอก (2026-08-14)

**บริบท:** `HomeAdmin` เดิมเป็น generic "check.io" project-management dashboard template ที่ import เข้ามาทั้งยวง — ทุกปุ่มแค่ `print('Button pressed ...')` ไม่มี binding อะไรเลย มีทั้ง fake ชื่อทีม (Randy Peterson, Rudy Fernandez, Abigail Rojas ฯลฯ), fake ตัวเลข task-completion/trend %, และปุ่ม "Assign"/"Create Task"/"Add New" ที่ไม่มี concept ที่ตรงกันในระบบซื้อขายนี้เลย

**ตัดสินใจ (pete สั่งชัดเจน):** ใช้โครง widget เดิมต่อ ไม่ redesign ใหม่ทั้งหน้า — เปลี่ยนแค่ข้อความ + ผูก query จริงเข้าส่วนที่มี concept ตรงกัน:
- side-nav identity card + stat card ตัวเลข → ผูกจริงผ่าน `admin_dashboard_stats` (view ใหม่, ดู `SCHEMA.md`)
- "Upcoming Milestones" table → กลายเป็นคิวสินค้ารอตรวจ (`products_review_view` filter `moderation_status='pending'`) — **นับเป็นการเริ่มใช้คืนหนี้ L8 ข้อ "รวมหน้า Inspect เข้ามาเป็นส่วนหนึ่งของ dashboard"** เพราะ v2 ยังไม่มีหน้า Inspect แยก
- ปุ่ม "Assign"/"Create Task"/"Add New" + avatar ทีมปลอม (`userRow`) → **ลบทิ้ง** (`page.ensureRemoved`) ไม่ใช่แค่ซ่อน — ปุ่มที่กดแล้วไม่ทำอะไรเลยในแผงแอดมินจริงแย่กว่าไม่มีปุ่ม
- ชาร์ต "Dashboard_recentActivity" + panel "Activity" (feed เพื่อนร่วมทีมปลอม) → **ลบทิ้งทั้งคู่** แทนที่จะผูกข้อมูลหลอกหรือทิ้งไว้เฉย ๆ เพราะไม่มี concept ที่ตรงกันในระบบนี้เลย (ไม่มี "task completion" ไม่มีทีม) และไม่มีตาราง audit/activity-log จริงให้ผูก

**เหตุผล:** งานนี้ scope คือ "ผูก query + เปลี่ยนข้อความ ไม่ต้อง redesign" — แต่ element ที่ **ไม่มี concept ตรงกันเลย** (ชาร์ต/activity feed) ไม่เข้าเงื่อนไข "fit this layer's spec" จึงตัดสินใจว่าดีกว่าที่จะเอาออกแทนที่จะฝืนผูกด้วยข้อมูลปลอมหรือทิ้งไว้ให้เข้าใจผิดว่าเป็นของจริง

**ผลที่ตามมา:**
- นับเป็นจุดเริ่มของ L8 (ก่อนหน้านี้ ⬜ ทั้ง Supabase/FlutterFlow) — ยังไม่ปิด layer เพราะ RLS admin-only "กันยิง API ตรง" ยังไม่ทำ (`products`/`chat` ยัง allow-all ตามหนี้เดิม), `"CAT"` CRUD ยังไม่มี, approve/reject action บนคิวสินค้ารอตรวจยังไม่ได้ wire (ตอนนี้กดแถวแค่ Navigate ไป `ProductDetails` เพื่อดูรายละเอียด ยังไม่มีปุ่มอนุมัติ/ปฏิเสธในหน้านี้)
- feed "รายงานล่าสุด" (bind `reports` เข้า Activity panel) เป็น follow-up ที่ตั้งใจปล่อยไว้ ไม่ใช่ลืม — รอ L7 ตัดสินใจ `reports.status` vocabulary ก่อน (P-10)
- กับดัก SDK 2 เรื่องที่เจอระหว่างทำ (selector พังหลัง `ensureRemoved`, ผูก view ใหม่ต้อง `postgres_helpers.addTable`) บันทึกไว้ที่ `PATTERNS.md` **PT-15**

**🆕 ตามด้วยรอบ pete ยืนยันของค้าง 3 ข้อ (เซสชันเดียวกัน 2026-08-14):**
1. **"จำนวนสินค้ารอตรวจ" แทน "pending orders"** — pete ยืนยันแล้วว่าใช้ตัวเลขนี้ต่อไปได้ (ไม่ต้องเริ่ม L5 ตอนนี้เพื่อสร้างตาราง orders/transactions จริง) การ์ดใบที่ 2 ของ `HomeAdmin` จึงตั้งใจนับจาก `products.moderation_status='pending'` ไม่ใช่ของค้างที่ต้องแก้
2. **"ยอดขายตามผู้ขาย" เป็น ranked list ธรรมดา ไม่ใช่กราฟจริง** — pete ยืนยันแล้วว่าใช้ต่อไปก่อนได้เช่นกัน (สร้างกราฟจริงต้องไปทาง custom widget + pub package อย่าง `fl_chart` ซึ่งเป็นงานคนละขนาด ยังไม่ทำตอนนี้)
3. **การทดสอบ end-to-end ผ่านแอปจริง** — สภาพแวดล้อมที่ Claude รันไม่มี `flutter` บน PATH (`local_run.list_devices` คืนค่าว่าง) และ Test Pilot ถูก auto-mode classifier บล็อกไม่ให้สร้าง test ใหม่ pete เลือกจะเทสเองผ่านแอปจริงแทนการเปิด permission — ใช้บัญชี admin `mju6577778888@mju.ac.th` (รหัสผ่านคุยกันในแชท ถูกตั้งใหม่ผ่าน SQL วันนี้เพราะของเดิมไม่รู้ค่า ดู `STATUS.md`)

---

## D-23 — `HomeAdmin` approve/reject จริง + `notifications` table (แก้บล็อก P-07) + trigger คุ้มกัน moderation field (2026-08-14)

**ตัดสินใจ:**
- `notifications.ref_product_id uuid` (nullable) แทน `ref_id` กลาง — แก้บล็อกเดิมของ P-07 ที่ผูก `chat.id` (bigint) ไม่ได้ เผื่อ `ref_chat_id bigint` เพิ่มทีหลัง
- แจ้งเตือนเป็น **in-app list** เท่านั้น (ตาราง + หน้า `Notifications` + bell icon) ไม่ต่อ push จริง (FCM) — pete เลือก, สอดคล้องกับย้ายออกจาก Firebase (D-21)
- คุ้มกัน `products.moderation_status`/`rejection_reason` ด้วย **trigger** ไม่ใช่ policy — permissive policy ใหม่ไม่มีผลเพราะ OR กับ allow-all เดิม, `WITH CHECK` เทียบ OLD/NEW ไม่ได้ ยืนยันด้วย impersonation test จริงว่า non-admin โดนบล็อก
- Approve ไม่ส่ง notification (reject เท่านั้น) — ตรงสเปคที่ขอ

**ตัดออกจากสโคปนี้:** unread badge, realtime บน `notifications`, notification จากแชท (P-04)

**กับดัก SDK ที่เจอ:** ดู `PATTERNS.md` PT-17

**ผล:** L6 ⬜→🟨 · L8 ปิดช่องโหว่ "approve/reject ยังไม่ wire" จาก D-22 · RLS admin-only ยังเหลือ (ปิดแค่ 2 คอลัมน์)

**ผลที่ตามมา:** L6 ขยับจาก ⬜ เป็น 🟨 ทั้งสองฝั่ง (ไม่ใช่ ✅ — ยังไม่ทดสอบผ่านแอปจริง, ยังไม่มี push จริง) · L8 ปิดช่องโหว่ "approve/reject บนคิวสินค้ารอตรวจยังไม่ได้ wire" จาก D-22 แล้ว แต่ RLS admin-only แบบเต็มยังเป็นของค้างเหมือนเดิม (ตอนนี้ปิดแค่ 2 คอลัมน์ ไม่ใช่ทั้งตาราง)

## D-24 — root cause ของบั๊ก reject-flow (sheet ไม่ปิด/ไม่มี notification) + เปิดใช้ `reports` จริง (2026-08-15)

**Root cause ที่ยืนยันแล้ว (ไม่ใช่เดา):** `NotificationsTable().insert()` ที่ codegen สร้างให้ ทำ `.insert(data).select().limit(1).single()` เสมอ (ไม่มีทางปิด select-back ได้จาก DSL) — select-back โดน RLS **SELECT** policy กรอง ไม่ใช่ INSERT policy เดิม `notifications` มีแค่ policy `user_id = auth.uid()` → admin insert แจ้งเตือนให้ seller คนอื่นแล้ว select-back เห็น 0 แถว → PostgREST error → ทั้ง insert rollback → exception ทำให้ action chain หยุดก่อนถึง `context.pop()` (สาเหตุเดียวอธิบายทั้ง "sheet ไม่ปิด" และ "ไม่มี notification" — ไม่ใช่ 2 บั๊ก)

**ตัดสินใจ:**
- เพิ่ม policy `admin can read all notifications` (SELECT, `private.is_admin()`) — OR กับ policy เดิม แก้ root cause ตรง ๆ
- เปิดใช้ `reports` จริง: **ทั้งสองทาง** — (1) user รายงานสินค้าได้เอง (`ReportProductSheet` บน `ProductDetails`) (2) admin reject ก็ log เข้า `reports` ด้วย (เขียนที่ 3 ต่อจาก update products + insert notifications เดิม ไม่ใช่แทนที่)
- พบกับดักเดียวกันซ้ำล่วงหน้าที่ `reports`: ถ้าเปิดแค่ INSERT policy โดยไม่มี SELECT ให้ reporter อ่านแถวตัวเอง จะพังแบบเดียวกันตอน user ทั่วไปรายงาน (ไม่ใช่แค่ admin) — เพิ่ม policy `reporter can read own reports` (SELECT, `reporter_id = auth.uid()`) กันไว้ล่วงหน้า ไม่ต้องเจอเองอีกรอบ
- `status`: `'pending'` (user รายงาน) / `'resolved'` (admin log ตอน reject, ถือว่า action แล้วตั้งแต่สร้าง) — เพิ่ม `CHECK (status IN ('pending','resolved'))` + `DEFAULT 'pending'`
- `reported_product_id` FK เปลี่ยนจาก `ON DELETE CASCADE` เป็น **`ON DELETE SET NULL`** — ลบสินค้าไม่ควรลบประวัติ report ทิ้งไปด้วย (`reports_admin_view` มี `LEFT JOIN products` อยู่แล้วเลยไม่กระทบ)
- กันสแปมรายงานซ้ำด้วย **partial unique index** `(reporter_id, reported_product_id) WHERE status = 'pending'` — เปิดรายงานซ้ำได้ใหม่หลัง resolved แล้วเท่านั้น ไม่บล็อกถาวร
- `reports_admin_view` (มี `security_invoker = true` เหมือน `products_review_view`) join `products` + `public_profiles` 2 รอบ (reporter/seller name) — ดู D-01 สำหรับ pattern นี้

**ตัดออกจากสโคปนี้:** ไม่ส่ง notification ตอนรายงาน (pete เลือก, เก็บเงียบไว้ให้ admin ไปดูเอง) · ไม่มี resolve/dismiss UI · admin mailbox แค่ list+detail พื้นฐาน

**พบว่าทำไม่ได้ตามแผนเดิม:** ตั้งใจจะใส่ `onFailure`/`onSuccess` Snackbar ให้ทุก Postgres write ใน reject chain (กันเงียบซ้ำแบบ root cause) — เช็ค SDK source ตรง ๆ แล้วพบว่า `onSuccess`/`onFailure` มีแค่บน `ApiCall` เท่านั้น `PostgresCreate`/`PostgresUpdate`/`PostgresQuery`/`PostgresDelete` ไม่มี parameter นี้เลย และไม่มี chain-level try/catch ใด ๆ ใน SDK เวอร์ชันนี้ — ตัด scope นี้ออก บันทึกเป็น **PT-18**

**สถานะ ณ จบ session:** SQL ทั้งหมด apply แล้วจริงและ verify ผ่านครบ (ดู `checks/L7.sql` และ impersonation test ใน session log) — DSL (`ReportProductSheet`, `ProductDetails` entry point, `RejectProductSheet` 3rd write, `Reports`/`ReportDetail` pages) เขียนเสร็จใน `dsl/edit.dart` แล้วแต่**ยังไม่ push** เพราะเจอบล็อกใหม่ที่ไม่เกี่ยวกัน — ดู **D-25**

## D-25 — 🔴 พบ regression บล็อกทุก push บนโปรเจกต์ FlutterFlow ไม่เกี่ยวกับงานวันนี้เลย (2026-08-15)

**อาการ:** `flutterflow ai run`/`validate` ทุกครั้งวันนี้ (ตั้งแต่ ~08:25 เป็นต้นมา) fail ด้วย validation error ใหม่ 7 ตัวที่ไม่เคยมีมาก่อน:
- `VALIDATION_PARAMETER_PASSING` x4 — พารามิเตอร์ `productId`/`productTitle`/`sellerId` ที่ `PendingProductItem`/`IconButton` ส่งให้ `ProductDetails`/`RejectProductSheet` "not properly set"
- `VALIDATION_SUPABASE_DATABASE_ACTION` x1 — filter ผิดใน Supabase action ของ `IconButton`
- `VALIDATION_PROPERTY_OVERRIDE` x2 — "Generator variable does not exist" บน `Text` widget 2 ตัว

**ยืนยันแล้วว่าไม่เกี่ยวกับงานวันนี้:** รัน `dsl/edit.dart` เวอร์ชัน**เดิมเป๊ะ**ที่ push สำเร็จล่าสุด (commit `UwVD988G`, 02:47:29Z, ผ่านแล้วตอนนั้นด้วย warning เดิม 12 ตัวล้วน — border radius/shrinkWrap/auth-navigate ไม่มีตัวไหนเป็น error บล็อก) ผ่าน `flutterflow ai validate` ตรง ๆ **ได้ error ชุดใหม่ 7 ตัวเดียวกันทุกตัว** ⇒ เป็นการเปลี่ยนแปลงฝั่ง **server-side** ของโปรเจกต์ FlutterFlow เองระหว่าง 02:47–08:25 ไม่ใช่จากสคริปต์ฝั่งนี้

**สงสัยแหล่งที่มา:** session นี้มี FlutterFlow Desktop live-paired (`live.status` → `paired: true`) ระหว่างที่ pete ทดสอบ reject flow/admin login ผ่านแอปจริง — เข้าข่ายเดียวกับที่ `PATTERNS.md` PT-16/PT-17 เคยบันทึกไว้ (orphan node ไม่ error แต่ validate เจอ) แต่ key ของ node ที่ error (เช่น `Container_r7ef6frs`, `IconButton_o8lcyzzx`) **สุ่มใหม่ทุกครั้งที่ validate** — ไม่ใช่ key คงที่แบบ orphan ที่เคยเจอ จึงยังไม่ยืนยันกลไกแน่ชัด

**root cause ที่แท้จริง (พบหลัง):** ไม่ใช่ orphan node สะสม — คือ `PendingProductsList` (ListView ใน `HomeAdmin`) validate ผ่านเฉพาะตอนสคริปต์ authored มัน**สดในพุชนั้นเอง**ผ่าน `ensureReplaced` เท่านั้น ลบ `ensureReplaced` ออก (เทียบกับของที่ push ไปแล้วซึ่งทำงานปกติทุกอย่างบนแอปจริง) validate fail ทันที ยืนยันซ้ำหลายรอบในเซสชันเดียวกัน — รายละเอียดเต็มดู `PATTERNS.md` **PT-19** ไม่ใช่ sweep อัตโนมัติแบบที่ PT-17 §2 เคยเสียหาย เป็นการ retarget `ensureReplaced` ที่มีอยู่แล้วด้วย key จริงที่ verify สดก่อนทุกครั้ง (ปลอดภัย ไม่ใช่ automated sweep)

**แก้แล้ว:** retarget `ensureReplaced` ที่ key จริง (`flutterflow ai inspect --page HomeAdmin` ตรง ๆ ไม่ใช่ `--outline`/`--dsl-json` ที่เดินแค่ reachable tree) → validate ผ่าน `[OK]` → push สำเร็จ (commit `iO73cDkL9bGAf4hcfKpP`) ตามด้วย D-24's Reports/ReportDetail pages + HomeAdmin sidebar entry point (commit `6hlHqRlpvnKvWYM8oUo4`) — ทั้งหมด**live แล้วจริง** ไม่ใช่แค่เขียนรอ

**ภาระถาวรที่เหลือ:** `PendingProductsList`'s `ensureReplaced` **ห้ามลบออกจากสคริปต์** ต่างจาก pattern ปกติที่ลบทิ้งหลังใช้เสร็จ — ทุก push ที่แตะ `dsl/edit.dart` (ไม่ใช่แค่ push ที่แก้ `HomeAdmin`) ต้อง verify key สดก่อนเสมอ ไม่งั้น validate fail — ดู PT-19

**ผล:** ปลดบล็อกแล้ว L7 ทั้งสองฝั่ง (Supabase + FlutterFlow) เสร็จจริง — user รายงานสินค้าได้ (`ReportProductSheet`), admin log ตอน reject (`RejectProductSheet` 3rd write), admin mailbox ใช้งานได้ (`Reports`/`ReportDetail` + sidebar icon)

## D-26 — `addproduct` แฟลชไป Login หลังลงขายสำเร็จ (root cause + แก้) + Notifications เชื่อมไป ProductDetails + ปุ่มติดต่อแอดมิน mock (2026-08-15)

**อาการที่ pete รายงาน:** กด "ลงขายสินค้า" สำเร็จ (snackbar ขึ้น, แถวเข้า `products` จริง) แต่แอปเด้งกลับไปหน้า `Login`

**root cause ที่ยืนยันแล้ว:** `addproduct` ลงทะเบียนเป็น **tab ของ `NavBarPage`** (`nav.dart`: `params.isComplete ? NavBarPage(initialPage: 'addproduct') : AddproductWidget()`) ไม่ใช่ route ที่ push ปกติ — ไม่มี back-stack ของตัวเองให้ pop กลับ ปุ่มลงขายจบด้วย `NavigateBack()` (หลัง insert+snackbar+reset รูปทั้งหมดทำงานถูกต้องแล้ว) การ pop ที่ไม่มีอะไรให้ pop จริงไปโดน router's root/error builder ทั้งคู่ที่ re-evaluate `appStateNotifier.loggedIn ? NavBarPage() : LoginWidget()` (`nav.dart:87,93`) ตรงกับอาการทุกจุด

**แก้แบบ surgical ไม่ reconstruct ทั้ง chain:** action chain ของปุ่มลึก 9 ชั้น (authored มาจาก session ก่อนหน้า ไม่อยู่ใน `dsl/edit.dart` ปัจจุบัน) ที่ insert/snackbar/reset ทำงานถูกต้องอยู่แล้ว — reconstruct ใหม่ทั้งหมดผ่าน `ensureActions` (replace ทั้ง chain) เสี่ยงพิมพ์ผิดแล้วพังของที่ใช้งานได้อยู่ แทนที่ด้วย `app.raw` เดินหา action สุดท้ายของ chain (รองรับ conditional branch ด้วย — เจอว่า chain มี `conditionActions` คั่นกลาง ไม่ใช่ linear ล้วน) แล้ว clear เฉพาะ `NavigateBack()` ตัวสุดท้ายออก ไม่แตะอะไรอื่นเลย — ยืนยันจาก `generated_code/lib/addproduct/addproduct_widget.dart` ว่า insert/snackbar/reset รูปทั้ง 6 บรรทัดยังอยู่ครบ เหลือแค่ `context.pop()` หายไป

**เพิ่มใหม่ (ตามที่ pete ขอหลังเทส):**
- `Notifications` (`Scaffold_u6bemkzb`) — แตะ item ตอนนี้ทำ 2 อย่างเรียงกัน: mark-as-read (เดิม) + `Navigate(ProductDetails, {productId: item['ref_product_id'], fromNotifications: true})`
- `ProductDetails` (`Scaffold_amt0m1za`) — param ใหม่ `fromNotifications` (bool, default false) + ปุ่ม "ติดต่อแอดมิน" เต็มความกว้าง แสดงเฉพาะตอน `fromNotifications = true` — **เป็น placeholder ล้วน** (แค่ snackbar) เตรียมไว้สำหรับ L4 (แชท) ตามที่ pete ยืนยัน ยังไม่ใช่ระบบส่งข้อความจริง

**กับดัก SDK ที่เจอเพิ่ม:** `page.findByKey(...)` (dynamic search) คืน "found no matches" สำหรับทุก key บน `ProductDetails` แม้ `inspect --outline` ยืนยันว่า key นั้น live อยู่จริง — หน้านี้ไม่เคยใช้ `page.findByKey` สำเร็จมาก่อน (edit เดิมทั้งหมดผ่าน `ff.Pages.productDetails.widgets.byPath/byKey` ของ typed SDK) สลับไปใช้ typed SDK selector แทนก็ผ่านทันที — ยังไม่รู้กลไกที่แท้จริง บันทึกไว้เป็นข้อสังเกต ไม่ใช่กฎทั่วไป (เพจอื่นที่ใช้ `page.findByKey` มาตลอดเช่น `HomeAdmin`/`Reports`/`Notifications` ไม่มีปัญหานี้)

**ผล:** ทั้ง 3 อย่าง push สำเร็จจริง ยืนยันผ่าน `generated_code/` ครบ (commit `bxujSHgcJpXUCibPheEe`, `Paj09FrVxaQrzsx0OJeE`) — รอ pete เทสผ่านแอปจริงเป็นด่านสุดท้าย

## D-27 — `ContactAdminButton` หายไปเงียบ ๆ 1 push ให้หลัง D-26 — พบ + แก้ root cause ที่กว้างกว่านั้นมาก (2026-08-15)

**อาการที่ pete รายงาน:** ปุ่ม "ติดต่อแอดมิน" ที่เพิ่งเพิ่มใน D-26 ไม่โผล่เลยในแอปจริง

**root cause:** ปุ่มถูกใส่เข้าไปจริงและ push สำเร็จใน D-26 (ยืนยันจาก `generated_code/` ตอนนั้น) — แต่ push ถัดมา (D-26's ส่วนที่ 2, wiring การเชื่อม `Notifications`) ทำให้มัน**หายไปเงียบ ๆ** เพราะ `ProductDetailsBody`'s `ensureReplaced` (สร้างไว้ตั้งแต่ L3 ยุคแรก ไม่เคย retire) ยังคง active อยู่ในสคริปต์ — ทุกครั้งที่ `flutterflow ai run` รันทั้งไฟล์ (ไม่ว่า push นั้นจะเกี่ยวกับ `ProductDetails` หรือไม่) มันคืนค่า body ทั้ง subtree กลับเป็นเวอร์ชันดั้งเดิม (ไม่มีปุ่ม) ทับปุ่มที่เพิ่มเข้าไปทีหลังผ่าน `ensureInsertedInto` แยกต่างหาก — ไม่มี error ใด ๆ เลยทั้ง validate และ push เพราะ key ยังแมตช์ถูกต้องทุกครั้ง (ต่างจาก D-25/PT-19 ที่ key ตายไปแล้ว) รายละเอียดกลไกเต็ม ๆ ดู `PATTERNS.md` **PT-21**

**สำรวจเพิ่ม:** grep ทั้งไฟล์หา `ensureReplaced`/`ensureInsertedInto` ที่ยัง active พบก้อนเก่าที่ควร retire ไปนานแล้วอีก 4 ก้อน — `ReportsList`, `ReportDetailContent`, `Home`'s bell icon (ทั้ง 3 นี้ยังไม่เคยเสียหายจริง เพราะไม่มีอะไรมาแตะ subtree ทีหลัง) และ dead code เก่าอีก 1 ก้อนที่ target key ตายไปนานแล้ว (`ListView_mctnycd6`, เป็นเวอร์ชัน `PendingProductsList` ก่อน D-23 เลย ไม่มี approve/reject) — retire/ลบทิ้งทั้งหมดในพุชเดียวกัน

**แก้แล้ว:** retire `ProductDetailsBody`'s `ensureReplaced`, เพิ่มปุ่มกลับเข้าไปใหม่ผ่าน `ensureInsertedInto` แยก แล้ว retire ตัวนั้นด้วยหลัง push สำเร็จ — ยืนยันจาก `generated_code/` ว่า `if (widget!.fromNotifications)` ครอบปุ่มถูกต้อง และเนื้อหาส่วนอื่นของ `ProductDetailsBody` (รูป/ชื่อ/ราคา/คำอธิบาย/ผู้ขาย) ไม่กระทบ (commit `wU20KxD0sL9ENyFQZdgY`)

**บทเรียนสำคัญ:** "ตรวจไม่เจอปัญหา" ไม่เท่ากับ "ปลอดภัยที่จะทิ้งไว้" — กฎ retire-หลัง-สำเร็จ (PT-16 เดิม) ต้องใช้กับ`ensure*`ทุกตัวไม่มีข้อยกเว้น ไม่ใช่แค่ตัวที่เคยเห็นพังจริงแล้ว
