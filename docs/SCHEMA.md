# SCHEMA.md — ความจริงของฐานข้อมูล

> ⭐ **ทุกอย่างในไฟล์นี้ apply ลง Supabase จริงแล้ว** — ถ้าไม่อยู่ในไฟล์นี้ แปลว่ายังไม่มี
> SQL ที่ยังเป็นข้อเสนอ อยู่ที่ `PROPOSED_SQL.md` เท่านั้น ห้ามปนกัน
> Project: `MJU market` (`rooydbxgcsybyanwsewv`) | ตรวจกับ DB จริงล่าสุด: **2026-08-07** (รัน `checks/_common.sql` ครบทุกบล็อก)
>
> 📌 สถานะข้อมูล ณ 2026-08-07: `auth.users` + `"Profile"` มี **4 แถว (ข้อมูลทดสอบ)** · `"CAT"` มี **12 แถว (ข้อมูลจริง)**
> ตารางที่เหลือ (`products` / `chat` / `chat_user` / `chat_message` / `reports`) **ยังว่าง 0 แถว**
> → เช็ค "ห้ามมี NULL" ของ `products_review_view` และ `chat_summary` **ยังตรวจไม่ได้** ต้องมีประกาศ/ห้องแชทจริงก่อน
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

✅ **seed แล้ว 2026-08-07 — 12 แถว** (`id` 1–12 ตามลำดับนี้เป๊ะ ใช้อ้างอิงใน FlutterFlow ได้)

| id | name | id | name |
|---|---|---|---|
| 1 | หนังสือ/ตำราเรียน | 7 | ของใช้ในหอพัก |
| 2 | อุปกรณ์การเรียน | 8 | เฟอร์นิเจอร์ |
| 3 | คอมพิวเตอร์/แล็ปท็อป | 9 | เครื่องใช้ไฟฟ้า |
| 4 | มือถือ/แท็บเล็ต | 10 | อุปกรณ์กีฬา |
| 5 | อุปกรณ์อิเล็กทรอนิกส์อื่น ๆ | 11 | จักรยาน/ยานพาหนะ |
| 6 | เสื้อผ้า/เครื่องแต่งกาย | 12 | อื่น ๆ |

ตรวจ 2 รอบแล้ว:

| role | เห็นกี่แถว |
|---|---|
| `postgres` | 12 |
| `authenticated` | **12** ✅ dropdown ใช้งานได้จริง |
| `anon` | **0** ⚠️ |

> ⚠️ **`anon` เห็น 0 แถว** เพราะ policy `Allow all for authenticated users` ระบุ `TO authenticated` เท่านั้น
> → หน้าไหนที่ให้เลือกหมวดหมู่**ก่อนล็อกอิน** (เช่น browse แบบไม่ต้องสมัคร) dropdown จะว่างเปล่า
> ถ้าจะรองรับ ต้องเพิ่ม policy SELECT ให้ `anon` ต่างหาก — ยังไม่ทำ เพราะยังไม่ได้ตัดสินใจว่าจะให้ browse ก่อนล็อกอินไหม

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
| `reporter_id` | uuid **NOT NULL**, FK → `"Profile".id` ON UPDATE CASCADE ON DELETE CASCADE, ไม่มี default |
| `reported_product_id` | uuid nullable, FK → `products.id` ON UPDATE CASCADE ON DELETE CASCADE, ไม่มี default |
| `reason` | text nullable |
| `status` | varchar nullable, **ไม่มี CHECK** — ค่าที่ใช้ได้ยังไม่ถูกบังคับ |
| `created_at` | timestamptz **NOT NULL** default `now()` |

> ✅ **แก้แล้ว 2026-08-07** (migration `fix_reports_column_defaults`, ตารางว่าง 0 แถว ตอน apply)
> เดิม `reporter_id` / `reported_product_id` มี default `gen_random_uuid()` ซึ่งไร้ความหมายกับคอลัมน์ FK
> — insert โดยไม่ส่งค่าจะได้ UUID มั่วที่ไม่ตรงแถวไหน แล้วไปตายที่ FK violation แทน NOT NULL violation
> และ `created_at` ไม่มี default ต่างจากทุกตารางอื่น ตอนนี้ถอด default ทิ้งและตั้ง `now()` เรียบร้อย
>
> 🔴 RLS เปิดอยู่ **แต่ยังไม่มี policy เลย = deny-all** — ต้องเพิ่มก่อนใช้จริง (Layer 7, ดู P-10)
>
> ⚠️ **ยังค้าง:** `status` ไม่มี CHECK — ค่าที่ใช้ได้ (`open`/`resolved`/…) ยังไม่ตัดสินใจ รอทำพร้อม P-10
>
> ⚠️ **ยังไม่ได้ตรวจ:** ตารางว่าง + deny-all → ยังไม่เคยเขียน/อ่านจริงผ่าน policy สักครั้ง

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

