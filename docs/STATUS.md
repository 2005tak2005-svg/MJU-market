# STATUS.md — สถานะโปรเจกต์ + จุดเริ่ม session

> 📍 **เปิดไฟล์นี้เป็นไฟล์แรกของทุก session**
> อัปเดตล่าสุด: **2026-08-15**
> ✅ **D-24–D-27 เสร็จและทดสอบผ่านแอปจริงโดย pete แล้วทั้งหมด** (ไม่ใช่แค่ยืนยันจาก `generated_code/` อีกต่อไป):
> reject-flow root cause (RLS select-back) แก้แล้ว + `reports` ใช้งานจริงทั้ง user-report/admin-log/admin mailbox (D-24) · แก้บั๊ก `addproduct` แฟลชไป Login หลังลงขายสำเร็จ + `Notifications`→`ProductDetails` link + ปุ่ม "ติดต่อแอดมิน" mock (D-26) · แก้ `ensureReplaced` เก่าทับปุ่มติดต่อแอดมินเงียบ ๆ (D-27, กฎใหม่ดู `PATTERNS.md` **PT-21**)
> ก่อนหน้า 2026-08-14: auth backend = Supabase (D-21) · L8 `HomeAdmin` approve/reject + `notifications` table + `Notifications` page + bell icon (D-22/D-23)
> **L1 confirm-email ยังหยุดที่ D-20** (OTP สร้างเสร็จ ติด email deliverability ฝั่ง tenant — ไม่ใช่คิวด่วน)

---

## 🔥 คิวถัดไป (3 อันดับ)

1. **regression ที่เหลือหลังสลับ auth backend (D-21)** — สมัครใหม่/OTP/role-routing/`ProfileUser` ผ่านแล้ว (V-11) เหลือ: กรอกเบอร์ว่างล้วนตอนสมัคร → `phone` ต้องเป็น `NULL` ไม่ใช่ `''` (ยังไม่เทสผ่าน UI จริง), อัปรูปโปรไฟล์เข้า `avatars` แล้วเปิด public URL จริงดูว่ารูปขึ้น
2. **เริ่ม L4 (chat) ใน v2** — ยังไม่มีหน้าแชทเลย อ่าน `PATTERNS.md` PT-02/PT-09/PT-10 ก่อนเริ่ม โดยเฉพาะ `chat_summary.member_names`
3. **สร้าง `MyPost`/`Inspect` ใน v2** (มีแค่ใน v1 archived) — อ่าน PT-09/PT-10/PT-12/PT-14 ก่อนเขียน Action Flow ทดสอบด้วย `mju6577778888@mju.ac.th` (admin)

🟡 **ไม่ใช่คิวด่วนแต่ยังไม่ปิด — L1 confirm-email (D-20)** บล็อกอยู่ที่ email deliverability ฝั่ง tenant มหาลัย ดู `layers/L1-auth-profile.md` หัวข้อ "งานค้าง — Confirm Email"

---

## สถานะ 8 Layers

| L | ชื่อ | Supabase | FlutterFlow | หมายเหตุ |
|---|---|---|---|---|
| 1 | Auth & User Profiles | ✅ ปิดแล้ว | 🟨 Login/SignUp/Home/HomeAdmin/`ProfileUser` ทำงานจริง เหลือ Confirm Email (D-20) | auth backend = Supabase แล้ว (D-21) · OTP ติด email deliverability |
| 2 | Product Listings + Storage | 🟨 อัปจริงผ่านแอปแล้ว เหลือเทส reject >5MB/ผิดชนิด | 🟨 `addproduct` insert ผ่านแอปจริง + แก้บั๊กแฟลชไป Login (D-26) | seed `CAT` 12 หมวด · bucket+policy+CHECK 3 รูป · อ่าน PT-09/10/12 ก่อนเริ่ม |
| 3 | Browse / Search / Filter | ⬜ | 🟨 `AllList`+`ProductDetails` ทำแล้ว | ผูก `products_review_view` ยังไม่มี search/filter รูปยังเป็น placeholder |
| 4 | Chat & Messaging | 🟨 schema เสร็จ ยังไม่เคยตรวจ | ⬜ ยังไม่เริ่มใน v2 | RLS allow-all ชั่วคราว · อ่าน PT-09/10 |
| 5 | Transaction & Status | ⬜ ไม่มีตาราง `transactions` | ⬜ | |
| 6 | Notifications | 🟨 ตาราง+RLS apply แล้ว | 🟨 `Notifications` page + bell icon + link ไป `ProductDetails` (D-26) — ทดสอบผ่านแอปจริงแล้ว | เขียนได้ทางเดียว: reject→insert · ไม่มี unread badge/realtime/push จริง |
| 7 | Reviews & Reports | 🟨 `reports` RLS+constraint เสร็จ (D-24) · `reviews` ยังไม่มี | 🟨 `ReportProductSheet`/`Reports`/`ReportDetail` — **ทดสอบผ่านแอปจริงแล้ว (pete, 2026-08-15)** | |
| 8 | Admin Dashboard | 🟨 เริ่มแล้ว 2026-08-14 | 🟨 `HomeAdmin` ผูกข้อมูลจริง + approve/reject ใช้งานได้ | `admin_dashboard_stats`+`admin_sales_by_seller` · trigger คุ้มกัน moderation 2 คอลัมน์ (D-23) เหลือ RLS admin-only เต็มรูปแบบ, `"CAT"` CRUD |

