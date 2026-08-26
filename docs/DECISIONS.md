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

## D-28 — ข้อจำกัดจริงของการเรียก subagent (`.claude/agents/`) ที่เจอตอนใช้งานจริง (2026-08-07, ย้ายมาจาก `AGENTS.md`)

**1. เรียก subagent ได้เฉพาะบน Claude Code CLI ในเทอร์มินัล** — Cowork/เดสก์ท็อปเรียกไม่ได้ (รายชื่อ agent ล็อกตายตัว ขึ้น `Agent type 'db-verifier' not found`)
ทางแก้เมื่อเรียกไม่ได้: implementer รันเองตาม checklist ใน `.claude/agents/db-verifier.md` เป๊ะ ๆ — เสียแค่ context isolation ไม่เสียความเข้มของการตรวจ

**2. ห้าม hardcode ชื่อ Supabase MCP ในบรรทัด `tools:`** — โปรเจกต์นี้ไม่มี `.mcp.json` ชื่อ MCP จึงไม่คงที่ (Cowork = UUID เปลี่ยนทุก session, CLI = แล้วแต่ config ที่ยังไม่มี) ชื่อ `mcp__supabase__*` ที่เคยเขียนไว้เป็นแค่ placeholder ที่ไม่เคยมีจริง — hardcode แล้ว agent เรียก tool ไม่ได้แบบเงียบ ๆ
**ตัดสินใจ:** ตัดบรรทัด `tools:` ออกจาก `db-verifier`/`doc-syncer` ให้ inherit จาก session แม่ (`ui-checker` คงไว้ได้ เพราะใช้ `Read, Glob, Grep, Bash` built-in ล้วน)
**ผลข้างเคียง:** `db-verifier` ได้ `Write`/`Edit` ติดมาด้วยจากการ inherit ทั้งหมด — กติกา READ-ONLY จึงบังคับด้วย prompt เท่านั้น ไม่มีรั้วระดับ tool แล้ว (ถ้าอยากได้รั้วจริงคืนมา ต้องสร้าง `.mcp.json` ชื่อ `supabase` ด้วย Supabase access token ที่ pete เป็นคนใส่ แล้วค่อย pin `tools:` กลับ)

**3. นิยาม subagent อยู่ที่ `.claude/agents/` ที่เดียว** — ห้ามทำสำเนาไว้ใน `docs/`, Claude Code โหลดจาก `.claude/` เท่านั้น สำเนาที่ไหนก็ตามจะกลายเป็นของเก่าที่ดูเหมือนของจริง

## D-29 — L4 chat: ปิดหนี้ RLS allow-all (D-03) ก่อนเริ่มสร้างจริง + เพิ่มรองรับส่งรูป (2026-08-16)

**บริบท:** เริ่ม L4 (chat) ตามคิว `STATUS.md` — ระหว่าง plan pete สั่งให้แก้ 6 จุดที่มองว่าเสี่ยงในดราฟต์แรก ก่อนลงมือจริง

