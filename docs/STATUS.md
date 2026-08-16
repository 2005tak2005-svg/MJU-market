# STATUS.md — สถานะโปรเจกต์ + จุดเริ่ม session

> 📍 **เปิดไฟล์นี้เป็นไฟล์แรกของทุก session**
> อัปเดตล่าสุด: **2026-08-17**
> 🔴 **D-32: DoD audit ทั้งโปรเจกต์ (db-verifier + ui-checker คู่ขนาน) พบบั๊กจริง 4 จุด** — (1) L1: 2 บัญชี `auth.users` ไม่มีแถวใน `"Profile"` เลย (`mju6606105382`/`mju6606105386`, สาเหตุยังไม่ทราบ) (2) L8: `admin_sales_by_seller` ไม่มี admin gate เลย — authenticated ธรรมดาอ่านยอดขายข้าม seller ได้ทันทีที่มีของขายจริงชิ้นแรก (3) L4: ยืนยันแล้วว่า Realtime ไม่มีเลย ไม่ใช่แค่ "ยังไม่ยืนยัน" (4) จุดแดง unread (D-31) มีบั๊ก stale-state บน `chatList`/`Notifications`/`ReportsFeedback` — ไม่หายจนกว่าจะออกจากหน้าจริง นอกจากนี้ `MyPost` มีอยู่แล้วจริง (ไม่ใช่ "ยังไม่สร้าง") แต่ query ไม่ filter `seller_id` เลย โชว์ของทุกคน — audit-only round ยังไม่ได้แก้โค้ด รายละเอียด `DECISIONS.md` D-32
> ก่อนหน้า 2026-08-17: **D-31: จุดแดง glow บอกยังไม่อ่าน (หายเมื่อแตะ) บน `chatList`/`Notifications`/`ReportsFeedback`** — `chat_user.last_read_at` (ต่อสมาชิก) + `chat_summary.is_unread`, `reports.is_read` + RPC `mark_chat_read`/`mark_report_read` (บล็อก non-admin จริง) 🔴 พบว่า pete rename หน้า "Reports" เป็น "ReportsFeedback" ตรงใน FlutterFlow editor ทำให้ `ensurePage('Reports', ...)` เดิมเกือบสร้างหน้าซ้อน (จับได้ตอน push fail แก้แล้ว) รายละเอียด `DECISIONS.md` D-31
> ก่อนหน้า 2026-08-16: **D-29/D-30: L4 (chat) เริ่มและปิด Supabase ฝั่งสมบูรณ์ + FlutterFlow ฝั่งข้อความล้วนใช้งานได้จริงครบ 3 ทางเข้า** — RLS membership-based (เดิม allow-all), `find_or_create_chat`/`find_or_create_chat_with_admin`/`is_chat_member`/`get_my_chats` + trigger auto-update `last_message`, รองรับส่งรูปที่ schema (ยังไม่ทำฝั่ง UI), `chatList` ผูกข้อมูลจริง + หน้า `chatMessages` ใหม่ + ปุ่ม "แชทกับผู้ขาย" บน `ProductDetails` + ปุ่ม "ติดต่อแอดมิน" ต่อจริงแล้ว (D-30) + ทางเข้า `chatList` ใน `HomeAdmin` drawer (D-30) รายละเอียด `layers/L4-chat.md` + `PATTERNS.md` PT-09/PT-22/PT-23
> ก่อนหน้า 2026-08-15: D-24–D-27 (reject-flow, reports, addproduct flash bug, ContactAdminButton) ทดสอบผ่านแอปจริงโดย pete แล้ว
> ก่อนหน้า 2026-08-14: auth backend = Supabase (D-21) · L8 `HomeAdmin` approve/reject + `notifications` table + `Notifications` page + bell icon (D-22/D-23)
> **L1 confirm-email ยังหยุดที่ D-20** (OTP สร้างเสร็จ ติด email deliverability ฝั่ง tenant — ไม่ใช่คิวด่วน)

---

## 🔥 คิวถัดไป

