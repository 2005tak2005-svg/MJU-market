# VERIFICATION.md — บันทึกผลตรวจ/ผลทดสอบ (append-only)

> ไฟล์นี้เก็บ **ความจริงที่ผูกกับวันที่** — ผลทดสอบ, ผล advisor, จำนวนแถว, log ดิบ
> `SCHEMA.md` เก็บเฉพาะสิ่งที่ re-derive จาก catalog query ได้ทุกเมื่อ ของที่ "จริง ณ วันนั้น" อยู่ที่นี่
>
> **กฎ: append-only** — เรียงตามวันที่ ใหม่สุดอยู่**ล่างสุด** ห้ามลบ/ห้ามแก้ของเก่า
> ผลเก่าที่ล้าสมัยแล้วให้ **เขียนรายการใหม่ทับความหมาย** ไม่ใช่ลบรายการเดิม (จะได้เห็นว่าอะไรเปลี่ยนเมื่อไหร่)
> ผลที่นำไปสู่การ**ตัดสินใจ** ให้สรุปเหตุผลไว้ที่ `DECISIONS.md` แล้วลิงก์กลับมาที่รายการที่นี่

---

## 2026-08-07 — ตรวจ DB ทั้งชุดกับของจริง

รัน `checks/_common.sql` ครบทุกบล็อก บน project `MJU market` (`rooydbxgcsybyanwsewv`)

### V-01 · สถานะข้อมูลในตาราง

| ตาราง | แถว | หมายเหตุ |
|---|---|---|
| `auth.users` | 4 | ข้อมูลทดสอบ |
| `"Profile"` | 4 | ข้อมูลทดสอบ ตรงกับ `auth.users` ครบ (`users_without_profile = 0`) |
| `"CAT"` | 12 | **ข้อมูลจริง** ใช้งานได้ |
| `products` | 0 | |
| `chat` | 0 | |
| `chat_user` | 0 | |
| `chat_message` | 0 | |
| `reports` | 0 | |

**ผลที่ตามมา:** เช็ค "ห้ามมี NULL" ของ `products_review_view` และ `chat_summary` **ยังตรวจไม่ได้** — ต้องมีประกาศจริงและห้องแชทจริงก่อน

---

### V-02 · ทดสอบสมัครสมาชิกจริง 4 คน (ผ่าน Supabase Dashboard)

ทดสอบ trigger `on_auth_user_created` → `public.handle_new_user()`

| อีเมลที่สมัคร | ผล | `student_id` ที่ได้ |
|---|---|---|
| `mju6512345678@mju.ac.th` | ✅ สร้างสำเร็จ | `6512345678` |
| `mju6598765432@mju.ac.th` | ✅ สร้างสำเร็จ | `6598765432` |
| `somchai.j@mju.ac.th` (บุคลากร) | ✅ สร้างสำเร็จ | `NULL` |
| `MJU6511112222@mju.ac.th` (ตัวใหญ่) | ✅ สร้างสำเร็จ | `6511112222` |
| `test@gmail.com` | ❌ **ถูกปฏิเสธ** | – |

ทุกคนได้ `role = 'user'` และมีแถวใน `"Profile"` ครบ

**สิ่งที่ยืนยันได้จากชุดนี้:**

1. **บังคับโดเมน `@mju.ac.th` ทำงานจริง** — อีเมลนอกโดเมนสมัครไม่ผ่าน
2. **derive `student_id` จากอีเมลทำงานจริง** — FlutterFlow **ไม่ต้อง** Update Row ใส่ `student_id` เอง (เขียนทับจะชน CHECK `profile_student_id_matches_email`)
3. **เคสอีเมลตัวใหญ่ผ่าน** — Supabase normalize อีเมลเป็นตัวเล็กก่อนเก็บลง `auth.users` regex ใน trigger ที่ไม่มี `lower()` จึงไม่เป็นปัญหาจริง → ข้อกังวลข้อ 5 ใน `DECISIONS.md` D-10 **ตกไป**
4. **บุคลากรได้ `student_id = NULL` จริง** → ยืนยันผลข้างเคียงข้อ 1 ของ D-10 ว่าเกิดขึ้นจริง
5. **`full_name` เป็น NULL ทุกคน** เพราะ Dashboard > Add user ไม่มีช่องใส่ user metadata
   → ยืนยันว่าถ้า FlutterFlow ไม่ส่ง `full_name` ใน `raw_user_meta_data` ตอน Sign Up **ชื่อจะหายทั้งระบบจริง**

