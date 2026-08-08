# STATUS.md — สถานะโปรเจกต์ + จุดเริ่ม session

> 📍 **เปิดไฟล์นี้เป็นไฟล์แรกของทุก session**
> อัปเดตล่าสุด: **2026-08-08** — ลีน `SCHEMA.md` ให้ re-derive จาก catalog ได้ทุกบรรทัด (ผลตรวจย้ายไป `VERIFICATION.md`) · ลดสถานะ L1/L4 ที่ให้ ✅ เกินจริง · **สร้าง Storage bucket `product-images` + policy + CHECK จำกัด 3 รูป** · **ปิด D-10 (ยืนยันรูปแบบอีเมลจริง) + อุด regex ที่ไม่ anchor + normalize อีเมล** · **repo เป็น private (D-13)** · **เตรียม L1 ให้พร้อมลงมือ: `phone` ผ่าน meta data (D-14) + bucket `avatars` (D-15)**

> 🔴 **บทเรียนของวันนี้:** เอกสารเดิมเขียนว่า "ยังไม่มี trigger/function เลย" ทั้งที่ **P-01 กับ P-02 apply อยู่ใน DB มาตลอด**
> ต้นเหตุคือ `checks/_common.sql` [C7] กรองแค่ `nspname='public'` เลยมองไม่เห็นของใน schema `private` และ trigger บน `auth.users`
> → **ห้ามเชื่อเอกสารโดยไม่ query จริง** และ query ที่ใช้ตรวจก็ต้องตรวจด้วยว่าครอบคลุมจริงไหม

---

## 🔥 คิวถัดไป (3 อันดับ)

0. **🚧 เคลียร์ 4 ข้อก่อนแตะ FlutterFlow** → ตาราง "เคลียร์ก่อนกด" ใน `layers/L1-auth-profile.md` — ที่สำคัญสุดคือ **เปิด Confirm email อยู่หรือเปล่า** (ถ้าเปิด PT-07 ใช้ไม่ได้ทันทีหลังสมัคร) และ **FlutterFlow CLI/MCP ยังไม่มีในเครื่อง**
1. **ทำหน้า Sign Up ใน FlutterFlow ที่ส่ง `full_name` + `phone` ใน user meta data** → เป็นสิ่งเดียวที่ปิด L1 ฝั่ง Supabase ได้ (ตอนนี้เส้นทางนั้นยังไม่เคยรันสำเร็จ) · ต้องสมัคร**บัญชีใหม่** เท่านั้น บัญชีเดิม 4 คนมี `full_name` เติมมือ
2. **ทำ upload รูปในหน้า `AddProduct` ตาม PT-08** → ปลดล็อกการยืนยัน Storage ที่เหลือ (ขนาดไฟล์ / mime / public URL) และได้ประกาศจริงไปด้วย
3. **ลงประกาศทดสอบ 1–2 ชิ้น + สร้างห้องแชท 1 ห้อง 2 คน** → ปลดล็อกการตรวจ `products_review_view` / `chat_summary` ว่า `seller_name` / `member_names` ไม่เป็น NULL ([C8] ที่ยังค้าง) — เป็นสิ่งเดียวที่ปิด L4 ฝั่ง Supabase ได้

---

## สถานะ 8 Layers

| L | ชื่อ | Supabase | FlutterFlow | หมายเหตุ |
|---|---|---|---|---|
| 1 | Auth & User Profiles | 🟨 **เหลือเส้นทาง `full_name`/`phone` ผ่านแอปจริง** | ⬜ ยังไม่สร้างหน้า | RLS + derive `student_id` ทดสอบผ่านครบ · trigger อ่าน `phone` แล้ว (D-14) · bucket `avatars` พร้อม (D-15) · แต่ดู 🔴 ด้านล่าง |
| 2 | Product Listings + Storage | 🟨 **ครบแล้ว เหลือยืนยันการอัปจริง** | 🟨 approve/reject ปุ่มเริ่มทำแล้วบางส่วน | seed `CAT` 12 หมวด · schema/RLS/view/realtime · bucket + 4 policy + CHECK 3 รูป |
| 3 | Browse / Search / Filter | ⬜ | ⬜ | ใช้ view เดิม ไม่มีตารางใหม่ |
| 4 | Chat & Messaging | 🟨 **schema เสร็จ แต่ยังไม่เคยตรวจ** | ⬜ ยังไม่เริ่ม | RLS เป็น allow-all ชั่วคราว · ดู 🔴 ด้านล่าง |
| 5 | Transaction & Status | ⬜ ยังไม่มีตาราง `transactions` | ⬜ | |
| 6 | Notifications | ⬜ ยังไม่มีตาราง | ⬜ | |
| 7 | Reviews & Reports | 🟨 `reports` มีแล้ว (ไม่มี policy) / `reviews` ยังไม่มี | ⬜ | |
| 8 | Admin Dashboard | ⬜ | ⬜ | |

