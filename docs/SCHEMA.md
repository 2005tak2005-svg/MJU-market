# SCHEMA.md — ความจริงของฐานข้อมูล

> ⭐ **ทุกอย่างในไฟล์นี้ apply ลง Supabase จริงแล้ว** — ถ้าไม่อยู่ในไฟล์นี้ แปลว่ายังไม่มี
> SQL ที่ยังเป็นข้อเสนอ อยู่ที่ `PROPOSED_SQL.md` เท่านั้น ห้ามปนกัน
> Project: `MJU market` (`rooydbxgcsybyanwsewv`) | ตรวจกับ DB จริงล่าสุด: **2026-08-07** (รัน `checks/_common.sql` ครบทุกบล็อก)
>
> 📌 สถานะข้อมูล ณ 2026-08-07: **ทุกตารางว่างเปล่า 0 แถว** รวมถึง `auth.users`
> → เช็คแบบ "ห้ามมี NULL" ยังตรวจไม่ได้ และยังทดสอบมุมมอง user ธรรมดาไม่ได้เลย (ไม่มี UID ให้ใช้)
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
| `bio` | text | nullable |

CHECK เพิ่มเติม `profile_student_id_matches_email`:

```sql
CHECK (student_id IS NULL
       OR (email IS NOT NULL
           AND lower(email) = 'mju' || student_id || '@mju.ac.th'))
```

> ⚠️ ข้อนี้ผูก `student_id` เข้ากับ `email` แบบตายตัว — จะตั้ง `student_id` ที่ไม่ตรงกับรูปแบบอีเมล `mju<10หลัก>@mju.ac.th` ไม่ได้เลย
> บุคลากรที่อีเมลไม่ใช่รูปแบบนี้จึงต้องปล่อย `student_id` เป็น NULL เท่านั้น

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
| `id` | bigint PK identity (BY DEFAULT) |
| `name` | text **NOT NULL** |

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
| `id` | uuid PK, default `gen_random_uuid()` |
| `reporter_id` | uuid **NOT NULL**, FK → `"Profile".id` ON UPDATE CASCADE ON DELETE CASCADE, ⚠️ default `gen_random_uuid()` |
| `reported_product_id` | uuid nullable, FK → `products.id` ON UPDATE CASCADE ON DELETE CASCADE, ⚠️ default `gen_random_uuid()` |
| `reason` | text nullable |
| `status` | varchar nullable, **ไม่มี CHECK** — ค่าที่ใช้ได้ยังไม่ถูกบังคับ |
| `created_at` | timestamptz nullable, **ไม่มี default** |

> RLS เปิดอยู่ **แต่ยังไม่มี policy เลย = deny-all** — ต้องเพิ่มก่อนใช้จริง (Layer 7, ดู P-10)
>
> 🔴 **บั๊ก schema ที่ต้องแก้ก่อนใช้ L7:** `reporter_id` และ `reported_product_id` มี default `gen_random_uuid()`
> ซึ่งไม่มีความหมายสำหรับคอลัมน์ FK — ถ้า INSERT โดยไม่ส่งค่ามา จะได้ UUID มั่วที่ไม่ตรงกับแถวไหนเลย
> แล้วไปตายที่ FK violation แทนที่จะเป็น NOT NULL violation ทำให้ debug ยาก
> `created_at` ก็ไม่มี default `now()` ต่างจากทุกตารางอื่นในระบบ

### `public.reports` — สิ่งที่ยังไม่ได้ตรวจ

ตารางว่าง 0 แถว + deny-all → ยังไม่เคยมีการเขียน/อ่านจริงผ่าน policy เลย

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

policy ของ `"Profile"` — ค่า `qual` / `with_check` จริงจาก `pg_policies`:

| policyname | cmd | roles | qual | with_check |
|---|---|---|---|---|
| Users can view own profile | SELECT | public | `auth.uid() = id` | – |
| Admins can view all profiles | SELECT | public | `private.is_admin()` | – |
| Users can update own profile | UPDATE | authenticated | `auth.uid() = id` | ดูด้านล่าง |
| Admins can update all profiles | UPDATE | public | `private.is_admin()` | – |

```sql
-- with_check ของ "Users can update own profile" (ค่าจริง)
auth.uid() = id
AND role = private.current_profile_role()                    -- ห้ามเลื่อนตัวเองเป็น admin
AND (private.current_profile_student_id() IS NULL            -- ตั้ง student_id ได้ครั้งเดียว
     OR student_id = private.current_profile_student_id())   -- ตั้งแล้วห้ามเปลี่ยน
```

