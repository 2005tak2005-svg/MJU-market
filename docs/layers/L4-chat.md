# Layer 4 — Chat & Messaging (Supabase Realtime)

> schema/view/RLS → `../SCHEMA.md` · pattern → `../PATTERNS.md` · ตรวจ → `../checks/L4.sql`
> **สถานะ: Supabase ✅ RLS membership-based + RPC harden + ทดสอบสิทธิ์จริงผ่านแล้ว (D-29, 2026-08-16) | FlutterFlow 🟨 แชทข้อความล้วนใช้งานได้จริง ยังไม่มีรูป/Realtime**
> ปิดได้เมื่อ: (1) ส่งรูปได้จริงผ่านแอป (2) Realtime ทำงาน (3) ปุ่ม "แชทกับผู้ขาย" ส่งชื่อคู่สนทนาไปด้วยได้ (ไม่ใช่แค่ chat_id)

## 🎯 เป้าหมาย

ผู้ซื้อ–ผู้ขายแชทกันแบบเรียลไทม์ รองรับ group chat (หลายคนในห้อง) แสดงชื่อห้องจากสมาชิกอัตโนมัติ

## 🧩 Supabase — เสร็จแล้ว (D-29)

`chat`/`chat_user`/`chat_message` (+ `chat_message.image_url`, CHECK `chat_message_has_content`) · RLS membership-based ผ่าน `is_chat_member()` (ทดสอบแล้วว่า non-member เห็น 0 แถวจริง) · `find_or_create_chat()` (กัน impersonation) · trigger `trg_update_last_message` (รองรับข้อความรูปล้วน → `'📷 รูปภาพ'`) · `get_my_chats()` (ยังไม่มีใครเรียกใช้) · bucket `chat-images` (public, 5MB, path `<uid>/<file>` เหมือน `product-images`) — รายละเอียดเต็ม `../SCHEMA.md`, เหตุผลออกแบบ `../DECISIONS.md` D-29

**ยังเหลือ:** ไม่มี — หนี้ allow-all เดิม (D-03) ปิดแล้วสำหรับ 3 ตารางนี้

## 🎨 FlutterFlow — ทำแล้ว (2026-08-16)

- **`chatList`** (หน้าที่ pete สร้าง mock ไว้ก่อน) ผูก `chat_summary` แบบไม่มี filter (RLS กรองให้แล้ว ไม่ต้อง array-contains) → `getOtherUsers` (PT-06) ตัดชื่อตัวเองออกจากหัวข้อแถว → แตะแถว Navigate ไป `chatMessages` พร้อม `chatId`/`memberNames`/`userIds`
- **`chatMessages`** (หน้าใหม่) — โหลด/ส่งข้อความข้อความล้วนได้จริง ผูก `chat_messages_view` (ไม่ใช่ table ตรง ๆ) เรียง `created_at` ascending ส่งข้อความผ่าน `PostgresCreate` + refetch มือ (ไม่มี Realtime)
- **ปุ่ม "แชทกับผู้ขาย" บน `ProductDetails`** — custom action `findOrCreateChatWithSeller` หา `seller_id` จาก `productId` เอง (ไม่ใช้ query builder) แล้วเรียก RPC — ปุ่มแสดงเสมอ (ซ่อนไม่ได้ตอนดูประกาศตัวเอง เพราะเข้าถึง `seller_id` แบบ item-scoped จากนอก itemBuilder ไม่ได้ — ดู PT-23) การกดใน้อ่านเงียบถ้าเป็นเจ้าของประกาศเอง (RPC คืน 0)
- **ปุ่ม "ติดต่อแอดมิน" บน `ProductDetails`** (D-30, 2026-08-16) — เดิม mock (D-26) ต่อเข้าระบบแชทจริงแล้ว ผ่าน RPC ใหม่ `find_or_create_chat_with_admin` (หาแอดมินคนแรกสุดตาม `created_at` เอง เพราะ RLS ของ `"Profile"` ไม่ให้ user ธรรมดาเห็นแถวแอดมิน) — ส่งไปหาแอดมิน**คนเดียว** ไม่ใช่กลุ่ม
- **ปุ่ม "ข้อความ" ใน Drawer ของ `HomeAdmin`** (D-30) — Navigate ไป `chatList` ให้แอดมินเข้าไปอ่าน/ตอบได้
- **จุดแดง glow บอกยังไม่อ่านใน `chatList`** (D-31, 2026-08-17) — `chat_summary.is_unread` (คำนวณต่อ `auth.uid()`) หายไปหลังแตะ (`mark_chat_read` RPC อัปเดต `chat_user.last_read_at` ของตัวเอง)

**กับดัก SDK ที่เจอใหม่ทั้งหมด:** `../PATTERNS.md` **PT-22** (state/onLoad ใน `ensurePage` เดียวกันอ้างกันเองไม่ได้ ต้องแยกพุช) และ **PT-23** (ItemRef นอก itemBuilder สด, ไม่มี RPC action, ไม่มี list literal, `SetState` vs `UpdateAppState.set`, custom function list arg nullable เสมอ, page param `.withDefault` ไม่ถึง constructor)

**🔴 เจอบั๊ก build-breaking ระหว่างตรวจปิด layer:** `getOtherUsers`/`senderLabel` เข้าถึง `.length`/`[i]` บน `List<String>?` โดยไม่ guard null — `dart analyze` ไม่ผ่านทั้งโปรเจกต์ (custom function ทุกตัวอยู่ไฟล์เดียวกัน) แก้แล้วด้วย `?? []` (commit `jpfa1sqLhlVEuJ0SccWn`) ยืนยันด้วย `dart analyze` จริงซ้ำหลังแก้ — **ผ่านแล้ว**

