# Layer 3 — Browse / Search / Filter

> schema → `../SCHEMA.md` · pattern → `../PATTERNS.md` · ตรวจ → `../checks/L3.sql`
> **สถานะ: 🟨 กำลังทำ** — `Home` (`AllList`) กรองตามหมวดหมู่ได้จริงแล้ว (D-37) + เป็น grid 2 คอลัมน์พร้อมรูปสินค้าจริงแล้ว (D-38) · `ProductDetails` โชว์รูปสินค้าจริงแล้ว + fallback icon เมื่อไม่มีรูป (D-42) + รูปที่ 2/3 โชว์แล้วผ่าน scaffold-level query แยกอิสระ (D-44) · **ค้นหาเป็น substring จริงแล้ว + ช่วงราคาแล้ว (D-62/D-63, 2026-08-24) — ผ่าน RPC `search_products` ไม่ใช่ typed filter อีกต่อไป** สุ่มลำดับ (`ORDER BY random()` ใน RPC) + pull-to-refresh ยังทำงานผ่าน chain เดียวกัน ยังไม่มี empty-state UI (ลองแล้วไม่สำเร็จ D-46), ยังไม่ทดสอบผ่านแอปจริงหลัง D-62/D-63 — ดู `STATUS.md` คิวถัดไป

## 🎯 เป้าหมาย

ผู้ซื้อค้นหา/กรองสินค้าตามคำค้น หมวดหมู่ และช่วงราคาได้

## 🗄️ ใช้ของเดิม ไม่มีตารางใหม่

ใช้ `products_review_view` (`title`, `description`, `category_id`/`category_name`, `price`, `moderation_status`)

> 🔴 **ต้อง filter `moderation_status = 'approved'` เสมอ** ไม่งั้นสินค้าที่ยังไม่ผ่านตรวจจาก L2 จะโผล่สู่สาธารณะ

## 🧩 ขั้นตอน Supabase

**D-45 (built-in filter พอ, ไม่สร้าง RPC) กลับคำแล้ว — D-62 (2026-08-24, pete สั่งทำ):** สร้าง RPC `search_products(keyword, p_category_id, min_price, max_price)` จริง ปิดข้อเสนอ P-05 — `RETURNS SETOF products_review_view` (คอลัมน์ครบเหมือน view เดิมทุกตัว) ค้นหาทั้ง `title`/`description` ด้วย `ILIKE` (ใช้ trigram index เดิมของ `title`, D-46) + `category_id`/`price` range ในตัวเดียว ทุกพารามิเตอร์ optional — รายละเอียดเต็ม `../SCHEMA.md`

## 🎨 ขั้นตอน FlutterFlow

**`Home` — เขียนใหม่ทั้งหมดผ่าน RPC (D-62/D-63, 2026-08-24):**

- 🔴 **`iLike`/`like`/`contains` ไม่มี null-safe codegen เลยในระบบนี้ (D-46/D-48 confirmed)** — ทางแก้จริงคือออกจาก typed-filter ทั้งหมด ไปเรียก `search_products` RPC ผ่าน custom action **0-argument** (`searchProducts`) แทน เพราะ **`CallCustomAction` ส่ง argument ไม่ได้เลยใน SDK เวอร์ชันนี้ (PT-09)** — action อ่าน `keyword`/`categoryId`/`minPrice`(string)/`maxPrice`(string) จาก App State ก่อนเรียก แล้ว parse เอง (`double.tryParse`) ไม่พึ่ง DSL coerce
- **ยืนยันใหม่ (D-62):** `SetState` บนฟิลด์ `List<PostgresRow>` (`productsList`) **รับค่าจาก `CallCustomAction`'s `ActionOutput` ได้จริง** — ต่างจาก D-45 ที่พบว่ารับจาก custom **FUNCTION** ไม่ได้ (`CustomFunction(...)`, value-expression) การันตีจาก `generated_code/`: `_model.productsList = _model.xRpcV1!.toList().cast<ProductsReviewViewRow>();` compile ถูกทุกจุด — ดู `PATTERNS.md` PT-33 สำหรับ recipe เต็ม
- Search bar (`SearchField`) → Page State `searchQuery` (แสดงผลเฉยๆ) → submit (IME หรือปุ่ม "ค้นหา", D-50) เขียน `searchQuery` เข้า App State `searchKeyword` แล้วเรียก RPC — ล้าง `selectedCategoryId`/`searchCategoryId` เป็น 0
- Category chip (D-37/D-38/D-39) กับ search ยังเป็นคนละแกน กดอันหนึ่งล้างอีกอันทิ้ง (เหมือนเดิม) — ทุก chip (13 หมวด × 2 selected/unselected) เรียก RPC ผ่าน `homeCategoryTapActions` เดียวกัน
- **ช่วงราคาทำแล้ว (D-63)** — 2 `TextField` (`minPriceField`/`maxPriceField`, keyboard number) + ปุ่ม "กรอง" (`PriceFilterButton`) ต่อจากปุ่ม "ค้นหา" เขียนเข้า App State `searchPriceMin`/`searchPriceMax` (type **String** ไม่ใช่ Double — ดู PT-33) เป็น**แกนอิสระ**ไม่ล้างค่า keyword/category และไม่ถูกล้างโดยการค้นหา/กดหมวดหมู่ — คงอยู่จนกว่าจะกด "กรอง" ใหม่
- สุ่มลำดับย้ายจาก `shuffle_key` column ไปเป็น `ORDER BY random()` ใน RPC ตรง ๆ (เอฟเฟกต์เดียวกัน)
- Pull-to-refresh บน grid → เรียก chain เดียวกับ search submit (`buildSearchRefreshChain`) เหมือนเดิม เคารพ keyword/category ปัจจุบัน (price แยกแกนอยู่แล้วไม่ต้อง reset)
- 🔴 **empty-state UI ลองแล้วไม่สำเร็จ ถอนออกแล้ว** (D-46) — ทั้ง raw-proto `listLength()` condition และ custom-function-derived boolean state ถูก backend ปฏิเสธทั้งคู่ ดู D-46/PT-27 — **ยังไม่ลองรอบ 3**

