-- L4 — Chat & Messaging

-- [4.1] คอลัมน์ครบไหมทั้ง 3 ตาราง
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema='public' AND table_name IN ('chat','chat_user','chat_message')
ORDER BY table_name, ordinal_position;

-- [4.2] 🔴 UNIQUE(chat_id, user_id) บน chat_user — กันสมาชิกซ้ำในห้อง
SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint
WHERE conrelid='public.chat_user'::regclass AND contype='u';

-- [4.2b] CHECK chat_message_has_content (D-29) — message/image_url ต้องมีอย่างน้อย 1
SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint
WHERE conrelid='public.chat_message'::regclass AND contype='c';

-- [4.3] Realtime — คาดหวัง chat + chat_message (ไม่มี chat_user โดยตั้งใจ)
SELECT tablename FROM pg_publication_tables
WHERE pubname='supabase_realtime' AND tablename IN ('chat','chat_message');

-- [4.4] นิยาม view — 🔴 ต้อง join public_profiles ไม่ใช่ "Profile" (PT-01)
--       chat_messages_view ต้องมี image_url เป็นคอลัมน์ท้ายสุด (D-29)
SELECT viewname, definition FROM pg_views
WHERE schemaname='public' AND viewname IN ('chat_summary','chat_messages_view');

-- [4.5] RPC/trigger ที่ layer นี้ใช้ (D-29/D-30/D-31) — คาดหวังครบ 6 function + 1 trigger
SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public'
  AND p.proname IN ('find_or_create_chat','update_chat_last_message','is_chat_member','get_my_chats',
                     'find_or_create_chat_with_admin','mark_chat_read','mark_report_read');

SELECT tgname FROM pg_trigger WHERE tgname='trg_update_last_message';

-- [4.5b] grant ของฟังก์ชันด้านบน — คาดหวัง: authenticated มีทุกตัวยกเว้น update_chat_last_message
--        (trigger function ไม่ต้องมี direct grant), anon ไม่มีเลยสักตัว
SELECT p.proname, p.proacl
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public'
  AND p.proname IN ('find_or_create_chat','update_chat_last_message','is_chat_member','get_my_chats',
                     'find_or_create_chat_with_admin','mark_chat_read','mark_report_read');

-- [4.5c] จุดแดง unread (D-31) — chat_user.last_read_at ต้องมี, chat_summary.is_unread ต้องอยู่ใน view
SELECT column_name, data_type, is_nullable FROM information_schema.columns
WHERE table_schema='public' AND table_name='chat_user' AND column_name='last_read_at';

SELECT viewname FROM pg_views
WHERE schemaname='public' AND viewname='chat_summary' AND definition ILIKE '%is_unread%';

-- [4.6] ⭐ NULL check + privacy check ในฐานะ user ธรรมดา — รันทีละบล็อกตาม _common.sql กับดัก 1
--       (member_names/sender_name ต้องไม่เป็น NULL, และ non-member ต้องเห็น 0 แถว)
BEGIN;
  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"<UID สมาชิก>","role":"authenticated"}';
  SELECT chat_id, member_names, user_ids FROM chat_summary LIMIT 10;
COMMIT;

BEGIN;
  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims = '{"sub":"<UID ไม่ใช่สมาชิก>","role":"authenticated"}';
  SELECT count(*) AS should_be_zero FROM chat_summary;
COMMIT;

-- [4.7] ห้องกำพร้า / ข้อความกำพร้า (integrity)
SELECT c.id AS chat_without_members FROM public.chat c
LEFT JOIN public.chat_user cu ON cu.chat_id=c.id WHERE cu.id IS NULL;

SELECT cm.id FROM public.chat_message cm
LEFT JOIN public.chat c ON c.id=cm.chat_id WHERE c.id IS NULL;

-- [4.8] ห้องซ้ำระหว่างคู่เดิม (ถ้า find_or_create_chat ทำงานถูก ต้องได้ 0 แถว)
SELECT a.user_id AS u1, b.user_id AS u2, count(DISTINCT a.chat_id) AS rooms
FROM chat_user a JOIN chat_user b ON a.chat_id=b.chat_id AND a.user_id < b.user_id
GROUP BY 1,2 HAVING count(DISTINCT a.chat_id) > 1;

-- [4.9] chat.last_message ตรงกับข้อความล่าสุดจริงไหม — ต้องครอบ COALESCE แบบเดียวกับ
--       trigger update_chat_last_message() (ข้อความล่าสุดเป็นรูปล้วน → '📷 รูปภาพ' ไม่ใช่ NULL)
SELECT c.id, c.last_message, m.actual_latest
FROM public.chat c
LEFT JOIN LATERAL (
  SELECT COALESCE(message, '📷 รูปภาพ') AS actual_latest FROM public.chat_message
  WHERE chat_id=c.id ORDER BY created_at DESC LIMIT 1
) m ON true
WHERE c.last_message IS DISTINCT FROM m.actual_latest;

-- [4.10] RLS ของ chat/chat_user/chat_message ต้องเป็น membership-based (D-29) ไม่ใช่ allow-all แล้ว
--        คาดหวัง: ทุกแถวมี qual อ้าง is_chat_member(...) ไม่มีแถวไหน qual='true'
SELECT tablename, policyname, cmd, qual, with_check FROM pg_policies
WHERE tablename IN ('chat','chat_user','chat_message');
