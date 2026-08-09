# SCHEMA.md — ความจริงของฐานข้อมูล

> ⭐ **ทุกอย่างในไฟล์นี้ apply ลง Supabase จริงแล้ว** — ถ้าไม่อยู่ในไฟล์นี้ แปลว่ายังไม่มี
> SQL ที่ยังเป็นข้อเสนอ อยู่ที่ `PROPOSED_SQL.md` เท่านั้น ห้ามปนกัน
> Project: `MJU market` (`rooydbxgcsybyanwsewv`)
>
> 🔴 **กฎของไฟล์นี้: ทุกบรรทัดต้อง re-derive จาก catalog query ได้เดี๋ยวนี้**
> ถ้าความจริงข้อไหน**ผูกกับวันที่** (จำนวนแถว · ผลทดสอบ · ผล advisor · log) → ไม่ใช่ schema ให้ไปอยู่ `VERIFICATION.md`
> ถ้าเป็น**เหตุผล/ประวัติ** ว่าทำไมถึงเป็นแบบนี้ → ไปอยู่ `DECISIONS.md`
>
> ⚠️ ห้ามคัดลอก schema จากไฟล์นี้ไปวางซ้ำในไฟล์อื่น — ให้อ้างอิงมาที่นี่ที่เดียว

---

## ตาราง

7 ตารางใน `public` — RLS **เปิดครบทุกตัว**, `FORCE ROW LEVEL SECURITY` ไม่เปิดที่ไหนเลย

### `auth.users` (Supabase Auth built-in — ห้ามแก้ตรง ๆ)

### `public."Profile"` ⚠️ `P` ตัวใหญ่ — ใน SQL ต้อง quote เสมอ

| # | คอลัมน์ | ชนิด | null? | default |
|---|---|---|---|---|
| 1 | `id` | uuid | NOT NULL | `gen_random_uuid()` |
| 2 | `created_at` | timestamptz | NOT NULL | `now()` |
| 3 | `email` | varchar | nullable | – |
| 4 | `full_name` | varchar | nullable | – |
| 5 | `avatar_url` | text | nullable | – |
| 6 | `role` | varchar | nullable | `'user'::character varying` |
| 7 | `student_id` | varchar | nullable | – |
| 8 | `phone` | varchar | nullable | – |
| 9 | `bio` | text | nullable | – |

```sql
-- constraint ทั้งหมด (pg_get_constraintdef คำต่อคำ)
PRIMARY KEY (id)
FOREIGN KEY (id) REFERENCES auth.users(id)          -- Profile_id_fkey (ไม่มี CASCADE)
UNIQUE (email)                                       -- Profile_email_key
UNIQUE (student_id)                                  -- profile_student_id_unique

CHECK (((role)::text = ANY ((ARRAY['user'::character varying,
                                   'admin'::character varying])::text[])))   -- profile_role_check

CHECK (((student_id)::text ~ '^[0-9]{10}$'::text))   -- profile_student_id_format

CHECK (((student_id IS NULL)
        OR ((email IS NOT NULL)
            AND (lower((email)::text) = (('mju'::text || (student_id)::text)
                                         || '@mju.ac.th'::text)))))          -- profile_student_id_matches_email

CHECK (((email IS NULL)
        OR (lower((email)::text) ~ '^[^@]+@mju\.ac\.th$'::text)))            -- profile_email_domain
```

> ⚠️ `profile_student_id_matches_email` ผูก `student_id` เข้ากับ `email` แบบตายตัว — ตั้ง `student_id` ที่ไม่ตรงรูปแบบ `mju<10หลัก>@mju.ac.th` ไม่ได้เลย ผลกระทบเต็ม ๆ ดู `DECISIONS.md` **D-10**
>
> 🔴 `profile_email_domain` anchor ทั้งสองด้าน (`^[^@]+@...$`) **จงใจ** — ถ้าใช้แค่ `@mju\.ac\.th$` อีเมลอย่าง `hacker@evil.com@mju.ac.th` จะผ่าน `[^@]+` บังคับให้มี `@` ตัวเดียว ยืนยันด้วยการทดสอบจริง `VERIFICATION.md` **V-09**

