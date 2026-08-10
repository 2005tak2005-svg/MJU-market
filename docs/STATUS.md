# STATUS.md — สถานะโปรเจกต์ + จุดเริ่ม session

> 📍 **เปิดไฟล์นี้เป็นไฟล์แรกของทุก session**
> อัปเดตล่าสุด: **2026-08-10** — **หยุดงาน L1 confirm-email ไว้ที่นี่ ย้ายไปทำ layer อื่นก่อน** ดู `DECISIONS.md` **D-20** เต็ม ๆ — สรุปสั้น: D-19 (ลิงก์ยืนยัน) ใช้ไม่ได้จริงเพราะ Microsoft Safe Links ของ tenant มหาลัยดึงลิงก์ไปสแกน/ใช้ token ทิ้งก่อนคนกด (ยืนยันด้วย WHOIS) → ปรับกลับไป OTP (D-18) → สร้างโค้ดฝั่ง FlutterFlow เสร็จครบ (`ConfirmEmail` page + `VerifyOtp`/`ResendSignupOtp`) → แต่ทดสอบจริงแล้วอีเมล OTP หายไปกลางทางไม่ถึงกล่องผู้รับเลย (ไม่ bounce ไม่ junk ไม่ quarantine — เข้าข่าย Microsoft Zero-hour Auto Purge) เป็นปัญหา deliverability ฝั่ง tenant ที่แก้จาก Supabase/FlutterFlow config ไม่ได้ตรง ๆ **L1 ฝั่ง FlutterFlow ค้างที่ 🟨 ต่อไป** โค้ด OTP flow พร้อมใช้แต่ยังไม่เคยเทส end-to-end สำเร็จสักครั้ง

> 🔴 **บทเรียนของวันนี้ (2026-08-10):** "ส่งอีเมลสำเร็จ" (SMTP ตอบ 200/250 OK) **ไม่ใช่หลักฐานว่าอีเมลถึงกล่องผู้รับ** — ต้องเช็คที่กล่องจริงเสมอ (Inbox/Junk/Quarantine/bounce ทั้ง 4 จุด) ก่อนสรุปว่า flow ทำงาน โดยเฉพาะเมื่อผู้รับอยู่หลัง Microsoft 365 Defender ที่มีทั้ง Safe Links (ดึงลิงก์ไปสแกนก่อนคนกด) และ ZAP (ลบเมลทิ้งย้อนหลังแบบเงียบ ๆ หลัง accept ไปแล้ว) — สองกลไกนี้ไม่ทิ้งร่องรอยฝั่งเราเลย ต้องไล่เช็คทีละจุดจริง ๆ ถึงจะเจอ

> 🔴 **บทเรียนของ 2026-08-09:** ระวังการ "เชื่อว่าปิดแล้ว" จากสิ่งที่ทดสอบผ่าน AI vision agent (Test Pilot) หรือ proto ที่ `inspect` เห็น — ทั้งคู่เคยดูเหมือนถูกทั้งที่โค้ด Dart จริงที่ generate ออกมาผิด (PT-09) ต้องเปิด `generated_code/` ดูโค้ดจริงเสมอก่อนเชื่อว่า action ทำงานถูก และ evidence ที่เชื่อถือได้ที่สุดคือ query ตรงจาก DB (เช่น `auth.users.last_sign_in_at`) ไม่ใช่รายงานจากคนอื่นหรือ AI agent

---

## 🔥 คิวถัดไป (3 อันดับ)