#### ✅ ทดสอบ RLS ด้วย user จริงที่ไม่ใช่ admin แล้ว 2026-08-07

ทดสอบเป็น `mju6598765432@mju.ac.th` (`role='user'`, ไม่ใช่เจ้าของข้อมูลที่ไปยุ่ง) ด้วยท่า `SET LOCAL ROLE authenticated` + `request.jwt.claims`:

| ทดสอบ | คาดหวัง | ผลจริง |
|---|---|---|
| `SELECT` จาก `public_profiles` | เห็นชื่อทุกคน | ✅ 4 แถว **ไม่มี NULL** |
| `SELECT` จาก `"Profile"` ตรง ๆ | เห็นแค่ของตัวเอง | ✅ 1 แถว |
| `UPDATE role = 'admin'` ให้ตัวเอง | ถูกปฏิเสธ | ✅ `42501 new row violates row-level security policy` |
| `UPDATE student_id` ของตัวเอง | ถูกปฏิเสธ | ✅ `42501` |
| `UPDATE full_name` ของ**คนอื่น** | ไม่มีผล | ✅ 0 แถว (ตรวจซ้ำแล้วข้อมูลคนอื่นไม่ถูกแตะ) |
| `UPDATE full_name`/`bio`/`phone` ของตัวเอง | สำเร็จ | ✅ |

> ⭐ **นี่คือการพิสูจน์ D-01** — `public_profiles` ให้ user ธรรมดาเห็นชื่อคนอื่นได้ โดย `email`/`student_id`/`role` ยังถูกซ่อน
> บั๊ก "ชื่อผู้ขายเป็น NULL เฉพาะ user ธรรมดา" ที่เอกสารเตือนไว้ **ยืนยันแล้วว่าไม่เกิดกับ `public_profiles`**
> (แต่ `products_review_view` / `chat_summary` ยังตรวจไม่ได้ เพราะยังไม่มีประกาศและห้องแชท)

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

#### ✅ ทดสอบกับการสมัครจริงแล้ว 2026-08-07 (user 4 คนผ่าน Dashboard)

| อีเมลที่สมัคร | ผล | `student_id` ที่ได้ |
|---|---|---|
| `mju6512345678@mju.ac.th` | ✅ สร้างสำเร็จ | `6512345678` |
| `mju6598765432@mju.ac.th` | ✅ สร้างสำเร็จ | `6598765432` |
| `somchai.j@mju.ac.th` (บุคลากร) | ✅ สร้างสำเร็จ | `NULL` |
| `MJU6511112222@mju.ac.th` (ตัวใหญ่) | ✅ สร้างสำเร็จ | `6511112222` |
| `test@gmail.com` | ❌ **ถูกปฏิเสธ** | – |

ทุกคนได้ `role = 'user'` และมีแถวใน `"Profile"` ครบ (`users_without_profile = 0`)

**เคสตัวใหญ่ผ่าน** — Supabase normalize อีเมลเป็นตัวเล็กก่อนเก็บลง `auth.users` regex ใน trigger ที่ไม่มี `lower()` จึงไม่เป็นปัญหาจริง (ข้อกังวลใน D-10 ตกไป)

**`full_name` เป็น NULL ทุกคน** เพราะ Dashboard > Add user ไม่มีช่องใส่ user metadata → ยืนยันว่าถ้า FlutterFlow ไม่ส่ง `full_name` ใน meta data ชื่อจะหายทั้งระบบจริง

#### 🔴 P-02 ทำงาน แต่ error ที่ client ได้รับใช้ไม่ได้เลย

จาก auth log ของ Supabase:

```
POST /admin/users → 500  error_code: unexpected_failure
error: failed to close prepared statement: ERROR: current transaction is aborted,
       commands ignored until end of transaction block (SQLSTATE 25P02):
       ERROR: Only @mju.ac.th email addresses are allowed (SQLSTATE P0001)
```

ข้อความจริงของเราถูกห่อไว้ชั้นในสุด **ฝั่ง client เห็นแค่ `Failed to create user: {}`** — body ว่างเปล่า

> ⚠️ **FlutterFlow พึ่ง error message จาก server ไม่ได้** ต้อง validate โดเมนฝั่ง client ก่อน submit เสมอ
> trigger เป็นแค่ตาข่ายกันพลาดชั้นสุดท้าย ไม่ใช่ชั้นที่คุยกับผู้ใช้
> (สาเหตุ: `raise exception` ทำให้ transaction abort → GoTrue ปิด prepared statement ไม่ได้ → error จริงถูกกลบด้วย 25P02 แล้วส่งกลับเป็น 500 เปล่า ๆ)

