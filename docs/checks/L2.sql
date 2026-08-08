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

-- [2.8] Storage bucket — คาดหวัง 1 แถว: product-images, public=true,
--       file_size_limit=5242880, allowed_mime_types={image/jpeg,image/png,image/webp}
SELECT id, public, file_size_limit, allowed_mime_types
FROM storage.buckets WHERE id = 'product-images';

-- [2.8b] policy บน storage.objects — คาดหวัง 4 แถว (public read / owner upload / update / delete)
--        ⚠️ pg_policies ไม่มีคอลัมน์ `name` และ `definition` ต้องใช้ policyname/qual/with_check
--        (เวอร์ชันเดิมของบล็อกนี้เขียนผิด รันแล้ว error ทันที — แก้ 2026-08-08)
SELECT policyname, cmd, roles, qual, with_check
FROM pg_policies WHERE schemaname='storage' AND tablename='objects'
ORDER BY policyname;

-- [2.9] ข้อมูลจริง — ประกาศที่ moderation_status ผิดค่า หรือ seller_id ไม่ตรงกับ Profile ที่มีอยู่
SELECT moderation_status, count(*) FROM public.products GROUP BY 1;
SELECT p.id, p.seller_id FROM public.products p
LEFT JOIN public."Profile" pr ON pr.id = p.seller_id WHERE pr.id IS NULL;

-- [2.10] rejected แล้วแต่ไม่มีเหตุผล (flow ไม่ครบ)
SELECT id, title FROM public.products
WHERE moderation_status='rejected' AND (rejection_reason IS NULL OR rejection_reason = '');

-- [2.11] CHECK จำกัด 3 รูป ต้องยังอยู่ — คาดหวัง 1 แถว
SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint
WHERE conname = 'products_image_urls_max_3';

-- [2.12] ⭐ ทดสอบจริงแบบไม่ทิ้งข้อมูลค้าง — INSERT จริงแล้ว abort ทั้ง block ด้วย RAISE
--        คาดหวัง: error ที่ขึ้นต้นด้วย [ผล] แล้วบอกว่า
--        3รูป=ผ่าน | 4รูป=ถูกปฏิเสธ | โฟลเดอร์ตัวเอง=อัปได้ | โฟลเดอร์คนอื่น=ถูกบล็อก
--        (error ตัวนี้คือ "ผ่าน" ไม่ใช่ "พัง" — เป็นกลไก rollback)
--        แทน <EMAIL> ด้วย user ธรรมดาที่ไม่ใช่ admin
-- DO $$
-- DECLARE me uuid; other uuid; r3 text; r4 text; own text; oth text;
-- BEGIN
--   SELECT id INTO me    FROM public."Profile" WHERE email = '<EMAIL>';
--   SELECT id INTO other FROM public."Profile" WHERE id <> me LIMIT 1;
--
--   BEGIN
--     INSERT INTO public.products (seller_id, title, image_urls)
--     VALUES (me, 'ทดสอบ', ARRAY['a.jpg','b.jpg','c.jpg']);            r3 := 'ผ่าน';
--   EXCEPTION WHEN check_violation THEN r3 := 'ถูกปฏิเสธ'; END;
--   BEGIN
--     INSERT INTO public.products (seller_id, title, image_urls)
--     VALUES (me, 'ทดสอบ', ARRAY['a.jpg','b.jpg','c.jpg','d.jpg']);    r4 := 'ผ่าน';
--   EXCEPTION WHEN check_violation THEN r4 := 'ถูกปฏิเสธ'; END;
--
--   PERFORM set_config('request.jwt.claims',
--     json_build_object('sub', me::text, 'role','authenticated')::text, true);
--   SET LOCAL ROLE authenticated;
--
--   BEGIN
--     INSERT INTO storage.objects (bucket_id, name, owner)
--     VALUES ('product-images', me::text || '/pic1.jpg', me);          own := 'อัปได้';
--   EXCEPTION WHEN insufficient_privilege THEN own := 'ถูกบล็อก (ผิดคาด!)'; END;
--   BEGIN
--     INSERT INTO storage.objects (bucket_id, name, owner)
--     VALUES ('product-images', other::text || '/hack.jpg', me);       oth := 'อัปได้ (ช่องโหว่!)';
--   EXCEPTION WHEN insufficient_privilege THEN oth := 'ถูกบล็อก'; END;
--
--   RAISE EXCEPTION '[ผล] 3รูป=% | 4รูป=% | โฟลเดอร์ตัวเอง=% | โฟลเดอร์คนอื่น=%', r3, r4, own, oth;
-- END $$;

-- [2.13] ❌ ตรวจจาก DB ไม่ได้ ต้องอัปไฟล์จริงผ่านแอป/REST:
--        file_size_limit (5 MB) และ allowed_mime_types — สองอย่างนี้บังคับที่ Storage API
--        ไม่ใช่ที่ Postgres การ INSERT เข้า storage.objects ตรง ๆ จึงข้ามด่านนี้ไปเลย