0. **เริ่ม L2 ใน v2** → AddProduct/MyPost/Inspect **ไม่มีอยู่ใน v2 เลย** (v1 archived ตาม D-16) ต้องสร้างใหม่ทั้งหมด — อ่าน `PATTERNS.md` PT-09/PT-10 **ก่อน** เขียน Action Flow เพราะจะเจอบั๊ก SDK ที่เจอตอน L1 ซ้ำแน่ (ดูคำเตือนใน `layers/L2-listings.md`) **ทดสอบ login ด้วย `mju6577778888@mju.ac.th`** (admin, เข้า Home/HomeAdmin ได้จริงอยู่แล้ว — ดูหมายเหตุ D-20 ด้านล่าง)
1. **เริ่ม L4 ใน v2** → เหมือนกัน ไม่มีหน้าแชทใน v2 เลย · อ่านคำเตือน PT-09/PT-10 ใน `layers/L4-chat.md` ก่อนเริ่ม โดยเฉพาะเรื่อง `chat_summary.member_names`
2. **🟡 หยุดไว้ — L1 confirm-email (D-20)** ไม่ใช่คิวด่วน แต่ยังไม่ปิด — ดู `layers/L1-auth-profile.md` หัวข้อ "งานค้าง — Confirm Email" และ `DECISIONS.md` **D-20** ก่อนแตะเรื่องนี้ต่อ
   **ค้างอยู่ก่อนปิด L1 ฝั่ง FlutterFlow ได้เต็มตัว:** (1) **แก้ปัญหา email deliverability ก่อน** — OTP ไปไม่ถึงกล่องผู้รับ `@mju.ac.th` เลย (ไม่ bounce ไม่ junk ไม่ quarantine เข้าข่าย Microsoft ZAP) ยังไม่ได้ลองปิด custom SMTP กลับไปใช้ default mailer เพื่อแยกว่าปัญหาอยู่ที่ Gmail relay หรือทั้ง tenant, (2) หลังแก้ deliverability แล้วค่อย **คลิกทดสอบจริงบนแอป** ทั้งเส้น (สมัคร → กรอก OTP → login → เข้า Home/HomeAdmin ไม่เด้งกลับ ระวัง PT-11), (3) ทดสอบเคส login ด้วยบัญชีที่ยังไม่ยืนยัน (ต้องสร้างบัญชีทดสอบใหม่ — บัญชีเดิม `mju6500000099@mju.ac.th` ถูกลบไปแล้ว 2026-08-10 พร้อมบัญชีทดสอบเก่าอีก 3 บัญชี), (4) ล้างบัญชีทดสอบ `mju6577778888@mju.ac.th` แล้วเทสสมัคร+ยืนยัน+login ใหม่ผ่าน flow จริงทั้งเส้น

---

## สถานะ 8 Layers

| L | ชื่อ | Supabase | FlutterFlow | หมายเหตุ |
|---|---|---|---|---|
| 1 | Auth & User Profiles | ✅ **ปิดแล้ว** | 🟨 **Login/SignUp/Home/HomeAdmin ทำงานจริง เหลือ Confirm Email flow (D-20) — หยุดไว้ชั่วคราว** | `full_name`/`phone`/role-routing ยืนยันผ่านแอปจริงครบ 2026-08-09 · Edit Profile ยังไม่สร้าง · OTP flow สร้างโค้ดเสร็จแต่ติด email deliverability (ดู D-20) |
| 2 | Product Listings + Storage | 🟨 **ครบแล้ว เหลือยืนยันการอัปจริง** | ⬜ **ยังไม่เริ่มใน v2** | seed `CAT` 12 หมวด · schema/RLS/view/realtime · bucket + 4 policy + CHECK 3 รูป · 🔴 อ่าน `PATTERNS.md` PT-09/PT-10 ก่อนเริ่ม |
| 3 | Browse / Search / Filter | ⬜ | ⬜ | ใช้ view เดิม ไม่มีตารางใหม่ |
| 4 | Chat & Messaging | 🟨 **schema เสร็จ แต่ยังไม่เคยตรวจ** | ⬜ ยังไม่เริ่มใน v2 | RLS เป็น allow-all ชั่วคราว · 🔴 อ่าน `PATTERNS.md` PT-09/PT-10 ก่อนเริ่ม · ดู 🔴 ด้านล่าง |
| 5 | Transaction & Status | ⬜ ยังไม่มีตาราง `transactions` | ⬜ | |
| 6 | Notifications | ⬜ ยังไม่มีตาราง | ⬜ | |
| 7 | Reviews & Reports | 🟨 `reports` มีแล้ว (ไม่มี policy) / `reviews` ยังไม่มี | ⬜ | |
| 8 | Admin Dashboard | ⬜ | ⬜ | |

✅ เสร็จ · 🟨 กำลังทำ · ⬜ ยังไม่เริ่ม

> 🔄 **2026-08-09 — รีเซ็ตโปรเจกต์ FlutterFlow (D-16):** คอลัมน์ "FlutterFlow" ของทุก layer ด้านบนคือสถานะใน **v2** (`m-j-u-market-v2-0xhjhg`) เท่านั้น — งานฝั่ง FlutterFlow ของ v1 (โปรเจกต์เก่า ตอนนี้ชื่อ "MJU-market-v1-archive") **ไม่นับรวมแล้ว** ต่อให้เคยทำไว้ก็ตาม