### `public.products`

| # | คอลัมน์ | ชนิด | null? | default |
|---|---|---|---|---|
| 1 | `id` | uuid | NOT NULL | `gen_random_uuid()` |
| 2 | `created_at` | timestamptz | NOT NULL | `now()` |
| 3 | `seller_id` | uuid | nullable | `auth.uid()` |
| 4 | `title` | varchar | nullable | – |
| 5 | `description` | text | nullable | – |
| 6 | `price` | numeric | nullable | – |
| 8 | `status` | varchar | nullable | – |
| 9 | `image_urls` | text[] | nullable | – |
| 10 | `condition` | varchar | nullable | – |
| 11 | `contact_phone` | varchar | nullable | – |
| 12 | `moderation_status` | varchar | **NOT NULL** | `'pending'::character varying` |
| 13 | `category_id` | bigint | nullable | – |
| 14 | `rejection_reason` | text | nullable | – |

> 📌 `ordinal_position` **ข้าม 7** — มีคอลัมน์ที่ถูก DROP ไปแล้ว ไม่ใช่เอกสารตกหล่น

```sql
PRIMARY KEY (id)
FOREIGN KEY (category_id) REFERENCES "CAT"(id)
FOREIGN KEY (seller_id) REFERENCES "Profile"(id) ON UPDATE CASCADE ON DELETE CASCADE

CHECK (((condition)::text = ANY ((ARRAY['new'::character varying,
                                        'used'::character varying])::text[])))
CHECK (((moderation_status)::text = ANY ((ARRAY['pending'::character varying,
                                                'approved'::character varying,
                                                'rejected'::character varying])::text[])))

CHECK (((image_urls IS NULL) OR (array_length(image_urls, 1) <= 3)))   -- products_image_urls_max_3
```

- `image_urls` เก็บได้ **สูงสุด 3 รูป** บังคับที่ระดับ DB — ยิง API ตรงก็เกินไม่ได้ (ดู `DECISIONS.md` D-12)
- `status` = สถานะการขาย (available/reserved/sold) — **ไม่มี CHECK** ยังไม่บังคับค่า, Layer 5 จะมาใช้
- `moderation_status` = สถานะตรวจสอบ — คนละเรื่องกับ `status` โดยตั้งใจ ดู `DECISIONS.md` D-04
- `image_urls` เป็น array เดียว ไม่มีตาราง `product_images` แยก
- `contact_phone` = เบอร์ต่อประกาศ คนละตัวกับ `"Profile".phone`

### `public."CAT"` ⚠️ ชื่อตัวใหญ่ทั้งหมด ต้อง quote

| # | คอลัมน์ | ชนิด | null? | default |
|---|---|---|---|---|
| 1 | `id` | bigint | NOT NULL | identity **BY DEFAULT** |
| 2 | `name` | text | **NOT NULL** | – |

`PRIMARY KEY (id)` — ไม่มี FK / UNIQUE / CHECK อื่น

**เนื้อข้อมูล lookup (id 1–12 เสถียร ใช้อ้างอิงตรง ๆ ใน FlutterFlow ได้):**

| id | name | id | name |
|---|---|---|---|
| 1 | หนังสือ/ตำราเรียน | 7 | ของใช้ในหอพัก |
| 2 | อุปกรณ์การเรียน | 8 | เฟอร์นิเจอร์ |
| 3 | คอมพิวเตอร์/แล็ปท็อป | 9 | เครื่องใช้ไฟฟ้า |
| 4 | มือถือ/แท็บเล็ต | 10 | อุปกรณ์กีฬา |
| 5 | อุปกรณ์อิเล็กทรอนิกส์อื่น ๆ | 11 | จักรยาน/ยานพาหนะ |
| 6 | เสื้อผ้า/เครื่องแต่งกาย | 12 | อื่น ๆ |

> ⚠️ policy เป็น `TO authenticated` → `anon` เห็น **0 แถว** dropdown จะว่างถ้าเปิดหน้าก่อนล็อกอิน (ผลตรวจ: `VERIFICATION.md` V-05)

### `public.chat`