---

### V-03 · 🔴 P-02 ทำงาน แต่ error ที่ client ได้รับใช้ไม่ได้เลย

auth log ดิบจาก Supabase ตอนสมัครด้วย `test@gmail.com`:

```
POST /admin/users → 500  error_code: unexpected_failure
error: failed to close prepared statement: ERROR: current transaction is aborted,
       commands ignored until end of transaction block (SQLSTATE 25P02):
       ERROR: Only @mju.ac.th email addresses are allowed (SQLSTATE P0001)
```

ข้อความจริงของเราถูกห่อไว้ชั้นในสุด **ฝั่ง client เห็นแค่ `Failed to create user: {}`** — body ว่างเปล่า

**สาเหตุ:** `raise exception` ทำให้ transaction abort → GoTrue ปิด prepared statement ไม่ได้ → error จริงถูกกลบด้วย `25P02` แล้วส่งกลับเป็น 500 body เปล่า

> ⚠️ **ข้อสรุปที่ต้องเอาไปใช้:** FlutterFlow พึ่ง error message จาก server **ไม่ได้** ต้อง validate โดเมนฝั่ง client ก่อน submit เสมอ
> trigger เป็นแค่ตาข่ายกันพลาดชั้นสุดท้าย ไม่ใช่ชั้นที่คุยกับผู้ใช้

---

### V-04 · ทดสอบ RLS ด้วย user ธรรมดา (ไม่ใช่ admin)

ทดสอบเป็น `mju6598765432@mju.ac.th` (`role='user'`, ไม่ใช่เจ้าของข้อมูลที่ไปยุ่ง)
ท่าที่ใช้: `SET LOCAL ROLE authenticated` + ตั้ง `request.jwt.claims`

| ทดสอบ | คาดหวัง | ผลจริง |
|---|---|---|
| `SELECT` จาก `public_profiles` | เห็นชื่อทุกคน | ✅ 4 แถว **ไม่มี NULL** |
| `SELECT` จาก `"Profile"` ตรง ๆ | เห็นแค่ของตัวเอง | ✅ 1 แถว |
| `UPDATE role = 'admin'` ให้ตัวเอง | ถูกปฏิเสธ | ✅ `42501 new row violates row-level security policy` |
| `UPDATE student_id` ของตัวเอง | ถูกปฏิเสธ | ✅ `42501` |
| `UPDATE full_name` ของ**คนอื่น** | ไม่มีผล | ✅ 0 แถว (ตรวจซ้ำแล้วข้อมูลคนอื่นไม่ถูกแตะ) |
| `UPDATE full_name`/`bio`/`phone` ของตัวเอง | สำเร็จ | ✅ |

> ⭐ **นี่คือการพิสูจน์ D-01** — `public_profiles` ให้ user ธรรมดาเห็นชื่อคนอื่นได้ โดย `email`/`student_id`/`role` ยังถูกซ่อน
> บั๊ก "ชื่อผู้ขายเป็น NULL เฉพาะ user ธรรมดา" **ยืนยันแล้วว่าไม่เกิดกับ `public_profiles`**
> (แต่ `products_review_view` / `chat_summary` ยังตรวจไม่ได้ เพราะยังไม่มีประกาศและห้องแชท — ดู V-01)

---