> 🔴 **กฎการให้ ✅ (ใช้กับตัวเราเองด้วย): "ตารางว่าง 0 แถว = ยังไม่ PASS"**
> เราตั้งกฎนี้ไว้ตอนตรวจ DB แล้วดันให้ ✅ ตัวเองทั้งที่เส้นทางจริงยังไม่เคยรัน — ลด L1/L4 กลับเป็น 🟨 เมื่อ 2026-08-08

**L1 — ✅ ปิดฝั่ง Supabase แล้ว 2026-08-09** — สมัครผ่าน FlutterFlow Sign Up จริง (`mju6577778888@mju.ac.th`) ได้ `full_name`/`phone`/`student_id`/`role` ครบทุกช่อง ไม่มี NULL
**FlutterFlow ยังไม่ปิด 🟨 — หยุดไว้ที่นี่ 2026-08-10 (D-20)** — Login/SignUp/Home/HomeAdmin ทำงานถูกต้องและยืนยันด้วย `auth.users.last_sign_in_at` จริงทั้ง user/admin path แล้ว **Confirm Email flow เปลี่ยนจากลิงก์ (D-19) เป็น OTP (D-20) เพราะ Microsoft Safe Links ดึงลิงก์ไปใช้ token ทิ้งก่อนคนกด** — โค้ด OTP (หน้า `ConfirmEmail` + custom action `VerifyOtp`/`ResendSignupOtp`) สร้างเสร็จและยืนยันจาก generated code จริงแล้วว่าตรงตามที่ตั้งใจ **แต่ทดสอบจริงแล้วอีเมล OTP ไปไม่ถึงกล่องผู้รับเลย** (ไม่ bounce ไม่ junk ไม่ quarantine — เข้าข่าย Microsoft Zero-hour Auto Purge) เป็นปัญหา deliverability ฝั่ง tenant มหาลัย ไม่ใช่บั๊กโค้ด — รายละเอียดเต็มดู `DECISIONS.md` **D-20** ตัดสินใจหยุดตรงนี้ไปทำ layer อื่นก่อน

**L4 — ทำไมยังไม่ใช่ ✅** — `chat_summary.member_names` **ยังไม่เคยตรวจว่าไม่เป็น NULL** เพราะ `chat` / `chat_user` / `chat_message` ยังว่าง 0 แถวทั้งหมด
view ที่ join `public_profiles` ถูกพิสูจน์แล้วแค่กับ `public_profiles` ตรง ๆ (V-04) **ยังไม่ได้พิสูจน์ผ่าน `chat_summary`** ซึ่งเป็นตัวที่บั๊ก NULL เคยเกิดจริง
→ ปิด L4 ฝั่ง Supabase ได้ต่อเมื่อ **สร้างห้องแชท 1 ห้อง สมาชิก 2 คน แล้ว SELECT `chat_summary` ในฐานะ user ธรรมดา เห็น `member_names` ครบ ไม่มี NULL**

**L2 — ทำไมยังไม่ใช่ ✅** — bucket + policy + CHECK ครบและทดสอบด้วย user ธรรมดาผ่านแล้ว (`VERIFICATION.md` V-08) แต่ `storage.objects` ยังมี **0 object**
`file_size_limit` (5 MB) กับ `allowed_mime_types` บังคับที่ **Storage API ไม่ใช่ที่ Postgres** — INSERT เข้า `storage.objects` ตรง ๆ ข้ามด่านนี้ไปเลย จึงทดสอบจาก DB แทนไม่ได้
→ ปิดได้ต่อเมื่อ **อัปไฟล์จริงผ่านแอป** แล้วเห็นว่าไฟล์เกิน 5 MB / ไฟล์ผิดชนิดถูกตีกลับ และรูปเปิดดูได้ผ่าน public URL

---

## ❓ คำถามที่ยังไม่ตัดสินใจ (รวมทุก layer)

**Layer 1**
- จะทำ role-based redirect ซ้ำที่หน้า Splash/Initial (กรณี auto-login) ด้วยไหม
- ~~รูปแบบอีเมลจริงของแม่โจ้เป็นยังไง~~ → **ตกไป 2026-08-08** pete ยืนยัน `mju<10หลัก>@mju.ac.th` ตรงกับ constraint เดิม ปิดใน **D-10**
- `handle_new_user()` ยังไม่มี `ON CONFLICT` — ถ้าแถวใน `"Profile"` ซ้ำจะ error ทั้งรายการ ต้องกันไหม
- ~~จะทำ server-side validate โดเมน (P-02) ไหม~~ → **ตกไป apply แล้วและทดสอบผ่านแล้ว**

