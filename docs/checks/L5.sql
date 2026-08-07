-- L5 — Transaction & Listing Status

-- [5.1] ตาราง transactions มีหรือยัง (P-06)
SELECT column_name, data_type, column_default FROM information_schema.columns
WHERE table_schema='public' AND table_name='transactions' ORDER BY ordinal_position;

-- [5.2] 🔴 products.status ต้องไม่ถูกใช้ปนกับ moderation_status (D-04)
--       ค่าที่พบต้องเป็น available/reserved/sold/NULL เท่านั้น
--       ถ้าเจอ pending/approved/rejected โผล่ในนี้ = flow ของ L2 เขียนผิดคอลัมน์
SELECT status, count(*) FROM public.products GROUP BY 1 ORDER BY 2 DESC;

-- [5.3] RLS ของ transactions — ต้องเป็น restrictive ไม่ใช่ allow-all
SELECT policyname, cmd, qual, with_check FROM pg_policies WHERE tablename='transactions';

-- [5.4] integrity — transaction ที่ product/buyer/seller ไม่มีอยู่จริง
SELECT t.id FROM public.transactions t
LEFT JOIN public.products p ON p.id=t.product_id WHERE p.id IS NULL;

-- [5.5] สินค้าที่ sold แล้วแต่ยังไม่มี transaction (ถ้าเลือกใช้ตาราง transactions)
SELECT p.id, p.title FROM public.products p
LEFT JOIN public.transactions t ON t.product_id=p.id
WHERE p.status='sold' AND t.id IS NULL;

-- [5.6] ⭐ ทดสอบ race condition ด้วยมือ (PT-05)
--       เปิด 2 session พร้อมกันแล้วรันคำสั่งเดียวกัน — ต้องมีแค่ session เดียวที่ได้ UPDATE 1
-- UPDATE products SET status='reserved' WHERE id='<PRODUCT_ID>' AND status='available';
--       ตรวจผล: ต้องไม่มีสินค้าที่ reserved โดยมี transaction pending มากกว่า 1 รายการ
SELECT product_id, count(*) FROM public.transactions
WHERE status='pending' GROUP BY 1 HAVING count(*) > 1;
