-- ลบข้อมูล seed 2026-10-26 (ก้อน 1–3) — รันเป็นก้อนเดียวด้วย role postgres
-- ลบ: สินค้า #01–#24 (5eed0000-…) + ธุรกรรม/รีวิว/แจ้งเตือน/ยอดดู/wishlist ที่ผูกกับสินค้านั้น, โพสต์โฆษณา …a1 + ไลก์,
--      ข้อความแชท id 102–161, ห้องแชท 24–33 (ห้องใหม่ที่ seed สร้าง)
-- ไม่ย้อน: คณะ/ชั้นปี/bio ใน "Profile" · ข้อความที่ seed ใส่ในห้องเดิม 10 และ 17 ถูกลบแต่ last_read_at ของสองห้องนี้ไม่ถูกคืน
--          · ยอดดู/wishlist/ไลก์ของ seed บนสินค้า/โพสต์ "เดิม" (แยกจากข้อมูลจริงไม่ได้) · รีวิวธุรกรรมเดิม 574b95c3 (ลบให้ด้านล่าง)
--          · แจ้งเตือนแชทที่ยังไม่อ่านเดิม 1 รายการในห้อง 10/17 ที่ trigger notify_chat_message ลบตอน seed (ไม่กลับมา)
DO $clean$
BEGIN
  DELETE FROM public.reviews
   WHERE transaction_id IN (SELECT id FROM public.transactions WHERE product_id::text LIKE '5eed0000%')
      OR (transaction_id = '574b95c3-9533-463d-8b46-d852853137ba'::uuid AND comment = 'ของดี ราคาเป็นกันเอง แนะนำครับ');
  DELETE FROM public.transactions WHERE product_id::text LIKE '5eed0000%';
  DELETE FROM public.notifications WHERE ref_chat_id BETWEEN 24 AND 33;   -- ที่ผูกสินค้า/รีวิว ถูก CASCADE ตามสินค้า/รีวิว
  DELETE FROM public.notifications WHERE id IN (   -- แจ้งเตือนแชทที่ seed สร้างในห้องเดิม 10 และ 17
    '59318a0b-4311-403f-bba8-fdf7fcd4d8e2', '33e489cc-e011-4d29-8743-90717aec7deb',
    '7ceed811-64dd-4dc4-861d-cd2cb3d6043e', 'ae59eff4-13a0-4dce-9a56-55ba2c0588df');
  DELETE FROM public.chat_message WHERE id BETWEEN 102 AND 161;
  DELETE FROM public.chat_user WHERE chat_id BETWEEN 24 AND 33;
  DELETE FROM public.chat WHERE id BETWEEN 24 AND 33;
  DELETE FROM public.advertisement_posts WHERE id = '5eed0000-0000-4000-8000-0000000000a1'::uuid;   -- ไลก์ CASCADE
  DELETE FROM public.products WHERE id::text LIKE '5eed0000%';   -- ยอดดู/wishlist/แจ้งเตือนของสินค้า CASCADE
END
$clean$;