**1. RLS ของ `chat`/`chat_user`/`chat_message` เปลี่ยนจาก allow-all → membership-based ทันที** (ไม่รอ production ตาม D-03 เดิม) เพราะแชทเป็นข้อมูลส่วนตัวโดยตรง ต่างจาก `products` (สาธารณะอยู่แล้ว) — สร้าง helper `is_chat_member(chat_id)` (`SECURITY DEFINER`) เพื่อเลี่ยง self-referential policy บน `chat_user` (ถ้าใช้ `user_id = auth.uid()` ตรง ๆ จะทำให้ `chat_summary`'s `member_names` เห็นแค่ชื่อตัวเอง เพราะ join ไม่เห็นแถวสมาชิกคนอื่น)

**2. `find_or_create_chat` เพิ่ม guard `auth.uid() = user_a`** — ดราฟต์เดิม (`PROPOSED_SQL.md` P-03) ไม่กันการปลอมตัว: `SECURITY DEFINER` + ไม่เช็คตัวตน = ใครก็เรียกได้ให้สร้างห้องแทนคนอื่นได้ ทดสอบแล้วว่า `raise exception` จริงเมื่อ `user_a` ไม่ตรงกับผู้เรียก

**3. `get_my_chats()` สร้างไว้แต่ไม่ได้ใช้จริง** — เดิมตั้งใจแก้ปัญหา "query builder รองรับ array-contains บน `user_ids` ไหม" (คำถามค้างเดิมใน `STATUS.md`) แต่หลังทำข้อ 1 แล้วพบว่า query `chat_summary` แบบไม่มี filter เลยก็ปลอดภัย เพราะ RLS กรองให้อยู่แล้ว — เก็บ RPC นี้ไว้เป็น convenience API เผื่ออนาคต (เช่น Edge Function) ไม่ลบทิ้ง

**4. Realtime ต้อง subscribe ที่ `chat_message` (table) ไม่ใช่ `chat_messages_view`** — ตอบได้จากหลักการ (Postgres logical replication ทำงานระดับ table เท่านั้น) ไม่ต้องเสียเวลาทดสอบ ตามที่ pete เตือน — แต่ยังไม่ได้ต่อ Realtime จริงในพุชนี้ (ดู `layers/L4-chat.md` คิวถัดไป)

**5. เพิ่มรองรับส่งรูป** — `chat_message.message` เปลี่ยนเป็น nullable, เพิ่ม `image_url text` + CHECK `chat_message_has_content` (อย่างน้อย 1 ใน 2 ต้องมีค่า), เพิ่ม bucket `chat-images` (public, 5MB, path เหมือน `product-images`) — trigger `update_chat_last_message` ใช้ `COALESCE(message, '📷 รูปภาพ')` กันข้อความรูปล้วนทำให้ chat list โชว์ค่าว่าง — **ฝั่ง FlutterFlow ยังไม่มีปุ่มส่งรูปเลย** (คิวถัดไป)

**6. Advisor เพิ่มเติมที่แก้พร้อมกัน (ไม่ได้ขอ แต่พบระหว่างทำ):** ทุกฟังก์ชันใหม่ pin `search_path = public` กันโจมตีแบบ search_path hijack, และ revoke EXECUTE จาก `anon` ออกจากทุกฟังก์ชัน (Supabase auto-grant `anon`/`authenticated` ตอน `CREATE FUNCTION` แยกจาก PUBLIC pseudo-role ต้อง `REVOKE ... FROM anon` ตรง ๆ ไม่ใช่แค่ `FROM PUBLIC`) — `update_chat_last_message` ไม่มี grant เลยเพราะเป็น trigger-only

**ผล:** L4 Supabase ✅ ปิดสนิท (RLS/RPC/trigger ทดสอบสิทธิ์จริงผ่าน `db-verifier`) · FlutterFlow 🟨 แชทข้อความล้วนใช้งานได้จริง (chatList + chatMessages + ปุ่ม "แชทกับผู้ขาย") ยังไม่มีรูป/Realtime — รายละเอียด `layers/L4-chat.md`, กับดัก SDK ที่เจอใหม่ `PATTERNS.md` PT-22/PT-23

**🔴 พบบั๊ก build-breaking ระหว่างตรวจปิด layer (ui-checker):** custom function `getOtherUsers`/`senderLabel` เข้าถึง `.length`/`[i]` บน `List<String>?` โดยไม่ guard null — ทำให้ `dart analyze` ไม่ผ่านทั้งโปรเจกต์ (validate ของ `flutterflow ai run` เป็นแค่ shape/format check ไม่ใช่ full type-check ข้ามไฟล์ จึงหลุดผ่านมาได้) แก้แล้วด้วย `?? []`, ยืนยันซ้ำด้วย `dart analyze` ตรง ๆ ผ่านสะอาด — บทเรียน: การันตี "compile ผ่าน" จริงต้องรัน `dart analyze` แยกต่างหาก ไม่ใช่เชื่อแค่ `flutterflow ai run` สำเร็จ

## D-30 — ปุ่ม "ติดต่อแอดมิน" ต่อเข้าระบบแชทจริง + เพิ่มทางเข้า `chatList` ใน `HomeAdmin` (2026-08-16)

**บริบท:** pete ทดสอบ D-29 แล้วสังเกตว่าปุ่ม "ติดต่อแอดมิน" บน `ProductDetails` (mock เดิมจาก D-26) ยังไม่ต่อกับระบบแชทจริง ทั้งที่หลักการเดียวกับปุ่ม "แชทกับผู้ขาย" — และ `HomeAdmin` (ที่ pete เพิ่ม Drawer เองแล้ว) ยังไม่มีทางเข้าไปดู `chatList` เลย

**1. "ติดต่อแอดมิน" ส่งไปหาแอดมิน**คนเดียว**ไม่ใช่กระจายทุกคน** — เลือกแอดมินแบบ deterministic (`created_at` เก่าสุด) ผ่าน RPC ใหม่ `find_or_create_chat_with_admin(user_a)` แทนที่จะให้ client query `"Profile" WHERE role='admin'` เอง เพราะ RLS ของ `"Profile"` (ดู `SCHEMA.md`) ให้ user ธรรมดาเห็นแค่แถวตัวเอง — query ตรงจาก client จะได้ 0 แถวเสมอ ต้องเป็น `SECURITY DEFINER` ฝั่ง DB เท่านั้นที่มองเห็นแอดมินได้ แนวทางกลุ่มแชท (ทุกแอดมินอยู่ห้องเดียวกัน) ก็ทำได้ (schema รองรับ many-to-many อยู่แล้ว) แต่ยังไม่ทำ — ยังไม่มีคนขอ เพิ่มทีหลังได้โดยไม่กระทบของเดิม

**2. `ContactAdminButton` ต่อผ่าน `page.ensureActions`** (เหมือน `SendMessageButton` ใน D-29) ไม่ใช่เขียนทับปุ่มใหม่ทั้งก้อน — ปุ่มมีอยู่แล้วจริงจาก D-26/D-27 แค่เปลี่ยน onTap จาก snackbar mock เป็น custom action `findOrCreateChatWithAdmin` (0-arg, PT-09) + Navigate แบบมี guard (`chatId != 0`)

**3. เพิ่มปุ่ม "ข้อความ" ใน Drawer ของ `HomeAdmin`** ที่ pete สร้างเอง (`Drawer_sdz1yfyn` > `Column_4pg1tqma`) ต่อจากปุ่ม "รายการรีพอร์ต" เดิม — ให้แอดมินเข้า `chatList` เพื่ออ่าน/ตอบข้อความที่ user ส่งมาได้

**🆕 กับดัก SDK ที่เจอเพิ่ม (แยกจาก PT-22/23):** custom action ที่เรียก `Supabase.instance.client` ต้อง `import 'package:supabase_flutter/supabase_flutter.dart';` เองเป็นบรรทัดแรกของ `code:` — ไม่อยู่ใน automatic imports `flutterflow ai run`/validate ไม่จับ (pete เจอเองจาก Issues panel ใน FlutterFlow editor ตอนทำ `findOrCreateChatWithSeller` ก่อนหน้านี้) บันทึกไว้ที่ `PATTERNS.md` PT-09 แล้ว ใส่ import ถูกต้องตั้งแต่แรกในรอบนี้ (`findOrCreateChatWithAdmin`) ไม่เจอซ้ำ

**ผล:** ทั้ง 2 จุด push สำเร็จ ยืนยันจาก `generated_code/` ครบ (commit `oYWn1zSpYRSrspqSNPaX`) — ยังไม่เคยทดสอบผ่านแอปจริง รอ pete

## D-31 — Unread indicator (จุดแดง glow) บน chatList/Notifications/ReportsFeedback + พบกับดักจากการ rename หน้าใน editor (2026-08-17)

**บริบท:** pete ขอจุดแดงบอกว่ายังไม่อ่าน หายไปเมื่อกด บนทั้ง 3 หน้ารายการ (chat, notification, report)

**1. "อ่านแล้ว" ของแชทเก็บเป็น `chat_user.last_read_at` (timestamp ต่อสมาชิก) ไม่ใช่ boolean เดียวแบบ `notifications.is_read`** — เพราะห้องแชทมีได้หลายคน แต่ละคนอ่านข้อความล่าสุดคนละเวลา ถ้าใช้ boolean เดียวจะพังทันทีที่มีสมาชิก ≥ 2 คน (คนหนึ่งอ่านแล้วอีกคนที่ยังไม่อ่านจะเห็นว่า "อ่านแล้ว" ไปด้วย) `chat_summary.is_unread` คำนวณจาก `auth.uid()` ของผู้เรียกเองที่ runtime เทียบกับ `last_read_at` ของตัวเอง

**2. Mark-as-read ทั้งแชทและรีพอร์ตต้องผ่าน RPC (`mark_chat_read`/`mark_report_read`) ไม่ใช่ table grant ตรง ๆ** (notifications ใช้ table grant ตรงได้เพราะ RLS เดิม `user_id = auth.uid()` ปลอดภัยอยู่แล้ว ไม่ต้องเปลี่ยน) — เหตุผลของแชท: ถ้าเปิด UPDATE บน `chat_user` ให้ authenticated ตรง ๆ (แม้จะจำกัดแค่แถวตัวเอง) จะเปิดช่องให้ user เขียนแถว `chat_user` ปลอมตัวเป็นสมาชิกห้องไหนก็ได้ ซึ่งเท่ากับ bypass `is_chat_member()` ทั้งระบบที่เพิ่งปิดไว้ใน D-29 — RPC จำกัดแค่ `UPDATE last_read_at WHERE user_id = auth.uid()` (แก้ได้แค่ค่าเดียว ไม่มีทาง INSERT แถวใหม่) เหตุผลของรีพอร์ต: `reports` ไม่เคยมี UPDATE policy เลย (ทุกการเขียนเดิมเป็น INSERT ตาม D-24) เปิด RPC ที่เช็ค `private.is_admin()` ง่ายกว่าและปลอดภัยกว่าเปิด UPDATE policy กว้าง ๆ

**3. 🔴 พบกับดักจริงระหว่างพุช — การ rename หน้าใน FlutterFlow editor โดยตรงทำให้ DSL script เก่าพังแบบไม่คาดคิด:** pete เปลี่ยนชื่อหน้า "Reports" เป็น "ReportsFeedback" ในตัว editor เอง — พุชแรกของงานนี้ fail ด้วย `Member not found: 'reports'` เพราะ `ff.Pages.reports` (typed SDK symbol) หายไปตามชื่อใหม่ ที่อันตรายกว่านั้นคือ **`app.ensurePage('Reports', ...)` ตัวเดิมในสคริปต์ (ที่เคยสร้างหน้านี้ไปนานแล้ว) จะไม่ no-op อีกต่อไป** เพราะ `ensurePage` เช็คตาม**ชื่อ** ไม่ใช่ node identity — ถ้าไม่จับได้ก่อน push ผ่าน จะได้หน้าใหม่ชื่อ "Reports" ซ้อนขึ้นมาแยกจาก "ReportsFeedback" ของจริง (และอาจชน route `/reports` เดิมด้วย) แก้โดยลบ `ensurePage('Reports', ...)` ทิ้งและเปลี่ยนทุกจุดเป็น `ff.Pages.reportsFeedback`
**บทเรียน:** การ rename entity ใน FlutterFlow editor โดยตรง (ไม่ผ่าน DSL) ปลอดภัยต่อ Action/Navigate ที่มีอยู่แล้ว (FF ผูกด้วย node id ไม่ใช่ชื่อ) แต่ทำให้ **DSL script เก่าที่อ้างชื่อเดิมเสี่ยงพังเงียบ** โดยเฉพาะ `ensurePage`/`ensureComponent` ที่ no-op ตามชื่อ — ควรเช็ค `flutterflow ai resources <id>` เทียบชื่อหน้าจริงก่อนแตะไฟล์ที่มี `ensurePage` เก่าเสมอถ้าสงสัยว่ามีใคร rename อะไรไปนอกเซสชัน

**ผล:** ทั้ง 3 หน้ามีจุดแดง glow (`Colors.error` + `Shadow(blur:6, spread:2)`) ที่ item ที่ยังไม่อ่าน หายไปหลังแตะ ยืนยันจาก `generated_code/` ครบทั้ง visibility condition และ mark-read wiring (commit `7h4OfmbkB8U6XViI1jiF`) — ยังไม่เคยทดสอบผ่านแอปจริง รอ pete

## D-32 — DoD audit ทั้งโปรเจกต์ (db-verifier + ui-checker คู่ขนาน) พบบั๊กจริง 4 จุด (2026-08-17)

**บริบท:** pete ขอตรวจ Definition of Done ของทุก layer ที่มีงานจริงแล้ว (L1/L2/L3/L4/L6/L7/L8, ข้าม L5 เพราะยังไม่เริ่ม) ก่อนแตะเอกสารต่อ — เรียก `db-verifier` (ตรวจ DB/RLS ตรง) และ `ui-checker` (ตรวจ `generated_code/` ตรง ไม่ใช่แค่ inspect) คู่ขนาน ผลตรงกัน: L2/L3/L4(core)/L6/L7 PASS, L1/L8 พบบั๊กจริง + 2 จุดที่ audit ฝั่ง FlutterFlow เจอเพิ่มนอกสโคป

**1. 🔴 L1 — 2 บัญชี `auth.users` ไม่มีแถวใน `"Profile"` เลย** (`handle_new_user()` ไม่ทำงาน/fail เงียบ):
   - `mju6606105382@mju.ac.th` ("ปิติเทพ โบวิเชียร") — สร้าง 2026-08-09, **ยืนยันอีเมลแล้ว 2026-08-13** → ดูเหมือนสมัครจริง บัญชีนี้ใช้แอปไม่ได้เลยตอนนี้ (ทุกจุดที่ join `"Profile"` จะว่าง)
   - `mju6606105386@mju.ac.th` ("pete") — สร้าง 2026-08-13, ยังไม่ยืนยันอีเมล
   ตรวจแล้วไม่มี UNIQUE constraint ชนกันที่ `email`/`student_id` ทั้งคู่ — หาสาเหตุจาก DB อย่างเดียวไม่เจอ (อาจเป็น trigger error ที่ auth log ไม่ได้เก็บ หรือ race condition) **ยังไม่ได้แก้/backfill** เพราะต้องรู้สาเหตุก่อนว่าจะเกิดซ้ำไหม ก่อน L1 ปิดสนิทได้จริง

**2. 🔴 L8 — `admin_sales_by_seller` ไม่มี admin gate เลย** — view นี้ `security_invoker=true` พึ่ง RLS ของ `products` เพียงอย่างเดียว และ `products` ยัง allow-all สำหรับ authenticated (หนี้ D-03 ที่ยังไม่ปิด) ผลคือ **authenticated ธรรมดาอ่านยอดขายรวมข้าม seller อื่นได้ทันที** (`seller_name`/`items_sold`/`total_sales`) ตอนนี้ยังไม่เห็นผลจริงเพราะยังไม่มีแถว `products.status='sold'` สักแถว — เป็นระเบิดเวลา ไม่ใช่ปัญหาที่ "ยังไม่เกิด" **ต้องแก้ก่อนมีการขายจริงครั้งแรก** ทางแก้ที่เป็นไปได้: เพิ่ม `WHERE` เช็ค `private.is_admin()` ในตัว view เอง (อย่าพึ่ง RLS ของ `products` ต่อ เพราะ `products` เองก็เป็นหนี้ D-03 ที่ยังไม่ปิด)

**3. L4 — ยืนยันแล้วว่า Realtime "ไม่มีเลย" ไม่ใช่แค่ "ยังไม่ยืนยัน"** — `ui-checker` grep ทั้ง `generated_code/lib/` หา `.stream(`/`StreamBuilder`/`SupabaseStreamBuilder` เจอ 0 จุดใช้งานจริงนอก unused base-class ใน `table.dart` ปิดคำถามเดิมใน STATUS.md ที่เขียนว่า "ยังไม่ยืนยัน" — ตอนนี้ยืนยันชัดว่าไม่มีการ subscribe เลย ต้องรีเฟรชมือหลังส่งข้อความ/มีข้อความใหม่เสมอ

**4. 🔴 L4/L6/L7 — จุดแดง unread (D-31) มี stale-state bug จริง ยืนยันจากโค้ด ไม่ต้องรอทดสอบสด:** `chatList`/`Notifications`/`ReportsFeedback` ทั้ง 3 หน้าโหลด list ครั้งเดียวใน `initState` ปุ่มกดของแต่ละหน้าเรียก mark-read RPC ถูกต้อง แต่ **ไม่ refetch list หรือแก้ค่า item ในโลคอลก่อน navigate ออก** — Flutter ไม่รัน `initState` ซ้ำตอน pop กลับมา จุดแดงเลยยังค้างแสดงผลเดิมจนกว่าหน้าจะถูกทำลาย/สร้างใหม่จริง (เช่นสลับ bottom-nav tab) เทียบกับปุ่ม approve/reject ของ `HomeAdmin` ที่ refetch ถูกต้องหลัง mutate (`home_admin_widget.dart:2321-2333`) — เป็น pattern อ้างอิงว่าต้องแก้ยังไง **ยังไม่ได้แก้ในรอบนี้** (audit-only round)

**นอกสโคปที่เจอเพิ่มระหว่างตรวจ L2 (คุ้มบันทึกเพราะกระทบ DoD):**
**5. `Mypost` มีอยู่แล้วจริงในโปรเจกต์ (ไม่ใช่ "ยังไม่สร้าง" ตามที่ STATUS.md คิวเดิมเขียนไว้)** — 1824 บรรทัด ขึ้นเป็นแท็บ bottom-nav จริง (`main.dart:148`) แต่ query เดียวของหน้านี้ (`ProductsReviewViewTable().queryRows`) **ไม่มี filter เลย** — grep ทั้งไฟล์หา `seller_id`/`currentUserUid` ไม่เจอ ผลคือหน้านี้โชว์สินค้าของ**ทุกคน**ทุกสถานะ ไม่ใช่ "ของฉัน" ตามชื่อหน้า — แก้คิว STATUS.md จาก "สร้าง Mypost/Inspect" เป็น "แก้ filter ของ Mypost ที่มีอยู่แล้ว"

**เอกสารที่ล้าสมัยที่พบและแก้พร้อมกันรอบนี้:**
- `checks/L4.sql` ไม่มีเช็ค RPC/คอลัมน์ที่เพิ่มจาก D-30/D-31 เลย — เพิ่ม [4.5]/[4.5b]/[4.5c] แล้ว
- `checks/L6.sql` [6.7] เช็คชื่อคอลัมน์ `ref_id` ที่ไม่เคย apply จริง (ของจริงคือ `ref_product_id` ตาม D-23) — query เดิมว่างเปล่าตลอด อ่านผิดเป็น "คอลัมน์หาย" ได้ — แก้ชื่อคอลัมน์ถูกแล้ว + เพิ่มเช็ค `is_read` (D-31)
- `checks/L8.sql` [8.2] แพทเทิร์นจับ policy แบบ admin-only พลาดเคสที่เรียกผ่านฟังก์ชัน (`private.is_admin()`) — ขยายแพทเทิร์นแล้ว + เพิ่ม [8.2b] เช็ค `admin_sales_by_seller` grants ตรงจากบั๊กข้อ 2
- `layers/L6-notifications.md`/`L7-reviews-reports.md`/`L8-admin.md` — header สถานะเขียนไว้ว่า "ยังไม่เริ่ม"/"⬜" ทั้งที่มีตาราง/RLS/UI ใช้งานจริงแล้วหลายเดือน (ไม่ตรงกับ `STATUS.md` มานานแล้ว) — อัปเดตให้ตรงสถานะจริงในรอบนี้

**ผล:** ไม่มีการแก้โค้ด/ไม่มีการ apply SQL ในรอบนี้ (audit + doc-sync only) — ปัญหาข้อ 1/2/4/5 ยังเปิดอยู่ รอ pete ตัดสินใจลำดับความสำคัญ ก่อนแตะแก้จริง

## D-33 — ปิดช่องโหว่ `admin_sales_by_seller` ด้วย gate ที่ตัว view เอง (2026-08-17)

**เลือก:** เพิ่ม `AND private.is_admin()` เข้า `WHERE` ของ view โดยตรง ไม่รอปิดหนี้ D-03 ของ `products` (RLS allow-all) ก่อน — ตามที่ D-32 เสนอไว้เป็นทางเลือกแรก

**เหตุผล:** D-03 กระทบ `products` ทั้งตาราง เป็นงานใหญ่กว่ามาก (Action Flow หลายจุดใน L2/L3/L8) ส่วนช่องโหว่นี้เป็นระเบิดเวลาเฉพาะ view เดียว แก้แยกได้ทันทีโดยไม่ต้องรอ · `private.is_admin()` เป็น helper ที่ใช้ซ้ำอยู่แล้วใน policy ของ `Profile`/`reports`/`notifications` พิสูจน์แล้วว่าทำงานถูกต้องกับ user ธรรมดา

**ทดสอบ:** impersonation test จริงผ่าน transaction (`UPDATE products SET status='sold'` ชั่วคราว แล้ว `ROLLBACK`) — user ธรรมดา (`mju6512345678`) ได้ 0 แถว, admin (`mju6577778888`) เห็นแถวถูกต้อง แม้มีแถว `sold` อยู่จริงระหว่างทดสอบ (ไม่ใช่แค่บล็อกเพราะตารางว่าง) · `get_advisors` ไม่ขึ้น advisory ใหม่จากการแก้นี้

**เอกสารที่แก้พร้อมกัน:** `SCHEMA.md` (นิยาม view), `STATUS.md` (ตัดคิว + หนี้), `layers/L8-admin.md` (ตัดหัวข้อ 🔴 ด่วน), `checks/L8.sql` [8.2b] (comment)

---

## D-34 — Confirm Email (D-20) ปลดล็อกจริง: Send Email Hook → Resend → relay เข้า admin inbox เดียว แทนส่งตรงถึง student (2026-08-17)

**บริบท:** D-20 ค้างเพราะ custom SMTP (Gmail ส่วนตัว) ส่ง OTP ไปไม่ถึงกล่อง `@mju.ac.th` เลย (เข้าข่าย Microsoft Zero-hour Auto Purge — ไม่มี sending reputation กับ tenant)

**ตัดสินใจ:** เลิกส่ง OTP ตรงถึง student ใช้ Supabase Auth **Send Email Hook** (HTTPS) เรียก Edge Function `send-otp-email` แทน mailer เริ่มต้น ฟังก์ชันส่ง OTP ผ่าน **Resend API** ไปที่ **inbox แอดมินเดียว** (`ADMIN_INBOX_EMAIL`) พร้อมอีเมลของ student แล้วให้แอดมิน relay รหัสออกนอกระบบเอง — ข้ามปัญหา deliverability แทนที่จะพยายามแก้มัน

**ของที่มีอยู่จริงตอนนี้:**
- Auth Hook "Send Email" (HTTPS, `ENABLED`) → `https://rooydbxgcsybyanwsewv.supabase.co/functions/v1/send-otp-email`
- Edge Function `send-otp-email` — verify payload ด้วย `standardwebhooks`, ส่งอีเมลผ่าน `resend` npm package
- 3 secrets ระดับโปรเจกต์ (Edge Functions → Secrets, ใช้ร่วมทุกฟังก์ชัน): `RESEND_API_KEY`, `SEND_EMAIL_HOOK_SECRET` (รูปแบบ `v1,whsec_<base64>` จากหน้า Auth Hooks), `ADMIN_INBOX_EMAIL`

**กับดักที่เจอระหว่างเซ็ต (เผื่อเจอซ้ำ):**
1. secret ขาด/พิมพ์ผิดชื่อ → throw ตอน cold boot ก่อนถึง request handler — `Missing API key` (`RESEND_API_KEY`) หรือ `Cannot read properties of undefined (reading 'replace')` (`SEND_EMAIL_HOOK_SECRET`) — GoTrue เห็นเป็น 500 เฉย ๆ
2. **Resend sandbox sender (`onboarding@resend.dev`) ส่งได้แค่อีเมลเจ้าของบัญชี Resend เท่านั้น** จนกว่าจะ verify domain จริง — `ADMIN_INBOX_EMAIL` ต้องตรงเป๊ะ ไม่ใช่อีเมลจริงอะไรก็ได้ ผิดแล้วได้ `422`/`403` จาก Resend ตรงใน `function_logs`
3. **`over_email_send_rate_limit` (429) คนละชั้นกับ Resend/hook** — เป็น GoTrue project-wide rate limit (`GOTRUE_RATE_LIMIT_EMAIL_SENT`) นับทุก signup/resend แม้ hook จะ fail ทีหลัง default ต่ำมาก (2/ชม.) ปรับขึ้นเป็น **30/ชม.** ที่ Authentication → Rate Limits ระหว่างเซสชันนี้ 🔴 **ต้องหรี่ก่อนขึ้น production**
4. `"Hook requires authorization token"` ที่ GoTrue โชว์ = แปลจาก **HTTP 401 ที่ฟังก์ชันส่งกลับเอง** (`catch` คืน 401 ทุก error) **ไม่ใช่ field ที่ขาดในหน้า config ของ Auth Hooks** (มีแค่ Endpoint/Secret) — อ่าน error จริงจาก `function_logs`/`function_edge_logs` เสมอ

**ยืนยันสำเร็จ end-to-end 2026-08-17:** สมัคร `mju6606105382@mju.ac.th` ผ่านแอปจริง → OTP ถึง `ADMIN_INBOX_EMAIL` → ยืนยันสำเร็จ → `"Profile"` ถูกสร้างถูกต้องครบ (`handle_new_user()` ทำงานปกติ — บั๊ก D-32 ของบัญชีนี้ไม่เกิดซ้ำ หลังลบบัญชีเก่าแล้วสมัครใหม่)

**หนี้ที่ยังไม่ปิด:**
- **Manual relay ไม่ scale** — ทุก OTP ต้องมีแอดมินคอยเปิดกล่องแล้ว relay ให้ student เอง เป็นทางออกช่วง prototype เท่านั้น ก่อน production ต้อง verify domain จริงที่ Resend แล้วเปลี่ยนให้ส่งตรงถึง student
- ค่า rate limit 30/ชม. เป็นค่าที่ปรับไว้ตอนดีบัก ยังไม่ได้ตัดสินใจค่าถาวรสำหรับ production
- `mju6606105386@mju.ac.th` ยังเป็นบัญชีทดสอบค้างจากก่อนแก้ (สมัครไม่สำเร็จ ไม่มี Profile) ยังไม่ลบ

## D-35 — แก้ `Mypost` filter `seller_id` (D-32 ข้อ 5) ด้วย widget-level query patch (2026-08-18)

**บริบท:** D-32 พบว่า `Mypost` ใช้ widget-level Backend Query บน `ListView_7h86cihf` ตรง ๆ (`ProductsReviewViewTable().queryRows(queryFn: (q) => q,)`) ไม่ใช่ page onLoad + state แบบหน้าอื่น (`Home`/`chatList`) — query ไม่มี filter เลย โชว์สินค้าทุกคนทุกสถานะ

**เลือก:** แก้ที่ตัว widget-level query เดิมโดยตรงผ่าน `page.mutateNode` เติม `FFPostgresFilter(seller_id EQUAL_TO SUPABASE_AUTH_USER/USER_ID)` เข้า `node.databaseRequest.postgres.filters` — ไม่ย้ายไปใช้ pattern onLoad+state (ของหน้าอื่น) เพราะ `itemBuilder` เดิมอ้างอิง item จาก generator variable ของ widget-level query อยู่แล้ว เปลี่ยนสถาปัตยกรรมจะกระทบมากกว่าจำเป็น

**ผลตรวจ `generated_code/lib/mypost/mypost_widget.dart` หลัง push:** `queryFn: (q) => q.eqOrNull('seller_id', currentUserUid)` — ตรงกับ pattern เดียวกับที่ `ProfileUser` ใช้กับ `id`

**ยังไม่ได้ทดสอบผ่านแอปจริง** (user ธรรมดา ต้องเห็นเฉพาะของตัวเอง) — รอคิวถัดไป

## D-36 — Category/Status filter chips: `Home` สำเร็จ, `Mypost` ติด platform limitation (2026-08-18)

**สิ่งที่ทำ:** เปลี่ยน ChoiceChips ทิ้งของ template เดิม (`ChoiceChips_9ld3fgia` บน `Home` มี option "For You"/"Sci-Fi"/ฯลฯ, `ChoiceChips_cgc572w2` บน `Mypost` มี "All"/"Owners"/"Editors"/"Viewers" — ไม่มี trigger action เลยทั้งคู่) เป็น `Row` ของ typed `Chip` widget (แต่ละอันคือ `FFChoiceChips` node ตัวเลือกเดียว ผูก `ON_TAP` จริง — ไม่มี typed DSL สำหรับแก้ multi-option ChoiceChips node ตัวเดิม จึงเปลี่ยนสถาปัตยกรรมเป็นหลายๆ chip แทน)

**`Home` (หมวดหมู่) — สำเร็จ:** 13 chip (ทั้งหมด + 12 หมวดจาก `"CAT"`) แต่ละอัน onTap = `SetState(selectedCategoryId)` + `PostgresQuery` (filter `moderation_status='approved'` + `category_id=N` ถ้าไม่ใช่ "ทั้งหมด") + `SetState(productsList, ActionOutput(...))` — เหมือน pattern onLoad เดิมทุกอย่าง ต่างแค่ trigger เป็น onTap แทน onLoad กับดักที่เจอ: ทุก chip ใช้ `outputAs: 'loadedProducts'` ชื่อเดียวกันหมด (รวมถึงชนกับของเดิมใน onLoad) → compileDslApp ฟ้อง "Action ... has an output variable with the same name as that of another widget" แก้โดยตั้ง `outputAs` ไม่ซ้ำต่อ chip (`loadedProductsCat<id>`) ยืนยันจาก `generated_code/lib/home/home_widget.dart` แล้วว่า query/SetState ผูกถูกต้องครบ 13 chip

**`Mypost` (สถานะ) — ติด platform limitation จริง ไม่ใช่เขียนโค้ดผิด:** ต้องการ filter `moderation_status` แบบ dynamic บน widget-level query ตัวเดิม (D-35) เหมือน `seller_id` แต่ผูกกับ state `selectedStatus` แทน AUTH_USER — **ลองแล้ว 5 รอบ ทุกรอบ push จริงผ่าน MCP `run` (ไม่ใช่แค่ validate):**
1. relation `LIKE` + ตัวแปร `LOCAL_STATE`/`WIDGET_CLASS_STATE` (ไม่มี `defaultValue`) → fail: `On ListView: One or more filters is invalid`
2. relation `LIKE` + ตัวแปรเดิม + เติม `defaultValue` ให้ตรงกับ default ของ state field → fail เหมือนเดิม
3. เปลี่ยน relation เป็น `CONTAINS` (ตัวเปรียบเทียบ substring ของ FlutterFlow เอง ไม่ใช่ SQL LIKE ตรงๆ) → fail เหมือนเดิม
4. สงสัยว่า key ของ state field ยังไม่นิ่งเพราะ `editPageState`+`app.raw` รันในสคริปต์เดียวกัน → push แยกให้ field มี key จริงจาก server ก่อน (`g9d3k5cm`) แล้วอ้างอิง key ที่นิ่งแล้วในสคริปต์ถัดไป → fail เหมือนเดิมทุกตัวอักษร — **ตัด "key ไม่นิ่ง" ออกจากสาเหตุที่เป็นไปได้**
5. **diagnostic:** เปลี่ยนเป็นค่า literal ล้วนๆ (`moderation_status = 'approved'`, ไม่มีตัวแปรเลย) → **push ผ่าน** ยืนยันว่าปัญหาไม่ใช่ "filter ตัวที่ 2 บน node นี้พังเสมอ" แต่เจาะจงที่ "filter ผูกกับตัวแปร (`FFVariableSource.LOCAL_STATE`) บน widget-level query" — filter diagnostic นี้ทำให้ `Mypost` โชว์เฉพาะ `approved` ชั่วคราวจริงบนโปรเดักชัน (ผิดเป้าหมายของ D-35) **ลบออกทันทีในก้อนถัดไป** (`removeWhere` unconditional) ยืนยันจาก `generated_code/` แล้วว่ากลับไปเหลือแค่ `seller_id` filter ตามเดิม

**สรุปสาเหตุที่น่าจะเป็น:** widget-level `databaseRequest.postgres.filters` (บน node ธรรมดา ไม่ใช่ page Scaffold) รองรับแค่ค่า literal หรือตัวแปรระบบบางชนิด (เช่น `SUPABASE_AUTH_USER` ที่ `seller_id` ใช้อยู่) — ไม่รองรับตัวแปร `LOCAL_STATE`/page state ทั่วไป ยังไม่ได้ลองว่า page-level `databaseRequest` (บน Scaffold โดยตรง แบบ `ProfileUser`/`HomeAdmin`) รองรับ `LOCAL_STATE` หรือไม่ — อาจเป็นข้อจำกัดเฉพาะ widget-level เท่านั้น

**สถานะตอนนี้:** chip สถานะทั้ง 4 อัน (`StatusChipAll`/`StatusChippending`/`StatusChipapproved`/`StatusChiprejected`) กด SetState `selectedStatus` ได้จริง (เห็นผลใน `generated_code/`) แต่**ยังไม่กรอง list จริง** — ต้องแก้ต่อด้วยแนวทางอื่น (ตัวเลือก: (a) ทำ conditional visibility ต่อแถวโดยอ่านค่าแถวผ่าน `generator variable` เทียบกับ `selectedStatus` แทนการกรองที่ query — ยังไม่ได้ลอง ต้องพิสูจน์ shape ของ `FFFunctionCall` แบบ 2-operand equality ก่อน (b) ย้ายสถาปัตยกรรม `Mypost` ทั้งหน้าไปใช้ pattern onLoad+state แบบ `Home` — งานใหญ่กว่าเพราะต้องสร้าง itemBuilder ใหม่ทั้งหมด)

## D-37 — Chip ทั้งคู่ใช้งานได้จริงแล้ว: สลับ `Chip`→`Button` (แก้ tap ค้าง) + ย้าย `Mypost` ไป onLoad+state (ปิด D-36) (2026-08-18)

**บั๊กจริงที่ pete เจอ:** กด chip แล้ว "ไม่มีอะไรเกิดขึ้นเลย" ทั้ง `Home` และ `Mypost` — ตรวจ `generated_code/lib/home/home_widget.dart` พบสาเหตุ: `UI.chip(...)` (ที่ D-36 ใช้สร้าง `Chip` widget) ห่อ `FlutterFlowChoiceChips` (แสดงผลเป็น Material `ChoiceChip`) ด้วย `InkWell(onTap:)` ของตัวเองอีกชั้น — แต่ `ChoiceChip` มี gesture handler ภายในตัวเอง (`onSelected`) สำหรับจัดการ selected state อยู่แล้ว สอง handler แย่ง gesture กัน ทำให้ `InkWell.onTap` (ที่ผูก action chain จริง) ไม่ทำงานเสถียร — เป็นบั๊กเลือกผิด widget ไม่ใช่ปัญหาสถาปัตยกรรม query/state

**แก้ (ทั้ง `Home`/`Mypost`):** เปลี่ยน `Chip` → `Button` (จัดสไตล์เป็นทรงเม็ดยาด้วย `borderRadius: 20`/`variant`) — `Button`'s onTap เป็น gesture handler เดียวบน node นั้น ไม่มีตัวไหนแย่ง ยืนยันจาก `generated_code/`: `FlutterFlowChoiceChips` เหลือ 0 จุดในทั้งสองไฟล์ เปลี่ยนเป็น `FFButtonWidget(onPressed:)` แทน

**`Mypost` — เลิกพยายามกรองที่ widget-level query แล้วย้ายทั้งหน้าไป onLoad+state (แบบ `Home`) แทน:** ลองอีก 2 รอบก่อนตัดสินใจย้าย — (1) `custom function` + conditional visibility ต่อแถว (`generatorVarField`+`accessDataStructField`) → fail: `Invalid value for argument rowStatus` (2) เปลี่ยนเป็น `accessPostgresRowField` (ถูกต้องกว่าสำหรับ Postgres row) → fail ข้อความเดิมทุกตัวอักษร — สรุปว่า GENERATOR_VARIABLE-sourced value ใช้เป็น custom function argument ไม่ได้ในโปรเจกต์นี้ (ไม่มี precedent อื่นในโปรเจกต์ที่ยืนยันวิธีนี้ใช้ได้เลย) จึง**เปลี่ยนแผนทั้งหมด**: rebuild `Mypost` ListView (`ListView_7h86cihf`, เดิมเป็น widget-level query ไม่ใช่ typed DSL) เป็น `ListView(source: State('myPostsList'), itemBuilder: ...)` ตัวจริง — onLoad ดึง `seller_id`-only ครั้งแรก แต่ละ status chip ยิง `PostgresQuery` (filter `seller_id` เสมอ + `moderation_status` ถ้าไม่ใช่ "ทั้งหมด") แล้ว `SetState(myPostsList, ...)` ใหม่ — กลไกเดียวกับ `Home`/`HomeAdmin`/`chatList` ที่พิสูจน์แล้วว่าใช้ได้จริง ไม่มี raw proto guessing เหลือเลย

**itemBuilder เดิมส่วนใหญ่เป็นของปลอมจาก template อยู่แล้ว** (ตรวจ `generated_code/` ก่อนรื้อ): มีแค่ `title` กับรูปแรกที่ผูกข้อมูลจริง ส่วน "randy@domainname.com"/"5 mins ago"/"Head of Design" เป็น static string ทั้งหมด — rebuild ใหม่ (title/price/status จริง, ไม่มีรูป — เหมือน `Home` AllList เอง) จึงไม่ได้เสียของจริงไปเลย

**กับดักที่เจอระหว่างแก้ (คุ้มบันทึกกันซ้ำ):**
- `outputAs` ต้อง unique ต่อ **จุดเรียก** ไม่ใช่แค่ต่อค่าที่ต่างกัน — onLoad กับ chip "ทั้งหมด" ทั้งคู่ filter เหมือนกัน (ไม่มี status) เลยได้ `outputAs` ชื่อเดียวกันโดยบังเอิญ ชนกันแบบเดียวกับที่ `Home` เจอตอน D-36 (ตอนนั้นชนเพราะ chip ทุกอันใช้ชื่อเดียวกันเลย) แก้ด้วยการเติม tag บอกจุดเรียก (`OnLoad`/`Chip`) ต่อท้าย `outputAs`
- 🔴 **ระหว่างรื้อไฟล์ใหญ่ (ตัดท้ายไฟล์ด้วย `head -n` แล้วต่อเนื้อหาใหม่) เกือบทำ section chip หมวดหมู่ของ `Home` หายไปทั้งหมดโดยไม่ตั้งใจ** — ตัดที่บรรทัดก่อนหน้า section ที่ต้องการรื้อจริง (`Mypost`) แต่ section `Home` อยู่ *หลัง* จุดตัดพอดี เลยหายไปด้วย จับได้จาก `generated_code/lib/home/home_widget.dart` ยังโชว์ `FlutterFlowChoiceChips` อยู่ทั้งที่เพิ่ง push "สำเร็จ" — บทเรียน: หลัง full-file rewrite ต้อง grep หา symbol ของทุก section ที่ควรอยู่ในไฟล์ ไม่ใช่แค่เชื่อ exit code ของ push

**ยืนยันผลจาก `generated_code/` หลัง push สุดท้าย:** `Home` — 13 `FFButtonWidget`, แต่ละอัน `onPressed` ยิง `PostgresQuery`+`SetState` จริง · `Mypost` — onLoad ดึง `seller_id`-only, 4 `FFButtonWidget` สถานะ แต่ละอัน `onPressed` ยิง `PostgresQuery(seller_id + moderation_status)`+`SetState(myPostsList)`, itemBuilder แสดง `title`/`price`/`moderationStatus` จริงจาก `_model.myPostsList` **ยังไม่ได้ทดสอบผ่านแอปจริงโดย pete**

## D-38 — `Home` AllList เปลี่ยนเป็น GridView 2 คอลัมน์ + เพิ่ม `first_image_url` (2026-08-18)

**บริบท:** pete อยากได้ layout แบบ e-commerce ทั่วไป (grid การ์ดสินค้า) แทนที่ list แถวเดียวเดิม — สโคปเฉพาะ `Home` (`AllList`) เท่านั้น ไม่แตะ `Mypost`

**ตัดสินใจ:** ใช้ typed DSL `GridView(source: State('productsList'), columns: 2, itemBuilder: ...)` แทน `ListView` ตัวเดิม (`ensureReplaced` บน `ListView_sxt9odnl`) — ไม่แตะกลไก filter เดิมเลย (onLoad query + 13 category chip `Button` ยังยิง `PostgresQuery`+`SetState('productsList', ...)` เหมือนเดิมทุกอย่าง เปลี่ยนแค่ widget ที่ render `productsList`)

**ปัญหารูปภาพ:** การ์ดต้องโชว์รูปสินค้าจริง แต่ `products_review_view.image_urls` เป็น array (`text[]`) — DSL ไม่มี list-index operator เลย (`item['field']` ทำได้แค่ named field access ตรงๆ ดู `src/dsl/references.dart`'s `DslExpression.operator[]`) เขียน `item['image_urls'][0]` ไม่ได้ **แก้ที่ SQL แทนที่จะพยายาม raw-proto/generator-variable trick** (บทเรียนจาก D-36/D-37 ที่เสียหลายรอบไปกับของคล้ายกัน) — เพิ่มคอลัมน์คำนวณ `image_urls[1] AS first_image_url` เข้า `products_review_view` (`CREATE OR REPLACE VIEW` — ต้องวางคอลัมน์ใหม่ **ท้ายสุด** ของ SELECT ไม่งั้น Postgres ฟ้อง `cannot change name of view column` เพราะนับตำแหน่งคอลัมน์เดิม) เป็น NULL ถ้าไม่มีรูป (ยอมรับ broken-image state ชั่วคราว ยังไม่มี placeholder asset)

**กับดักที่เจอ (คุ้มบันทึกกันซ้ำ):**
- **field ที่เพิ่งลง `postgres_helpers.addTableField` ในพุชเดียวกัน ใช้ `item['fieldname']` อ้างอิงในพุชเดียวกันไม่ได้** — fail `Bad state: Field "products_review_view.first_image_url" was not compiled.` (คนละอาการกับปัญหา LOCAL_STATE ของ D-36 แต่หลักการเดียวกัน: field/table ที่เพิ่งลงทะเบียนสดในสคริปต์เดียวกันยังใช้งานผ่าน typed field access ไม่ได้ทันที) **ต้องแยกพุช**: พุชแรกลงทะเบียน field อย่างเดียว ยืนยันจาก `lib/flutterflow_project/schemas.dart` ว่าขึ้นจริง แล้วค่อยพุชที่สองที่ใช้ `item['first_image_url']` — ตรงกับ pattern ที่ `admin_sales_by_seller` เคยบันทึกไว้แล้ว (คอมเมนต์ใน `dsl/edit.dart`)
- ระหว่างแก้ `banned_users`'s guarded-add block เพื่อแทรกโค้ดใหม่ต่อท้าย เกือบพิมพ์ `postgresType: 'int8'` เป็น `'text'` โดยไม่ตั้งใจ (copy-paste แล้วแก้ไม่ครบ) — จับได้จากอ่านทวนโค้ดก่อน push ไม่ได้เจอจาก error ของ compiler เพราะ `postgresType` เป็นแค่ string metadata ไม่ validate

**ยืนยันผลจาก `generated_code/lib/home/home_widget.dart`:** `GridView.builder` + `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.68)` + `shrinkWrap: true` (codegen ใส่ให้อัตโนมัติ ไม่ต้องระบุเอง — DSL's `GridView` ไม่มี param `shrinkWrap` เลย) + `productsListItemItem.firstImageUrl` ผูกกับ `Image.network` จริง ปุ่มหมวดหมู่/onTap→ProductDetails ไม่กระทบ

**`ensureReplaced` retire แล้ว** ตาม PT-16/21 — ทดสอบด้วย `flutterflow ai validate` หลังลบออกจากสคริปต์แล้วผ่านสะอาด (ไม่มีอาการ PT-19 แบบ `PendingProductsList`) จึงไม่ต้องเก็บไว้ถาวร

**ยังไม่ได้ทดสอบผ่านแอปจริงโดย pete** — โดยเฉพาะเคส "สินค้าไม่มีรูป" ว่า broken-image state จะรบกวนผู้ใช้แค่ไหน

## D-39 — Filter chip highlight ตามการเลือกจริงแล้ว (2026-08-18)

**บั๊กที่ pete เจอหลังทดสอบ D-37:** filter ทำงานถูกต้อง (list กรองจริง) แต่สี highlight ของ chip ที่กดไม่เปลี่ยนตาม — เพราะ `Button.color`/`textColor` เป็น `ColorToken` แบบ static ล้วน (กำหนดตอน author สคริปต์ ไม่ผูกกับ state) ทุก chip เลยค้างสไตล์เดิมตลอดไม่ว่าจะกดอันไหน

**แก้:** แต่ละ filter option render เป็น **คู่ Button** (สไตล์ selected + สไตล์ unselected) ซ้อนตำแหน่งเดียวกัน สลับด้วย `visible:` (typed DSL param มาตรฐาน คอมไพล์เป็น node-level conditional visibility จริง — `_applyVisibility`/`setConditionalVisibility` ใน compiler — กลไกเดียวกับที่ `ProfileUser`'s avatar/name fallback ใช้อยู่แล้ว) เทียบด้วย `Equals(State(...), value)`/`Not(...)` (typed comparison expression ที่ใช้อยู่แล้วใน `If(...)` action condition ของไฟล์นี้) — **ไม่มี raw proto เลย** ต่างจาก D-36 ที่เสียหลายรอบไปกับของทำนองนี้

**กับดักที่เจอ:** ทั้งสองปุ่มในคู่เดียวกัน (selected/unselected) เป็น **widget คนละตัว** ที่ compile จริงทั้งคู่ (แค่โชว์แค่อันเดียวตาม `visible:`) — ถ้าใช้ `onTap` list เดียวกันซ้ำสองครั้ง `PostgresQuery`'s `outputAs` จะชนกัน (`Action ... has an output variable with the same name as that of another widget`) แก้โดยเปลี่ยน `onTap` param เป็น `onTapBuilder(variantTag)` เรียกแยกต่อปุ่ม ('Selected'/'Unselected' ต่อท้าย `outputAs`)

**ยืนยันจาก `generated_code/`:** `Home` — `if (_model.selectedCategoryId == N) Button(...)` / `if (!(_model.selectedCategoryId == N)) Button(...)` ครบ 13 คู่ · `Mypost` — `if (_model.selectedStatus == '...')` ครบ 4 คู่ — เป็น conditional list element จริง (`if (...) Widget()`) ไม่ใช่ `Visibility`/`Opacity` ที่จองพื้นที่ไว้ ดังนั้นไม่มีช่องว่างหลอนตอนสลับ

## D-40 — `chatList` ว่างเปล่าจริง: layout crash ไม่ใช่บั๊ก RLS/data (2026-08-18)

**pete รายงาน:** เปิด `chatList` แล้วว่างเปล่า เห็นแค่หัวข้อ "My Messages" ไม่มีห้องแชทโผล่เลย แนบ console log มาด้วย: `Assertion failed: .../rendering/box.dart:2251` ซ้ำ ๆ (48 issues)

**ตรวจ 3 ชั้นตามกฎข้อ 9 ก่อนแก้:**
1. **Supabase** — ให้ `db-verifier` ทดสอบ `chat_summary` แบบ impersonate บัญชีที่มีห้องแชทจริง (`mju6512345678@mju.ac.th`) → **คืนแถวถูกต้องครบ ไม่มี error** RLS/`is_chat_member()`/view definition ตรงกับ `SCHEMA.md` ทุกจุด ไม่มี drift ตั้งแต่ D-29
2. **Widget tree + binding** — `chatList`'s onLoad (`PostgresQuery(chatSummary)` + `SetState('myChats', ...)`) และ `ChatListItems`'s generator variable ผูกกับ `State('myChats')` ถูกต้องทุกจุด ตรงกับ pattern เดียวกับ `Home`/`HomeAdmin` ที่ใช้งานได้จริง
3. **สรุป:** ไม่ใช่บั๊ก data/RLS เลย — เป็น **layout crash** ที่ทำให้พื้นที่ list เรนเดอร์อะไรไม่ได้เลย ไม่ว่าจะมีข้อมูลกี่แถว

**root cause จริง:** `ChatListItems` (`ListView.builder`) เป็นลูกตรงของ page body's `Column` (คู่กับ subtitle Text "Below are messages with your friends." ด้านบน) โดย**ไม่ได้ห่อด้วย `Expanded`** และ `shrinkWrap` ไม่ได้ตั้งไว้ (default `false`) — คอมเมนต์เก่าในสคริปต์เข้าใจผิดว่ามันถูกห่อด้วย `Expanded` อยู่แล้ว ("ChatListSection (Expanded > ListView...)") แต่ `inspect` สดยืนยันว่าไม่ใช่ `Column` ให้ child ที่ไม่ใช่ `Expanded` เป็น unbounded height เสมอ → `ListView` ไม่มี `shrinkWrap` โดนความสูงไม่จำกัด throw assertion ทุกรอบ layout พอดีกับ `box.dart:2251` ที่เห็นในภาพ

**แก้:** ตั้ง `shrinkWrap: true` ตรง ๆ (ไม่มี typed DSL หรือ fast-lane op ครอบคลุม `shrinkWrap` บน node ที่มีอยู่แล้ว ต้อง raw proto: `node.props.listView.shrinkWrapValue = FFBooleanValue(inputValue: true)`) — pattern เดียวกับที่ `Home`/`Mypost`/`HomeAdmin`'s list ทุกตัวใช้อยู่แล้วเป็นปกติ (`ChatListItems` เป็นตัวเดียวที่หลุด)

**ตรวจสอบเพิ่ม (กันเจอซ้ำ):** เช็ค `Notifications`/`ReportsFeedback` (list ที่สร้างช่วงเดียวกับ D-31) ด้วย — โครงสร้างต่างกัน (`ListView` เป็นลูกตรงของ `SafeArea` ไม่มี sibling Text ไม่ต้องมี `Column` คั่น) จึง**ไม่มีบั๊กนี้**

**ยืนยันจาก `generated_code/lib/chat_list/chat_list_widget.dart`:** `shrinkWrap: true` ปรากฏจริงบน `ListView.builder` แล้ว **ยังไม่ได้ให้ pete ทดสอบซ้ำผ่านแอปจริงว่าห้องแชทขึ้นแล้ว**

**ยังไม่ได้ทดสอบผ่านแอปจริงโดย pete**

## D-41 — `chatMessages`: bubble UI สองฝั่ง + ส่งรูปได้จริง (2026-08-18)

**ทำ:** เปลี่ยน `ChatMessageItems` จาก list คอลัมน์เดียว (sender label/ข้อความ/divider) เป็น bubble สองฝั่ง (ของตัวเอง = ขวา สีธีม primary, ของคนอื่น = ซ้าย สีเทา + ชื่อผู้ส่ง) และเพิ่มปุ่มแนบรูป (`AttachImageButton`) อัปโหลดเข้า bucket `chat-images` ที่มีอยู่แล้ว (D-29) แล้ว insert `chat_message.image_url`

**บั๊กที่เจอระหว่างทำ + วิธีแก้ (4 รอบ ทดสอบผ่านแอปจริงโดย pete ทุกรอบ):**

1. **`Equals(item['field'], '')` เทียบ null ผิด — ทำให้ `messageItem.message!` crash จริง ("Unexpected null value")** — เข้าใจผิดว่า PT-12 §11 ("nullable Postgres text column map เป็น `String` ไม่ใช่ `String?` ใช้ `''` แทน null") ใช้ได้กับทุกที่ ที่จริงใช้ได้แค่กับ binding path บางแบบ **ไม่ใช่กับ Supabase table/view row model** (`ChatMessagesViewRow.message` เป็น genuine `String?` จาก `getField<String>('message')` จริง ยืนยันจากไฟล์ table model) เทียบ `null == ''` ได้ `false` การ์ดเลยเปิดผ่านทั้งที่ยังเป็น null จริง **แก้ที่ SQL แทนที่จะเดา Dart nullability**: เพิ่ม `has_message`/`has_image` (boolean, `IS NOT NULL`) เข้า `chat_messages_view` ใช้เป็น `visible:` ตรง ๆ — ดู `SCHEMA.md`
2. **field ที่เพิ่งลง `postgres_helpers.addTableField` ใช้ใน `item['field']` ของพุชเดียวกันไม่ได้** (`Bad state: Field "chat_messages_view.has_message" was not compiled.`) — ซ้ำกับกับดักเดียวกันที่ D-38 เจอกับ `first_image_url` ยืนยันว่าเป็นกฎทั่วไป ไม่ใช่กรณีเฉพาะ `products_review_view` ต้องแยกพุชเสมอ
3. **`ListView` ไม่มี `Expanded` ห่อ ทำให้ ComposeBar ลอยกลางจอแทนที่จะติดขอบล่าง** — คนละเคสกับ D-40 (`chatList` ไม่มี `Expanded` โดยตั้งใจ ต้องใช้ `shrinkWrap: true`) แต่ `chatMessages` **ต้องการ** ให้ list ขยายเต็มพื้นที่ระหว่าง AppBar กับ ComposeBar จึงต้องห่อ `Expanded` แทน ไม่ใช่ `shrinkWrap` — สองกลไกแก้คนละปัญหา อย่าใช้ตัวเดียวกับทุกที่
4. **`PostgresCreate` สอง widget บนหน้าเดียวกัน (ปุ่มส่งข้อความ vs ปุ่มส่งรูป) ชนกันที่ `outputAs` default (`'rows'`)** — ขยายกฎเดิมจาก D-37 (`outputAs` ต้อง unique ต่อจุดเรียก): ไม่ใช่แค่ chip/loop ซ้ำกัน แต่ **widget คนละตัวบนหน้าเดียวกัน** ก็ชนกันได้ถ้าไม่ตั้ง `outputAs` เอง

**ปุ่มดูรูปเต็ม:** ใช้ **แตะ** ไม่ใช่กดค้าง — DSL ไม่มี `onLongPress` เป็น widget property เลยสักตัว (มีแค่ `onTap`) เปิด dialog ผ่าน component ใหม่ `FullImageViewer` (`ShowDialog.component`, ส่ง `imageUrl` จาก `item['image_url']` ในสโคป itemBuilder เดิม ไม่ผ่าน `ensureActions` ภายหลังเพราะ item-scope ใช้นอก itemBuilder สดไม่ได้ ดู PT-23 §1)

**ยืนยันจาก `generated_code/`:** bubble ซ้าย/ขวาถูกฝั่ง, `if (messageItem.hasMessage ?? true)`/`hasImage` แทน `== ''`, `Expanded(flex: 1, child: ...ListView...)`, `uploadSupabaseStorageFiles(bucketName: 'chat-images', ...)`, `FullImageViewerWidget(imageUrl: messageItem.imageUrl)` — **ทดสอบผ่านแอปจริงโดย pete แล้วทั้งหมด (bubble/ส่งรูป/ComposeBar ติดขอบล่าง/ดูรูปเต็ม)**

รายละเอียด pattern ใหม่ → `PATTERNS.md` **PT-24**

## D-42 — `ProductDetails` ไม่เคยโชว์รูปสินค้าเลย: static placeholder icon ไม่ใช่ Image widget (2026-08-19)

**pete รายงาน:** เปิด `ProductDetails` แล้วรูปสินค้าไม่ขึ้น ไม่ว่าสินค้าไหน

**ตรวจ 3 ชั้นตามกฎข้อ 9:** widget tree (`lib/flutterflow_project/pages/product_details.dart`) + `generated_code/lib/product_details/product_details_widget.dart` ยืนยันตรงกัน — `Container_g5bpqqbn` (ช่องรูป สูง 220) มีลูกเป็น `Icon(Icons.image)` **คงที่** เท่านั้น ไม่มี `Image`/`CachedNetworkImage` widget อยู่บนหน้านี้เลยสักจุด เป็นซากจาก template doctor-booking เดิมที่ `ensureReplaced` ตัวที่สร้างหน้านี้ (retired แล้ว, ดู D-27) ไม่เคยเปลี่ยนเป็นรูปจริง ไม่ใช่บั๊ก data/RLS — `products_review_view` มี `image_urls`/`first_image_url` (D-38) พร้อมใช้อยู่แล้ว

**แก้:** เพิ่ม `has_image` (boolean, `image_urls IS NOT NULL AND array_length(...) > 0`) เข้า `products_review_view` แล้ว rebuild `ProductDetailsContent` (`ListView_26isq2qt`) ทั้ง itemBuilder ใหม่ผ่าน `ensureReplaced` (จำเป็นต้อง rebuild ทั้งก้อน ไม่ใช่ patch เฉพาะ `Container_g5bpqqbn` เพราะ `ItemRef()`/`item[]` ใช้นอก itemBuilder สดไม่ได้ ตาม PT-23 §1/D-41) คัดลอกทุก field เดิม (title/price/condition/category/description/seller/phone) มาจาก `generated_code` เป๊ะ เปลี่ยนแค่ช่องรูป: `Image(item['first_image_url'], fit: cover)` โชว์เมื่อ `has_image`, `Icon('image')` โชว์เมื่อ `!has_image` (คู่ `visible:`/`Not(...)` แบบเดียวกับ D-39) — **ตั้งใจไม่เดินตาม Home's `first_image_url!` (force-unwrap ตรง ๆ ไม่มี fallback, D-38) เพราะจะ crash จริงถ้าสินค้าไม่มีรูป (เคสนี้ Home เองก็ยังไม่เคยทดสอบ ดู STATUS.md คิว 6)** — ทำให้ `ProductDetails` ปลอดภัยกว่า `Home` ในจุดนี้แล้ว ยังไม่ได้ย้อนไปแก้ `Home` ให้เหมือนกัน (แยกงาน)

**แยก 2 พุชตาม PT-17 §1/PT-24 §2:** พุชแรกลงทะเบียน `has_image` อย่างเดียว ยืนยันจาก `lib/flutterflow_project/schemas.dart` (`ProductsReviewViewFields.hasImage`) ก่อน แล้วพุชที่สองค่อยใช้ `item['has_image']` ใน `ensureReplaced`

**กับดักที่เจอ:** DSL ไม่มี `Icons.xxx` (ใช้ `Icon('image', ...)`/`Icon('call', ...)` เป็น string name แทน) และไม่มี `Padding` เป็น widget แยก (`Container`'s `padding:` param ทำหน้าที่แทน) — สองอันนี้ compile error ทันทีตอน validate ไม่ใช่ runtime bug

**ยืนยันจาก `generated_code/lib/product_details/product_details_widget.dart`:** `if (productRowItem.hasImage ?? true) CachedNetworkImage(imageUrl: productRowItem.firstImageUrl!, ...)` / `if (!productRowItem.hasImage!) Icon(Icons.image, ...)` ครบ ทุก field อื่น (title/price/condition/categoryName/description/sellerName/contactPhone) ยังผูกถูกเหมือนเดิมทุกจุด — **ยังไม่ได้ให้ pete ทดสอบผ่านแอปจริง**

## D-43 — multi-photo carousel + tap-to-view บน `ProductDetails`: ทำไม่สำเร็จ พบขีดจำกัดจริงของ SDK 3 ข้อ (2026-08-19)

**pete ขอ:** ถ้าประกาศมีรูปมากกว่า 1 ให้ทำ carousel เลื่อนดูรูปที่เหลือ + แตะรูปแล้วเปิด popup ดูรูปเต็ม

**เตรียมฝั่ง Supabase สำเร็จ:** เพิ่ม `second_image_url`/`third_image_url`/`has_second_image`/`has_third_image` เข้า `products_review_view` (pattern เดียวกับ `first_image_url`/`has_image`, D-38/D-42) — `image_urls` จำกัดที่ 3 รูปอยู่แล้ว (L2 CHECK) จึงใช้ named column แทนการวน array (DSL ไม่มี list-index/iterate operator, D-38)

**ฝั่ง FlutterFlow ทำไม่สำเร็จ — พบขีดจำกัดจริง 3 ข้อ จากการทดสอบแยกทีละตัวแปรกว่า 20 พุช (ทุกข้อ isolate แล้วจริง ไม่ใช่เดา):**

1. **`item['field']` ส่งเป็น param/value ของ action ไม่ได้เลย** ไม่ว่า action ไหน (`Navigate`, `ShowDialog.component`, `ShowBottomSheet`, `SetState`) แม้โครงสร้างจะเหมือนโค้ดที่ใช้งานได้จริงอยู่แล้วเป๊ะ (`MyPostsList`'s `onTap: Navigate(ff.Pages.productDetails, params: {'productId': item['id']})`) — error เดิมทุกครั้ง: `Parameter X ... not properly set` + `Generator variable does not exist` ลามไปทุก node ที่เหลือใน itemBuilder เดียวกัน (แม้ node ที่ไม่เกี่ยวกับรูปเลยก็โดน) จุดนี้ทำให้ **tap-to-view-full-image ทำไม่ได้เลยในหน้านี้** ด้วยกลไกใดๆ ที่ลองมา
2. **`item[]` ผ่าน Dart helper function ไม่ได้** — ฟังก์ชันแบบ `Container photoSlot(DslExpression url, ...) => Container(...)` เรียกด้วย `photoSlot(item['x'], ...)` จาก itemBuilder พังทันทีแม้ไม่มี action เลย (แค่ property ธรรมดา) ต้อง inline ทุกอย่างตรงจุดเรียกเท่านั้น — ขยาย PT-23 §1 ให้ครอบคลุมมากกว่าแค่ ensureInsertedAfter/action
3. **🔴 ตัวบล็อกจริง: มี `Image` widget ที่ผูกกับ `item[]` ได้แค่ 1 ตัวต่อ itemBuilder** — ลองใส่ `Image` ตัวที่ 2 (คนละ field/field เดียวกันก็ได้) ทั้งในและนอก `Row`, มี/ไม่มี `visible:`, ตั้ง `name:` ไม่ซ้ำแล้วก็ยังพัง error เดิมทุกครั้ง ไม่พบวิธีแก้ในขอบเขต itemBuilder เดียวกันเลย

**เช็คแล้ว (pete ถาม): DSL's native `Carousel` widget ก็ใช้ไม่ได้เหมือนกัน** — ทดสอบตรงๆ (`Carousel(children: [Image(item['first_image_url'], ...), Image(item['second_image_url'], ...)])` ในตำแหน่งเดิม) ได้ error เดียวกับ `PageView` เป๊ะ: `"Carousel widget with the current configuration will not function properly when generated dynamically ... because it is associated with a local state variable ... wrap it inside of a component"` — `Carousel`/`PageView` เป็น controller-based widget ทั้งคู่ (`viewportFraction`/`infiniteScroll`/`autoPlay` ยืนยันว่ามี `CarouselController` ข้างใน) เจอขีดจำกัดเดียวกันแน่นอน ไม่ใช่แค่เดา — "wrap in component" ที่ error แนะนำก็ตันอยู่ดีที่ข้อ 1 (component instantiation param ก็รับ `item[]` ไม่ได้เหมือนกัน, ลองแล้วตอนพยายามทำ `ProductImageGallery`)

**ผลลัพธ์ที่ push จริง:** เก็บแค่รูปเดียว (hero image, `first_image_url`/`has_image`) จาก D-42 ไว้เหมือนเดิม ไม่มี carousel ไม่มี tap-to-view — คอลัมน์ `second_image_url`/`third_image_url`/`has_second/has_third_image` ที่เตรียมไว้ยังอยู่ใน view เฉยๆ ยังไม่ได้ใช้

**ถ้าจะกลับมาทำต่อ:** ต้องเลี่ยง item-scope-in-list ทั้งหมด — แนวทางที่น่าจะได้ผล: bind รูปที่ 2/3 + ค่าที่ actions ต้องใช้ผ่าน **scaffold-level `databaseRequest` + `nodeKeyRef`** (raw proto, เทคนิคเดียวกับ `ProfileUser`/PT-14 — เป็น scalar field access จริง ไม่ใช่ list/generator variable) แทนการเพิ่ม `Image`/action ตัวที่ 2 เข้าไปใน `ListView`'s itemBuilder

รายละเอียด pattern ใหม่ → `PATTERNS.md` **PT-25**

## D-44 — `ProductDetails` โชว์รูปที่ 2/3 สำเร็จแล้ว: เลี่ยง `ListView`/`item[]` ทั้งหมดด้วย scaffold-level query (2026-08-19)

**ทำตาม D-43's แนวทางที่แนะไว้:** bind รูป 2/3 ผ่าน scaffold-level `databaseRequest` + `nodeKeyRef` (เทคนิคเดียวกับ `ProfileUser`/`HomeAdmin`, PT-14) แทนที่จะพยายามยัดเข้า `ListView`'s itemBuilder เดิม — ไม่แตะ `ListView_k8hk1168` (hero image + text ทั้งหมด) เลย, เป็น query คนละตัว แยกอิสระ

**สเปคที่ pete ยืนยัน:** ไม่ใช้ `Carousel`/`PageView` (กัน SDK state conflict ตามที่เจอใน D-43) ใช้รูปที่ 2/3 วางเคียงกันใน `Row(scrollable: true)` แทน (เลื่อนดูได้แบบ SingleChildScrollView ธรรมดา ไม่มี controller) — container ทั้งกลุ่มกับรูปทั้งสองใช้เงื่อนไข visibility เดียวกัน (`has_second_image`) ไม่ทำ OR สองเงื่อนไขในเวอร์ชันแรก

**2 พุช:**
1. **Push 1** — `page.ensureInsertedAfter(ListView_k8hk1168, Container('ProductPhotoGalleryContainer', ...))` แทรก node ใหม่ (Container > Column > [Text label, Row(scrollable:true) > [Image 'SecondProductImage', Image 'ThirdProductImage']]) + ผูก `productDetailsPage.node.databaseRequest` (raw proto, `app.raw`) กรอง `id = productId` (page param) ผ่าน `FFVariableSource.WIDGET_CLASS_PARAMETER`/`FFWidgetClassVariable` (ยืนยันตรงกับ SDK's เอง `varFromPageParam` helper ใน `variable_helpers.dart:31-36` เป๊ะ) `isSingleRow: true, hideOnEmpty: true`
2. **Push 2** — bind ค่าจริงผ่าน `nodeKeyRef: FFNodeKeyReference(key: 'Scaffold_amt0m1za')` (ต้องตรงกับ node ที่ตั้ง `databaseRequest` ไว้): `node.props.image.pathValue = FFStringValue(variable: productField('second_image_url'))` + `node.props.ensureVisibility().visibleValue = FFBooleanValue(variable: productField('has_second_image'))` ต่อรูป และ container เอง — pattern ตรงกับ `ProfileUser`'s `profileField`/`setVisibility` และ `HomeAdmin`'s `statsField`/`bindText` เป๊ะ

**🔴 กับดักใหม่ที่เจอระหว่างทำ (Push 1):** `visible: false` แบบ literal bool (static, ไม่ผูก variable) **ไม่ทำให้ widget หายจริงในโค้ดที่ export ออกมา** — Container/รูปทั้งสองโชว์ออกมาแบบไม่มีเงื่อนไข `if (...)` ห่อเลย (เห็นกล่องรูปว่างเปล่า `imageUrl: ''` โผล่บนแอปจริงช่วงสั้นๆ ระหว่าง Push 1→2) ตรวจ compiler source แล้วพบสาเหตุ: `visible: <literal bool>` compile ผ่าน `setVisibility()` (`FFBooleanValue(inputValue: ...)`) ซึ่งเป็นคนละ path จาก `setConditionalVisibility()` (`FFBooleanValue(variable: ...)`) ที่ `has_image` ใช้อยู่แล้วและได้ `if (...)` จริง — งานนี้ยังไม่รู้ว่า static `visible:false` ควรจะ render เป็นอะไร (`Visibility`/`Opacity` widget?) ที่ codegen export ไม่แสดงให้เห็น หรือเป็นบั๊กจริงของ codegen export path นี้ **ทางแก้ที่ใช้จริง:** อย่าพึ่ง static `visible:` เป็นตัวซ่อนชั่วคราวระหว่างรอพุชถัดไป — รีบทำพุชที่ผูก conditional visibility จริง (`variable:`-based) ทันทีแทน ไม่ต้องดีบัก static-literal path ต่อ

**ยืนยันจาก `generated_code/lib/product_details/product_details_widget.dart`:** `if (productDetailsProductsReviewViewRow?.hasSecondImage ?? true) Container(...)`, รูปทั้งสองมี `if (...hasSecondImage/hasThirdImage ?? true)` ห่อจริง ผูก `.secondImageUrl!`/`.thirdImageUrl!` จริง, `FutureBuilder<List<ProductsReviewViewRow>>` ห่อทั้งหน้าจริงตามที่คาด (ยอมรับความเสี่ยงนี้แล้วตาม D-43's plan) เนื้อหาเดิม (hero/title/price/description/seller/phone) ไม่กระทบเลย — **ทดสอบผ่านแอปจริงโดย pete แล้ว — ผ่าน** (`products.id = 930b4539-396a-48b1-bc35-8462d0301a89`)

รายละเอียด pattern ใหม่ (static vs conditional visibility) → `PATTERNS.md` **PT-26**

## D-45 — `Home`: ค้นหา + สุ่มลำดับสินค้า + pull-to-refresh (2026-08-19)

**pete ขอ:** ยังไม่มีระบบค้นหาประกาศเลย และอยากให้ `Home` โชว์สินค้าแบบสุ่ม (ไม่เรียงใหม่สุดเสมอ) + pull-to-refresh สุ่มใหม่ — ไม่ใช่ recommendation algorithm จริง แค่สุ่ม + มีช่องค้นหาช่วย

**ตัดสินใจตั้งต้น (ก่อนเจอกับดัก):** สุ่มฝั่ง Dart (custom function shuffle หลัง query) ไม่แตะ schema, ค้นหาใช้ built-in filter ไม่สร้าง RPC `search_products` (P-05 ยังไม่ build) — เปลี่ยนใจเรื่องสุ่มระหว่างทำ ดูกับดักข้อ 1

**🔴 กับดักที่ 1 — client-side shuffle ทำไม่ได้จริง:** `SetState('productsList', CustomFunction(shuffleProducts, ...))` compile ผ่านทุกครั้ง (`shuffleProducts` คืน `listOf(ff.Tables.productsReviewView)` ตรง type) แต่ **push แล้ว validate fail เสมอ**: `Field "productsList" has an update value that is not properly set in Update App State action` — เกิดกับทุก widget ที่ตั้ง `productsList` พร้อมกัน (26 chip + onLoad + search) ยืนยันสาเหตุด้วยการถอด `CustomFunction(...)` wrap ออกแล้ว push สะอาดทันที **สรุป:** field ที่เป็น `List<PostgresRow>` (ผูกกับ table/view จริง) รับค่าจาก `SetState` ได้เฉพาะที่มาจาก `PostgresQuery`'s `ActionOutput` (source `POSTGRES_QUERY`) เท่านั้น — ค่าจาก custom function (source `FUNCTION_CALL`) แม้ type ตรงกันก็ไม่ผ่าน ไม่มีตัวอย่างที่ใช้งานได้ในโปรเจกต์นี้หรือ `references/` เลยสักจุดที่ป้อน list เข้า state field แบบนี้ — เป็นข้อจำกัดจริงของ backend ไม่ใช่ syntax ผิด

**ทางแก้ที่ใช้จริง:** ย้ายการสุ่มไปที่ SQL แทน — เพิ่มคอลัมน์ `products_review_view.shuffle_key = random()` (view ไม่ materialize จึงสุ่มใหม่ทุกครั้งที่ query จริง) แล้วสั่ง `orderBys: [PostgresOrderBy('shuffle_key')]` แทน `created_at` — ใช้กลไก `PostgresQuery`+`SetState(ActionOutput(...))` เดิมทุกจุด ไม่ต้อง custom function เลย ถอด `shuffleProducts` ออกจากสคริปต์ทั้งหมด

**🔴 กับดักที่ 2 — เปลี่ยนแค่ `orderBys` โดยใช้ `outputAs` เดิม push แล้วไม่มีผลอะไรเลย:** push ครั้งแรกที่เปลี่ยน `created_at` → `shuffle_key` compile ผ่าน, push สำเร็จ, `codegen status` บอก fresh — แต่ `generated_code/lib/home/home_widget.dart` ยังเป็น `.order('created_at')` เป๊ะทุกจุด (onLoad, search, 26 chip) ทั้งที่ field compile ผ่านจริง (ถ้า field ไม่ผ่านจะ throw `StateError` ตอน compile ไม่ใช่เงียบ) ทดสอบแยก: เปลี่ยน `outputAs` ของ onLoad จาก `loadedProducts` → `loadedProductsShuffled` (ไม่แตะอะไรอื่น) push อีกที **แก้ปัญหาทันที** — สรุป: `ensureActions`/`editPageOnLoad` **ไม่ re-emit โค้ดของ trigger ถ้า `outputAs` เดิมซ้ำกับที่เคย push ไปแล้ว แม้ payload อื่นเปลี่ยน** (`orderBys` ในที่นี้) เป็นกับดักคนละแบบกับ PT-15 §3 (ascending flag หาย) — อันนี้ field เปลี่ยนก็ไม่ขึ้นเลยถ้า `outputAs` ไม่เปลี่ยนตาม **ต้องเปลี่ยน `outputAs` ทุกครั้งที่แก้ orderBys ของ trigger ที่เคย push มาก่อนแล้ว**

**🔴 กับดักที่ 3 — ปล่อย `ensureReplaced` ของช่องค้นหาไว้ active ตาม PT-16/D-27 ที่เตือนไว้แล้วจริง:** ลืม retire `ensureReplaced(TextField_cjz7pmp6, TextField(name:'SearchField', ...))` หลังจาก push แรกที่มันสำเร็จ พอ push รอบถัดไป (แก้ `outputAs` เพื่อกับดักที่ 2) เจอ error ใหม่เฉพาะ `SearchField` (`searchQuery`/`productsList` update value ไม่ถูกต้อง) — แก้ด้วยการ retire `ensureReplaced` แล้วเปลี่ยนไปผูก `onChanged`/`onSubmitted` ผ่าน `page.ensureActions(key, triggerType: ON_TEXTFIELD_CHANGE/ON_TEXTFIELD_SUBMIT, ...)` แทน (`TextField.onChanged`/`onSubmitted` compile เป็น trigger จริงตาม `compiler.dart`'s `_attachActions`, ปลอดภัยกว่าเพราะ rerun ซ้ำได้ ต่างจาก `ensureReplaced`)

**สถาปัตยกรรมที่ใช้จริง:** ค้นหา (title `iLike`) กับหมวดหมู่ (category chip) เป็นคนละแกน คนละ query ไม่รวมกัน — กดค้นหารีเซ็ต `selectedCategoryId=0`, กด chip ล้าง `searchQuery=''` — chain เดียว (`buildSearchRefreshChain`) ใช้ซ้ำทั้ง search-submit และ pull-to-refresh (เพราะ `iLike('title','')` แมตช์ทุกแถว การ refresh ระหว่างค้นหาอยู่จึงยัง scope ตามคำค้นเดิมให้ถูก)

**🟡 ข้อจำกัดที่ยังไม่ปิด — ค้นหาแบบ exact match เท่านั้น ไม่ใช่ substring:** `PostgresFilterRelation.iLike` compile เป็น `.ilike('title', _model.searchQuery)` ตรง ๆ **ไม่มี `%...%` ห่อให้** (ยืนยันจาก generated code) DSL ไม่มี string-concat/interpolation expression ที่ใช้กับ `PostgresFilter.value` ได้ (`interpolateVar(...)` มีอยู่แต่คืน raw `FFStringValue` ที่ `normalizeExpression` ปฏิเสธ) พิมพ์คำค้นที่ไม่ตรงชื่อเป๊ะ (case-insensitive) จะไม่เจอผลเลย — ทางแก้ที่เหลือ: raw-proto surgery ผ่าน `page.mutateNode` เจาะเข้าไปแก้ `FFPostgresFilter.value` ตรง ๆ (ยังไม่ทำ) หรือย้อนกลับไปทำ RPC `search_products` (P-05) ผ่าน custom action

**ยืนยันจาก `generated_code/lib/home/home_widget.dart`:** `RefreshIndicator` ครอบ grid จริง, `.order('shuffle_key', ascending: true)` ทุกจุด (onLoad/search/26 chip), `.ilike('title', _model.searchQuery)`, 26 `FFButtonWidget` ยังอยู่ครบ (เช็คกัน D-37's near-miss) — **ยังไม่ได้ให้ pete ทดสอบผ่านแอปจริง**

รายละเอียด pattern ใหม่ (outputAs ต้องเปลี่ยนตาม orderBys, CustomFunction ใช้กับ list-typed SetState ไม่ได้) → `PATTERNS.md` **PT-27**

## D-46 — `Home`: ปิดช่อง substring search + trigram index + พยายามทำ empty-state (ไม่สำเร็จ) (2026-08-19)

**pete รายงาน:** พิมพ์คำค้นบางส่วน (ไม่ตรงชื่อเป๊ะ) แล้วไม่เจอสินค้าเลย — สอบถามเพิ่มว่า filter ทำงานไหม ยืนยันว่า filter ทำงานจริงแต่กรองจนเหลือ 0 (D-45's `iLike` ไม่มี `%...%` ห่อ) ขอให้แก้แบบกระทบ layer อื่นน้อยที่สุด พร้อม null-safety, trigram index, empty-state UI

**🔴 พบบั๊กเพิ่มระหว่างสืบ:** `buildSearchRefreshChain` ใช้ร่วมกับ pull-to-refresh ด้วย ค่า default ของ `searchQuery` คือ `''` → `title ILIKE ''` แมตช์เฉพาะ title ที่เป็นสตริงว่างจริง (ไม่มีสินค้าไหนเป็นแบบนั้น) **แปลว่า pull-to-refresh ตอนไม่ได้ค้นหาอยู่จะโชว์ grid ว่างเปล่า** — บั๊กจริงใน D-45 ที่ pete ยังไม่ทันเจอ (ยังไม่ได้ทดสอบแอปจริง) แก้พร้อมกันในตัวเดียวกับ search fix

**ค้นพบสำคัญ (แก้ทฤษฎีเดิมของ D-45):** ตอนแรกกลัวว่า custom function ใช้กับ `PostgresFilter.value` ไม่ได้เหมือน `SetState` ที่พัง — ตรวจ compiler source แล้วพบว่า `PostgresFilter.value` compile ผ่าน path ทั่วไป (`_compileValue`/`_compileVariable`, compiler.dart:8390/8585) คนละเส้นทางกับ "Update App State" (ที่ปฏิเสธ custom function สำหรับ `List<PostgresRow>` state field) — เส้นทางเดียวกับที่ `Snackbar`/`Text` ใช้ `CustomFunction(...)` สำเร็จอยู่แล้วในตัวอย่าง SDK เอง **ทดสอบจริงแล้วใช้ได้** — เพิ่ม custom function `wrapSearchPattern(keyword) => '%$keyword%'` (มี guard trim + คืน `%%` เมื่อว่าง) ผูกเป็น `value:` ของ `title` filter แทน `State('searchQuery')` ตรง ๆ

**🔴 กับดักที่เจอระหว่างทำ (Dart nullability ของ custom function param):** `args: {'keyword': string}` ใน DSL ก็ยัง compile parameter เป็น **nullable** (`String? keyword`) ในโค้ดจริงเสมอ ไม่ว่า DSL type จะระบุยังไง (ยืนยันจาก `generated_code/lib/flutter_flow/custom_functions.dart`) — พุชแรกเขียน `keyword.trim()` ตรง ๆ ไม่มี null-check `flutterflow ai run` push ผ่านเฉย ๆ (แค่ validate FlutterFlow proto ไม่ได้ dart-compile ตัว custom code body) ถ้าปล่อยไว้จะพังตอน build แอปจริง จับได้จากการอ่าน `generated_code/` ก่อนถือว่าเสร็จ ไม่ใช่จาก push สำเร็จ แก้เป็น `(keyword ?? '').trim()` — ตรงกับกับดักเดิมที่เคยเจอกับ `getOtherUsers`/`senderLabel` (chatMessages section) เป๊ะ ใช้ `custom_code_helpers.updateCustomFunction` แก้ (ไม่ใช้ `app.customFunction` ซ้ำ เพราะ `ensureCustomFunction` throw ถ้า payload ต่างจากที่ deploy ไปแล้ว)

**Trigram index:** `CREATE EXTENSION pg_trgm` + `CREATE INDEX ... USING gin (title gin_trgm_ops)` บน `products` (ตาราง ไม่ใช่ view) — ใช้ `CREATE INDEX` ธรรมดา ไม่ใช้ `CONCURRENTLY` เพราะ migration tool รันใน transaction block (`CONCURRENTLY` รันในนั้นไม่ได้) ข้อมูลตอนนี้มีไม่กี่แถวเลยล็อกสั้น ๆ ไม่กระทบ

**🔴 Empty-state UI — ลองแล้วไม่สำเร็จ ถอนออกทั้งหมด:** ลอง 2 วิธี ทั้งคู่ถูกปฏิเสธฝั่ง backend โดยไม่มี local validator เตือนล่วงหน้าเลย:
1. Raw-proto: จำลอง shape เดียวกับที่ compiler สร้างให้ `Equals(...)` เอง (`FFVariable(source: FUNCTION_CALL, functionCall: FFFunctionCall(condition: FFCondition(relation: EQUAL_TO), ...))`) เทียบ `listLength(productsList)` กับ `0` ผูกเป็น `visible:` — compile ผ่าน push ผ่าน แต่ error "Condition configuration is invalid"
2. Custom function: เพิ่ม state `hasNoResults` (bool) + custom function `isProductListEmpty(items) => items.isEmpty` เรียกคู่กับทุกจุดที่ set `productsList` — พังด้วย error เดียวกับที่ D-45 เจอกับ `productsList` เป๊ะ ("update value is not properly set") **ทั้งที่ target เป็น `bool` ไม่ใช่ `List<PostgresRow>`** — ล้มทฤษฎีเดิมของ D-45 ที่คิดว่าปัญหาอยู่ที่ type ของ field ปลายทาง

**สรุปทฤษฎีใหม่ (ยังไม่ยืนยัน 100%):** custom function ที่รับ `List<PostgresRow>` ActionOutput เป็น argument จะถูกปฏิเสธทุกครั้งที่ผลลัพธ์ไปจบที่ SetState ไม่ว่า function จะ return type อะไรหรือ SetState ไป field ไหน (`wrapSearchPattern` รอดเพราะ argument เป็น `State('searchQuery')` ธรรมดา ไม่ใช่ list) — **ถอน `hasNoResults`/`isProductListEmpty`/`EmptySearchState` ออกทั้งหมด ไม่ทิ้งครึ่ง ๆ กลาง ๆ ไว้** ยืนยันจาก `generated_code/`: ทั้งสองชื่อไม่เหลือเลย, search fix + shuffle_key + 26 ปุ่ม + RefreshIndicator ยังอยู่ครบเหมือนเดิม

**ทางที่ยังไม่ลอง (ถ้าจะกลับมาทำ):** scaffold-level `databaseRequest` + `nodeKeyRef` แบบ `ProfileUser`/PT-14/PT-26 (`hideOnEmpty`/`EXISTS_AND_NON_EMPTY` พิสูจน์แล้วว่าใช้ได้จริงกับ query แบบนั้น) แต่เป็นกลไกคนละแบบกับ action-chain query ที่ `Home` ใช้อยู่ตอนนี้ทั้งหน้า — ถือว่าเปลี่ยนโครงสร้างใหญ่เกินไปสำหรับ UX nicety ไม่ใช่บั๊กที่ต้องรีบปิด

**ยืนยันจาก `generated_code/lib/home/home_widget.dart`:** `.ilike('title', functions.wrapSearchPattern(_model.searchQuery))` ทั้ง search-submit และ pull-to-refresh, `shuffle_key` 29 จุดเหมือนเดิม, 26 `FFButtonWidget` + `RefreshIndicator` ยังอยู่ครบ — **ยังไม่ได้ให้ pete ทดสอบผ่านแอปจริง**

รายละเอียด pattern ใหม่ (custom function ใช้กับ `PostgresFilter.value` ได้จริง, custom function param เป็น nullable เสมอ, empty-state ผ่าน list-based condition ยังทำไม่ได้) → `PATTERNS.md` **PT-27** (ต่อท้าย)

## D-47 — 🔴 `shuffleProducts` custom function ค้าง orphan บนโปรเจกต์จริง ทำ custom_functions.dart ทั้งไฟล์ compile ไม่ผ่าน (2026-08-19)

**pete รายงาน:** เปิด FlutterFlow editor เจอ error 2 จุด — เปิด `getOtherUsers` (ฟังก์ชันเก่าจาก L4, ไม่ได้แตะเลยวันนี้) ก็ error, เปิด `shuffleProducts` ก็ error คนละข้อความ (แนบสกรีนช็อตทั้งคู่)

**ต้นเหตุจริง:** ตอน D-45 ย้ายจาก client-side shuffle ไปใช้ `shuffle_key` (SQL) ลบแค่บรรทัด `app.customFunction('shuffleProducts', ...)` ออกจากสคริปต์ — **แต่การไม่ declare ซ้ำ ไม่เท่ากับลบออกจากโปรเจกต์จริง** ต้องเรียก `app.removeCustomFunction(...)` อย่างชัดเจนเท่านั้นถึงจะลบ (ไม่เคยเรียก) `shuffleProducts` เลยค้างอยู่บนโปรเจกต์จริงพร้อม signature ที่ผิดเพี้ยน: `ProductsReviewViewRow? shuffleProducts(ProductsReviewViewRow? items)` (ทั้ง arg และ return ไม่ถูกตั้งเป็น list ทั้งที่สคริปต์ตอนประกาศระบุ `listOf(...)` ทั้งคู่) แต่ body ยังทำ `List<ProductsReviewViewRow>.from(items)..shuffle()` (ปฏิบัติกับ `items` เหมือนเป็น Iterable) — type mismatch จริง compile ไม่ผ่าน `flutterflow ai run` ไม่เคยจับได้เพราะ validate แค่ FlutterFlow proto ไม่ dart-compile ตัว custom code (กับดักเดียวกับที่เจอกับ `wrapSearchPattern`'s nullable param, D-46) เพราะ custom function **ทุกตัวในโปรเจกต์ compile รวมเป็นไฟล์เดียว** (`custom_functions.dart`) ฟังก์ชันเสียตัวเดียวทำทั้งไฟล์พังหมด แสดง error แม้เปิดฟังก์ชันอื่นที่ไม่เกี่ยวข้องเลย (`getOtherUsers`)

**แก้:** `app.removeCustomFunction('shuffleProducts')` แล้ว push ยืนยันจาก `generated_code/lib/flutter_flow/custom_functions.dart`: `shuffleProducts` หายไปจริง เหลือ 6 ฟังก์ชัน (`mapProductCondition`/`parseProductPrice`/`parseCategoryId`/`senderLabel`/`getOtherUsers`/`wrapSearchPattern`) signature สะอาดทุกตัว ไม่กระทบ `Home`'s shuffle/search/26 chip/RefreshIndicator เลย (คนละกลไก, `shuffle_key` เป็น SQL ไม่ผ่าน custom function อยู่แล้ว)

**บทเรียน:** เลิก declare custom function/entity อื่นในสคริปต์ **ไม่ได้แปลว่าลบออกจากโปรเจกต์จริง** ถ้าตั้งใจเลิกใช้ ต้อง `app.removeCustomFunction`/`removePage`/`removeComponent`/ฯลฯ ให้ตรงชนิด explicit เสมอ ไม่งั้นเหลือ orphan ค้างที่อาจพังทั้งไฟล์ร่วม (กรณี custom function ร้ายแรงกว่า widget เดี่ยว ๆ เพราะ compile รวมไฟล์เดียวกันทั้งโปรเจกต์)

## D-48 — 🔴 `iLike` filter + custom function ทำ Live Test Mode "Analyzer Errors" จริง — ถอย search กลับเป็น exact match (2026-08-19)

**pete รายงาน:** รัน Live Test Mode เจอ error 3 จุด (สกรีนช็อต) — 2 จุดเป็น `test_mode_codegen` HTTP 410 "Session is deleted" (session ฝั่ง FlutterFlow test-mode หมดอายุ/ถูกลบ ไม่เกี่ยวกับโค้ดเรา น่าจะแก้ด้วยการกด Retry รันใหม่) อีก 1 จุดเป็น **"Analyzer Errors" จริง**: `dart analyze reported 2 error(s)` ที่ `home/home_widget.dart` — `argument_type_not_assignable: The argument type 'String?' can't be assigned to the parameter type 'String'`

**ต้นเหตุ:** D-46's fix (custom function `wrapSearchPattern` ผูกเป็น `PostgresFilter.value` ของ `title` `iLike`) compile เป็น `.ilike('title', functions.wrapSearchPattern(...))` — custom function return value เป็น `String?` เสมอ (D-47 พิสูจน์แล้วว่า param เป็น nullable เสมอ ครั้งนี้พบว่า **return ก็เป็น nullable เสมอเหมือนกัน** ไม่ว่า DSL จะประกาศ `returns: string` ก็ตาม) แต่ `.ilike(...)`'s parameter ต้องการ `String` (non-null) ตรง ๆ — type mismatch จริง `flutterflow ai run` ไม่เคยจับได้เพราะ validate แค่ proto ไม่ dart-compile หน้าเพจที่เรียกใช้ custom function เลย

**ลองแก้ก่อนแล้วพัง:** ย้ายไปคำนวณ pattern ผ่าน page-state field (`searchPattern`) ก่อน ด้วยสมมติฐานว่า state field compile เป็น non-nullable — **ผิด** ตรวจ `generated_code/lib/home/home_model.dart` ตรง ๆ พบว่า **ทุก page-state field เป็น nullable หมด** ไม่ว่า type อะไร (`int? selectedCategoryId`, `String? searchQuery` เดิมก็เป็น `String?` อยู่แล้ว) เหตุที่ `.eqOrNull('moderation_status', 'approved')` (แม้เป็น literal ธรรมดา) ใช้ได้เพราะ **`equalTo` compile ผ่าน `eqOrNull` (null-safe) เสมอ ไม่ว่าค่าจะมาจากไหน** เป็นคุณสมบัติของ relation ไม่ใช่ของค่าที่ผูก — **`iLike` (และคาดว่า `like`/`contains` ด้วย) ไม่มี null-safe variant แบบนี้ใน SDK นี้เลย** เป็นข้อจำกัดจริงของ backend codegen ไม่ใช่เรื่องที่แก้ด้วยการเลือกแหล่งค่าต่างกันได้

**แก้จริง — ถอย search กลับเป็น exact match (`equalTo`, null-safe พิสูจน์แล้ว):** ลบ `wrapSearchPattern` (`app.removeCustomFunction`, เรียนบทเรียนจาก D-47 ทันที ไม่ปล่อยค้าง) เปลี่ยน `title` filter กลับเป็น `equalTo` + `State('searchQuery')` ตรง ๆ — แต่ `equalTo` ทำให้ "ค้นหาว่างเปล่า = โชว์ทุกอย่าง" (ที่ `iLike('')` เคยได้ผลบังเอิญ) ใช้ไม่ได้อีกต่อไป (title = '' ไม่ match อะไรเลย) แก้ด้วย **`If(Equals(State('searchQuery'), ''), then: [query ไม่มี title filter], orElse: [query มี title filter])`** — DSL's typed conditional action (`If`, ไม่ใช่ `Actions.conditional` ที่ CLAUDE.md อ้างซึ่งรับแค่ raw `FFVariable` ไม่รับ typed `DslExpression`) แยก query เป็น 2 กิ่งจริง คนละ `outputAs`

**สถานะค้นหาตอนนี้:** exact match เท่านั้น (case-insensitive ผ่าน `eqOrNull`) — substring search ที่ D-46 ทำไว้ใช้จริงไม่ได้ ถอนออกหมดแล้ว **ทางที่เหลือถ้าจะทำ substring จริง:** RPC `search_products` (P-05, `PROPOSED_SQL.md`) เรียกผ่าน custom action (`Supabase.instance.client.rpc(...)`, pattern เดียวกับ `find_or_create_chat`/D-29) — เขียน null-handling เองใน Dart ได้ตรง ๆ ไม่ผ่าน typed-filter codegen ที่มีช่องโหว่นี้ ยังไม่ได้ทำ รอ pete ตัดสินใจว่าจะลงทุนทำต่อไหม

**ยืนยันจาก `generated_code/lib/home/home_widget.dart`:** ไม่มี `.ilike(` เหลือเลยทั้งไฟล์, ทุก filter ใช้ `.eqOrNull(` หมด, if/else 2 กิ่งคอมไพล์ถูกทั้ง search-submit และ pull-to-refresh, `shuffle_key`/26 ปุ่ม/`RefreshIndicator` ไม่กระทบ, `custom_functions.dart` เหลือ 5 ฟังก์ชันสะอาด (`wrapSearchPattern`/`shuffleProducts`/`isProductListEmpty` หายหมดแล้ว) — **ยังไม่ได้ให้ pete รัน Live Test Mode ซ้ำเพื่อยืนยันว่า analyzer error หายจริง**

รายละเอียด pattern ใหม่ (ทุก page-state field เป็น nullable เสมอ, `equalTo` เท่านั้นที่ null-safe, `If` คือ typed conditional action ตัวจริง) → `PATTERNS.md` **PT-27** ข้อ 6

---

## D-49 — จุดแดง unread ค้าง (D-32): แก้ครบ 3 หน้าแล้ว — `Notifications`/`ReportsFeedback` ยังขาด refetch ที่ `chatList` มีอยู่ก่อนแล้ว (2026-08-20)

**พบว่า `chatList` แก้ไปแล้วจริงตั้งแต่ก่อนหน้านี้** (raw-proto refetch tail ต่อท้าย Navigate node, ยืนยันจาก `dsl/edit.dart` — งานนี้แค่ verify ผ่าน `generated_code`) แต่ `STATUS.md`/`L4-chat.md` ยังเขียนว่าเป็นหนี้ค้างอยู่ — เอกสารตกหล่นไม่ได้อัปเดตตามโค้ดที่ push แล้วจริง

**`Notifications`/`ReportsFeedback` ยังไม่เคยแก้จริง:** onTap เดิม update DB (`is_read`) ถูกต้อง แต่ไม่ refetch list state ของหน้าตัวเอง (`_model.notifications`/`_model.reports`) เลย — `safeSetState()` rebuild ด้วยข้อมูลเดิม จุดแดงเลยไม่หายจนกว่าหน้าจะถูกสร้างใหม่จริง (สลับ tab)

**แก้:** เทคนิคเดียวกับ `chatList` เป๊ะ — เดิน raw proto ไปหา Navigate node ท้ายสุดของ ON_TAP chain เดิม (ไม่แตะของเดิมเพราะมี generator-variable reference จาก itemBuilder scope) แล้วต่อท้ายด้วย tail ที่ compile ผ่าน `compileDslActionSequenceForExistingWidgetClass` (PostgresQuery + SetState) — `Notifications` chain ตื้นกว่า `chatList`/`ReportsFeedback` 1 ชั้น (root = update action ตรง ๆ ไม่มี pendingId SetState คั่น)

**เจอบั๊กเดิมค้าง ระหว่างแก้:** `dsl/edit.dart` มี `app.removeCustomFunction('wrapSearchPattern')` (จาก D-48) ที่ตาม comment บอกว่า "สำเร็จแล้วและ retire แล้ว" แต่บรรทัดเรียกจริงยังไม่ถูกลบ — push ครั้งนี้ค้าง `CustomCodeNotFoundError` เพราะ remove ไม่ idempotent (D-27) ลบบรรทัดออกแล้ว push ผ่าน

**ยืนยันจาก `generated_code/`:** ทั้ง `notifications_widget.dart`/`reports_feedback_widget.dart` มี `queryRows` + reassign `_model.notifications`/`_model.reports` ต่อท้าย mark-read แล้วก่อน `safeSetState` — **ยังไม่ได้ทดสอบผ่านแอปจริงโดย pete**

**เหมือน `chatList`:** refetch fire ทันทีตอนแตะ (ไม่ใช่ตอนกลับมาหน้าเดิม) เพราะ `context.pushNamed` ไม่ await — ใช้ได้เพราะ mark-read await เสร็จก่อนหน้านั้นแล้ว. `last_message`/content staleness จาก data ที่เปลี่ยนระหว่างอยู่หน้าอื่นยังไม่แก้ (ไม่มี pull-to-refresh บน 2 หน้านี้ ต่างจาก `chatList`) — ยังไม่มีคนขอ

---

## D-50 — `Home` เพิ่มปุ่ม "ค้นหา" ให้กด submit ได้จริง (2026-08-20)

**pete รายงาน:** ช่องค้นหาไม่มีปุ่มให้กด submit เลย — ที่ผ่านมา (D-45–D-48) query จะยิงก็ต่อเมื่อกด IME "search"/"done" บนคีย์บอร์ดเท่านั้น (`ON_TEXTFIELD_SUBMIT`) ไม่มีปุ่มที่มองเห็น/แตะได้บนหน้าจอเลย

**แก้:** เพิ่ม `Button` ชื่อ `SearchSubmitButton` (key จริง `Button_ym795py5`) เป็น sibling ต่อจาก `TextField_muyt5648` โดยตรง (ไม่แตะ/re-author ช่องค้นหาเดิมเลย) — onTap เรียก `buildSearchRefreshChain(...)` ฟังก์ชันเดียวกับที่ผูกกับ `ON_TEXTFIELD_SUBMIT`/pull-to-refresh อยู่แล้ว คนละ `outputAs` (`searchSubmitButtonExact...`) กันชนกับ 2 จุดเดิม (บทเรียนจาก D-38/Mypost status chip: reuse `outputAs` ข้าม widget compile ไม่ผ่าน)

**เทคนิค:** `page.ensureInsertedAfter` (one-shot, ไม่ rerun-safe ตาม PT-16) ต่อ push แล้ว retire call ออกจากสคริปต์ทันทีหลังยืนยัน key จริงจาก `lib/flutterflow_project/pages/home.dart` — ยืนยันจาก `generated_code/`: `FFButtonWidget` "ค้นหา" ต่อท้าย search field จริง เรียก query/If/SetState shape เดียวกับปุ่ม submit เดิม ไม่มี outputAs ชนกัน

**ยังไม่ได้ทดสอบผ่านแอปจริง**

---

## D-51 — `ProductDetails` ซ่อนปุ่ม "รายงาน"/"แชทกับผู้ขาย" จากเจ้าของประกาศเอง (2026-08-20)

**pete สั่ง:** ตอนเข้าดู `ProductDetails` ของประกาศตัวเอง (เช่นจาก `MyPost`) ให้ซ่อน `IconButton_k689spgx` (ปุ่มรายงาน, AppBar action) กับ `Button_p7zb7whe` (ปุ่ม "แชทกับผู้ขาย")

**เคยติดเป็นหนี้ (D-32 ข้อ 4):** บันทึกเดิมเข้าใจผิดว่าติดปัญหา ItemRef/generator scope เหมือน PT-23 — ตรวจ `lib/flutterflow_project/pages/product_details.dart` จริงแล้วพบว่า **ทั้งสองปุ่มเป็น sibling ระดับหน้าตรง ๆ** (`Button_p7zb7whe` อยู่ใต้ body Column โดยตรง, `IconButton_k689spgx` อยู่ใน AppBar actions) ไม่ได้อยู่ใน itemBuilder เลย — ตัวบล็อกจริงคือ **ไม่เคยมี `seller_id` ระดับหน้าให้ผูกมาก่อน** จนกระทั่ง D-44 เพิ่ม page-scoped `databaseRequest` (ผูกกับ `Scaffold_amt0m1za`, filter `id = productId`) ไว้ใช้กับรูปที่ 2/3 อยู่แล้ว — งานนี้แค่ต่อยอด query เดิม ไม่เพิ่ม query ใหม่

**แก้:** raw proto ล้วน (`isNotOwner()` function คืน `FFVariable` ใหม่ทุกครั้งที่เรียก — protobuf message ผูกกับ parent ได้แค่ที่เดียว แชร์ instance เดียวกัน 2 จุดไม่ได้) hand-replicate shape ที่ compiler สร้างจาก `Not(Equals(...))` จริง (`FUNCTION_CALL` + `FFCondition(EQUAL_TO)` เทียบ 2 `FFValue` แล้วต่อ `FFVariableOperation(negate: ...)`) เพราะ typed `Equals()`/`Not()` รับแค่ `State`/`Param`/`AuthUser` ไม่รับ raw page-scoped `FFVariable` แบบ `productField('seller_id')` — เทียบกับ `SUPABASE_AUTH_USER`/`USER_ID` (shape เดียวกับที่ใช้ผูก storage path มาก่อนแล้วในไฟล์นี้) ผูกเป็น `visible:` ให้ทั้ง 2 widget ผ่าน `node.props.ensureVisibility()`

**ยืนยันจาก `generated_code/lib/product_details/product_details_widget.dart`:** ปุ่มรายงานคอมไพล์เป็น `Visibility(visible: !(...sellerId == currentUserUid), ...)`, ปุ่มแชทคอมไพล์เป็น `if (!(...sellerId == currentUserUid)) FFButtonWidget(...)` — เป็น conditional จริง ไม่ใช่ static-visible:false ที่เคยพังใน D-43/D-44 push แรก

**ยังไม่ได้ทดสอบผ่านแอปจริง** (โดยเฉพาะกรณี `seller_id` เป็น NULL — LEFT JOIN ของ `products_review_view` — คาดว่าจะโชว์ปุ่มตามปกติเพราะ `NULL == uid` เป็น false, `Not(false)` เป็น true แต่ยังไม่เคยมีเคสจริงให้ยืนยัน)

---

## D-52 — ระบบ Ban User: soft ban บังคับที่ RLS จริง (2026-08-21)

**ปัญหา:** `"Profile".is_banned` มีมาตั้งแต่ 2026-08-14 แต่เป็นแค่ตัวนับบน `admin_dashboard_stats` — ไม่มี RLS/trigger/Action Flow ตัวไหนอ่านค่านี้เลย ผู้ที่ `is_banned = true` ยังลงประกาศ/แชท/รายงานได้ปกติ และไม่มี UI ให้แอดมินกดแบน (แก้ได้ทางเดียวคือ SQL ตรง ๆ) · 🔴 ระหว่างสำรวจพบช่องโหว่จริงเพิ่ม: `with_check` ของ policy `Users can update own profile` ล็อกแค่ `role`/`student_id` **ไม่ได้ล็อก `is_banned`** — ผู้ถูกแบนยิง API ตรงปลดแบนตัวเองได้

**สเปคที่ pete เลือก:** soft ban (login/browse ได้ แต่ลงประกาศ/แชท/รายงานไม่ได้) · ถาวรอย่างเดียว + เหตุผลบังคับ · ทางเข้าแอดมิน = หน้า `ManageUsers` ใหม่ + ปุ่มใน `ReportDetail` · ประกาศเดิมถูก**ซ่อน**ไม่ใช่ลบ/reject · ผู้ถูกแบนเห็น popup การ์ดบน `Home` พร้อมปุ่มไปแชทแอดมิน ปัดทิ้งแล้วท่องแอปต่อได้

**ตัดสินใจ 6 ข้อ:**

1. **`RESTRICTIVE` policy ไม่ใช่ `PERMISSIVE`** — `products` เป็น allow-all อยู่ PERMISSIVE ใหม่จะ OR แล้วไม่มีผล (บทเรียนตรงจาก D-23) RESTRICTIVE จะ AND ทับผลรวม เป็น RESTRICTIVE ชุดแรกของโปรเจกต์นี้ · จงใจไม่แตะ `SELECT` เพราะเป็น soft ban

2. **ปิดช่องปลดแบนตัวเองด้วย trigger ไม่ใช่แก้ `with_check`** — คัดแม่แบบ `enforce_moderation_admin_only` (D-23) มาตรง ๆ คุมครบ 4 คอลัมน์ ban ในที่เดียว และ `with_check` เทียบ OLD/NEW ไม่ได้อยู่แล้ว

3. **ซ่อนประกาศด้วย gate-in-view ไม่ใช่ filter ฝั่ง FlutterFlow** — เติม `WHERE NOT is_user_banned(seller_id) OR seller_id = auth.uid() OR is_admin()` ใน `products_review_view` (แม่แบบ D-33) **ผลคือไม่ต้องแตะ query ฝั่ง FF เลยสักตัว** — Home onLoad + ค้นหา + 26 category chip + pull-to-refresh + Mypost + ProductDetails + HomeAdmin ถูกต้องหมดทันที (ถ้าไปใส่ filter ฝั่ง FF ต้องแก้ทุก query และต้องเปลี่ยน `outputAs` ทุกตัวตาม D-45)

4. **รวมทุก write ไว้ใน RPC เดียว `admin_set_user_ban`** — update `"Profile"` + insert `notifications` อยู่ใน SECURITY DEFINER ตัวเดียว ทำให้ insert แจ้งเตือนไม่ผ่าน PostgREST จึง**ไม่โดน select-back ที่เคยฆ่า action chain เงียบ ๆ ใน D-24** และเป็นทางเดียวที่ได้ error handling จริงเพราะ Postgres action ใน DSL ไม่มี `onSuccess`/`onFailure` (PT-18) · guard 4 ชั้นในตัวเอง ไม่เชื่อ client (D-29)

5. **เปิดช่องอุทธรณ์ไว้โดยตั้งใจ** — `chat_message` RESTRICTIVE มีข้อยกเว้น `OR private.chat_has_admin(chat_id)` และ `find_or_create_chat_with_admin` จงใจไม่ใส่ ban guard (ต่างจาก `find_or_create_chat`) ถ้าปิดหมดผู้ถูกแบนจะติดต่อใครไม่ได้เลย · guard ใน `find_or_create_chat` วางไว้**หลัง** early-return ห้องเดิม → ห้องที่มีอยู่แล้วยังเข้าได้ ปิดเฉพาะการเปิดห้องใหม่

6. **`can_ban`/`can_unban`/`is_self` เป็น computed boolean ใน `admin_users_view`** — คำนวณเงื่อนไข (ไม่ใช่ตัวเอง ไม่ใช่แอดมิน) ที่ SQL แล้วให้ UI ผูก `visible:` ตรง ๆ ซึ่งเป็นวิธีที่ PT-24 §1 ระบุว่าปลอดภัยที่สุด — เลี่ยง raw proto ที่ D-51 ต้องเจอ และเลี่ยง `Equals(item['f'], '')` ที่เทียบผิดกับ `String?`

**ยืนยันด้วย impersonation test ครบ 3 บทบาท** (แอดมิน/user ปกติ/user ที่ถูกแบน) — ผลเต็ม `VERIFICATION.md` V-12

🔴 **กับดักที่เจอระหว่างทำ (รายละเอียดเต็ม PT-28):** grant ของ helper ใหม่หลุดจาก `authenticated` ตอน revoke · RESTRICTIVE `USING` บล็อกแบบเงียบ (คืน 0 แถว ไม่ raise) ทำให้เทสรอบแรกอ่านผลผิด

**Phase A (Supabase) ปิดแล้ว** · Phase B–D (FlutterFlow: `ManageUsers`/`BanUserSheet`/popup บน Home/ปุ่มใน ReportDetail) ยังไม่ทำ

### D-52 (ต่อ) — Phase B–D: UI ครบแล้ว (2026-08-21)

**ทำอะไรไปบ้าง (5 พุช)**

| พุช | ได้อะไร |
|---|---|
| B | register `admin_users_view` · app state 4 ตัว (`banTargetUserId`/`banTargetUserName`/`banReason`/`myBanReason`) · custom action 3 ตัว 0-arg (`adminBanUser`/`adminUnbanUser`/`getMyBanReason`) |
| C1 | หน้า `ManageUsers` (placeholder) + component `BanUserSheet` |
| C2 | body จริงของ `ManageUsers` (ListView + ปุ่ม Ban/Unban) + ปลุกเมนู "ผู้ใช้งาน" บน `HomeAdmin` |
| C2b | ปุ่ม "รีเฟรช" ระดับหน้า (จำเป็นเพราะ PT-29 §1) |
| D | popup `BannedNoticeDialog` บน `Home` + ปุ่ม "ระงับผู้ขายรายนี้" บน `ReportDetail` |

**เพิ่มจากสเปคเดิม (pete สั่งระหว่างทำ):** ฝั่งผู้ใช้เป็น **popup การ์ด** ไม่ใช่แบนเนอร์นิ่ง — บอกเหตุผล + รายการสิ่งที่ทำไม่ได้ + ปุ่ม "ติดต่อแอดมิน" (ไปห้องแชทแอดมินเพื่อเคลียร์ปัญหา) + ปุ่มปิด **ปัดทิ้งแล้วท่องแอปต่อได้** (`showAlignedDialog` barrier-dismissible) ซึ่งคือนิยามของ soft ban พอดี

**ตัดสินใจเพิ่ม 3 ข้อ**

7. **ปุ่ม Ban/Unban แยกเป็น 2 widget สลับด้วย `visible:`** ผูกกับ `can_ban`/`can_unban` ที่คำนวณใน view (D-52 ข้อ 6) — ยืนยันจาก `generated_code/` ว่าคอมไพล์เป็น `if (userItem.canBan ?? true) IconButton(...)` จริง ไม่ใช่ static
8. **ปุ่ม "รีเฟรช" ระดับหน้าเป็นสิ่งจำเป็น ไม่ใช่ของแถม** — เจอขีดจำกัดใหม่ว่า itemBuilder เดียวมี PostgresQuery ได้แค่ตัวเดียว (PT-29 §1) ปุ่ม Ban ใช้โควตาไปแล้ว ปุ่ม Unban จึงยิง refetch เองไม่ได้ ต้องมีปุ่มรีเฟรชนอก itemBuilder มารับหน้าที่นี้
9. **`BanUserSheet` ไม่มี params ใช้ซ้ำได้ 2 ทางเข้า** — เป้าหมายเดินทางผ่าน App State (`item['id']` เป็น action param ไม่ได้ PT-25 §1) ผลพลอยได้คือ `ManageUsers` กับ `ReportDetail` ใช้ component ตัวเดียวกันได้เลย ไม่ต้องทำสองอัน

🔴 **กับดักที่เจอเพิ่ม (รายละเอียดเต็ม PT-29):** query ได้ตัวเดียวต่อ itemBuilder (ตั้ง outputAs ไม่ซ้ำ/เปลี่ยน signature ไม่ช่วย) · `visible:` จาก view compile เป็น `?? true` → NULL = โชว์ ต้อง COALESCE ที่ SQL (แก้ `admin_users_view` แล้ว) · `AppState(ff.AppState.x)` handle ต้องอยู่ข้างใน error message ชวนเข้าใจผิด · `Button`/`Expanded` รับ positional, `Snackbar` ไม่ใช่ `SnackBar`, ไม่มี `Actions.chain` · PT-19 key ดริฟต์อีกครั้งจริง (`ListView_89z1y0to`→`ListView_qglcpyh5`)

**ยืนยันแล้ว** (ผลเต็ม `VERIFICATION.md` V-13): `generated_code/` ทุกพุช, `dart analyze` custom action ทั้ง 3 ตัวสะอาด (ด่านที่ `flutterflow ai run` ไม่ตรวจ — ต้นเหตุ D-46/D-47), impersonation ปลายทาง, สคริปต์ rerun-safe หลัง retire ครบ (PT-21)

**ยังไม่ได้ทดสอบผ่านแอปจริงโดย pete** — ทั้งหมดยืนยันจาก `generated_code/` + DB เท่านั้น

---

## D-53 — หน้า `BannedUsers` แยกจาก `ManageUsers` (2026-08-22)

**ปัญหา:** `ManageUsers` (D-52) list ผู้ใช้ทั้งหมด ไม่กรอง — pete ขอหน้าแยกที่โชว์เฉพาะคนถูกแบนอยู่ พร้อมปุ่ม Unban เดียว

**สเปคที่ pete เลือก:** หน้าใหม่แยกต่างหาก (ไม่ใช่ filter บน `ManageUsers` เดิม) · ระบบ ban เป็นถาวรอย่างเดียว (D-52) ไม่มี `banned_until`/duration ใน DB จึงโชว์ **`banned_at`** ("ถูกแบนเมื่อ") แทน ไม่ใช่ duration/expiry ที่ไม่มีจริง

**ทำอะไรไปบ้าง (2 พุช, PT-22 split เหมือน `ManageUsers` C1/C2):**

| พุช | ได้อะไร |
|---|---|
| E1 | หน้า `BannedUsers` (placeholder, route `banned-users`) |
| E2 | body จริง — `ListView` ผูก `admin_users_view` กรอง `is_banned = true` เรียงตาม `banned_at desc`, แถวโชว์ชื่อ/อีเมล/ถูกแบนเมื่อ/เหตุผล/ระงับโดย + ปุ่ม Unban เดียว (`visible: can_unban`, เรียก `adminUnbanUser` ตัวเดิมจาก D-52), ปุ่มรีเฟรชระดับหน้า (เหตุผลเดียวกับ PT-29 §1) + ปลุก tap ให้การ์ดสถิติ "ผู้ใช้ถูกระงับ" บน `HomeAdmin` ให้ Navigate มาหน้านี้ |

**ยืนยันว่า `BannedUsersValue` (การ์ดสถิติ) ผูกอยู่แล้วจริง** กับ `admin_dashboard_stats.banned_users` มาตั้งแต่ D-52 (ไม่ใช่ placeholder ตามที่ดูตอนแรก) — ไม่ต้องเพิ่มอะไร แค่ปลุก tap ให้ navigate

🔴 **กับดักซ้ำที่ยืนยันอีกครั้ง:** `ensurePage` แยกพุชจาก `state:`/`onLoad:`/body ที่อ้างอิง state เดิม ใช้ได้กับหน้าที่**เพิ่งสร้างใหม่**เหมือนกับหน้าที่มีอยู่แล้ว (PT-22) · `SetState(...)` เขียน app state (`banTargetUserId`) ไม่ได้ ต้องใช้ `UpdateAppState.set(...)` (PT-23 ข้อ 4) · `ensureReplaced` ของ root ใหม่ต้องมี `name:` ไม่งั้น validate fail ทันที ("requires an inserted or replacement root widget with a non-empty name")

**ยืนยันจาก `generated_code/lib/banned_users/banned_users_widget.dart`** (conditional `if (bannedUserItem.canUnban ?? true)` จริง, ปุ่มเรียก `actions.adminUnbanUser()`) + `generated_code/lib/home_admin/home_admin_widget.dart` (การ์ดสถิติ `onTap` ยิง `context.pushNamed(BannedUsersWidget.routeName)` จริง)

**ยังไม่ได้ทดสอบผ่านแอปจริงโดย pete**

---

## D-55 — ป๊อปอัพโปรไฟล์ผู้ใช้ (avatar/ชื่อ/bio/ชั้นปี/คณะ) จาก ProductDetails + BannedUsers (2026-08-22)

**ปัญหา:** pete อยากให้แตะชื่อผู้ใช้แล้วเห็นข้อมูลโปรไฟล์พื้นฐานของคนอื่น จาก 2 จุด
(ชื่อผู้ขายบน `ProductDetails`, แถวผู้ใช้บน `BannedUsers`) — `year_of_study`/
`faculty` ไม่เคยมีคอลัมน์เก็บเลย ("likes rate" งดไว้ก่อน ยังไม่มีฟีเจอร์นั้นจริง)

**ตัดสินใจหลัก:**

1. **เพิ่ม `"Profile".year_of_study`/`faculty` (nullable ทั้งคู่) แล้วขยาย
   `public_profiles` (D-01) แทนสร้าง view ใหม่** — view นี้ไม่มี `security_invoker`
   มาตั้งแต่ D-01 (รันด้วยสิทธิ์ owner ข้าม RLS ของ `"Profile"`) และ grant SELECT
   ให้ `anon`/`authenticated` อยู่แล้ว การเพิ่มคอลัมน์ต่อท้ายจึงอยู่ใน exposure tier
   เดียวกับ `full_name`/`avatar_url` ที่เปิดเผยอยู่แล้วทุกหน้าจอ — ไม่ใช่การตัดสินใจ
   เปิดเผยข้อมูลใหม่ ยืนยันด้วย `get_advisors(security)` ว่าไม่มี lint ใหม่
2. **Paramless component (`UserProfileCard`) + custom action คั่นกลาง แทน
   `params:` ตรง ๆ แบบ `FullImageViewer`** — ข้อมูลโปรไฟล์ต้อง**ดึงจาก DB ก่อน**
   ไม่ใช่พร้อมอยู่แล้วแบบ URL รูป จึงต้องมี custom action (`loadViewedProfile`)
   คั่นระหว่างแตะกับเปิดการ์ด เหมือนแพทเทิร์น `BanUserSheet` (D-52) — เป็นจุดใช้ที่ 3
   ของแพทเทิร์น "paramless component + App State + custom action fetch"
3. **Reset ทุก field ที่โชว์ผลก่อนตั้ง target ใหม่และก่อน query เสมอ (pete สั่ง)** —
   กัน state leakage ข้ามโปรไฟล์ (สลับดูคนที่ 2 ติด ๆ กันแล้วเห็นข้อมูลคนแรกค้าง)
   และเปิดการ์ดเฉพาะตอน query สำเร็จเท่านั้น (`loadProfileResult == ''`) ล้มเหลว
   โชว์ SnackBar แทนไม่เปิดการ์ดเปล่า
4. **ชั้นปี/คณะคงพื้นที่แสดงผลไว้เสมอ ไม่ซ่อนทั้ง Row (pete สั่ง)** — label คงที่ +
   value สลับข้อความจริง/"ยังไม่ระบุ..." ด้วย `Equals`/`Not` (เหมือนแพทเทิร์น bio)
   กันเค้าโครงการ์ดขยับเมื่อข้อมูลว่าง (แทบทุกคนตอนนี้ เพราะยังไม่มีฟีเจอร์กรอกข้อมูล)
5. **Re-author itemBuilder ทั้งก้อนแบบ verbatim ทั้ง 2 จุด (ไม่ใช่แค่แปะปุ่ม)** —
   `item['seller_id']`/`item['id']` เป็น itemBuilder-scoped ทั้งคู่ (PT-23 §1: item[]
   ใช้ได้เฉพาะตอน author fresh ในสเตทเมนต์เดียวกัน) จึงต้อง `ensureReplaced`
   คัดลอกทุก field เดิมเป๊ะ (สำรองไฟล์ `generated_code/` ไปไว้ scratchpad ก่อนเขียน
   ทับ แล้ว diff ยืนยันหลัง push ทุกครั้งตามที่ pete สั่ง) เพิ่มแค่ Container(onTap:)
   ห่อชื่อ + ไอคอน `info_outline`

🔴 **กับดักที่เจอระหว่างทำ:**
- **`ensureReplaced` ไม่ปลอดภัยที่จะรันซ้ำแม้เนื้อหาถูกต้อง** (PT-16) — retry ครั้ง
  ที่สองด้วย key เดิมที่เพิ่ง landed ไปแล้วจากพุชก่อนหน้า ทำให้เกิด
  `Field "viewedProfileUserId" has an update value that is not properly set` +
  `Generator variable does not exist` ลามไปยัง itemBuilder อื่นที่ไม่เกี่ยวข้องเลย
  (`ChatListItems`/`SalesBySellerList`/`PendingProductsList`) แก้ด้วยการ
  `inspect --outline` ใหม่ดึง key สดก่อน retry ทุกครั้ง — คอนเฟิร์มอีกครั้งว่า
  "เช็ค outline สดก่อนเขียนโค้ดทุกครั้ง" ไม่ใช่ขั้นตอนที่ข้ามได้จริง ๆ
- **ห้ามห่อ ListView (เป้าหมายของ `ensureReplaced`) ด้วย `Expanded(...)`** — ทำให้
  เกิด error ชุดเดียวกันข้างบน (item-scope/generator-variable resolution พังทั้ง
  โปรเจกต์) ใช้ `shrinkWrap: true` บน `ListView` เอง (แพทเทิร์นเดียวกับ D-40
  `chatList`) แทน ได้ผลลัพธ์ปลอดภัยเดียวกัน (กัน unbounded-height crash) โดยไม่แตะ
  โครงสร้าง parent
- `ensureReplaced` ของ root ใหม่ต้องมี `name:` เสมอ ไม่งั้น validate fail ทันที
  ("requires an inserted or replacement root widget with a non-empty name")
- `SetState(...)` เขียน app state ไม่ได้ ต้อง `UpdateAppState.set(...)` (PT-23 ข้อ 4,
  ยืนยันซ้ำอีกครั้งเหมือน D-53)

**ยืนยันจาก `generated_code/`:** `load_viewed_profile.dart` (reset ไม่ทำในนี้ ทำที่
chain ก่อนเรียก, ไม่เซ็ต field ถ้าไม่เจอแถว), `user_profile_card_widget.dart`
(fallback ทุก field เป็น conditional จริง), `product_details_widget.dart` +
`banned_users_widget.dart` (diff กับไฟล์ backup ยืนยันว่า field เดิมทั้งหมดรอด
ครบ มีแค่ tap-wrapper ใหม่กับ shrinkWrap ที่เปลี่ยน)

**ยังไม่ได้ทดสอบผ่านแอปจริงโดย pete**

---

## D-56 — หน้า "ผู้ใช้งานทั้งหมด" (UserDirectory) + ตาราง `faculties` แยก (2026-08-22)

**ปัญหา:** pete อยากได้หน้ารวมโปรไฟล์ผู้ใช้ทุกคน (ไม่ใช่แค่แอดมิน) คล้าย `Home`
กรองชั้นปี (4 ระดับจริง) + คณะ (เริ่ม 4 คณะ) + ค้นหาชื่อ — สั่งให้สร้างตาราง `faculties`
แยกใน Supabase เอง ไม่ใช่ text อิสระแบบที่ D-55 ทำไว้ก่อน

**ตัดสินใจหลัก:**

1. **`faculties` (id/name) แยกจริง แทน `Profile.faculty` (text)** — เพิ่ม
   `Profile.faculty_id` FK ชี้ `faculties`, ลบคอลัมน์ `faculty` เดิมทิ้ง (ว่างทุก
   แถวอยู่แล้ว) `public_profiles` แก้เป็น join ผ่าน `faculty_id` แต่ผลลัพธ์
   คอลัมน์ `faculty` (ชื่อ/type) **เหมือนเดิมทุกประการ** — `UserProfileCard`/
   `loadViewedProfile` (D-55) ไม่ต้องแก้เลย RLS ของ `faculties` copy จาก `"CAT"`
   เป๊ะ (`ALL`/`authenticated`/`true`) ยังไม่มีชื่อคณะจริง ใส่ placeholder
   "คณะ A-D" ไปก่อนรอ pete แก้ผ่าน SQL
2. **CHECK ของ `year_of_study` แคบลงจาก 1-8 (D-55 เดาไว้กว้าง) เป็น 1-4** — pete
   ยืนยันแล้วว่ามหาลัยมี 4 ชั้นปีจริง
3. **View ใหม่แยก `public_directory_view` แทนแก้ `public_profiles`** — ต้องกรอง
   `WHERE NOT is_banned` สำหรับไดเรกทอรีสาธารณะ แต่แก้ `public_profiles` ตรง ๆ
   จะพัง `UserProfileCard` ที่ admin เปิดจากหน้า `BannedUsers` (D-55 ใช้
   `public_profiles` หา id เดียวกัน ถ้ากรองคนถูกแบนออกจาก view นั้นเลย admin จะ
   ดูโปรไฟล์คนที่เพิ่งแบนไม่ได้อีก) — เป็น gate-in-view pattern เดียวกับ D-33/D-52
   ข้อ 3 ที่ `products_review_view` ใช้อยู่แล้ว
4. **`public_directory_view` COALESCE ทุกคอลัมน์ที่ nullable ก่อนส่งออก** (ต่างจาก
   `public_profiles` ที่ปล่อย NULL ผ่านได้เพราะมี `loadViewedProfile` คอยจัดการ) —
   คอลัมน์ของ view นี้ bind ตรงกับ `item[]`/`Text` widget ใน `ListView` โดยไม่มี
   custom action คั่น การ bind field ที่เป็น NULL ตรง ๆ compile เป็น force-unwrap
   (`item.field!`) ที่ **crash จริงตอนรัน** (ยืนยันจากโค้ดจริงของ `BannedUserRow`
   ที่ทำแบบเดียวกันมาก่อน) `year_of_study` (raw int, nullable) เก็บไว้สำหรับ
   filter เท่านั้น เพิ่ม `year_label` (text, COALESCE แล้ว) แยกไว้แสดงผล
5. **Filter chip แบบ mutually-exclusive ไม่ใช่ AND รวมกัน** — `filters:` ของ
   `PostgresQuerySpec` fix ตอน compile-time (ไม่มี list-literal expression —
   PT-23 §7) ครบทุก combination ของ 3 filter ต้องใช้ `If` ซ้อน 8 กิ่ง เลือกทำแบบ
   `Home`'s category chip แทน (D-37/D-39/D-46/D-48): แตะแกนไหนล้างอีก 2 แกน
   ยิง query ใหม่แค่ filter เดียว — proven แล้วในโปรเจกต์ ไม่ต้องคิดกลไกใหม่
6. **ค้นหาชื่อ exact match เท่านั้น** — สืบทอดข้อจำกัดจาก D-48 (`equalTo` เท่านั้นที่
   null-safe เมื่อผูกกับค่า dynamic)
7. **หน้าเป็น `ListView` แถวมีหัวตาราง ไม่ใช่ `PaginatedDataTable`/`DataTable`
   ของจริง** — เช็ค SDK แล้วพบว่า DSL นี้ bind ได้แค่หัวคอลัมน์เท่านั้น
   (`compiler.dart:5112-5163`, ไม่มี itemBuilder/field-mapping ต่อคอลัมน์เลย)
   ทั้งสอง widget ไม่เคยถูกใช้ในโปรเจกต์นี้มาก่อนด้วย — ทำ `ListView` + แถวหัว
   ตาราง static แทน (ดูเป็นตารางแต่ proven 100%)
8. **ทางเข้า: ไอคอนใหม่บน header ของ `Home`** ต่อจาก `NotificationsBellButton`,
   **แตะแถวผู้ใช้เปิด `UserProfileCard` เดิมจาก D-55** ผ่าน `openProfileChain`
   ที่ยัง defined อยู่ในสคริปต์ — reuse ตรง ๆ ไม่สร้าง popup ใหม่

**กับดักที่ตรวจพบ+แก้ก่อนลงมือ (pete สั่งให้ทวนก่อนเริ่ม):**
- `PendingProductsList`'s `ensureReplaced` (PT-19) — key ดริฟต์ไปแล้วจริงจาก
  push ของ D-55 ก่อนหน้า (`ListView_qglcpyh5` → `ListView_l1lk6db9`) แก้ก่อนพุช
  แรกของงานนี้ ไม่งั้นพุชแรกจะ fail ด้วยเหตุผลที่ไม่เกี่ยวกับหน้าใหม่เลย
- SQL: ต้อง `CREATE OR REPLACE VIEW` ให้เลิกอ้างคอลัมน์ `faculty` ก่อน
  `DROP COLUMN` เสมอ (สลับลำดับชน dependency error ของ Postgres ทันที)
- ไม่ต้อง `GRANT` เพิ่มให้ตาราง/view ใหม่ — โปรเจกต์นี้มี default privileges
  ระดับ schema ที่ให้ `anon`/`authenticated` อัตโนมัติอยู่แล้ว (ยืนยันจาก
  `notifications` ตารางเก่า)

**กับดักที่เจอเพิ่มระหว่างทำ (ไม่เคยบันทึกมาก่อน):**
- **View ใหม่ที่ยังไม่เคยมี consumer ต้อง register เป็น typed table ผ่าน
  `postgres_helpers.addTable` ก่อน DSL อ้างถึงได้** — `flutterflow ai
  refresh-context` เฉย ๆ **ไม่ทำให้** table/view ที่สร้างตรงใน Supabase
  กลายเป็น `ff.Tables.*` handle อัตโนมัติ ต้อง registration guard ด้วย
  `findTable`/`addTable` แบบเดียวกับที่ `admin_dashboard_stats` เคยต้องทำ
  (ไม่ใช่แค่ view เก่าที่มี consumer อยู่แล้วอย่าง `public_profiles`) — ต้องอยู่
  **คนละพุช** จากพุชที่ page/component อ้างถึงมัน (PT-17 compile order)
- **ห้ามห่อ `ListView` เป้าหมายของ `ensureReplaced` ด้วย `Expanded`** — ยืนยันซ้ำ
  จาก D-55 อีกครั้ง ใช้ `shrinkWrap: true` แทนตั้งแต่แรก ไม่ต้องเจอ error ซ้ำ
- 🔴 **outputAs ที่ unique ตามกฎ D-39 แล้วก็ยัง collide ได้** — ให้แต่ละ chip
  widget's query action มี outputAs ไม่ซ้ำกัน (`directoryFaculty1_Selected` ฯลฯ)
  แล้วก็ยัง validate fail ด้วย "output variable with the same name as that of
  another widget" อยู่ดี เฉพาะ chip index 1 (ทดสอบแล้วว่าไม่ใช่บั๊ก closure/loop —
  unroll เป็น literal ตรง ๆ ก็ยังพัง) แก้ได้ด้วยการเปลี่ยน**รูปแบบการตั้งชื่อ**
  ทั้งชุดให้ไม่มี pattern ตัวเลข/prefix ร่วมกับ chip แกนอื่น (เช่นเปลี่ยนจาก
  `directoryFaculty{i}_{tag}` เป็น `facQry{letterTag}_{tag}`) — root cause ไม่
  ทราบแน่ชัด (คาดว่า internal identifier collision/normalization บางอย่าง) ถ้า
  เจอ outputAs collision ที่ "unique แล้วแต่ก็ยัง error" ให้ลองเปลี่ยนรูปแบบชื่อ
  ทั้งชุดก่อนคิดว่าสคริปต์ยังผิด

**ยืนยันจาก `generated_code/`:** `user_directory_widget.dart` (filters จริงทุก
chip, `shrinkWrap: true`, tap เรียก `openProfileChain`) + `home_widget.dart`
(diff กับไฟล์ backup ยืนยันว่ามีแค่ปุ่มไอคอนใหม่เพิ่มเข้ามา ไม่กระทบช่องค้นหา/chip
หมวดหมู่สินค้าเดิม)

**ยังไม่ได้ทดสอบผ่านแอปจริงโดย pete**

---

## D-57 — `ProfileUser` เพิ่ม Dropdown ชั้นปี/คณะ ให้ผู้ใช้กรอกข้อมูลตัวเองได้จริง (2026-08-22)

**ปัญหา:** D-55/D-56 สร้างช่องทางแสดงผล (`UserProfileCard`) + กรอง
(`UserDirectory`) ของ `year_of_study`/`faculty` ไปแล้ว แต่ไม่เคยมีที่ให้ผู้ใช้
**กรอกข้อมูลตัวเอง** เลยสักจุด — `ProfileUser`'s `RenameProfileSection` มีแค่ช่อง
แก้ชื่อ (`NewFullNameField`+`SaveFullNameButton`)

**ตัดสินใจหลัก:**

1. **`Dropdown` (ไม่ใช่ chip) สำหรับฟอร์มแก้โปรไฟล์ตัวเอง** — ต่างจาก `UserDirectory`
   (D-56) ที่เลือก chip เพราะเป็น browse/filter UI, ที่นี่เป็น single-select form
   field ธรรมดา `Dropdown` เหมาะกว่า — `WidgetValue()` (references.dart: "intended
   for widgets like Dropdown, Checkbox, and Toggle") คือทางอ่านค่าที่เพิ่งเลือกใน
   `onChanged` ของมันเอง
2. **แต่ละฟิลด์ (ชื่อ/ชั้นปี/คณะ) เซฟแบบ optional อิสระ ("เว้นว่างไว้เท่าเดิม" ตามที่
   pete สั่ง)** — ปุ่ม "บันทึกข้อมูลโปรไฟล์" ยิง `PostgresUpdate` แยกต่อฟิลด์ ครอบด้วย
   `If(field ไม่ว่าง/ไม่ใช่ sentinel, then: [update], orElse: [])` — ไม่ใช่ update
   ก้อนเดียวรวมทุก field เพราะจะเผลอเขียน NULL ทับค่าที่เคยตั้งไว้ก่อนหน้าทุกครั้งที่
   แก้แค่ชื่ออย่างเดียว
3. **แปลงค่า Dropdown (string) เป็น int (`year_of_study`/`faculty_id`) ที่
   `onChanged` ของ Dropdown เอง ไม่ใช่ตอนกดบันทึก** — เหตุผลเต็มอยู่กับดักข้อ 5-6
   ด้านล่าง (ข้อจำกัดใหม่ที่เพิ่งเจอ)
4. **โปรไฟล์ที่เพิ่งบันทึกไหลไปโชว์ใน `UserProfileCard` (D-55) อัตโนมัติทันที
   ไม่ต้องต่อสายอะไรเพิ่ม** — chain สำเร็จรูปอยู่แล้ว: `ProfileUser` เขียน
   `Profile.year_of_study`/`faculty_id` → `public_profiles` (D-56) join
   `faculties` → `loadViewedProfile` (D-55) อ่านคอลัมน์ชื่อเดิม `faculty`/
   `year_of_study` เป๊ะ ไม่มีจุดไหนต้องแก้เพิ่มเลย

**กับดักใหม่ที่เจอระหว่างทำ (สำคัญมาก จดไว้ละเอียดใน `PATTERNS.md` PT-31):**

5. **`ff.Tables.profile`'s typed field ค้างมาตั้งแต่ก่อน D-52 — ไม่มี
   `year_of_study`/`faculty_id` (และ `student_id`/`ban_reason`/`banned_at`/
   `banned_by`) เลย** ทั้งที่คอลัมน์เหล่านี้มีจริงใน DB มานานแล้ว เพราะทุกที่ที่เคย
   เขียน/อ่านคอลัมน์พวกนี้ผ่าน custom action (`Supabase.instance.client` ตรง ๆ)
   หรือผ่าน view ที่ลงทะเบียนแยก (`admin_users_view`) ไม่เคยผ่าน
   `PostgresQuery`/`PostgresUpdate` ทับ `ff.Tables.profile` ตรง ๆ มาก่อนเลยสักครั้ง
   จนกระทั่งงานนี้ — ต้อง `postgres_helpers.addTableField` เพิ่ม 2 field ที่ใช้จริง
   (ไม่ได้ไล่แก้ครบทุกคอลัมน์ที่ขาด นอก scope งานนี้)
6. **🔴 [สำคัญ] widget หนึ่งตัวมี action ที่ผลิต "output variable" ได้สูงสุด 5 ตัว
   เท่านั้น — เกินแล้ว collide ไม่ว่าจะตั้งชื่อ unique แค่ไหนก็ตาม** — ค้นพบใหม่
   ระหว่างพยายามทำปุ่มเดียวอัปเดต 3 field (ชื่อ+ชั้นปี×4 branch+คณะ×4 branch+
   refetch = 10 action) validate fail ซ้ำ ๆ ด้วย "output variable ... same name"
   ลองเปลี่ยนชื่อ 3 รอบ (ไม่ช่วย) จนสลับลำดับ branch แล้วเห็นว่า**ตัวที่ 6 เป็นต้นไป
   fail เสมอไม่ว่าจะเป็น field ไหน** — สรุปว่าเป็น limit จริงของ SDK ไม่ใช่ปัญหาการ
   ตั้งชื่อ ทางแก้: ย้าย string→int conversion (4 branch ต่อ field) ไปทำที่
   Dropdown's `onChanged` ด้วย `SetState` ล้วน (ไม่มี outputAs เกี่ยวข้องเลย ไม่โดน
   limit นี้) เหลือแค่ 4 action ที่ปุ่ม (name/year/faculty update + refetch)

**ยืนยันจาก `generated_code/lib/profile_user/profile_user_widget.dart`**
(Dropdown จริงทั้งคู่, `selectedYearValue`/`selectedFacultyValue` int แปลงจริงใน
onChanged, ปุ่ม conditional update 3 field + refetch) — diff กับไฟล์ backup
ยืนยันว่ามีแค่ `RenameProfileSection` ที่เปลี่ยน ส่วนอื่นของหน้า (avatar/Active
toggle/Edit Profile/Account Settings/Log Out) ไม่กระทบเลย

**ยังไม่ได้ทดสอบผ่านแอปจริงโดย pete**

---

## D-58 — Admin advertisement posts + likes บน `Home` (`ListView_6etuspo6`) (2026-08-22)

**ปัญหา:** `ListView_6etuspo6` บน `Home` เป็น static placeholder ทิ้งจาก template
เดิม (2 การ์ดข่าวปลอม ไม่ผูกข้อมูล) — pete ขอให้โชว์รูปประกาศที่แอดมินโพสต์ พร้อม
ฟีเจอร์ไลก์เล็ก ๆ และหน้าแอดมินสำหรับสร้างโพสต์ใหม่

**ตัดสินใจหลัก:**

1. **รูปเดียวต่อโพสต์ ไม่ใช่ grid หลายรูปแบบ `products`** — เป็น banner/ประกาศ
   ไม่ใช่สินค้า ไม่ต้องการความซับซ้อนแบบเดียวกัน
2. **`is_active` soft-hide แทน hard delete** — แอดมิน "ลบ" โพสต์คือ flip flag
3. **ไลก์แบบ per-user จริง (junction table `advertisement_likes`, composite PK)**
   ไม่ใช่ counter column เปล่า ๆ — pete เลือกแบบนี้เมื่อถามตรง ๆ (กันกดไลก์ซ้ำ,
   รองรับ unlike, นับจริง) ตรงกับ pattern junction table เดิมของโปรเจกต์
   (`chat_user`/`reports`)
4. **การ์ดไม่โชว์ผู้โพสต์** — เป็นประกาศของระบบ ไม่ต้อง join `public_profiles`
5. **admin gate ใช้ `IsCurrentUserAdmin` เดิมซ้ำ** (custom action เดียวกับที่
   `login_widget.dart` ใช้แยก Home/HomeAdmin) ไม่สร้าง gate ใหม่
6. **ปุ่มไลก์/เลิกไลก์ refetch เต็มแทน optimistic update ฝั่ง client** — DSL ไม่มี
   per-item state mutation สำหรับ ListView ที่ผูกกับ Postgres โดยตรง (มีแค่
   `StateFieldUpdate.removeAtIndex`/`insertAtIndex` สำหรับ AppState-backed list)
   list จำกัด 20 แถวอยู่แล้วทำให้ refetch เต็มไม่แพง

**กับดักใหม่ที่เจอระหว่างทำ:**

7. **table ใหม่ที่สร้างตรงใน Supabase + ถูกอ้างจากหน้า/component ใหม่ในพุชเดียวกัน
   พังด้วย "Table was not compiled"** (PT-15/PT-30 ยืนยันซ้ำ) — compiler compile
   หน้า/component ใหม่ *ก่อน* apply `app.raw` mutation เสมอ ส่วน edit บนหน้าที่มี
   อยู่แล้ว (`editPageOnLoad`ฯลฯ) ปลอดภัยในพุชเดียวกัน แก้ด้วยแยก 4 พุช: (1)
   register ตาราง + rebind `Home` (หน้าเดิม) (2) `ensurePage` shell เปล่า (3) body
   จริง + admin gate + nav entry (4) raw-proto patch bucket/path ของปุ่มอัปโหลด
8. **`PostgresCreate`/`PostgresDelete` ไม่ใส่ `outputAs` default เป็น `'rows'`
   เสมอ** — สอง widget บนหน้าเดียวกันชนกันทันทีถ้าไม่ตั้งชื่อเอง (บทเรียนเดิมที่
   เคยเจอมาแล้วที่ `insertAndRefetchChain`, ย้ำอีกครั้งเพราะพลาดซ้ำ)
9. **🔴 คีย์ state field ต้องอ่านจาก generated schema ตรง ๆ ห้ามเดาจาก grep ผลรวม
   หลายบรรทัด** — พุชแรกของ raw-proto capture node ผูก URL ที่อัปโหลดเข้าผิด field
   (`body` แทน `imageUrl`) เพราะ grep คนละ pattern คืนบรรทัด key/name ของคนละ field
   มาอยู่ติดกันโดยบังเอิญ จับได้จาก `generated_code/` ก่อนส่งมอบ แก้ด้วยพุชแก้ไข
   เดี่ยว — บทเรียน: อ่านไฟล์ตรง ๆ (`Read` ทั้ง state class) แทน grep เดายามมีหลาย
   field ชื่อคล้ายกัน

**ยืนยันจาก `generated_code/`:** `Home`'s `AdPostsList` ผูก `_model.adPosts`
จริง พร้อมปุ่มไลก์/เลิกไลก์ที่ยิง insert/delete บน `advertisement_likes` +
refetch; `AdminCreatePost` มี on-load gate เรียก `isCurrentUserAdmin()`,
ปุ่มอัปโหลดรูปเข้า bucket `ad-post-images` ผูก URL เข้า `imageUrl` ถูกต้อง,
ปุ่มโพสต์ insert เข้า `advertisement_posts` ครบ 3 field; `HomeAdmin` มี nav
item ใหม่ navigate ไปหน้านี้จริง

**ยังไม่ได้ทดสอบผ่านแอปจริงโดย pete** — RLS ยืนยันด้วย impersonation test จริง
แล้ว (non-admin insert/update/delete โพสต์ถูกบล็อก, ไลก์แทนคนอื่นถูกบล็อก, admin
insert สำเร็จ) ผ่าน SQL โดยตรง แต่ยังไม่เคยกดผ่านแอปจริง

---

## D-61 — `products.category_id` เป็น `NOT NULL` (2026-08-24)

**บริบท:** pete สั่งทำ L2/L3 ต่อจาก Realtime — คำถามค้างเดิมเรื่อง `category_id` nullable

**ตัดสินใจ:** บังคับ `NOT NULL` — เช็คก่อนว่า 0 แถว null จาก 10 แถวทั้งหมด ไม่ต้อง backfill apply ตรงตามกฎข้อ 5 (ปลอดภัย + ไม่มีข้อมูลชนกัน)

**คำถามอื่นของ L2 ที่ถามพร้อมกัน — ตอบแล้วทั้งคู่:** ไม่เปิด browse ก่อน login (คงต้อง auth เหมือนเดิม) · ไม่ทำ `"CAT"` admin CRUD UI (manual SQL seed พอ) — ไม่มีอะไรต้องทำเพิ่มสำหรับสองข้อนี้

## D-62 — RPC `search_products()` — substring search จริงครั้งแรก ปิดข้อเสนอ P-05 (2026-08-24)

**บริบท:** D-45–D-48 สรุปไว้ว่า `iLike`/`like`/`contains` ไม่มี null-safe codegen เลยในระบบนี้ ค้นหาเลยถอยเป็น exact match มาตลอด pete สั่งให้ทำ substring จริงรอบนี้แทนที่จะปล่อยไว้

**สถาปัตยกรรมที่ใช้ได้จริง (ยืนยันจาก `generated_code/` ทุกจุด ไม่ใช่แค่ push ผ่าน):**

1. RPC `search_products(keyword, p_category_id, min_price, max_price)` — `RETURNS SETOF products_review_view`, ทุกพารามิเตอร์ optional, ANDed กัน (`SCHEMA.md`)
2. เรียกผ่าน custom action **0-argument** `searchProducts` — ไม่ใช่ `Actions.callSupabaseRpc` (typed DSL) เพราะต้อง sync RPC schema จาก Supabase เข้า FlutterFlow ก่อน (`Settings → Supabase → Get Schema`) ซึ่งเป็น manual GUI action ที่ CLI/MCP ไม่มีทางเรียกได้ — ลอง `flutterflow ai refresh-context`/`resources` แล้วไม่เจอ `search_products` ใน registry เลย ยืนยันว่าทางนี้ตันจริง ไม่ใช่แค่ยังไม่ได้ลอง
3. 0-argument เพราะ **`CallCustomAction` ส่ง argument ไม่ได้เลยในเวอร์ชัน SDK นี้ (PT-09, บั๊กเก่าตั้งแต่ L1)** — action อ่าน `keyword`/`categoryId`/`minPrice`/`maxPrice` จาก App State เอง (relay pattern เดียวกับ `pendingChatProductId`/`pendingSoldChatId`)
4. **ค้นพบใหม่ที่สำคัญที่สุด:** `SetState` บนฟิลด์ `List<PostgresRow>` (`Home.productsList`) **รับค่าจาก `CallCustomAction`'s `ActionOutput` ได้จริง** — ไม่ใช่ข้อจำกัดเดียวกับที่ D-45 เจอ (ตอนนั้น custom **FUNCTION** ถูกปฏิเสธ เพราะเป็น value-expression คนละ node kind กับ custom **ACTION** ที่ผลิต `ActionOutput` แบบเดียวกับ `PostgresQuery`) เปิดทางให้ RPC-backed list มาแทน typed-filter ได้เต็มรูปแบบ โดยไม่ต้องแก้ ListView/itemBuilder ที่มีอยู่แล้วเลยสักจุด — รายละเอียด `PATTERNS.md` PT-33
5. Realtime ทดลองก่อน (D-60's spirit): ลอง `isStreamingSupabaseQuery: true` บน action-based `PostgresQuery` ก่อนไปทาง RPC — **ไม่เกี่ยวกับเรื่องนี้โดยตรง แต่ยืนยันซ้ำว่า flag นั้น inert นอก page-level `databaseRequest`** (ตรงกับที่บันทึกไว้ใน PT-32)

**ผล:** onLoad + search submit + ปุ่ม "ค้นหา" + pull-to-refresh + category chip ทั้ง 13 หมวด (26 variant) เปลี่ยนมาเรียก RPC เดียวกันหมด ลด duplicated `PostgresQuery` block ลงมาก ปิดข้อเสนอ P-05 ใน `PROPOSED_SQL.md` — **ยังไม่ทดสอบผ่านแอปจริง**

## D-63 — ช่วงราคา (price range) บน `Home` (2026-08-24)

**บริบท:** ทำพร้อม D-62 เพราะใช้กลไกเดียวกัน (RPC มี `min_price`/`max_price` อยู่แล้ว) — ไม่ใช่คำถามที่ pete ตอบตรง ๆ แต่เป็นช่องว่างที่ระบุไว้ชัดใน `STATUS.md`/`L3-browse-search.md` มาตั้งแต่ D-45

**ตัดสินใจ:** เป็น**แกนอิสระ** ไม่ผูกกับ/ไม่ล้างโดย keyword search หรือ category chip (ต่างจาก search↔category ที่ยังล้างกันเองเหมือนเดิม) — กด "กรอง" ราคาแล้วค่าคงอยู่จนกว่าจะเปลี่ยนเอง แม้สลับหมวดหมู่/ค้นหาใหม่

**กับดักที่เจอ:**
- App state ประกาศ `double_` ก่อน แล้วพบว่า `WidgetState(...).text` เป็น `String` เสมอ (TextField ไม่มี numeric variant ใน `WidgetStateProperty`) — ผูก String เข้า Double field ตรง ๆ เป็นเส้นทาง type-coercion ที่ไม่เคยพิสูจน์มาก่อนในโปรเจกต์นี้ (ความเสี่ยงแบบเดียวกับ D-45/D-46 ที่เจอมาแล้วหลายรอบ) เปลี่ยนเป็น **String app state + parse เองด้วย `double.tryParse` ในโค้ด custom action** แทน (ปลอดภัยกว่า ไม่พึ่ง DSL coerce เลย)
- เปลี่ยน type ของ app state ที่มีอยู่แล้วต้องใช้ `updateAppStateField(...)` ไม่ใช่ `app.state(...)` ซ้ำ — `app.state` เป็น create-if-missing เท่านั้น throw ถ้า payload ต่างจากของเดิมบน backend
- `WidgetState` อ้างอิง widget ที่มี typed handle แล้วต้องใช้ `ff.Pages.x.widgets.byKey(key).single` ไม่ใช่ชื่อ string ดิบ (เหมือนกฎเดียวกับ `ff.AppState.x`) — error message บอกตรง ๆ ไม่ต้องเดา
- ปุ่ม "กรอง" อ้างอิง TextField ที่เพิ่ง insert ในพุชเดียวกันไม่ได้ (PT-22) ต้องแยก 2 พุช (insert ก่อน ไม่ผูก onTap → ผูก onTap พุชถัดไปด้วย key จริง) เหมือนที่เคยเจอกับ chatMessages' SendMessageButton

**ผล:** ยืนยันจาก `generated_code/` ว่า compile ถูกทุกจุด (`FFAppState().searchPriceMin = _model.minPriceFieldTextController.text;` ฯลฯ) — **ยังไม่ทดสอบผ่านแอปจริง**

---

## D-60 — Realtime (chat + Notifications) เปิดจริงครั้งแรก, ปิดหนี้ D-32 บางส่วน (2026-08-24)

**บริบท:** pete สั่งเคลียร์ Realtime (chat+notification) ก่อนงานอื่น — ยืนยันไปแล้วว่าไม่มีเลยจริง ๆ ใน FlutterFlow (D-32) ทั้งที่ Supabase publication เปิดไว้ก่อนแล้วสำหรับ `chat`/`chat_message`/`products`

**ตัดออกจากสโคปนี้ตามที่ pete สั่งตรง ๆ ก่อนเริ่ม:** unread badge ตัวเลข (จุดแดงเดิม D-49 พอ) · P-04 (สร้าง notification จากข้อความแชทใหม่ ยังไม่ตัดสินใจ) · dedicated test account (ใช้บัญชีเพื่อน pete จริงแทน แล้วลบทิ้ง)

**กลไกที่ใช้ได้จริง (ยืนยันจาก `generated_code/`, ไม่ใช่แค่ push ผ่าน):**
- `isStreamingSupabaseQuery` (bool บน `FFPostgresQuery`) ต่อกับ **page-level `databaseRequest`** (raw proto, เทคนิคเดียวกับ `ProfileUser`) เท่านั้นที่ compile เป็น `StreamBuilder` + `SupaFlow.client.from(...).stream(...)` จริง — 🔴 **ลองใส่ flag เดียวกันบน action-based `PostgresQuery` (ใน onLoad chain) ก่อน ไม่ทำงาน** ยัง compile เป็น one-shot `.queryRows()` เหมือนเดิม (ยืนยันด้วยพุชจริง 1 ครั้งแล้วอ่าน `generated_code/`) — จำไว้อย่าลองซ้ำ
- `databaseRequest` ที่ตั้งไว้ไม่ผูกกับ widget ไหนเลย (ไม่มี UI แสดงผลตรง ๆ) มีไว้ถือ subscription เฉยๆ แล้วต่อ trigger `ON_DATA_CHANGE` (`page.ensureActions(page.root, triggerType: ON_DATA_CHANGE, ...)`) ให้รัน onLoad query+SetState เดิมซ้ำ — ของเดิมไม่ต้องแก้เลย เพิ่มแค่ 2 บล็อกต่อหน้า
- Realtime target เป็น **base table เท่านั้น** (`chat_message`, `notifications`) ไม่ใช่ view (D-29) — `chatList`/`chatMessages` ฟังที่ `chat_message` แล้ว refetch view (`chat_summary`/`chat_messages_view`) ตามเดิม, `Notifications` ฟัง `notifications` ตรง ๆ (ไม่ใช่ view อยู่แล้ว)
- ทำสำเร็จ 3 หน้า: `Notifications` (validation spike ตัวแรก) → `chatList` (ฟัง `chat_message` ไม่มี filter เหมือน onLoad เดิม) → `chatMessages` (ฟัง `chat_message` filter `chat_id`)

**ปิดหนี้พ่วง — `findOrCreateChatWithSeller` (L4-chat.md ข้อ 3):** เดิมปุ่ม "แชทกับผู้ขาย" ส่งแค่ `chatId` ทำให้ `memberNames`/`userIds` เป็น null ตอนเข้าห้องแชทใหม่ทางนี้ แก้ด้วยให้ custom action query `chat_summary` (ตัวเดียวกับที่ `chatList` ใช้อยู่แล้ว — `member_names`/`user_ids` เป็น `array_agg` พร้อมใช้) ทันทีหลัง `find_or_create_chat` คืน `chatId` แล้ว relay ผ่าน app state ใหม่ 2 ตัว (`pendingChatMemberNames`/`pendingChatUserIds`) — pattern เดียวกับ `pendingChatProductId` เดิม

**กับดักใหม่ที่เจอ:** `app.state('x', listOf(string).withDefault([]))` throw ที่ compile time ("Default values are not supported for type ListType...") — ต่างจาก page param ที่รับ default เงียบๆ แต่ไม่ถึง constructor จริง (PT-23) · SDK บังคับใช้ `ff.AppState.x` แทนชื่อ string ดิบเมื่อ field มี typed handle อยู่แล้ว (validation error ชัดเจน ไม่ใช่เดา) · `varFromPageParam`/`variable_helpers.dart` ไม่ได้ export จาก barrel หลัก ต้อง import ตรงจาก `src/helpers/` เหมือน `postgres_helpers`/`custom_code_helpers`

**ยังไม่ทำ (ตัดสโคปไว้แล้ว ไม่ใช่ค้าง):** unread badge, P-04, notification/push จริงตอนปิดแอป — รายละเอียด `layers/L4-chat.md`/`layers/L6-notifications.md`, pattern ใหม่ `PATTERNS.md` PT-32 — **ยังไม่ทดสอบผ่านแอปจริง** (รอ pete + บัญชีเพื่อน)

---

## D-59 — Layer 5 (Transaction & Listing Status) เริ่มและปิดครบ + ปิดหนี้ D-03 (2026-08-23)

**บริบท:** pete สั่งสเปค "ปิดการขาย" — เจ้าของประกาศเลือกผู้ซื้อจาก
`chatMessages` แล้วกดขาย มีป๊อปอัพยืนยัน ของหายจาก grid สาธารณะ ยอดขายรวมโชว์
ใน `HomeAdmin`, `Mypost` ยังเห็นของตัวเองที่ขายแล้ว, ผู้ซื้อโชว์เฉพาะเจ้าของ/แอดมิน
+ ขอ **ตาราง `transactions` แบบ query ได้จริง** ไม่ใช่แค่ flag บน `products`

**ตัดสินใจหลัก (ยืนยันกับ pete ตรง ๆ ก่อนเริ่ม):**

1. **flow อยู่ที่ `chatMessages` (`Scaffold_o6ieoidd`) ไม่ใช่ `ProductDetails`**
   — chat เป็น thread คู่ 1-1 ไม่ผูก `product_id` เลย (`ChatMessagesParams` มีแค่
   `chatId`/`memberNames`/`userIds`) ผู้ซื้อคือคู่สนทนาอีกฝั่งอยู่แล้ว สิ่งที่ต้อง
   เลือกจริงคือ "ประกาศไหนของฉัน" ไม่ใช่ "ใครคือผู้ซื้อ"
2. **ผู้ซื้อโชว์เฉพาะเจ้าของ + แอดมิน** ไม่ใช่ผู้ซื้อเองหรือสาธารณะ
3. **ปุ่ม "ปิดการขาย" ต้องซ่อนเมื่อ:** ไม่มีประกาศให้ขาย (ไม่มี listing
   `available`/`approved` ของตัวเอง), แชทนี้เคยขายไปแล้ว, บัญชีถูกแบน
4. **ปิดหนี้ D-03 (`products` allow-all) ไปพร้อมกัน** — ไม่ใช่แค่ทำ L5 แล้วปล่อย
   ช่องโหว่เดิมไว้ต่อ pete เลือกตัวเลือก "ปิดให้ครบ" เมื่อถามตรง ๆ

**สถาปัตยกรรม (Supabase, ทุกจุด impersonation-test แล้วจริงก่อนแตะ FlutterFlow):**

- `products.status` เดิม nullable ไม่มี `CHECK` → backfill NULL→`'available'`,
  เพิ่ม `CHECK IN ('available','reserved','sold')`, `DEFAULT 'available' NOT NULL`
  (NOT NULL ทำให้ filter ฝั่ง DSL ใช้ `notEqualTo` ตรง ๆ ได้ ไม่ต้องเลี่ยง null
  แบบ D-48) + คอลัมน์ใหม่ `buyer_id uuid REFERENCES "Profile"(id) ON DELETE SET NULL`
- ตาราง `transactions` ใหม่ (`product_id`/`buyer_id`/`seller_id` ทุกตัว
  `ON DELETE SET NULL` ตาม precedent `reports.reported_product_id`/D-24 — ไม่ลบ
  ประวัติทิ้งเพราะสินค้า/บัญชีถูกลบทีหลัง, `price` snapshot ตอนขาย, `status`
  `NOT NULL DEFAULT 'completed' CHECK (status='completed')` เพราะ flow นี้ไม่มี
  pending/cancelled, `chat_id` เก็บว่าขายจากแชทไหน) RLS แบบ PERMISSIVE ธรรมดา
  (`buyer_id=auth.uid() OR seller_id=auth.uid() OR is_admin()`) — ไม่มี
  INSERT/UPDATE/DELETE policy ให้ authenticated เลย เขียนได้ทางเดียวผ่าน RPC
- RPC `mark_product_sold(target_chat_id, target_product_id)` (`SECURITY DEFINER`,
  แบบเดียวกับ `admin_set_user_ban`/D-52): เช็ค `is_banned()`/`is_chat_member()`
  เอง (bypass RLS ของ SECURITY DEFINER ไม่ครอบคลุมเรื่องนี้), หาผู้ซื้อจาก
  `chat_user` ตัดตัวเอง, conditional `UPDATE ... WHERE status IS DISTINCT FROM
  'sold'` (PT-05, กัน race), `INSERT INTO transactions` ในฟังก์ชันเดียวกัน (เลี่ยง
  select-back ตาม D-24) — impersonation-test ครบ: ขายสำเร็จ, ขายซ้ำถูกบล็อก,
  non-member ถูกบล็อก
- `products_review_view` เพิ่ม `buyer_id`/`buyer_name` (join `public_profiles`
  ตาม PT-01) + `can_see_buyer` (`COALESCE(status='sold' AND (seller_id=auth.uid()
  OR is_admin()), false)`) — คอมพิวต์เงื่อนไข owner-or-admin ที่ SQL ครั้งเดียว
  ฝั่ง DSL ผูก raw variable ตัวเดียว ไม่ต้องแต่ง AND/OR เองที่ raw-proto (ไม่มี
  combinator นี้ใน SDK — เช็คแล้วจาก actions.dart)
- `admin_sales_by_seller` (ของเดิมอ้าง `products.status='sold'` ตรง ๆ เป็น
  stand-in ชั่วคราวตามที่ `SCHEMA.md` เตือนไว้ตั้งแต่แรก) **repoint ไปอ้าง
  `transactions` แทน** คอลัมน์ชื่อ/type เดิมทุกตัว → **`HomeAdmin`'s
  `SalesBySellerList` ไม่ต้องแก้ DSL เลย** ได้ข้อมูลจริงทันทีที่มีคนขายของ
- **ตาราง/view ใหม่เพื่อเลี่ยง `listLength()`:** `chat_sale_status_view`
  (`chat_id`, `chat_already_sold`, `can_show_picker`) คอมพิวต์เงื่อนไขซ่อนปุ่ม
  ทั้ง 3 ข้อ (มีของขาย + ยังไม่เคยขายในแชทนี้ + ไม่ถูกแบน) เป็น boolean เดียวใน
  SQL — **D-46 เคยพิสูจน์แล้วว่า `listLength()`/boolean จาก custom function ถูก
  backend ปฏิเสธทั้งคู่** เลี่ยงโดยให้ SQL ตอบ boolean ตรง ๆ แล้วผูกผ่าน
  `item['field']` ใน itemBuilder (proven pattern, ไม่ใช่ raw-proto ใหม่)
- **ปิดหนี้ D-03:** ถอด policy `"Allow all for authenticated users"` บน
  `products` แทนด้วย 4 policy ตาม cmd จริง (`SELECT` เปิดกว้างเหมือนเดิมเพื่อให้
  browse ได้ปกติ, `INSERT` ต้อง `seller_id=auth.uid()`, `UPDATE`/`DELETE` ต้อง
  `seller_id=auth.uid() OR is_admin()`) RESTRICTIVE เดิม 3 ตัว (D-52) + trigger
  moderation (D-23) ยังทำงานถูกทับได้ตามปกติเพราะ RESTRICTIVE แคบกว่า PERMISSIVE
  เสมอไม่ว่าฐานจะกว้างแค่ไหน — เพิ่ม trigger ใหม่
  `enforce_sale_via_rpc_only` บล็อกการเปลี่ยน `status`/`buyer_id` ตรง ๆ
  ไม่ว่าใคร (แม้เจ้าของ/แอดมิน) ให้ผ่านได้ทาง `mark_product_sold` เท่านั้น (เช็ค
  session-local flag `app.via_mark_sold_rpc` ที่ RPC ตั้งก่อน `UPDATE` ของตัวเอง)
  — impersonation-test ครบ: non-owner แก้ราคาคนอื่นไม่ได้, owner แก้ราคาตัวเองได้
  แต่แก้ `status` ตรงไม่ได้แม้เป็นเจ้าของ, admin ก็แก้ `status` ตรงไม่ได้เหมือนกัน
  (ตั้งใจ ไม่มีข้อยกเว้น), flow เดิม (moderation approve/reject) ไม่กระทบ

**FlutterFlow (5 พุช, เรียงตามลำดับ compile — PT-17):**

R1/R2 register field/table ใหม่ (`products.buyer_id`,
`products_review_view.buyer_id/buyer_name/can_see_buyer`, `transactions`,
`chat_sale_status_view`) → P2 `chatMessages` (custom action 0-arg
`markProductSold` อ่าน `FFAppState()` ตาม PT-09, panel แบบฝังในหน้าไม่ใช้
`ShowBottomSheet` — เลี่ยงความเสี่ยง 2 อย่าง: ส่ง List เป็น component param
(ไม่เคยมี precedent ในโปรเจกต์นี้) และเพิ่ม page-level `databaseRequest` ให้หน้า
ที่ทดสอบผ่านแล้ว (D-40/D-41) ซึ่งจะห่อทั้งหน้าด้วย `FutureBuilder` ใหม่โดยไม่จำเป็น)
→ P3 `Home` เพิ่ม filter `status != 'sold'` ใน 3 จุด (onLoad,
`buildSearchRefreshChain`, `homeCategoryTapActions` — ไม่ใช่ 33 จุดแยกกันตามที่
กังวลตอนแรก เป็น 3 ฟังก์ชันต้นทางที่ compile ออกมาเป็น ~31 call site) พร้อมบั๊ก
outputAs เดิม (PT-27 §2) → P4 `Mypost` เพิ่ม `SoldBadge` ในแถวเดิม (ไม่ต้องแก้
query เลยเพราะ D-35 filter แค่ `seller_id`/`moderation_status` อยู่แล้ว) → P5
`ProductDetails` เพิ่ม `BuyerInfoSection` ผ่าน `productField()`/nodeKeyRef เดิม
จาก D-44/D-51 (คนละ closure ต้อง redeclare helper ใหม่เพราะตัวเดิมปิด scope
ไปแล้ว)

**กับดักใหม่ที่เจอระหว่างทำ:**

- **`ff.AppState.*` typed accessor อ้างฟิลด์ที่ประกาศในพุชเดียวกันไม่ได้** (เหมือน
  PT-17 §1 ของตาราง แต่เป็น app state) — ใช้ string literal (`AppState('x')`,
  `UpdateAppState.set('x', ...)`) แทนได้ในพุชแรกที่ประกาศ
- **`page.findByKey(...)` ในสคริปต์เก่าอ้าง key ที่ตายไปแล้วจริง** — คีย์ของ
  `Mypost`'s `ListView` ในสคริปต์ยังเป็น `ListView_7h86cihf` แต่ของจริงคือ
  `ListView_z48phx0c` แล้ว (`ensureReplaced` "preserve key" คือ preserve ของ
  รอบที่รันเอง ไม่ใช่ค้ำประกันตลอดไปข้ามเวลาที่ไม่ได้รันสคริปต์เดิมซ้ำ) แก้ด้วย
  `flutterflow ai inspect --outline` สดก่อนแก้จริงตามที่ควรทำตั้งแต่แรก — บทเรียน
  ตรงกับกฎข้อ 9 ของ `CLAUDE.md` (ต้อง inspect ก่อนแตะเสมอ)
- **`Colors.hex(...)` รับ `int` ARGB ไม่ใช่ string `'#RRGGBB'`** — เขียนผิดรอบแรก
  (`Colors.hex('#9CA3AF')`) จับได้จาก `compileDslApp` fail ทันที ไม่ต้องรอ push จริง

**ยืนยันจาก Supabase (impersonation ตรง, ROLLBACK ทุกเทส) + `generated_code/`:**
ครบทั้ง RPC (สำเร็จ/ขายซ้ำ/non-member), RLS overhaul (owner/non-owner/admin),
`chat_sale_status_view` ตอบถูกทั้งฝั่งขาย/ฝั่งซื้อ, DSL คอมไพล์ตรงตามตั้งใจทุกพุช
(เช็คโค้ด generate จริงทีละไฟล์ ไม่ใช่แค่ push ผ่าน) `dart analyze` รันไม่ได้ใน
environment นี้ (`flutter` ไม่อยู่บน PATH ทำให้ import ทุกไฟล์ error ทั้งโปรเจกต์
ไม่ใช่เฉพาะจุดที่แก้ — ไม่ใช่สัญญาณจริง)

---

## D-64 — Layer 7 `reviews` (ให้คะแนนผู้ขาย) เริ่มและปิดครบ ปิดข้อเสนอ P-08 (2026-08-24)

**บริบท:** pete สั่ง "ลงมือได้เลย ดู codebase SQL เดิมด้วย ออกแบบให้เข้ากันได้ง่ายที่สุดจากสถาปัตยกรรมตอนนี้" หลังตอบคำถามยืนยัน 4 ข้อ (ทั้งหมดเลือก Recommended): รีวิว public ให้ authenticated ทุกคนเห็น, จุดเข้าอยู่บน `ProductDetail` เดิม (ไม่สร้างหน้า MyPurchases ใหม่), immutable ตลอดไป (ไม่มี UPDATE/DELETE policy เลย), P-09 (รีพอร์ตผู้ใช้) แยกไปทำทีหลัง

**ตัดสินใจสำคัญ — เปลี่ยนจาก draft P-08 เดิม:** draft เดิมผูก unique key แค่ `(reviewer_id, product_id)` (ร่างไว้ก่อน L5/`transactions` จะมีอยู่จริง) เปลี่ยนมาผูกกับ `transactions` โดยตรงแทน (`transaction_id` FK, `UNIQUE(transaction_id, reviewer_id)`) เพราะ `transactions` (D-59) เป็นแหล่งความจริงเรื่องใครซื้อ-ใครขาย-สินค้าไหนอยู่แล้ว — RLS insert เช็คว่า `reviewer_id = auth.uid()` ตรงกับ `buyer_id` ของ `transaction_id` นั้นจริง และ `reviewee_id` ตรงกับ `seller_id` ของธุรกรรมเดียวกันจริง กันคนที่ไม่เคยซื้อสินค้านั้นจริง insert ไม่ได้เลยที่ระดับ DB

**Schema (Supabase, apply ตรงผ่าน MCP — ตารางว่าง+ปลอดภัย ตาม CLAUDE.md ข้อ 5):**

```sql
CREATE TABLE public.reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id uuid NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
  reviewer_id uuid NOT NULL REFERENCES public."Profile"(id) ON DELETE CASCADE,
  reviewee_id uuid NOT NULL REFERENCES public."Profile"(id) ON DELETE CASCADE,
  rating int NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT reviews_one_per_transaction_reviewer UNIQUE (transaction_id, reviewer_id)
);
```

RLS 3 policy: `reviews_select_all` (SELECT, `authenticated`, `true` — public read ตามคำตอบ pete) · `reviews_insert_buyer_only` (INSERT, `WITH CHECK reviewer_id = auth.uid() AND EXISTS(...transactions ที่ buyer_id/seller_id ตรงกัน...)`) · `reviews_block_banned_insert` (RESTRICTIVE INSERT, `NOT private.is_banned()` — ตาม pattern เดิมของ D-52) **ไม่มี UPDATE/DELETE policy เลย = immutable ตลอดไป**

`products_review_view` เพิ่ม 4 คอลัมน์คอมพิวต์ (แทนที่จะสร้าง view ใหม่ — "ง่ายที่สุดจากสถาปัตยกรรมตอนนี้" ตามที่ pete สั่ง เพราะ `ProductDetails` ผูกกับ view นี้อยู่แล้ว): `seller_avg_rating`/`seller_review_count` (LEFT JOIN subquery `GROUP BY reviewee_id` — pattern เดียวกับ `advertisement_posts_view.like_count`, D-58) · `my_transaction_id` (LEFT JOIN `transactions WHERE buyer_id = auth.uid()`) · `can_rate_seller` (`COALESCE(status='sold' AND my_transaction_id ไม่ null AND ยังไม่เคยรีวิว transaction นี้, false)` — pattern เดียวกับ `can_see_buyer`/`can_show_picker`, D-52/D-59: คอมพิวต์บูลีนที่ SQL ครั้งเดียว ผูก `visible:` ตรง ๆ ไม่ต้องคิด AND/OR ที่ FlutterFlow)

**FlutterFlow (2 พุช, `dsl/edit.dart`):**

- Push 1: register 4 field ใหม่ของ `products_review_view` (PT-15 §6/D-57) + `app.state` 3 ตัว (`pendingReviewProductId`/`Rating`/`Comment`) + custom action `submitSellerReview` (0-arg, อ่าน app state, query `transactions` หา `id`/`seller_id` ของธุรกรรมนี้ตรง ๆ แล้ว insert `reviews` — **ไม่ผ่าน RPC เลย**, เขียน Dart ตรงเหมือน `findOrCreateChatWithSeller`, ไม่จำเป็นต้องมี SECURITY DEFINER เพราะ RLS ที่เขียนไว้อนุญาต insert รูปแบบนี้อยู่แล้ว) + component `RateSellerSheet` (`Slider` 1-5 แทน star rating จริง — DSL ไม่มี `RatingBar` ที่ construct ได้ มีแค่ระดับ proto — + `TextField` คอมเมนต์ + ปุ่มยกเลิก/ส่ง) + แทรกปุ่ม "ให้คะแนนผู้ขาย" บน `ProductDetails` ต่อจาก `ContactAdminButton` พร้อม `onTap` (inline ปลอดภัย ไม่ใช่ find-by-key) แต่ยังไม่ผูก visibility
- Push 2: ผูก visibility ปุ่มเข้ากับ `can_rate_seller` ผ่าน `productField()`/`nodeKeyRef` เดิม (จาก D-44/D-59) — ต้องแยกพุชเพราะ PT-22 (widget ที่เพิ่ง insert ในพุชเดียวกัน ยังไม่รู้ key จริง จน typed SDK regenerate หลังพุชแรกลง)

**กับดักใหม่ที่เจอ:** `UpdateAppState.set(target, value)` — `target` ต้องเป็น **string ธรรมดาหรือ typed field handle** (`resolveProjectFieldName`) **ห้ามห่อด้วย `AppState(...)`** (คลาส `DslExpression` สำหรับ*อ่าน*ค่าเป็น value ในนิพจน์อื่น ไม่ใช่ตัวระบุ target ของ mutation) — ผสมกันแล้วได้ error `Expected a generated FlutterFlow field handle.` ทันทีตอน build DSL (ก่อนถึงขั้น validate/push) จุดสับสน: `AppState('x')` (อ่าน) กับ raw string `'x'` (target ของ `UpdateAppState.set`) หน้าตาคล้ายกันมาก — D-59 เคยโน้ตกำกวมเรื่องนี้ไว้แล้วที่ "กับดักใหม่ที่เจอระหว่างทำ" แต่ยังไม่ชัดพอ บันทึกซ้ำให้ชัดตรงนี้

**Confirmed จาก `generated_code/`:** ทั้ง 2 พุชคอมไพล์ตรงตามตั้งใจ — `submitSellerReview` เรียก `transactions`/`reviews` ตรงตามดีไซน์, `RateSellerSheetWidget` มี `Slider`/`TextFormField`/ปุ่มครบ, ปุ่มบน `ProductDetails` ห่อด้วย `if (...canRateSeller ?? true)` (fallback `?? true` เป็น pattern เดิมของหน้านี้ทั้งหน้า เหมือน `hasSecondImage`/`canSeeBuyer` ไม่ใช่บั๊กใหม่)

**ยังไม่ทำรอบนี้ (ตามคำตอบ pete):** P-09 (รีพอร์ตผู้ใช้) · edit/delete รีวิว · แสดงคะแนนเฉลี่ยที่หน้าโปรไฟล์ผู้ขาย (ทำแค่บน `ProductDetails` ที่ผูกกับ `products_review_view` อยู่แล้ว) · **ยังไม่ทดสอบผ่านแอปจริงโดย pete**

---

## D-65 — P-09: รองรับรีพอร์ต "ผู้ใช้" เริ่มและปิดครบ (2026-08-24)

**บริบท:** pete สั่ง "ลุย P-09/L1 ตามลำดับ" — P-09 เป็นข้อเสนอที่ค้างมาตั้งแต่ D-24 (`reports` มีแค่ `reported_product_id`) และตั้งใจแยกออกจากรอบ `reviews`/D-64 ไว้แล้ว

**Schema:** `reports.reported_user_id uuid REFERENCES "Profile"(id) ON DELETE SET NULL` (pattern เดียวกับ `reported_product_id`) + 2 CHECK ใหม่: `reports_target_required` (ต้องมีอย่างน้อย 1 ใน `reported_product_id`/`reported_user_id`) และ `reports_no_self_report` (`reported_user_id <> reporter_id`, กันรีพอร์ตตัวเองที่ระดับ DB — draft เดิมไม่มี CHECK นี้ เพิ่มเองเพราะเป็นช่องโหว่ตรรกะที่ชัดเจน) + unique partial index `reports_unique_pending_per_reporter_user` (mirror ของเดิม, ปลอดภัยกับแถว product-report เพราะ Postgres ไม่ถือ NULL ชนกันเอง) `reports_admin_view` เพิ่ม 4 คอลัมน์: `reported_user_id`/`reported_user_name` (join `public_profiles` ตาม PT-01) + `is_product_report`/`is_user_report` (boolean คอมพิวต์ครั้งเดียว, pattern เดียวกับ `can_see_buyer`/`can_show_picker`)

**พบและปิดช่องโหว่ crash แฝงไปพร้อมกัน:** `ReportDetailContent` (เดิมจาก D-24) force-unwrap `item['product_title']!`/`item['seller_name']!` แบบไม่มีเงื่อนไขมาตลอด — NULL ได้จริงทุกครั้งที่สินค้าที่ถูกรายงานโดนลบทีหลัง (`reported_product_id` เป็น `ON DELETE SET NULL`) เป็นบั๊กที่ไม่เคยถูกจับเพราะไม่มีใครเทสเคส "รายงานสินค้าที่ถูกลบไปแล้ว" ยังไม่นับว่า P-09 เองก็จะชนบั๊กเดิมทันทีเพราะ user-only report ก็มี `reported_product_id = NULL` เหมือนกัน — ปิดพร้อมกันด้วยการครอบทั้ง 2 บล็อกด้วย `if (isProductReport == true)`/`if (isUserReport == true)`

**FlutterFlow (2 พุช):**

- Push 1: register field ใหม่ทั้งหมด (PT-15 §6/D-57 pattern — `reports.reported_user_id` + `reports_admin_view` 4 คอลัมน์) ไม่แตะ page/component ใด (PT-17 §1)
- Push 2: component `ReportUserSheet` (mirror `ReportProductSheet` เป๊ะ, param `userId` โดยตรงไม่ผ่าน App State เพราะ `ShowBottomSheet` มีค่าอยู่ในมือแล้ว) · ปุ่ม "รายงานผู้ใช้" แทรกเข้า `UserProfileCard` (D-55's paramless profile popup — ครอบคลุมทุกจุดเข้าถึงโปรไฟล์อัตโนมัติ: `ProductDetails` ชื่อผู้ขาย, `BannedUsers` แถว, `UserDirectory` แถว) · re-author `ReportDetailContent` ทั้งก้อน (PT-23 §1 บังคับ) เพิ่มบล็อก "ผู้ใช้ที่ถูกรายงาน" + ปุ่ม "ระงับผู้ใช้รายนี้" (reuse `banUserSheetRef` เดิมจาก D-52 Phase D เป๊ะ — component เดียวกับปุ่ม "ระงับผู้ขายรายนี้")

**กับดักที่คาดไว้แต่ไม่เจอ (คุ้มบันทึกไว้):** ปุ่ม "รายงานผู้ใช้" ต้องซ่อนตอนดูโปรไฟล์ตัวเอง (กัน error เงียบจาก `reports_no_self_report` CHECK เพราะ Postgres action ไม่มี onFailure hook, PT-18) ตอนแรกกังวลว่าจะต้องใช้ raw-proto เหมือนที่ `ProductDetails`'s owner-hiding (D-51) เคยต้องทำ — **ไม่จริง**: D-51 ต้อง raw-proto เพราะ `seller_id` ตอนนั้นเป็น raw page-scoped `FFVariable` (จาก `nodeKeyRef`) ไม่ใช่ typed expression แต่ที่นี่ทั้งสองฝั่งเป็น typed `DslExpression` อยู่แล้ว (`AppState('viewedProfileUserId')` กับ `AuthUser(AuthUserField.userId)`) เลยใช้ `visible: Not(Equals(...))` ตรงบน widget ที่เพิ่ง insert ได้เลย — pattern เดียวกับ D-39 เป๊ะ ไม่ต้องแตะ raw proto เลยทั้งพุช

**Confirmed จาก `generated_code/`:** `ReportUserSheetWidget` insert `reports` ด้วย `reported_user_id: widget!.userId` ตรงตามดีไซน์ · `UserProfileCardWidget` ปุ่มห่อด้วย `if (!(viewedProfileUserId == currentUserUid))` จริง (ไม่ใช่ static) · `ReportDetailWidget` ทั้ง 2 conditional block (`isProductReport`/`isUserReport`) ครอบ force-unwrap ถูกจุดครบ

**ยังไม่ทำ:** UI แสดง `reports` ทั้งสองประเภทแยก tab/filter บนหน้า `ReportsFeedback` (list ยังโชว์รวมกันเหมือนเดิม แค่ `ReportDetail` แยกเนื้อหาตามประเภท) · **ยังไม่ทดสอบผ่านแอปจริงโดย pete**

**ยังไม่ได้ทดสอบผ่านแอปจริงโดย pete**

---

## D-66 — P-12: เก็บกวาดไฟล์กำพร้าใน Storage เริ่มและปิดครบ (2026-08-25)

**บริบท:** pete สั่ง "เก็บกวาดฝ่ายกำพร้าก่อน" — เลือกแนวทาง **Edge Function รันเป็นรอบ** (ไม่ใช่ trigger `AFTER DELETE`) พร้อม 2 พารามิเตอร์ความปลอดภัย: grace period **24 ชม.**, รอบแรก **dry-run ก่อน** ค่อยเปิดลบจริง

**Schema:** ตารางใหม่ 2 ตัว — `storage_cleanup_config` (singleton, `dry_run`/`grace_period_hours`, toggle ผ่าน `UPDATE` เดียวไม่ต้อง redeploy) และ `storage_cleanup_log` (audit trail append-only, `action IN ('would_delete','deleted','delete_failed')`) ทั้งคู่ RLS admin-read เท่านั้น เขียนได้ทาง `service_role` เท่านั้น เปิด extension `pg_cron`/`pg_net` เพิ่ม

**Edge Function `cleanup-orphan-storage`:** list ไฟล์ทุกไฟล์ใน bucket `product-images`/`avatars` ผ่าน Storage API (`.storage.from(bucket).list(...)`) เทียบกับ path ที่ถูกอ้างถึงจริงใน `products.image_urls`/`"Profile".avatar_url` — ไฟล์ที่ไม่ถูกอ้างถึง **และ** เก่ากว่า grace period ถือว่ากำพร้า `dry_run=true` (ค่าเริ่มต้น) log อย่างเดียว ไม่ลบจริง

**cron job** `cleanup-orphan-storage-daily` — รันทุกวัน 19:00 UTC (02:00 ไทย) เรียก Edge Function ผ่าน `net.http_post` ด้วย **anon key** (public พอ เพราะสิทธิ์ลบจริงมาจาก `SUPABASE_SERVICE_ROLE_KEY` ที่ฟังก์ชันสร้าง client เองข้างใน ไม่เกี่ยวกับ token ที่ใช้เรียก)

**🔴 เจอกับดักจริงระหว่างทดสอบ dry-run (พิสูจน์ว่าตัดสินใจ dry-run-ก่อนถูกต้อง):**
1. `.schema('storage').from('objects')` ใช้ไม่ได้ — PostgREST ของโปรเจกต์นี้ไม่ expose schema `storage` เจอ error `Invalid schema: storage` ตั้งแต่ทดสอบรอบแรก แก้ด้วยเปลี่ยนไปใช้ Storage API's `list()` แทน (list โฟลเดอร์ระดับบนสุด = uid ก่อน แล้ว list ไฟล์ในแต่ละโฟลเดอร์)
2. `net.http_post` default timeout 5000ms สั้นเกินสำหรับงานนี้ (list ทีละ user folder หลาย round-trip) — client รายงาน timeout ทั้งที่ฟังก์ชันรันสำเร็จจริงฝั่ง server (เห็นจาก log ซ้ำ 2 ชุดในการทดสอบ) แก้ด้วย `timeout_milliseconds := 60000` ทุกครั้งที่เรียก

**ทดสอบ dry-run แล้ว (2026-08-25):** `product-images` scan 22 ไฟล์ พบกำพร้า 6, `avatars` scan 5 ไฟล์ พบกำพร้า 2 — cross-check ด้วยมือว่าทุกไฟล์ที่ log ไม่ปรากฏใน `products.image_urls`/`"Profile".avatar_url` เลยจริง (ไม่มี false positive)

**ยังไม่ทำ:** ยังไม่สลับ `dry_run = false` — รอ pete ตรวจ `storage_cleanup_log` อย่างน้อย 1 รอบเต็มจากตัว cron จริง (รอบแรก 02:00 ไทย คืนถัดไป) ก่อนเปิดลบจริง

---

## D-67 — Retheme ทั้งแอปเป็นสีม่วง-ม่วงพาสเทล + ยืนยัน root cause ของ PT-25 ข้อ 1 (2026-08-25)

**บริบท:** pete สั่ง retheme ทั้งแอปให้ดูเป็นแอปปกติ สีม่วง-ม่วงพาสเทล ไม่กระทบระบบ/โลจิก ทำผ่าน FlutterFlow AI workspace (`mju_market_v2/dsl/edit.dart`) ไม่ใช่ SQL

**Theme:** ธีมเดิมเป็นค่า default ของ FlutterFlow ล้วน (ไม่เคยแตะมาก่อน, ยืนยันจาก `grep app.themeColor` ทั้ง `dsl/create.dart`/`dsl/edit.dart` ว่างเปล่า) แก้ทั้ง 16 slot (light+dark) ครั้งเดียวผ่าน `app.themeColor(...)` — primary `#7C3AED`/`#9F7AEA`, ใช้สีม่วงเดิมที่มีอยู่แล้วจริงในแอป (`0xFF874EBB`, native `FlutterFlowChoiceChips` บน `addproduct`) เป็น `tertiary` ตรง ๆ แทนเลือกใหม่ กันชนกับสีที่ patch ไม่ได้ (ดูด้านล่าง) ยืนยันจาก `generated_code/lib/flutter_flow/flutter_flow_theme.dart` ว่าโค้ดจริงตรงตามค่าที่ตั้ง เนื่องจาก token (`FlutterFlowTheme.of(context)`) มากกว่า literal hex ทั้งแอป 1,027:39 จุด การแก้ 16 slot จุดเดียวจึงไหลไปทั่วแอปอัตโนมัติ (รวม category-chip 24 ปุ่มบน `Home`/`Mypost` — ไม่ต้องแตะเลยเพราะผูก `Colors.primary`/`Colors.secondaryBackground` อยู่แล้ว)

**Sweep สีที่ยังไม่ผูก token:** กวาดจุด literal hex ที่เหลือใน `chatList`/`home`/`productDetails`/`addproduct`/`mypost` ผ่าน `page.update(...).patch.color(NamedColor(...))` (Text/Icon/Container/Divider) — ลด literal hex ที่ไม่โปร่งใสทั้งแอปจาก 39 เหลือ 22 จุด 🔴 **`patch.color(...)` ไม่รองรับ `Scaffold`/`AppBar`** (compiler switch มีแค่ Text/Button/Icon/IconButton/Container/Card/Divider/TextField) ต้องใช้ raw proto (`page.mutateNode` + `node.props.scaffold.backgroundColorValue = FFColorValue(inputValue: FFColor(themeColor: FFColor_ThemeColor.PRIMARY_BACKGROUND))`) แทน — pattern ใหม่ ยังไม่เคยมีตัวอย่างใน `dsl/edit.dart` มาก่อน

**จุดที่ตั้งใจไม่แตะ:** `addproduct`'s native ChoiceChips `0xFF874EBB` (== `tertiary` ใหม่พอดีแล้ว) · `homeAdmin`'s box-shadow `0x430B0D0F` (เงาปกติ ไม่ใช่พื้นผิว brand) · container ไม่มี key หลายจุดใน `home`/`addproduct` (พื้นหลังอยู่หลังรูปเครือข่าย, patch ไม่ได้เพราะหา key ไม่เจอ) · **`profile_user_widget.dart` ทั้งก้อน (12 จุด)** — สงสัยว่าเป็นซากเทมเพลต FlutterFlow เดิมที่ไม่มีใครใช้จริง (label ภาษาอังกฤษ "Edit Profile"/"Account Settings"/switch "Active", ฟอนต์ `Plus Jakarta Sans` ที่ไม่เจอที่ไหนอื่นในแอปเลย) ยังไม่ตัดสินใจว่าจะลบทิ้งหรือทำจริง — รอ pete ตัดสินใจ ไม่ retheme ให้เพราะไม่อยากทำให้ดูเหมือนตรวจสอบแล้วว่าใช้งานจริง

**🔴 ยืนยัน root cause ของ `PT-25` ข้อ 1 ที่ทิ้งไว้เป็นปริศนา (2026-08-19):** ตอน push พบ `dsl/edit.dart` ทั้งไฟล์ compile ไม่ผ่านจริง ไม่เกี่ยวกับ retheme เลย — `Container 'MyPostRow' — Parameter "productId" ... not properly set` + `Text — Generator variable does not exist` ×3 + `Container 'SoldBadge' — Condition configuration is invalid` ยืนยันด้วย isolation test (comment ทับ retheme sweep ทั้งก้อนแล้ว error เดิมทุกตัวอักษร) ว่าไม่เกี่ยวกับงานนี้เลย ต้นตอจริง: **`page.ensureReplaced` selector ของ `MyPostsList` ยังชี้ `'ListView_z48phx0c'` ที่ live drift ไปเป็น `'ListView_1xe02ssc'` แล้ว** (drift รอบที่ 2 — คอมเมนต์เดิมในสคริปต์บันทึกรอบแรกไว้ตั้งแต่ 2026-08-23) แก้แค่เปลี่ยน key ใน `findByKey(...)` ให้ตรงของจริง (ยืนยันจาก `flutterflow ai inspect --page Mypost`) แล้ว error ทั้ง 4 ตัวหายพร้อมกันหมด — พิสูจน์ว่า PT-25 ข้อ 1 เดาถูกทาง (`item['field']` เป็น action param เอง**ไม่ใช่ตัวปัญหา** ปัญหาจริงคือ generator variable ทั้งชุดผูกกับ `nodeKeyRef` ของ ListView ที่ตายไปแล้ว ทำให้ resolve ไม่ได้เลยทั้ง itemBuilder ไม่ใช่แค่ widget ที่ใช้ `item[]` ตรง ๆ) — อัปเดต `PATTERNS.md` PT-25 ให้ตรงแล้ว

**เจอด้วย:** `app.component('ReportUserSheet', ...)` (D-65) ที่ landed แล้วแต่ไม่เคย retire ออกจากสคริปต์ (ซ้ำ pattern เดียวกับ D-47/D-49) ทำ push ค้าง "already exists" — แก้ด้วยการลบ declaration แล้วสร้าง reference-only `ComponentHandle(ComponentDeclaration(...))` stub แทน (pattern เดียวกับ `banUserSheetRef`/`rejectProductSheetRef` ที่มีอยู่แล้ว)

**ยังไม่ทำ:** ยังไม่ได้ดู screenshot จริงผ่าน Live Session (bridge ไม่ bind ตอนทดสอบ, `rpc_error[bridge_unavailable]`) ยืนยันแค่จาก `generated_code/` — **pete ยืนยันแล้วว่า "ดูดีขึ้นกว่าเดิม" (2026-08-25)** แต่ยังไม่ใช่การทดสอบผ่านแอปจริงแบบละเอียด

---

## D-68 — แก้บั๊ก scroll ค้างที่ grid สินค้าใน `Home` (2026-08-26)

**บริบท:** pete รายงานว่าเลื่อนหน้า Home ลงมาถึง grid สินค้า (`AllList`) แล้วเลื่อนกลับขึ้นไม่ได้ ต้องออกไปหน้าอื่นแล้วกลับเข้ามาใหม่

**Root cause:** `GridView_fxvqqbog` (`AllList`) มี `shrinkWrap: true` เพื่อซ้อนอยู่ใน `SingleChildScrollView` ของ Column นอก แต่ FlutterFlow AI SDK codegen ไม่เคยใส่ `physics:` ให้ GridView/ListView ที่ `shrinkWrap: true` เลยทั้งโปรเจกต์ (ตรวจ `generated_code/lib/**` ยืนยันแล้ว) — proto `FFGridView` ไม่มี field physics เลย ตั้งผ่าน DSL/fast-lane ไม่ได้จริง ๆ (ไม่ใช่แค่ SDK ไม่ expose) ทำให้ grid มี Scrollable ของตัวเองแย่ง gesture arena กับ scroll หลักของหน้า

**ลองแล้วไม่ผ่าน:** แทน `GridView` ด้วย custom widget (`physics: NeverScrollableScrollPhysics()` ตรง ๆ ในโค้ด) — พารามิเตอร์ `products: List<PostgresRow>` (bind กับ page state `productsList`) ถูก FlutterFlow backend validator ปฏิเสธเสมอ (`"parameter products not set properly"`) ยืนยันด้วย control probe: พารามิเตอร์ `string` ธรรมดา bind page state เดียวกัน push ผ่านปกติ → สรุปว่า custom-widget parameter ที่เป็น `List<PostgresRow>` ใช้ไม่ได้กับ FlutterFlow AI SDK ปัจจุบัน แม้ page state field เดียวกันจะผูกกับ native GridView `source:` ได้ปกติ (รายละเอียด `PATTERNS.md` PT-35)

**ทางแก้ v1 (ใช้ชั่วคราว แล้ว pete ขอเปลี่ยนวันเดียวกัน):** ไม่ปิด scroll ของ grid — ทำให้ grid เป็น scrollable ตัวเดียวของหน้าแทน (ปิด `scrollable` บน `Column_q5ywpv4w` + ปิด `shrinkWrap` บน `GridView_fxvqqbog` + ตั้ง `props.expanded` ให้ grid ยืดเต็มพื้นที่ที่เหลือ) แลกกับ: ช่องค้นหา/กรองราคา/รายการโพสต์แอดมิน/chip หมวดหมู่ กลายเป็น header คงที่ ไม่เลื่อนหายไปพร้อมเนื้อหาอีกต่อไป — pete ทดสอบแล้วว่า grid เลื่อนได้ปกติจริง แต่ไม่เอา trade-off นี้ ขอ whole-page scroll กลับคืนมา

**⚠️ ระหว่างทดลอง custom widget (v1) เกิด push ขึ้นจริงโดยไม่ตั้งใจ 2 ครั้ง** (diagnostic custom widget `DiagnosticStringProbe`/`ProductGridView` + placement `StringProbe` บน `Home`) — ลบออกหมดแล้วในพุชถัดมา ยืนยันจาก `generated_code/`/`lib/flutterflow_project/pages/home.dart` ว่าไม่มีร่องรอยเหลือ

**ทางแก้ v2 (ใช้จริงตอนนี้):** คืน `Column_q5ywpv4w.scrollable = true` แล้วแทน `GridView_fxvqqbog` ด้วย custom widget `ProductGridSection` ที่ **fetch ข้อมูลเอง** (เรียก RPC `search_products` ตรง ๆ โค้ดเดียวกับ custom action `searchProducts`) แทนรับ list เป็น parameter — เลี่ยงข้อจำกัดที่เจอใน v1 (`List<PostgresRow>` param ถูกปฏิเสธเสมอ) เพราะ widget ไม่มี parameter แบบ list เลย มีแต่ scalar 5 ตัว (`keyword`/`categoryId`/`minPrice`/`maxPrice`: bind `AppState`, `refreshToken`: bind page state ใหม่ `gridRefreshToken`) โค้ดข้างในตั้ง `physics: NeverScrollableScrollPhysics()` ได้ตรงๆ เพราะเป็น Dart ที่เราเขียนเอง ไม่ผ่าน FF proto เลย
- `didUpdateWidget` เทียบ 5 พารามิเตอร์เก่า/ใหม่ — ตัวไหนเปลี่ยนสั่ง fetch ใหม่อัตโนมัติ (กลไก Flutter ล้วน ไม่พึ่ง `context.watch<FFAppState>()` เพราะยืนยันจากโค้ดจริงแล้วว่า action chain เดิมที่ set `FFAppState().searchKeyword`/`searchCategoryId` ไม่เรียก `notifyListeners()` เลย ใช้แค่ `safeSetState` ของหน้า)
- Pull-to-refresh ผูกใหม่ที่ `Column_q5ywpv4w` (ไม่ใช่ตัว grid อีกต่อไป) ผ่าน `page.ensureActions(..., ON_PULL_TO_REFRESH, [SetState.increment('gridRefreshToken', 1)])` — แค่เพิ่มค่า token ให้ widget เห็นแล้ว fetch ใหม่ ไม่ reset ตัวกรองหมวดหมู่เหมือน chain เดิมอีกต่อไป (เจตนาลดความซับซ้อน — pull-to-refresh ตอนนี้แปลว่า "โหลดใหม่ด้วยตัวกรองเดิม" ไม่ใช่ "ล้างตัวกรอง")
- **จุดที่ไม่ชัวร์ก่อน push แต่ยืนยันแล้วว่าใช้ได้จริง**: ไม่เคยพิสูจน์มาก่อนว่า FF AI SDK codegen ห่อ `RefreshIndicator` ไว้ *นอก* `SingleChildScrollView` ถูกตำแหน่งไหมเมื่อ trigger อยู่บน Column ที่ตัว scrollable เอง — ตรวจ `generated_code/lib/home/home_widget.dart` แล้วยืนยันว่าห่อถูกจริง (`RefreshIndicator(onRefresh: ..., child: SingleChildScrollView(physics: AlwaysScrollableScrollPhysics(), ...))`) — เป็นข้อมูลใหม่ที่ยืนยันแล้ว ใช้ pattern นี้ซ้ำได้ในหน้าอื่น

**เจตนาลดความเสี่ยง:** ปุ่มค้นหา/13 category chip/price filter button — ไม่แตะเลย ยังคง `SetState('productsList', ...)` เดิมที่ไม่ได้ใช้แล้ว (ยิง RPC ซ้ำ 1 รอบทุกครั้งที่กด ไม่กระทบ UX เพราะเป็น user-triggered ไม่ใช่ต่อเนื่อง) — ไม่คุ้มความเสี่ยงที่จะไปแก้ ~15 action chain ที่ทำงานถูกต้องอยู่แล้วเพื่อลด 1 RPC call ต่อครั้ง ปรับทีหลังได้

**ยังไม่ทำ:** ยังไม่ได้ทดสอบผ่านแอปจริงบนมือถือ (เครื่องพัฒนาไม่มี Flutter SDK ติดตั้ง, `local_run.list_devices` คืนค่าง่าง) ยืนยันแค่ `generated_code/` (โครงสร้าง/parameter ตรงตามที่เขียน) + canvas screenshot ผ่าน Live Session (ไม่มี error, custom widget แสดง placeholder ตามปกติที่ design-time render ไม่ได้)

## D-69 — `addproduct`: เพิ่มปุ่มลบรูปที่อัปแล้ว (2026-08-26)

**บริบท:** pete ขอฟีเจอร์ลบรูปในหน้าเพิ่มรายการ เมื่อไม่เอารูปที่เพิ่งอัปแล้ว

**ทำ:** reuse badge icon เดิม (`Icon_hzgec1g3`/`Icon_r8r3w5z6`/`Icon_bwoocet1` — เดิมเป็น check_circle สีเขียว แค่บอกสถานะ ไม่มี action ผูก) เปลี่ยน icon เป็น `cancel` สีแดง (`error` token) แล้วผูก `ON_TAP` ให้เป็นปุ่มลบ — ไม่สร้าง widget ใหม่/ไม่ต้อง restructure Stack เลย เพราะ node เดิมอยู่ใน `if (imageXUploaded)` แล้ว (โชว์เฉพาะช่องที่อัปแล้วพอดี) action chain: `removeFromUploadedImageUrls(imageXUrl)` ก่อน (ต้องอ่านค่า URL ก่อนล้าง) แล้วค่อย set `imageXUrl=''`/`imageXUploaded=false`

**ทำไมไม่ลบไฟล์ใน Storage ตรงนี้เลย:** ตั้งใจ — ปล่อยให้ orphan-cleanup batch job ที่มีอยู่แล้ว (D-66) กวาดทีหลังตาม grace period แทน ลดความเสี่ยง/ความซับซ้อนของปุ่มนี้

**กับดักที่เจอ:** `SetState`/`State` field ต้องเป็น typed handle (`ff.Pages.addproduct.state.xxx`) ห้ามส่ง string ตรง ๆ แม้ทั้งไฟล์ `dsl/edit.dart` ก่อนหน้านี้จะใช้ string มาตลอด — validator บล็อกตั้งแต่ compile ไม่ใช่ runtime (ยืนยันจาก error message "Use ff.Pages.addproduct.state.X instead of SetState(...)")

**ยังไม่ทำ:** ยังไม่ได้ทดสอบผ่านแอปจริง (ยืนยันแค่ `generated_code/` ว่า nested `InkWell` ห่อ icon ถูกตำแหน่ง/ลำดับ action ถูก)
