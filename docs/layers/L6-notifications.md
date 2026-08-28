# Layer 6 — Notifications

> schema → `../SCHEMA.md` · ตรวจ → `../checks/L6.sql`
> **สถานะ: 🟨 ตาราง+RLS+UI ใช้งานจริงแล้ว (D-22/D-23/D-26) + จุดแดง unread (D-31, มีบั๊ก stale-state D-32) — เขียนได้ทางเดียว (reject→insert), ไม่มี trigger อัตโนมัติ · **Realtime บนรายการ `Notifications` ทำแล้ว (D-60, 2026-08-24)** · **avatar แอดมิน + คุยกับแอดมินจากแจ้งเตือน + badge ตาม type ทำแล้ว (D-74, 2026-08-28)** ยังไม่มี unread badge ตัวเลข/push จริงตอนปิดแอป**

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
- แตะแถว → mark `is_read=true` + Navigate `ProductDetails` **เฉพาะ** `listing_approved`/`listing_rejected` (แก้บั๊กเดิม: `account_banned`/`account_unbanned` เคย Navigate ด้วย `productId` เป็น null เสมอ)
- ปุ่ม "คุยกับแอดมิน" แยกจากการแตะแถว — โผล่เฉพาะแถว `listing_rejected`/`account_banned` (เลือกสโคปนี้ตามที่ pete ตอบ) เรียก `findOrCreateChatWithAdmin` (ต่อยอดให้ relay memberNames/userIds แล้ว) → Navigate `chatMessages`
- รายละเอียดกับดักที่เจอ (action ซ้ำ structure ชน validate, `Equals(item[],null)` ไม่เช็ค null จริง) → `PATTERNS.md` PT-39, ตัดสินใจเต็ม → `DECISIONS.md` D-74 — **ยังไม่ทดสอบผ่านแอปจริง**

**ยังไม่ทำ:** badge นับ unread ที่ระดับ App State/bell icon (ตัดสโคปไว้ตอน D-60 — pete สั่งเว้นรอบนี้) · push notification จริงตอนปิดแอป (FCM/OneSignal) · thumbnail สินค้าในแถว approved/rejected (ตัดสโคปไว้ตอน D-74)

## 🧪 Definition of Done

- [x] เหตุการณ์จริง (reject) สร้าง notification ให้ถูกคน — ยืนยันจาก DB (`db-verifier`)
- [x] ผู้ใช้อ่าน notification ของคนอื่นไม่ได้ — ทดสอบ non-admin จริงแล้ว (0 แถวข้ามคน)
- [ ] badge นับ unread ถูกต้องและอัปเดต live — ยังไม่ทำ (ตัดสโคปไว้)
- [x] รายการอัปเดตสดระหว่างเปิดหน้าค้างอยู่ (Realtime) — ทำแล้ว (D-60) ยืนยันจาก `generated_code/` — **ยังไม่ทดสอบผ่านแอปจริง**
- [ ] ปิดแอปแล้วเปิดใหม่ยังเห็นแจ้งเตือนที่พลาดไปแบบ push จริง — ยังไม่ทำ (ต้อง FCM/OneSignal แยกจาก Realtime)
- [ ] จุดแดง unread หายทันทีตอนแตะ — มีบั๊ก stale-state (D-32) ยังไม่แก้
- [ ] + DoD ร่วมใน `CLAUDE.md` — ยังไม่เคยทดสอบจุดแดงผ่านแอปจริง

## ❓ ค้างอยู่

Supabase table + Realtime พอไหม หรือต้องต่อ push notification จริง (FCM) ด้วย · จะเพิ่ม trigger อัตโนมัติ (chat_message insert / products approved) แทน app-code ทางเดียวไหม
