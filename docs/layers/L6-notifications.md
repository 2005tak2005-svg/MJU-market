# Layer 6 — Notifications

> schema → `../SCHEMA.md` · ตรวจ → `../checks/L6.sql`
> **สถานะ: 🟨 ตาราง+RLS+UI ใช้งานจริงแล้ว (D-22/D-23/D-26) + จุดแดง unread (D-31, มีบั๊ก stale-state D-32) — เขียนได้ทางเดียว (reject→insert), ไม่มี trigger อัตโนมัติ · **Realtime บนรายการ `Notifications` ทำแล้ว (D-60, 2026-08-24)** · **avatar แอดมิน + คุยกับแอดมินจากแจ้งเตือน + badge ตาม type ทำแล้ว (D-74, 2026-08-28)** ยังไม่มี unread badge ตัวเลข/push จริงตอนปิดแอป · banner ตอนเปิดแอปอยู่ทำแล้ว (D-88)**

## 🎯 เป้าหมาย

แจ้งเตือนเมื่อมีเหตุการณ์สำคัญ: ข้อความใหม่ (L4) · สินค้าถูกอนุมัติ/ปฏิเสธ (L2) · มีคนสนใจ/จองสินค้า (L5)

> 💡 layer นี้คือคำตอบของข้อจำกัด **PT-04** — realtime popup เห็นได้เฉพาะตอนเปิดหน้าค้างอยู่ layer นี้ทำให้แจ้งเตือนไม่หายแม้ปิดแอป (ยังไม่ครบ — ดูด้านล่าง)

## 🧩 Supabase — ทำแล้ว

`notifications` (`user_id`/`type`/`title`/`body`/`ref_product_id`/`is_read`) + RLS restrictive ตั้งแต่แรก (อ่าน/แก้ได้เฉพาะของตัวเอง, ไม่มี DELETE policy) — รายละเอียดคอลัมน์เต็ม `../SCHEMA.md`

**ยังไม่ทำ:** ไม่มี trigger/Edge Function สร้าง notification อัตโนมัติเลย — การสร้างตอนนี้เป็น**app-code ทางเดียว**: `RejectProductSheet` (D-23) insert `type='listing_rejected'` เท่านั้น ไม่มีเส้นทาง `listing_approved`/ข้อความใหม่จาก L4 (P-04, ยังไม่ตัดสินใจ)/ธุรกรรมจาก L5

**Realtime (D-60, 2026-08-24):** `notifications` เพิ่มเข้า `supabase_realtime` publication แล้ว — ดู `SCHEMA.md`

**`admin_contact_view` (D-74, 2026-08-28):** view ใหม่ ไม่มี security_invoker คืนแถวแอดมิน (id/avatar_url/full_name) แถวเดียว — ดู `SCHEMA.md`

## 🎨 FlutterFlow — ทำแล้ว

`Notifications` page ผูก `notifications` filter `user_id = currentUserUid` · bell icon บน `Home` → `Notifications` · จุดแดง unread ผูก `is_read` (D-31) — **มีบั๊ก: ไม่หายทันทีตอนกลับมาหน้าเดิม ต้องออกจากหน้าจริงก่อน (D-32, รายละเอียด `L4-chat.md` ข้อ 3)**

**Realtime ทำแล้ว (D-60, 2026-08-24):** page-level `databaseRequest` + `isStreamingSupabaseQuery` + `ON_DATA_CHANGE` (`PATTERNS.md` PT-32) — รายการใหม่ขึ้นเองระหว่างเปิดหน้าค้างอยู่ ไม่ต้องออกแล้วกลับเข้ามาใหม่ ยืนยันจาก `generated_code/` (compile เป็น `StreamBuilder` จริง) — **ยังไม่ทดสอบผ่านแอปจริง**

**รายการต่อแถวปรับใหม่ทั้งชุด (D-74, 2026-08-28)** — เดิมทุกแถวเหมือนกัน (ไอคอนเดียว, แตะแล้ว mark read + Navigate ProductDetails เสมอ) ตอนนี้:
- avatar วงกลม (รูปแอดมิน จาก `admin_contact_view`, ค่าเดียวใช้ร่วมทุกแถว — ไม่ใช่ per-row)
- badge ไอคอน 4 สีตาม `type` (approved/rejected/banned/unbanned)
- ~~แตะแถว → Navigate `ProductDetails`~~ **เลิกแล้ว (D-89)** แตะแถว → mark `is_read=true` อย่างเดียวทุก type · (เดิม: Navigate `ProductDetails` **เฉพาะ** `listing_approved`/`listing_rejected` (แก้บั๊กเดิม: `account_banned`/`account_unbanned` เคย Navigate ด้วย `productId` เป็น null เสมอ))
- ปุ่ม "คุยกับแอดมิน" แยกจากการแตะแถว — โผล่เฉพาะแถว `listing_rejected`/`account_banned` (เลือกสโคปนี้ตามที่ pete ตอบ) เรียก `findOrCreateChatWithAdmin` (ต่อยอดให้ relay memberNames/userIds แล้ว) → Navigate `chatMessages`
- รายละเอียดกับดักที่เจอ (action ซ้ำ structure ชน validate, `Equals(item[],null)` ไม่เช็ค null จริง) → `PATTERNS.md` PT-39, ตัดสินใจเต็ม → `DECISIONS.md` D-74 — **ยังไม่ทดสอบผ่านแอปจริง**