### `private.*` — helper สำหรับ RLS (ทั้ง 3 ตัว SECURITY DEFINER, `search_path=''`)

| function | ใช้ที่ไหน |
|---|---|
| `private.is_admin()` | policy `Admins can view/update all profiles` |
| `private.current_profile_role()` | `with_check` ของ `Users can update own profile` — กันเลื่อนขั้นตัวเอง |
| `private.current_profile_student_id()` | `with_check` เดียวกัน — กันแก้ `student_id` ที่ตั้งแล้ว |

```sql
-- ทั้ง 3 ตัวเป็น LANGUAGE sql, STABLE, SECURITY DEFINER, SET search_path TO ''
CREATE OR REPLACE FUNCTION private.is_admin() RETURNS boolean AS $$
  SELECT EXISTS (SELECT 1 FROM public."Profile" WHERE id = auth.uid() AND role = 'admin');
$$;

CREATE OR REPLACE FUNCTION private.current_profile_role() RETURNS varchar AS $$
  SELECT role FROM public."Profile" WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION private.current_profile_student_id() RETURNS varchar AS $$
  SELECT student_id FROM public."Profile" WHERE id = auth.uid();
$$;
```

> 📌 อยู่ใน schema `private` ไม่ใช่ `public` — query ที่กรอง `nspname='public'` อย่างเดียวจะ**มองไม่เห็น** (`checks/_common.sql` [C7] เดิมพลาดข้อนี้ แก้แล้ว)

---

## Storage

**ยังไม่มี bucket** — Layer 2 ต้องสร้าง `product-images` + policy

---

## 🔍 ผล `get_advisors` (2026-08-07)

### 🔴 ERROR ที่ **ห้ามแก้** — อ่านก่อนจะไป "แก้ให้เขียว"

| lint | เป้า |
|---|---|
| `security_definer_view` | `public.public_profiles` |

> **นี่คือ D-01 ที่ตั้งใจทำแบบนี้ ไม่ใช่บั๊ก**
> `public_profiles` **ต้องไม่มี** `security_invoker` เพราะมันต้องรันด้วยสิทธิ์ owner เพื่อให้ user ธรรมดาเห็นชื่อ/รูปคนอื่นได้
> ถ้าไปใส่ `security_invoker = true` ตามที่ advisor แนะนำ → RLS ของ `"Profile"` จะกลับมาบังคับ → **`seller_name` / `member_names` จะเป็น NULL ทั้งระบบทันที** ซึ่งคือบั๊กที่โปรเจกต์นี้เคยเจอมาแล้ว
> ตัว view เปิดเผยแค่ `id` / `full_name` / `avatar_url` — `email` / `phone` / `student_id` / `role` ไม่ได้อยู่ในนั้น จึงยอมรับได้
> **ทดสอบยืนยันแล้ว** ด้วย user ธรรมดา เห็นครบ 4 คน ไม่มี NULL

### ⚠️ WARN ที่ควรจัดการ

| lint | รายละเอียด |
|---|---|
| `anon_security_definer_function_executable` | `public.handle_new_user()` เรียกได้ผ่าน `/rest/v1/rpc/handle_new_user` โดย `anon` และ `authenticated` — ควร `REVOKE EXECUTE` เพราะมันเป็น trigger function ไม่ได้ตั้งใจให้เรียกตรง (เรียกตรงจะ error เพราะไม่มี `NEW` แต่ไม่ควรเปิดไว้ตั้งแต่แรก) |
| `auth_leaked_password_protection` | ปิดอยู่ — เปิดใน Dashboard > Auth ได้ ตรวจรหัสผ่านกับ HaveIBeenPwned |

### ℹ️ INFO / ที่รู้อยู่แล้ว

- `rls_enabled_no_policy` → `reports` (ตั้งใจ รอ P-10)
- `unindexed_foreign_keys` **7 จุด** — `chat_message.chat_id`, `chat_message.user_id`, `chat_user.user_id`, `products.category_id`, `products.seller_id`, `reports.reported_product_id`, `reports.reporter_id`
  ยังไม่เร่ง เพราะข้อมูลยังน้อย แต่ `products.seller_id` กับ `chat_message.chat_id` จะเจ็บก่อนเพื่อนเมื่อข้อมูลโต
- `auth_rls_initplan` **2 policy** ของ `"Profile"` — `auth.uid()` ถูกประเมินใหม่ทุกแถว แก้โดยเปลี่ยนเป็น `(select auth.uid())`
- `multiple_permissive_policies` — `"Profile"` มี 2 policy ซ้อนกันสำหรับ SELECT/UPDATE (self + admin) เป็นผลจากดีไซน์ ยอมรับได้