| # | คอลัมน์ | ชนิด | null? | default |
|---|---|---|---|---|
| 1 | `id` | bigint | NOT NULL | identity BY DEFAULT |
| 2 | `created_at` | timestamptz | NOT NULL | `now()` |
| 3 | `last_message` | text | nullable | – |

`PRIMARY KEY (id)` — ไม่มี FK / CHECK

### `public.chat_user` (junction table, many-to-many)

| # | คอลัมน์ | ชนิด | null? | default |
|---|---|---|---|---|
| 1 | `id` | bigint | NOT NULL | identity BY DEFAULT |
| 2 | `created_at` | timestamptz | NOT NULL | `now()` |
| 3 | `chat_id` | bigint | nullable | – |
| 4 | `user_id` | uuid | nullable | – |

```sql
PRIMARY KEY (id)
UNIQUE (chat_id, user_id)                            -- กันสมาชิกซ้ำในห้องเดียวกัน
FOREIGN KEY (chat_id) REFERENCES chat(id)
FOREIGN KEY (user_id) REFERENCES "Profile"(id)
```

### `public.chat_message`

| # | คอลัมน์ | ชนิด | null? | default |
|---|---|---|---|---|
| 1 | `id` | bigint | NOT NULL | identity BY DEFAULT |
| 2 | `created_at` | timestamptz | NOT NULL | `now()` |
| 3 | `chat_id` | bigint | nullable | – |
| 4 | `user_id` | uuid | **NOT NULL** | – (ผู้ส่ง) |
| 5 | `message` | text | **NOT NULL** | – |

```sql
PRIMARY KEY (id)
FOREIGN KEY (chat_id) REFERENCES chat(id)
FOREIGN KEY (user_id) REFERENCES "Profile"(id)
```

### `public.reports`

| # | คอลัมน์ | ชนิด | null? | default |
|---|---|---|---|---|
| 1 | `id` | uuid | NOT NULL | `gen_random_uuid()` |
| 2 | `reporter_id` | uuid | **NOT NULL** | – |
| 3 | `reported_product_id` | uuid | nullable | – |
| 4 | `reason` | text | nullable | – |
| 5 | `status` | varchar | nullable | – |
| 6 | `created_at` | timestamptz | **NOT NULL** | `now()` |

```sql
PRIMARY KEY (id)
FOREIGN KEY (reporter_id)         REFERENCES "Profile"(id) ON UPDATE CASCADE ON DELETE CASCADE
FOREIGN KEY (reported_product_id) REFERENCES products(id)  ON UPDATE CASCADE ON DELETE CASCADE
```

- `status` **ไม่มี CHECK** — ค่าที่ใช้ได้ (`open`/`resolved`/…) ยังไม่บังคับ รอทำพร้อม P-10
- 🔴 RLS เปิดอยู่ **แต่ 0 policy = deny-all** — ต้องเพิ่มก่อนใช้จริง (Layer 7, ดู P-10)

### ตารางที่ยังไม่มี

`transactions` (L5) · `notifications` (L6) · `reviews` (L7) — DDL ร่างไว้ที่ `PROPOSED_SQL.md`

---

## Views

4 view — นิยามด้านล่างคือผล `pg_get_viewdef()` ของจริง คำต่อคำ

```sql
-- ⭐ ไม่มี security_invoker โดยตั้งใจ (reloptions = NULL) → รันด้วยสิทธิ์ owner
CREATE VIEW public.public_profiles AS
 SELECT id,
    full_name,
    avatar_url
   FROM "Profile";
```

> 🔴 **ห้ามใส่ `security_invoker` ให้ `public_profiles`** — ใส่แล้ว `seller_name` / `member_names` เป็น NULL ทั้งระบบทันที
> advisor จะฟ้อง `security_definer_view` ตรงนี้ตลอดไป **นั่นคือของที่ตั้งใจ ไม่ใช่บั๊ก** เหตุผลเต็มอยู่ `DECISIONS.md` **D-01**