**Banner ในแอป (D-88, 2026-10-14):** custom action `startInAppNotificationBanner` (main.dart final action, PT-45) subscribe INSERT บน `notifications` ของ user ปัจจุบัน → overlay banner บนทุกหน้า (5 วิ, แตะ→`Notifications`, ไม่เด้งเมื่ออยู่หน้า `/notifications`) — **ยังไม่ทดสอบบนแอปจริง**

**แจ้งเตือนแชท ฝั่ง DB (D-90, 2026-10-14):** trigger `trg_notify_chat_message` บน `chat_message` → แถว `notifications` type `chat_message` (+`ref_chat_id`) ให้สมาชิกห้องยกเว้นผู้ส่ง · `mark_chat_read` mark แจ้งเตือนห้องนั้นอ่านแล้วด้วย · **ฝั่ง UI ยังไม่ทำ** (แถวบน `Notifications`, banner→เข้าห้อง, banner ไม่เด้งซ้ำในห้องที่เปิดอยู่)

**ตัวเลข unread บนกระดิ่ง `Home` (2026-10-24):** custom widget `NotificationUnreadBadge` (PT-36 fetch เอง, `.stream()` Realtime) ซ้อนบนกระดิ่งใน `Stack_bellbdg1` · ปุ่มจริง `IconButton_bellbtn1` (แทนคีย์ `IconButton_3gsou322`) · จุดแดง D-31 ไม่มีบน `Home` แล้ว — **ยังไม่ทดสอบบนแอปจริง**

**การ์ดป๊อบอัพรีวิว (D-101, 2026-10-25):** คอมโพเนนต์ `ReviewReceivedCard` เด้งแทน banner เมื่อ `review_received` เข้ามาสดขณะผู้ขายเปิดแอป (ดาว/ผู้รีวิว/สินค้า/ความเห็น/ปุ่มดูสินค้า) · ข้อมูลจาก RPC `get_review_card` ผ่าน `notifications.ref_review_id` · เปิดจาก `startInAppNotificationBanner` (PT-48) — **ยังไม่ทดสอบบนแอปจริง**

**แจ้งเตือนผู้ขายเมื่อได้รับรีวิว (D-100, 2026-10-25):** type `review_received` (category `system`) — trigger `trg_notify_review_received` บน `reviews` · body ระบุชื่อผู้รีวิว ดาว และชื่อสินค้า · ไม่มีไอคอน/ปุ่มเฉพาะ type นี้ — **ยังไม่ทดสอบบนแอปจริง**

**แจ้งเตือนยอดเข้าดูครบ 10 (D-99, 2026-10-25):** type `product_popular` (category `system`) — trigger `trg_notify_product_popular` บน `product_views` แจ้งเจ้าของครั้งเดียวต่อสินค้า · แถวแสดง title/body ปกติ ไม่มีไอคอน/ปุ่มเฉพาะ type นี้ · banner ใช้กระดิ่งสีหลัก — **ยังไม่ทดสอบบนแอปจริง**

**ตัวกรองประเภท (D-98, 2026-10-25):** ชิป 4 อัน (ทั้งหมด / ข้อความผู้ใช้ / ข้อความแอดมิน / ระบบ) เหนือ `NotificationsList` · `notifications.category` (`user`/`admin`/`system`) ตั้งใน `notify_chat_message()` · App State `notifFilter` รีเซ็ตเป็นทั้งหมดทุกครั้งที่เข้าหน้า · onInit/`ON_DATA_CHANGE`/แตะแถวดึงผ่าน custom action `loadMyNotifications` ตัวเดียว (PT-46) · ยังไม่มี empty-state/ตัวเลข unread ต่อชิป — **ยังไม่ทดสอบบนแอปจริง**

**แจ้งเตือนนอกแอป (D-96, 2026-10-24):** trigger `trg_push_notification_ntfy` → ntfy topic กลาง (prototype)

**ยังไม่ทำ:** push notification จริงต่อผู้ใช้ตอนปิดแอป (FCM) · thumbnail สินค้าในแถว approved/rejected (ตัดสโคปไว้ตอน D-74)

## 🧪 Definition of Done

- [x] เหตุการณ์จริง (reject) สร้าง notification ให้ถูกคน — ยืนยันจาก DB (`db-verifier`)
- [x] ผู้ใช้อ่าน notification ของคนอื่นไม่ได้ — ทดสอบ non-admin จริงแล้ว (0 แถวข้ามคน)
- [ ] badge นับ unread ถูกต้องและอัปเดต live — push แล้ว (2026-10-24) ยังไม่ทดสอบบนแอปจริง
- [x] รายการอัปเดตสดระหว่างเปิดหน้าค้างอยู่ (Realtime) — ทำแล้ว (D-60) ยืนยันจาก `generated_code/` — **ยังไม่ทดสอบผ่านแอปจริง**
- [ ] banner เด้งตอนเปิดแอปอยู่ (D-88) — push แล้ว ยังไม่ทดสอบบนแอปจริง
- [ ] ปิดแอปแล้วเปิดใหม่ยังเห็นแจ้งเตือนที่พลาดไปแบบ push จริง — ยังไม่ทำ (ต้อง FCM/OneSignal แยกจาก Realtime)
- [ ] จุดแดง unread หายทันทีตอนแตะ — มีบั๊ก stale-state (D-32) ยังไม่แก้
- [ ] + DoD ร่วมใน `CLAUDE.md` — ยังไม่เคยทดสอบจุดแดงผ่านแอปจริง

## ❓ ค้างอยู่

Supabase table + Realtime พอไหม หรือต้องต่อ push notification จริง (FCM) ด้วย · จะเพิ่ม trigger อัตโนมัติ (chat_message insert / products approved) แทน app-code ทางเดียวไหม