**🔴 รอ pete ตอบ**

1. ~~D-17 — Confirm Email เปิดอยู่จริง แต่ยังไม่เลือกทางรับมือ~~ → ✅ ตอบแล้ว 2026-08-09 เลือกทางเลือก (ก) สร้าง flow ยืนยันอีเมลจริง — ดู `DECISIONS.md` **D-17**
   ~~D-18 — ตรวจ Site URL/Redirect URL แล้ว ยังไม่เลือกรูปแบบ flow~~ → ✅ ตอบแล้ว 2026-08-09 เลือกทางเลือก (3) OTP 6 หลักแทนลิงก์ — ดู `DECISIONS.md` **D-18**
   ~~D-19 — ยกเลิก OTP กลับไปใช้หน้าเว็บกลาง~~ → ทำเสร็จแต่**ใช้งานจริงไม่ได้** เพราะ Microsoft Safe Links — ดู `DECISIONS.md` **D-19**
   **D-20 — กลับไป OTP อีกครั้ง สร้างเสร็จแล้ว แต่ติด email deliverability ฝั่ง tenant → หยุดไว้ 2026-08-10** ดู `DECISIONS.md` **D-20** · ไม่ใช่คำถามค้างที่รอ pete ตอบแล้ว เป็นบล็อกทางเทคนิคที่ต้องแก้ deliverability ก่อนถึงจะไปต่อได้
2. **จะรับข้อเสนอ P-11 / P-12 ไหม** — unique index บน `lower(email)` และระบบเก็บกวาดไฟล์กำพร้า ทั้งคู่เป็นข้อเสนอของ Claude ที่ยังไม่ตอบรับ อยู่ใน `PROPOSED_SQL.md`

~~เปิด Confirm email อยู่ไหม~~ → ✅ ตอบแล้ว 2026-08-09 (เปิดอยู่) ย้ายเป็นข้อ 1 ด้านบน
~~จะติดตั้ง FlutterFlow CLI ไหม~~ → ✅ ติดตั้งแล้ว ใช้งานได้เต็มรูปแบบ
~~ตั้งใครเป็น admin คนแรก~~ → ✅ ตั้งแล้ว 2026-08-09 (`mju6577778888@mju.ac.th`)

**Layer 2**
- จะเปิดให้ browse ก่อนล็อกอินไหม — ถ้าเอา ต้องเพิ่ม policy ให้ `anon` ทั้ง `"CAT"` และ `products` (ตอนนี้ `anon` เห็น `"CAT"` เป็น 0 แถว)
- จะบังคับ `category_id` ห้าม null ไหม
- ผู้ขายไม่ได้เปิดแอปตอน admin กด reject → รอ Layer 6 มาช่วย หรือปล่อยตามนี้

**Layer 3**
- FlutterFlow built-in filter พอไหม หรือต้องสร้าง RPC `search_products` (P-05) — รอทดสอบจริง

**Layer 4**
- FlutterFlow เปิด "Listen for realtime updates" บน **view** ได้จริงไหม (ต้องทดสอบ)
- FlutterFlow query builder รองรับ operator "array contains" บน `chat_summary.user_ids` ไหม ถ้าไม่ ต้องทำ RPC `get_my_chats(uid)`
- จะสร้าง trigger auto-update `chat.last_message` (P-04) หรือให้ Action Flow อัปเดต 2 ที่เอง

**Layer 5**
- ต้องการ `status` กี่แบบจริง ๆ, ต้องเก็บประวัติ transaction แยกไหม หรือใช้ `products.status` พอ

**Layer 6**
- Supabase table + Realtime พอไหม หรือต้องต่อ push จริง (FCM)
- 🔴 `notifications.ref_id` ร่างเป็น uuid แต่ `chat.id` เป็น bigint → อ้าง chat ไม่ได้ ต้องเลือก design ก่อน apply (P-07)

**Layer 7**
- รองรับรีพอร์ต "ผู้ใช้" ด้วยไหม (P-09)
- `reviews` ใช้ RLS allow-all หรือ restrictive

**Layer 8**
- ยังไม่ได้เริ่มคุยรายละเอียด

---

## 💣 หนี้ทางเทคนิคที่ต้องใช้คืนก่อน production

