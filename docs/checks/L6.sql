-- L6 — Notifications

-- [6.1] ตาราง notifications มีหรือยัง (P-07)
SELECT column_name, data_type, column_default FROM information_schema.columns
WHERE table_schema='public' AND table_name='notifications' ORDER BY ordinal_position;

-- [6.2] 🔴 RLS ต้อง restrictive ตั้งแต่แรก — อ่านได้เฉพาะของตัวเอง
--       ห้ามเป็น allow-all แบบตารางเก่า (D-03)
SELECT policyname, cmd, qual, with_check FROM pg_policies WHERE tablename='notifications';

-- [6.3] Realtime ต้องเปิด (badge จะได้อัปเดต live)
SELECT tablename FROM pg_publication_tables
WHERE pubname='supabase_realtime' AND tablename='notifications';

-- [6.4] trigger ที่สร้าง notification อัตโนมัติ
--       🔴 D-32 (2026-08-17): ยืนยันแล้วว่า "ไม่มี" — การสร้าง notification ตอนนี้เป็น
--       app-code ทางเดียว (RejectProductSheet → insert type='listing_rejected') ไม่ใช่ DB trigger
--       query นี้คาดหวังผลว่างเปล่า ไม่ใช่บั๊กถ้าว่าง — เก็บไว้เผื่อวันที่เปลี่ยนมาใช้ trigger จริง
SELECT t.tgname, c.relname AS on_table, p.proname
FROM pg_trigger t
JOIN pg_class c ON c.oid=t.tgrelid
JOIN pg_proc p ON p.oid=t.tgfoid
WHERE NOT t.tgisinternal AND c.relname IN ('chat_message','products','transactions');

-- [6.5] notification ที่ไม่มีเจ้าของจริง หรือ type ไม่รู้จัก
SELECT n.id FROM public.notifications n
LEFT JOIN public."Profile" p ON p.id=n.user_id WHERE p.id IS NULL;

SELECT type, count(*) FROM public.notifications GROUP BY 1;

-- [6.6] ⭐ ทดสอบว่า user อ่าน notification ของคนอื่นไม่ได้
-- BEGIN;
--   SET LOCAL ROLE authenticated;
--   SET LOCAL request.jwt.claims = '{"sub":"<UID_A>","role":"authenticated"}';
--   SELECT count(*) FROM notifications WHERE user_id <> '<UID_A>';  -- ต้องได้ 0
-- ROLLBACK;

-- [6.7] ชื่อคอลัมน์อ้างอิงจริงคือ ref_product_id (D-23) ไม่ใช่ ref_id ที่ P-07 ร่างไว้ตอนแรก
--       คาดหวัง 1 แถว, data_type = bigint (อ้าง products.id)
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='public' AND table_name='notifications' AND column_name='ref_product_id';

-- [6.7b] จุดแดง unread (D-31) — is_read ต้องมี, NOT NULL, default false
SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns
WHERE table_schema='public' AND table_name='notifications' AND column_name='is_read';

-- [6.8] ตรวจว่า reject-flow จริงสร้าง notification ครบ (ทางเดียวที่มีตอนนี้ — reject→insert)
SELECT p.id AS rejected_product_without_notification
FROM public.products p
WHERE p.moderation_status = 'rejected'
  AND NOT EXISTS (
    SELECT 1 FROM public.notifications n
    WHERE n.type = 'listing_rejected' AND n.ref_product_id = p.id
  );