### V-05 · `"CAT"` เห็นกี่แถวในแต่ละ role

| role | เห็นกี่แถว |
|---|---|
| `postgres` | 12 |
| `authenticated` | **12** ✅ dropdown ใช้งานได้จริง |
| `anon` | **0** ⚠️ |

**`anon` เห็น 0 แถว** เพราะ policy `Allow all for authenticated users` ระบุ `TO authenticated` เท่านั้น

> ⚠️ หน้าไหนที่ให้เลือกหมวดหมู่**ก่อนล็อกอิน** (เช่น browse แบบไม่ต้องสมัคร) dropdown จะว่างเปล่า
> ถ้าจะรองรับ ต้องเพิ่ม policy SELECT ให้ `anon` ต่างหาก — **ยังไม่ทำ** เพราะยังไม่ตัดสินใจว่าจะให้ browse ก่อนล็อกอินไหม

---

### V-06 · ผล `get_advisors` (security + performance) เต็มชุด

#### 🔴 ERROR ที่ **ห้ามแก้** — อ่านก่อนจะไป "แก้ให้เขียว"

| lint | เป้า |
|---|---|
| `security_definer_view` | `public.public_profiles` |

> **นี่คือ D-01 ที่ตั้งใจทำแบบนี้ ไม่ใช่บั๊ก**
> `public_profiles` **ต้องไม่มี** `security_invoker` เพราะต้องรันด้วยสิทธิ์ owner เพื่อให้ user ธรรมดาเห็นชื่อ/รูปคนอื่นได้
> ถ้าใส่ `security_invoker = true` ตามที่ advisor แนะนำ → RLS ของ `"Profile"` จะกลับมาบังคับ → **`seller_name` / `member_names` เป็น NULL ทั้งระบบทันที** ซึ่งคือบั๊กที่โปรเจกต์นี้เคยเจอมาแล้ว
> view เปิดเผยแค่ `id` / `full_name` / `avatar_url` — `email` / `phone` / `student_id` / `role` ไม่ได้อยู่ในนั้น จึงยอมรับได้
> **ทดสอบยืนยันแล้ว** ที่ V-04 — user ธรรมดาเห็นครบ 4 คน ไม่มี NULL

#### ⚠️ WARN ที่ควรจัดการ

| lint | รายละเอียด |
|---|---|
| `anon_security_definer_function_executable` | `public.handle_new_user()` เรียกได้ผ่าน `/rest/v1/rpc/handle_new_user` โดย `anon` และ `authenticated` — ควร `REVOKE EXECUTE` เพราะเป็น trigger function ไม่ได้ตั้งใจให้เรียกตรง (เรียกตรงจะ error เพราะไม่มี `NEW` แต่ไม่ควรเปิดไว้ตั้งแต่แรก) |
| `auth_leaked_password_protection` | ปิดอยู่ — เปิดใน Dashboard > Auth ได้ ตรวจรหัสผ่านกับ HaveIBeenPwned |

#### ℹ️ INFO / ที่รู้อยู่แล้ว

- `rls_enabled_no_policy` → `reports` (ตั้งใจ รอ P-10)
- `unindexed_foreign_keys` **7 จุด** — `chat_message.chat_id`, `chat_message.user_id`, `chat_user.user_id`, `products.category_id`, `products.seller_id`, `reports.reported_product_id`, `reports.reporter_id`
  ยังไม่เร่ง เพราะข้อมูลยังน้อย แต่ `products.seller_id` กับ `chat_message.chat_id` จะเจ็บก่อนเพื่อนเมื่อข้อมูลโต
- `auth_rls_initplan` **2 policy** ของ `"Profile"` — `auth.uid()` ถูกประเมินใหม่ทุกแถว แก้โดยเปลี่ยนเป็น `(select auth.uid())`
- `multiple_permissive_policies` — `"Profile"` มี 2 policy ซ้อนกันสำหรับ SELECT/UPDATE (self + admin) เป็นผลจากดีไซน์ ยอมรับได้