## ❓ ที่เคยค้าง — ตอนนี้ตอบแล้ว

- **"array contains บน `chat_summary.user_ids` รองรับไหม"** — ไม่ต้องตอบ เพราะไม่ต้องใช้เลย: RLS ที่ `chat`/`chat_user` กรองให้เหลือแค่ห้องของ user คนนั้นอยู่แล้ว query `chat_summary` แบบไม่มี filter เลยก็ปลอดภัย
- **"Realtime ฟังบน view ได้จริงไหม"** — ไม่ได้ เพราะ Realtime (Postgres logical replication) ทำงานระดับ table เท่านั้น ไม่มีอะไรให้ subscribe บน view — ตอบได้โดยไม่ต้องทดสอบ ต้อง subscribe ตรงที่ `chat_message` (table) แล้ว resolve sender name ฝั่ง client จาก `memberNames`/`userIds` param แทน `chat_messages_view`'s join

## 🚧 ยังไม่ทำ (คิวถัดไป)

1. **ส่งรูปภาพ** — schema/bucket พร้อมแล้ว (`chat_message.image_url`, bucket `chat-images`) ฝั่ง FlutterFlow ยังไม่มีปุ่มแนบรูป/`UploadData` เข้า bucket นี้เลย ต้องทำตาม PT-08 pattern (bucket/path เหมือน `product-images`) — เมื่อทำแล้ว **ต้องแก้ `messageItem.message!`** (force-unwrap ตรง ๆ ตอนนี้) ให้เป็น conditional แสดงรูปแทนข้อความเมื่อ `message` เป็น null ไม่งั้นข้อความรูปล้วนแรกที่มีจะ crash หน้าห้องแชททันที
2. **Realtime บน `chat_message`** — ยังไม่ได้เปิด "Listen for realtime updates" เลย (Supabase publication เปิดไว้แล้ว ฝั่ง FF DSL ยังไม่ได้ตั้ง `isStreamingSupabaseQuery: true` จริง) ตอนนี้ใช้ manual refetch หลังส่งข้อความแทน
3. **ปุ่ม "แชทกับผู้ขาย" ไม่ส่ง `memberNames`/`userIds`** — ทางเข้าห้องแชทจาก `ProductDetails` ตอนนี้หัวข้อ/ชื่อผู้ส่งจะว่างเปล่าจนกว่าจะเปิดห้องเดิมซ้ำผ่าน `chatList` (ที่มี array จริงจาก `chat_summary`) — สาเหตุคือ PT-23 ข้อ 1 (ItemRef นอก scope) รวมกับไม่มี list literal (PT-23 ข้อ 7) ทางแก้ที่เป็นไปได้: ให้ `chatMessages` โหลด `chat_summary` เพิ่มเองตอน onLoad ด้วย `chatId` แทนพึ่ง param (ยังไม่ได้ลองเพราะ PT-10 เคยเจอปัญหา index list-state นอก ListView)
4. **ปุ่ม "แชทกับผู้ขาย" ซ่อนไม่ได้ตอนดูประกาศตัวเอง** — เหตุผลเดียวกับข้อ 3 (ไม่มี `seller_id` แบบ item-scoped นอก itemBuilder) กดได้แต่ RPC คืน 0 เงียบ ๆ ไม่มี feedback ใด ๆ
5. **การส่งข้อความยังไม่มี error feedback จริง** — ใช้ `PostgresCreate` ตรง ๆ (ไม่มี `onSuccess`/`onFailure`, PT-18) ส่งไม่สำเร็จ (เช่น เน็ตหลุด) จะเงียบ ไม่มี snackbar เตือน

## 🧪 Definition of Done

- [x] แชทระหว่าง 2+ บัญชีจริงแบบ**ข้อความล้วน** — ทดสอบระดับ DB แล้ว (RLS/RPC/trigger, `db-verifier` PASS) **ยังไม่เคยทดสอบผ่านแอปจริงบนมือถือ/เว็บ** — รอ pete
- [ ] ข้อความขึ้นโดยไม่ต้อง refresh (Realtime) — ยังไม่ทำ (ข้อ 2 ด้านบน)
- [x] Chat List แสดงเฉพาะห้องที่ตัวเองอยู่ — ยืนยันด้วย non-member account เห็น 0 แถวจริง
- [x] ชื่อห้องถูกต้องผ่าน `getOtherUsers` — ไม่เป็น NULL ด้วยบัญชี user ธรรมดา (ยืนยันจาก `chat_summary` query จริง)
- [x] ห้องแชท: ข้อความ + `sender_name`/`senderLabel` ถูกต้อง เรียงเวลาถูก (ascending, ยืนยันจาก generated code)
- [x] เพิ่มสมาชิกซ้ำในห้องเดิมไม่ได้ — `find_or_create_chat` idempotent ยืนยันแล้ว
- [x] `chat.last_message` ตรงกับข้อความล่าสุดจริงเสมอ — trigger ยืนยันแล้ว
- [ ] ส่งรูปได้ — ยังไม่ทำ (ข้อ 1)
- [x] จุดแดงบอกยังไม่อ่าน + หายไปหลังแตะ — ยืนยันจาก `generated_code/` (D-31) **ยังไม่เคยทดสอบผ่านแอปจริง**
- [ ] + DoD ร่วมใน `CLAUDE.md` (ทดสอบผ่านแอปจริงด้วยบัญชี user ธรรมดา — ยังไม่ทำ)
