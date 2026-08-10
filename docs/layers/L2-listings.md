# Layer 2 — Product Listings CRUD + Supabase Storage

> schema → `../SCHEMA.md` · pattern → `../PATTERNS.md` · ตรวจ → `../checks/L2.sql`

## 🎯 เป้าหมาย

ผู้ขายลงประกาศพร้อมรูปที่หน้า **`AddProduct`** · ดูของตัวเองที่ **`MyPost`** · ทุกประกาศต้องผ่าน Admin ที่ **`Inspect`** ก่อนเผยแพร่

> 🔴 **ก่อนเริ่มฝั่ง FlutterFlow อ่านนี่ก่อน:** `image_urls` เป็น array column — ถ้าจะเช็คเงื่อนไขจากมันหรือฟิลด์เดียวอื่นของ `products` ใน action chain (ไม่ใช่แค่แสดงผลทั้งแถวแบบ PT-03) มีบั๊ก SDK ที่เจอมาแล้วตอน L1 ที่จะเจอซ้ำแน่ ๆ — อ่าน `../PATTERNS.md` **PT-09** (custom action argument เสีย) และ **PT-10** (`PostgresQuery`/`FieldAccess` ดึงฟิลด์เดียวจากแถวไม่ได้) ก่อนเขียน Action Flow ไม่ใช่หลังชนบั๊กแล้วมางง

## 🧩 ขั้นตอน Supabase ที่เหลือ

- [x] สร้าง Storage bucket `product-images` + policy — **apply แล้ว 2026-08-08**
      public · 5 MB/ไฟล์ · jpeg-png-webp · 🔴 **path บังคับ `<currentUserId>/<ชื่อไฟล์>`** ไม่งั้นอัปไม่ผ่าน
      ค่าจริงทั้งหมด → `../SCHEMA.md` หัวข้อ Storage · เหตุผล → `../DECISIONS.md` **D-12** · วิธีทำใน FlutterFlow → `../PATTERNS.md` **PT-08**

**เหลืออย่างเดียว:** ยืนยันการอัปไฟล์จริงผ่านแอป — `file_size_limit` / `allowed_mime_types` บังคับที่ **Storage API** ทดสอบจาก DB แทนไม่ได้ (ดู `../VERIFICATION.md` V-08)

**ทำแล้ว:** schema ครบ · RLS allow-all · `products_review_view` · Realtime บน `products` · **seed `"CAT"` 12 หมวดหมู่แล้ว (id 1–12 ดู `../SCHEMA.md`)** · CHECK จำกัด `image_urls` ที่ 3 รูป

> ⚠️ dropdown หมวดหมู่ต้องอ่านตอน**ล็อกอินแล้ว**เท่านั้น — `anon` เห็น `"CAT"` เป็น 0 แถว (policy เป็น `TO authenticated`)

---

## 🎨 A. หน้า `addproduct` ⚠️ ชื่อจริงในโปรเจกต์ตัวเล็กล้วน ไม่ใช่ `AddProduct`

> 🟡 **2026-08-10 อัปเดต:** หน้านี้**มีอยู่แล้วจริง** ใน v2 (สร้างไว้ก่อน session นี้ โดยไม่มีใครบันทึกไว้ในเอกสาร — ดู doc drift note ใน `STATUS.md`) session นี้ผูก backend ให้ครบแล้วผ่าน `flutterflow ai run` บน `flutterflow-export/mju_market_v2/dsl/edit.dart`
> รายละเอียด/กับดักของ SDK ที่เจอตอนเขียน DSL นี้ทั้งหมดอยู่ที่ `PATTERNS.md` **PT-12** — ต้องอ่านก่อนแก้ไขหน้านี้ต่อทุกครั้ง
> ✅ **pete ทดสอบจริงแล้ว 2026-08-10: กด "ลงขายสินค้า" บันทึกเข้า `products` สำเร็จ** — เจอบั๊ก UI แยกต่างหาก (รูปพรีวิวหลังอัปขึ้นขาวเปล่า) แก้แล้วตาม PT-12 ข้อ 9 **แต่ยังไม่ได้ทดสอบซ้ำหลังแก้จุดนี้**

