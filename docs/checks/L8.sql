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

-- ═══════════════════════════════════════════════════════════════════
-- [8.7]–[8.11] ระบบ ban user (D-52, 2026-08-21)
-- 🔴 execute_sql หลายคำสั่งคืนแค่ผลสุดท้าย — รันทีละบล็อก
-- ═══════════════════════════════════════════════════════════════════

-- [8.7] ของครบไหม (ต้องได้ 3 helper + 1 trigger fn + 1 RPC + 1 trigger + 5 policy + 1 view)
SELECT 'function' AS ชนิด, n.nspname||'.'||p.proname AS ชื่อ, p.prosecdef::text AS security_definer
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE (n.nspname='private' AND p.proname IN ('is_banned','is_user_banned','chat_has_admin','enforce_ban_admin_only'))
    OR (n.nspname='public'  AND p.proname='admin_set_user_ban')
UNION ALL
SELECT 'trigger', t.tgname, t.tgenabled::text
  FROM pg_trigger t WHERE t.tgname='enforce_ban_admin_only'
UNION ALL
SELECT 'policy('||CASE WHEN pol.polpermissive THEN 'PERMISSIVE!ผิด' ELSE 'RESTRICTIVE' END||')',
       pol.polrelid::regclass::text||'.'||pol.polname, pol.polcmd::text
  FROM pg_policy pol WHERE pol.polname LIKE '%block_banned%'
UNION ALL
SELECT 'view', 'admin_users_view',
       (SELECT count(*)::text FROM information_schema.views
         WHERE table_schema='public' AND table_name='admin_users_view');

-- [8.8] 🔴 grant ของ helper ต้องตรงกับ private.is_admin() เป๊ะ
--       ({postgres=X, authenticated=X, service_role=X}) — ถ้า authenticated หาย policy พังทั้งชุด (PT-28 §3)
SELECT p.proname, p.proacl::text AS grants
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='private' AND p.proname IN ('is_admin','is_banned','is_user_banned','chat_has_admin')
 ORDER BY 1;

-- [8.9] products_review_view ต้องมี WHERE ซ่อนผู้ถูกแบน (ต้องเจอทั้ง 3 ท่อน)
SELECT (view_definition LIKE '%is_user_banned%')  AS มี_ซ่อนผู้ถูกแบน,
       (view_definition LIKE '%seller_id = auth.uid()%') AS เจ้าของยังเห็นของตัวเอง,
       (view_definition LIKE '%is_admin()%')      AS แอดมินเห็นทุกอย่าง
  FROM information_schema.views
 WHERE table_schema='public' AND table_name='products_review_view';

-- [8.10] notifications.type ต้องรับ account_banned/account_unbanned แล้ว
SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='notifications_type_check';

-- [8.11] 🔴 การบังคับจริง — ต้องรันในธุรกรรมที่ ROLLBACK และสวมเป็น user จริง ไม่ใช่ role postgres
--        (postgres bypass RLS — ผลที่ได้จะหลอกว่าผ่าน ดู AGENTS.md ข้อห้าม)
--        ⚠️ UPDATE/DELETE ที่โดน RESTRICTIVE USING บล็อกจะ "สำเร็จ 0 แถว" ไม่ raise
--           ต้องวัดด้วย GET DIAGNOSTICS ROW_COUNT ห้ามสรุปจาก "ไม่ error" (PT-28 §2)
-- BEGIN;
--   SET LOCAL ROLE authenticated;
--   SET LOCAL request.jwt.claims = '{"sub":"<uuid แอดมิน>","role":"authenticated"}';
--   SELECT public.admin_set_user_ban('<uuid เป้าหมาย>', true, 'ทดสอบ');
--   SET LOCAL request.jwt.claims = '{"sub":"<uuid เป้าหมาย>","role":"authenticated"}';
--   -- ต้อง 42501 ทั้ง 3: ลงประกาศ / ส่งรายงาน / แชทห้องที่ไม่มีแอดมิน
--   -- ต้องสำเร็จ: แชทห้องที่มีแอดมิน (ช่องอุทธรณ์) + find_or_create_chat_with_admin
--   -- ต้อง exception: UPDATE "Profile" SET is_banned=false WHERE id=auth.uid()
--   -- ต้อง 0 แถว: UPDATE/DELETE products WHERE seller_id=auth.uid()  ← เช็ค ROW_COUNT
--   -- ต้องยังเห็นประกาศคนอื่น (soft ban) และเห็นประกาศตัวเองครบ (Mypost)
-- ROLLBACK;

-- [8.12] สถานะ ban ปัจจุบัน (ควรว่างถ้ายังไม่ได้แบนใครจริง)
SELECT p.email, p.is_banned, p.ban_reason, p.banned_at, b.email AS banned_by_email
  FROM public."Profile" p LEFT JOIN public."Profile" b ON b.id = p.banned_by
 WHERE p.is_banned;