1. **🔴 [D-32] แก้ L1: 2 บัญชี `auth.users` ไม่มีแถวใน `"Profile"`** — `mju6606105382@mju.ac.th` (ยืนยันอีเมลแล้ว, ใช้แอปไม่ได้ตอนนี้) + `mju6606105386@mju.ac.th`. ต้องหาสาเหตุก่อน (ไม่มี UNIQUE ชนกัน ยังไม่รู้ว่าทำไม `handle_new_user()` ไม่ทำงาน) แล้วค่อย backfill/แก้
2. **🔴 [D-32] ปิดช่องโหว่ `admin_sales_by_seller`** — ไม่มี admin gate เลย พึ่ง `products` RLS (allow-all) เพียงอย่างเดียว ต้องแก้ก่อนมีของขายจริงชิ้นแรก (ตอนนี้ยังไม่เห็นผลเพราะยังไม่มีแถว `status='sold'`) ดู `layers/L8-admin.md`
3. **ทดสอบ L4 (chat) + จุดแดง unread ผ่านแอปจริง** — ทดสอบระดับ DB ผ่านหมดแล้ว (`db-verifier` PASS) ยังไม่เคยเปิดแอปจริงเลย ใช้บัญชี `mju6512345678@mju.ac.th` + `mju6500000002@mju.ac.th` (มีห้องแชท 1 ห้องรออยู่แล้ว) เทส: ส่งข้อความ 2 ทาง, เปิดจาก `chatList`/"แชทกับผู้ขาย"/"ติดต่อแอดมิน"/Drawer ของ `HomeAdmin` — **รู้อยู่แล้วว่าจุดแดงจะไม่หายทันที ต้องออกจากหน้าก่อน (บั๊ก stale-state, D-32)** ไม่ต้องรายงานซ้ำถ้าเจอ
4. **L4: ทำส่งรูปภาพ + Realtime** — schema/bucket พร้อมแล้ว (`chat_message.image_url`, bucket `chat-images`) ฝั่ง FlutterFlow ยังไม่มีปุ่มแนบรูปเลย อ่าน PT-08 ก่อน — **ต้องแก้ `messageItem.message!` force-unwrap ก่อนเริ่ม** ไม่งั้นข้อความรูปล้วนแรกจะ crash หน้าห้องแชท
5. **[D-32] แก้ filter ของ `MyPost`** — หน้ามีอยู่แล้วจริง (ไม่ใช่ "ยังไม่สร้าง" ตามที่เคยเข้าใจ) แต่ query ไม่ filter `seller_id`/`currentUserUid` เลย ตอนนี้โชว์สินค้าทุกคนทุกสถานะ ต้องเพิ่ม filter ให้ตรงชื่อหน้า

🟡 **ไม่ใช่คิวด่วนแต่ยังไม่ปิด — L1 confirm-email (D-20)** บล็อกอยู่ที่ email deliverability ฝั่ง tenant มหาลัย ดู `layers/L1-auth-profile.md` หัวข้อ "งานค้าง — Confirm Email"

---

## สถานะ 8 Layers

| L | ชื่อ | Supabase | FlutterFlow | หมายเหตุ |
|---|---|---|---|---|
| 1 | Auth & User Profiles | ✅ ปิดแล้ว 🔴 พบ 2 บัญชีไม่มี `Profile` (D-32) | 🟨 Login/SignUp/Home/HomeAdmin/`ProfileUser` ทำงานจริง เหลือ Confirm Email (D-20) | auth backend = Supabase แล้ว (D-21) · OTP ติด email deliverability |
| 2 | Product Listings + Storage | 🟨 อัปจริงผ่านแอปแล้ว เหลือเทส reject >5MB/ผิดชนิด | 🟨 `addproduct` insert ผ่านแอปจริง + แก้บั๊กแฟลชไป Login (D-26) | seed `CAT` 12 หมวด · bucket+policy+CHECK 3 รูป · อ่าน PT-09/10/12 ก่อนเริ่ม |
| 3 | Browse / Search / Filter | ⬜ | 🟨 `AllList`+`ProductDetails` ทำแล้ว | ผูก `products_review_view` ยังไม่มี search/filter รูปยังเป็น placeholder |
| 4 | Chat & Messaging | ✅ RLS membership-based + RPC/trigger ทดสอบสิทธิ์จริงผ่านแล้ว (D-29/D-30) | 🟨 3 ทางเข้า (`chatList`, "แชทกับผู้ขาย", "ติดต่อแอดมิน") + Drawer nav ใน `HomeAdmin` ข้อความล้วนใช้ได้จริง — **ยังไม่เคยเทสผ่านแอปจริง** | ยังไม่มีส่งรูป · Realtime ยืนยันว่าไม่มีเลย (D-32) · จุดแดง unread มีบั๊ก stale-state (D-32) · อ่าน PT-06/09/22/23 ก่อนแตะต่อ |
| 5 | Transaction & Status | ⬜ ไม่มีตาราง `transactions` | ⬜ | |
| 6 | Notifications | 🟨 ตาราง+RLS apply แล้ว | 🟨 `Notifications` page + bell icon + link ไป `ProductDetails` (D-26) + จุดแดง unread (D-31, มีบั๊ก stale-state D-32) | เขียนได้ทางเดียว: reject→insert · ไม่มี realtime/push จริง |
| 7 | Reviews & Reports | 🟨 `reports` RLS+constraint เสร็จ (D-24) + `is_read` (D-31) · `reviews` ยังไม่มี | 🟨 `ReportProductSheet`/`ReportsFeedback`/`ReportDetail` + จุดแดง unread (D-31, มีบั๊ก stale-state D-32) — เนื้อหาหลัก**ทดสอบผ่านแอปจริงแล้ว (pete, 2026-08-15)** | หน้า "Reports" ถูก pete rename เป็น "ReportsFeedback" ตรงใน editor (2026-08-17) — ตรวจแล้วไม่มีจุดอ้างชื่อเก่าค้าง |
| 8 | Admin Dashboard | 🟨 เริ่มแล้ว 2026-08-14 🔴 `admin_sales_by_seller` ไม่มี admin gate (D-32) | 🟨 `HomeAdmin` ผูกข้อมูลจริง + approve/reject ใช้งานได้ | trigger คุ้มกัน moderation 2 คอลัมน์ (D-23) เหลือ RLS admin-only เต็มรูปแบบ (`products` คอลัมน์อื่น + sales view), `"CAT"` CRUD |