```sql
-- reloptions: security_invoker=true
CREATE VIEW public.chat_summary WITH (security_invoker = true) AS
 SELECT c.id AS chat_id,
    c.last_message,
    c.created_at,
    array_agg(p.full_name ORDER BY p.full_name) AS member_names,
    array_agg(cu.user_id) AS user_ids
   FROM chat c
     JOIN chat_user cu ON cu.chat_id = c.id
     JOIN public_profiles p ON p.id = cu.user_id
  GROUP BY c.id, c.last_message, c.created_at;

-- reloptions: security_invoker=true
CREATE VIEW public.chat_messages_view WITH (security_invoker = true) AS
 SELECT cm.id AS message_id,
    cm.chat_id,
    cm.user_id,
    p.full_name AS sender_name,
    cm.message,
    cm.created_at
   FROM chat_message cm
     JOIN public_profiles p ON p.id = cm.user_id;

-- reloptions: security_invoker=true
CREATE VIEW public.products_review_view WITH (security_invoker = true) AS
 SELECT p.id,
    p.created_at,
    p.title,
    p.description,
    p.price,
    p.contact_phone,
    p.condition,
    p.image_urls,
    p.moderation_status,
    p.status,
    p.category_id,
    c.name AS category_name,
    p.seller_id,
    pr.full_name AS seller_name,
    p.rejection_reason
   FROM products p
     LEFT JOIN "CAT" c ON c.id = p.category_id
     LEFT JOIN public_profiles pr ON pr.id = p.seller_id;
```

> 📌 `products_review_view` ใช้ **LEFT JOIN** ทั้งสองขา — ประกาศที่ไม่มี `category_id` หรือ `seller_id` ยังโผล่ในผลลัพธ์ โดย `category_name` / `seller_name` เป็น NULL

> 🔴 **กฎ: view ใดก็ตามที่ต้องการชื่อ/รูปผู้ใช้ ต้อง join `public_profiles` ห้าม join `"Profile"` ตรง ๆ**
> เหตุผลเต็มอยู่ `DECISIONS.md` D-01 — ละเมิดแล้วชื่อจะเป็น NULL เฉพาะตอน user ธรรมดาเปิดดู (admin เห็นปกติ จึงตรวจไม่เจอถ้าเทสด้วย admin อย่างเดียว)

---

## RLS ที่ apply แล้ว

RLS `ENABLE` ครบทั้ง 7 ตาราง จำนวน policy ต่อตาราง:

| ตาราง | policy | สรุป |
|---|---|---|
| `"Profile"` | 4 | ดูตารางค่าจริงด้านล่าง |
| `products` | 1 | allow-all |
| `chat` | 1 | allow-all |
| `chat_user` | 1 | allow-all |
| `chat_message` | 1 | allow-all |
| `"CAT"` | 1 | allow-all — เป็นแค่ lookup |
| `reports` | **0** | 🔴 RLS เปิด ไม่มี policy = **deny-all** |

**ค่าจริงจาก `pg_policies` — ทุก policy เป็น `PERMISSIVE` ไม่มี `RESTRICTIVE` สักตัว**

| ตาราง | policyname | cmd | roles | qual | with_check |
|---|---|---|---|---|---|
| `"CAT"` | Allow all for authenticated users | ALL | `{authenticated}` | `true` | `true` |
| `products` | Allow all for authenticated users | ALL | `{authenticated}` | `true` | `true` |
| `chat` | Allow all for authenticated users | ALL | `{authenticated}` | `true` | `true` |
| `chat_user` | Allow all for authenticated users | ALL | `{authenticated}` | `true` | `true` |
| `chat_message` | Allow all for authenticated users | ALL | `{authenticated}` | `true` | `true` |
| `"Profile"` | Users can view own profile | SELECT | `{public}` | `(auth.uid() = id)` | – |
| `"Profile"` | Admins can view all profiles | SELECT | `{public}` | `private.is_admin()` | – |
| `"Profile"` | Admins can update all profiles | UPDATE | `{public}` | `private.is_admin()` | – |
| `"Profile"` | Users can update own profile | UPDATE | `{authenticated}` | `(auth.uid() = id)` | ↓ |

```sql
-- with_check ของ "Users can update own profile" (ค่าจริง คำต่อคำ)
((auth.uid() = id)
 AND ((role)::text = (private.current_profile_role())::text)
 AND ((private.current_profile_student_id() IS NULL)
      OR ((student_id)::text = (private.current_profile_student_id())::text)))
```

