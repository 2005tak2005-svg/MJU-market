-- L5 — Transaction & Listing Status (D-59)

-- [5.1] ตาราง transactions มีคอลัมน์ครบตามที่ออกแบบไหม
SELECT column_name, data_type, column_default FROM information_schema.columns
WHERE table_schema='public' AND table_name='transactions' ORDER BY ordinal_position;

-- [5.2] products.status ต้องเป็น available/reserved/sold เท่านั้น (NOT NULL แล้ว — ไม่มี NULL ที่ถูกต้องอีกต่อไป)
--       ถ้าเจอ pending/approved/rejected โผล่ในนี้ = flow ของ L2 เขียนผิดคอลัมน์ (D-04)
SELECT status, count(*) FROM public.products GROUP BY 1 ORDER BY 2 DESC;

-- [5.3] RLS ของ transactions — ต้องมีแค่ SELECT policy เดียว ไม่มี INSERT/UPDATE/DELETE ให้ authenticated เลย
SELECT policyname, cmd, roles, qual, with_check FROM pg_policies WHERE tablename='transactions';

-- [5.3b] products ต้องไม่มี "Allow all for authenticated users" หลงเหลือ (ปิดหนี้ D-03)
--        ต้องเห็น 4 policy ตาม cmd (SELECT/INSERT/UPDATE/DELETE) + RESTRICTIVE เดิม 3 ตัว (D-52)
SELECT policyname, cmd, permissive, roles, qual, with_check FROM pg_policies WHERE tablename='products' ORDER BY cmd;

-- [5.3c] trigger ที่ล็อก status/buyer_id ไว้กับ RPC ต้องเปิดอยู่
SELECT tgname, tgenabled FROM pg_trigger WHERE tgrelid = 'public.products'::regclass AND tgname = 'enforce_sale_via_rpc_only';

-- [5.4] integrity — transaction ที่ product ไม่มีอยู่จริง (product_id เป็น NULL ได้ปกติถ้าประกาศถูกลบทีหลัง — ON DELETE SET NULL)
SELECT t.id FROM public.transactions t
WHERE t.product_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.products p WHERE p.id = t.product_id);

-- [5.5] สินค้าที่ sold แล้วแต่ยังไม่มี transaction คู่กัน (ควรว่างเสมอ — mark_product_sold insert คู่กับ UPDATE ในทรานแซกชันเดียว)
SELECT p.id, p.title FROM public.products p
LEFT JOIN public.transactions t ON t.product_id = p.id
WHERE p.status = 'sold' AND t.id IS NULL;

-- [5.6] ⭐ race condition — สินค้าเดียวห้ามมีมากกว่า 1 transaction (mark_product_sold's conditional UPDATE
--       ป้องกันไว้แล้ว — query นี้คือการยืนยันย้อนหลังว่าไม่มีการขายซ้ำเล็ดลอดผ่านไปได้จริง)
SELECT product_id, count(*) FROM public.transactions
GROUP BY 1 HAVING count(*) > 1;

-- ทดสอบ race condition ด้วยมือ (ถ้าต้องการยืนยันซ้ำ): เปิด 2 session พร้อมกัน
-- impersonate คนละ session เป็นผู้ขายคนเดียวกัน แล้วยิง SELECT mark_product_sold(<chat_id>, <product_id>)
-- พร้อมกัน — ต้องมีแค่ session เดียวที่สำเร็จ อีกฝั่งได้ error "ไม่พบประกาศนี้ ไม่ใช่ของคุณ หรือถูกขายไปแล้ว"

-- [5.7] chat_sale_status_view ตอบถูกทั้ง 2 คอลัมน์ไหม (แทนคีย์จริงก่อนรัน)
-- SELECT * FROM chat_sale_status_view WHERE chat_id = <CHAT_ID>;

-- [5.8] (D-93) แถวการ์ดสินค้าต้องผ่านกติกา trigger: สินค้า approved, ผู้ส่ง ≠ เจ้าของสินค้า, เจ้าของสินค้าอยู่ในห้อง — ต้องคืน 0 แถว
SELECT cm.id, cm.chat_id, cm.product_id
FROM public.chat_message cm
JOIN public.products p ON p.id = cm.product_id
WHERE cm.product_id IS NOT NULL
  AND (p.seller_id = cm.user_id
       OR NOT EXISTS (SELECT 1 FROM public.chat_user cu WHERE cu.chat_id = cm.chat_id AND cu.user_id = p.seller_id));

-- [5.9] (D-93) ห้องที่มีการ์ด: chat_already_sold ต้องตรงกับสถานะสินค้าที่อ้างถึงล่าสุด (แทน <CHAT_ID> ก่อนรัน · ดูผลในนามผู้ใช้ที่เป็นสมาชิกห้อง)
-- SELECT s.chat_id, s.inquiry_product_id, s.chat_already_sold, p.status
-- FROM public.chat_sale_status_view s JOIN public.products p ON p.id = s.inquiry_product_id
-- WHERE s.chat_id = <CHAT_ID>;   -- chat_already_sold ต้อง = (p.status = 'sold')
