# Layer 3 — Browse / Search / Filter

> schema → `../SCHEMA.md` · pattern → `../PATTERNS.md` · ตรวจ → `../checks/L3.sql`
> **สถานะ: 🟨 กำลังทำ** — `Home` (`AllList`) กรองตามหมวดหมู่ได้จริงแล้ว (D-37) + เป็น grid 2 คอลัมน์พร้อมรูปสินค้าจริงแล้ว (D-38) · `ProductDetails` โชว์รูปสินค้าจริงแล้ว + fallback icon เมื่อไม่มีรูป (D-42) + รูปที่ 2/3 โชว์แล้วผ่าน scaffold-level query แยกอิสระ (D-44) · ค้นหา (title, **exact match** — substring D-46 ใช้จริงไม่ได้ ถอนแล้ว D-48) + สุ่มลำดับสินค้า (`shuffle_key`) + pull-to-refresh เพิ่มแล้ว (D-45/D-48) ยังไม่มีช่วงราคา, ยังไม่มี empty-state UI (ลองแล้วไม่สำเร็จ D-46), ยังไม่ทดสอบผ่าน Live Test Mode ซ้ำหลัง D-48 — ดู `STATUS.md` คิวถัดไป

## 🎯 เป้าหมาย

ผู้ซื้อค้นหา/กรองสินค้าตามคำค้น หมวดหมู่ และช่วงราคาได้

## 🗄️ ใช้ของเดิม ไม่มีตารางใหม่

ใช้ `products_review_view` (`title`, `description`, `category_id`/`category_name`, `price`, `moderation_status`)

> 🔴 **ต้อง filter `moderation_status = 'approved'` เสมอ** ไม่งั้นสินค้าที่ยังไม่ผ่านตรวจจาก L2 จะโผล่สู่สาธารณะ

## 🧩 ขั้นตอน Supabase

**ตัดสินใจแล้ว (D-45):** built-in filter พอ ไม่สร้าง RPC `search_products` (P-05 ยังคงเป็นข้อเสนอค้าง ไม่ build) — เพิ่ม `products_review_view.shuffle_key` (`random()`) สำหรับสุ่มลำดับ + `products.title` มี GIN trigram index (`pg_trgm`, D-46) — **ยังไม่ได้ใช้จริง** เพราะค้นหาถอยกลับเป็น exact match (D-48) ไม่ได้ใช้ `ILIKE '%...%'` แล้ว index ยังอยู่เผื่ออนาคตถ้าจะทำ RPC

## 🎨 ขั้นตอน FlutterFlow

**`Home` — ทำแล้ว (D-45/D-48):**

- Search bar (`SearchField`) → Page State `searchQuery`, query ตอน submit เท่านั้น (ไม่ query ทุก keystroke)
- 🔴 **ค้นหาเป็น exact match เท่านั้น (D-48, ถอยจาก D-46's substring)** — `equalTo` เป็น relation เดียวที่ null-safe จริง (`iLike`/`like`/`contains` ไม่มี `...OrNull` variant เลย ผูกกับค่าไดนามิกแล้วได้ `dart analyze` error จริงตอน Live Test Mode) ดู D-48/PT-27 ข้อ 6
- "ค้นหาว่าง = โชว์ทุกอย่าง" ทำผ่าน `If(Equals(searchQuery, ''), then: [query ไม่มี title filter], orElse: [มี filter])` แทน trick `iLike('')` เดิมที่ใช้ไม่ได้แล้ว (D-48/PT-27 ข้อ 7)
- Category chip (เดิม, D-37/D-38/D-39) กับ search เป็นคนละแกน กดอันหนึ่งล้างอีกอันทิ้ง
- สุ่มลำดับ: `ORDER BY shuffle_key` แทน `created_at` ทุก query (onLoad/search/chip) — สุ่มฝั่ง Dart (custom function) ทำไม่ได้จริง ดู D-45/PT-27
- Pull-to-refresh บน grid → เรียก chain เดียวกับ search submit (เคารพคำค้น/หมวดหมู่ปัจจุบันแล้วสุ่มใหม่)
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
- [ ] 🆕 (D-45/D-48) ทดสอบผ่าน Live Test Mode + แอปจริงด้วย user ธรรมดา: **ไม่มี Analyzer Errors แล้ว** (ประเด็นที่ pete รายงาน), ค้นหาด้วยชื่อเป๊ะเจอจริง, pull-to-refresh ตอนไม่ได้ค้นหาโชว์ของครบ (ไม่ว่างเปล่า), สุ่มลำดับเปลี่ยนทุกครั้งที่โหลด/pull-to-refresh, กด chip ล้างคำค้น, ไม่มีสินค้า pending/rejected หลุดมาในผลค้นหา

## ❓ ค้างอยู่

- 🆕 (D-48) ค้นหาเป็น exact match เท่านั้น ไม่ใช่ substring — `iLike`/`like`/`contains` ผูกกับค่าไดนามิกไม่ได้เลยในระบบนี้ (ไม่มี null-safe codegen) ถ้าจะทำ substring จริงต้องออกนอก typed-filter ไปทำ RPC `search_products` (P-05) ผ่าน custom action แทน — ยังไม่ทำ รอ pete ตัดสินใจว่าคุ้มจะลงทุนไหม
- 🆕 (D-46) ไม่มี empty-state UI เมื่อค้นหาแล้วไม่เจอสินค้าเลย (grid ว่างเปล่าเฉย ๆ ) — ลองแก้ 2 วิธีแล้วไม่สำเร็จทั้งคู่ (backend ปฏิเสธ) ดู D-46/PT-27 "ทางที่ยังไม่ลอง" ถ้าจะกลับมาทำ
- ช่วงราคา (`priceMin`/`priceMax`) ยังไม่ทำ
