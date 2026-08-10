-- _common.sql — ตรวจสุขภาพทั่วไป รันก่อนทุก layer
--
-- ⚠️ กับดัก 1 — execute_sql คืนผลแค่คำสั่งสุดท้าย → รันทีละบล็อก ห้ามปิดท้ายด้วย ROLLBACK/COMMIT
-- ⚠️ กับดัก 2 — MCP ต่อด้วย role `postgres` (BYPASS RLS) → ข้อที่เกี่ยวกับ view/RLS ต้องรัน 2 รอบเทียบกัน
--    (postgres = ข้อมูลจริง, authenticated = user เห็นอะไร) ต่างกัน = RLS/view พัง
--    รันได้แค่รอบเดียว → เขียนว่า "ยังไม่ได้ตรวจมุมมอง user" ห้ามเขียนว่า PASS
-- ⚠️ กับดัก 3 — ตารางว่าง 0 แถว ไม่ใช่ PASS (เช็ค "ห้ามมี NULL" กับตารางว่างผ่านเสมอโดยไม่ตรวจอะไรเลย)
--
-- ✅ `BEGIN;` ที่ไม่ COMMIT จะ ROLLBACK อัตโนมัติ (ยืนยันแล้ว) — ใช้ทดสอบ UPDATE/INSERT ที่ policy
--    ควรปฏิเสธได้โดยไม่ทิ้งขยะใน DB ⚠️ คำสั่งที่ไม่มี BEGIN นำหน้า = autocommit เขียนจริงทันที

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

-- [C7] function ที่มีอยู่จริง
--      🔴 ต้องรวม schema 'private' ด้วย — helper ของ RLS (is_admin ฯลฯ) อยู่ที่นั่น
--         เวอร์ชันเดิมกรองแค่ 'public' เลยมองไม่เห็น แล้วสรุปผิดว่า "ยังไม่มี function เลย"
SELECT n.nspname AS schema, p.proname, pg_get_function_arguments(p.oid) AS args,
       p.prosecdef AS security_definer, p.proconfig
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public','private') ORDER BY 1, 2;

-- [C7b] trigger ที่มีอยู่จริง — แยกบล็อก (กับดักที่ 1)
--       🔴 ต้องแสดง schema ด้วย — trigger สำคัญที่สุดของระบบ (on_auth_user_created)
--          อยู่บน auth.users ไม่ใช่ public จึงดูจากชื่อตารางอย่างเดียวไม่พอ
SELECT t.tgname, n.nspname AS schema, c.relname AS on_table, t.tgenabled,
       pg_get_triggerdef(t.oid) AS def
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
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

-- [C9] ⭐ ทดสอบด้าน "ลบ" — policy ต้องปฏิเสธ ไม่ใช่แค่ยอมให้ทำสิ่งที่ถูก
--      ปลอดภัยเพราะ BEGIN ที่ไม่ COMMIT จะ rollback เอง (ดูหัวไฟล์)
--      คาดหวังทุกข้อ: error 42501 หรือ 0 แถว — ถ้า "สำเร็จ" เมื่อไหร่คือช่องโหว่

-- [C9a] user ยกระดับตัวเองเป็น admin ไม่ได้ → คาดหวัง 42501
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub":"<UID>","role":"authenticated"}';
UPDATE public."Profile" SET role='admin' WHERE id='<UID>' RETURNING email, role;

-- [C9b] user แก้ student_id ตัวเองไม่ได้ → คาดหวัง 42501
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub":"<UID>","role":"authenticated"}';
UPDATE public."Profile" SET student_id='6500000000' WHERE id='<UID>' RETURNING email, student_id;

-- [C9c] user แก้โปรไฟล์คนอื่นไม่ได้ → คาดหวัง 0 แถว (RLS กรองเงียบ ไม่ error)
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub":"<UID>","role":"authenticated"}';
UPDATE public."Profile" SET full_name='ไม่ควรสำเร็จ' WHERE id='<UID_คนอื่น>' RETURNING email, full_name;

-- [C10] anon เห็นอะไรบ้าง — สำคัญถ้าจะเปิด browse ก่อนล็อกอิน
--       ปัจจุบัน "CAT" คืน 0 เพราะ policy เป็น TO authenticated
BEGIN;
SET LOCAL ROLE anon;
SELECT
  (SELECT count(*) FROM public."CAT")     AS cat_as_anon,
  (SELECT count(*) FROM public.products)  AS products_as_anon,
  (SELECT count(*) FROM public_profiles)  AS profiles_as_anon;
