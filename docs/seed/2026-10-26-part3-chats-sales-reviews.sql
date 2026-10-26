-- Seed 2026-10-26 ก้อน 3/3 — แชท + ปิดการขาย + รีวิว + ปรับเวลา/สถานะอ่านของแจ้งเตือน
-- ปิดการขายเรียก public.mark_product_sold() จริง (ตั้ง request.jwt.claims เป็นผู้ขาย) → ได้ transactions + sale_confirmed จากทริกเกอร์ปกติ
-- ข้อความแรกของทุกห้องเป็นการ์ดสินค้า (product_id, message NULL → trg_guard_chat_message_product เติม "สนใจสินค้า: ...")
DO $seed$
DECLARE
  seed_start timestamptz := now();
  c record; cid bigint; b uuid; s uuid; pid uuid; ts timestamptz;
  idx int := 0; msg text; sender uuid; last_sender uuid;
BEGIN
  ALTER TABLE public.notifications DISABLE TRIGGER trg_push_notification_ntfy;

  CREATE TEMP TABLE seed_users(k text, id uuid) ON COMMIT DROP;
  INSERT INTO seed_users VALUES
    ('t1','88d36b1d-ff3d-4caa-a41e-7f037ca324de'), ('sm','2060a1d7-7764-42af-9037-60ef81de0d81'),
    ('t3','e7ad704d-6164-4092-a489-25facc6cd8d9'), ('pt','5f96717b-b9e8-46dd-8888-1c0e77a6a3cc'),
    ('nu','19353e8f-05d8-4bbc-9674-c1b2cdae8c17'), ('ka','c0f8e5cc-5942-43bb-9e2b-fb6de6439405'),
    ('su','69b466c8-e218-40b1-9127-0d2b6a5bb7d0'), ('kr','ee6c7a3e-26f8-4730-86a0-288aff54dad4'),
    ('pp','a255560a-88da-48d6-be7d-8097569860a2'), ('mi','061dd663-3761-4200-b2ee-f27aa465f933'),
    ('pe','7a61ae5c-e8a6-48e8-a4cf-02f97f23f61a');
  CREATE TEMP TABLE seed_chats(chat_id bigint, last_sender uuid) ON COMMIT DROP;

  FOR c IN
    SELECT * FROM (VALUES
      -- ผู้ซื้อ, ผู้ขาย, สินค้า #, ปิดการขาย?, กี่วันก่อน, ข้อความ (b|=ผู้ซื้อ s|=ผู้ขาย) — ข้อความสุดท้ายของห้องที่ปิดท้ายด้วยอีกฝ่ายยังไม่อ่าน
      ('t1','kr', 4,false, 3, ARRAY['b|สวัสดีครับ จักรยานคันนี้ยังอยู่ไหมครับ','s|ยังอยู่ค่ะ ปั่นได้ปกติ เพิ่งเปลี่ยนยางใหม่','b|ลดได้อีกนิดไหมครับ 2,500 ได้ไหม','s|2,600 ได้ค่ะ รับที่หน้าหอในได้เลย']),
      ('nu','sm',11,false, 2, ARRAY['b|สนใจหม้อทอดค่ะ ใช้มากี่เดือนแล้วคะ','s|ประมาณ 8 เดือนครับ สภาพดี มีกล่องครบ','b|ขอบคุณค่ะ เดี๋ยวขอคิดดูก่อนนะคะ']),
      ('su','pp',18,false, 1, ARRAY['b|iPhone 11 เครื่องศูนย์ไทยไหมครับ','s|ศูนย์ไทยครับ ประกันหมดแล้ว มีใบเสร็จ','b|แบตเสื่อมเท่าไหร่ครับ','s|86% ครับ เดี๋ยวส่งรูปหน้าจอแบตให้']),
      ('pt','t1', 7,false, 5, ARRAY['b|สนใจ iPad ครับ มีรอยตรงไหนไหม','s|มีรอยเล็กน้อยที่ขอบ หน้าจอไม่มีรอยครับ','b|นัดดูเครื่องที่ตึกสารสนเทศได้ไหมครับ','s|ได้ครับ บ่ายวันพุธว่าง','b|โอเคครับ เจอกัน']),
      ('mi','ka', 2,false, 4, ARRAY['b|ชุดพยาบาลไซซ์ S รอบอกกี่นิ้วคะ','s|รอบอก 34 นิ้วค่ะ','b|ได้เลยค่ะ ขอเอาเลยนะคะ','s|ได้ค่ะ นัดรับที่โรงอาหารกลางนะคะ']),
      ('pe','nu',14,false, 6, ARRAY['b|หนังสือ TOEIC มีเขียนในเล่มไหมครับ','s|ไม่มีค่ะ สะอาดเลย','b|เดี๋ยวผมแวะไปรับครับ','s|ได้ค่ะ']),
      ('t3','pe',22,false, 1, ARRAY['b|ลูกบอลยังอยู่ไหมครับ']),
      ('kr','mi',21,false, 3, ARRAY['b|โคมไฟปรับแสงได้กี่ระดับคะ','s|3 ระดับค่ะ มีไฟเหลืองกับไฟขาว','b|น่าสนใจค่ะ เสาร์นี้ขอไปรับได้ไหมคะ']),
      -- ห้องที่ปิดการขายแล้ว
      ('t1','ka', 1, true,  9, ARRAY['b|ตำรากายวิภาคเล่ม 1 ยังอยู่ไหมครับ ผมสอบกลางภาคอาทิตย์หน้า','s|ยังอยู่ค่ะ 280 บาท','b|รับเลยครับ เจอกันที่ห้องสมุดได้ไหม','s|ได้ค่ะ พรุ่งนี้เที่ยงนะคะ','b|ได้รับหนังสือแล้วครับ ขอบคุณครับ','s|ขอบคุณเช่นกันค่ะ']),
      ('nu','kr', 6, true, 12, ARRAY['b|ลำโพง JBL เสียงยังดีอยู่ไหมคะ','s|ดีค่ะ แบตอยู่ได้ประมาณ 5 ชั่วโมง','b|รับค่ะ 650 โอนได้เลยไหมคะ','s|ได้ค่ะ เดี๋ยวส่งเลขบัญชีให้','b|โอนแล้วนะคะ','s|ได้รับยอดแล้วค่ะ ขอบคุณค่ะ']),
      ('su','t3',10, true,  8, ARRAY['b|เครื่องคิดเลข Casio ใช้สอบได้ไหมคะ','s|ได้ครับ รุ่นที่อนุญาตเข้าห้องสอบ','b|เอาค่ะ 280 บาท','s|ได้ครับ นัดตึกคณะบริหารนะครับ']),
      ('t3','pp',19, true, 15, ARRAY['b|Power bank ชาร์จ iPhone ได้กี่รอบครับ','s|ประมาณ 2 รอบครับ','b|ซื้อครับ 250','s|รับที่หน้าหอสมุดได้เลยครับ'])
    ) v(bk, sk, pn, sale, days_ago, msgs)
  LOOP
    idx := idx + 1;
    SELECT id INTO b FROM seed_users WHERE k = c.bk;
    SELECT id INTO s FROM seed_users WHERE k = c.sk;
    pid := ('5eed0000-0000-4000-8000-' || lpad(c.pn::text, 12, '0'))::uuid;
    ts := now() - make_interval(days => c.days_ago) - make_interval(mins => idx * 13);

    SELECT cu1.chat_id INTO cid
    FROM public.chat_user cu1
    JOIN public.chat_user cu2 ON cu2.chat_id = cu1.chat_id AND cu2.user_id = s
    WHERE cu1.user_id = b LIMIT 1;
    IF cid IS NULL THEN
      INSERT INTO public.chat (created_at) VALUES (ts) RETURNING id INTO cid;
      INSERT INTO public.chat_user (chat_id, user_id, created_at) VALUES (cid, b, ts), (cid, s, ts);
    END IF;

    INSERT INTO public.chat_message (chat_id, user_id, message, product_id, created_at)
    VALUES (cid, b, NULL, pid, ts);
    last_sender := b;
    FOREACH msg IN ARRAY c.msgs LOOP
      sender := CASE split_part(msg, '|', 1) WHEN 'b' THEN b ELSE s END;
      ts := ts + (2 + random() * 4) * interval '1 minute';
      INSERT INTO public.chat_message (chat_id, user_id, message, created_at)
      VALUES (cid, sender, substr(msg, 3), ts);
      last_sender := sender;
    END LOOP;
    INSERT INTO seed_chats VALUES (cid, last_sender);

    IF c.sale THEN
      PERFORM set_config('request.jwt.claims', json_build_object('sub', s, 'role', 'authenticated')::text, true);
      PERFORM set_config('request.jwt.claim.sub', s::text, true);
      PERFORM public.mark_product_sold(cid, pid);
      PERFORM set_config('request.jwt.claims', '', true);
      PERFORM set_config('request.jwt.claim.sub', '', true);
      UPDATE public.transactions SET created_at = ts + interval '1 hour' WHERE chat_id = cid AND product_id = pid;
    END IF;
  END LOOP;

  -- รีวิว: ผู้ซื้อให้ดาวผู้ขาย 3 จาก 4 ธุรกรรมใหม่ (เหลือ #10 ไว้ทดสอบ prompt ให้คะแนน) + ธุรกรรมเก่าที่ยังไม่มีรีวิว 1 รายการ
  INSERT INTO public.reviews (transaction_id, reviewer_id, reviewee_id, rating, comment, created_at)
  SELECT t.id, t.buyer_id, t.seller_id, v.rating, v.comment, least(now(), t.created_at + interval '1 day')
  FROM (VALUES
    ('5eed0000-0000-4000-8000-000000000001'::uuid, 5, 'ผู้ขายตอบไว นัดตรงเวลา หนังสือสภาพดีตามรูป'),
    ('5eed0000-0000-4000-8000-000000000006'::uuid, 4, 'ของตรงปก ส่งมอบไว แต่นัดรับช้าไปนิดหน่อย'),
    ('5eed0000-0000-4000-8000-000000000019'::uuid, 5, 'สภาพตามที่บอก ชาร์จได้เร็ว ขอบคุณครับ')
  ) v(pid, rating, comment)
  JOIN public.transactions t ON t.product_id = v.pid;

  INSERT INTO public.reviews (transaction_id, reviewer_id, reviewee_id, rating, comment, created_at)
  SELECT t.id, t.buyer_id, t.seller_id, 5, 'ของดี ราคาเป็นกันเอง แนะนำครับ', least(now(), t.created_at + interval '2 days')
  FROM public.transactions t
  WHERE t.id = '574b95c3-9533-463d-8b46-d852853137ba'::uuid
    AND NOT EXISTS (SELECT 1 FROM public.reviews r WHERE r.transaction_id = t.id);

  -- สถานะอ่าน: แจ้งเตือนแชทของห้อง seed อ่านแล้วทั้งหมด ยกเว้นผู้รับข้อความสุดท้ายของห้องที่อีกฝ่ายพูดปิดท้าย
  -- (ห้องที่ปิดการขายถือว่าอ่านแล้วทั้งหมด)
  UPDATE public.notifications n SET is_read = true
  WHERE n.type = 'chat_message' AND n.created_at >= seed_start
    AND n.ref_chat_id IN (SELECT chat_id FROM seed_chats);
  UPDATE public.notifications n SET is_read = false
  FROM seed_chats sc
  WHERE n.type = 'chat_message' AND n.ref_chat_id = sc.chat_id AND n.user_id <> sc.last_sender
    AND n.created_at >= seed_start
    AND NOT EXISTS (SELECT 1 FROM public.transactions t WHERE t.chat_id = sc.chat_id);

  -- เวลาแจ้งเตือนให้ตรงกับเหตุการณ์จริง
  UPDATE public.notifications n SET created_at = x.ts
  FROM (SELECT n2.id, (SELECT max(m.created_at) FROM public.chat_message m
                       WHERE m.chat_id = n2.ref_chat_id AND m.user_id <> n2.user_id) ts
        FROM public.notifications n2
        WHERE n2.type = 'chat_message' AND n2.created_at >= seed_start) x
  WHERE n.id = x.id AND x.ts IS NOT NULL;
  UPDATE public.notifications n SET created_at = t.created_at
  FROM public.transactions t
  WHERE n.type = 'sale_confirmed' AND n.created_at >= seed_start
    AND n.ref_chat_id = t.chat_id AND n.ref_product_id = t.product_id;
  UPDATE public.notifications n SET created_at = r.created_at
  FROM public.reviews r
  WHERE n.type = 'review_received' AND n.created_at >= seed_start AND n.ref_review_id = r.id;
  UPDATE public.notifications n SET created_at = (SELECT max(v.viewed_at) FROM public.product_views v WHERE v.product_id = n.ref_product_id)
  WHERE n.type = 'product_popular' AND n.ref_product_id::text LIKE '5eed0000%';

  -- chat_user.last_read_at: ผู้รับข้อความท้ายสุดที่ยังไม่อ่านค้างที่ข้อความสุดท้ายของตัวเอง นอกนั้นอ่านถึงปัจจุบัน
  UPDATE public.chat_user cu SET last_read_at = CASE
      WHEN cu.user_id <> sc.last_sender
           AND NOT EXISTS (SELECT 1 FROM public.transactions t WHERE t.chat_id = sc.chat_id)
        THEN (SELECT max(m.created_at) FROM public.chat_message m WHERE m.chat_id = cu.chat_id AND m.user_id = cu.user_id)
      ELSE (SELECT max(m.created_at) FROM public.chat_message m WHERE m.chat_id = cu.chat_id) + interval '1 minute'
    END
  FROM seed_chats sc WHERE cu.chat_id = sc.chat_id;

  ALTER TABLE public.notifications ENABLE TRIGGER trg_push_notification_ntfy;
END
$seed$;
