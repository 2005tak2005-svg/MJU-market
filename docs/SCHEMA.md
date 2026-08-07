# SCHEMA.md — ความจริงของฐานข้อมูล

> ⭐ **ทุกอย่างในไฟล์นี้ apply ลง Supabase จริงแล้ว** — ถ้าไม่อยู่ในไฟล์นี้ แปลว่ายังไม่มี
> SQL ที่ยังเป็นข้อเสนอ อยู่ที่ `PROPOSED_SQL.md` เท่านั้น ห้ามปนกัน
> Project: `MJU market` (`rooydbxgcsybyanwsewv`) | ตรวจกับ DB จริงล่าสุด: **2026-08-02**
> ⚠️ ห้ามคัดลอก schema จากไฟล์นี้ไปวางซ้ำในไฟล์อื่น — ให้อ้างอิงมาที่นี่ที่เดียว

---

## ตาราง

### `auth.users` (Supabase Auth built-in — ห้ามแก้ตรง ๆ)

### `public."Profile"` ⚠️ `P` ตัวใหญ่ — ใน SQL ต้อง quote เสมอ

| คอลัมน์ | ชนิด | รายละเอียด |
|---|---|---|
| `id` | uuid | PK, default `gen_random_uuid()`, FK → `auth.users.id` |
| `created_at` | timestamptz | default `now()` |
| `email` | varchar | unique, nullable |
| `full_name` | varchar | nullable |
| `avatar_url` | text | nullable |
| `role` | varchar | default `'user'`, CHECK IN (`'user'`,`'admin'`) |
| `student_id` | varchar | nullable, UNIQUE (`profile_student_id_unique`), CHECK `~ '^[0-9]{10}$'` (`profile_student_id_format`) |
| `phone` | varchar | nullable, free text ไม่มี unique/format |

### `public.products`

| คอลัมน์ | ชนิด | รายละเอียด |
|---|---|---|
| `id` | uuid | PK, default `gen_random_uuid()` |
| `created_at` | timestamptz | default `now()` |
| `seller_id` | uuid | FK → `"Profile".id`, default `auth.uid()` |
| `title` | varchar | nullable — "ตั้งชื่อสินค้า" |
| `description` | text | nullable |
| `price` | numeric | nullable |
| `category_id` | bigint | FK → `"CAT".id`, nullable |
| `image_urls` | text[] | nullable — array เดียว ไม่มีตาราง `product_images` แยก |
| `condition` | varchar | nullable, CHECK IN (`'new'`,`'used'`) |
| `contact_phone` | varchar | nullable — เบอร์ต่อประกาศ (คนละตัวกับ `Profile.phone`) |
| `status` | varchar | nullable — **สถานะการขาย** (available/reserved/sold) — Layer 5 จะมาใช้ |
| `moderation_status` | varchar | NOT NULL default `'pending'`, CHECK IN (`'pending'`,`'approved'`,`'rejected'`) — **สถานะตรวจสอบ** |
| `rejection_reason` | text | nullable — เหตุผลตอน admin ปฏิเสธ |

> `status` กับ `moderation_status` เป็นคนละเรื่องกันโดยตั้งใจ — ดู `DECISIONS.md` D-04

### `public."CAT"` ⚠️ ชื่อตัวใหญ่ทั้งหมด ต้อง quote

| คอลัมน์ | ชนิด |
|---|---|
| `id` | bigint PK identity |
| `name` | text |

> 🔴 **ตารางนี้ยังว่างเปล่า (0 แถว)** — dropdown หมวดหมู่ใน `AddProduct` จะไม่มีตัวเลือกจนกว่าจะ seed

### `public.chat`

| คอลัมน์ | ชนิด |
|---|---|
| `id` | bigint PK identity |
| `created_at` | timestamptz default `now()` |
| `last_message` | text |

### `public.chat_user` (junction table, many-to-many)

| คอลัมน์ | ชนิด |
|---|---|
| `id` | bigint PK identity |
| `created_at` | timestamptz default `now()` |
| `chat_id` | bigint FK → `chat.id` |
| `user_id` | uuid FK → `"Profile".id` |

UNIQUE `(chat_id, user_id)` — กันสมาชิกซ้ำในห้องเดียวกัน

### `public.chat_message`

| คอลัมน์ | ชนิด |
|---|---|
| `id` | bigint PK identity |
| `created_at` | timestamptz default `now()` |
| `chat_id` | bigint FK → `chat.id` |
| `user_id` | uuid NOT NULL FK → `"Profile".id` (ผู้ส่ง) |
| `message` | text NOT NULL |

### `public.reports`

| คอลัมน์ | ชนิด |
|---|---|
| `id` | uuid PK |
| `reporter_id` | uuid FK → `"Profile".id` |
| `reported_product_id` | uuid FK → `products.id`, nullable |
| `reason` | text |
| `status` | varchar |
| `created_at` | timestamptz |

