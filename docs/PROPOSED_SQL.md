# PROPOSED_SQL.md — SQL ที่ยังไม่ apply

> 🚧 **ทุกอย่างในไฟล์นี้ยังไม่มีอยู่จริงในฐานข้อมูล**
> ห้าม reference ในโค้ด/Action Flow จนกว่าจะ apply แล้วย้ายไป `SCHEMA.md`
> เมื่อ apply แล้ว: ลบออกจากไฟล์นี้ → เพิ่มเข้า `SCHEMA.md` → บันทึกเหตุผลที่ `DECISIONS.md`

| # | ของ | Layer | สถานะ |
|---|---|---|---|
| ~~P-01~~ | ~~`handle_new_user()` + trigger auto-insert Profile~~ | L1 | ✅ **apply แล้ว** ย้ายไป `SCHEMA.md` (พบ 2026-08-07) |
| ~~P-02~~ | ~~trigger ตรวจโดเมน `@mju.ac.th` ฝั่ง server~~ | L1 | ✅ **apply แล้ว** รวมอยู่ใน `handle_new_user()` |
| P-03 | `find_or_create_chat(user_a, user_b)` | L2/L3/L4 | รอ confirm แนวทาง |
| P-04 | `update_chat_last_message()` + trigger | L4 | รอ confirm |
| P-05 | `search_products(...)` | L3 | รอทดสอบว่า FF filter พอไหม |
| P-06 | ตาราง `transactions` | L5 | รอ confirm ค่า status |
| P-07 | ตาราง `notifications` | L6 | ยังไม่เริ่ม |
| P-08 | ตาราง `reviews` | L7 | ยังไม่เริ่ม |
| P-09 | `reports.reported_user_id` | L7 | รอตัดสินใจว่าจะรีพอร์ตผู้ใช้ไหม |
| P-10 | RLS policy ของ `reports` | L7 | 🔴 ตอนนี้ deny-all ใช้งานไม่ได้เลย |

---

## ~~P-01~~ / ~~P-02~~ — ✅ apply ไปแล้วทั้งคู่ (ตรวจพบ 2026-08-07)

**ย้ายไป `SCHEMA.md` → หัวข้อ "Trigger / Function ที่ apply แล้ว" แล้ว อ่านที่นั่นแทน**

ตอนตรวจ DB จริงครั้งแรกพบว่า `handle_new_user()` + trigger `on_auth_user_created`
มีอยู่ใน DB เรียบร้อยแล้ว และตัวมันทำงานของ **P-02 รวมอยู่ในตัวเดียวกัน** (บังคับโดเมน `@mju.ac.th`)
ไฟล์นี้กับ `SCHEMA.md` เข้าใจผิดตรงกันมาตลอดว่ายังไม่มี

⚠️ ของจริงต่างจากที่ร่างไว้ข้างบน 3 จุด อย่าใช้ร่างเดิมอ้างอิง:

| ร่างเดิมเขียนว่า | ของจริง |
|---|---|
| insert แค่ `id`, `email` | insert `id, email, full_name, role, student_id` |
| ไม่ระบุ `role` ปล่อย default | ระบุ `role = 'user'` ตรง ๆ |
| FlutterFlow ต้อง Update Row ใส่ `student_id` เอง | trigger derive `student_id` จากอีเมลให้แล้ว — **ห้ามเขียนทับ** จะชน CHECK `profile_student_id_matches_email` |

**ยังค้างอยู่จริง ๆ:** `phone` ยังไม่มีใครใส่ให้ — ถ้าฟอร์มสมัครเก็บเบอร์ FlutterFlow ยังต้อง Update Row เพิ่มเอง

🔴 **ยังไม่เคยทดสอบ** — `auth.users` มี 0 แถว เส้นทางสมัครสมาชิกจึงยังไม่เคยรันจริงสักครั้ง
ต้องสมัคร user จริงแล้วยืนยันว่าแถวใน `"Profile"` เกิดขึ้นครบก่อนถึงจะปิด L1 ได้