---

## 2026-08-08 — re-derive `SCHEMA.md` จาก catalog

### V-07 · ยืนยันว่าทุกบรรทัดใน `SCHEMA.md` ตรงกับ catalog

รัน catalog query ชุดเต็ม (`pg_class` / `information_schema.columns` / `pg_constraint` / `pg_policies` / `pg_proc` / `pg_trigger` / `pg_publication_tables` / `storage.buckets`) แล้วเขียน `SCHEMA.md` ใหม่จากผลที่ได้ล้วน ๆ

**สิ่งที่พบว่าเอกสารเดิมคลาดเคลื่อน** (แก้ใน `SCHEMA.md` แล้ว):

| จุด | เอกสารเดิม | ของจริงจาก catalog |
|---|---|---|
| `products_review_view` | เขียน `AS ...` ทิ้งไว้ ไม่มีนิยาม | `LEFT JOIN "CAT"` + `LEFT JOIN public_profiles` — ดึง `pg_get_viewdef()` มาใส่ครบแล้ว |
| policy ของ `"Profile"` | เขียนว่า **restrictive** | ทั้ง 4 ตัวเป็น **PERMISSIVE** (`pg_policies.permissive`) |
| `products.seller_id` FK | เขียนแค่ `FK → "Profile".id` | มี `ON UPDATE CASCADE ON DELETE CASCADE` |
| `products` ลำดับคอลัมน์ | เรียงตามที่จำ | `ordinal_position` ข้าม 7 (มีคอลัมน์ที่ถูก drop ไปแล้ว) — ลำดับจริงคือ id, created_at, seller_id, title, description, price, status, image_urls, condition, contact_phone, moderation_status, category_id, rejection_reason |

**สิ่งที่ยืนยันว่า *ไม่* เปลี่ยนจาก 2026-08-07:** ตาราง 7 ตัว · view 4 ตัว · policy 9 ตัว · function 4 ตัว (`private.*` 3 + `public.handle_new_user`) · trigger `on_auth_user_created` (`tgenabled = 'O'`) · realtime 3 ตาราง · `"CAT"` 12 แถว id 1–12 · storage **0 bucket, 0 policy** ← เปลี่ยนแล้วใน V-08 ด้านล่าง

---

### V-08 · ทดสอบ Storage `product-images` + CHECK 3 รูป ทันทีหลัง apply

**ท่าทดสอบ:** `DO` block ที่ลอง INSERT จริง แล้วปิดท้ายด้วย `RAISE EXCEPTION` เพื่อ abort ทั้ง block
→ ได้ผลจริงจาก DB โดย **ไม่มีข้อมูลทดสอบค้าง** (ยืนยันหลังทดสอบ: `products` 0 แถว, `storage.objects` 0 แถว)

**ก. CHECK `products_image_urls_max_3`**

| ทดสอบ | คาดหวัง | ผลจริง |
|---|---|---|
| INSERT `image_urls` 3 รูป | ผ่าน | ✅ ผ่าน |
| INSERT `image_urls` 4 รูป | ถูกปฏิเสธ | ✅ ถูกปฏิเสธ (`check_violation`) |

**ข. Storage policy — ทดสอบในฐานะ `authenticated` ที่เป็น user ธรรมดา**

เป็น `mju6598765432@mju.ac.th` ด้วย `SET LOCAL ROLE authenticated` + `request.jwt.claims`

| ทดสอบ | คาดหวัง | ผลจริง |
|---|---|---|
| อัปเข้า `<uid ตัวเอง>/pic1.jpg` | สำเร็จ | ✅ สำเร็จ |
| อัปเข้า `<uid คนอื่น>/hack.jpg` | ถูกปฏิเสธ | ✅ ถูกบล็อก (`insufficient_privilege`) |