> ⚠️ 3 policy ที่ `roles = {public}` (ไม่ใช่ `authenticated`) ครอบคลุม `anon` ด้วย — ปลอดภัยอยู่เพราะ `auth.uid()` / `is_admin()` เป็น NULL/false สำหรับ anon แต่ควรเปลี่ยนเป็น `authenticated` ให้ชัดเจน

> ⚠️ **TODO ก่อน production:** `products` / `chat` / `chat_user` / `chat_message` เป็น allow-all — authenticated user ทุกคนอ่าน/เขียนได้หมดทุกห้อง ต้องเปลี่ยนเป็น restrictive ตาม `chat_user` membership ก่อนเปิดใช้จริง (ดู `DECISIONS.md` D-03)

**วิธีดู RLS จริง** — `list_tables` ไม่คืน policy ต้องรัน:

```sql
SELECT tablename, policyname, permissive, cmd, roles, qual, with_check
FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename, policyname;
```

---

## Realtime ที่เปิดแล้ว

`supabase_realtime` มี 3 ตาราง: `public.chat` · `public.chat_message` · `public.products`

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_message;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat;
ALTER PUBLICATION supabase_realtime ADD TABLE public.products;  -- จำเป็นสำหรับ reject-alert flow (L2)
```

ตรวจ: `SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';`

---

## Function / Trigger ที่ apply แล้ว

4 function (`public` 1 + `private` 3) · 1 trigger — ทั้งหมดคือผล `pg_get_functiondef()` / `pg_get_triggerdef()` ของจริง

### `public.handle_new_user()` + trigger `on_auth_user_created`

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  normalized_email varchar;
  derived_student_id varchar;
begin
  normalized_email := lower(new.email);

  if normalized_email !~ '^[^@]+@mju\.ac\.th$' then
    raise exception 'Only @mju.ac.th email addresses are allowed';
  end if;

  derived_student_id := substring(normalized_email from '^mju([0-9]{10})@mju\.ac\.th$');

  insert into public."Profile" (id, email, full_name, role, student_id, phone)
  values (
    new.id,
    normalized_email,
    nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
    'user',
    derived_student_id,
    nullif(trim(new.raw_user_meta_data->>'phone'), '')
  );

  return new;
end;
$function$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();   -- tgenabled = 'O' (เปิดอยู่)
```

สิ่งที่ต้องรู้ก่อนต่อ FlutterFlow:

1. **บังคับโดเมน `@mju.ac.th`** — สมัครด้วยอีเมลอื่นจะ `raise exception` ทันที แต่ **error ที่ client ได้รับใช้ไม่ได้** ต้อง validate ฝั่ง client เอง (ผลตรวจ + log ดิบ: `VERIFICATION.md` V-03)
   รับ**ทุก**อีเมล `@mju.ac.th` ไม่ใช่เฉพาะ `mju<10หลัก>` — บุคลากร/อาจารย์สมัครได้ โดย `student_id` เป็น NULL (เหตุผล: `DECISIONS.md` **D-10**)
2. **`student_id` เป็นค่า derived** — trigger ดึงจากอีเมลเอง FlutterFlow **ห้าม**เขียนทับ จะชน CHECK `profile_student_id_matches_email`
   ⚠️ **`"Profile".email` ถูก `lower()` เสมอ ส่วน `auth.users.email` เก็บตามที่ผู้ใช้พิมพ์** — โค้ดที่จับคู่สองที่นี้ด้วย `=` ตรง ๆ จะพลาดเมื่อผู้ใช้พิมพ์ตัวใหญ่ ให้ join ด้วย `id` เท่านั้น
3. **`full_name` มาจาก `raw_user_meta_data->>'full_name'`** — FlutterFlow ต้องส่ง meta data ตัวนี้ตอน Sign Up ไม่งั้น `full_name` เป็น NULL
4. **ไม่มี `ON CONFLICT`** — ถ้าแถวใน `"Profile"` มีอยู่แล้วจะ error และทำให้สมัครไม่ผ่านทั้งรายการ
5. **`phone` มาจาก `raw_user_meta_data->>'phone'`** (เพิ่ม 2026-08-08 ดู **D-14**) — ส่ง key `phone` ไปพร้อม `full_name` ตอน Sign Up ได้เลย **ไม่ต้อง Update Row ตามหลัง**
6. **`bio` / `avatar_url` ยังไม่มีใครใส่ให้** — `insert` แตะแค่ `id, email, full_name, role, student_id, phone` สองตัวนี้ต้องแก้ที่หน้า Edit Profile
7. **`full_name` / `phone` ผ่าน `nullif(trim(...), '')`** — ส่งช่องว่างล้วนมาจะได้ `NULL` ไม่ใช่ `''` เพื่อให้เช็ค "ยังไม่กรอก" ที่เดียวพอ

### `private.*` — helper สำหรับ RLS

ทั้ง 3 ตัว: `LANGUAGE sql` · `STABLE` · `SECURITY DEFINER` · `SET search_path TO ''`

| function | ใช้ที่ไหน |
|---|---|
| `private.is_admin()` | qual ของ `Admins can view/update all profiles` |
| `private.current_profile_role()` | `with_check` ของ `Users can update own profile` — กันเลื่อนขั้นตัวเอง |
| `private.current_profile_student_id()` | `with_check` เดียวกัน — กันแก้ `student_id` ที่ตั้งแล้ว |

```sql
CREATE OR REPLACE FUNCTION private.is_admin()
 RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public."Profile" WHERE id = auth.uid() AND role = 'admin'
  );
