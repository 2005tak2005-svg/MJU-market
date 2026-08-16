-- L7 — Reviews & Reports

-- [7.1] reports policy (D-24, 2026-08-15) — คาดหวัง 3 แถว: admin-read, reporter-read-own, authenticated-insert
SELECT policyname, cmd, qual, with_check FROM pg_policies WHERE tablename='reports';

-- [7.1b] constraints ของ reports (D-24) — คาดหวัง: CHECK status, unique index กันซ้ำ, FK reported_product_id เป็น ON DELETE SET NULL
SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid = 'public.reports'::regclass
UNION ALL
SELECT indexname, indexdef FROM pg_indexes WHERE schemaname='public' AND tablename='reports';

-- [7.2] คอลัมน์ของ reports — มี reported_user_id หรือยัง (P-09) และ is_read (D-31)
SELECT column_name, data_type, is_nullable FROM information_schema.columns
WHERE table_schema='public' AND table_name='reports' ORDER BY ordinal_position;

-- [7.3] ตาราง reviews มีหรือยัง (P-08)
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='public' AND table_name='reviews' ORDER BY ordinal_position;

-- [7.4] 🔴 constraints ของ reviews
--       คาดหวัง: UNIQUE(reviewer_id, product_id) + CHECK rating BETWEEN 1 AND 5
SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint
WHERE conrelid = 'public.reviews'::regclass ORDER BY conname;

-- [7.5] ⭐ ทดสอบว่า constraint ทำงานจริง ไม่ใช่กันแค่ที่ UI
-- INSERT INTO reviews (reviewer_id, reviewee_id, product_id, rating)
-- VALUES ('<UID>','<UID2>','<PID>', 6);        -- ต้อง error: CHECK violation
-- INSERT ซ้ำคู่ (reviewer_id, product_id) เดิม  -- ต้อง error: unique violation

-- [7.6] ข้อมูลผิดปกติ
SELECT rating, count(*) FROM public.reviews GROUP BY 1 ORDER BY 1;
SELECT id FROM public.reviews WHERE reviewer_id = reviewee_id;  -- รีวิวตัวเอง ต้องได้ 0

-- [7.7] report ที่ไม่ระบุเป้าหมายเลย (ทั้ง product และ user เป็น null)
SELECT id FROM public.reports WHERE reported_product_id IS NULL;

-- [7.8] ⭐ ทดสอบว่า user ทั่วไปอ่าน reports ของ**คนอื่น**ไม่ได้ (แต่อ่านของตัวเองได้ตั้งแต่ D-24)
-- BEGIN;
--   SET LOCAL ROLE authenticated;
--   SET LOCAL request.jwt.claims = '{"sub":"<UID_ที่ไม่ใช่admin>","role":"authenticated"}';
--   SELECT count(*) FROM reports WHERE reporter_id = '<UID_ที่ไม่ใช่admin>';  -- เห็นของตัวเอง
--   SELECT count(*) FROM reports WHERE reporter_id <> '<UID_ที่ไม่ใช่admin>'; -- ต้องได้ 0
-- ROLLBACK;

-- [7.9] ⭐ กันรายงานซ้ำ (D-24) — insert ซ้ำ (reporter_id, reported_product_id) เดิมตอน status ยัง 'pending' ต้อง error unique_violation
-- [7.10] ⭐ CHECK status (D-24) — insert status นอกเหนือ 'pending'/'resolved' ต้อง error check_violation
-- [7.11] ลบ products แถวที่มี report อยู่ — reports แถวนั้นต้องยังอยู่ (reported_product_id เป็น NULL แทนที่จะหายไปทั้งแถว)
