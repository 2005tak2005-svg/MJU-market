-- _common.sql — ตรวจสุขภาพทั่วไป รันก่อนทุก layer
--
-- ⚠️ กับดักที่ 1 — execute_sql คืนผลแค่คำสั่ง "สุดท้าย"
--    → รันทีละบล็อกแยกกัน และทุกบล็อกต้องจบด้วย SELECT ที่อยากเห็นผล
--    → ห้ามปิดท้ายด้วย ROLLBACK/COMMIT เด็ดขาด ไม่งั้นได้ผลลัพธ์ว่างแล้วเข้าใจผิดว่าผ่าน
--
-- ⚠️ กับดักที่ 2 — MCP ต่อ DB ด้วย role `postgres` ซึ่ง BYPASS RLS ทั้งหมด
--    → query ธรรมดา "ผ่านทุกข้อโดยอัตโนมัติ" ไม่ได้แปลว่าระบบถูก
--    → ทุกข้อที่เกี่ยวกับ view หรือ RLS ต้องรัน 2 รอบแล้วเอามาเทียบกัน:
--        รอบ A (postgres)      = ข้อมูลจริงมีอะไรอยู่
--        รอบ B (authenticated) = user ธรรมดามองเห็นอะไร
--      ต่างกันเมื่อไหร่ = RLS/view มีปัญหา
--    → ข้อไหนรันได้แค่รอบเดียว ให้เขียนว่า "ยังไม่ได้ตรวจมุมมอง user"
--      ❌ ห้ามเขียนว่า PASS
--
-- ⚠️ กับดักที่ 3 — ตารางว่าง ผลลัพธ์ 0 แถวก็ "ไม่ใช่ PASS"
--    เช็คแบบ "ห้ามมี NULL" กับตารางว่างจะผ่านเสมอโดยไม่ได้ตรวจอะไรเลย
--    ต้องมีข้อมูลจริงก่อน ถึงจะสรุปได้

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
--
--      🔴 ก่อนรัน ต้องหา UID ของ user ที่ "ไม่ใช่ admin" และ "ไม่ใช่เจ้าของข้อมูลที่กำลังตรวจ"
--         ถ้าหาไม่ได้ ห้ามเดา UID มั่ว ๆ ให้รายงานว่าตรวจไม่ได้แล้วหยุด
--         (UID ปลอมจะได้ 0 แถวเสมอ ซึ่งหน้าตาเหมือน "ผ่าน" ทั้งที่ไม่ได้ตรวจอะไรเลย)
SELECT p.id, p.role
FROM public."Profile" p
WHERE coalesce(p.role,'') <> 'admin'
ORDER BY p.created_at
LIMIT 5;

--      ⚠️ แต่ละ SELECT = 1 บล็อก แยกรัน ห้ามยัดรวมกัน (กับดักที่ 1)
--         ไม่ต้องมี ROLLBACK — SET LOCAL หมดอายุเองเมื่อจบ transaction และทั้งหมดนี้ read-only

-- [C8a] products_review_view มุมมอง user ธรรมดา — ห้ามมี NULL ใน seller_name / category_name
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub":"<UID>","role":"authenticated"}';
SELECT id, seller_name, category_name FROM products_review_view LIMIT 5;

-- [C8b] chat_summary มุมมอง user ธรรมดา — ห้ามมี NULL ใน member_names
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub":"<UID>","role":"authenticated"}';
SELECT chat_id, member_names FROM chat_summary LIMIT 5;

-- [C8-cmp] รอบเทียบ (role postgres) — รันคู่กับ C8a/C8b เสมอ
--          ถ้ารอบนี้มีข้อมูลแต่รอบ authenticated ว่าง/เป็น NULL = RLS หรือ view พัง
SELECT
  (SELECT count(*) FROM products_review_view) AS prv_rows_as_postgres,
  (SELECT count(*) FROM chat_summary)         AS chat_rows_as_postgres;
