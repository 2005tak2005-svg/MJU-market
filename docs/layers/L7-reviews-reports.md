# Layer 7 — Reviews & Reports

> schema → `../SCHEMA.md` · ตรวจ → `../checks/L7.sql`
> **สถานะ: 🟨 `reports` (สินค้า+ผู้ใช้) RLS+constraint+UI ใช้งานจริงแล้ว (D-24/D-65) + `is_read` (D-31) — เนื้อหาหลักทดสอบผ่านแอปจริงแล้ว (pete, 2026-08-15) จุดแดงยังไม่เทส (D-32), รีพอร์ตผู้ใช้ยังไม่เทส (D-65) | `reviews` (ให้คะแนนผู้ขาย) Supabase+FlutterFlow ปิดครบแล้ว (D-64, 2026-08-24) — ยังไม่ทดสอบผ่านแอปจริง**

## 🎯 เป้าหมาย

ผู้ใช้รีพอร์ตสินค้า/ผู้ใช้ที่ไม่เหมาะสมได้ และให้คะแนนผู้ขายหลังธุรกรรมเสร็จได้

## 🧩 Supabase — `reports` ทำแล้ว (D-24/D-65), `reviews` ทำแล้ว (D-64)

`reports` (`reporter_id`/`reported_product_id`/`reported_user_id`/`reason`/`status`/`is_read`) + RLS จริง (insert ทุก authenticated, select เจ้าของ+admin) + CHECK `status` + CHECK ต้องมีเป้าหมายอย่างน้อย 1 อย่าง + CHECK กันรีพอร์ตตัวเอง (D-65) + unique partial index กันรายงานซ้ำตอนยัง pending (ทั้งสินค้าและผู้ใช้แยกกัน) + FK ทั้งคู่เป็น `ON DELETE SET NULL` — รายละเอียดคอลัมน์เต็ม `../SCHEMA.md`

`reviews` (`transaction_id`/`reviewer_id`/`reviewee_id`/`rating`/`comment`) ผูกกับ `transactions` (L5) โดยตรงแทน `product_id` ตรง ๆ ตาม draft เดิม — RLS insert เช็คว่าเป็นผู้ซื้อจริงของธุรกรรมนั้น (`EXISTS` เทียบ `transactions`) เท่านั้น + RESTRICTIVE กันผู้ถูกแบน + **ไม่มี UPDATE/DELETE เลย = immutable ตลอดไป** · SELECT public ให้ authenticated ทุกคนเห็น · `products_review_view` เพิ่ม 4 คอลัมน์คอมพิวต์ (`seller_avg_rating`/`seller_review_count`/`my_transaction_id`/`can_rate_seller`) — รายละเอียดเต็ม `../SCHEMA.md`, `../DECISIONS.md` D-64

`reports_admin_view` เพิ่ม `reported_user_id`/`reported_user_name`/`is_product_report`/`is_user_report` (D-65) — `is_product_report`/`is_user_report` เป็นตัวคุม `visible:` บน `ReportDetailContent` **และปิดช่องโหว่ crash แฝงจาก D-24 ไปด้วย** (force-unwrap `product_title!`/`seller_name!` แบบไม่มีเงื่อนไขเดิม ตอนนี้ครอบด้วย conditional แล้ว) รายละเอียด `../DECISIONS.md` D-65

## 🎨 FlutterFlow — ทำแล้ว

`ReportProductSheet` (ปุ่ม Report บน `ProductDetails` → insert `reports`) · `ReportsFeedback` (list สำหรับแอดมิน, เดิมชื่อ "Reports" — pete rename ตรงใน editor 2026-08-17, ตรวจแล้วไม่มีจุดอ้างชื่อเก่าหลงเหลือ) · `ReportDetail` (re-authored D-65 — แยกโชว์บล็อกสินค้า/ผู้ใช้ตามประเภทรายงาน + ปุ่ม "ระงับผู้ใช้รายนี้" ใหม่ reuse `banUserSheetRef`) · จุดแดง unread ผูก `is_read` (D-31) — **มีบั๊กเดียวกับ L4/L6: ไม่หายทันทีตอนกลับมาหน้าเดิม (D-32)**

