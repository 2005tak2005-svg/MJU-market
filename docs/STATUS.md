# STATUS.md — สถานะโปรเจกต์ + จุดเริ่ม session

> 📍 **เปิดไฟล์นี้เป็นไฟล์แรกของทุก session**
> อัปเดตล่าสุด: **2026-08-07** — ตรวจ `SCHEMA.md` กับ DB จริงครั้งแรก (เอกสารเดิมลงวันที่ 2026-08-02 ไม่เคย query จริงเลย)

> 🔴 **บทเรียนของวันนี้:** เอกสารเดิมเขียนว่า "ยังไม่มี trigger/function เลย" ทั้งที่ **P-01 กับ P-02 apply อยู่ใน DB มาตลอด**
> ต้นเหตุคือ `checks/_common.sql` [C7] กรองแค่ `nspname='public'` เลยมองไม่เห็นของใน schema `private` และ trigger บน `auth.users`
> → **ห้ามเชื่อเอกสารโดยไม่ query จริง** และ query ที่ใช้ตรวจก็ต้องตรวจด้วยว่าครอบคลุมจริงไหม

---

## 🔥 คิวถัดไป (3 อันดับ)

1. **สร้าง Storage bucket `product-images`** + policy → ปลดล็อกอัปโหลดรูปใน L2 (งานฝั่ง Supabase ชิ้นเดียวที่เหลือใน L1–L2)
2. **เริ่มหน้า FlutterFlow ของ L1** — Sign Up / Log In / Edit Profile (ฝั่ง Supabase ปิดครบแล้ว)
3. **ลงประกาศทดสอบ 1–2 ชิ้น** → ปลดล็อกการตรวจ `products_review_view` / `chat_summary` ว่า `seller_name` / `member_names` ไม่เป็น NULL ([C8] ที่ยังค้าง)

---

## สถานะ 8 Layers

| L | ชื่อ | Supabase | FlutterFlow | หมายเหตุ |
|---|---|---|---|---|
| 1 | Auth & User Profiles | ✅ **100%** | ⬜ ยังไม่สร้างหน้า | trigger + RLS ทดสอบกับ user จริง 4 คนผ่านครบ |
| 2 | Product Listings + Storage | 🟨 เหลือ Storage bucket | 🟨 approve/reject ปุ่มเริ่มทำแล้วบางส่วน | seed `CAT` 12 หมวดแล้ว · schema/RLS/view/realtime เสร็จ |
| 3 | Browse / Search / Filter | ⬜ | ⬜ | ใช้ view เดิม ไม่มีตารางใหม่ |
| 4 | Chat & Messaging | ✅ 100% | ⬜ ยังไม่เริ่ม | RLS เป็น allow-all ชั่วคราว |
| 5 | Transaction & Status | ⬜ ยังไม่มีตาราง `transactions` | ⬜ | |
| 6 | Notifications | ⬜ ยังไม่มีตาราง | ⬜ | |
| 7 | Reviews & Reports | 🟨 `reports` มีแล้ว (ไม่มี policy) / `reviews` ยังไม่มี | ⬜ | |
| 8 | Admin Dashboard | ⬜ | ⬜ | |

✅ เสร็จ · 🟨 กำลังทำ · ⬜ ยังไม่เริ่ม

---

## ❓ คำถามที่ยังไม่ตัดสินใจ (รวมทุก layer)

**Layer 1**
- จะทำ role-based redirect ซ้ำที่หน้า Splash/Initial (กรณี auto-login) ด้วยไหม
- 🔴 **รูปแบบอีเมลจริงของแม่โจ้เป็นยังไง** (pete กำลังเช็ค) — CHECK ปัจจุบันรับเฉพาะ `mju<10หลัก>@mju.ac.th` ถ้าของจริงไม่ตรง นักศึกษาจะไม่มี `student_id` เลยสักคน ดู **D-10**
- `handle_new_user()` ยังไม่มี `ON CONFLICT` — ถ้าแถวใน `"Profile"` ซ้ำจะ error ทั้งรายการ ต้องกันไหม
- ~~จะทำ server-side validate โดเมน (P-02) ไหม~~ → **ตกไป apply แล้วและทดสอบผ่านแล้ว**

**Layer 2**
- จะเปิดให้ browse ก่อนล็อกอินไหม — ถ้าเอา ต้องเพิ่ม policy ให้ `anon` ทั้ง `"CAT"` และ `products` (ตอนนี้ `anon` เห็น `"CAT"` เป็น 0 แถว)

**Layer 2**
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
- [ ] **`git add -A && git commit && git push`** — ไม่ push = เครื่องอื่นทำงานกับข้อมูลเก่า