| widget key จริง | ชนิด | → คอลัมน์ |
|---|---|---|
| `Stack_s1nq0r5h`/`Stack_vdp8xsqu`/`Stack_361f48qw` (3 ช่องรูป, tap เพื่ออัป) | UploadData → Supabase | `image_urls` (text[]) — สะสมใน page state `uploadedImageUrls` แล้วส่งเข้า insert; รูปที่เพิ่งอัปโชว์พรีวิวจริงผ่าน page state แยกต่อช่อง `image1Url`/`image2Url`/`image3Url` (ต้อง set แยกจาก `uploadedImageUrls` เพราะ Image widget ผูกได้แค่ URL เดียวต่อช่อง ไม่ใช่ทั้ง list) |
| `TextField_rl5m9b8b` | ชื่อสินค้า | `title` |
| `TextField_gxb0yu0f` | รายละเอียด | `description` |
| `TextField_1egqbjvw` | ราคา | `price` (ผ่าน custom function `parseProductPrice`) |
| `TextField_kqo5qlgf` | เบอร์ติดต่อ | `contact_phone` |
| `ChoiceChips_viplbq3c` (มือหนึ่ง/มือสอง) | `condition` | ผ่าน custom function `mapProductCondition` — อ่านจาก page state `selectedConditionLabel` ไม่ใช่จาก widget ตรง ๆ (ดู PT-12 ข้อ 5) |
| `DropDown_b2e5c9nv` (จาก `"CAT"` 12 หมวดหมู่จริง) | `category_id` | ผ่าน custom function `parseCategoryId` — **map จาก label ไม่ใช่ parse ตัวเลข** (ดู PT-12 ข้อ 4 — `FlutterFlowDropDown` ไม่มี value list แยกจาก label) |
| `Button_85x7xhe6` ("ลงขายสินค้า") | submit | Insert Row เข้า `products`, `seller_id` ผูกกับ `AuthUser(userId)` เอง |

❗ **ไม่ต้องส่ง `moderation_status`** ปล่อยให้ default `'pending'` ทำงาน (ยืนยันจาก DSL script — ไม่ได้ส่งฟิลด์นี้)
❗ **UI ต้องกันที่ 3 รูปเอง** — DB กันไว้ด้วย CHECK แต่ถ้าปล่อยให้อัปครบ 4 ไฟล์ก่อน ผู้ใช้จะเสียเน็ตฟรีแล้วโดนปฏิเสธตอนกดบันทึก + เหลือไฟล์กำพร้าใน bucket (**ยังไม่ได้ทำ** — หน้านี้มีแค่ 3 ช่องพอดีอยู่แล้วจึงกันเองโดยธรรมชาติ แต่ยังไม่มี guard แยกถ้ามีคนแก้ layout เพิ่มช่องทีหลัง)

## 🎨 B. หน้า `MyPost`

Backend Query ผูก `products_review_view` filter `seller_id = currentUserId` — แสดงทุกแถวไม่ว่า `moderation_status` เป็นอะไร
+ เปิด **"Listen for realtime updates"** (ใช้ใน reject flow ข้อ D)

## 🎨 C. หน้า `Inspect` — Admin approve

1. **DataTable** ผูก `products_review_view` filter `moderation_status = 'pending'`
   คอลัมน์: รูปแรกจาก `image_urls` · `title` · `seller_name` · `moderation_status` (map เป็น "รออนุมัติ")
