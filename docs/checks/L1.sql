-- L1 — Authentication & User Profiles
-- รัน _common.sql ก่อน แล้วค่อยรันทีละบล็อกด้านล่าง

-- [1.1] คอลัมน์ของ "Profile"
--       คาดหวังครบ: id, created_at, email, full_name, avatar_url, role, student_id, phone
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='public' AND table_name='Profile' ORDER BY ordinal_position;

-- [1.2] constraints ของ "Profile"
--       คาดหวัง: profile_student_id_unique, profile_student_id_format,
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

-- [1.7] อีเมลนอกโดเมน @mju.ac.th ที่หลุดเข้ามาแล้ว
SELECT id, email FROM auth.users WHERE email NOT ILIKE '%@mju.ac.th';