$function$;

CREATE OR REPLACE FUNCTION private.current_profile_role()
 RETURNS character varying
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$ SELECT role FROM public."Profile" WHERE id = auth.uid() $function$;

CREATE OR REPLACE FUNCTION private.current_profile_student_id()
 RETURNS character varying
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$ SELECT student_id FROM public."Profile" WHERE id = auth.uid() $function$;
```

> 📌 อยู่ใน schema **`private`** ไม่ใช่ `public` — query ที่กรอง `nspname='public'` อย่างเดียวจะ**มองไม่เห็น**
> เช่นเดียวกับ `on_auth_user_created` ที่อยู่บนตารางใน schema **`auth`**
> เคยทำให้เอกสารเขียนผิดมาแล้ว → `DECISIONS.md` **D-11**

---

## Storage

### bucket `product-images`

| ค่า | |
|---|---|
| `public` | **true** — อ่านผ่าน public URL ได้เลย ไม่ต้องทำ signed URL (ดู `DECISIONS.md` D-12) |
| `file_size_limit` | `5242880` (5 MB ต่อไฟล์) |
| `allowed_mime_types` | `{image/jpeg, image/png, image/webp}` |

🔴 **โครงสร้าง path บังคับ: `<auth.uid()>/<ชื่อไฟล์>`** — policy ตัดสินสิทธิ์จาก `(storage.foldername(name))[1]` อัปเข้าโฟลเดอร์อื่นถูกปฏิเสธ

**policy บน `storage.objects` — ค่าจริงจาก `pg_policies`**

| policyname | cmd | roles | qual / with_check |
|---|---|---|---|
| product-images: public read | SELECT | `{public}` | qual: `(bucket_id = 'product-images'::text)` |
| product-images: owner upload | INSERT | `{authenticated}` | with_check: ↓ |
| product-images: owner update | UPDATE | `{authenticated}` | qual **และ** with_check: ↓ |
| product-images: owner delete | DELETE | `{authenticated}` | qual: ↓ |

```sql
-- นิพจน์ ↓ ที่ใช้ร่วมกันทั้ง upload / update / delete (ค่าจริง คำต่อคำ)
((bucket_id = 'product-images'::text)
 AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text))