✅ เสร็จ · 🟨 กำลังทำ · ⬜ ยังไม่เริ่ม — คอลัมน์ FlutterFlow คือสถานะใน **v2** (`m-j-u-market-v2-0xhjhg`) เท่านั้น งานฝั่ง v1 (archived) ไม่นับ (D-16)

> 🔴 **กฎการให้ ✅:** "ตารางว่าง 0 แถว = ยังไม่ PASS" — นับเป็น ✅ ได้ต่อเมื่อทดสอบด้วย user ธรรมดาจริงแล้วเท่านั้น

**L1** ปิดฝั่ง Supabase แล้ว (2026-08-09) · FlutterFlow ค้างที่ Confirm Email — ลิงก์ (D-19) ใช้ไม่ได้เพราะ Microsoft Safe Links ดึง token ทิ้งก่อนคนกด → เปลี่ยนเป็น OTP (D-20) แต่อีเมลไปไม่ถึงกล่อง (deliverability ฝั่ง tenant) รายละเอียด `DECISIONS.md` **D-20**

**L2** ปิดไม่ได้เพราะยังไม่เคยเทสอัปไฟล์เกิน 5MB/ผิดชนิดผ่านแอปจริง (บังคับที่ Storage API ไม่ใช่ Postgres ทดสอบจาก DB แทนไม่ได้) — อัปสำเร็จ + path ถูกต้องยืนยันแล้ว (`VERIFICATION.md` V-08)

**L4** ปิดไม่ได้เพราะ `chat`/`chat_user`/`chat_message` ว่าง 0 แถวทั้งหมด — `chat_summary.member_names` (จุดที่เคยพัง NULL) ยังไม่เคยพิสูจน์ผ่าน view จริง มีแค่ `public_profiles` ตรง ๆ (V-04) → ปิดได้ต่อเมื่อสร้างห้องแชท 1 ห้อง 2 สมาชิก แล้ว SELECT `chat_summary` ด้วย user ธรรมดา เห็น `member_names` ครบ

---

## ❓ คำถามที่ยังไม่ตัดสินใจ (รวมทุก layer)

**🔴 รอ pete ตอบ**
1. **D-20 — OTP เสร็จ ติด email deliverability** ดู `DECISIONS.md` **D-20** — ไม่ใช่คำถามค้าง เป็นบล็อกทางเทคนิค
2. **รับข้อเสนอ P-11/P-12 ไหม** — unique index บน `lower(email)` + เก็บกวาดไฟล์กำพร้า ยังไม่ตอบรับ อยู่ใน `PROPOSED_SQL.md`

**Layer 1** — role-based redirect ที่ Splash/Initial (auto-login) ด้วยไหม · `handle_new_user()` ยังไม่มี `ON CONFLICT`

**Layer 2** — เปิด browse ก่อนล็อกอินไหม (ต้องเพิ่ม policy ให้ `anon` ทั้ง `"CAT"`/`products`) · บังคับ `category_id` ห้าม null ไหม

**Layer 3** — FlutterFlow built-in filter พอไหม หรือต้องสร้าง RPC `search_products` (P-05)

**Layer 4** — listen realtime บน **view** ได้จริงไหม (ต้องทดสอบ) · query builder รองรับ "array contains" บน `chat_summary.user_ids` ไหม ถ้าไม่ต้องทำ RPC `get_my_chats(uid)` · trigger auto-update `chat.last_message` (P-04) หรือให้ Action Flow อัปเดต 2 ที่เอง

**Layer 5** — ต้องการ `status` กี่แบบจริง ๆ, เก็บประวัติ transaction แยกไหม หรือใช้ `products.status` พอ

**Layer 6** — ยังไม่ทำ: notification จาก `chat_message` insert (P-04), unread badge, realtime

**Layer 7** — รองรับรีพอร์ต "ผู้ใช้" ด้วยไหม (P-09) · `reviews` ใช้ RLS allow-all หรือ restrictive

**Layer 8** — RLS admin-only เต็มรูปแบบยังไม่ทำ (`products`/`chat`/`chat_user`/`chat_message` ยัง allow-all, D-03) · หน้า `Inspect` แยกยังไม่มีใน v2 (คิวรอตรวจอยู่ใน `HomeAdmin` มีปุ่มอนุมัติ/ปฏิเสธจริงแล้ว) · `"CAT"` ยังจัดการผ่าน UI ไม่ได้ ต้อง seed ด้วยมือ · `admin_sales_by_seller` อ้าง `products.status='sold'` ชั่วคราวเพราะยังไม่มี `transactions` (L5) — ถ้า L5 เริ่มจริงต้องตัดสินใจย้ายไปอ้าง `transactions` ไหม

