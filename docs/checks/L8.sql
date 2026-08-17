-- L8 — Admin Dashboard
-- หนี้ D-03 (กัน admin ด้วย RLS จริง ไม่ใช่แค่ซ่อน UI) ปิดแล้วสำหรับ chat/chat_user/chat_message (D-29)
-- และ admin_sales_by_seller (gate ที่ตัว view เอง, D-33) — เหลือแค่ products (ยัง allow-all) — ดู [8.2b]

-- [8.1] view/RPC สรุปสำหรับ dashboard
SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind='v'
  AND (c.relname ILIKE '%admin%' OR c.relname ILIKE '%dashboard%');

-- [8.2] 🔴 policy ที่ตรวจ role='admin' มีอยู่ที่ตารางไหนบ้าง
--       ครอบคลุมทั้ง inline qual (role='admin') และเรียกผ่านฟังก์ชัน (private.is_admin() ฯลฯ)
--       pattern เดิม (qual ILIKE '%role%admin%') พลาดเคสหลังไปเงียบๆ — แก้แล้ว 2026-08-17 (D-32)
SELECT tablename, policyname, cmd, qual FROM pg_policies
WHERE qual ILIKE '%role%admin%' OR qual ILIKE '%is_admin%' ORDER BY tablename;

-- [8.2b] D-33 (2026-08-17): admin_sales_by_seller ปิดช่องโหว่แล้ว — เพิ่ม AND private.is_admin()
--       ในตัว view เอง ไม่พึ่ง products RLS อีกต่อไป (ยืนยันด้วย impersonation test จริง)
--       grant ระดับตารางด้านล่างยังกว้างตามปกติ (authenticated/anon) เพราะ gate มาจาก row filter
--       ไม่ใช่การ revoke table grant — ตรวจแค่เพื่อยืนยันว่า grant ไม่เปลี่ยนไปจากเดิม
SELECT grantee, privilege_type FROM information_schema.role_table_grants
WHERE table_name='admin_sales_by_seller' ORDER BY grantee;

-- [8.3] 💣 หนี้ D-03 — ตารางที่ยังเป็น allow-all (user ยิง API ตรงยังทำได้ทุกอย่าง)
--       ก่อนปิด L8 ต้องเหลือให้น้อยที่สุด
SELECT tablename, policyname, qual, with_check FROM pg_policies
WHERE schemaname='public' AND qual = 'true' ORDER BY tablename;

-- [8.4] ⭐ ทดสอบสำคัญที่สุดของ layer นี้:
--       user ธรรมดายิง query ของ admin ตรง ๆ ต้องไม่ได้ผล
-- BEGIN;
--   SET LOCAL ROLE authenticated;
--   SET LOCAL request.jwt.claims = '{"sub":"<UID_user_ธรรมดา>","role":"authenticated"}';
--   -- approve สินค้าคนอื่น — ปัจจุบัน "ทำได้" เพราะ products เป็น allow-all (นี่คือหนี้ที่ต้องแก้)
--   UPDATE products SET moderation_status='approved' WHERE id='<PID>';
--   -- อ่านรายงาน — ต้องได้ 0
--   SELECT count(*) FROM reports;
--   -- ยกระดับตัวเองเป็น admin — ต้อง error หรือ 0 rows (มี WITH CHECK คุ้มครอง)
--   UPDATE "Profile" SET role='admin' WHERE id='<UID_user_ธรรมดา>';
-- ROLLBACK;

-- [8.5] จำนวน admin ในระบบ (ควรมีน้อยและรู้ตัวทุกคน — ตั้งด้วยมือเท่านั้น D-02)
SELECT id, email, full_name FROM public."Profile" WHERE role='admin';

-- [8.6] ข้อมูลสรุปที่ dashboard น่าจะต้องใช้
SELECT
  (SELECT count(*) FROM public."Profile")                                        AS total_users,
  (SELECT count(*) FROM public.products WHERE moderation_status='pending')       AS pending_products,
  (SELECT count(*) FROM public.products WHERE moderation_status='approved')      AS approved_products,
  (SELECT count(*) FROM public.reports)                                          AS total_reports,
  (SELECT count(*) FROM public."CAT")                                            AS categories;