```

> 📌 **จำนวนรูปสูงสุด 3 บังคับที่ `products.image_urls` ไม่ใช่ที่ Storage** — policy บน `storage.objects` เห็นทีละไฟล์ นับรวมไม่ได้ ผลคืออัปไฟล์ที่ 4 เข้า bucket ได้ แต่ผูกกับประกาศไม่ได้ (กลายเป็นไฟล์กำพร้า) เหตุผลเต็ม: `DECISIONS.md` **D-12**

### bucket `avatars`

| ค่า | |
|---|---|
| `public` | **true** — `public_profiles.avatar_url` ถูกแสดงทุกหน้าจอ signed URL หมดอายุจึงเก็บลงคอลัมน์ไม่ได้ (เหตุผลเดียวกับ D-12) |
| `file_size_limit` | `2097152` (2 MB ต่อไฟล์) |
| `allowed_mime_types` | `{image/jpeg, image/png, image/webp}` |

🔴 **path บังคับ `<auth.uid()>/<ชื่อไฟล์>`** เหมือนกัน

| policyname | cmd | roles | qual / with_check |
|---|---|---|---|
| `avatars public read` | SELECT | `{public}` | qual: `(bucket_id = 'avatars'::text)` |
| `avatars owner upload` | INSERT | `{authenticated}` | with_check: ↓ |
| `avatars owner update` | UPDATE | `{authenticated}` | qual **และ** with_check: ↓ |
| `avatars owner delete` | DELETE | `{authenticated}` | qual: ↓ |

```sql
-- นิพจน์ ↓ ร่วมกันทั้ง upload / update / delete (ค่าจริง คำต่อคำ)
((bucket_id = 'avatars'::text)
 AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text))
```

> 📌 **`"Profile".avatar_url` เป็นแค่ text ไม่มีอะไรผูกกับไฟล์จริงใน bucket** — ลบไฟล์แล้วคอลัมน์ยังชี้ URL เดิม และเปลี่ยนรูปแล้วไฟล์เก่าไม่ถูกลบ (ไฟล์กำพร้าแบบเดียวกับ D-12)

### bucket `static-pages`

สร้างวันที่ 2026-08-09 สำหรับหน้าเว็บกลาง "ยืนยันอีเมลสำเร็จ" ของ D-19 (Site URL ชี้มาที่ไฟล์ในนี้แทน `localhost:3000`) — ไม่ใช่ bucket สำหรับ user upload

| ค่า | |
|---|---|
| `public` | **true** |
| `file_size_limit` | ไม่ได้ตั้ง (ไม่จำกัด) |
| `allowed_mime_types` | ไม่ได้ตั้ง (ไม่จำกัด) |

| policyname | cmd | roles | qual |
|---|---|---|---|
| `static-pages public read` | SELECT | `{public}` | `(bucket_id = 'static-pages'::text)` |

**ไฟล์ที่มีอยู่จริง:** `email-confirmed.txt` (**ไม่ใช่** `.html` — ดูเหตุผลกับดักใน `CLAUDE.md` ตาราง "กับดัก tool") — plain text ล้วน อัปโหลดสำเร็จแล้ว
public URL: `https://rooydbxgcsybyanwsewv.supabase.co/storage/v1/object/public/static-pages/email-confirmed.txt` — ตั้งเป็น **Site URL** ใน Authentication → URL Configuration แล้ว 2026-08-09 (ดู `DECISIONS.md` D-19)

🔴 **ไม่มี policy INSERT/UPDATE/DELETE เลย** — อัปโหลด/แก้ไขไฟล์ในนี้ได้เฉพาะผ่าน Dashboard (service_role bypass RLS) เท่านั้น ตั้งใจให้เป็นแบบนี้เพราะเป็นหน้าคงที่ ไม่ต้องการให้ใครแก้ได้จากแอป

**ไฟล์ที่ต้องมี (ยังไม่ได้อัปโหลด ณ 2026-08-09):** `email-confirmed.html` — pete เตรียมอัปโหลดเองผ่าน Dashboard ตาม `DECISIONS.md` D-19

---

## 📎 ความจริงที่ไม่ได้อยู่ในไฟล์นี้

| อยากรู้ | ไปที่ |
|---|---|
| จำนวนแถว · ผลทดสอบ RLS ด้วย user ธรรมดา · ผลสมัครจริง · ผล `get_advisors` · log ดิบ | `VERIFICATION.md` |
| ทำไมถึงออกแบบแบบนี้ · เอกสารเคยเขียนผิดตรงไหน | `DECISIONS.md` |
| SQL ที่ยังไม่ apply | `PROPOSED_SQL.md` |
