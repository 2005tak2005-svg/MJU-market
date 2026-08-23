# Layer 5 — Transaction & Listing Status Management

> schema → `../SCHEMA.md` · ตรวจ → `../checks/L5.sql` · รายละเอียดเต็ม → `../DECISIONS.md` D-59
> **สถานะ: 🟨 Supabase ปิดครบ + FlutterFlow ปิดครบ (5 พุช) — ยังไม่ทดสอบผ่านแอปจริงโดย pete**

## 🎯 เป้าหมาย

เปลี่ยนสถานะสินค้าเป็น `sold` ได้จริงจาก `chatMessages` (เจ้าของเลือกประกาศของ
ตัวเองที่จะขายให้คู่สนทนาปัจจุบัน) พร้อมเก็บ log การขายที่ query ได้จริง

## 🗄️ ของที่มีอยู่จริงแล้ว

- `products.status` — `NOT NULL DEFAULT 'available'`, `CHECK IN ('available','reserved','sold')`, + `buyer_id uuid`
- ตาราง `transactions` (`product_id`/`buyer_id`/`seller_id`/`price`/`status`/`created_at`/`chat_id`) — RLS อ่านได้เฉพาะคู่ค้า/แอดมิน เขียนได้ทาง RPC เท่านั้น
- RPC `mark_product_sold(target_chat_id, target_product_id)` — SECURITY DEFINER, กัน race (PT-05), เขียน `transactions` ในฟังก์ชันเดียวกัน
- trigger `enforce_sale_via_rpc_only` — บล็อกการแก้ `status`/`buyer_id` ตรงบน `products` ไม่ว่าใคร ต้องผ่าน RPC เท่านั้น
- `products_review_view` เพิ่ม `buyer_id`/`buyer_name`/`can_see_buyer`
- `admin_sales_by_seller` repoint ไปอ้าง `transactions` แล้ว (เดิมอ้าง `products.status='sold'` ตรง ๆ)
- `chat_sale_status_view` (`chat_id`/`chat_already_sold`/`can_show_picker`) — คุมเงื่อนไขซ่อนปุ่ม "ปิดการขาย" ทั้ง 3 ข้อในที่เดียว

## 🎨 ที่ทำแล้วฝั่ง FlutterFlow

- `chatMessages`: ส่วน "ทำเครื่องหมายว่าขายแล้ว" (ฝังในหน้า ไม่ใช่ bottom sheet) — เลือกประกาศของตัวเองจาก list, ยืนยัน, เรียก RPC, refetch
- `Home` (`AllList`/onLoad/ค้นหา/category chip): กรอง `status != 'sold'` ครบทุกทาง
- `Mypost`: badge "ขายแล้ว" บนแถวที่ `status='sold'` (ไม่ต้องแก้ query — D-35 filter อยู่แล้วแค่ `seller_id`/`moderation_status`)
- `ProductDetails`: ส่วน `BuyerInfoSection` โชว์เฉพาะเจ้าของ/แอดมิน (`can_see_buyer`)
- `HomeAdmin`'s `SalesBySellerList` — ไม่ต้องแก้ DSL เลย ได้ข้อมูลจริงอัตโนมัติ

## 🧪 Definition of Done

- [x] เปลี่ยนสถานะสินค้าได้ถูกต้อง (impersonation test ผ่าน)
- [x] กดขายซ้ำ/race condition ถูกกันจริง (impersonation test ผ่าน — SQL level)
- [x] `moderation_status` ไม่ถูกเขียนทับโดย flow นี้ (แยก column เดิม ไม่แตะเลย)
- [ ] **ทดสอบผ่านแอปจริง** — ยังไม่เคยกดจริงในแอป ดู checklist ที่ `STATUS.md`

## ❓ ไม่มีคำถามค้างแล้ว

ตอบครบทั้ง 4 ข้อกับ pete แล้ว (ตำแหน่ง flow / การมองเห็นผู้ซื้อ / เงื่อนไขซ่อนปุ่ม / ปิดหนี้ D-03) รายละเอียด `DECISIONS.md` D-59
