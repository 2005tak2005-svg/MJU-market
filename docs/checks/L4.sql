-- L4 — Chat & Messaging

-- [4.1] คอลัมน์ครบไหมทั้ง 3 ตาราง
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema='public' AND table_name IN ('chat','chat_user','chat_message')
ORDER BY table_name, ordinal_position;

-- [4.2] 🔴 UNIQUE(chat_id, user_id) บน chat_user — กันสมาชิกซ้ำในห้อง
SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint
WHERE conrelid='public.chat_user'::regclass AND contype='u';

-- [4.3] Realtime — คาดหวัง chat + chat_message
SELECT tablename FROM pg_publication_tables
WHERE pubname='supabase_realtime' AND tablename IN ('chat','chat_message');

-- [4.4] นิยาม view — 🔴 ต้อง join public_profiles ไม่ใช่ "Profile" (PT-01)
SELECT viewname, definition FROM pg_views
WHERE schemaname='public' AND viewname IN ('chat_summary','chat_messages_view');

-- [4.5] RPC ที่ layer นี้ต้องใช้ (P-03 / P-04) — คาดหวังหลัง apply
SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN ('find_or_create_chat','update_chat_last_message');

SELECT tgname FROM pg_trigger WHERE tgname='trg_update_last_message';

-- [4.6] ⭐ NULL check ในฐานะ user ธรรมดา — member_names/sender_name ต้องไม่เป็น NULL
-- BEGIN;
--   SET LOCAL ROLE authenticated;
--   SET LOCAL request.jwt.claims = '{"sub":"<UID>","role":"authenticated"}';
--   SELECT chat_id, member_names, user_ids FROM chat_summary LIMIT 10;
--   SELECT message_id, sender_name, message FROM chat_messages_view LIMIT 10;
-- ROLLBACK;

-- [4.7] ห้องกำพร้า / ข้อความกำพร้า (integrity)
SELECT c.id AS chat_without_members FROM public.chat c
LEFT JOIN public.chat_user cu ON cu.chat_id=c.id WHERE cu.id IS NULL;

SELECT cm.id FROM public.chat_message cm
LEFT JOIN public.chat c ON c.id=cm.chat_id WHERE c.id IS NULL;

-- [4.8] ห้องซ้ำระหว่างคู่เดิม (ถ้า find_or_create_chat ทำงานถูก ต้องได้ 0 แถว)
SELECT a.user_id AS u1, b.user_id AS u2, count(DISTINCT a.chat_id) AS rooms
FROM chat_user a JOIN chat_user b ON a.chat_id=b.chat_id AND a.user_id < b.user_id
GROUP BY 1,2 HAVING count(DISTINCT a.chat_id) > 1;

-- [4.9] chat.last_message ตรงกับข้อความล่าสุดจริงไหม
SELECT c.id, c.last_message, m.message AS actual_latest
FROM public.chat c
LEFT JOIN LATERAL (
  SELECT message FROM public.chat_message
  WHERE chat_id=c.id ORDER BY created_at DESC LIMIT 1
) m ON true
WHERE c.last_message IS DISTINCT FROM m.message;

-- [4.10] 💣 หนี้ D-03 — เตือนว่า RLS ยังเป็น allow-all
--        ก่อน production ต้องเปลี่ยนเป็น membership-based
SELECT tablename, policyname, qual FROM pg_policies
WHERE tablename IN ('chat','chat_user','chat_message');
