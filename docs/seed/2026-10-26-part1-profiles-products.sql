-- Seed 2026-10-26 ก้อน 1/3 — โปรไฟล์ + สินค้า (รันด้วย role postgres ผ่าน execute_sql)
-- ปิด trg_push_notification_ntfy ใน transaction เดียวกัน (DDL rollback ได้) กันยิง ntfy.sh จริง
-- สินค้า seed ใช้ id 5eed0000-0000-4000-8000-0000000000NN (NN = 01..24) → ลบด้วย cleanup.sql
-- รูปเป็น placeholder จาก placehold.co (ไม่มีไฟล์จริงใน Storage)
DO $seed$
DECLARE seed_start timestamptz := now();
BEGIN
  ALTER TABLE public.notifications DISABLE TRIGGER trg_push_notification_ntfy;

  CREATE TEMP TABLE seed_users(k text, id uuid) ON COMMIT DROP;
  INSERT INTO seed_users VALUES
    ('t1','88d36b1d-ff3d-4caa-a41e-7f037ca324de'), ('sm','2060a1d7-7764-42af-9037-60ef81de0d81'),
    ('t3','e7ad704d-6164-4092-a489-25facc6cd8d9'), ('bo','5ea0307d-44c8-4d09-b233-1786f8d83054'),
    ('pt','5f96717b-b9e8-46dd-8888-1c0e77a6a3cc'), ('nu','19353e8f-05d8-4bbc-9674-c1b2cdae8c17'),
    ('ka','c0f8e5cc-5942-43bb-9e2b-fb6de6439405'), ('su','69b466c8-e218-40b1-9127-0d2b6a5bb7d0'),
    ('kr','ee6c7a3e-26f8-4730-86a0-288aff54dad4'), ('pp','a255560a-88da-48d6-be7d-8097569860a2'),
    ('mi','061dd663-3761-4200-b2ee-f27aa465f933'), ('pe','7a61ae5c-e8a6-48e8-a4cf-02f97f23f61a');

  -- โปรไฟล์: เติมเฉพาะช่องที่ว่าง (faculty_id/year_of_study ว่าง → trigger enforce_academic_info_lock ไม่ทำงาน)
  UPDATE public."Profile" p SET
    faculty_id    = COALESCE(p.faculty_id, v.fac),
    year_of_study = COALESCE(p.year_of_study, v.yr),
    bio           = CASE WHEN COALESCE(btrim(p.bio), '') = '' THEN v.bio ELSE p.bio END
  FROM (VALUES
    ('t1', 11, 2,    'สนใจอุปกรณ์ไอทีมือสอง ซื้อ-ขายได้ในมอ'),
    ('sm',  3, NULL, 'บุคลากร คณะวิทยาศาสตร์ ขายของใช้ในบ้านที่ไม่ได้ใช้แล้ว'),
    ('t3',  4, 1,    'ปี 1 มองหาหนังสือเรียนและอุปกรณ์ราคาประหยัด'),
    ('bo',  9, 2,    'ขายของใช้ส่วนตัว นัดรับในมอได้'),
    ('pt', 11, 3,    'ของสภาพดี ราคาเป็นกันเอง นัดรับได้ทุกวัน'),
    ('nu',  7, 2,    'ขายหนังสือและของใช้ในหอ'),
    ('ka', 12, 3,    'นักศึกษาพยาบาล ขายตำราและชุดฝึกงานสภาพดี'),
    ('su',  4, 2,    'ขายเฟอร์นิเจอร์และของใช้ในหอพัก'),
    ('kr',  5, 4,    'ปี 4 เคลียร์ของก่อนจบ ราคาต่อรองได้'),
    ('pp', 11, 3,    'รับซื้อ-ขายโน้ตบุ๊กและมือถือสภาพดี'),
    ('mi', 10, 1,    'ขายอุปกรณ์เขียนแบบและของใช้ในห้องพัก')
  ) v(k, fac, yr, bio)
  JOIN seed_users u ON u.k = v.k
  WHERE p.id = u.id;

  -- สินค้า
  INSERT INTO public.products
    (id, created_at, seller_id, title, description, price, status, image_urls, condition,
     contact_phone, moderation_status, category_id, rejection_reason)
  SELECT
    ('5eed0000-0000-4000-8000-' || lpad(v.n::text, 12, '0'))::uuid,
    now() - make_interval(days => v.days_ago, hours => (v.n * 5) % 12),
    u.id, v.title, v.descr, v.price, v.st,
    CASE WHEN v.nimg = 0 THEN NULL ELSE ARRAY(
      SELECT format('https://placehold.co/600x600/%s/FFFFFF/png?text=%s',
                    (ARRAY['2E7D32','1565C0','6A1B9A','EF6C00','00838F','AD1457','4E342E','37474F','558B2F','283593','C62828','00695C'])[v.cat],
                    v.label || CASE WHEN i = 1 THEN '' ELSE '+' || i END)
      FROM generate_series(1, v.nimg) i) END,
    v.cond,
    (SELECT NULLIF(btrim(phone), '') FROM public."Profile" WHERE id = u.id),
    v.modst, v.cat, v.reason
  FROM (VALUES
    -- n, seller, title, descr, price, status, nimg, cond, moderation, cat, reason, label, days_ago
    ( 1,'ka','ตำรากายวิภาคศาสตร์ ฉบับพยาบาล เล่ม 1','ปกแข็ง สภาพดี มีไฮไลต์เล็กน้อยบางหน้า ใช้เรียนปี 1',280,'available',2,'used','approved',1,NULL,'Anatomy+Book',16),
    ( 2,'ka','ชุดนักศึกษาพยาบาล เสื้อ+กระโปรง ไซซ์ S','ซักรีดแล้ว ใส่ไม่กี่ครั้ง รอบอก 34 นิ้ว',350,'available',2,'used','approved',6,NULL,'Nursing+Uniform',11),
    ( 3,'ka','หูฟังแพทย์ Stethoscope มือสอง','ใช้ตอนฝึกงาน 1 เทอม เสียงชัด สายไม่แตก',900,'available',1,'used','pending',12,NULL,'Stethoscope',1),
    ( 4,'kr','จักรยานเสือภูเขา 26 นิ้ว ปั่นสบาย','เพิ่งเปลี่ยนยางใหม่ เบรกดี มีตะกร้าหน้า',2800,'available',3,'used','approved',11,NULL,'Mountain+Bike',13),
    ( 5,'kr','หมวกกันน็อคจักรยาน ไซซ์ M','ใช้งานน้อย สายรัดปรับได้ มีรอยขีดข่วนเล็กน้อย',150,'reserved',1,'used','approved',11,NULL,'Bike+Helmet',9),
    ( 6,'kr','ลำโพงบลูทูธ JBL Go 3','เสียงดี แบตอยู่ได้ประมาณ 5 ชั่วโมง มีสายชาร์จ',650,'available',2,'used','approved',5,NULL,'JBL+Speaker',14),
    ( 7,'t1','iPad Air 4 64GB สีฟ้า พร้อมเคส','ใช้จดโน้ตเรียน แบต 90% มีรอยเล็กน้อยที่ขอบ จอไม่มีรอย',14500,'available',3,'used','approved',4,NULL,'iPad+Air',7),
    ( 8,'t1','เมาส์ไร้สาย Logitech M331 เงียบ','คลิกเงียบ ใช้ถ่าน AA แถมถ่านให้ 1 คู่',250,'available',1,'used','approved',5,NULL,'Wireless+Mouse',5),
    ( 9,'t3','หนังสือเศรษฐศาสตร์จุลภาค Mankiw (ฉบับแปลไทย)','เรียนจบวิชานี้แล้ว ไม่มีรอยเขียน',200,'available',1,'used','approved',1,NULL,'Economics+Book',6),
    (10,'t3','เครื่องคิดเลข Casio fx-350ES Plus','รุ่นที่อนุญาตเข้าห้องสอบ ปุ่มครบ จอชัด',280,'available',1,'used','approved',2,NULL,'Calculator',20),
    (11,'sm','หม้อทอดไร้น้ำมัน 4 ลิตร','ใช้มา 8 เดือน มีกล่องและคู่มือครบ',1200,'available',2,'used','approved',9,NULL,'Air+Fryer',10),
    (12,'sm','พัดลมไอเย็น ใช้งานได้ปกติ','ถังน้ำ 20 ลิตร รีโมตครบ เหมาะกับห้องพัก',1500,'available',2,'used','approved',9,NULL,'Cooling+Fan',12),
    (13,'sm','ไมโครเวฟ 20 ลิตร','อุ่นอาหารได้ปกติ ถาดหมุนครบ',1000,'available',1,'used','pending',9,NULL,'Microwave',1),
    (14,'nu','หนังสือ TOEIC Reading ฉบับสมบูรณ์','ไม่มีรอยเขียน พร้อมเฉลยท้ายเล่ม',180,'available',1,'used','approved',1,NULL,'TOEIC+Book',15),
    (15,'nu','ชุดแบดมินตันไม้ Yonex 2 อัน + ลูก','เอ็นใหม่ เพิ่งขึงเมื่อเดือนก่อน มีกระเป๋าให้',450,'available',2,'used','approved',10,NULL,'Badminton+Set',8),
    (16,'nu','ร่มพับ UV กันแดด','ร่มใหม่ ยังไม่แกะป้าย กันแดดได้ดี',90,'available',0,'new','rejected',12,'รูปภาพไม่ชัดเจน ไม่เห็นตัวสินค้า กรุณาถ่ายรูปใหม่','Umbrella',4),
    (17,'su','รองเท้าวิ่ง Nike Revolution ไซซ์ 40','ใส่วิ่งไม่ถึง 10 ครั้ง พื้นยังไม่สึก',790,'available',3,'used','approved',10,NULL,'Running+Shoes',9),
    (18,'pp','iPhone 11 128GB สีดำ แบตฯ 86%','เครื่องศูนย์ไทย มีใบเสร็จ ประกันหมดแล้ว ไม่เคยแกะซ่อม',7900,'available',3,'used','approved',4,NULL,'iPhone+11',6),
    (19,'pp','Power Bank Eloop 10000mAh','ชาร์จ iPhone ได้ประมาณ 2 รอบ มีสายในกล่อง',250,'available',1,'used','approved',5,NULL,'Power+Bank',22),
    (20,'mi','ชุดไม้บรรทัดสถาปัตย์ + ปากกาเขียนแบบ','ไม้ T-square, สเกล, ปากกาเขียนแบบครบชุด เหมาะปี 1',320,'available',2,'used','approved',2,NULL,'Drafting+Set',5),
    (21,'mi','โคมไฟตั้งโต๊ะ LED ปรับแสงได้','ปรับ 3 ระดับ มีไฟเหลืองและไฟขาว',180,'available',2,'used','approved',7,NULL,'Desk+Lamp',8),
    (22,'pe','ลูกฟุตบอลหนังเบอร์ 5','เตะได้ปกติ ลมไม่รั่ว ใช้ในสนามหญ้าเทียม',250,'available',1,'used','approved',10,NULL,'Football',3),
    (23,'pe','สายชาร์จ USB-C 2 เมตร (ใหม่ ยังไม่แกะ)','ซื้อมาเกิน ยังไม่ได้แกะซอง',80,'available',1,'new','approved',5,NULL,'USB-C+Cable',2),
    (24,'pt','กล้องฟิล์ม Canon AE-1 + เลนส์ 50mm','ชัตเตอร์ทำงานปกติ ไฟวัดแสงใช้ได้ มีสายคล้อง',6500,'available',3,'used','pending',5,NULL,'Film+Camera',1)
  ) v(n, sk, title, descr, price, st, nimg, cond, modst, cat, reason, label, days_ago)
  JOIN seed_users u ON u.k = v.sk;

  -- แจ้งเตือนสินค้าถูกปฏิเสธ (รูปแบบเดียวกับ RejectProductSheet)
  INSERT INTO public.notifications (user_id, type, ref_product_id, title, body, created_at)
  SELECT p.seller_id, 'listing_rejected', p.id, 'ประกาศของคุณถูกปฏิเสธ', p.rejection_reason, now() - interval '3 days'
  FROM public.products p
  WHERE p.id = '5eed0000-0000-4000-8000-000000000016'::uuid;

  ALTER TABLE public.notifications ENABLE TRIGGER trg_push_notification_ntfy;
END
$seed$;