✅ เสร็จ · 🟨 กำลังทำ · ⬜ ยังไม่เริ่ม

> 🔴 **กฎการให้ ✅ (ใช้กับตัวเราเองด้วย): "ตารางว่าง 0 แถว = ยังไม่ PASS"**
> เราตั้งกฎนี้ไว้ตอนตรวจ DB แล้วดันให้ ✅ ตัวเองทั้งที่เส้นทางจริงยังไม่เคยรัน — ลด L1/L4 กลับเป็น 🟨 เมื่อ 2026-08-08

**L1 — ทำไมยังไม่ใช่ ✅** — เส้นทาง `full_name` ของ `handle_new_user()` **ยังไม่เคยรันสำเร็จเลยสักครั้ง**
`insert ... new.raw_user_meta_data->>'full_name'` ไม่เคยได้ค่าที่ไม่ใช่ NULL เพราะสมัคร 4 คนผ่าน Dashboard > Add user ซึ่ง**ไม่มีช่องใส่ user metadata** ชื่อที่เห็นในตารางตอนนี้เป็นค่าที่เติมมือทีหลัง ไม่ใช่ผลจาก trigger
→ ปิด L1 ฝั่ง Supabase ได้ต่อเมื่อ **สมัครผ่าน FlutterFlow Sign Up ที่ส่ง `full_name` ใน meta data แล้วเห็นชื่อโผล่ใน `"Profile"` เอง** (ผลตรวจที่ทำให้รู้: `VERIFICATION.md` V-02 ข้อ 5)

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

**🔴 รอ pete ตอบ — ค้างจากรอบวางแผน 2026-08-08 (บล็อกการเริ่ม L1 ฝั่ง FlutterFlow)**

1. **เปิด Confirm email อยู่ไหม** — ตรวจจาก DB ไม่ได้ ต้องเปิด Dashboard → Auth → Email ดู · ถ้าเปิดอยู่ **PT-07 ใช้ทันทีหลังสมัครไม่ได้** เพราะยังไม่มี session ให้ query `role` · ทางรับมือยังไม่ตกลง ดู `layers/L1-auth-profile.md` ❓ ค้างอยู่
2. **จะติดตั้ง FlutterFlow CLI + `FLUTTERFLOW_API_TOKEN` ไหม** — ตอนนี้ไม่มีในเครื่อง Claude จึง inspect ชื่อจริงในโปรเจกต์ไม่ได้ กฎข้อ 3 ตรวจได้แค่ฝั่ง Supabase และ `ui-checker` ยังใช้ไม่ได้ · ถ้าไม่ติดตั้ง Claude ทำได้แค่เขียนสเปคให้ pete กดเอง 🔴 token ห้าม commit
3. **ตั้งใครเป็น admin คนแรก** — ยังไม่มี admin ในระบบเลย (0 คน) ต้องมีก่อนถึงเทสสาขา `role == "admin"` ของ PT-07 ได้ (ตั้งด้วยมือตาม **D-02**)
4. **จะรับข้อเสนอ P-11 / P-12 ไหม** — unique index บน `lower(email)` และระบบเก็บกวาดไฟล์กำพร้า ทั้งคู่เป็นข้อเสนอของ Claude ที่ยังไม่ตอบรับ อยู่ใน `PROPOSED_SQL.md`

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
- [ ] **ชื่อหน้า/State ฝั่ง FlutterFlow ยังไม่เคยเทียบกับโปรเจกต์จริงเลยสักตัว** — ทำเครื่องหมาย **[ยังไม่ยืนยันชื่อ]** ไว้ใน `layers/L1-auth-profile.md` แล้ว · กฎข้อ 3 ยังตรวจได้แค่ครึ่งเดียวจนกว่าจะมี CLI/token
- [ ] **repo เป็น private แล้ว (D-13) แต่นั่นไม่ใช่การปิดช่องโหว่** — ของจริงที่ต้องปิดคือ 3 ข้อบนสุดของรายการนี้ อย่าให้ private กลายเป็นข้ออ้างเลื่อนออกไป

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