> ⚠️ **ยังไม่ได้ทดสอบ:** `file_size_limit` (5 MB) และ `allowed_mime_types` — สองอย่างนี้บังคับที่ **Storage API** ไม่ใช่ที่ Postgres การ INSERT เข้า `storage.objects` ตรง ๆ จึงข้ามไป ต้องอัปไฟล์จริงผ่าน FlutterFlow/REST ถึงจะยืนยันได้
> ⚠️ **ยังไม่ได้ทดสอบ:** การอ่านผ่าน public URL จริง และ flow อัปครบ 3 รูปแล้วผูกเข้าประกาศ

**สถานะ storage หลัง apply:** 1 bucket (`product-images`) · 4 policy บน `storage.objects` · 0 object

---

## 2026-08-08 (รอบสอง)

### V-09 · ทดสอบ trigger หลังแก้ regex + normalize อีเมล

ทดสอบทันทีหลัง apply 2 migration (`profile_email_domain_check`, `handle_new_user_normalize_email_and_anchor_regex`)
วิธี: `DO` block ที่ INSERT เข้า `auth.users` จริงทั้ง 4 เคส แล้ว `RAISE EXCEPTION` ปิดท้ายเพื่อ rollback ทั้งก้อน — **ได้ผลจริงโดยไม่ทิ้งข้อมูลค้าง**

| # | อินพุต | คาดหวัง | ผลจริง |
|---|---|---|---|
| 1 | `MJU6511119999@MJU.AC.TH` | normalize + derive ได้ | ✅ `email=mju6511119999@mju.ac.th` `student_id=6511119999` |
| 2 | `ajarn.somsri@mju.ac.th` (บุคลากร) | สมัครได้ `student_id` NULL | ✅ `student_id=NULL` |
| 3 | `hacker@evil.com@mju.ac.th` | ถูกบล็อก | ✅ ถูกบล็อก |
| 4 | `hacker@evil.com` | ถูกบล็อก | ✅ ถูกบล็อก |

🔴 **เคส 3 คือของที่ regex เดิมปล่อยผ่าน** — `'@mju\.ac\.th$'` เช็คแค่ท้ายสตริง อีเมลนี้ลงท้ายถูกจริงเลยผ่านด่านและได้ Profile ในระบบ (เหตุผลเต็ม: `DECISIONS.md` **D-10** หัวข้อช่องโหว่)

**ยืนยันไม่มีข้อมูลค้าง:** `auth.users` = 4 · `"Profile"` = 4 (เท่าเดิมก่อนทดสอบ)

**ยืนยันก่อน apply CHECK `profile_email_domain`:** 4 แถวเดิมไม่มีแถวไหนขัด (`would_violate = 0`, `null_emails = 0`, `not_lowercase = 0`) จึงเพิ่ม constraint ได้โดยไม่ต้องแก้ข้อมูลก่อน

> ⚠️ **ยังไม่ได้ทดสอบ:** เส้นทางสมัครจริงผ่าน GoTrue (`/auth/v1/signup`) หลังแก้ — ทดสอบนี้เขียนลง `auth.users` ตรง ๆ ซึ่งข้ามการ normalize ของ GoTrue ไป (จงใจ เพื่อดูว่า trigger เอาอยู่เอง) เส้นทางจริงยังต้องยืนยันตอนทำหน้า Sign Up

---

### V-10 · ทดสอบ `phone` ผ่าน meta data + bucket `avatars` ทันทีหลัง apply

2 migration: `handle_new_user_read_phone_from_meta_data`, `create_avatars_bucket_and_policies`
วิธีเดิม — `DO` block INSERT จริงแล้ว `RAISE EXCEPTION` ปิดท้ายเพื่อ rollback

