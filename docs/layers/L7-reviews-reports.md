# Layer 7 — Reviews & Reports

> schema → `../SCHEMA.md` · ตรวจ → `../checks/L7.sql`
> **สถานะ: 🟨 `reports` มีตารางแล้ว (แต่ RLS deny-all) | `reviews` ยังไม่มี**

## 🎯 เป้าหมาย

ผู้ใช้รีพอร์ตสินค้า(/ผู้ใช้)ที่ไม่เหมาะสมได้ และให้คะแนนผู้ขายหลังธุรกรรมเสร็จได้

## 🧩 ขั้นตอน Supabase

1. **🔴 ด่วน:** `reports` เปิด RLS แต่**ไม่มี policy เลย = deny-all** ตอนนี้ insert/select ไม่ได้เลยแม้แต่ admin
   → ต้องเพิ่ม policy: insert ได้ทุก authenticated, select ได้เฉพาะ admin — DDL ที่ `PROPOSED_SQL.md` **P-10**
2. **ตัดสินใจ:** รองรับรีพอร์ต "ผู้ใช้" ด้วยไหม → ถ้าใช่ ใช้ `PROPOSED_SQL.md` P-09
3. สร้างตาราง `reviews` — DDL ที่ P-08 (มี `UNIQUE (reviewer_id, product_id)` กันรีวิวซ้ำ)
4. RLS ของ `reviews`: ตัดสินใจว่า allow-all หรือ restrictive (แนะนำ: SELECT เปิด, INSERT ต้อง `reviewer_id = auth.uid()`)

## 🎨 ขั้นตอน FlutterFlow

- ปุ่ม Report บน `ProductDetail` → form เหตุผล → Insert `reports` (`reporter_id = currentUserId`)
- หน้า Rate Seller หลังธุรกรรมเสร็จ (ต่อกับ Layer 5) → rating 1-5 + comment
- แสดงคะแนนเฉลี่ยผู้ขายบน `ProductDetail` (ต้องทำ view สรุป — ใช้ **PT-01** ถ้าต้องดึงชื่อผู้รีวิว)

## 🧪 Definition of Done

- [ ] รีพอร์ตบันทึกจริง และ **user ทั่วไปอ่านรีพอร์ตของคนอื่นไม่ได้**
- [ ] admin เห็นรีพอร์ตทั้งหมด
- [ ] รีวิวซ้ำสินค้าเดิมไม่ได้ (unique constraint ทำงานจริง ไม่ใช่แค่กันที่ UI)
- [ ] rating นอกช่วง 1-5 ถูกปฏิเสธที่ระดับ DB
- [ ] + DoD ร่วมใน `CLAUDE.md`

## ❓ ค้างอยู่

- รองรับรีพอร์ตผู้ใช้ไหม (P-09)
- `reviews` ใช้ RLS allow-all หรือ restrictive
