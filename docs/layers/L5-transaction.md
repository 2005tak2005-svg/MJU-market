# Layer 5 — Transaction & Listing Status Management

> schema → `../SCHEMA.md` · ตรวจ → `../checks/L5.sql`
> **สถานะ: ⬜ ยังไม่เริ่ม — ยังไม่มีตาราง `transactions`**

## 🎯 เป้าหมาย

เปลี่ยนสถานะสินค้า (available / reserved / sold) ได้ถูกต้อง ไม่มี race condition เวลามีคนกดจองพร้อมกัน

## 🗄️ ของที่มีอยู่

มีแค่ `products.status` (varchar, nullable) — **คนละคอลัมน์กับ `moderation_status`** โดยตั้งใจ (`DECISIONS.md` D-04)

## 🧩 ขั้นตอน Supabase

1. **ตัดสินใจก่อน:** ต้องการตาราง `transactions` แยกจริงไหม หรือใช้แค่ `products.status` พอ
   - ถ้าต้องการ → DDL ร่างไว้ที่ `PROPOSED_SQL.md` P-06 (ต้อง confirm ค่า status ที่ใช้จริงก่อน)
2. **กัน race condition ตอนจอง** — ใช้ **PT-05** (conditional update)
   ```sql
   UPDATE products SET status = 'reserved' WHERE id = ? AND status = 'available';
   ```
3. RLS ของ `transactions`: ผู้ซื้อ/ผู้ขายที่เกี่ยวข้องอ่านได้เฉพาะของตัวเอง
   ⚠️ ต่างจาก allow-all ของตารางอื่น เพราะมีข้อมูลธุรกรรม — ถ้าจะทำต้องออกแบบ policy จริง

## 🎨 ขั้นตอน FlutterFlow

1. ปุ่ม "จองสินค้า" บน `ProductDetail` → Action Flow conditional update ตามข้อ 2
   - ถ้า 0 แถวถูกอัปเดต → แสดงข้อความ "มีคนจองไปแล้ว"
2. ปุ่มเปลี่ยนสถานะฝั่งผู้ขายที่ `MyPost` (available ↔ reserved ↔ sold)
3. แจ้งเตือน buyer/seller เมื่อสถานะเปลี่ยน → ต่อกับ Layer 6

## 🧪 Definition of Done

- [ ] เปลี่ยนสถานะสินค้าได้ถูกต้องทุกทาง
- [ ] **กดจองพร้อมกัน 2 บัญชี → มีคนเดียวที่สำเร็จ** อีกคนได้ข้อความบอกว่าถูกจองแล้ว
- [ ] `moderation_status` ไม่ถูกเขียนทับโดย flow ของ layer นี้
- [ ] + DoD ร่วมใน `CLAUDE.md`

## ❓ ค้างอยู่

- ต้องการ `status` กี่แบบจริง ๆ
- ต้องเก็บประวัติ transaction แยกไหม หรือ `products.status` พอ