---

## 💣 หนี้ทางเทคนิคที่ต้องใช้คืนก่อน production

- [ ] `products`/`chat`/`chat_user`/`chat_message` เป็น allow-all RLS — เปลี่ยนเป็น restrictive ตาม `chat_user` membership
- [ ] คิวอนุมัติ/`Inspect` กันด้วย UI เท่านั้น ไม่ใช่ RLS — user ยิง API ตรงยัง approve สินค้าเองได้
- [ ] ไม่มีระบบกันกดปุ่มลบซ้ำ/popup ค้างใน reject flow (ยอมรับเป็น MVP)
- [ ] `"Profile".id` มี default `gen_random_uuid()` ทั้งที่เป็นคอลัมน์ FK — ควรถอด default ออก (ยังไม่ทำ)
- [ ] ข้อมูลทดสอบค้างใน DB: `"Profile"` มี 7 แถว — 4 แถวมี `full_name` ปลอม (`ทดสอบ นักศึกษาหนึ่ง/สอง/สาม`, `สมชาย ใจดี`) ต้องล้างก่อน production
- [ ] 🆕 **พบบัญชี admin `mju6500000001@mju.ac.th` ที่ไม่มีบันทึกที่มา** (ตรวจพบ 2026-08-15 ตอน sync เอกสาร) — `created_at` = `email_confirmed_at` เป๊ะ (ไม่ผ่าน OTP flow จริง เพราะ confirm-email ยังไม่เคยทำงาน) ไม่อยู่ในตารางบัญชีทดสอบด้านล่าง — ต้องหาว่าใครสร้าง/ทำไม แล้วบันทึกหรือลบทิ้ง
- [ ] `"CAT"` ไม่มี UNIQUE บน `name` — seed ซ้ำได้
- [ ] `"Profile".is_banned` มีคอลัมน์แล้วแต่ไม่มี enforcement เลย — login/โพสต์/แชทได้ปกติแม้ `is_banned = true` ยังไม่มี UI ให้แอดมินกดแบน (แก้ได้แค่ผ่าน SQL ตรง ๆ)
- [ ] ไฟล์กำพร้าใน `avatars`/`product-images` — เปลี่ยน/ลบแล้วไฟล์เก่าไม่ถูกลบ (D-15) ยังไม่มีระบบเก็บกวาด (P-12 ยังไม่เลือกแนวทาง)
- [ ] รูปของประกาศ `pending`/`rejected` เปิดดูได้ถ้ารู้ URL (public bucket, D-12) — ห้ามเก็บของอ่อนไหวในนี้
- [ ] `Profile_email_key` เป็น unique ธรรมดา ไม่ใช่ index บน `lower(email)` — ยังไม่มีปัญหาจริงเพราะ trigger `lower()` ให้ก่อน insert (P-11 ยังไม่ตอบรับ)
- [ ] repo private (D-13) ไม่ใช่การปิดช่องโหว่ — ของจริงที่ต้องปิดคือ 2 ข้อบนสุดของรายการนี้

**บัญชีทดสอบที่ credential ถูกแก้ตรงด้วย SQL (ไม่ใช่สภาพ user จริง — ห้ามใช้เทสอย่างอื่นโดยไม่รู้ตัว):**

| อีเมล | role | แก้อะไร | ใช้เทสอะไรได้ | ห้ามเทส |
|---|---|---|---|---|
| `mju6577778888@mju.ac.th` | admin | `email_confirmed_at` patch ด้วย SQL | auth/role routing, ทุก layer อื่น | "สมัครแล้วต้องยืนยันอีเมล" |
| `mju6512345678@mju.ac.th` | user | `encrypted_password` เขียนทับด้วย SQL | Test Pilot login | เหมือนกัน |
| `mju6500000002@mju.ac.th` (สร้าง 2026-08-15) | user | insert ตรงเข้า `auth.users`+`auth.identities` (PT-20) | L7 report-a-listing ด้วย non-admin | "สมัครแล้วต้องยืนยันอีเมล" |

🔴 **บัญชีทดสอบสดสำหรับ confirm-email เดิมถูกลบไปแล้ว 2026-08-10** (`mju6500000099`+อีก 3 บัญชี) — ไม่มีบัญชีสดพร้อมใช้ ต้องสมัครใหม่เมื่อกลับมาทำ D-20 ต่อ

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

> ถ้ามี `flutterflow ai` (MCP) ให้สั่งใช้ `inspect`/`search`/`status` ดึงชื่อจริงมาก่อน แทนพิมพ์เอง

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