✅ เสร็จ · 🟨 กำลังทำ · ⬜ ยังไม่เริ่ม — คอลัมน์ FlutterFlow คือสถานะใน **v2** (`m-j-u-market-v2-0xhjhg`) เท่านั้น งานฝั่ง v1 (archived) ไม่นับ (D-16)

> 🔴 **กฎการให้ ✅:** "ตารางว่าง 0 แถว = ยังไม่ PASS" — นับเป็น ✅ ได้ต่อเมื่อทดสอบด้วย user ธรรมดาจริงแล้วเท่านั้น

**L1** ปิดฝั่ง Supabase แล้ว (2026-08-09) · FlutterFlow ค้างที่ Confirm Email — ลิงก์ (D-19) ใช้ไม่ได้เพราะ Microsoft Safe Links ดึง token ทิ้งก่อนคนกด → เปลี่ยนเป็น OTP (D-20) แต่อีเมลไปไม่ถึงกล่อง (deliverability ฝั่ง tenant) รายละเอียด `DECISIONS.md` **D-20** · 🔴 พบ 2 บัญชีจริงที่ `handle_new_user()` ไม่ทำงาน (D-32) ยังไม่ปิดสนิท

**L2** ปิดไม่ได้เพราะยังไม่เคยเทสอัปไฟล์เกิน 5MB/ผิดชนิดผ่านแอปจริง (บังคับที่ Storage API ไม่ใช่ Postgres ทดสอบจาก DB แทนไม่ได้) — อัปสำเร็จ + path ถูกต้องยืนยันแล้ว (`VERIFICATION.md` V-08)

**L4** Supabase ปิดแล้ว (D-29, 2026-08-16) — `chat_summary.member_names` พิสูจน์แล้วว่าไม่เป็น NULL ด้วย user ธรรมดาจริง (มีห้องแชท 1 ห้อง 2 สมาชิกจากการทดสอบ) FlutterFlow ปิดไม่ได้เพราะยังไม่มีส่งรูป/Realtime และยังไม่เคยเทสผ่านแอปจริงเลย (แค่ตรวจ `generated_code/`) รายละเอียด `layers/L4-chat.md`

---

## ❓ คำถามที่ยังไม่ตัดสินใจ (รวมทุก layer)

**🔴 รอ pete ตอบ**
1. **D-20 — OTP เสร็จ ติด email deliverability** ดู `DECISIONS.md` **D-20** — ไม่ใช่คำถามค้าง เป็นบล็อกทางเทคนิค
2. **รับข้อเสนอ P-11/P-12 ไหม** — unique index บน `lower(email)` + เก็บกวาดไฟล์กำพร้า ยังไม่ตอบรับ อยู่ใน `PROPOSED_SQL.md`

**Layer 1** — role-based redirect ที่ Splash/Initial (auto-login) ด้วยไหม · `handle_new_user()` ยังไม่มี `ON CONFLICT`

**Layer 2** — เปิด browse ก่อนล็อกอินไหม (ต้องเพิ่ม policy ให้ `anon` ทั้ง `"CAT"`/`products`) · บังคับ `category_id` ห้าม null ไหม

**Layer 3** — FlutterFlow built-in filter พอไหม หรือต้องสร้าง RPC `search_products` (P-05)

