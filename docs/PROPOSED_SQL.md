# PROPOSED_SQL.md — SQL ที่ยังไม่ apply

> 🚧 **ทุกอย่างในไฟล์นี้ยังไม่มีอยู่จริงในฐานข้อมูล**
> ห้าม reference ในโค้ด/Action Flow จนกว่าจะ apply แล้วย้ายไป `SCHEMA.md`
> เมื่อ apply แล้ว: ลบออกจากไฟล์นี้ → เพิ่มเข้า `SCHEMA.md` → บันทึกเหตุผลที่ `DECISIONS.md`

> 📌 **P-01 / P-02 ถูกลบออกจากไฟล์นี้แล้ว** — apply อยู่ใน DB จริง (`handle_new_user()` + trigger `on_auth_user_created`) อ่านที่ `SCHEMA.md` แทน
> เลข P-01/P-02 **เลิกใช้ ห้ามเอากลับมาใช้ซ้ำ** · ประวัติเต็มอยู่ใน git และ `DECISIONS.md` D-11
>
> 📌 **P-07 ถูกลบออกจากไฟล์นี้แล้ว** — apply อยู่ใน DB จริง (ตาราง `notifications` + RLS + trigger `enforce_moderation_admin_only`) อ่านที่ `SCHEMA.md` แทน
> เลข P-07 **เลิกใช้ ห้ามเอากลับมาใช้ซ้ำ** · เหตุผลออกแบบเต็มอยู่ `DECISIONS.md` **D-23**
>
> 📌 **P-10 ถูกลบออกจากไฟล์นี้แล้ว** — apply อยู่ใน DB จริง (`reports` มี 3 policy: admin-read, reporter-read-own, authenticated-insert) อ่านที่ `SCHEMA.md` แทน
> เลข P-10 **เลิกใช้ ห้ามเอากลับมาใช้ซ้ำ** · เหตุผลออกแบบเต็มอยู่ `DECISIONS.md` **D-24**
>
> 📌 **P-03 / P-04 ถูกลบออกจากไฟล์นี้แล้ว** — apply อยู่ใน DB จริง (`find_or_create_chat`/`update_chat_last_message`/`is_chat_member`/`get_my_chats` + trigger + RLS membership-based) อ่านที่ `SCHEMA.md` แทน โค้ดจริงต่างจากดราฟต์เดิม (เพิ่ม impersonation guard, `is_chat_member` helper, ค่า default `last_message`, COALESCE รูปภาพ)
> เลข P-03/P-04 **เลิกใช้ ห้ามเอากลับมาใช้ซ้ำ** · เหตุผลออกแบบเต็มอยู่ `DECISIONS.md` **D-29**

| # | ของ | Layer | สถานะ |
|---|---|---|---|
| P-05 | `search_products(...)` | L3 | รอทดสอบว่า FF filter พอไหม |
| P-06 | ตาราง `transactions` | L5 | รอ confirm ค่า status |
| P-08 | ตาราง `reviews` | L7 | ยังไม่เริ่ม |
| P-09 | `reports.reported_user_id` | L7 | รอตัดสินใจว่าจะรีพอร์ตผู้ใช้ไหม |
| P-11 | unique index บน `lower("Profile".email)` | L1 | **ข้อเสนอของ Claude pete ยังไม่ตอบรับ** |
| P-12 | เก็บกวาดไฟล์กำพร้าใน Storage | L1/L2/L5 | **ข้อเสนอของ Claude pete ยังไม่ตอบรับ** — แนวทางยังไม่เลือก |

---

## P-05 — full-text search (L3)

```sql
CREATE OR REPLACE FUNCTION search_products(keyword text, cat_id bigint, min_price numeric, max_price numeric)
RETURNS SETOF products AS $$
  SELECT * FROM products
  WHERE (keyword IS NULL OR title ILIKE '%'||keyword||'%' OR description ILIKE '%'||keyword||'%')
    AND (cat_id IS NULL OR category_id = cat_id)
    AND (min_price IS NULL OR price >= min_price)
    AND (max_price IS NULL OR price <= max_price)
    AND moderation_status = 'approved';
$$ LANGUAGE sql STABLE;
```

> ถ้าจะใช้จริง แนะนำเปลี่ยน `FROM products` → `FROM products_review_view` จะได้ `category_name`/`seller_name` ติดมาด้วย
> ทดสอบก่อนว่า FlutterFlow built-in filter พอไหม ถ้าพอก็ไม่ต้องสร้างอันนี้เลย

## P-06 — ตาราง `transactions` (L5)

```sql
CREATE TABLE public.transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid REFERENCES public.products(id),
  buyer_id uuid REFERENCES public."Profile"(id),
  seller_id uuid REFERENCES public."Profile"(id),
  status varchar DEFAULT 'pending',   -- pending / completed / cancelled
  created_at timestamptz DEFAULT now(),
  completed_at timestamptz
);
```