> ⚠️ **แก้จากที่เอกสารเคยเขียนไว้ผิด** — เดิมเขียนว่า admin policy ใช้ `EXISTS (SELECT 1 FROM "Profile" ...)` inline
> ของจริงเรียก `private.is_admin()` (SECURITY DEFINER) เพื่อเลี่ยง infinite recursion ที่เกิดจาก policy บน `"Profile"` ที่ query `"Profile"` เอง
> และ `with_check` ล็อกทั้ง `role` **และ** `student_id` ไม่ใช่แค่ `role`
>
> ⚠️ 2 policy ที่ `roles = public` (ไม่ใช่ `authenticated`) ครอบคลุม `anon` ด้วย — ปลอดภัยอยู่เพราะ `auth.uid()` / `is_admin()` เป็น NULL/false สำหรับ anon แต่ควรเปลี่ยนเป็น `authenticated` ให้ชัดเจน

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

> 🔴 **แก้ครั้งใหญ่ 2026-08-07** — เอกสารเดิมเขียนว่า "ยังไม่มีเลย" ซึ่ง**ผิด**
> ของจริงมี function 4 ตัว + trigger 1 ตัว apply อยู่แล้ว รวมถึง P-01 และ P-02 ที่ `PROPOSED_SQL.md` ยังคิดว่าค้างอยู่

### `public.handle_new_user()` + trigger `on_auth_user_created` — คือ P-01 **และ** P-02 รวมกัน

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare
  derived_student_id varchar;
begin
  if new.email !~ '@mju\.ac\.th$' then
    raise exception 'Only @mju.ac.th email addresses are allowed';
  end if;

  derived_student_id := substring(new.email from '^mju([0-9]{10})@mju\.ac\.th$');

  insert into public."Profile" (id, email, full_name, role, student_id)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name', 'user', derived_student_id);

  return new;
end;
$function$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();   -- enabled (tgenabled='O')
```

ของจริง**ทำมากกว่า**ที่ P-01 ร่างไว้ 3 อย่าง:

1. **บังคับโดเมน `@mju.ac.th`** — คือ P-02 ที่เอกสารบอกว่า "รอตัดสินใจ" apply ไปแล้ว สมัครด้วยอีเมลอื่น `raise exception` ทันที
2. **ดึง `student_id` จากอีเมลอัตโนมัติ** — อีเมล `mju6512345678@mju.ac.th` → `student_id = '6512345678'`
   ⚠️ ย้อนแย้งกับหมายเหตุใน P-01 ที่บอกว่า FlutterFlow ต้อง Update Row ใส่ `student_id` เอง — **ไม่ต้องแล้ว** และถ้าไปเขียนทับจะชน CHECK `profile_student_id_matches_email`
3. **ใส่ `full_name` จาก `raw_user_meta_data->>'full_name'`** — FlutterFlow ต้องส่ง meta data ตัวนี้ตอน Sign Up ไม่งั้น `full_name` เป็น NULL

> ⚠️ ยังไม่มี `ON CONFLICT` — ถ้าแถวใน `"Profile"` มีอยู่แล้วจะ error และทำให้สมัครไม่ผ่านทั้งรายการ
> ⚠️ **ยังไม่เคยทดสอบกับการสมัครจริง** — `auth.users` มี 0 แถว เส้นทางนี้จึงยังไม่เคยรันเลยสักครั้ง

### `private.*` — helper สำหรับ RLS (ทั้ง 3 ตัว SECURITY DEFINER, `search_path=''`)

| function | ใช้ที่ไหน |
|---|---|
| `private.is_admin()` | policy `Admins can view/update all profiles` |
| `private.current_profile_role()` | `with_check` ของ `Users can update own profile` — กันเลื่อนขั้นตัวเอง |
| `private.current_profile_student_id()` | `with_check` เดียวกัน — กันแก้ `student_id` ที่ตั้งแล้ว |

> 📌 อยู่ใน schema `private` ไม่ใช่ `public` — query ที่กรอง `nspname='public'` อย่างเดียวจะ**มองไม่เห็น** (`checks/_common.sql` [C7] เดิมพลาดข้อนี้ แก้แล้ว)

---

## Storage

**ยังไม่มี bucket** — Layer 2 ต้องสร้าง `product-images` + policy
