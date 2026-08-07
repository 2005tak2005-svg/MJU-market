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
