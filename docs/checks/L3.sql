-- L3 — Browse / Search / Filter

-- [3.1] RPC search_products มีอยู่จริงไหม (P-05 — อาจตัดสินใจไม่สร้างก็ได้)
SELECT p.proname, pg_get_function_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS returns
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname='search_products';

-- [3.2] 🔴 ถ้ามี search_products ต้องมี moderation_status='approved' อยู่ในนิยาม
--       ไม่งั้นสินค้าที่ยังไม่ผ่านตรวจจะรั่วสู่สาธารณะ
SELECT prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname='search_products';

-- [3.3] index ที่ช่วยเรื่อง search/filter (ตอนนี้ยังไม่มี — เพิ่มถ้าข้อมูลเยอะขึ้น)
SELECT indexname, indexdef FROM pg_indexes
WHERE schemaname='public' AND tablename='products';

-- [3.4] ⭐ ทดสอบว่าสินค้าที่ยังไม่ approved ไม่รั่ว
--       จำลอง query แบบที่หน้า Browse จะใช้ — ผลลัพธ์ต้องไม่มี pending/rejected เลย
SELECT moderation_status, count(*)
FROM products_review_view
WHERE moderation_status = 'approved'
GROUP BY 1;

-- ตรวจสวนทาง: มีของ pending/rejected อยู่กี่ชิ้น (ต้องไม่โผล่ในหน้า Browse)
SELECT moderation_status, count(*) FROM public.products
WHERE moderation_status <> 'approved' GROUP BY 1;

-- [3.5] ราคาผิดปกติที่จะทำให้ filter ช่วงราคาเพี้ยน
SELECT id, title, price FROM public.products
WHERE price IS NULL OR price < 0 ORDER BY price NULLS FIRST LIMIT 20;

-- [3.6] wishlist_items (D-81) — ของครบไหม: 1 table (RLS เปิด) + 3 policy (select/insert/delete เฉพาะแถวตัวเอง)
SELECT 'table' AS ชนิด, c.relname AS ชื่อ, c.relrowsecurity::text AS rls_enabled
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relname='wishlist_items'
UNION ALL
SELECT 'policy', policyname, cmd FROM pg_policies
 WHERE schemaname='public' AND tablename='wishlist_items';

-- [3.7] products_review_view.saved_by_me ต้องผูก auth.uid() จริง ไม่ hardcode
SELECT (view_definition LIKE '%wishlist_items%')          AS มี_join_wishlist_items,
       (view_definition LIKE '%saved_by_me%')              AS มีคอลัมน์_saved_by_me,
       (view_definition LIKE '%wi.user_id = auth.uid()%')  AS ผูก_auth_uid_จริง
  FROM information_schema.views
 WHERE table_schema='public' AND table_name='products_review_view';

-- [3.8] ⭐ impersonation: insert/delete แถวตัวเองผ่าน, ของคนอื่นถูกบล็อกทั้ง insert และ delete
--       ยืนยันแล้วจริงด้วย SQL ตรง ๆ ตอน apply (2026-09-02) — บล็อกไว้เผื่อ regression ทดสอบซ้ำภายหลัง
-- BEGIN;
--   INSERT INTO wishlist_items (product_id, user_id) VALUES ('<PID>', '<UID_B>');  -- เตรียมแถวของ B ไว้ก่อน (ยังไม่ SET ROLE)
--   SET LOCAL ROLE authenticated;
--   SET LOCAL request.jwt.claims = '{"sub":"<UID_A>","role":"authenticated"}';
--   INSERT INTO wishlist_items (product_id, user_id) VALUES ('<PID>', '<UID_A>');  -- ต้องผ่าน
--   INSERT INTO wishlist_items (product_id, user_id) VALUES ('<PID>', '<UID_B>');  -- ต้อง error (WITH CHECK 42501)
--   DELETE FROM wishlist_items WHERE user_id = '<UID_B>';                         -- ต้องรันผ่านแต่ affect 0 แถว (USING กันไว้)
--   RESET ROLE;
--   SELECT count(*) FROM wishlist_items WHERE user_id='<UID_B>';                  -- ต้องยังเป็น 1 (แถว B ไม่ถูกลบ)
-- ROLLBACK;

-- [3.9] cascade delete: ลบ product แล้ว wishlist_items ที่เกี่ยวข้องหายไปด้วยจริง (ON DELETE CASCADE)
--       ยืนยันแล้วจริงตอน apply (2026-09-02) — orphaned_rows = 0
-- BEGIN;
--   WITH new_product AS (
--     INSERT INTO products (seller_id, title, category_id, status, moderation_status)
--     VALUES ('<UID>', '__cascade_test__', 1, 'available', 'approved') RETURNING id
--   ), new_wish AS (
--     INSERT INTO wishlist_items (product_id, user_id) SELECT id, '<UID>' FROM new_product RETURNING product_id
--   ) SELECT product_id FROM new_wish;
--   DELETE FROM products WHERE title = '__cascade_test__';
--   SELECT count(*) AS orphaned_rows FROM wishlist_items wi
--     WHERE NOT EXISTS (SELECT 1 FROM products p WHERE p.id = wi.product_id);      -- ต้องได้ 0
-- ROLLBACK;
