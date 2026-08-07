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

**สถานะ: 🔴 ยังไม่ตัดสินใจ — บันทึกไว้เพราะ constraint นี้ apply อยู่ใน DB แล้วโดยไม่มีใครจดไว้**

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

### ✅ ส่วนที่ยืนยันด้วยการทดสอบจริงแล้ว (2026-08-07)

สมัคร user 4 คนผ่าน Dashboard แล้วได้ผลตามที่ constraint ตั้งใจทุกเคส:

| อีเมล | `student_id` |
|---|---|
| `mju6512345678@mju.ac.th` | `6512345678` |
| `somchai.j@mju.ac.th` (บุคลากร) | `NULL` — ยืนยันผลข้างเคียงข้อ 1 ว่าเกิดขึ้นจริง |
| `MJU6511112222@mju.ac.th` | `6511112222` |

และยืนยันผลข้างเคียงข้อ 2 แล้วเช่นกัน — user ธรรมดาพยายาม `UPDATE student_id` ตัวเองถูกปฏิเสธด้วย `42501`

### ❓ ค้างรอ pete

**รูปแบบอีเมลจริงของ ม.แม่โจ้ เป็นยังไง** — ถ้าไม่ใช่ `mju<10หลัก>@mju.ac.th` เป๊ะ constraint นี้จะทำให้**นักศึกษาไม่มี `student_id` เลยสักคน** ซึ่งแย่กว่าไม่มี constraint

ทางเลือกถ้ารูปแบบจริงไม่ตรง:

| ทางเลือก | ผล |
|---|---|
| แก้ regex ทั้งใน CHECK และใน trigger ให้ตรงของจริง | ดีสุดถ้ารูปแบบคงที่จริง |
| ถอด CHECK ออก เหลือแค่ format + unique (กลับไปตาม D-05) | ยืดหยุ่นกว่า แต่ `student_id` ปลอมได้ |
| เก็บ CHECK ไว้แต่ให้ admin override ได้ | ซับซ้อนขึ้น ต้องมี policy เพิ่ม |

**ห้ามแก้ constraint นี้จนกว่า pete จะยืนยันรูปแบบอีเมลจริง** — เดาแล้วแก้ผิดจะพังตอนมีผู้ใช้จริงแล้ว ซึ่งแก้ยากกว่าตอนนี้ที่ตารางยังว่าง
