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

## 🎨 A. หน้า `AddProduct`

| widget | → คอลัมน์ |
|---|---|
| Upload รูป **สูงสุด 3 รูป** — ทำตาม **PT-08** | `image_urls` (text[]) |
| TextField ชื่อสินค้า | `title` |
| TextField รายละเอียด | `description` |
| TextField ราคา | `price` |
| TextField เบอร์ติดต่อ | `contact_phone` |
| ChoiceChip มือหนึ่ง/มือสอง | `condition` → map เป็น `'new'` / `'used'` |
| Dropdown หมวดหมู่ (จาก `"CAT"` แสดง `name` เก็บ `id`) | `category_id` |

**ปุ่ม "ลงขายสินค้า"** → Insert Row เข้า `products` + **ผูก `seller_id = currentUserId` เอง**
❗ **ไม่ต้องส่ง `moderation_status`** ปล่อยให้ default `'pending'` ทำงาน
❗ **UI ต้องกันที่ 3 รูปเอง** — DB กันไว้ด้วย CHECK แต่ถ้าปล่อยให้อัปครบ 4 ไฟล์ก่อน ผู้ใช้จะเสียเน็ตฟรีแล้วโดนปฏิเสธตอนกดบันทึก + เหลือไฟล์กำพร้าใน bucket

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
