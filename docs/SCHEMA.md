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

12 ตารางใน `public` — RLS **เปิดครบทุกตัว**, `FORCE ROW LEVEL SECURITY` ไม่เปิดที่ไหนเลย

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
| 10 | `is_banned` | boolean | **NOT NULL** | `false` |
| 11 | `ban_reason` | text | nullable | – |
| 12 | `banned_at` | timestamptz | nullable | – |
| 13 | `banned_by` | uuid | nullable | – |
| 14 | `year_of_study` | smallint | nullable | – |
| 15 | `faculty_id` | bigint | nullable | – |

```sql
-- constraint ทั้งหมด (pg_get_constraintdef คำต่อคำ)
PRIMARY KEY (id)
FOREIGN KEY (id) REFERENCES auth.users(id)          -- Profile_id_fkey (ไม่มี CASCADE)
FOREIGN KEY (banned_by) REFERENCES "Profile"(id)    -- Profile_banned_by_fkey (D-52)
FOREIGN KEY (faculty_id) REFERENCES faculties(id)   -- D-56
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

CHECK ((year_of_study IS NULL) OR (year_of_study BETWEEN 1 AND 4))          -- profile_year_of_study_range (D-56: 4 ระดับชั้นปีจริง)
```

> ⚠️ `profile_student_id_matches_email` ผูก `student_id` เข้ากับ `email` แบบตายตัว — ตั้ง `student_id` ที่ไม่ตรงรูปแบบ `mju<10หลัก>@mju.ac.th` ไม่ได้เลย ผลกระทบเต็ม ๆ ดู `DECISIONS.md` **D-10**
>
> 🔴 `profile_email_domain` anchor ทั้งสองด้าน (`^[^@]+@...$`) **จงใจ** — ถ้าใช้แค่ `@mju\.ac\.th$` อีเมลอย่าง `hacker@evil.com@mju.ac.th` จะผ่าน `[^@]+` บังคับให้มี `@` ตัวเดียว ยืนยันด้วยการทดสอบจริง `VERIFICATION.md` **V-09**

