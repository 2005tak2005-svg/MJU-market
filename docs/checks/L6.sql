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
--       คาดหวัง: บน chat_message (INSERT), products (UPDATE moderation_status)
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

-- [6.7] 🔴 ตรวจชนิดของ ref_id ก่อนอย่างอื่น
--       P-07 ร่างไว้เป็น uuid แต่ chat.id เป็น bigint → อ้าง chat_id ไม่ได้
--       ต้องแก้ design ก่อน apply (ดูหมายเหตุใน PROPOSED_SQL.md P-07)
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='public' AND table_name='notifications' AND column_name='ref_id';

-- [6.8] ตรวจว่าเหตุการณ์จริงสร้าง notification ครบ
--       ⚠️ ปรับ join ให้ตรงกับ design ของ ref_id ที่เลือกใช้จริงก่อนรัน
-- SELECT cm.id AS message_without_notification
-- FROM public.chat_message cm
-- WHERE NOT EXISTS (
--   SELECT 1 FROM public.notifications n
--   WHERE n.type='new_message' AND n.ref_id = <อ้างอิงตาม design ที่เลือก>
--     AND n.created_at >= cm.created_at
-- ) LIMIT 20;