`ReportUserSheet` (component ใหม่, D-65 — mirror `ReportProductSheet` เป๊ะ, param `userId`) · ปุ่ม "รายงานผู้ใช้" แทรกใน `UserProfileCard` (D-55's popup — ครอบคลุมทุกจุดเข้าถึงโปรไฟล์: `ProductDetails`/`BannedUsers`/`UserDirectory`) ผูก visibility ซ่อนตอนดูโปรไฟล์ตัวเองด้วย typed `visible: Not(Equals(...))` ล้วน ไม่ต้องใช้ raw proto (ต่างจาก D-51 เพราะทั้งสองฝั่งเป็น typed expression อยู่แล้ว)

`RateSellerSheet` (component ใหม่, D-64) — `Slider` 1-5 (ไม่มี `RatingBar` ที่ construct ได้จริงในระบบนี้) + comment `TextField` + ปุ่มยกเลิก/ส่ง · custom action `submitSellerReview` (0-arg, หา `transaction_id`/`seller_id` เองจาก `transactions` แล้ว insert `reviews` ตรง ไม่ผ่าน RPC) · ปุ่ม "ให้คะแนนผู้ขาย" บน `ProductDetails` ต่อจาก `ContactAdminButton` ผูก visibility เข้ากับ `can_rate_seller` ผ่าน `productField()`/`nodeKeyRef` เดิม (D-44/D-59) — โชว์เฉพาะผู้ซื้อจริงของสินค้าที่ขายแล้วและยังไม่เคยรีวิว

**ยังไม่ทำ (ตามคำตอบ pete):** แก้ไข/ลบรีวิวที่โพสต์แล้ว · แสดงคะแนนเฉลี่ยที่หน้าโปรไฟล์ผู้ขาย (ทำแค่บน `ProductDetails`) · หน้า "MyPurchases" แยก (จุดเข้าใช้ `ProductDetail` เดิม) · แยก tab/filter รายงานสินค้า vs ผู้ใช้บน `ReportsFeedback` list (list ยังโชว์รวมกัน แค่ `ReportDetail` แยกเนื้อหา)

## 🧪 Definition of Done

- [x] รีพอร์ตบันทึกจริง และ user ทั่วไปอ่านรีพอร์ตของคนอื่นไม่ได้ — ทดสอบ non-admin จริงแล้ว
- [x] admin เห็นรีพอร์ตทั้งหมด — ทดสอบผ่านแอปจริงแล้ว (pete, 2026-08-15)
- [x] รีวิวซ้ำ transaction เดิมไม่ได้ — `UNIQUE(transaction_id, reviewer_id)` + RLS insert เช็ค EXISTS ยืนยันจาก schema/RLS จริง **ยังไม่ทดสอบผ่านแอปจริง**
- [x] rating นอกช่วง 1-5 ถูกปฏิเสธที่ระดับ DB — `CHECK (rating BETWEEN 1 AND 5)`
- [x] รีพอร์ตผู้ใช้ซ้ำตอนยัง pending ไม่ได้ + รีพอร์ตตัวเองไม่ได้ — บังคับที่ระดับ DB (unique partial index + CHECK) ยืนยันจาก schema จริง **ยังไม่ทดสอบผ่านแอปจริง**
- [ ] จุดแดง unread หายทันทีตอนแตะ — มีบั๊ก stale-state (D-32) ยังไม่แก้
- [ ] + DoD ร่วมใน `CLAUDE.md`
- [ ] 🆕 (D-64) ทดสอบผ่านแอปจริงด้วย user ธรรมดา: ซื้อสินค้าจริง (ผ่าน `mark_product_sold`) แล้วเห็นปุ่ม "ให้คะแนนผู้ขาย" บน `ProductDetail`, ให้คะแนนสำเร็จ, กดซ้ำไม่ได้อีก (ปุ่มหาย/error), user อื่นที่ไม่ใช่ผู้ซื้อไม่เห็นปุ่มเลย, คะแนนเฉลี่ยโชว์ถูกต้อง
- [ ] 🆕 (D-65) ทดสอบผ่านแอปจริงด้วย user ธรรมดา: เปิดโปรไฟล์คนอื่น (ผ่าน `ProductDetails`/`BannedUsers`/`UserDirectory`) → เห็นปุ่ม "รายงานผู้ใช้", เปิดโปรไฟล์ตัวเอง → **ไม่เห็น**ปุ่มเลย, ส่งรายงานสำเร็จ, admin เปิด `ReportsFeedback`/`ReportDetail` → เห็นรายงานประเภทผู้ใช้แยกจากประเภทสินค้าถูกต้อง (ไม่ครอสกัน ไม่ว่างเปล่าผิดจุด), admin กด "ระงับผู้ใช้รายนี้" จาก report ประเภทผู้ใช้ → ใช้ `BanUserSheet` เดิมได้จริง

## ❓ ค้างอยู่

ไม่มี — P-09 ปิดแล้ว (D-65)