| # | ทดสอบ | คาดหวัง | ผลจริง |
|---|---|---|---|
| 1 | meta data มี `full_name` + `phone` | เข้า `"Profile"` ทั้งคู่ | ✅ `full_name=ทดสอบ เบอร์` `phone=0812345678` |
| 2 | `full_name` เป็นช่องว่างล้วน `"   "`, ไม่ส่ง `phone` | ได้ `NULL` ทั้งคู่ ไม่ใช่ `''` | ✅ `full_name=NULL` `phone=NULL` |
| 3 | อัป avatar เข้า `<uid ตัวเอง>/` | สำเร็จ | ✅ อัปได้ |
| 4 | อัป avatar เข้า `<uid คนอื่น>/` | ถูกปฏิเสธ | ✅ ถูกบล็อก |

**ยืนยันไม่มีข้อมูลค้าง:** `auth.users` = 4 · `"Profile"` = 4 · `storage.objects` = 0

**สถานะ storage หลัง apply:** 2 bucket — `avatars` (public, 2 MB) · `product-images` (public, 5 MB) · **8 policy** บน `storage.objects`

> ⚠️ **ยังไม่ได้ทดสอบ:** `file_size_limit` / `allowed_mime_types` ของ `avatars` (บังคับที่ Storage API เหมือน `product-images` ดู V-08) และเส้นทางสมัครจริงผ่าน GoTrue ที่ส่ง meta data มาจาก FlutterFlow
> 🔴 **ยังไม่รู้:** โปรเจกต์เปิด **Confirm email** ไว้หรือเปล่า — เป็น setting ของ GoTrue ตรวจจาก DB ไม่ได้ ต้องเปิด Dashboard ดู ถ้าเปิดอยู่จะกระทบ PT-07 (ไม่มี session ให้ query `role` ทันทีหลังสมัคร)

---

## 2026-08-14

### V-11 · ทดสอบ `ProfileUser` + ผลข้างเคียงของการสลับ auth backend (D-21)

**ทดสอบผ่านแอปจริงโดย pete** (ไม่ใช่แค่ inspect) — ทุกข้อผ่าน:
- `ProfileUser` แสดง avatar/ชื่อ/อีเมลของ user ที่ล็อกอินถูกต้อง ไม่ crash (ก่อนหน้านี้ crash `Unexpected null value` ที่ `FutureBuilder`)
- เปลี่ยนชื่อ · เปลี่ยนรูปโปรไฟล์ · Log Out ออกจากระบบจริง
- `AllList` (Home) แตะแล้วเข้า `ProductDetails` พร้อมข้อมูลสินค้า
- คำทักทายหน้า `Home` โชว์อีเมล — **รับได้ ไม่ใช่บั๊ก** (ดู D-21)

**ยืนยันจาก DB ตรง ๆ หลังทดสอบ:**

| ตรวจ | ผล |
|---|---|
| `"Profile"` ทั้งหมด | 5 แถว · `full_name`/`email` **ไม่ NULL สักแถว** (0) |
| `"Profile".avatar_url` ที่ไม่ NULL | **1 แถว** → บันทึกรูปโปรไฟล์สำเร็จจริงครบเส้นทาง |
| `storage.objects` bucket `avatars` | **3 object** · path เป็น `<uid>/<ไฟล์>` **ตรงกับ `"Profile".id` ทั้ง 3 ไฟล์** |

🔴 **ข้อสรุปสำคัญ: path storage เป็น Supabase uid จริง = D-21 ทำงานถูกต้อง** — ยืนยันว่า `currentUserUid` ส่งค่าถูกไปถึง Storage แล้ว (ก่อน D-21 จะเป็น `''` ซึ่งผิด policy) **ปิดประเด็น upload path ในคิว regression ข้อ 0 ไปได้**

**ผลของการตั้ง `maxResolution` 512×512 + `imageQuality` 80 (PT-14 ข้อ 3):**
ไฟล์ก่อนแก้ **1470 KB** × 2 · ไฟล์หลังแก้ **42 KB** — เล็กลง ~35 เท่า (ก่อนแก้เจอ **413 Payload too large** เพราะ `avatars` จำกัด 2 MB)

