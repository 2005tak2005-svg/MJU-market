-- ย้อน seed เดโมแจ้งเตือนของ mju6606105382 (2026-10-27) — รันด้วย role postgres
-- ไม่ย้อน: แถว product_views ที่เติมให้เสื้อเชิ้ต/เบลเซอร์ (แยกจากของจริงไม่ได้) · last_read_at ของห้อง 6, 8, 12, 15, 21
DO $clean$
BEGIN
  DELETE FROM public.notifications
   WHERE user_id = '5f96717b-b9e8-46dd-8888-1c0e77a6a3cc' AND type = 'chat_message'
     AND ref_chat_id IN (6, 8, 12, 15, 21) AND created_at >= '2026-10-26' AND is_read = false;
  DELETE FROM public.chat_message WHERE id BETWEEN 162 AND 169;
  DELETE FROM public.products WHERE id = '5eed0000-0000-4000-8000-000000000025'::uuid;
END
$clean$;
