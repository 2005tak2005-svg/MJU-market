-- L2 — Product Listings + Storage

-- [2.1] คอลัมน์ของ products
--       คาดหวัง: moderation_status NOT NULL default 'pending', seller_id default auth.uid()
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='public' AND table_name='products' ORDER BY ordinal_position;

-- [2.2] 🔴 seller_id default ต้องเป็น auth.uid() ไม่ใช่ gen_random_uuid() (บั๊ก D-06)
SELECT column_default FROM information_schema.columns
WHERE table_schema='public' AND table_name='products' AND column_name='seller_id';

-- [2.3] constraints — คาดหวัง CHECK condition IN ('new','used'),
--       CHECK moderation_status IN ('pending','approved','rejected'), FK category_id → CAT
SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint
WHERE conrelid = 'public.products'::regclass ORDER BY conname;

-- [2.4] 🔴 CAT ต้องมีข้อมูล — ถ้า 0 แถว dropdown ใน AddProduct จะว่างเปล่า
SELECT count(*) AS cat_rows FROM public."CAT";

-- [2.5] products_review_view คืนคอลัมน์ครบไหม
--       คาดหวัง 15 คอลัมน์ รวม category_name, seller_name, rejection_reason
SELECT column_name FROM information_schema.columns
WHERE table_schema='public' AND table_name='products_review_view' ORDER BY ordinal_position;

-- [2.6] ⭐ NULL check ในฐานะ user ธรรมดา — บั๊กที่เคยหลุดเพราะเทสด้วย admin
--       แทน <UID> ด้วย user ธรรมดาที่ไม่ใช่ผู้ขาย → seller_name/category_name ต้องไม่เป็น NULL
-- BEGIN;
--   SET LOCAL ROLE authenticated;
--   SET LOCAL request.jwt.claims = '{"sub":"<UID>","role":"authenticated"}';
--   SELECT id, title, seller_name, category_name FROM products_review_view LIMIT 10;
-- ROLLBACK;

-- [2.7] Realtime บน products (จำเป็นสำหรับ reject alert / PT-04)
SELECT tablename FROM pg_publication_tables
WHERE pubname='supabase_realtime' AND tablename='products';

-- [2.8] Storage bucket — คาดหวังหลังทำ: มี product-images
SELECT id, name, public FROM storage.buckets;
SELECT name, definition FROM pg_policies WHERE schemaname='storage';

-- [2.9] ข้อมูลจริง — ประกาศที่ moderation_status ผิดค่า หรือ seller_id ไม่ตรงกับ Profile ที่มีอยู่
SELECT moderation_status, count(*) FROM public.products GROUP BY 1;
SELECT p.id, p.seller_id FROM public.products p
LEFT JOIN public."Profile" pr ON pr.id = p.seller_id WHERE pr.id IS NULL;

-- [2.10] rejected แล้วแต่ไม่มีเหตุผล (flow ไม่ครบ)
SELECT id, title FROM public.products
WHERE moderation_status='rejected' AND (rejection_reason IS NULL OR rejection_reason = '');
