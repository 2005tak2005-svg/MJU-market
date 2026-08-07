-- _common.sql — ตรวจสุขภาพทั่วไป รันก่อนทุก layer
-- ⚠️ execute_sql คืนผลแค่คำสั่งสุดท้าย → รันทีละบล็อกแยกกัน

-- [C1] ตารางทั้งหมดใน public + สถานะ RLS
--      คาดหวัง: rls_enabled = true ทุกตาราง
SELECT c.relname AS table_name, c.relrowsecurity AS rls_enabled
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r'
ORDER BY 1;

-- [C2] 🔴 ตารางที่เปิด RLS แต่ไม่มี policy = deny-all (ต้นเหตุบั๊ก NULL ทั้งชุด)
--      คาดหวังตอนนี้: มีแค่ 'reports' — ถ้าเจอตัวอื่นโผล่มา = มีคนสร้างตารางใหม่แล้วลืมทำ policy
SELECT c.relname AS deny_all_table
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relrowsecurity
  AND NOT EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname='public' AND p.tablename=c.relname);

-- [C3] policy ทั้งหมดพร้อมตรรกะจริง (list_tables ไม่คืนข้อมูลนี้)
SELECT tablename, policyname, cmd, roles, qual, with_check
FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename, cmd;

-- [C4] ตารางที่เปิด Realtime อยู่
--      คาดหวัง: chat, chat_message, products
SELECT tablename FROM pg_publication_tables
WHERE pubname = 'supabase_realtime' ORDER BY 1;

-- [C5] view ทั้งหมด + มี security_invoker ไหม
--      คาดหวัง: public_profiles = ไม่มี (โดยตั้งใจ)
--                chat_summary / chat_messages_view / products_review_view = true
SELECT c.relname AS view_name, c.reloptions
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'v' ORDER BY 1;

-- [C6] 🔴 หา view ที่ join "Profile" ตรง ๆ (ละเมิด PT-01 → ชื่อจะเป็น NULL สำหรับ user ธรรมดา)
--      คาดหวัง: 0 แถว (ยกเว้น public_profiles เองที่ต้อง join)
SELECT viewname FROM pg_views
WHERE schemaname = 'public' AND viewname <> 'public_profiles'
  AND definition ILIKE '%"Profile"%';

-- [C7] function / trigger ที่มีอยู่จริง
SELECT p.proname, pg_get_function_arguments(p.oid) AS args
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' ORDER BY 1;

SELECT tgname, c.relname AS on_table
FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
WHERE NOT t.tgisinternal ORDER BY 1;

-- [C8] ⭐ ทดสอบมุมมองของ user ธรรมดา — ข้อที่พลาดบ่อยที่สุด
--      แทน <UID> ด้วย id ของ user ธรรมดาที่ "ไม่ใช่" เจ้าของข้อมูล
-- BEGIN;
--   SET LOCAL ROLE authenticated;
--   SET LOCAL request.jwt.claims = '{"sub":"<UID>","role":"authenticated"}';
--   SELECT id, seller_name, category_name FROM products_review_view LIMIT 5;   -- ห้ามมี NULL
--   SELECT chat_id, member_names FROM chat_summary LIMIT 5;                    -- ห้ามมี NULL
-- ROLLBACK;