⚠️ **3 object แต่ `avatar_url` ชี้แค่ 1** → เหลือ **ไฟล์กำพร้า 2 ไฟล์** ตรงกับหนี้ที่รับไว้แล้วใน **D-15** (เปลี่ยนรูปแล้วไฟล์เก่าไม่ถูกลบ) ไม่ใช่เคสใหม่

**ยังไม่ได้ทดสอบหลัง D-21:** สมัครใหม่ · OTP · role-routing (user→`Home` / admin→`HomeAdmin`) · อัปรูปใน `addproduct`

---

## 2026-08-21 — ระบบ Ban User (D-52) impersonation test

รันทุกเคสในธุรกรรมที่ `ROLLBACK` สวมบทบาทจริงผ่าน `SET LOCAL ROLE authenticated` + `request.jwt.claims` (ไม่ใช่ role `postgres`) ครอบ 3 บทบาท: แอดมิน · user ปกติ · user ที่ถูกแบน

### V-12 · Phase A — บังคับที่ RLS

| เคส | ผล |
|---|---|
| ผู้ถูกแบน: ลงประกาศ / ส่งรายงาน / แชทห้องที่ไม่มีแอดมิน | `42501` ทั้ง 3 |
| ผู้ถูกแบน: แชทห้องที่มีแอดมิน + เปิดแชทกับแอดมินใหม่ | สำเร็จ (ช่องอุทธรณ์) |
| ผู้ถูกแบน: เปิดแชทใหม่กับผู้ขาย | blocked |
| ผู้ถูกแบน: `UPDATE "Profile" SET is_banned=false` | blocked ที่ trigger |
| ผู้ถูกแบน: เห็นประกาศคนอื่น / ประกาศตัวเอง | 5 แถว / 4 แถว ครบ (soft ban) |
| user ปกติ: เห็นประกาศของผู้ถูกแบน | 0 แถว (แอดมินเห็นครบ 4) |
| user ปกติ: `admin_users_view` | 0 แถว (แอดมินเห็น 8, `can_ban`=6) |
| แบนซ้ำครั้งที่ 2 | ไม่เกิดแจ้งเตือนซ้ำ (idempotent) |
| ปลดแบน | 4 คอลัมน์ล้าง NULL + ประกาศกลับมาโผล่ |
| regression: user ปกติ/แอดมิน ทำงานเดิมทุกอย่าง | ผ่านครบ (approve/insert noti/อ่าน view/self-escalate role ยัง blocked) |

### V-13 · Phase B–D — ปลายทางที่ UI ใช้จริง

| เคส | ผล |
|---|---|
| `dart analyze` custom action 3 ตัว (`adminBanUser`/`adminUnbanUser`/`getMyBanReason`) แบบ standalone | `No issues found` |
| `generated_code/`: ปุ่ม Ban/Unban เป็น `if (...)` conditional จริง | ยืนยันแล้ว ไม่ใช่ static |
| `generated_code/`: `ManageUsersList` มี `Expanded` ห่อ (ไม่เจอ D-40) | ยืนยันแล้ว |
| `generated_code/`: `ReportDetail` ของเดิมครบ 11 Text ไม่หาย | ยืนยันแล้ว |
| ผู้ถูกแบน: อ่าน `ban_reason` ตัวเอง (ที่ popup ใช้) | ได้ค่าจริง |
| ผู้ถูกแบน: เห็นแจ้งเตือน `account_banned` | 1 รายการ |
| สคริปต์ `dsl/edit.dart` rerun-safe หลัง retire ครบ (PT-21) | push เปล่าซ้ำผ่าน |

**ยังไม่ทำ:** ทดสอบผ่านแอปจริงโดย pete (คิวอยู่ `STATUS.md` ข้อ 0)
