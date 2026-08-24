# Layer 7 — Reviews & Reports

> schema → `../SCHEMA.md` · ตรวจ → `../checks/L7.sql`
> **สถานะ: 🟨 `reports` RLS+constraint+UI ใช้งานจริงแล้ว (D-24) + `is_read` (D-31) — เนื้อหาหลักทดสอบผ่านแอปจริงแล้ว (pete, 2026-08-15) จุดแดงยังไม่เทส (D-32) | `reviews` (ให้คะแนนผู้ขาย) Supabase+FlutterFlow ปิดครบแล้ว (D-64, 2026-08-24) — ยังไม่ทดสอบผ่านแอปจริง**

## 🎯 เป้าหมาย

ผู้ใช้รีพอร์ตสินค้า(/ผู้ใช้)ที่ไม่เหมาะสมได้ และให้คะแนนผู้ขายหลังธุรกรรมเสร็จได้

## 🧩 Supabase — `reports` ทำแล้ว (D-24), `reviews` ทำแล้ว (D-64)

`reports` (`reporter_id`/`reported_product_id`/`reason`/`status`/`is_read`) + RLS จริง (insert ทุก authenticated, select เจ้าของ+admin) + CHECK `status` + unique partial index กันรายงานซ้ำตอนยัง pending + FK `reported_product_id` เป็น `ON DELETE SET NULL` — รายละเอียดคอลัมน์เต็ม `../SCHEMA.md`

`reviews` (`transaction_id`/`reviewer_id`/`reviewee_id`/`rating`/`comment`) ผูกกับ `transactions` (L5) โดยตรงแทน `product_id` ตรง ๆ ตาม draft เดิม — RLS insert เช็คว่าเป็นผู้ซื้อจริงของธุรกรรมนั้น (`EXISTS` เทียบ `transactions`) เท่านั้น + RESTRICTIVE กันผู้ถูกแบน + **ไม่มี UPDATE/DELETE เลย = immutable ตลอดไป** · SELECT public ให้ authenticated ทุกคนเห็น · `products_review_view` เพิ่ม 4 คอลัมน์คอมพิวต์ (`seller_avg_rating`/`seller_review_count`/`my_transaction_id`/`can_rate_seller`) — รายละเอียดเต็ม `../SCHEMA.md`, `../DECISIONS.md` D-64

**ยังไม่ทำ:** รองรับรีพอร์ต "ผู้ใช้" (`reported_user_id`, P-09 ยังไม่ตอบรับ — ตั้งใจแยกออกจากรอบ `reviews` นี้)

## 🎨 FlutterFlow — ทำแล้ว

`ReportProductSheet` (ปุ่ม Report บน `ProductDetails` → insert `reports`) · `ReportsFeedback` (list สำหรับแอดมิน, เดิมชื่อ "Reports" — pete rename ตรงใน editor 2026-08-17, ตรวจแล้วไม่มีจุดอ้างชื่อเก่าหลงเหลือ) · `ReportDetail` · จุดแดง unread ผูก `is_read` (D-31) — **มีบั๊กเดียวกับ L4/L6: ไม่หายทันทีตอนกลับมาหน้าเดิม (D-32)**

`RateSellerSheet` (component ใหม่, D-64) — `Slider` 1-5 (ไม่มี `RatingBar` ที่ construct ได้จริงในระบบนี้) + comment `TextField` + ปุ่มยกเลิก/ส่ง · custom action `submitSellerReview` (0-arg, หา `transaction_id`/`seller_id` เองจาก `transactions` แล้ว insert `reviews` ตรง ไม่ผ่าน RPC) · ปุ่ม "ให้คะแนนผู้ขาย" บน `ProductDetails` ต่อจาก `ContactAdminButton` ผูก visibility เข้ากับ `can_rate_seller` ผ่าน `productField()`/`nodeKeyRef` เดิม (D-44/D-59) — โชว์เฉพาะผู้ซื้อจริงของสินค้าที่ขายแล้วและยังไม่เคยรีวิว

**ยังไม่ทำ (ตามคำตอบ pete):** แก้ไข/ลบรีวิวที่โพสต์แล้ว · แสดงคะแนนเฉลี่ยที่หน้าโปรไฟล์ผู้ขาย (ทำแค่บน `ProductDetails`) · หน้า "MyPurchases" แยก (จุดเข้าใช้ `ProductDetail` เดิม)

## 🧪 Definition of Done

- [x] รีพอร์ตบันทึกจริง และ user ทั่วไปอ่านรีพอร์ตของคนอื่นไม่ได้ — ทดสอบ non-admin จริงแล้ว
- [x] admin เห็นรีพอร์ตทั้งหมด — ทดสอบผ่านแอปจริงแล้ว (pete, 2026-08-15)
- [x] รีวิวซ้ำ transaction เดิมไม่ได้ — `UNIQUE(transaction_id, reviewer_id)` + RLS insert เช็ค EXISTS ยืนยันจาก schema/RLS จริง **ยังไม่ทดสอบผ่านแอปจริง**
- [x] rating นอกช่วง 1-5 ถูกปฏิเสธที่ระดับ DB — `CHECK (rating BETWEEN 1 AND 5)`
- [ ] จุดแดง unread หายทันทีตอนแตะ — มีบั๊ก stale-state (D-32) ยังไม่แก้
- [ ] + DoD ร่วมใน `CLAUDE.md`
- [ ] 🆕 (D-64) ทดสอบผ่านแอปจริงด้วย user ธรรมดา: ซื้อสินค้าจริง (ผ่าน `mark_product_sold`) แล้วเห็นปุ่ม "ให้คะแนนผู้ขาย" บน `ProductDetail`, ให้คะแนนสำเร็จ, กดซ้ำไม่ได้อีก (ปุ่มหาย/error), user อื่นที่ไม่ใช่ผู้ซื้อไม่เห็นปุ่มเลย, คะแนนเฉลี่ยโชว์ถูกต้อง

## ❓ ค้างอยู่

- รองรับรีพอร์ตผู้ใช้ไหม (P-09)