> RLS เปิดอยู่ **แต่ยังไม่มี policy เลย = deny-all** — ต้องเพิ่มก่อนใช้จริง (Layer 7)

### ตารางที่ยังไม่มี

`transactions` (L5) · `notifications` (L6) · `reviews` (L7) — DDL ร่างไว้ที่ `PROPOSED_SQL.md`

---

## Views

```sql
-- ⭐ กุญแจสำคัญ: ไม่มี security_invoker โดยตั้งใจ → รันด้วยสิทธิ์ owner (postgres, rolbypassrls=true)
--    ทำให้ user ทั่วไปเห็นชื่อ/รูปคนอื่นได้ โดย email/phone/student_id/role ยังถูกซ่อน
CREATE VIEW public.public_profiles AS
SELECT id, full_name, avatar_url FROM public."Profile";

-- security_invoker = true
CREATE VIEW public.chat_summary WITH (security_invoker = true) AS
SELECT c.id AS chat_id, c.last_message, c.created_at,
       array_agg(p.full_name ORDER BY p.full_name) AS member_names,
       array_agg(cu.user_id) AS user_ids
FROM public.chat c
JOIN public.chat_user cu ON cu.chat_id = c.id
JOIN public.public_profiles p ON p.id = cu.user_id
GROUP BY c.id, c.last_message, c.created_at;

-- security_invoker = true
CREATE VIEW public.chat_messages_view WITH (security_invoker = true) AS
SELECT cm.id AS message_id, cm.chat_id, cm.user_id,
       p.full_name AS sender_name, cm.message, cm.created_at
FROM public.chat_message cm
JOIN public.public_profiles p ON p.id = cm.user_id;

-- security_invoker = true — join products + CAT + public_profiles ไว้ในคิวรีเดียว
CREATE VIEW public.products_review_view WITH (security_invoker = true) AS ...
-- คอลัมน์: id, created_at, title, description, price, contact_phone, condition,
--          image_urls, moderation_status, status, category_id, category_name,
--          seller_id, seller_name, rejection_reason
```

> 🔴 **กฎ: view ใดก็ตามที่ต้องการชื่อ/รูปผู้ใช้ ต้อง join `public_profiles` ห้าม join `"Profile"` ตรง ๆ**
> เหตุผลเต็มอยู่ `DECISIONS.md` D-01 — ละเมิดกฎนี้แล้วชื่อจะเป็น NULL เฉพาะตอน user ธรรมดาเปิดดู (admin เห็นปกติ จึงตรวจไม่เจอถ้าเทสด้วย admin อย่างเดียว)

---

## RLS ที่ apply แล้ว

| ตาราง | policy |
|---|---|
| `"Profile"` | **restrictive** — SELECT/UPDATE เฉพาะของตัวเอง (`auth.uid() = id`), UPDATE มี `WITH CHECK` ล็อกไม่ให้เปลี่ยน `role` ตัวเอง, + policy แยกให้ admin ดู/แก้ได้ทุกแถว |
| `products` | `FOR ALL TO authenticated USING (true) WITH CHECK (true)` — allow-all |
| `chat` | allow-all (เหมือนบน) |
| `chat_user` | allow-all |
| `chat_message` | allow-all |
| `"CAT"` | allow-all — เป็นแค่ lookup ไม่มีข้อมูลอ่อนไหว |
| `reports` | ⚠️ RLS เปิด **ไม่มี policy = deny-all** |

```sql
-- policy ของ Profile (สรุปเชิงตรรกะ)
-- SELECT: USING (auth.uid() = id)
-- UPDATE: USING (auth.uid() = id) WITH CHECK (auth.uid() = id AND role ไม่เปลี่ยนจากค่าเดิม)
-- SELECT/UPDATE (admin): USING (EXISTS (SELECT 1 FROM "Profile" WHERE id = auth.uid() AND role = 'admin'))
```

> ⚠️ **TODO ก่อน production:** `products` / `chat` / `chat_user` / `chat_message` เป็น allow-all ทั้งหมด — authenticated user ทุกคนอ่าน/เขียนได้หมดทุกห้อง ต้องเปลี่ยนเป็น restrictive ตาม `chat_user` membership ก่อนเปิดให้นักศึกษาใช้จริง (ดู `DECISIONS.md` D-03)

**วิธีดู RLS จริง** — `list_tables` ไม่คืน policy ต้องรัน:

```sql
SELECT tablename, policyname, cmd, roles, qual, with_check
FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename;
```

---

## Realtime ที่เปิดแล้ว

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_message;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat;
ALTER PUBLICATION supabase_realtime ADD TABLE public.products;  -- จำเป็นสำหรับ reject-alert flow (L2)
```

ตรวจ: `SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';`

---

## Trigger / Function ที่ apply แล้ว

**ยังไม่มีเลย** — รวมถึง trigger auto-insert `Profile` ตอนสมัครใหม่ (คิวถัดไปของ Layer 1)

---

## Storage

**ยังไม่มี bucket** — Layer 2 ต้องสร้าง `product-images` + policy