- [ ] `products` / `chat` / `chat_user` / `chat_message` เป็น **allow-all RLS** — เปลี่ยนเป็น restrictive ตาม `chat_user` membership
- [ ] `reports` เปิด RLS แต่ไม่มี policy = deny-all — ยังใช้งานไม่ได้เลย
- [ ] หน้า `Inspect` กันด้วย UI เท่านั้น ไม่ใช่ RLS — user ยิง API ตรงยัง approve สินค้าเองได้
- [ ] ไม่มีระบบกันกดปุ่มลบซ้ำ/popup ค้างใน reject flow (ยอมรับเป็น MVP)
- [ ] `"Profile".id` มี default `gen_random_uuid()` ทั้งที่เป็นคอลัมน์ FK — บั๊กแบบเดียวกับที่แก้ไปแล้วใน `reports` ควรถอด default ออก (ยังไม่ทำ)
- [ ] `reports.status` ไม่มี CHECK — ค่าที่ใช้ได้ยังไม่ตัดสินใจ ทำพร้อม P-10
- [ ] ข้อมูลทดสอบค้างอยู่ใน DB: user 4 คน + `full_name` ปลอม (`ทดสอบ นักศึกษาหนึ่ง/สอง/สาม`, `สมชาย ใจดี (บุคลากร)`) — ต้องล้างก่อน production
      (`bio`/`phone` **ไม่ได้ค้าง** — ดูหมายเหตุเรื่อง auto-rollback ใน `checks/_common.sql`)
- [ ] `"CAT"` ไม่มี UNIQUE บน `name` — seed ซ้ำได้ ถ้า L8 ให้ admin เพิ่มหมวดหมู่เองควรใส่
- [ ] **ไฟล์กำพร้าใน `avatars`** — เปลี่ยนรูปโปรไฟล์แล้วไฟล์เก่าไม่ถูกลบ และ `avatar_url` ชี้ URL ที่ไฟล์อาจไม่มีแล้ว (D-15) — แก้พร้อมข้อถัดไป
- [ ] **ไฟล์กำพร้าใน `product-images`** — อัปรูปแล้วไม่กดบันทึก หรือลบประกาศทีหลัง ไฟล์ยังค้างใน bucket ยังไม่มีระบบเก็บกวาด (ควรทำตอน L5 ที่มีการลบประกาศจริง — Edge Function หรือ trigger บน `DELETE products`)
- [ ] **รูปของประกาศ `pending`/`rejected` เปิดดูได้ถ้ารู้ URL** — ผลจากการเลือก public bucket (หนี้ที่รับไว้ใน `DECISIONS.md` D-12) · 🔴 อย่าเอา bucket นี้ไปเก็บของอ่อนไหว เช่น บัตรนักศึกษา/สลิปโอนเงิน
- [ ] **`Profile_email_key` เป็น unique ธรรมดา ไม่ใช่ index บน `lower(email)`** — ตอนนี้ trigger `lower()` ให้ก่อน insert จึงยังไม่มีปัญหา แต่ถ้ามีเส้นทางเขียนอื่นที่ไม่ผ่าน trigger จะสมัครซ้ำด้วยอีเมลคนละตัวพิมพ์ได้ (ตรวจด้วย `checks/L1.sql` [1.9])
- [x] ~~ชื่อหน้า/State ฝั่ง FlutterFlow ยังไม่เคยเทียบกับโปรเจกต์จริง~~ → **ปิดแล้วสำหรับ L1** 2026-08-09 (มี CLI แล้ว, ชื่อ v2 ยืนยันจริงหมดแล้วดู `layers/L1-auth-profile.md`) — **แต่ L2 ขึ้นไปยังไม่เคยตั้งชื่อใน v2 เลย** ต้องตรวจใหม่ทุก layer ที่เริ่ม
- [ ] **repo เป็น private แล้ว (D-13) แต่นั่นไม่ใช่การปิดช่องโหว่** — ของจริงที่ต้องปิดคือ 3 ข้อบนสุดของรายการนี้ อย่าให้ private กลายเป็นข้ออ้างเลื่อนออกไป
- [ ] 🔴 **บัญชีทดสอบ 2 บัญชีถูกแก้ credential ตรงด้วย SQL — ไม่ใช่สภาพที่ user จริงไปถึงได้ ห้ามใช้เทสอย่างอื่นโดยไม่รู้ตัว** (2026-08-09):
      - `mju6577778888@mju.ac.th` — `email_confirmed_at` ถูก patch ด้วย SQL ตรง ๆ (`UPDATE auth.users SET email_confirmed_at = now() ...`) เพื่อปลดล็อกเทส login หลังเจอ "Email not confirmed" — บัญชีนี้**ไม่เคยผ่านขั้นตอนยืนยันอีเมลจริงของ Supabase เลย** **ยังไม่ได้ล้าง** ณ 2026-08-09 แม้ D-17 จะสร้าง flow เสร็จแล้ว — เป็นงานค้างข้อสุดท้ายก่อนปิด L1 ดู `layers/L1-auth-profile.md`
      - `mju6512345678@mju.ac.th` — `encrypted_password` ถูกเขียนทับด้วย SQL (`crypt('TestPilot!2026', gen_salt('bf'))`) เพื่อให้มีรหัสผ่านที่รู้ค่าไว้เทส Test Pilot login — **รหัสผ่านเดิมของบัญชีนี้ (ถ้าเคยมีคนตั้งไว้) ใช้ไม่ได้แล้ว** และ `email_confirmed_at` ก็ถูกแตะด้วย (แม้จะเป็น no-op เพราะเดิมน่าจะ confirmed อยู่แล้วจากการสร้างผ่าน Dashboard)
      ทั้งสองบัญชีปลอดภัยสำหรับ**เทส auth/role routing ต่อ**เท่านั้น — **ห้ามใช้เทส "สมัครสมาชิกแล้วต้องยืนยันอีเมล" เพราะสภาพถูกลัดผ่านไปแล้ว**
      🔴 **บัญชีสดสำหรับเทส confirm-flow เดิม (`mju6500000099@mju.ac.th`) ถูกลบไปแล้ว 2026-08-10** พร้อมบัญชีทดสอบเก่าอีก 3 บัญชี (`mju6500000101@mju.ac.th`, `mju6606105382@mju.ac.th`, `mju6606105383@mju.ac.th`) — ลบเพื่อเคลียร์ข้อมูลค้างระหว่างเทส D-19/D-20 (รายละเอียด `DECISIONS.md` **D-20**) **ต้องสมัครบัญชีทดสอบใหม่เมื่อกลับมาแก้ confirm-email ต่อ** — ไม่มีบัญชีสดพร้อมใช้ ณ ตอนนี้