2. **กดแถว** → เปิด popup `MaterialCard` ส่ง Supabase Row ทั้งแถวเป็น parameter (**PT-03**)
3. **ใน `MaterialCard`** bind ครบ: รูปทั้งหมด, `title`, `description`, `price`, `contact_phone`, `condition`, `category_name`, `seller_name`
4. **ปุ่ม "ยืนยันอนุมัติ"** → Update Row `products` (ใช้ `id` จาก parameter) ตั้ง `moderation_status = 'approved'` → ปิด popup → DataTable query ใหม่เอง (แถวหายเพราะไม่ใช่ pending แล้ว)
5. **ปุ่ม "แชทกับผู้ขาย"** → ใช้ **PT-02** ส่ง `user_b = seller_id` จาก parameter

## 🎨 D. Reject flow

1. **ปุ่ม "ปฏิเสธ"** ใน `MaterialCard` → เปิด popup `reason` ส่ง product `id` ต่อไปให้
2. **ใน `reason`** — TextField เหตุผล + ปุ่มส่ง
3. **ปุ่มส่ง** → Update Row `products` ตั้ง `moderation_status = 'rejected'` + `rejection_reason = [TextField]` → ปิด popup ทั้งคู่
4. **ฝั่งผู้ขายที่ `MyPost`** — ใช้ **PT-04**: On Data Change เช็ค `moderation_status == 'rejected'` → เปิด popup `rejectAlert` ส่ง row เป็น parameter
5. **ใน `rejectAlert`** — แสดงแค่ `title` + รูปแรก + ปุ่มลบ → Delete Row `products`

⚠️ ข้อจำกัดของ PT-04: ผู้ขายต้องเปิดหน้า `MyPost` ค้างอยู่พอดีถึงจะเห็น popup — ถ้าปิดแอปจะเห็นแค่สถานะตอนเปิดครั้งถัดไป (แก้จริงต้องรอ Layer 6)

---

## 🧪 Definition of Done

- [ ] อัปรูปแล้วได้ path `<currentUserId>/...` จริง และรูปเปิดดูได้ผ่าน public URL ที่เก็บลง `image_urls`
- [ ] อัปไฟล์ **> 5 MB** และไฟล์ที่ไม่ใช่ jpeg/png/webp → ถูก Storage API ตีกลับ พร้อมข้อความที่ผู้ใช้เข้าใจ
- [ ] เลือกรูปที่ 4 → **UI กันเอง** ไม่ปล่อยให้อัปแล้วไปตายตอนกดบันทึก
- [ ] กด "ลงขายสินค้า" → row ใหม่ที่ `moderation_status = 'pending'` เสมอ และ `seller_id` ตรงกับคนที่ล็อกอิน
- [ ] `MyPost` เห็นประกาศตัวเองครบทุกสถานะ
- [ ] `Inspect` เห็นเฉพาะ pending พร้อม `seller_name` + `category_name` ถูกต้อง **ทุกแถว**
- [ ] กดอนุมัติ → `moderation_status = 'approved'` จริง และแถวหายจาก Inspect
- [ ] กด "แชทกับผู้ขาย" → เข้าห้องถูก และไม่สร้างห้องซ้ำถ้าเคยแชทแล้ว
- [ ] กดปฏิเสธ + กรอกเหตุผล → `rejection_reason` บันทึกจริง, ผู้ขายที่เปิด `MyPost` ค้างเห็น popup แบบ live และลบประกาศได้
- [ ] ประกาศที่ `moderation_status != 'approved'` **ไม่**โผล่ใน Browse สาธารณะ (เช็คตอนทำ L3)
- [ ] + DoD ร่วมใน `CLAUDE.md` โดยเฉพาะ **ทดสอบด้วย user ธรรมดา** ที่ดูประกาศคนอื่น

## ❓ ค้างอยู่

- จะบังคับ `category_id` ห้าม null ไหม
- ผู้ขายไม่ได้เปิดแอปตอน admin reject → รอ Layer 6 หรือปล่อย
- `Inspect` ยังกันด้วย UI เท่านั้น ไม่ใช่ RLS (`DECISIONS.md` D-03)
