-- Seed 2026-10-26 ก้อน 2/3 — ยอดดู + wishlist + โพสต์โฆษณา/ไลก์
-- ผู้ดู/ผู้บันทึก = role 'user' ที่ไม่ถูกแบน และไม่ใช่เจ้าของสินค้า (ตรงกับกติกา record_product_view)
-- สินค้า #4 และ #18 ได้ผู้ดูครบ 10 คนต่างกัน → trigger trg_notify_product_popular สร้างแจ้งเตือน product_popular จริง
DO $seed$
DECLARE
  prod record;
  n int;
  t0 timestamptz;
BEGIN
  ALTER TABLE public.notifications DISABLE TRIGGER trg_push_notification_ntfy;

  CREATE TEMP TABLE eligible ON COMMIT DROP AS
    SELECT id FROM public."Profile" WHERE role = 'user' AND NOT is_banned;

  FOR prod IN
    SELECT id, seller_id, created_at FROM public.products
    WHERE moderation_status = 'approved' ORDER BY created_at
  LOOP
    n := CASE WHEN prod.id IN ('5eed0000-0000-4000-8000-000000000004'::uuid,
                               '5eed0000-0000-4000-8000-000000000018'::uuid) THEN 10
              ELSE floor(random() * 8)::int END;
    t0 := greatest(prod.created_at, now() - interval '14 days');
    INSERT INTO public.product_views (product_id, viewer_id, viewed_at)
    SELECT prod.id, e.id, t0 + random() * (now() - t0)
    FROM (SELECT id FROM eligible WHERE id <> prod.seller_id ORDER BY random() LIMIT n) e
    ORDER BY 3;
  END LOOP;

  -- wishlist: ผู้ใช้แต่ละคนบันทึก 1–3 ชิ้นที่ยังไม่ถูกขายและไม่ใช่ของตัวเอง
  INSERT INTO public.wishlist_items (product_id, user_id, created_at)
  SELECT w.pid, w.uid, now() - random() * interval '10 days'
  FROM (
    SELECT e.id uid, p.id pid,
           row_number() OVER (PARTITION BY e.id ORDER BY random()) rn,
           1 + floor(random() * 3)::int cap
    FROM eligible e
    JOIN public.products p
      ON p.moderation_status = 'approved' AND p.status IN ('available', 'reserved') AND p.seller_id <> e.id
  ) w
  WHERE w.rn <= w.cap
  ON CONFLICT DO NOTHING;

  -- โพสต์โฆษณาเพิ่ม 1 โพสต์ (แอดมิน c1243882) + ไลก์จากผู้ใช้ราวครึ่งหนึ่งในทุกโพสต์ที่เปิดอยู่
  INSERT INTO public.advertisement_posts (id, image_url, title, body, is_active, created_by, created_at)
  VALUES ('5eed0000-0000-4000-8000-0000000000a1',
          'https://placehold.co/900x500/2E7D32/FFFFFF/png?text=MJU+Market+Week',
          'สัปดาห์ตลาดมือสอง ม.แม่โจ้',
          'ลงประกาศขายของใช้ที่ไม่ได้ใช้แล้ว ช่วยน้องปีหนึ่งประหยัดงบ ร่วมสนุกได้ตลอดสัปดาห์นี้',
          true, 'c1243882-2c7f-45ee-b78c-392e11ff1e10', now() - interval '2 days');

  INSERT INTO public.advertisement_likes (post_id, user_id, created_at)
  SELECT a.id, e.id, now() - random() * interval '5 days'
  FROM public.advertisement_posts a CROSS JOIN eligible e
  WHERE a.is_active AND random() < 0.5
  ON CONFLICT DO NOTHING;

  ALTER TABLE public.notifications ENABLE TRIGGER trg_push_notification_ntfy;
END
$seed$;
