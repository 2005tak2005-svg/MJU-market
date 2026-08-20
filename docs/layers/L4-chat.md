# Layer 4 — Chat & Messaging (Supabase Realtime)

> schema/view/RLS → `../SCHEMA.md` · pattern → `../PATTERNS.md` · ตรวจ → `../checks/L4.sql`
> **สถานะ: Supabase ✅ RLS membership-based + RPC harden + ทดสอบสิทธิ์จริงผ่านแล้ว (D-29, 2026-08-16) | FlutterFlow 🟨 `chatList`+`chatMessages` ใช้งานได้จริง ทดสอบผ่านแอปจริงแล้ว (D-40/D-41, 2026-08-18) — ส่งข้อความ+รูปได้, bubble UI สองฝั่ง, ดูรูปเต็มได้ — เหลือ Realtime; จุดแดง unread stale-state แก้แล้วทั้ง 3 หน้า (D-49) ยังไม่ทดสอบผ่านแอปจริง**
> ปิดได้เมื่อ: (1) Realtime ทำงาน (2) ปุ่ม "แชทกับผู้ขาย" ส่งชื่อคู่สนทนาไปด้วยได้ (ไม่ใช่แค่ chat_id)

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
- **`chatList` layout crash แก้แล้ว** (D-40, 2026-08-18) — `shrinkWrap: true`, ทดสอบผ่านแอปจริงแล้ว
- **`chatMessages` bubble UI สองฝั่ง + ส่งรูปได้จริง** (D-41, 2026-08-18) — ของตัวเอง/คนอื่นแยกฝั่ง+สี, ปุ่มแนบรูปอัปโหลดเข้า `chat-images` แล้ว insert `chat_message.image_url`, แตะรูปเปิดดูเต็มผ่าน component `FullImageViewer`, ComposeBar ติดขอบล่างจอ (`Expanded`) — **ทดสอบผ่านแอปจริงโดย pete แล้วทั้งหมด**

**กับดัก SDK ที่เจอใหม่ทั้งหมด:** `../PATTERNS.md` **PT-22** (state/onLoad ใน `ensurePage` เดียวกันอ้างกันเองไม่ได้ ต้องแยกพุช) · **PT-23** (ItemRef นอก itemBuilder สด, ไม่มี RPC action, ไม่มี list literal, `SetState` vs `UpdateAppState.set`, custom function list arg nullable เสมอ, page param `.withDefault` ไม่ถึง constructor) · **PT-24** (nullable table/view row model field เป็น `String?` จริง ไม่ใช่ `''`, field ใหม่บน view ใช้พุชเดียวกันไม่ได้, `Expanded` vs `shrinkWrap` คนละปัญหา, `outputAs` ชนข้าม widget, ไม่มี `onLongPress`)

**🔴 เจอบั๊ก build-breaking ระหว่างตรวจปิด layer:** `getOtherUsers`/`senderLabel` เข้าถึง `.length`/`[i]` บน `List<String>?` โดยไม่ guard null — `dart analyze` ไม่ผ่านทั้งโปรเจกต์ (custom function ทุกตัวอยู่ไฟล์เดียวกัน) แก้แล้วด้วย `?? []` (commit `jpfa1sqLhlVEuJ0SccWn`) ยืนยันด้วย `dart analyze` จริงซ้ำหลังแก้ — **ผ่านแล้ว**

## ❓ ที่เคยค้าง — ตอนนี้ตอบแล้ว

- **"array contains บน `chat_summary.user_ids` รองรับไหม"** — ไม่ต้องตอบ เพราะไม่ต้องใช้เลย: RLS ที่ `chat`/`chat_user` กรองให้เหลือแค่ห้องของ user คนนั้นอยู่แล้ว query `chat_summary` แบบไม่มี filter เลยก็ปลอดภัย
- **"Realtime ฟังบน view ได้จริงไหม"** — ไม่ได้ เพราะ Realtime (Postgres logical replication) ทำงานระดับ table เท่านั้น ไม่มีอะไรให้ subscribe บน view — ตอบได้โดยไม่ต้องทดสอบ ต้อง subscribe ตรงที่ `chat_message` (table) แล้ว resolve sender name ฝั่ง client จาก `memberNames`/`userIds` param แทน `chat_messages_view`'s join

## 🚧 ยังไม่ทำ (คิวถัดไป)

