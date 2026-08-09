# Layer 4 — Chat & Messaging (Supabase Realtime)

> schema/view/RLS → `../SCHEMA.md` · pattern → `../PATTERNS.md` · ตรวจ → `../checks/L4.sql`
> **สถานะ: Supabase 🟨 schema เสร็จ แต่ยังไม่เคยตรวจ | FlutterFlow ⬜ ยังไม่เริ่ม**
> `chat` / `chat_user` / `chat_message` ยังว่าง 0 แถว → `chat_summary.member_names` ยังไม่เคยยืนยันว่าไม่เป็น NULL
> ปิดได้เมื่อสร้างห้อง 1 ห้อง สมาชิก 2 คน แล้ว SELECT `chat_summary` ในฐานะ user ธรรมดาแล้วเห็นชื่อครบ

## 🎯 เป้าหมาย

ผู้ซื้อ–ผู้ขายแชทกันแบบเรียลไทม์ รองรับ group chat (หลายคนในห้อง) แสดงชื่อห้องจากสมาชิกอัตโนมัติ

> 🔴 **ก่อนเริ่มฝั่ง FlutterFlow อ่านนี่ก่อน:** `chat_summary.member_names`/`user_ids` เป็น array column — คำถามค้างข้างล่าง ("array contains currentUserId" รองรับไหม) มีโอกาสสูงที่จะชนบั๊ก SDK ตัวเดียวกับที่เจอตอน L1 อ่าน `../PATTERNS.md` **PT-09** (custom action argument เสีย) และ **PT-10** (`PostgresQuery`/`FieldAccess` ดึงฟิลด์เดียวจากแถวไม่ได้ — อาจเป็นคำตอบว่าทำไมต้องทำ RPC `get_my_chats(uid)` แทน query builder ธรรมดา) ก่อนเขียน Action Flow

## 🧩 ขั้นตอน Supabase ที่เหลือ

- [ ] (ก่อน production) เปลี่ยน RLS allow-all → restrictive ตาม `chat_user` membership — `DECISIONS.md` D-03
- [ ] ตัดสินใจ: trigger auto-update `chat.last_message` (P-04) หรือให้ Action Flow อัปเดต 2 ที่เอง
- [ ] apply `find_or_create_chat` (P-03) — เป็นทางเข้าห้องแชทของทั้งระบบ

**ทำแล้ว:** ตาราง `chat`/`chat_user`/`chat_message` + UNIQUE(chat_id,user_id) · `chat_summary` + `chat_messages_view` (join `public_profiles` แล้ว) · RLS allow-all · Realtime บน `chat` + `chat_message`

---

## 🎨 A. หน้า `chats` (Chat List)

- Backend Query ผูก view `chat_summary` แสดงเป็น List View
- **⚠️ ต้อง verify:** filter เฉพาะห้องที่ current user อยู่ (`user_ids` array contains `currentUserId`) — เช็คว่า FlutterFlow query builder รองรับ operator "array contains" บน view ไหม **ถ้าไม่รองรับ ต้องสร้าง RPC `get_my_chats(uid)` แยก**
- แต่ละแถว: ใช้ Custom Function `getOtherUsers` (**PT-06**) ผูก Combine Text → ได้ชื่อห้องแบบ `"chat with Rob awesome, TomTom"`
- **กดเลือกห้อง** → Navigate To `chat messages` แนบ Row ทั้งแถวจาก `chat_summary` เป็น Page Parameter (**PT-03**)

## 🎨 B. หน้า `chat messages`

- รับ Page Parameter → ดึง `chat_id`
- Backend Query ผูก `chat_messages_view` filter `chat_id = [parameter]`, sort by `created_at`
- **⚠️ ต้อง verify:** FlutterFlow เปิด "Realtime listen" บน **view** ได้จริงไหม
  Realtime ทำงานที่ table level (Postgres replication) — ถ้าไม่รองรับ ทางเลือกคือ subscribe ตาราง `chat_message` ตรง ๆ แล้ว join ชื่อ sender ฝั่ง client เอง หรือ refresh query เป็นระยะ
- **ส่งข้อความ** → Insert row เข้า `chat_message` (`chat_id`, `user_id = currentUserId`, `message`)
  ถ้ายังไม่ทำ trigger P-04 → ต้องมี action ที่ 2 อัปเดต `chat.last_message` ด้วยมือ

## 🎨 C. ทางเข้าห้องแชท

ไม่มีปุ่ม "สร้างห้องใหม่" ตรง ๆ — ทุกห้องเกิดจาก **PT-02** (find-or-create) ที่ถูกเรียกจาก `MaterialCard` (L2) และ `ProductDetail` (L3)

---

## 🧪 Definition of Done

- [ ] แชทระหว่าง 2+ บัญชีจริงแบบเรียลไทม์ ข้อความขึ้นโดยไม่ต้อง refresh
- [ ] Chat List แสดงเฉพาะห้องที่ตัวเองอยู่ (ไม่ใช่ทุกห้องในระบบ)
- [ ] ชื่อห้องถูกต้องผ่าน `getOtherUsers` — **ชื่อคู่สนทนาต้องไม่เป็น NULL ตอนใช้บัญชี user ธรรมดา** (PT-01)
- [ ] ห้องแชท: ข้อความ + `sender_name` ถูกต้อง เรียงเวลาถูก
- [ ] เพิ่มสมาชิกซ้ำในห้องเดิมไม่ได้ (unique constraint)
- [ ] `chat.last_message` ตรงกับข้อความล่าสุดจริงเสมอ
- [ ] + DoD ร่วมใน `CLAUDE.md`

## ❓ ค้างอยู่

- Realtime บน view ใช้ได้จริงไหมใน FlutterFlow (ต้องทดสอบ)
- "array contains" บน `chat_summary.user_ids` รองรับไหม
- trigger auto-update `last_message` — จะสร้างไหม