**Layer 4** — ตอบแล้วทั้งหมด (D-29): realtime ต้องฟังที่ table `chat_message` ไม่ใช่ view (ยังไม่ได้ต่อจริง), ไม่ต้อง array-contains เพราะ RLS กรองให้แล้ว, trigger auto-update `last_message` apply แล้ว — คำถามใหม่ที่เหลือ: จะแก้ปุ่ม "แชทกับผู้ขาย" ให้ส่ง `memberNames`/`userIds` ได้ไหม (ดู `layers/L4-chat.md` ข้อ 3-4)

**Layer 5** — ต้องการ `status` กี่แบบจริง ๆ, เก็บประวัติ transaction แยกไหม หรือใช้ `products.status` พอ

**Layer 6** — ยังไม่ทำ: notification จาก `chat_message` insert (P-04), unread badge, realtime

**Layer 7** — รองรับรีพอร์ต "ผู้ใช้" ด้วยไหม (P-09) · `reviews` ใช้ RLS allow-all หรือ restrictive

**Layer 8** — RLS admin-only เต็มรูปแบบยังไม่ทำ (`products` ยัง allow-all, D-03 — `chat`/`chat_user`/`chat_message` ปิดหนี้นี้แล้ว D-29) · หน้า `Inspect` แยกยังไม่มีใน v2 (คิวรอตรวจอยู่ใน `HomeAdmin` มีปุ่มอนุมัติ/ปฏิเสธจริงแล้ว) · `"CAT"` ยังจัดการผ่าน UI ไม่ได้ ต้อง seed ด้วยมือ · `admin_sales_by_seller` อ้าง `products.status='sold'` ชั่วคราวเพราะยังไม่มี `transactions` (L5) — ถ้า L5 เริ่มจริงต้องตัดสินใจย้ายไปอ้าง `transactions` ไหม

---

## 💣 หนี้ทางเทคนิคที่ต้องใช้คืนก่อน production

- [ ] 🆕 **[D-32, 2026-08-17] `admin_sales_by_seller` ไม่มี admin gate เลย** — พึ่ง `products` RLS (allow-all) เพียงอย่างเดียว authenticated ธรรมดาอ่านยอดขายข้าม seller ได้ทันทีที่มีของขายจริงชิ้นแรก (ตอนนี้ยังไม่เห็นผลเพราะยังไม่มีแถว `status='sold'`) — ดู `layers/L8-admin.md`
- [ ] 🆕 **[D-32] 2 บัญชี `auth.users` ไม่มีแถวใน `"Profile"`** (`mju6606105382@mju.ac.th` ยืนยันอีเมลแล้ว ใช้แอปไม่ได้ตอนนี้ + `mju6606105386@mju.ac.th`) — สาเหตุยังไม่ทราบ ไม่มี UNIQUE ชนกัน ดู `layers/L1-auth-profile.md`
- [ ] 🆕 **[D-32] จุดแดง unread (D-31) มีบั๊ก stale-state** บน `chatList`/`Notifications`/`ReportsFeedback` — ไม่หายทันทีตอนกลับมาหน้าเดิม (list ไม่ refetch ก่อน navigate ออก) ต้องออกจากหน้าจริงก่อนถึงจะหาย — ดู `layers/L4-chat.md` ข้อ 3
- [ ] 🆕 **[D-32] `MyPost` มีอยู่แล้วจริง แต่ query ไม่ filter `seller_id` เลย** — โชว์สินค้าทุกคนทุกสถานะ ไม่ใช่แค่ของตัวเอง
- [ ] `products` เป็น allow-all RLS นอกเหนือ 2 คอลัมน์ moderation — non-admin ยัง `UPDATE`/`DELETE` คอลัมน์อื่น (ราคา/รูป/ชื่อ) ของสินค้าคนอื่นได้ (คิวอนุมัติเองถูกปิดแล้วจริงด้วย trigger `enforce_moderation_admin_only`, D-23 — ยืนยัน live ว่าบล็อก non-admin จริง `chat`/`chat_user`/`chat_message` ก็ปิดหนี้นี้แล้ว D-29)
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
- [ ] 🆕 **L4 `chatMessages`: `messageItem.message!` force-unwrap** — ตอนนี้ปลอดภัยเพราะทุกข้อความเป็นข้อความล้วน แต่ถ้าเพิ่มปุ่มส่งรูป (ทำให้ `message` เป็น NULL ได้จริง) โดยไม่แก้บรรทัดนี้ก่อน จะ crash หน้าห้องแชททันทีที่มีข้อความรูปล้วนแรก

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
