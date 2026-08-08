-- L1 — Authentication & User Profiles
-- รัน _common.sql ก่อน แล้วค่อยรันทีละบล็อกด้านล่าง

-- [1.1] คอลัมน์ของ "Profile"
--       คาดหวังครบ: id, created_at, email, full_name, avatar_url, role, student_id, phone
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='public' AND table_name='Profile' ORDER BY ordinal_position;

-- [1.2] constraints ของ "Profile"
--       คาดหวัง: profile_student_id_unique, profile_student_id_format,
--                profile_student_id_matches_email, profile_email_domain,
--                CHECK role IN ('user','admin'), FK → auth.users
SELECT conname, contype, pg_get_constraintdef(oid) AS definition
FROM pg_constraint WHERE conrelid = 'public."Profile"'::regclass ORDER BY conname;

-- [1.3] 🔥 trigger auto-insert Profile (P-01) — คิวถัดไป
--       คาดหวังหลัง apply: 1 แถว (on_auth_user_created บน auth.users)
SELECT t.tgname, c.relname AS on_table, p.proname AS function_name
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE NOT t.tgisinternal AND c.relname = 'users';

-- [1.4] RLS policy ของ "Profile"
--       คาดหวัง: SELECT/UPDATE self + SELECT/UPDATE admin
--       🔴 UPDATE ต้องมี with_check ที่ล็อก role ไม่ให้เปลี่ยน — ถ้าหายไป = ช่องโหว่ privilege escalation
SELECT policyname, cmd, qual, with_check
FROM pg_policies WHERE tablename = 'Profile' ORDER BY cmd;

-- [1.5] ข้อมูลจริง — ต้องไม่มี role นอก ('user','admin') และไม่มี student_id ผิดรูปแบบ
SELECT role, count(*) FROM public."Profile" GROUP BY role;
SELECT id, student_id FROM public."Profile"
WHERE student_id IS NOT NULL AND student_id !~ '^[0-9]{10}$';

-- [1.6] auth.users ที่ยังไม่มีแถวใน Profile (ถ้า trigger ทำงานถูก ต้องได้ 0 แถว)
SELECT u.id, u.email FROM auth.users u
LEFT JOIN public."Profile" p ON p.id = u.id WHERE p.id IS NULL;

-- [1.7] อีเมลนอกโดเมน @mju.ac.th ที่หลุดเข้ามาแล้ว — คาดหวัง 0 แถว
--       🔴 ห้ามใช้ ILIKE '%@mju.ac.th' — 'hacker@evil.com@mju.ac.th' จะรอดสายตา
--       ต้อง anchor สองด้าน + [^@]+ บังคับให้มี @ ตัวเดียว (แก้ 2026-08-08 ดู D-10)
SELECT id, email FROM auth.users
WHERE lower(email) !~ '^[^@]+@mju\.ac\.th$';

-- [1.8] "Profile".email ต้องเป็นตัวเล็กทั้งหมด (trigger normalize ให้) — คาดหวัง 0 แถว
--       ถ้าเจอแถว = มีคนเขียนเลี่ยง trigger เข้ามา (service_role / SQL ตรง)
SELECT id, email FROM public."Profile" WHERE email <> lower(email);

-- [1.9] อีเมลซ้ำกันเมื่อไม่สนตัวพิมพ์ — คาดหวัง 0 แถว
--       Profile_email_key เป็น unique ธรรมดา ไม่ใช่ index บน lower() จึงจับเคสนี้เองไม่ได้
SELECT lower(email) AS email_lower, count(*) FROM public."Profile"
GROUP BY 1 HAVING count(*) > 1;

