# Layer 6 — Notifications

> schema → `../SCHEMA.md` · ตรวจ → `../checks/L6.sql`
> **สถานะ: ⬜ ยังไม่เริ่ม — ยังไม่มีตาราง `notifications`**

## 🎯 เป้าหมาย

แจ้งเตือนเมื่อมีเหตุการณ์สำคัญ: ข้อความใหม่ (L4) · สินค้าถูกอนุมัติ/ปฏิเสธ (L2) · มีคนสนใจ/จองสินค้า (L5)

> 💡 layer นี้คือคำตอบของข้อจำกัด **PT-04** — realtime popup เห็นได้เฉพาะตอนเปิดหน้าค้างอยู่ layer นี้ทำให้แจ้งเตือนไม่หายแม้ปิดแอป

## 🧩 ขั้นตอน Supabase

1. สร้างตาราง `notifications` — DDL ที่ `PROPOSED_SQL.md` P-07
2. เปิด Realtime บนตารางนี้ (เพื่อให้ badge อัปเดต live)
3. สร้าง notification อัตโนมัติด้วย trigger หรือ Edge Function:
   - trigger บน `chat_message` INSERT → แจ้งสมาชิกห้องคนอื่น (join `chat_user`)
   - trigger บน `products` UPDATE เมื่อ `moderation_status` เปลี่ยน → แจ้ง `seller_id`
   - trigger บน `transactions` (ถ้ามี L5) → แจ้ง buyer/seller
4. RLS: อ่านได้เฉพาะ `user_id = auth.uid()` — **ตารางนี้ควรเป็น restrictive ตั้งแต่แรก** ไม่ต้องตามรอย allow-all ของตารางเก่า

## 🎨 ขั้นตอน FlutterFlow

- หน้า Notification Center — List View ผูก `notifications` filter `user_id = currentUserId` sort `created_at desc`
- Badge widget ผูกกับ count ของ `is_read = false` → App State `unreadCount`
- กดรายการ → mark `is_read = true` + navigate ตาม `type`/`ref_id`

## 🧪 Definition of Done

- [ ] เหตุการณ์จริงในระบบสร้าง notification ให้**ถูกคน**
- [ ] ผู้ใช้อ่าน notification ของคนอื่นไม่ได้ (ทดสอบด้วย 2 บัญชี)
- [ ] badge นับ unread ถูกต้องและอัปเดต live
- [ ] ปิดแอปแล้วเปิดใหม่ ยังเห็นแจ้งเตือนที่พลาดไป (แก้ข้อจำกัด PT-04 ได้จริง)
- [ ] + DoD ร่วมใน `CLAUDE.md`

## ❓ ค้างอยู่

Supabase table + Realtime พอไหม หรือต้องต่อ push notification จริง (FCM) ด้วย