## P-03 — find-or-create ห้องแชท (L2 / L3 / L4)

```sql
CREATE OR REPLACE FUNCTION find_or_create_chat(user_a uuid, user_b uuid)
RETURNS bigint AS $$
DECLARE existing_chat_id bigint; new_chat_id bigint;
BEGIN
  SELECT cu1.chat_id INTO existing_chat_id
  FROM chat_user cu1 JOIN chat_user cu2 ON cu1.chat_id = cu2.chat_id
  WHERE cu1.user_id = user_a AND cu2.user_id = user_b
  LIMIT 1;

  IF existing_chat_id IS NOT NULL THEN
    RETURN existing_chat_id;
  END IF;

  INSERT INTO chat (last_message) VALUES (NULL) RETURNING id INTO new_chat_id;
  INSERT INTO chat_user (chat_id, user_id) VALUES (new_chat_id, user_a), (new_chat_id, user_b);
  RETURN new_chat_id;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;
```

> ทำไมต้องใช้ RPC: การหาห้องที่ทั้งคู่เป็นสมาชิกคือ self-join ข้าม 2 แถวใน `chat_user` ซึ่ง FlutterFlow query builder ทำเองไม่ได้
> ใช้ที่เดียวกัน 3 จุด: ปุ่ม "แชทกับผู้ขาย" ใน `MaterialCard` (L2), ใน `ProductDetail` (L3), และเป็นทางเข้าห้องแชทของ L4 — ดู `PATTERNS.md` PT-02

## P-04 — auto-update `chat.last_message` (L4)

```sql
CREATE OR REPLACE FUNCTION update_chat_last_message() RETURNS trigger AS $$
BEGIN
  UPDATE public.chat SET last_message = NEW.message WHERE id = NEW.chat_id;
  RETURN NEW;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_update_last_message
  AFTER INSERT ON public.chat_message
  FOR EACH ROW EXECUTE FUNCTION update_chat_last_message();
```

> ทางเลือก: ให้ FlutterFlow Action Flow อัปเดต 2 ที่เอง (insert message + update chat) — เสี่ยงลืม ทำให้ chat list แสดงข้อความเก่า

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

## P-07 — ตาราง `notifications` (L6)

```sql
CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public."Profile"(id),
  type varchar,      -- 'new_message' / 'listing_approved' / 'listing_rejected' / ...
  ref_id uuid,       -- ⚠️ ดูหมายเหตุด้านล่าง
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);
```

> 🔴 **ปัญหาที่ต้องแก้ก่อน apply:** `ref_id uuid` ใช้อ้าง `chat_id` ไม่ได้ เพราะ `chat.id` เป็น **bigint** ส่วน `products.id` เป็น uuid
> ทางเลือก: (ก) เปลี่ยน `ref_id` เป็น `text` แล้วเก็บเป็น string (ข) แยกเป็น 2 คอลัมน์ `ref_product_id uuid` / `ref_chat_id bigint` (ค) เปลี่ยน `chat.id` เป็น uuid ให้เหมือนตารางอื่น (กระทบ L4 ที่สร้างเสร็จแล้ว — ไม่แนะนำ)

+ เปิด Realtime บนตารางนี้ + trigger สร้าง notification อัตโนมัติ (เช่น บน `chat_message` insert → แจ้งสมาชิกห้องคนอื่น)

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

## P-10 — RLS policy ของ `reports` (L7) 🔴

ตอนนี้ `reports` เปิด RLS แต่ไม่มี policy เลย = **deny-all** — insert/select ไม่ได้เลยแม้แต่ admin ตารางนี้ใช้งานไม่ได้จริงจนกว่าจะเพิ่ม policy

```sql
CREATE POLICY "authenticated can report" ON public.reports
  FOR INSERT TO authenticated WITH CHECK (reporter_id = auth.uid());

CREATE POLICY "admin can read reports" ON public.reports
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public."Profile" WHERE id = auth.uid() AND role = 'admin'));
```
