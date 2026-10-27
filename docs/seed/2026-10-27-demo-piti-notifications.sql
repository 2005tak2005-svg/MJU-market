-- Seed 2026-10-27 — เตรียมบัญชี mju6606105382 (ปิติเทพ, 5f96717b…) สำหรับเดโมแจ้งเตือนจริง
-- หลักการ: เตรียมให้ "ขาดอีก 1 การกระทำ" แล้วให้คนกดตอนพรีเซนต์ → ntfy ยิงจริงจากทริกเกอร์ปกติ
--   · ยอดดู: เสื้อเชิ้ต (14b1f223…) และเบลเซอร์ (f90007b8…) = 9 แถว → ผู้ใช้อื่นเปิด ProductDetails 1 ครั้ง = ครบ 10 → product_popular
--   · รอตรวจ: #24 กล้องฟิล์ม + #25 กางเกงยีนส์ → แอดมินปฏิเสธ = listing_rejected
--   · ห้อง 6 (กับ พีทน้อย) มีการ์ดสอบถามเสื้อเชิ้ต → ปิติเทพปิดการขาย = sale_confirmed ถึงพีทน้อย → พีทน้อยให้ดาว = review_received ถึงปิติเทพ
-- ระหว่างเตรียมปิด trg_push_notification_ntfy ใน transaction เดียวกัน (กันยิงก่อนเวลา)
DO $seed$
DECLARE
  pt constant uuid := '5f96717b-b9e8-46dd-8888-1c0e77a6a3cc';
  seed_start timestamptz := now();
  base bigint;
  prod record;
  need int;
BEGIN
  ALTER TABLE public.notifications DISABLE TRIGGER trg_push_notification_ntfy;
  SELECT coalesce(max(id), 0) INTO base FROM public.chat_message;

  -- 1) ยอดดู: เติมให้ครบ 9 แถว (ผู้ดู = role user ไม่แบน ไม่ใช่เจ้าของ, เวลา 1–10 วันก่อน → พ้น dedupe 30 นาที)
  FOR prod IN
    SELECT id, created_at FROM public.products
    WHERE id IN ('14b1f223-79df-439c-a852-f65956b9ee0b', 'f90007b8-9fbb-4651-bd79-bfa51f32ea37')
  LOOP
    need := 9 - (SELECT count(*) FROM public.product_views WHERE product_id = prod.id);
    IF need > 0 THEN
      INSERT INTO public.product_views (product_id, viewer_id, viewed_at)
      SELECT prod.id, e.id, greatest(prod.created_at, now() - interval '10 days') + random() * (now() - interval '1 day' - greatest(prod.created_at, now() - interval '10 days'))
      FROM (SELECT id FROM public."Profile" WHERE role = 'user' AND NOT is_banned AND id <> pt ORDER BY random() LIMIT need) e;
    END IF;
  END LOOP;

  -- 2) ประกาศรอตรวจเพิ่ม 1 รายการ (#24 มีอยู่แล้วจาก seed รอบก่อน)
  INSERT INTO public.products (id, created_at, seller_id, title, description, price, status, image_urls, condition,
                               contact_phone, moderation_status, category_id)
  VALUES ('5eed0000-0000-4000-8000-000000000025', now() - interval '2 hours', pt,
          'กางเกงยีนส์ Levi''s 501 ไซซ์ 30', 'ทรงตรง สีเข้ม ใส่น้อย ไม่มีรอยขาด', 650, 'available',
          ARRAY['https://placehold.co/600x600/C62828/FFFFFF/png?text=Levis+501',
                'https://placehold.co/600x600/C62828/FFFFFF/png?text=Levis+501+2'],
          'used', (SELECT NULLIF(btrim(phone), '') FROM public."Profile" WHERE id = pt), 'pending', 6);

  -- 3) ข้อความที่ยังไม่อ่านในกระดิ่ง (ย้อนเวลา; แจ้งเตือนถูกปรับเวลาตามด้านล่าง)
  -- ห้อง 6 พีทน้อย (ใช้เดโมปิดการขาย) · ห้อง 8 นุช · ห้อง 15 ปิยพงษ์ · ห้อง 12 กฤตยา · ห้อง 21 แอดมิน
  INSERT INTO public.chat_message (chat_id, user_id, message, product_id, created_at) VALUES
    (6,  '7a61ae5c-e8a6-48e8-a4cf-02f97f23f61a', NULL, '14b1f223-79df-439c-a852-f65956b9ee0b', now() - interval '95 minutes'),
    (6,  '7a61ae5c-e8a6-48e8-a4cf-02f97f23f61a', 'เสื้อเชิ้ตตัวนี้ยังอยู่ไหมครับ', NULL, now() - interval '92 minutes'),
    (6,  '7a61ae5c-e8a6-48e8-a4cf-02f97f23f61a', 'ถ้ารับวันนี้ ลดให้หน่อยได้ไหมครับ', NULL, now() - interval '88 minutes'),
    (8,  '19353e8f-05d8-4bbc-9674-c1b2cdae8c17', NULL, 'f90007b8-9fbb-4651-bd79-bfa51f32ea37', now() - interval '5 hours'),
    (8,  '19353e8f-05d8-4bbc-9674-c1b2cdae8c17', 'สูทตัวนี้รอบอกกี่นิ้วคะ', NULL, now() - interval '4 hours 55 minutes'),
    (15, 'a255560a-88da-48d6-be7d-8097569860a2', NULL, '14b1f223-79df-439c-a852-f65956b9ee0b', now() - interval '9 hours'),
    (12, 'ee6c7a3e-26f8-4730-86a0-288aff54dad4', 'ที่คุยกันไว้เมื่อวาน เสาร์นี้ไปรับได้เลยนะคะ', NULL, now() - interval '20 hours'),
    (21, '14475718-6390-494b-8d4e-ded8a766258c', 'ประกาศของคุณอยู่ระหว่างตรวจสอบ ขอบคุณที่รอนะคะ', NULL, now() - interval '2 hours');

  -- แจ้งเตือนที่เกิดจากข้อความข้างบน: เวลา = เวลาข้อความล่าสุดของห้อง
  UPDATE public.notifications n SET created_at = x.ts
  FROM (SELECT n2.id, (SELECT max(m.created_at) FROM public.chat_message m
                       WHERE m.chat_id = n2.ref_chat_id AND m.id > base AND m.user_id <> n2.user_id) ts
        FROM public.notifications n2
        WHERE n2.user_id = pt AND n2.type = 'chat_message' AND n2.created_at >= seed_start) x
  WHERE n.id = x.id AND x.ts IS NOT NULL;

  -- last_read_at ของปิติเทพ: ค้างที่ข้อความก่อนหน้าชุดนี้ (ให้ตัวเลขยังไม่อ่านในรายการแชทตรงกับกระดิ่ง)
  UPDATE public.chat_user cu SET last_read_at = (
      SELECT max(m.created_at) FROM public.chat_message m WHERE m.chat_id = cu.chat_id AND m.id <= base)
  WHERE cu.user_id = pt AND cu.chat_id IN (6, 8, 12, 15, 21);

  ALTER TABLE public.notifications ENABLE TRIGGER trg_push_notification_ntfy;
END
$seed$;