> 📌 `is_banned` (L8, เพิ่ม 2026-08-14) — คอลัมน์ boolean แยกจาก `role` โดยตั้งใจ (`role` คุม **สิทธิ์** user/admin, `is_banned` คุม **การเข้าถึง** — คนละมิติ ผสมกันจะทำให้ CHECK/logic ของ `role` ซับซ้อนโดยไม่จำเป็น)
>
> ✅ **มี enforcement จริงแล้วตั้งแต่ 2026-08-21 (D-52)** — soft ban: login/browse ได้ แต่ลงประกาศ/แก้/ลบ · ส่งรายงาน · แชท (ยกเว้นห้องที่มีแอดมิน) ไม่ได้ บังคับด้วย RESTRICTIVE policy 5 ตัว + guard ใน `find_or_create_chat` · เขียนค่าได้ทางเดียวคือ RPC `admin_set_user_ban` (trigger `enforce_ban_admin_only` กันคนแก้เอง)
>
> `ban_reason`/`banned_at`/`banned_by` (D-52) — เซ็ตพร้อมกันทั้งชุดโดย `admin_set_user_ban` เท่านั้น ตอนปลดแบนถูกล้างเป็น NULL ทั้ง 3 · `banned_by` FK ชี้กลับ `"Profile"(id)` = แอดมินคนที่กดแบน
>
> 📌 `faculty_id` (D-56, เพิ่ม 2026-08-22) — แทนที่คอลัมน์ `faculty` (text) เดิมจาก
> D-55 ที่ใช้ไปแค่ 1 วัน ย้ายไปเป็น FK ชี้ตาราง `faculties` แยกแทนเก็บ text อิสระ
> `public_profiles`/`public_directory_view` ยัง resolve เป็นชื่อคณะ (text) ให้เหมือนเดิมผ่าน join ไม่กระทบฝั่ง FlutterFlow ที่ผูกไว้แล้ว (D-55's `UserProfileCard`)

### `public.faculties` (D-56, เพิ่ม 2026-08-22)

| # | คอลัมน์ | ชนิด | null? | default |
|---|---|---|---|---|
| 1 | `id` | bigint | NOT NULL | identity **ALWAYS** |
| 2 | `name` | text | NOT NULL | – |

```sql
PRIMARY KEY (id)
UNIQUE (name)
```

RLS: `ALL` / `authenticated` / `USING (true)` — เหมือน `"CAT"` เป๊ะ (reference data ไม่ใช่ข้อมูลส่วนตัว) ตอนนี้มี 4 แถว placeholder (`คณะ A`/`คณะ B`/`คณะ C`/`คณะ D`) รอ pete แก้เป็นชื่อจริงผ่าน `UPDATE faculties SET name='...' WHERE id=...`

> 🔴 chip label บนหน้า `UserDirectory` (FlutterFlow) เป็นค่าฮาร์ดโค้ดในสคริปต์
> (`facultyChipLabels` ใน `dsl/edit.dart`) ไม่ได้ query ตารางนี้ตรง ๆ — แก้ชื่อคณะ
> ในตารางนี้อย่างเดียว **ไม่ทำให้ chip label เปลี่ยนตาม** ต้องแก้สคริปต์ + push ด้วย

### `public.products`

| # | คอลัมน์ | ชนิด | null? | default |
|---|---|---|---|---|
| 1 | `id` | uuid | NOT NULL | `gen_random_uuid()` |
| 2 | `created_at` | timestamptz | NOT NULL | `now()` |
| 3 | `seller_id` | uuid | nullable | `auth.uid()` |
| 4 | `title` | varchar | nullable | – |
| 5 | `description` | text | nullable | – |
| 6 | `price` | numeric | nullable | – |
| 8 | `status` | varchar | **NOT NULL** | `'available'::character varying` |
| 9 | `image_urls` | text[] | nullable | – |
| 10 | `condition` | varchar | nullable | – |
| 11 | `contact_phone` | varchar | nullable | – |
| 12 | `moderation_status` | varchar | **NOT NULL** | `'pending'::character varying` |
| 13 | `category_id` | bigint | **NOT NULL** (D-61, 2026-08-24 — 0 แถว null ตอน apply) | – |
| 14 | `rejection_reason` | text | nullable | – |
| 15 | `buyer_id` | uuid | nullable | – (D-59, เขียนได้ทาง `mark_product_sold()` เท่านั้น) |

> 📌 `ordinal_position` **ข้าม 7** — มีคอลัมน์ที่ถูก DROP ไปแล้ว ไม่ใช่เอกสารตกหล่น

```sql
PRIMARY KEY (id)
FOREIGN KEY (category_id) REFERENCES "CAT"(id)
FOREIGN KEY (seller_id) REFERENCES "Profile"(id) ON UPDATE CASCADE ON DELETE CASCADE
FOREIGN KEY (buyer_id) REFERENCES "Profile"(id) ON DELETE SET NULL   -- D-59

CHECK (((condition)::text = ANY ((ARRAY['new'::character varying,
                                        'used'::character varying])::text[])))
CHECK (((moderation_status)::text = ANY ((ARRAY['pending'::character varying,
                                                'approved'::character varying,
                                                'rejected'::character varying])::text[])))
CHECK (((status)::text = ANY ((ARRAY['available'::character varying,
                                     'reserved'::character varying,
                                     'sold'::character varying])::text[])))   -- products_status_check (D-59)

CHECK (((image_urls IS NULL) OR (array_length(image_urls, 1) <= 3)))   -- products_image_urls_max_3
```

- `image_urls` เก็บได้ **สูงสุด 3 รูป** บังคับที่ระดับ DB — ยิง API ตรงก็เกินไม่ได้ (ดู `DECISIONS.md` D-12)
- `status` = สถานะการขาย (available/reserved/sold) — `NOT NULL` + `CHECK` แล้ว (D-59) เขียนได้ **ทาง `mark_product_sold()` เท่านั้น** — trigger `enforce_sale_via_rpc_only` บล็อกทุกทางอื่นแม้เจ้าของ/แอดมิน (ดู Function/Trigger ด้านล่าง)
- `moderation_status` = สถานะตรวจสอบ — คนละเรื่องกับ `status` โดยตั้งใจ ดู `DECISIONS.md` D-04
- `buyer_id` (D-59) = ผู้ซื้อหลังขายแล้ว เขียนพร้อม `status='sold'` ในฟังก์ชันเดียวกัน — `products_review_view.can_see_buyer` คุมว่าใครเห็นชื่อ (เจ้าของ/แอดมินเท่านั้น)
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
| 5 | `last_read_at` | timestamptz | nullable | – (เพิ่ม 2026-08-17, D-31 — คนละแถวต่อสมาชิก 1 คน ไม่ใช่ boolean เดียวเหมือน `notifications.is_read` เพราะห้องแชทมีสมาชิกได้หลายคน แต่ละคนอ่านล่าสุดคนละเวลา) |

```sql
PRIMARY KEY (id)
UNIQUE (chat_id, user_id)                            -- กันสมาชิกซ้ำในห้องเดียวกัน
FOREIGN KEY (chat_id) REFERENCES chat(id)
FOREIGN KEY (user_id) REFERENCES "Profile"(id)
```

### `public.chat_message` (แก้ 2026-08-16, D-29 — เพิ่มรองรับรูปภาพ)

| # | คอลัมน์ | ชนิด | null? | default |
|---|---|---|---|---|
| 1 | `id` | bigint | NOT NULL | identity BY DEFAULT |
| 2 | `created_at` | timestamptz | NOT NULL | `now()` |
| 3 | `chat_id` | bigint | nullable | – |
| 4 | `user_id` | uuid | **NOT NULL** | – (ผู้ส่ง) |
| 5 | `message` | text | nullable (เปลี่ยนจาก NOT NULL, D-29) | – |
| 6 | `image_url` | text | nullable | – |

```sql
PRIMARY KEY (id)
FOREIGN KEY (chat_id) REFERENCES chat(id)
FOREIGN KEY (user_id) REFERENCES "Profile"(id)
CHECK (message IS NOT NULL OR image_url IS NOT NULL)  -- chat_message_has_content, D-29
```

ฝั่ง FlutterFlow ผูก `image_url` แล้ว (ส่งรูปได้จริง, D-41) — ดู `layers/L4-chat.md`

### `public.reports` (แก้ 2026-08-15, D-24)

| # | คอลัมน์ | ชนิด | null? | default |
|---|---|---|---|---|
| 1 | `id` | uuid | NOT NULL | `gen_random_uuid()` |
| 2 | `reporter_id` | uuid | **NOT NULL** | – |
| 3 | `reported_product_id` | uuid | nullable | – |
| 4 | `reason` | text | nullable | – |
| 5 | `status` | varchar | nullable | `'pending'` |
| 6 | `created_at` | timestamptz | **NOT NULL** | `now()` |
| 7 | `is_read` | boolean | **NOT NULL** | `false` (เพิ่ม 2026-08-17, D-31) |

```sql
PRIMARY KEY (id)
FOREIGN KEY (reporter_id)         REFERENCES "Profile"(id) ON UPDATE CASCADE ON DELETE CASCADE
FOREIGN KEY (reported_product_id) REFERENCES products(id)  ON DELETE SET NULL   -- เปลี่ยนจาก CASCADE (D-24) — ลบสินค้าไม่ลบประวัติ report
CHECK (status IN ('pending', 'resolved'))                                       -- เพิ่ม (D-24)
CREATE UNIQUE INDEX reports_unique_pending_per_reporter_product
  ON reports (reporter_id, reported_product_id) WHERE status = 'pending'        -- กันรายงานซ้ำ (D-24)
```

- ใช้จริงแล้ว 2 ทาง: user รายงานสินค้าเอง (`status='pending'`) และ admin log ตอน reject (`status='resolved'`, เขียนที่ 3 ต่อจาก update `products` + insert `notifications` ใน `RejectProductSheet`)
- `reported_product_id` เป็น NULL ได้จริงหลังลบสินค้า (`ON DELETE SET NULL`) — แถว report ยังอยู่ (`reports_admin_view` ใช้ `LEFT JOIN` รองรับอยู่แล้ว)

### `public.notifications` (L6, เพิ่ม 2026-08-14)

| # | คอลัมน์ | ชนิด | null? | default |
|---|---|---|---|---|
| 1 | `id` | uuid | NOT NULL | `gen_random_uuid()` |
| 2 | `user_id` | uuid | **NOT NULL** | – |
| 3 | `type` | varchar | **NOT NULL** | – |
| 4 | `ref_product_id` | uuid | nullable | – |
| 5 | `title` | text | **NOT NULL** | – |
| 6 | `body` | text | nullable | – |
| 7 | `is_read` | boolean | **NOT NULL** | `false` |
| 8 | `created_at` | timestamptz | **NOT NULL** | `now()` |

```sql
PRIMARY KEY (id)
FOREIGN KEY (user_id) REFERENCES "Profile"(id) ON DELETE CASCADE
FOREIGN KEY (ref_product_id) REFERENCES products(id) ON DELETE CASCADE

CHECK (((type)::text = ANY ((ARRAY['listing_approved'::character varying,
                                   'listing_rejected'::character varying,
                                   'account_banned'::character varying,
                                   'account_unbanned'::character varying])::text[])))
```

- `ref_product_id` nullable โดยตั้งใจ — เผื่อ `ref_chat_id bigint` เพิ่มทีหลัง (แก้บล็อกเดิมของ P-07 ดู D-23)
- `type` CHECK: มี path เขียนจริงแล้ว 3 ตัว — `listing_rejected` (จาก `RejectProductSheet`), `account_banned`/`account_unbanned` (จาก RPC `admin_set_user_ban`, D-52) · `listing_approved` เผื่อไว้ ยังไม่มี path เขียน
- 🔴 `account_banned`/`account_unbanned` มี `ref_product_id = NULL` เสมอ (ไม่มี `ref_user_id` และไม่ได้เพิ่ม — ตัวผู้รับคือ `user_id` อยู่แล้ว)
- ไม่เปิด Realtime

### `public.advertisement_posts` (L3/L8, เพิ่ม 2026-08-22, D-58)

| # | คอลัมน์ | ชนิด | null? | default |
|---|---|---|---|---|
| 1 | `id` | uuid | NOT NULL | `gen_random_uuid()` |
| 2 | `image_url` | text | **NOT NULL** | – |
| 3 | `title` | varchar | nullable | – |
| 4 | `body` | text | nullable | – |
| 5 | `is_active` | boolean | **NOT NULL** | `true` |
| 6 | `created_by` | uuid | **NOT NULL** | `auth.uid()` |
| 7 | `created_at` | timestamptz | **NOT NULL** | `now()` |

```sql
PRIMARY KEY (id)
FOREIGN KEY (created_by) REFERENCES "Profile"(id)
```

- แอดมินโพสต์รูปประกาศ/แบนเนอร์ให้ขึ้นใน `ListView_6etuspo6` ของ `Home` — รูปเดียวต่อโพสต์ (ไม่ใช่ grid หลายรูปแบบ `products`)
- ลบแบบ soft (`is_active = false`) ไม่ hard delete
- ไม่มีคอลัมน์ผู้เขียน/ชื่อผู้โพสต์เปิดเผยใน UI — การ์ดไม่โชว์ attribution

### `public.advertisement_likes` (junction table, เพิ่ม 2026-08-22, D-58)

| # | คอลัมน์ | ชนิด | null? | default |
|---|---|---|---|---|
| 1 | `post_id` | uuid | **NOT NULL** | – |
| 2 | `user_id` | uuid | **NOT NULL** | `auth.uid()` |
| 3 | `created_at` | timestamptz | **NOT NULL** | `now()` |

```sql
PRIMARY KEY (post_id, user_id)
FOREIGN KEY (post_id) REFERENCES advertisement_posts(id) ON DELETE CASCADE
FOREIGN KEY (user_id) REFERENCES "Profile"(id) ON DELETE CASCADE
```

- composite PK กันกดไลก์ซ้ำในตัว ไม่ต้อง UNIQUE เพิ่ม · insert/delete เท่านั้น ไม่มี UPDATE policy (ไลก์เป็น toggle)

### `public.transactions` (L5, เพิ่ม 2026-08-23, D-59)

| # | คอลัมน์ | ชนิด | null? | default |
|---|---|---|---|---|
| 1 | `id` | uuid | NOT NULL | `gen_random_uuid()` |
| 2 | `product_id` | uuid | nullable | – |
| 3 | `buyer_id` | uuid | nullable | – |
| 4 | `seller_id` | uuid | nullable | – |
| 5 | `price` | numeric | **NOT NULL** | – (snapshot ราคาตอนขาย) |
| 6 | `status` | varchar | **NOT NULL** | `'completed'::character varying` |
| 7 | `created_at` | timestamptz | **NOT NULL** | `now()` |
| 8 | `chat_id` | bigint | nullable | – (แชทที่เกิดการขาย) |

```sql
PRIMARY KEY (id)
FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL
FOREIGN KEY (buyer_id)   REFERENCES "Profile"(id) ON DELETE SET NULL
FOREIGN KEY (seller_id)  REFERENCES "Profile"(id) ON DELETE SET NULL
FOREIGN KEY (chat_id)    REFERENCES chat(id)      ON DELETE SET NULL

CHECK (((status)::text = 'completed'::text))   -- transactions_status_check — ค่าเดียวตอนนี้ (flow นี้ไม่มี pending/cancelled)
```

- แถวเกิดจาก `mark_product_sold()` เท่านั้น — ไม่มี INSERT/UPDATE/DELETE policy ให้ `authenticated` เลย (ดู RLS ด้านล่าง)
- FK ทั้ง 4 ตัวเป็น `ON DELETE SET NULL` (ตาม precedent `reports.reported_product_id`, D-24) — ลบสินค้า/โปรไฟล์/แชททีหลังไม่ลบประวัติธุรกรรม
- `admin_sales_by_seller` (ดู Views) อ่านจากตารางนี้แทน `products.status='sold'` ตรง ๆ แล้ว

### `public.reviews` (L7, เพิ่ม 2026-08-24, D-64, ปิดข้อเสนอ P-08)

| # | คอลัมน์ | ชนิด | null? | default |
|---|---|---|---|---|
| 1 | `id` | uuid | NOT NULL | `gen_random_uuid()` |
| 2 | `transaction_id` | uuid | **NOT NULL** | – |
| 3 | `reviewer_id` | uuid | **NOT NULL** | – |
| 4 | `reviewee_id` | uuid | **NOT NULL** | – |
| 5 | `rating` | int | **NOT NULL** | – |
| 6 | `comment` | text | nullable | – |
| 7 | `created_at` | timestamptz | **NOT NULL** | `now()` |

```sql
PRIMARY KEY (id)
FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
FOREIGN KEY (reviewer_id)    REFERENCES "Profile"(id)    ON DELETE CASCADE
FOREIGN KEY (reviewee_id)    REFERENCES "Profile"(id)    ON DELETE CASCADE
CHECK (rating BETWEEN 1 AND 5)
CONSTRAINT reviews_one_per_transaction_reviewer UNIQUE (transaction_id, reviewer_id)
```

- ผูกกับ `transactions` โดยตรง (ต่างจาก draft P-08 เดิมที่ผูกแค่ `product_id`) — RLS insert เช็คว่า `reviewer_id`/`reviewee_id` ตรงกับ `buyer_id`/`seller_id` ของ `transaction_id` นั้นจริง กันคนที่ไม่เคยซื้อสินค้านั้นจริง insert ไม่ได้เลยที่ระดับ DB
- **ไม่มี UPDATE/DELETE policy เลย = immutable ตลอดไป** (pete ยืนยันแล้ว)
- ไม่มี consumer เป็นตัว table เองในฝั่ง FlutterFlow — การ insert ทำผ่าน custom action `submitSellerReview` เรียก Supabase ตรง (ไม่ผ่าน typed `PostgresCreate`) เพราะต้องหา `transaction_id`/`seller_id` เองก่อน insert — รายละเอียด D-64

---

## Views

11 view — นิยามด้านล่างคือผล `pg_get_viewdef()` ของจริง คำต่อคำ

```sql
-- ⭐ ไม่มี security_invoker โดยตั้งใจ (reloptions = NULL) → รันด้วยสิทธิ์ owner
CREATE VIEW public.public_profiles AS
 SELECT p.id,
    p.full_name,
    p.avatar_url,
    p.bio,
    p.year_of_study,
    f.name AS faculty
   FROM "Profile" p
     LEFT JOIN faculties f ON f.id = p.faculty_id;
```

> 📌 `bio`/`year_of_study`/`faculty` (D-55, เพิ่ม 2026-08-22) — ต่อท้ายคอลัมน์เดิม
> ของ `public_profiles` ไม่ใช่ view ใหม่ อยู่ใน exposure tier เดียวกับ
> `full_name`/`avatar_url` ที่เปิดเผยแบบนี้อยู่แล้ว (`security_invoker` ไม่มี
> ตั้งแต่ D-01 — ดูเหตุผลเต็มที่นั่น) `email`/`phone`/`student_id`/`role`/ban
> columns ยังไม่อยู่ใน view นี้เหมือนเดิม
>
> 📌 `faculty` (D-56, เพิ่ม 2026-08-22) — ผลลัพธ์ของคอลัมน์นี้**เหมือนเดิมทุก
> ประการ** (ชื่อ `faculty`, type text) แม้ต้นทางเปลี่ยนจากคอลัมน์ text ตรง ๆ เป็น
> join `faculties` ผ่าน `faculty_id` แล้ว — ตั้งใจให้ `UserProfileCard`/
> `loadViewedProfile` (D-55) ไม่ต้องแก้อะไรเลย

> 🔴 **ห้ามใส่ `security_invoker` ให้ `public_profiles`** — ใส่แล้ว `seller_name` / `member_names` เป็น NULL ทั้งระบบทันที
> advisor จะฟ้อง `security_definer_view` ตรงนี้ตลอดไป **นั่นคือของที่ตั้งใจ ไม่ใช่บั๊ก** เหตุผลเต็มอยู่ `DECISIONS.md` **D-01**

```sql
-- ⭐ ไม่มี security_invoker เหมือน public_profiles (D-01) — ต้องรันด้วยสิทธิ์ owner
-- ถึงจะข้าม RLS ของ "Profile" ได้
CREATE VIEW public.public_directory_view AS
 SELECT p.id,
    COALESCE(p.full_name, 'ผู้ใช้ MJU Market'::character varying) AS full_name,
    COALESCE(p.avatar_url, ''::text) AS avatar_url,
    COALESCE(p.bio, ''::text) AS bio,
    p.year_of_study,
    COALESCE(f.name, 'ยังไม่ระบุคณะ'::text) AS faculty,
    COALESCE(p.year_of_study::text, 'ยังไม่ระบุชั้นปี'::text) AS year_label
   FROM "Profile" p
     LEFT JOIN faculties f ON f.id = p.faculty_id
  WHERE (NOT p.is_banned);
```

> 📌 `public_directory_view` (D-56, เพิ่ม 2026-08-22) — แหล่งข้อมูลของหน้า
> `UserDirectory` (browse ผู้ใช้ทั้งหมด, กรองชั้นปี/คณะ, ค้นหาชื่อ) แยกจาก
> `public_profiles` โดยตั้งใจ **เหตุผลคู่**:
> 1. `WHERE NOT is_banned` ซ่อนผู้ใช้ที่ถูกแบนจากไดเรกทอรีสาธารณะ — ทำใน view
>    ใหม่แยกแทนแก้ `public_profiles` ตรง ๆ เพราะ `public_profiles` ถูก
>    `UserProfileCard`/`loadViewedProfile` (D-55) ใช้เปิดดูโปรไฟล์คนที่ถูกแบนจาก
>    หน้า admin `BannedUsers` ด้วย — ถ้ากรองใน `public_profiles` เอง admin จะเปิด
>    ดูโปรไฟล์คนที่เพิ่งแบนไม่ได้อีกต่อไป
> 2. คอลัมน์ที่จะ bind ตรงกับ `item[]`/`Text` widget ใน FlutterFlow (ไม่ผ่าน
>    custom action คั่นแบบ `loadViewedProfile`) ต้อง **COALESCE ทุกตัวที่ nullable**
>    ก่อนส่งออก — ผูก field ที่เป็น NULL ตรง ๆ กับ `Text` widget compile เป็น
>    force-unwrap (`item.field!`) ที่ crash จริงตอนรัน (ยืนยันจากโค้ดจริงของ
>    `BannedUserRow`, D-52/D-55) `year_of_study` (raw, nullable) ยังคงอยู่ไว้
>    สำหรับ filter เท่านั้น — ไม่เคย bind ตรงกับ widget แสดงผล ใช้
>    `year_label` (text, COALESCE แล้ว) สำหรับแสดงผลแทน

```sql
-- reloptions: security_invoker=true
CREATE VIEW public.chat_summary WITH (security_invoker = true) AS
 SELECT c.id AS chat_id,
    c.last_message,
    c.created_at,
    array_agg(p.full_name ORDER BY p.full_name) AS member_names,
    array_agg(cu.user_id) AS user_ids,
    EXISTS (
      SELECT 1 FROM chat_message cm
      WHERE cm.chat_id = c.id
        AND cm.user_id IS DISTINCT FROM auth.uid()
        AND cm.created_at > COALESCE(
          (SELECT cu2.last_read_at FROM chat_user cu2
             WHERE cu2.chat_id = c.id AND cu2.user_id = auth.uid()),
          '-infinity'::timestamptz)
    ) AS is_unread                                     -- เพิ่ม 2026-08-17, D-31 — คำนวณต่อ auth.uid() ของผู้เรียกเอง
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
    cm.created_at,
    cm.image_url,
    (cm.message IS NOT NULL) AS has_message,
    (cm.image_url IS NOT NULL) AS has_image
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
    p.rejection_reason,
    p.image_urls[1] AS first_image_url,
    (p.image_urls IS NOT NULL AND array_length(p.image_urls, 1) > 0) AS has_image,
    p.image_urls[2] AS second_image_url,
    (p.image_urls[2] IS NOT NULL) AS has_second_image,
    p.image_urls[3] AS third_image_url,
    (p.image_urls[3] IS NOT NULL) AS has_third_image,
    random() AS shuffle_key,
    p.buyer_id,
    buyer.full_name AS buyer_name,
    COALESCE((p.status::text = 'sold'::text) AND (p.seller_id = auth.uid() OR private.is_admin()), false) AS can_see_buyer,
    COALESCE(rv.avg_rating, 0::numeric) AS seller_avg_rating,
    COALESCE(rv.review_count, 0)::integer AS seller_review_count,
    my_tx.transaction_id AS my_transaction_id,
    COALESCE(
      p.status::text = 'sold'::text
      AND my_tx.transaction_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM reviews rv2
        WHERE rv2.transaction_id = my_tx.transaction_id
          AND rv2.reviewer_id = auth.uid()
      ),
      false
    ) AS can_rate_seller
   FROM products p
     LEFT JOIN "CAT" c ON c.id = p.category_id
     LEFT JOIN public_profiles pr ON pr.id = p.seller_id
     LEFT JOIN public_profiles buyer ON buyer.id = p.buyer_id   -- D-59, PT-01: join public_profiles ไม่ใช่ "Profile" ตรง ๆ
     LEFT JOIN (                                                -- D-64: คะแนนเฉลี่ยผู้ขาย, pattern เดียวกับ advertisement_posts_view.like_count (D-58)
       SELECT reviews.reviewee_id,
              round(avg(reviews.rating), 1) AS avg_rating,
              count(*) AS review_count
         FROM reviews
        GROUP BY reviews.reviewee_id
     ) rv ON rv.reviewee_id = p.seller_id
     LEFT JOIN (                                                -- D-64: ธุรกรรมของผู้เรียก (ถ้ามี) บนสินค้านี้ — ใช้ทั้ง my_transaction_id และ can_rate_seller
       SELECT t.product_id, t.id AS transaction_id
         FROM transactions t
        WHERE t.buyer_id = auth.uid()
     ) my_tx ON my_tx.product_id = p.id
  -- ↓ D-52: ซ่อนประกาศของผู้ถูกแบนจากคนอื่น (gate-in-view แบบ D-33)
  WHERE NOT private.is_user_banned(p.seller_id)   -- ผู้ขายไม่ถูกแบน
     OR p.seller_id = auth.uid()                  -- เจ้าของยังเห็นของตัวเองใน Mypost
     OR private.is_admin();                       -- แอดมินเห็นทุกอย่าง

-- reloptions: security_invoker=true
CREATE VIEW public.admin_dashboard_stats WITH (security_invoker = true) AS
 SELECT id,
    full_name,
    email,
    ( SELECT count(*) AS count
           FROM "Profile") AS total_users,
    ( SELECT count(*) AS count
           FROM "Profile"
          WHERE "Profile".is_banned = true) AS banned_users,
    ( SELECT count(*) AS count
           FROM products
          WHERE products.moderation_status::text = 'pending'::text) AS pending_products,
    ( SELECT count(*) AS count
           FROM products
          WHERE products.moderation_status::text = 'approved'::text) AS approved_products,
    ( SELECT count(*) AS count
           FROM reports) AS total_reports
   FROM "Profile" p
  WHERE id = auth.uid();

-- reloptions: security_invoker=true — repoint ไปอ้าง transactions แล้ว (D-59, 2026-08-23)
CREATE VIEW public.admin_sales_by_seller WITH (security_invoker = true) AS
 SELECT t.seller_id,
    pr.full_name AS seller_name,
    count(*) AS items_sold,
    sum(t.price) AS total_sales
   FROM transactions t
     LEFT JOIN public_profiles pr ON pr.id = t.seller_id
  WHERE private.is_admin()
  GROUP BY t.seller_id, pr.full_name
  ORDER BY (sum(t.price)) DESC;

-- reloptions: security_invoker=true   (L5, เพิ่ม 2026-08-23, D-59)
CREATE VIEW public.chat_sale_status_view WITH (security_invoker = true) AS
 SELECT c.id AS chat_id,
    (EXISTS (SELECT 1 FROM transactions t WHERE t.chat_id = c.id)) AS chat_already_sold,
    (NOT (EXISTS (SELECT 1 FROM transactions t WHERE t.chat_id = c.id))
     AND NOT private.is_banned()
     AND (EXISTS (SELECT 1 FROM products p
            WHERE p.seller_id = auth.uid()
              AND p.moderation_status::text = 'approved'::text
              AND p.status::text <> 'sold'::text))) AS can_show_picker
   FROM chat c;

-- reloptions: security_invoker=true   (L8, เพิ่ม 2026-08-21, D-52)
CREATE VIEW public.admin_users_view WITH (security_invoker = true) AS
 SELECT p.id,
    p.full_name,
    p.email,
    p.student_id,
    p.role,
    p.created_at,
    p.is_banned,
    p.ban_reason,
    p.banned_at,
    banner.full_name AS banned_by_name,
    ( SELECT count(*) FROM products pd
       WHERE pd.seller_id = p.id) AS product_count,
    ( SELECT count(*) FROM reports r
        JOIN products pd2 ON pd2.id = r.reported_product_id
       WHERE pd2.seller_id = p.id) AS reports_against_count,
    COALESCE((NOT p.is_banned)
             AND COALESCE(p.role::text, 'user') <> 'admin'
             AND p.id IS DISTINCT FROM auth.uid(), false) AS can_ban,
    COALESCE(p.is_banned AND p.id IS DISTINCT FROM auth.uid(), false) AS can_unban,
    COALESCE(p.id = auth.uid(), false) AS is_self
   FROM "Profile" p
     LEFT JOIN public_profiles banner ON banner.id = p.banned_by
  WHERE private.is_admin();
```

> 📌 `admin_users_view` (L8, เพิ่ม 2026-08-21, D-52) — แหล่งข้อมูลของหน้า `ManageUsers` gate ด้วย `private.is_admin()` **ในตัว view เอง** ตามแม่แบบ D-33 ไม่พึ่ง RLS ของ `"Profile"` (user ธรรมดาได้ 0 แถว ยืนยันแล้ว)
>
> `can_ban` / `can_unban` / `is_self` เป็น **computed boolean ตั้งใจให้ผูก `visible:` ตรง ๆ** ซึ่งเป็นวิธีที่ PT-24 §1 ระบุว่าปลอดภัยที่สุดกับ Supabase row model (เลี่ยง `Equals(item['f'], '')` ที่เทียบผิดกับ `String?` และเลี่ยง raw proto แบบ D-51) · `can_ban` ตัดทั้งแอดมินและตัวเองออกให้แล้วที่ SQL — UI ไม่ต้องคิดเงื่อนไขซ้ำ
>
> 🔴 **ทั้ง 3 ตัวต้อง `COALESCE(..., false)` ห้ามลืม** — FlutterFlow codegen ผูก `visible:` เป็น `if (userItem.canBan ?? true)` **fallback เป็น `true`** ถ้าคอลัมน์เป็น NULL ปุ่มจะโผล่ทั้งที่ไม่ควร (`role` nullable → `NULL <> 'admin'` = NULL) และใช้ `IS DISTINCT FROM` แทน `<>` ตอนเทียบ `auth.uid()` ที่เป็น NULL ได้ — เจอจริงตอนอ่าน `generated_code/` (PT-29 §2)
>
> `banned_by` join ผ่าน `public_profiles` ไม่ใช่ `"Profile"` ตรง ๆ ตามกฎ PT-01/D-01

> 📌 `admin_sales_by_seller` (L8, เพิ่ม 2026-08-14) ประมาณ "ยอดขายที่ปิดแล้วต่อผู้ขาย" — **repoint ไปอ้างตาราง `transactions` แล้ว (D-59, 2026-08-23)**, เดิมอ้าง `products.status = 'sold'` ตรง ๆ ชั่วคราวเพราะ L5 ยังไม่เริ่ม คอลัมน์ output เหมือนเดิมทุกตัว (`seller_id`/`seller_name`/`items_sold`/`total_sales`) — `HomeAdmin`'s `SalesBySellerList` ไม่ต้องแก้ DSL เลย
>
> 🔴 **`AND private.is_admin()` (เพิ่ม 2026-08-17, D-33)** — view นี้เคยพึ่ง RLS ของ `products` เพียงอย่างเดียว (allow-all, D-03) ทำให้ authenticated ธรรมดาอ่านยอดขายข้าม seller ได้ (D-32) ตอนนี้ gate ที่ตัว view เองแล้ว ยืนยันด้วย impersonation test จริง (user ธรรมดา → 0 แถว, admin → เห็นแถวถูกต้อง)
>
> 📌 `chat_sale_status_view` (L5, เพิ่ม 2026-08-23, D-59) — คอมพิวต์เงื่อนไขซ่อนปุ่ม "ปิดการขาย" บน `chatMessages` ทั้ง 3 ข้อ (มีของขายอยู่ + แชทนี้ยังไม่เคยขาย + ไม่ถูกแบน) เป็น boolean เดียว (`can_show_picker`) แทนที่จะให้ FlutterFlow เดาความยาว list เอง (`listLength()`/custom-function boolean ถูก backend ปฏิเสธมาแล้วที่ D-46) — 1 แถวต่อ `chat_id`, `EXISTS`/`auth.uid()` ทำให้ผลลัพธ์ต่างกันไปตามว่าใครเป็นคน query (ฝั่งขาย vs ฝั่งซื้อเห็นค่าต่างกันสำหรับแชทเดียวกัน)

```sql
-- reloptions: security_invoker=true
CREATE VIEW public.reports_admin_view WITH (security_invoker = true) AS
 SELECT r.id,
    r.created_at,
    r.status,
    r.reason,
    r.reporter_id,
    reporter.full_name AS reporter_name,
    r.reported_product_id,
    p.title AS product_title,
    p.seller_id,
    seller.full_name AS seller_name,
    r.is_read                                          -- เพิ่ม 2026-08-17, D-31
   FROM reports r
     LEFT JOIN products p ON p.id = r.reported_product_id
     LEFT JOIN public_profiles reporter ON reporter.id = r.reporter_id
     LEFT JOIN public_profiles seller ON seller.id = p.seller_id;
```

> 📌 `reports_admin_view` (L7, เพิ่ม 2026-08-15, D-24) — mailbox สำหรับหน้า `Reports`/`ReportDetail` (admin) `security_invoker = true` พึ่ง RLS ของ `reports` เอง (`admin can read reports`) ในการกรองแถว ส่วน `public_profiles` 2 รอบ (reporter/seller) join แบบ D-01 ปกติ · `LEFT JOIN products` รองรับกรณี `reported_product_id` เป็น NULL หลังสินค้าโดนลบ (`ON DELETE SET NULL`)

> 📌 `products_review_view` ใช้ **LEFT JOIN** ทั้งสองขา — ประกาศที่ไม่มี `category_id` หรือ `seller_id` ยังโผล่ในผลลัพธ์ โดย `category_name` / `seller_name` เป็น NULL
>
> 📌 `buyer_id`/`buyer_name`/`can_see_buyer` (D-59, เพิ่ม 2026-08-23) — `buyer_name` join `public_profiles` ตามกฎ PT-01 (ไม่ join `"Profile"` ตรง ๆ) `can_see_buyer` คอมพิวต์ owner-or-admin ที่ SQL ครั้งเดียว (`COALESCE(..., false)` ตามแม่แบบ `admin_users_view`/D-52) — ฝั่ง FlutterFlow ผูก `visible: can_see_buyer` ตรง ๆ ไม่ต้องแต่ง AND/OR เอง
>
> 📌 `seller_avg_rating`/`seller_review_count`/`my_transaction_id`/`can_rate_seller` (L7, เพิ่ม 2026-08-24, D-64) — คะแนนเฉลี่ย+จำนวนรีวิวของผู้ขาย (LEFT JOIN subquery `GROUP BY reviewee_id`, pattern เดียวกับ `advertisement_posts_view.like_count`/D-58) และธุรกรรม+สิทธิ์ให้คะแนนของผู้เรียกเองบนสินค้านี้ (`can_rate_seller` คอมพิวต์ครั้งเดียวเหมือน `can_see_buyer`/`can_show_picker` — status ขายแล้ว + ผู้เรียกคือผู้ซื้อจริง + ยังไม่เคยรีวิวธุรกรรมนี้) ฝั่ง FlutterFlow ผูกปุ่ม "ให้คะแนนผู้ขาย" บน `ProductDetails` เข้ากับ `can_rate_seller` ตรง ๆ ผ่าน `productField()`/`nodeKeyRef` เดิม (D-44/D-59)
>
> 📌 `first_image_url` (`image_urls[1]`, เพิ่ม 2026-08-18, D-38) — FlutterFlow AI DSL ไม่มี list-index operator (`item['image_urls'][0]` เขียนไม่ได้) จึงดึงรูปแรกที่ SQL แทน ใช้กับ `Home` grid layout · เป็น NULL ถ้าประกาศไม่มีรูปเลย · **`Home` ยัง force-unwrap `first_image_url!` ตรง ๆ ไม่มี fallback (ยังไม่ทดสอบเคสไม่มีรูปผ่านแอปจริง — เสี่ยง crash)**
>
> 📌 `has_image` (เพิ่ม 2026-08-19, D-42) — boolean คำนวณจาก `image_urls IS NOT NULL AND array_length(...) > 0` ใช้เป็น `visible:` คู่กับ `Icon`/`Image` บน `ProductDetails` (`ProductDetailsContent`) กัน crash จากสินค้าไม่มีรูป — pattern เดียวกับ `chat_messages_view.has_message`/`has_image` (D-41) **ยังไม่ได้เอาไปใช้กับ `Home` grid**
>
> 📌 `second_image_url`/`third_image_url`/`has_second_image`/`has_third_image` (เพิ่ม 2026-08-19, D-43) — ตั้งใจทำไว้สำหรับรูปที่ 2/3 บน `ProductDetails`; D-43's `ListView`/`item[]` approach ทำไม่สำเร็จ (SDK จำกัดไว้ที่ 1 `Image` widget ต่อ itemBuilder) แต่ **ใช้สำเร็จแล้วผ่าน scaffold-level `databaseRequest`+`nodeKeyRef` แทน (D-44/PT-26)** — ยังไม่ได้ทดสอบผ่านแอปจริง
>
> 📌 `shuffle_key` (`random()`, เพิ่ม 2026-08-19, D-45) — สุ่มลำดับสินค้าบน `Home` (`ORDER BY shuffle_key` แทน `created_at`) ค่าไม่ persist เพราะ view ไม่ materialize จึง recompute ใหม่ทุก SELECT จริง ทำที่ SQL แทน client-side shuffle เพราะ `SetState` ของ `List<PostgresRow>` field รับค่าจาก custom function ไม่ได้ (D-45/PT-27) — ยังไม่ได้ทดสอบผ่านแอปจริง
>
> 📌 `products.title` มี **GIN trigram index** (`products_title_trgm_idx`, `pg_trgm` extension, เพิ่ม 2026-08-19, D-46) — รองรับ `ILIKE '%keyword%'` (substring search บน `Home`) ให้ใช้ index แทน full table scan เมื่อข้อมูลโตขึ้น อยู่บนตาราง `products` ไม่ใช่ view (`products_review_view.title` เป็น passthrough ตรง ๆ ใช้ index เดียวกันได้) สร้างด้วย `CREATE INDEX` ธรรมดา ไม่ใช้ `CONCURRENTLY` เพราะ migration tool รันใน transaction block
>
> 📌 `chat_messages_view.has_message`/`has_image` (เพิ่ม 2026-08-18, D-41) — `chat_message.message`/`image_url` เป็น genuine `String?` ในโมเดล row ของ FlutterFlow (`getField<String>`) ไม่ใช่ `''` แทน null เทียบ `Equals(item['message'], '')` ตรง ๆ จึงพัง (`null == ''` เป็น false) ใช้ boolean คำนวณจาก SQL แทน

> 🔴 **กฎ: view ใดก็ตามที่ต้องการชื่อ/รูปผู้ใช้ ต้อง join `public_profiles` ห้าม join `"Profile"` ตรง ๆ**
> เหตุผลเต็มอยู่ `DECISIONS.md` D-01 — ละเมิดแล้วชื่อจะเป็น NULL เฉพาะตอน user ธรรมดาเปิดดู (admin เห็นปกติ จึงตรวจไม่เจอถ้าเทสด้วย admin อย่างเดียว)

> 📌 `admin_dashboard_stats` (L8, เพิ่ม 2026-08-14) join `"Profile"` ตรง ๆ แทน `public_profiles` **โดยตั้งใจ** — ต่างจากกฎด้านบน เพราะ view นี้ถูก `WHERE p.id = auth.uid()` กรองเหลือแค่แถวของตัวเองเสมอ (ไม่ใช่ list ของคนอื่น) จึงไม่เจอบั๊ก NULL แบบ D-01 · การนับ 5 ค่า (`total_users`/`banned_users`/`pending_products`/`approved_products`/`total_reports`) เป็น scalar subquery ธรรมดา **ไม่มี filter** จึงคืนแถวเดียวเสมอไม่มีทางว่าง (ต่างจาก query กรอง `id = auth.uid()` ที่ว่างได้ช่วงเฟรมแรกก่อน auth resolve — ดู PT-14) แต่ตัวนับยังนับจาก **มุมมองของ role ที่ query อยู่** ผ่าน `security_invoker` — user ทั่วไปที่ query ตรงจะได้ตัวเลขที่ถูก RLS ของตารางข้างในกรองแล้ว (เช่น `total_users` เหลือ 1 เพราะ `"Profile"` ให้เห็นแค่แถวตัวเอง) ไม่ใช่ตัวเลขจริงของทั้งระบบ — **ไม่ใช่ช่องโหว่ใหม่** แต่ก็ไม่ได้ปิดกั้นการยิง query ตรงแบบเข้มงวดตามที่ L8 DoD ต้องการเช่นกัน (`products`/`reports` policy ที่ตารางข้างในยังกว้างกว่าที่ควรอยู่แล้ว — ดู TODO ก่อน production ด้านล่าง)

---

```sql
-- security_invoker = true (ปกติ ไม่มี author name/avatar ให้ต้อง owner-run)
CREATE VIEW public.advertisement_posts_view WITH (security_invoker = true) AS
 SELECT p.id,
    p.image_url,
    COALESCE(p.title, ''::character varying) AS title,
    COALESCE(p.body, ''::text) AS body,
    p.created_at,
    p.is_active,
    COALESCE(l.like_count, 0::bigint)::integer AS like_count,
    (EXISTS ( SELECT 1
           FROM advertisement_likes al
          WHERE al.post_id = p.id AND al.user_id = auth.uid())) AS liked_by_me
   FROM advertisement_posts p
     LEFT JOIN ( SELECT advertisement_likes.post_id,
            count(*) AS like_count
           FROM advertisement_likes
          GROUP BY advertisement_likes.post_id) l ON l.post_id = p.id
  WHERE p.is_active = true;
```

> เพิ่ม 2026-08-22 (D-58) — `title`/`body` ผ่าน `COALESCE` กัน force-unwrap crash บน FF `Text` widget ตามธรรมเนียมเดิม (D-38) `WHERE is_active = true` กรองโพสต์ที่ถูกซ่อนออกให้ทุก caller (รวม `Home`) `liked_by_me` ใช้ `auth.uid()` ตรงในตัว view เอง

## RLS ที่ apply แล้ว

RLS `ENABLE` ครบทั้ง 12 ตาราง จำนวน policy ต่อตาราง (8 ตารางเดิม + `advertisement_posts`/`advertisement_likes` D-58 + `transactions` D-59 + `reviews` D-64):

| ตาราง | policy | สรุป |
|---|---|---|
| `"Profile"` | 4 | ดูตารางค่าจริงด้านล่าง |
| `products` | **7** | 4 PERMISSIVE ตาม cmd จริง (owner-or-admin, D-59 — ปิดหนี้ D-03 แล้ว) + **RESTRICTIVE กันผู้ถูกแบน 3 ตัว** (D-52) (+ trigger กัน moderation_status/rejection_reason และ status/buyer_id — ดู Function/Trigger) |
| `transactions` | 1 | อ่านได้เฉพาะคู่ค้า/แอดมิน (`buyer_id=auth.uid() OR seller_id=auth.uid() OR is_admin()`) เขียนได้ทาง `mark_product_sold()` เท่านั้น ไม่มี INSERT/UPDATE/DELETE policy เลย (D-59) |
| `chat` | 1 | membership-based ผ่าน `is_chat_member()` (D-29, 2026-08-16 — เดิม allow-all) |
| `chat_user` | 1 | membership-based ผ่าน `is_chat_member()` (D-29) |
| `chat_message` | **3** | membership-based select + insert เฉพาะของตัวเอง (D-29) + **RESTRICTIVE กันผู้ถูกแบน** (D-52) |
| `"CAT"` | 1 | allow-all — เป็นแค่ lookup |
| `reports` | **4** | admin อ่านทั้งหมด, reporter อ่าน/insert ของตัวเอง (D-24, 2026-08-15) + **RESTRICTIVE กันผู้ถูกแบน** (D-52) |
| `notifications` | **4** | user อ่าน/มาร์กอ่านเฉพาะของตัวเอง, admin insert **และอ่านทั้งหมด** (D-24 เพิ่ม admin-read แก้ root cause select-back RLS) |
| `advertisement_posts` | 4 | select: active หรือ admin · insert/update/delete: admin เท่านั้น (D-58) |
| `advertisement_likes` | 3 | select: ทุกคน (ให้ view's `EXISTS` ทำงาน) · insert/delete: เฉพาะแถวของตัวเอง (D-58) |
| `reviews` | **3** | select: ทุกคน (public rating) · insert: เฉพาะผู้ซื้อจริงของธุรกรรมนั้น (`EXISTS` เทียบ `transactions`) + **RESTRICTIVE กันผู้ถูกแบน** · ไม่มี UPDATE/DELETE เลย = immutable (D-64) |

**ค่าจริงจาก `pg_policies`** — PERMISSIVE ทั้งหมด **ยกเว้น 5 ตัวของ D-52 ที่เป็น `RESTRICTIVE`**

| ตาราง | policyname | cmd | roles | qual | with_check |
|---|---|---|---|---|---|
| `"CAT"` | Allow all for authenticated users | ALL | `{authenticated}` | `true` | `true` |
| `products` | products_select_all | SELECT | `{authenticated}` | `true` | – |
| `products` | products_insert_own | INSERT | `{authenticated}` | – | `seller_id = auth.uid()` |
| `products` | products_update_own_or_admin | UPDATE | `{authenticated}` | `seller_id = auth.uid() OR private.is_admin()` | เหมือน qual |
| `products` | products_delete_own_or_admin | DELETE | `{authenticated}` | `seller_id = auth.uid() OR private.is_admin()` | – |
| `transactions` | transactions_select_involved | SELECT | `{authenticated}` | `buyer_id = auth.uid() OR seller_id = auth.uid() OR private.is_admin()` | – |
| `chat` | chat_select_if_member | SELECT | `{authenticated}` | `is_chat_member(id)` | – |
| `chat_user` | chat_user_select_if_member | SELECT | `{authenticated}` | `is_chat_member(chat_id)` | – |
| `chat_message` | chat_message_select_if_member | SELECT | `{authenticated}` | `is_chat_member(chat_id)` | – |
| `chat_message` | chat_message_insert_own | INSERT | `{authenticated}` | – | `user_id = auth.uid() AND is_chat_member(chat_id)` |
| `"Profile"` | Users can view own profile | SELECT | `{public}` | `(auth.uid() = id)` | – |
| `"Profile"` | Admins can view all profiles | SELECT | `{public}` | `private.is_admin()` | – |
| `"Profile"` | Admins can update all profiles | UPDATE | `{public}` | `private.is_admin()` | – |
| `"Profile"` | Users can update own profile | UPDATE | `{authenticated}` | `(auth.uid() = id)` | ↓ |
| `reports` | admin can read reports | SELECT | `{authenticated}` | `private.is_admin()` | – |
| `reports` | reporter can read own reports | SELECT | `{authenticated}` | `(reporter_id = auth.uid())` | – |
| `reports` | authenticated can report | INSERT | `{authenticated}` | – | `(reporter_id = auth.uid())` |
| `notifications` | users can read own notifications | SELECT | `{authenticated}` | `(user_id = auth.uid())` | – |
| `notifications` | admin can read all notifications | SELECT | `{authenticated}` | `private.is_admin()` | – |
| `notifications` | users can mark own notifications read | UPDATE | `{authenticated}` | `(user_id = auth.uid())` | `(user_id = auth.uid())` |
| `notifications` | admin can insert notifications | INSERT | `{authenticated}` | – | `private.is_admin()` |
| `advertisement_posts` | Public can view active ads, admins view all | SELECT | `{authenticated}` | `is_active = true OR private.is_admin()` | – |
| `advertisement_posts` | Admins can insert ad posts | INSERT | `{authenticated}` | – | `private.is_admin()` |
| `advertisement_posts` | Admins can update ad posts | UPDATE | `{authenticated}` | `private.is_admin()` | `private.is_admin()` |
| `advertisement_posts` | Admins can delete ad posts | DELETE | `{authenticated}` | `private.is_admin()` | – |
| `advertisement_likes` | Anyone can view ad likes | SELECT | `{authenticated}` | `true` | – |
| `advertisement_likes` | Users can like as themselves | INSERT | `{authenticated}` | – | `user_id = auth.uid()` |
| `advertisement_likes` | Users can remove their own like | DELETE | `{authenticated}` | `user_id = auth.uid()` | – |
| `reviews` | reviews_select_all | SELECT | `{authenticated}` | `true` | – |
| `reviews` | reviews_insert_buyer_only | INSERT | `{authenticated}` | – | `reviewer_id = auth.uid() AND EXISTS(SELECT 1 FROM transactions t WHERE t.id = transaction_id AND t.buyer_id = auth.uid() AND t.seller_id = reviewee_id)` |

**RESTRICTIVE — กันผู้ถูกแบน (D-52, 2026-08-21) ทุกตัว `TO authenticated`**

| ตาราง | policyname | cmd | qual (USING) | with_check |
|---|---|---|---|---|
| `products` | products_block_banned_insert | INSERT | – | `NOT private.is_banned()` |
| `products` | products_block_banned_update | UPDATE | `NOT private.is_banned()` | `NOT private.is_banned()` |
| `products` | products_block_banned_delete | DELETE | `NOT private.is_banned()` | – |
| `reports` | reports_block_banned_insert | INSERT | – | `NOT private.is_banned()` |
| `chat_message` | chat_message_block_banned_insert | INSERT | – | `NOT private.is_banned() OR private.chat_has_admin(chat_id)` |
| `reviews` | reviews_block_banned_insert | INSERT | – | `NOT private.is_banned()` |

```sql
-- with_check ของ "Users can update own profile" (ค่าจริง คำต่อคำ)
((auth.uid() = id)
 AND ((role)::text = (private.current_profile_role())::text)
 AND ((private.current_profile_student_id() IS NULL)
      OR ((student_id)::text = (private.current_profile_student_id())::text)))
```

> 🔴 **`with_check` นี้ไม่ได้ล็อก `is_banned`** — ของเดิมล็อกแค่ `role`/`student_id` ผู้ถูกแบนยิง API ตรงปลดแบนตัวเองได้ **ปิดด้วย trigger `enforce_ban_admin_only` แทน** (D-52) ไม่ใช่แก้ policy นี้ เพราะ trigger คุมครบทั้ง 4 คอลัมน์ ban ในที่เดียว
>
> 🔴 **ทำไมต้อง `RESTRICTIVE`** — ตอนสร้าง (D-52) `products` ยังเป็น allow-all อยู่ การเพิ่ม PERMISSIVE policy จะ **OR** กับ allow-all แล้วไม่มีผลอะไรเลย (บทเรียนเดียวกับ D-23) `RESTRICTIVE` **AND** ทับผลรวมจึงบังคับได้จริง — ปิดหนี้ D-03 แล้ว (D-59, `products` ไม่ allow-all อีกต่อไป) แต่ 5 ตัวนี้ยังทำงานถูกต้องเหมือนเดิมเพราะ RESTRICTIVE แคบกว่า PERMISSIVE เสมอไม่ว่าฐานจะกว้างแค่ไหน ไม่ต้องแก้อะไร · ทั้ง 5 ตัวจงใจไม่แตะ `SELECT` เพราะเป็น **soft ban** (ผู้ถูกแบนยังท่องแอปได้)
>
> ⚠️ **RESTRICTIVE `USING` บล็อกแบบเงียบ ไม่ raise** — `UPDATE`/`DELETE` ของผู้ถูกแบนคืน **0 แถว** ไม่ใช่ error (ต่างจาก `WITH_CHECK` ที่ raise `42501`) ยืนยันด้วย `GET DIAGNOSTICS ROW_COUNT` แล้ว — ฝั่ง FlutterFlow จะไม่เห็น error ต้องปิด affordance ที่ UI ด้วย

> ⚠️ 3 policy ที่ `roles = {public}` (ไม่ใช่ `authenticated`) ครอบคลุม `anon` ด้วย — ปลอดภัยอยู่เพราะ `auth.uid()` / `is_admin()` เป็น NULL/false สำหรับ anon แต่ควรเปลี่ยนเป็น `authenticated` ให้ชัดเจน

> ✅ **D-03 ปิดแล้ว (D-59, 2026-08-23):** `products` ไม่ allow-all อีกต่อไป — 4 policy ตาม cmd จริง (owner-or-admin) เหมือน `chat`/`chat_user`/`chat_message` ที่ปิดหนี้เดียวกันนี้ตั้งแต่ D-29 (`is_chat_member()`) — ทดสอบแล้วว่า non-owner เห็น 0 แถวตอนแก้ (impersonation test)

**วิธีดู RLS จริง** — `list_tables` ไม่คืน policy ต้องรัน:

```sql
SELECT tablename, policyname, permissive, cmd, roles, qual, with_check
FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename, policyname;
```

---

## Realtime ที่เปิดแล้ว

`supabase_realtime` มี 4 ตาราง: `public.chat` · `public.chat_message` · `public.products` · `public.notifications` (เพิ่ม 2026-08-24, กำลังต่อ FlutterFlow ฝั่ง L4/L6)

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_message;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat;
ALTER PUBLICATION supabase_realtime ADD TABLE public.products;  -- จำเป็นสำหรับ reject-alert flow (L2)
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;  -- L6, ยังไม่มี FlutterFlow subscribe
```

ตรวจ: `SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';`

---

## Function / Trigger ที่ apply แล้ว

19 function (`public` 10 + `private` 9) · 5 trigger — ทั้งหมดคือผล `pg_get_functiondef()` / `pg_get_triggerdef()` ของจริง

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

### `private.enforce_moderation_admin_only()` + trigger `enforce_moderation_admin_only` (L8, เพิ่ม 2026-08-14)

```sql
CREATE OR REPLACE FUNCTION private.enforce_moderation_admin_only()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  IF NOT private.is_admin() THEN
    RAISE EXCEPTION 'Only admins can change moderation_status or rejection_reason';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER enforce_moderation_admin_only
  BEFORE UPDATE ON public.products
  FOR EACH ROW
  WHEN (((old.moderation_status)::text IS DISTINCT FROM (new.moderation_status)::text)
        OR (old.rejection_reason IS DISTINCT FROM new.rejection_reason))
  EXECUTE FUNCTION private.enforce_moderation_admin_only();   -- tgenabled = 'O' (เปิดอยู่)
```

- ไม่ใช่ `SECURITY DEFINER` — เรียก `private.is_admin()` (ตัวนั้น definer อยู่แล้ว) ไม่ต้อง bypass เพิ่ม
- `WHEN` เทียบ OLD/NEW ก่อนเรียกฟังก์ชัน — แก้ title/price/images ปกติไม่โดน trigger นี้
- ใช้ trigger ไม่ใช่ policy เพราะ permissive policy OR กับ allow-all เดิมของ `products` เสมอ (ไม่มีผล) และ `WITH CHECK` เทียบ OLD/NEW ไม่ได้ — ยืนยันด้วย impersonation test จริง (ดู D-23)
- คุ้มกันแค่ 2 คอลัมน์นี้ — คอลัมน์อื่นยังอยู่ใต้ allow-all เดิม (D-03)

### L8 ban — `private.is_banned` / `is_user_banned` / `chat_has_admin` (เพิ่ม 2026-08-21, D-52)

```sql
-- ผู้เรียกถูกแบนไหม — ใช้ใน RESTRICTIVE policy ทั้ง 5 ตัว
CREATE OR REPLACE FUNCTION private.is_banned()
 RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT COALESCE((SELECT is_banned FROM public."Profile" WHERE id = auth.uid()), false);
$function$;

-- user คนนั้นถูกแบนไหม — ใช้ใน products_review_view
CREATE OR REPLACE FUNCTION private.is_user_banned(target uuid)
 RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT COALESCE((SELECT is_banned FROM public."Profile" WHERE id = target), false);
$function$;

-- ห้องแชทนี้มีแอดมินไหม — ข้อยกเว้น "ช่องอุทธรณ์" ใน chat_message policy
CREATE OR REPLACE FUNCTION private.chat_has_admin(target_chat_id bigint)
 RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.chat_user cu
    JOIN public."Profile" p ON p.id = cu.user_id
    WHERE cu.chat_id = target_chat_id AND p.role = 'admin'
  );
$function$;
```

- 🔴 **`COALESCE(..., false)` จำเป็น** — มีบัญชี `auth.users` ที่ไม่มีแถว `"Profile"` จริง (D-32) ถ้าคืน NULL จะโดนบล็อกทั้งที่ไม่ได้ถูกแบน
- 🔴 `is_user_banned` ต้อง **SECURITY DEFINER** เพราะ `"Profile"` RLS ซ่อนแถวคนอื่น — ถ้าเป็น invoker จะคืน NULL แล้วซ่อนประกาศไม่สำเร็จ
- grant: `authenticated` + `service_role` (ตรงกับ `private.is_admin()` เป๊ะ) — `anon` ไม่ได้

### `private.enforce_ban_admin_only()` + trigger `enforce_ban_admin_only` (L8, เพิ่ม 2026-08-21, D-52)

```sql
CREATE OR REPLACE FUNCTION private.enforce_ban_admin_only()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  IF NOT private.is_admin() THEN
    RAISE EXCEPTION 'Only admins can change ban status';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER enforce_ban_admin_only
  BEFORE UPDATE ON public."Profile"
  FOR EACH ROW
  WHEN (old.is_banned  IS DISTINCT FROM new.is_banned
     OR old.ban_reason IS DISTINCT FROM new.ban_reason
     OR old.banned_at  IS DISTINCT FROM new.banned_at
     OR old.banned_by  IS DISTINCT FROM new.banned_by)
  EXECUTE FUNCTION private.enforce_ban_admin_only();   -- tgenabled = 'O' (เปิดอยู่)
```

- แม่แบบเดียวกับ `enforce_moderation_admin_only` เป๊ะ (D-23) — ปิดช่องที่ `with_check` ของ `Users can update own profile` ล็อกไม่ถึง
- คุม 4 คอลัมน์ในที่เดียว · `WHEN` เทียบ OLD/NEW ก่อน แก้ `full_name`/`avatar_url` ปกติไม่โดน
- ยังผ่านตอน `admin_set_user_ban` เรียก เพราะ `private.is_admin()` อ่าน `auth.uid()` ซึ่งคงเป็นแอดมินคนเรียกแม้อยู่ใน SECURITY DEFINER

### `public.admin_set_user_ban()` (L8, เพิ่ม 2026-08-21, D-52)

```sql
CREATE OR REPLACE FUNCTION public.admin_set_user_ban(
  target_user_id uuid, should_ban boolean, reason text DEFAULT NULL
) RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT private.is_admin() THEN RAISE EXCEPTION 'only admins can ban or unban users'; END IF;
  IF target_user_id = auth.uid() THEN RAISE EXCEPTION 'cannot ban yourself'; END IF;
  IF should_ban AND EXISTS (
    SELECT 1 FROM public."Profile" WHERE id = target_user_id AND role = 'admin'
  ) THEN RAISE EXCEPTION 'cannot ban an admin'; END IF;
  IF should_ban AND btrim(coalesce(reason, '')) = '' THEN
    RAISE EXCEPTION 'ban reason is required'; END IF;

  UPDATE public."Profile" SET
    is_banned  = should_ban,
    ban_reason = CASE WHEN should_ban THEN btrim(reason) ELSE NULL END,
    banned_at  = CASE WHEN should_ban THEN now()         ELSE NULL END,
    banned_by  = CASE WHEN should_ban THEN auth.uid()    ELSE NULL END
  WHERE id = target_user_id
    AND is_banned IS DISTINCT FROM should_ban;   -- PT-05: กันกดซ้ำ

  IF NOT FOUND THEN RETURN; END IF;              -- อยู่สถานะนั้นแล้ว ไม่ยิงแจ้งเตือนซ้ำ

  INSERT INTO public.notifications (user_id, type, title, body) VALUES (
    target_user_id,
    CASE WHEN should_ban THEN 'account_banned' ELSE 'account_unbanned' END,
    CASE WHEN should_ban THEN 'บัญชีของคุณถูกระงับ' ELSE 'บัญชีของคุณถูกปลดระงับแล้ว' END,
    CASE WHEN should_ban THEN btrim(reason)
         ELSE 'คุณสามารถลงประกาศและแชทได้ตามปกติแล้ว' END
  );
END;
$function$;
```

- **ทางเดียวที่เขียน `is_banned` ได้** — trigger บล็อกทุกเส้นทางอื่น
- guard 4 ชั้นในตัวเอง (ไม่เชื่อ client เลย ตาม D-29): ต้องเป็นแอดมิน · แบนตัวเองไม่ได้ · แบนแอดมินไม่ได้ · เหตุผลห้ามว่าง
- `IS DISTINCT FROM` + `IF NOT FOUND RETURN` = idempotent กดซ้ำไม่ยิงแจ้งเตือนซ้ำ (ยืนยันแล้ว)
- 🔴 **insert notification ฝั่ง server โดยตั้งใจ** — ไม่ผ่าน PostgREST จึงไม่โดน select-back ที่เคยฆ่า action chain เงียบ ๆ ใน D-24 และเป็นทางเดียวที่ได้ error handling จริงเพราะ Postgres action ใน DSL ไม่มี `onSuccess`/`onFailure` (PT-18)
- grant: `authenticated` เท่านั้น (`PUBLIC`/`anon` revoke แล้ว) — advisor เตือน `authenticated_security_definer_function_executable` เป็นเรื่องปกติ คลาสเดียวกับ `mark_report_read`/`find_or_create_chat` ที่ guard ในตัวเองเหมือนกัน

### L4 chat — `is_chat_member` / `find_or_create_chat` / `update_chat_last_message` / `get_my_chats` (เพิ่ม 2026-08-16, D-29)

```sql
CREATE OR REPLACE FUNCTION public.is_chat_member(target_chat_id bigint)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  SELECT EXISTS (SELECT 1 FROM chat_user WHERE chat_id = target_chat_id AND user_id = auth.uid());
$function$;

CREATE OR REPLACE FUNCTION public.find_or_create_chat(user_a uuid, user_b uuid)
 RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE existing_chat_id bigint; new_chat_id bigint;
BEGIN
  IF auth.uid() IS DISTINCT FROM user_a THEN
    RAISE EXCEPTION 'user_a must be the authenticated caller';
  END IF;
  SELECT cu1.chat_id INTO existing_chat_id
  FROM chat_user cu1 JOIN chat_user cu2 ON cu1.chat_id = cu2.chat_id
  WHERE cu1.user_id = user_a AND cu2.user_id = user_b LIMIT 1;
  IF existing_chat_id IS NOT NULL THEN RETURN existing_chat_id; END IF;
  -- D-52: ผู้ถูกแบนเปิดห้องใหม่ไม่ได้ (ห้องเดิมยังเข้าได้ เพราะ guard อยู่หลัง early-return)
  IF private.is_banned() THEN
    RAISE EXCEPTION 'banned users cannot start new chats';
  END IF;
  INSERT INTO chat (last_message) VALUES ('เริ่มการสนทนาแล้ว') RETURNING id INTO new_chat_id;
  INSERT INTO chat_user (chat_id, user_id) VALUES (new_chat_id, user_a), (new_chat_id, user_b);
  RETURN new_chat_id;
END; $function$;

CREATE OR REPLACE FUNCTION public.update_chat_last_message() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE public.chat SET last_message = COALESCE(NEW.message, '📷 รูปภาพ') WHERE id = NEW.chat_id;
  RETURN NEW;
END; $function$;

CREATE TRIGGER trg_update_last_message
  AFTER INSERT ON public.chat_message
  FOR EACH ROW EXECUTE FUNCTION update_chat_last_message();   -- tgenabled = 'O'

CREATE OR REPLACE FUNCTION public.get_my_chats() RETURNS SETOF chat_summary
 LANGUAGE sql STABLE
AS $function$ SELECT * FROM public.chat_summary ORDER BY created_at DESC; $function$;

CREATE OR REPLACE FUNCTION public.find_or_create_chat_with_admin(user_a uuid)
 RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE admin_id uuid; existing_chat_id bigint; new_chat_id bigint;
BEGIN
  IF auth.uid() IS DISTINCT FROM user_a THEN
    RAISE EXCEPTION 'user_a must be the authenticated caller';
  END IF;
  SELECT id INTO admin_id FROM "Profile" WHERE role = 'admin' ORDER BY created_at ASC LIMIT 1;
  IF admin_id IS NULL THEN RAISE EXCEPTION 'no admin account available'; END IF;
  IF admin_id = user_a THEN RAISE EXCEPTION 'caller is already an admin'; END IF;
  SELECT cu1.chat_id INTO existing_chat_id
  FROM chat_user cu1 JOIN chat_user cu2 ON cu1.chat_id = cu2.chat_id
  WHERE cu1.user_id = user_a AND cu2.user_id = admin_id LIMIT 1;
  IF existing_chat_id IS NOT NULL THEN RETURN existing_chat_id; END IF;
  INSERT INTO chat (last_message) VALUES ('เริ่มการสนทนาแล้ว') RETURNING id INTO new_chat_id;
  INSERT INTO chat_user (chat_id, user_id) VALUES (new_chat_id, user_a), (new_chat_id, admin_id);
  RETURN new_chat_id;
END; $function$;
```

- **`is_chat_member`** — SECURITY DEFINER เพื่อเลี่ยง RLS วนซ้ำตัวเองบน `chat_user` (self-referential policy) EXECUTE grant ให้เฉพาะ `authenticated` (revoke `anon` ออกแล้ว — ค่า default ของ Supabase คือ grant `anon` ให้อัตโนมัติตอน `CREATE FUNCTION` ต้อง revoke เองทีละ role ไม่ใช่แค่ `REVOKE ... FROM PUBLIC`)
- **`find_or_create_chat_with_admin`** (เพิ่ม 2026-08-16, D-30) — เหมือน `find_or_create_chat` (guard impersonation, default `last_message`) ต่างแค่ `user_b` ไม่ได้รับจาก caller แต่หาเองจาก `"Profile" WHERE role='admin' ORDER BY created_at ASC LIMIT 1` (แอดมินคนแรกสุด แบบ deterministic) — ต้องเป็น SECURITY DEFINER เพราะ RLS ของ `"Profile"` ปกติไม่ให้ user ธรรมดาเห็นแถวของแอดมิน EXECUTE grant `authenticated` เท่านั้น ทดสอบแล้วว่า idempotent + ได้แอดมินที่คาดหวังจริง (`mju6577778888`)
- 🔴 **`find_or_create_chat_with_admin` จงใจ *ไม่มี* ban guard** ต่างจาก `find_or_create_chat` (D-52) — เป็น **ช่องอุทธรณ์** ของผู้ถูกแบน คู่กับข้อยกเว้น `private.chat_has_admin(chat_id)` ใน policy `chat_message_block_banned_insert` ถ้าใส่ guard ที่นี่ = ตัดทางติดต่อแอดมินทิ้ง ผู้ถูกแบนจะอุทธรณ์ไม่ได้เลย

```sql
CREATE OR REPLACE FUNCTION public.mark_chat_read(target_chat_id bigint)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE public.chat_user SET last_read_at = now()
  WHERE chat_id = target_chat_id AND user_id = auth.uid();
END; $function$;

CREATE OR REPLACE FUNCTION public.mark_report_read(target_report_id uuid)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT private.is_admin() THEN
    RAISE EXCEPTION 'only admins can mark reports read';
  END IF;
  UPDATE public.reports SET is_read = true WHERE id = target_report_id;
END; $function$;
```

- **`mark_chat_read`** (เพิ่ม 2026-08-17, D-31) — `UPDATE` แค่แถว `chat_user` ของ**ตัวเองเท่านั้น** (`user_id = auth.uid()`) จงใจ**ไม่**ให้ authenticated แก้ `chat_user` ตรง ๆ ผ่าน table grant (จะเปิดช่องให้ user ปลอมตัวเป็นสมาชิกห้องไหนก็ได้ด้วยการ INSERT/UPDATE `chat_user` เอง — เท่ากับ bypass `is_chat_member()` ทั้งระบบ) EXECUTE grant `authenticated` เท่านั้น
- **`mark_report_read`** (เพิ่ม 2026-08-17, D-31) — เฉพาะ admin เท่านั้น (`private.is_admin()` guard, ทดสอบแล้วว่า non-admin โดนปฏิเสธจริง) EXECUTE grant `authenticated` เท่านั้น
- **`find_or_create_chat`** — เดิมดราฟต์ (`PROPOSED_SQL.md` P-03) ไม่มี guard `auth.uid()` เทียบ `user_a` เพิ่มเข้าไปตอน apply จริงกันไม่ให้ user คนหนึ่งบังคับสร้างห้องแทนคนอื่น · `INSERT INTO chat (last_message)` ใช้ข้อความ default แทน `NULL` เพราะฝั่ง FlutterFlow force-unwrap ค่านี้ (`lastMessage!` ใน `chat_list_widget.dart`) EXECUTE grant `authenticated` เท่านั้น
- **`update_chat_last_message`** — trigger-only ไม่มี EXECUTE grant ให้ role ไหนเลย (เรียกผ่าน trigger ไม่ต้องมี grant)
- **`get_my_chats()`** — ไม่มี parameter, `SECURITY INVOKER` (default) พึ่ง RLS ของ `chat`/`chat_user` กรองให้ทั้งหมด — **ยังไม่มีใครเรียกใช้จริง** ฝั่ง FlutterFlow ผูก `chat_summary` ตรง ๆ แบบไม่มี filter แทน (RLS กรองให้แล้ว ไม่ต้อง array-contains) EXECUTE grant `authenticated` เท่านั้น
- ทั้ง 3 ฟังก์ชันที่เป็น `SECURITY DEFINER`/มี query ภายใน (`is_chat_member`, `find_or_create_chat`, `update_chat_last_message`) pin `search_path = public` กันโจมตีแบบ search_path hijack

### L5 sale — `mark_product_sold()` + trigger `enforce_sale_via_rpc_only` (เพิ่ม 2026-08-23, D-59)

```sql
CREATE OR REPLACE FUNCTION public.mark_product_sold(target_chat_id bigint, target_product_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  the_buyer_id uuid;
  the_price numeric;
BEGIN
  IF private.is_banned() THEN
    RAISE EXCEPTION 'บัญชีถูกระงับ ไม่สามารถทำรายการนี้ได้';
  END IF;

  IF NOT is_chat_member(target_chat_id) THEN
    RAISE EXCEPTION 'คุณไม่ใช่สมาชิกของแชทนี้';
  END IF;

  SELECT user_id INTO the_buyer_id
  FROM chat_user
  WHERE chat_id = target_chat_id AND user_id IS DISTINCT FROM auth.uid()
  LIMIT 1;

  IF the_buyer_id IS NULL THEN
    RAISE EXCEPTION 'ไม่พบคู่สนทนาในแชทนี้';
  END IF;

  PERFORM set_config('app.via_mark_sold_rpc', 'true', true);

  UPDATE products
     SET status = 'sold', buyer_id = the_buyer_id
   WHERE id = target_product_id
     AND seller_id = auth.uid()
     AND status IS DISTINCT FROM 'sold'
   RETURNING price INTO the_price;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ไม่พบประกาศนี้ ไม่ใช่ของคุณ หรือถูกขายไปแล้ว';
  END IF;

  INSERT INTO transactions (product_id, buyer_id, seller_id, price, chat_id)
  VALUES (target_product_id, the_buyer_id, auth.uid(), the_price, target_chat_id);
END;
$function$;

CREATE OR REPLACE FUNCTION private.enforce_sale_via_rpc_only()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  IF current_setting('app.via_mark_sold_rpc', true) IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'status/buyer_id เปลี่ยนได้เฉพาะผ่าน mark_product_sold() เท่านั้น';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER enforce_sale_via_rpc_only
  BEFORE UPDATE ON public.products
  FOR EACH ROW
  WHEN (((old.status)::text IS DISTINCT FROM (new.status)::text)
        OR (old.buyer_id IS DISTINCT FROM new.buyer_id))
  EXECUTE FUNCTION private.enforce_sale_via_rpc_only();   -- tgenabled = 'O' (เปิดอยู่)
```

- **`mark_product_sold`** — SECURITY DEFINER เหมือน `admin_set_user_ban` (D-52): เช็ค `is_banned()`/`is_chat_member()` เอง เพราะ SECURITY DEFINER bypass RLS ของ `products`/`chat_user` ไปแล้ว ไม่ได้แปลว่า bypass การเช็คสิทธิ์เชิงตรรกะไปด้วย ผู้ซื้อหาจาก `chat_user` (สมาชิกอีกคนของแชท ไม่ใช่พารามิเตอร์จาก caller — `chatMessages` ไม่มี concept ผู้ซื้อให้เลือก) `UPDATE ... WHERE status IS DISTINCT FROM 'sold'` กัน race condition (PT-05) `INSERT INTO transactions` อยู่ในฟังก์ชันเดียวกันเลี่ยง select-back (D-24) EXECUTE grant `authenticated` เท่านั้น (revoke `anon` ออกแล้ว ตามกฎเดียวกับ `is_chat_member`)
- **`enforce_sale_via_rpc_only`** — ไม่ใช่ SECURITY DEFINER (ต่างจาก `enforce_moderation_admin_only`/D-23 ที่เรียก `private.is_admin()`) เพราะแค่เช็ค session-local GUC ไม่ต้อง privilege เพิ่ม บล็อกการแก้ `status`/`buyer_id` ตรง ๆ **ทุกทาง ไม่มีข้อยกเว้น แม้เจ้าของ/แอดมิน** — `mark_product_sold()` ตั้ง `app.via_mark_sold_rpc = 'true'` (transaction-scoped, `is_local=true`) ก่อน `UPDATE` ของตัวเองเท่านั้น `WHEN` เทียบ OLD/NEW ก่อนเรียกฟังก์ชัน (แก้ field อื่นของ `products` ปกติไม่โดน trigger นี้)

### L3 search — `search_products()` (เพิ่ม 2026-08-24, D-62, ปิดข้อเสนอ P-05)

```sql
CREATE OR REPLACE FUNCTION public.search_products(
  keyword text DEFAULT NULL,
  p_category_id bigint DEFAULT NULL,
  min_price numeric DEFAULT NULL,
  max_price numeric DEFAULT NULL
)
RETURNS SETOF public.products_review_view
LANGUAGE sql
STABLE
AS $$
  SELECT *
  FROM public.products_review_view
  WHERE moderation_status = 'approved'
    AND status <> 'sold'
    AND (keyword IS NULL OR keyword = '' OR title ILIKE '%'||keyword||'%' OR description ILIKE '%'||keyword||'%')
    AND (p_category_id IS NULL OR category_id = p_category_id)
    AND (min_price IS NULL OR price >= min_price)
    AND (max_price IS NULL OR price <= max_price)
  ORDER BY random()
  LIMIT 50;
$$;

REVOKE ALL ON FUNCTION public.search_products(text, bigint, numeric, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_products(text, bigint, numeric, numeric) TO authenticated;
```

- **`search_products`** — `LANGUAGE sql` ธรรมดา ไม่ใช่ SECURITY DEFINER (ไม่ต้อง bypass อะไร — `products_review_view` เป็น `security_invoker=true` อยู่แล้ว กรอง banned-seller/RLS ให้ตามปกติ) `RETURNS SETOF products_review_view` แทน `products` ตรง ๆ (ตาม P-05 note เดิม) เพื่อให้ได้ `category_name`/`seller_name`/`first_image_url`/`can_see_buyer` ฯลฯ ติดมาครบ ไม่ต้อง query ซ้ำฝั่ง FlutterFlow แทนที่ built-in typed-filter ของ D-45–D-48 ทั้งชุด (exact-match only เพราะ `iLike`/`like` ไม่มี null-safe codegen ในระบบ FlutterFlow AI SDK นี้) ทุกพารามิเตอร์ optional (`NULL` = ไม่กรองแกนนั้น) ANDed กันหมด — คำค้นค้นทั้ง `title`/`description` (กว้างกว่า P-05 draft เดิมที่มีแค่ title) `title` มี GIN trigram index อยู่แล้ว (D-46) EXECUTE grant `authenticated` เท่านั้น (revoke `anon`/PUBLIC ออกแล้ว — สอดคล้องกับคำตอบ pete ว่าไม่เปิด browse ก่อน login)

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

### bucket `chat-images` (L4, เพิ่ม 2026-08-16, D-29)

| ค่า | |
|---|---|
| `public` | **true** — เหตุผลเดียวกับ `product-images`/`avatars` (D-12): path เดาไม่ได้ก็ยอมรับความเสี่ยงได้ ยังไม่มี signed-URL infra |
| `file_size_limit` | `5242880` (5 MB ต่อไฟล์ — เท่า `product-images`) |
| `allowed_mime_types` | `{image/jpeg, image/png, image/webp}` |

🔴 **path บังคับ `<auth.uid()>/<ชื่อไฟล์>`** เหมือนกัน

| policyname | cmd | roles | qual / with_check |
|---|---|---|---|
| `chat-images: public read` | SELECT | `{public}` | qual: `(bucket_id = 'chat-images'::text)` |
| `chat-images: owner upload` | INSERT | `{authenticated}` | with_check: ↓ |
| `chat-images: owner update` | UPDATE | `{authenticated}` | qual **และ** with_check: ↓ |
| `chat-images: owner delete` | DELETE | `{authenticated}` | qual: ↓ |

```sql
-- นิพจน์ ↓ เหมือน product-images/avatars ทุกตัวอักษร
((bucket_id = 'chat-images'::text)
 AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text))
```

> ⚠️ **ยังไม่มีฝั่ง FlutterFlow อัปโหลดเข้า bucket นี้เลย** — schema/policy พร้อมแล้ว รอ Action Flow ส่งรูป (ดู `layers/L4-chat.md`)

### bucket `ad-post-images` (L8, เพิ่ม 2026-08-22, D-58)

| ค่า | |
|---|---|
| `public` | **true** — เหตุผลเดียวกับ bucket อื่น (D-12) |
| `file_size_limit` | `5242880` (5 MB) |
| `allowed_mime_types` | `{image/jpeg, image/png, image/webp}` |

**ไม่มี owner-folder check แบบ bucket อื่น** — เขียนได้เฉพาะแอดมิน ไม่ใช่ owner ของตัวเอง:

| policyname | cmd | roles | qual / with_check |
|---|---|---|---|
| `Public can view ad post images` | SELECT | `{public}` | qual: `bucket_id = 'ad-post-images'` |
| `Admins can upload ad post images` | INSERT | `{authenticated}` | with_check: `bucket_id = 'ad-post-images' AND private.is_admin()` |
| `Admins can update ad post images` | UPDATE | `{authenticated}` | qual **และ** with_check เหมือนกัน |
| `Admins can delete ad post images` | DELETE | `{authenticated}` | qual: `bucket_id = 'ad-post-images' AND private.is_admin()` |

folder path อัปโหลดใช้ `<auth.uid() ของแอดมิน>/<ชื่อไฟล์>` เพื่อจัดระเบียบ (ไม่ใช่ RLS requirement — policy เช็คแค่ `is_admin()`)

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