*รอ confirm ว่าต้องการ status กี่แบบจริง ๆ และต้องเก็บประวัติแยกไหม หรือใช้แค่ `products.status` พอ*

## P-08 — ตาราง `reviews` (L7)

```sql
CREATE TABLE public.reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reviewer_id uuid REFERENCES public."Profile"(id),
  reviewee_id uuid REFERENCES public."Profile"(id),
  product_id uuid REFERENCES public.products(id),
  rating int CHECK (rating BETWEEN 1 AND 5),
  comment text,
  created_at timestamptz DEFAULT now(),
  UNIQUE (reviewer_id, product_id)   -- รีวิวได้ครั้งเดียวต่อสินค้า
);
```

## P-09 — รองรับรีพอร์ตผู้ใช้ (L7)

```sql
ALTER TABLE public.reports ADD COLUMN reported_user_id uuid REFERENCES public."Profile"(id);
-- ควรมี CHECK: ต้องมีอย่างน้อย 1 ใน (reported_product_id, reported_user_id) ที่ไม่ null
```

*รอตัดสินใจว่าจะรองรับรีพอร์ต "ผู้ใช้" ด้วยไหม หรือรีพอร์ตแค่สินค้าพอ*

## P-11 — unique index บน `lower("Profile".email)` (L1)

> 🚧 **ข้อเสนอของ Claude — pete ยังไม่ตอบรับ ห้ามถือว่าตกลงแล้ว**

```sql
CREATE UNIQUE INDEX profile_email_lower_unique
  ON public."Profile" (lower(email));
```

**ที่มา:** `Profile_email_key` เป็น UNIQUE ธรรมดาบนคอลัมน์ดิบ ไม่ใช่ index บน `lower()`
ตอนนี้ `handle_new_user()` `lower()` ให้ก่อน insert อยู่แล้ว (D-14) จึงยัง**ไม่มีปัญหาจริง** — ข้อเสนอนี้เป็นชั้นกันเผื่อเส้นทางเขียนอื่นที่ไม่ผ่าน trigger (`service_role` / SQL ตรง)

**ที่ต้องตัดสินใจก่อน apply:**
- คุ้มไหมที่จะเพิ่ม index อีกตัวเพื่อกันเคสที่ trigger กันอยู่แล้ว
- ถ้าเอา ควรถอด `Profile_email_key` ตัวเดิมทิ้งไหม หรือเก็บทั้งคู่

**ตรวจว่ายังไม่มีปัญหาอยู่หรือเปล่า:** `checks/L1.sql` [1.9]

---

## P-12 — เก็บกวาดไฟล์กำพร้าใน Storage (L1 / L2 / L5)

> 🚧 **ข้อเสนอของ Claude — pete ยังไม่ตอบรับ และยังไม่ได้เลือกแนวทาง จึงยังไม่มี SQL ให้รัน**

**ที่มา:** หนี้ที่รับไว้ตอน D-12 (`product-images`) และ D-15 (`avatars`) — ไฟล์ค้างใน bucket ได้ 3 ทาง

| ทางที่เกิดไฟล์กำพร้า | bucket |
|---|---|
| อัปรูปแล้วไม่กดบันทึกประกาศ | `product-images` |
| ลบประกาศทีหลัง รูปไม่ถูกลบตาม | `product-images` |
| เปลี่ยนรูปโปรไฟล์ ไฟล์เก่าไม่ถูกลบ | `avatars` |

**แนวทางที่ยังไม่ได้เลือก:**

| แนวทาง | ข้อดี | ข้อเสีย |
|---|---|---|
| trigger `AFTER DELETE ON products` ลบไฟล์ตาม `image_urls` | ตรงจุด ทันที | ลบข้ามไป `storage.objects` จาก trigger ต้องใช้สิทธิ์สูง และ path ต้อง parse จาก URL |
| Edge Function รันเป็นรอบ กวาดไฟล์ที่ไม่มีใครอ้างถึง | ปลอดภัยกว่า ย้อนดูได้ | ไฟล์ค้างอยู่ระหว่างรอบ · ต้องมีตัวตั้งเวลา |
| ไม่ทำเลย ยอมให้ค้าง | ไม่ต้องเขียนอะไร | ค่าเก็บโตเรื่อย ๆ ไม่มีวันหด |

🔴 **ห้ามเขียนตัวนี้ก่อนคุยกันจบ** — ของที่ลบไฟล์ผู้ใช้อัตโนมัติ ถ้าเงื่อนไขผิดคือลบรูปที่ยังใช้อยู่ กู้คืนไม่ได้