---

## 📋 แม่แบบเปิด session กับ Claude Code

```
[git pull ก่อนเสมอ]
Layer ที่ทำอยู่: [เช่น Layer 1 — trigger auto-insert Profile]
อ่านก่อน: CLAUDE.md → docs/STATUS.md → [ไฟล์ตามตาราง router ใน CLAUDE.md]
Supabase objects ที่เกี่ยวข้อง: [ชื่อ table/column/FK จริง — ดู docs/SCHEMA.md ห้ามพิมพ์จากความจำ]
FlutterFlow page/state ที่เกี่ยวข้อง: [ชื่อ Page, Page/App State, widget parameter]
สิ่งที่ต้องการ: [ระบุให้ชัด]
Error / screenshot Action Flow (ถ้ามี): [แนบ]
```

> ถ้ามี `flutterflow ai` (MCP) ให้สั่งใช้ `inspect` / `search` / `status` ดึงชื่อจริงมาก่อน แทนพิมพ์เอง

---

## 🔚 เช็คลิสต์ปิด session (ห้ามข้าม)

- [ ] `INBOX.md` ว่างแล้ว (ของที่ pete เขียนมาถูกกระจายเข้าที่หมดแล้ว)
- [ ] `SCHEMA.md` ตรงกับ DB จริง (สั่ง `db-verifier` ตรวจให้ก็ได้)
- [ ] SQL ที่ apply ไปแล้ว ย้ายออกจาก `PROPOSED_SQL.md` เข้า `SCHEMA.md` แล้ว
- [ ] ตาราง "สถานะ 8 Layers" ด้านบนอัปเดตแล้ว
- [ ] "คิวถัดไป" อัปเดตแล้ว
- [ ] ตัดสินใจใหม่ (ถ้ามี) บันทึกลง `DECISIONS.md` แล้ว
- [ ] doc-syncer รายงานว่าไม่มีไฟล์ไหนเกินเพดาน (หรือรับทราบที่เกินแล้ว)
- [ ] **`git add -A && git commit && git push`** — ไม่ push = เครื่องอื่นทำงานกับข้อมูลเก่า