**หน้า Browse อื่น (ยังไม่ทำ):**

- กดการ์ด → Navigate To `ProductDetail` ส่ง Row จาก `products_review_view` เป็น Page Parameter (**PT-03**)

**หน้า `ProductDetail`** *(ยืนยันชื่อหน้าแล้ว — ยังไม่ได้สร้างจริง)*

1. รับ Page Parameter แสดงเต็ม: รูป, `title`, `description`, `price`, `contact_phone`, `condition`, `category_name`, `seller_name` — **สร้างจริงแล้ว** รูปแรกผ่าน `ListView`/`item[]` เดิม (D-42) รูปที่ 2/3 ผ่าน scaffold-level query แยกอิสระ (D-44, `Row(scrollable: true)` ไม่ใช่ carousel widget) รวมสูงสุด 3 รูปครบตาม `image_urls`
2. **ปุ่ม "แชทกับผู้ขาย"** → **PT-02** (โค้ดเดียวกับ L2 เป๊ะ เปลี่ยนแค่บริบทจาก admin→seller เป็น buyer→seller)
3. (ถ้าต้องการ) ปุ่ม "จองสินค้า"/"สนใจ" → ต่อกับ Layer 5

## 🧪 Definition of Done

- [x] ค้นหา/กรองแล้วผลตรงกับข้อมูลจริงทุกกรณี (คำค้น / หมวดหมู่ / ช่วงราคา) — ทำแล้ว (D-62/D-63) ยืนยันจาก `generated_code/` **ยังไม่ทดสอบผ่านแอปจริง**
- [x] สินค้าที่ยังไม่ approved **ไม่โผล่**ในผลค้นหาเด็ดขาด — RPC filter `moderation_status='approved'` เสมอ (SCHEMA.md)
- [ ] กดการ์ด → `ProductDetail` ข้อมูลครบถูกต้อง
- [ ] ปุ่ม "แชทกับผู้ขาย" เข้าห้องถูก ไม่สร้างห้องซ้ำ
- [ ] + DoD ร่วมใน `CLAUDE.md`
- [ ] 🆕 (D-62/D-63) ทดสอบผ่านแอปจริงด้วย user ธรรมดา: ค้นหาแบบ substring จริงเจอ (ไม่ต้องพิมพ์เป๊ะ), ค้นหาจาก description ด้วยได้, กรองหมวดหมู่+ช่วงราคาพร้อมกันได้ (สองแกนไม่ล้างกัน), กดปุ่ม "กรอง" ราคาแล้วคงอยู่ตอนสลับหมวดหมู่/ค้นหาใหม่, ค่าราคาว่าง/ใส่ตัวอักษรไม่ crash (parse ล้มเหลว = ไม่กรอง), pull-to-refresh เคารพคำค้น/หมวดหมู่ปัจจุบัน, ไม่มีสินค้า pending/rejected/sold หลุดมาในผลค้นหา

## ❓ ค้างอยู่

- 🆕 (D-46) ไม่มี empty-state UI เมื่อค้นหาแล้วไม่เจอสินค้าเลย (grid ว่างเปล่าเฉย ๆ ) — ลองแก้ 2 วิธีแล้วไม่สำเร็จทั้งคู่ (backend ปฏิเสธ) ดู D-46/PT-27 "ทางที่ยังไม่ลอง" ถ้าจะกลับมาทำ — ยังไม่ลองรอบ 3 หลัง D-62 เปิดทางใหม่ (RPC คืน list เปล่าได้ตรงๆ อาจลอง `listLength()`/`ActionOutput` บน RPC output แทน custom function ได้ ยังไม่ได้ลอง)
