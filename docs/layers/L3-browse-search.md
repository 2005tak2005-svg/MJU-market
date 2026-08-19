# Layer 3 — Browse / Search / Filter

> schema → `../SCHEMA.md` · pattern → `../PATTERNS.md` · ตรวจ → `../checks/L3.sql`
> **สถานะ: 🟨 กำลังทำ** — `Home` (`AllList`) กรองตามหมวดหมู่ได้จริงแล้ว (D-37) + เป็น grid 2 คอลัมน์พร้อมรูปสินค้าจริงแล้ว (D-38) · `ProductDetails` โชว์รูปสินค้าจริงแล้ว + fallback icon เมื่อไม่มีรูป (D-42) + รูปที่ 2/3 โชว์แล้วผ่าน scaffold-level query แยกอิสระ (D-44) · ค้นหา (title, substring/`%...%`) + trigram index + สุ่มลำดับสินค้า (`shuffle_key`) + pull-to-refresh เพิ่มแล้ว (D-45/D-46) ยังไม่มีช่วงราคา, ยังไม่มี empty-state UI (ลองแล้วไม่สำเร็จ D-46), ยังไม่ทดสอบผ่านแอปจริง — ดู `STATUS.md` คิวถัดไป

## 🎯 เป้าหมาย

ผู้ซื้อค้นหา/กรองสินค้าตามคำค้น หมวดหมู่ และช่วงราคาได้

## 🗄️ ใช้ของเดิม ไม่มีตารางใหม่

ใช้ `products_review_view` (`title`, `description`, `category_id`/`category_name`, `price`, `moderation_status`)

> 🔴 **ต้อง filter `moderation_status = 'approved'` เสมอ** ไม่งั้นสินค้าที่ยังไม่ผ่านตรวจจาก L2 จะโผล่สู่สาธารณะ

## 🧩 ขั้นตอน Supabase

**ตัดสินใจแล้ว (D-45):** built-in filter พอ ไม่สร้าง RPC `search_products` (P-05 ยังคงเป็นข้อเสนอค้าง ไม่ build) — เพิ่ม `products_review_view.shuffle_key` (`random()`) สำหรับสุ่มลำดับ + `products.title` มี GIN trigram index (`pg_trgm`, D-46) รองรับ substring search

## 🎨 ขั้นตอน FlutterFlow

**`Home` — ทำแล้ว (D-45/D-46):**

- Search bar (`SearchField`) → Page State `searchQuery`, query ตอน submit เท่านั้น (ไม่ query ทุก keystroke)
- ค้นหาแบบ substring จริงแล้ว (D-46): custom function `wrapSearchPattern(keyword) => '%$keyword%'` ผูกเป็น `value:` ของ `title` `iLike` filter (DSL ไม่มี string-concat expression ใช้ตรง ๆ ใน filter value ได้) — มี guard คำค้นว่าง/เว้นวรรคล้วน คืน `%%` (แมตช์ทุกแถว)
- Category chip (เดิม, D-37/D-38/D-39) กับ search เป็นคนละแกน กดอันหนึ่งล้างอีกอันทิ้ง
- สุ่มลำดับ: `ORDER BY shuffle_key` แทน `created_at` ทุก query (onLoad/search/chip) — สุ่มฝั่ง Dart (custom function) ทำไม่ได้จริง ดู D-45/PT-27
- Pull-to-refresh บน grid → เรียก chain เดียวกับ search submit (เคารพคำค้น/หมวดหมู่ปัจจุบันแล้วสุ่มใหม่) — เดิม (D-45 ก่อนแก้) ตอนไม่มีคำค้น pull-to-refresh จะโชว์ grid ว่างเปล่า (บั๊กจริง, แก้พร้อมกับ D-46)
- 🔴 **empty-state UI ลองแล้วไม่สำเร็จ ถอนออกแล้ว** (D-46) — ทั้ง raw-proto `listLength()` condition และ custom-function-derived boolean state ถูก backend ปฏิเสธทั้งคู่ ดู D-46/PT-27

**หน้า Browse อื่น (ยังไม่ทำ):**

- Price range slider → `priceMin` / `priceMax`
- กดการ์ด → Navigate To `ProductDetail` ส่ง Row จาก `products_review_view` เป็น Page Parameter (**PT-03**)

**หน้า `ProductDetail`** *(ยืนยันชื่อหน้าแล้ว — ยังไม่ได้สร้างจริง)*

1. รับ Page Parameter แสดงเต็ม: รูป, `title`, `description`, `price`, `contact_phone`, `condition`, `category_name`, `seller_name` — **สร้างจริงแล้ว** รูปแรกผ่าน `ListView`/`item[]` เดิม (D-42) รูปที่ 2/3 ผ่าน scaffold-level query แยกอิสระ (D-44, `Row(scrollable: true)` ไม่ใช่ carousel widget) รวมสูงสุด 3 รูปครบตาม `image_urls`
2. **ปุ่ม "แชทกับผู้ขาย"** → **PT-02** (โค้ดเดียวกับ L2 เป๊ะ เปลี่ยนแค่บริบทจาก admin→seller เป็น buyer→seller)
3. (ถ้าต้องการ) ปุ่ม "จองสินค้า"/"สนใจ" → ต่อกับ Layer 5

## 🧪 Definition of Done

- [ ] ค้นหา/กรองแล้วผลตรงกับข้อมูลจริงทุกกรณี (คำค้น / หมวดหมู่ / ช่วงราคา)
- [ ] สินค้าที่ยังไม่ approved **ไม่โผล่**ในผลค้นหาเด็ดขาด
- [ ] กดการ์ด → `ProductDetail` ข้อมูลครบถูกต้อง
- [ ] ปุ่ม "แชทกับผู้ขาย" เข้าห้องถูก ไม่สร้างห้องซ้ำ
- [ ] + DoD ร่วมใน `CLAUDE.md`
- [ ] 🆕 (D-45/D-46) ทดสอบผ่านแอปจริงด้วย user ธรรมดา: ค้นหาแบบคำบางส่วนเจอจริง, pull-to-refresh ตอนไม่ได้ค้นหาโชว์ของครบ (ไม่ว่างเปล่า), สุ่มลำดับเปลี่ยนทุกครั้งที่โหลด/pull-to-refresh, กด chip ล้างคำค้น, ไม่มีสินค้า pending/rejected หลุดมาในผลค้นหา

## ❓ ค้างอยู่

- 🆕 (D-46) ไม่มี empty-state UI เมื่อค้นหาแล้วไม่เจอสินค้าเลย (grid ว่างเปล่าเฉย ๆ ) — ลองแก้ 2 วิธีแล้วไม่สำเร็จทั้งคู่ (backend ปฏิเสธ) ดู D-46/PT-27 "ทางที่ยังไม่ลอง" ถ้าจะกลับมาทำ
- ช่วงราคา (`priceMin`/`priceMax`) ยังไม่ทำ