1. **Realtime บน `chat_message`** — ยืนยันแล้วว่าไม่มีเลย ไม่ใช่แค่ "ยังไม่ยืนยัน" (`ui-checker` grep `generated_code/lib/` ทั้งต้นไม้หา `.stream(`/`StreamBuilder`/`SupabaseStreamBuilder` เจอ 0 จุด, D-32) Supabase publication เปิดไว้แล้ว แต่ฝั่ง FF DSL ไม่มี subscribe เลย ตอนนี้ใช้ manual refetch หลังส่งข้อความแทน
2. ~~🔴 จุดแดง unread (D-31) ไม่หายทันทีตอนกลับมาหน้าเดิม~~ — **แก้ครบ 3 หน้าแล้ว (D-49, 2026-08-20)** ทั้ง `chatList`/`Notifications`/`ReportsFeedback` ต่อ refetch+SetState ท้าย ON_TAP chain เดิมแล้ว (raw proto ต่อท้าย Navigate node) ยืนยันจาก `generated_code/` ครบ 3 ไฟล์ — **ยังไม่ได้ทดสอบผ่านแอปจริงโดย pete**
3. **ปุ่ม "แชทกับผู้ขาย" ไม่ส่ง `memberNames`/`userIds`** — ทางเข้าห้องแชทจาก `ProductDetails` ตอนนี้หัวข้อ/ชื่อผู้ส่งจะว่างเปล่าจนกว่าจะเปิดห้องเดิมซ้ำผ่าน `chatList` (ที่มี array จริงจาก `chat_summary`) — สาเหตุคือ PT-23 ข้อ 1 (ItemRef นอก scope) รวมกับไม่มี list literal (PT-23 ข้อ 7) ทางแก้ที่เป็นไปได้: ให้ `chatMessages` โหลด `chat_summary` เพิ่มเองตอน onLoad ด้วย `chatId` แทนพึ่ง param (ยังไม่ได้ลองเพราะ PT-10 เคยเจอปัญหา index list-state นอก ListView)
4. **ปุ่ม "แชทกับผู้ขาย" ซ่อนไม่ได้ตอนดูประกาศตัวเอง** — เหตุผลเดียวกับข้อ 3 (ไม่มี `seller_id` แบบ item-scoped นอก itemBuilder) กดได้แต่ RPC คืน 0 เงียบ ๆ ไม่มี feedback ใด ๆ
5. **การส่งข้อความยังไม่มี error feedback จริง** — ใช้ `PostgresCreate` ตรง ๆ (ไม่มี `onSuccess`/`onFailure`, PT-18) ส่งไม่สำเร็จ (เช่น เน็ตหลุด) จะเงียบ ไม่มี snackbar เตือน

## 🧪 Definition of Done

- [x] แชทระหว่าง 2+ บัญชีจริงแบบข้อความล้วน+รูป — ทดสอบผ่านแอปจริงโดย pete แล้ว (D-40/D-41)
- [ ] ข้อความขึ้นโดยไม่ต้อง refresh (Realtime) — ยืนยันแล้วว่าไม่มีเลย (ข้อ 1 ด้านบน, D-32)
- [x] Chat List แสดงเฉพาะห้องที่ตัวเองอยู่ — ยืนยันด้วย non-member account เห็น 0 แถวจริง
- [x] ชื่อห้องถูกต้องผ่าน `getOtherUsers` — ไม่เป็น NULL ด้วยบัญชี user ธรรมดา (ยืนยันจาก `chat_summary` query จริง)
- [x] ห้องแชท: ข้อความ + `sender_name`/`senderLabel` ถูกต้อง เรียงเวลาถูก (ascending, ยืนยันจาก generated code)
- [x] เพิ่มสมาชิกซ้ำในห้องเดิมไม่ได้ — `find_or_create_chat` idempotent ยืนยันแล้ว
- [x] `chat.last_message` ตรงกับข้อความล่าสุดจริงเสมอ — trigger ยืนยันแล้ว
- [x] ส่งรูปได้ + bubble UI สองฝั่ง + ดูรูปเต็ม — ทำแล้ว (D-41) ทดสอบผ่านแอปจริงแล้ว
- [x] จุดแดงบอกยังไม่อ่าน + หายไปหลังแตะ — แก้ stale-state แล้ว (D-49) ยืนยันจาก `generated_code/` แต่**ยังไม่ทดสอบผ่านแอปจริง**
- [x] + DoD ร่วมใน `CLAUDE.md` (ทดสอบผ่านแอปจริงด้วยบัญชี user ธรรมดา) — ทำแล้ว (D-40/D-41)