-- [1.10] ⭐ ทดสอบ trigger จริงแบบไม่ทิ้งข้อมูลค้าง — INSERT จริงแล้ว abort ด้วย RAISE
--        คาดหวัง: error [ผล] ที่บอกว่า 1) normalize+derive ได้ | 2) บุคลากร student_id=NULL
--                 | 3) @ซ้อน=ถูกบล็อก | 4) โดเมนนอก=ถูกบล็อก
--        (error ตัวนี้คือ "ผ่าน" ไม่ใช่ "พัง" — เป็นกลไก rollback) ผลรอบล่าสุด: VERIFICATION.md V-09
-- DO $do$
-- DECLARE r1 text; r2 text; r3 text; r4 text; uid uuid;
-- BEGIN
--   BEGIN
--     uid := gen_random_uuid();
--     INSERT INTO auth.users (id, email, raw_user_meta_data)
--     VALUES (uid, 'MJU6511119999@MJU.AC.TH', '{"full_name":"ทดสอบใหญ่"}'::jsonb);
--     SELECT format('email=%s student_id=%s', email, coalesce(student_id,'NULL'))
--       INTO r1 FROM public."Profile" WHERE id = uid;
--   EXCEPTION WHEN others THEN r1 := 'ERROR: ' || SQLERRM; END;
--   BEGIN
--     uid := gen_random_uuid();
--     INSERT INTO auth.users (id, email, raw_user_meta_data)
--     VALUES (uid, 'ajarn.somsri@mju.ac.th', '{"full_name":"อาจารย์"}'::jsonb);
--     SELECT format('email=%s student_id=%s', email, coalesce(student_id,'NULL'))
--       INTO r2 FROM public."Profile" WHERE id = uid;
--   EXCEPTION WHEN others THEN r2 := 'ERROR: ' || SQLERRM; END;
--   BEGIN
--     INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), 'hacker@evil.com@mju.ac.th');
--     r3 := 'ปล่อยผ่าน (ช่องโหว่!)';
--   EXCEPTION WHEN others THEN r3 := 'ถูกบล็อก'; END;
--   BEGIN
--     INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), 'hacker@evil.com');
--     r4 := 'ปล่อยผ่าน (ช่องโหว่!)';
--   EXCEPTION WHEN others THEN r4 := 'ถูกบล็อก'; END;
--   RAISE EXCEPTION '[ผล] 1)% || 2)% || 3)@ซ้อน=% || 4)โดเมนนอก=%', r1, r2, r3, r4;
-- END $do$;

-- [1.11] ❌ ตรวจจาก DB ไม่ได้: เส้นทางสมัครจริงผ่าน GoTrue (/auth/v1/signup)
--        [1.10] เขียนลง auth.users ตรง ๆ ซึ่งข้าม GoTrue ไป — ต้องสมัครผ่านแอปจริงถึงจะยืนยัน
--        ว่า full_name ถูกส่งมาใน raw_user_meta_data (ข้อที่ค้างปิด L1 อยู่ตอนนี้)

-- [1.12] bucket avatars — คาดหวัง 1 แถว: public=true, 2097152, {jpeg,png,webp}
SELECT id, public, file_size_limit, allowed_mime_types
FROM storage.buckets WHERE id = 'avatars';

-- [1.13] policy ของ avatars บน storage.objects — คาดหวัง 4 แถว
SELECT policyname, cmd, roles, qual, with_check
FROM pg_policies WHERE schemaname='storage' AND tablename='objects'
  AND policyname LIKE 'avatars%' ORDER BY policyname;

-- [1.14] trigger ต้องอ่าน phone จาก meta data (D-14) — คาดหวัง true ทั้งคู่
SELECT pg_get_functiondef(p.oid) LIKE '%raw_user_meta_data->>''phone''%' AS reads_phone,
       pg_get_functiondef(p.oid) LIKE '%nullif(trim(%'                  AS trims_blank
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname='public' AND p.proname='handle_new_user';

-- [1.15] ค่าช่องว่างล้วนที่หลุดเข้ามา (ต้องเป็น NULL ไม่ใช่ '') — คาดหวัง 0 แถว
SELECT id, email FROM public."Profile"
WHERE full_name = '' OR phone = '' OR bio = '' OR avatar_url = '';

-- [1.16] avatar_url ที่ชี้ไปนอก bucket avatars (ควรตรวจตาหลังมีข้อมูลจริง)
SELECT id, avatar_url FROM public."Profile"
WHERE avatar_url IS NOT NULL AND avatar_url NOT LIKE '%/storage/v1/object/public/avatars/%';
