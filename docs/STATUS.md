# STATUS.md — สถานะโปรเจกต์ + จุดเริ่ม session

> 📍 **เปิดไฟล์นี้เป็นไฟล์แรกของทุก session**
> อัปเดตล่าสุด: **2026-08-19**
> ✅ **D-44: `ProductDetails` โชว์รูปที่ 2/3 สำเร็จแล้ว** — เลี่ยง D-43's `ListView`/`item[]` ทั้งหมด ใช้ scaffold-level `databaseRequest` + `nodeKeyRef` แทน (เทคนิคเดียวกับ `ProfileUser`/`HomeAdmin`) — query แยกอิสระคนละตัวจาก list เดิม ไม่แตะ hero image/text fields เลย แสดงรูป 2/3 เป็น `Row(scrollable: true)` เคียงข้างกัน (ไม่ใช้ `Carousel`/`PageView` ตามที่ pete สั่ง) 🔴 เจอกับดักใหม่ระหว่างทำ: static `visible: false` ไม่ซ่อน widget จริงในโค้ดที่ export (ต้องใช้ conditional/`variable:`-based visibility เท่านั้น) แก้แล้วในพุชที่ 2 รายละเอียด `DECISIONS.md` D-44, pattern ใหม่ `PATTERNS.md` PT-26 — **ทดสอบผ่านแอปจริงโดย pete แล้ว — ผ่าน**
> ก่อนหน้า: **D-43: multi-photo carousel + tap-to-view บน `ProductDetails` ทำไม่สำเร็จด้วยวิธี `ListView`/`item[]`** — พบขีดจำกัดจริงของ FlutterFlow AI SDK 3 ข้อจาก itemBuilder เดียวกัน (isolate แยกทีละตัวแปรกว่า 20 พุช): (1) `item['field']` ใช้เป็น action param ไม่ได้เลยไม่ว่า action ไหน (2) `item[]` ผ่าน Dart helper function ไม่ได้ (3) 🔴 **มี `Image` widget ผูก `item[]` ได้แค่ 1 ตัวต่อ itemBuilder** — บล็อกทั้ง carousel และ tap-to-view เตรียม schema ไว้แล้ว (`second_image_url`/`third_image_url`/`has_second/third_image`) แต่ยังใช้ไม่ได้ รายละเอียด `DECISIONS.md` D-43, pattern ใหม่ `PATTERNS.md` PT-25
> ✅ **D-42: `ProductDetails` โชว์รูปสินค้าจริงแล้ว** — เดิมช่องรูปเป็น `Icon(Icons.image)` คงที่ ไม่เคยผูกกับข้อมูลเลยสักจุด (ซากจาก template เดิม) เพิ่ม `products_review_view.has_image` (boolean) แล้ว rebuild `ProductDetailsContent` itemBuilder ใหม่ทั้งก้อนผ่าน `ensureReplaced` (จำเป็นเพราะ `ItemRef()`/`item[]` ใช้นอก itemBuilder สดไม่ได้) — โชว์รูปจริงเมื่อมี, fallback icon เมื่อไม่มี (ไม่ crash) field อื่นทั้งหมดคัดลอกจาก `generated_code` เป๊ะ ไม่กระทบ รายละเอียด `DECISIONS.md` D-42 — **ยังไม่ได้ให้ pete ทดสอบผ่านแอปจริง**
> ก่อนหน้า 2026-08-18: **D-41: `chatMessages` bubble UI สองฝั่ง + ส่งรูปได้จริง** — เปลี่ยนจาก list คอลัมน์เดียวเป็น bubble ซ้าย/ขวา เพิ่มปุ่มแนบรูปเข้า bucket `chat-images` (มีอยู่แล้ว) + ดูรูปเต็มผ่าน component `FullImageViewer` (แตะ ไม่ใช่กดค้าง — DSL ไม่มี `onLongPress`) แก้บั๊ก null-crash (`has_message`/`has_image` ใน view แทนเทียบ `== ''`) + ComposeBar ไม่ติดขอบล่าง (`Expanded` แทน `shrinkWrap`) + `outputAs` ชนกันข้าม widget รายละเอียด `DECISIONS.md` D-41, pattern ใหม่ `PATTERNS.md` PT-24 — **ทดสอบผ่านแอปจริงโดย pete แล้วทั้งหมด**
> ✅ **D-40: แก้ `chatList` ว่างเปล่า — เป็น layout crash ไม่ใช่บั๊ก RLS/data** — pete รายงานพร้อม console log (`Assertion failed: box.dart:2251` ซ้ำๆ) ตรวจ Supabase (db-verifier ยืนยัน `chat_summary` คืนแถวถูกต้อง) + widget binding ก่อนแล้วพบว่าถูกทั้งคู่ ตัวปัญหาจริงคือ `ChatListItems` (ListView) เป็นลูก `Column` โดยไม่ได้ห่อ `Expanded` และไม่ได้ตั้ง `shrinkWrap` → unbounded height ทำให้เรนเดอร์อะไรไม่ได้เลยไม่ว่าจะมีข้อมูลกี่แถว แก้ด้วย `shrinkWrap: true` (raw proto, ไม่มี typed/fast-lane op) ยืนยันจาก `generated_code/` แล้ว รายละเอียด `DECISIONS.md` D-40 — **ยังไม่ได้ให้ pete ทดสอบซ้ำ**
> ✅ **D-39: Filter chip highlight ตามการเลือกจริงแล้ว** — บั๊กหลัง D-37: filter ทำงานถูกแต่สี chip ไม่เปลี่ยนตามที่กด (`Button.color` เป็น static, ไม่ผูก state) แก้ด้วยคู่ Button (selected/unselected) สลับด้วย `visible: Equals(...)`/`Not(...)` — typed DSL ล้วน ไม่มี raw proto ยืนยันจาก `generated_code/`: `if (_model.selectedX == N) Button(...)` ครบทุก chip ทั้ง `Home`/`Mypost` รายละเอียด `DECISIONS.md` D-39 — **ยังไม่ทดสอบผ่านแอปจริงโดย pete**
> ✅ **D-38: `Home` AllList เป็น GridView 2 คอลัมน์แบบ e-commerce แล้ว** — เปลี่ยนจาก `ListView` แถวเดียว ไม่แตะกลไก filter เดิมเลย (onLoad + 13 category chip ยังยิง query เหมือนเดิม) เพิ่มคอลัมน์ `first_image_url` (`image_urls[1]`) เข้า `products_review_view` เพราะ DSL ไม่มี list-index operator ยืนยันจาก `generated_code/`: `GridView.builder` + รูปจริงผูกแล้ว รายละเอียด `DECISIONS.md` D-38 — **ยังไม่ทดสอบผ่านแอปจริงโดย pete** โดยเฉพาะเคสสินค้าไม่มีรูป (ยังไม่มี placeholder)
> ✅ **D-37: Category/Status filter chips ใช้งานได้จริงทั้งคู่แล้ว** — บั๊กจริงคือ `Chip` widget (D-36) ห่อ `InkWell.onTap` รอบ Material `ChoiceChip` ที่มี gesture handler ของตัวเองอยู่แล้ว สองอันแย่ง tap กัน แก้ด้วยการเปลี่ยนเป็น `Button` ทั้ง `Home`/`Mypost` (ยืนยันจาก `generated_code/`: `FlutterFlowChoiceChips` เหลือ 0 จุด) `Mypost` ยังย้ายจาก widget-level query ไปเป็น onLoad+state pattern แบบ `Home` เพื่อให้ status chip กรอง list ได้จริง (เดิมติด platform limitation ตาม D-36) รายละเอียดเต็ม `DECISIONS.md` D-37 — **ยังไม่ทดสอบผ่านแอปจริงโดย pete**
> ✅ **D-35: แก้ filter `seller_id` ของ `Mypost`** — เดิม widget-level query ไม่มี filter เลย (D-32 ข้อ 5) เพิ่ม `seller_id = currentUserUid` ผ่าน `page.mutateNode` บน `ListView_7h86cihf` ยืนยันจาก `generated_code/` แล้วว่า query เปลี่ยนจริง รายละเอียด `DECISIONS.md` D-35 — **ยังไม่ทดสอบผ่านแอปจริง**
> ✅ **D-34: L1 confirm-email (D-20) ปลดล็อกจริง** — เลิกส่ง OTP ตรงถึง student เปลี่ยนเป็น Send Email Hook → Edge Function `send-otp-email` → Resend → relay เข้า admin inbox เดียว ยืนยัน end-to-end สำเร็จผ่านแอปจริงแล้ว (`mju6606105382@mju.ac.th`) รายละเอียด+กับดัก `DECISIONS.md` D-34 — **หนี้ที่เหลือ:** manual relay ไม่ scale, rate limit email 30/ชม. เป็นค่าดีบักชั่วคราว ทั้งคู่ต้องแก้ก่อน production
> ✅ **D-33: ปิดช่องโหว่ `admin_sales_by_seller`** — เพิ่ม `AND private.is_admin()` ในตัว view เอง ไม่พึ่ง RLS ของ `products` (allow-all, D-03) อีกต่อไป ยืนยันด้วย impersonation test จริง (user ธรรมดา 0 แถว, admin เห็นถูกต้อง) รายละเอียด `DECISIONS.md` D-33 — ปิดข้อ 2 ของคิว D-32 แล้ว เหลือ 4 ข้อ
> 🔴 **D-32: DoD audit ทั้งโปรเจกต์ (db-verifier + ui-checker คู่ขนาน) พบบั๊กจริง 4 จุด** — (1) L1: 2 บัญชี `auth.users` ไม่มีแถวใน `"Profile"` เลย ~~(`mju6606105382`/`mju6606105386`)~~ **`mju6606105382` แก้แล้ว (ลบบัญชีเก่า สมัครใหม่สะอาด, D-34) เหลือ `mju6606105386` ยังค้าง** (สาเหตุเดิมยังไม่ทราบ — สมัครปกติรอบล่าสุดไม่เจอบั๊กนี้ซ้ำ) (2) ~~L8: `admin_sales_by_seller` ไม่มี admin gate~~ **ปิดแล้ว (D-33)** (3) L4: ยืนยันแล้วว่า Realtime ไม่มีเลย ไม่ใช่แค่ "ยังไม่ยืนยัน" (4) จุดแดง unread (D-31) มีบั๊ก stale-state บน `chatList`/`Notifications`/`ReportsFeedback` — ไม่หายจนกว่าจะออกจากหน้าจริง (5) `MyPost` มีอยู่แล้วจริง (ไม่ใช่ "ยังไม่สร้าง") query ไม่ filter `seller_id` เลย โชว์ของทุกคน ~~— แก้แล้ว (D-35)~~ รายละเอียด `DECISIONS.md` D-32
> ก่อนหน้า 2026-08-17: **D-31: จุดแดง glow บอกยังไม่อ่าน (หายเมื่อแตะ) บน `chatList`/`Notifications`/`ReportsFeedback`** — `chat_user.last_read_at` (ต่อสมาชิก) + `chat_summary.is_unread`, `reports.is_read` + RPC `mark_chat_read`/`mark_report_read` (บล็อก non-admin จริง) 🔴 พบว่า pete rename หน้า "Reports" เป็น "ReportsFeedback" ตรงใน FlutterFlow editor ทำให้ `ensurePage('Reports', ...)` เดิมเกือบสร้างหน้าซ้อน (จับได้ตอน push fail แก้แล้ว) รายละเอียด `DECISIONS.md` D-31
> ก่อนหน้า 2026-08-16: **D-29/D-30: L4 (chat) เริ่มและปิด Supabase ฝั่งสมบูรณ์ + FlutterFlow ฝั่งข้อความล้วนใช้งานได้จริงครบ 3 ทางเข้า** — RLS membership-based (เดิม allow-all), `find_or_create_chat`/`find_or_create_chat_with_admin`/`is_chat_member`/`get_my_chats` + trigger auto-update `last_message`, รองรับส่งรูปที่ schema (ยังไม่ทำฝั่ง UI), `chatList` ผูกข้อมูลจริง + หน้า `chatMessages` ใหม่ + ปุ่ม "แชทกับผู้ขาย" บน `ProductDetails` + ปุ่ม "ติดต่อแอดมิน" ต่อจริงแล้ว (D-30) + ทางเข้า `chatList` ใน `HomeAdmin` drawer (D-30) รายละเอียด `layers/L4-chat.md` + `PATTERNS.md` PT-09/PT-22/PT-23
> ก่อนหน้า 2026-08-15: D-24–D-27 (reject-flow, reports, addproduct flash bug, ContactAdminButton) ทดสอบผ่านแอปจริงโดย pete แล้ว
> ก่อนหน้า 2026-08-14: auth backend = Supabase (D-21) · L8 `HomeAdmin` approve/reject + `notifications` table + `Notifications` page + bell icon (D-22/D-23)
---

## 🔥 คิวถัดไป

1. **[D-32] `mju6606105386@mju.ac.th` ยังค้าง — ตัดสินใจว่าจะลบหรือปล่อยไว้** — สมัครไม่สำเร็จ (ไม่เคยยืนยันอีเมล) ไม่มี `"Profile"` คู่ `mju6606105382` แก้ไปแล้วด้วยการลบบัญชีเก่า+สมัครใหม่สะอาด (D-34) — ทางเดียวกันน่าจะใช้ได้ ไม่ใช่คิวด่วนแล้ว (root cause เดิมของ D-32 ยังไม่ทราบ แต่ไม่เกิดซ้ำในรอบทดสอบล่าสุด)
2. ~~**ทดสอบ L4 (chat) ผ่านแอปจริง**~~ **ทดสอบแล้ว (D-40/D-41, 2026-08-18)** — `chatList` ขึ้นถูก, ส่งข้อความ/รูปได้จริง, bubble UI ถูกฝั่ง, ComposeBar ติดขอบล่าง, ดูรูปเต็มได้ — เหลือแค่จุดแดง unread ที่**รู้อยู่แล้วว่าไม่หายทันที ต้องออกจากหน้าก่อน (บั๊ก stale-state, D-32, ยังไม่แก้)** ไม่ต้องรายงานซ้ำถ้าเจอ
3. ~~**L4: ทำส่งรูปภาพ**~~ **แก้แล้ว (D-41, 2026-08-18)** — เหลือ **Realtime** (ยืนยันว่าไม่มีเลย D-32, ยังไม่ทำ)
4. ~~**[D-32] แก้ filter ของ `MyPost`**~~ **แก้แล้ว (D-35, 2026-08-18)** — เหลือทดสอบผ่านแอปจริงด้วย user ธรรมดาที่มีประกาศหลายสถานะ (pending/approved/rejected) ว่าเห็นเฉพาะของตัวเองจริง
5. ~~**[D-36] ทำให้ status chip บน `Mypost` กรอง list จริง**~~ **แก้แล้ว (D-37, 2026-08-18)** — ย้าย `Mypost` ไป onLoad+state pattern แบบ `Home` เหลือทดสอบผ่านแอปจริงว่ากด chip แล้ว list กรองถูกต้องจริง (category ของ `Home` ด้วย)
6. **[D-38/D-39] ทดสอบ `Home` grid layout + filter chip highlight ผ่านแอปจริง** — ยังไม่เคยเปิดแอปดูทั้งคู่ เช็ค: การ์ดจัดเรียง 2 คอลัมน์ไม่ถูกตัด, กดการ์ดยังเข้า `ProductDetails` ถูก, กด chip แล้วสี highlight ตามจริงทั้ง `Home` (หมวดหมู่)/`Mypost` (สถานะ) — 🔴 **สินค้าไม่มีรูปบน `Home` ยัง crash ได้จริง** (`firstImageUrl!` force-unwrap ไม่มี fallback) `products_review_view.has_image` มีแล้ว (D-42, ทำไว้ให้ `ProductDetails`) แค่ยังไม่เอาไปใช้กับ `Home` grid — ทำตอนเจอปัญหานี้จริงหรือก่อน production
7. ~~**[D-42/D-44] `ProductDetails` โชว์รูปสินค้าจริงแล้ว (รูปแรก + รูปที่ 2/3)**~~ **ทดสอบผ่านแอปจริงโดย pete แล้ว — ผ่าน (2026-08-19)**

🟡 **ไม่ใช่คิวด่วนแต่ยังไม่ปิด — L1 confirm-email production-readiness** ดู `DECISIONS.md` D-34 หัวข้อหนี้

---

## สถานะ 8 Layers

| L | ชื่อ | Supabase | FlutterFlow | หมายเหตุ |
|---|---|---|---|---|
| 1 | Auth & User Profiles | ✅ ปิดแล้ว 🔴 พบ 2 บัญชีไม่มี `Profile` (D-32) | 🟨 Login/SignUp/Home/HomeAdmin/`ProfileUser` ทำงานจริง เหลือ Confirm Email (D-20) | auth backend = Supabase แล้ว (D-21) · OTP ติด email deliverability |
| 2 | Product Listings + Storage | 🟨 อัปจริงผ่านแอปแล้ว เหลือเทส reject >5MB/ผิดชนิด | 🟨 `addproduct` insert ผ่านแอปจริง + แก้บั๊กแฟลชไป Login (D-26) · `MyPost` filter `seller_id` แก้แล้ว (D-35) + status chip กรอง list จริงแล้ว (D-37) ยังไม่ทดสอบผ่านแอปจริง | seed `CAT` 12 หมวด · bucket+policy+CHECK 3 รูป · อ่าน PT-09/10/12 ก่อนเริ่ม |
| 3 | Browse / Search / Filter | ⬜ | 🟨 `AllList`+`ProductDetails` ทำแล้ว · category filter chip requery จริงแล้ว (D-37) · `AllList` เป็น grid 2 คอลัมน์ + รูปจริงแล้ว (D-38) ยังไม่ทดสอบผ่านแอปจริง · `ProductDetails` โชว์รูปจริง + fallback icon แล้ว (D-42) ยังไม่ทดสอบผ่านแอปจริง | ผูก `products_review_view` ยังไม่มี search · `Home` grid สินค้าไม่มีรูปยัง crash ได้ (`firstImageUrl!` ไม่มี fallback, ต่างจาก `ProductDetails` แล้ว) |
| 4 | Chat & Messaging | ✅ RLS membership-based + RPC/trigger ทดสอบสิทธิ์จริงผ่านแล้ว (D-29/D-30) | 🟨 3 ทางเข้า + Drawer nav, ข้อความ+รูป+bubble UI ใช้ได้จริง **ทดสอบผ่านแอปจริงแล้ว (D-40/D-41)** | ยังไม่มี Realtime (D-32) · จุดแดง unread มีบั๊ก stale-state (D-32) · อ่าน PT-06/09/22/23/24 ก่อนแตะต่อ |
| 5 | Transaction & Status | ⬜ ไม่มีตาราง `transactions` | ⬜ | |
| 6 | Notifications | 🟨 ตาราง+RLS apply แล้ว | 🟨 `Notifications` page + bell icon + link ไป `ProductDetails` (D-26) + จุดแดง unread (D-31, มีบั๊ก stale-state D-32) | เขียนได้ทางเดียว: reject→insert · ไม่มี realtime/push จริง |
| 7 | Reviews & Reports | 🟨 `reports` RLS+constraint เสร็จ (D-24) + `is_read` (D-31) · `reviews` ยังไม่มี | 🟨 `ReportProductSheet`/`ReportsFeedback`/`ReportDetail` + จุดแดง unread (D-31, มีบั๊ก stale-state D-32) — เนื้อหาหลัก**ทดสอบผ่านแอปจริงแล้ว (pete, 2026-08-15)** | หน้า "Reports" ถูก pete rename เป็น "ReportsFeedback" ตรงใน editor (2026-08-17) — ตรวจแล้วไม่มีจุดอ้างชื่อเก่าค้าง |
| 8 | Admin Dashboard | 🟨 เริ่มแล้ว 2026-08-14 · `admin_sales_by_seller` gate ปิดแล้ว (D-33) | 🟨 `HomeAdmin` ผูกข้อมูลจริง + approve/reject ใช้งานได้ | trigger คุ้มกัน moderation 2 คอลัมน์ (D-23) เหลือ RLS admin-only เต็มรูปแบบ (`products` คอลัมน์อื่น), `"CAT"` CRUD |

✅ เสร็จ · 🟨 กำลังทำ · ⬜ ยังไม่เริ่ม — คอลัมน์ FlutterFlow คือสถานะใน **v2** (`m-j-u-market-v2-0xhjhg`) เท่านั้น งานฝั่ง v1 (archived) ไม่นับ (D-16)

> 🔴 **กฎการให้ ✅:** "ตารางว่าง 0 แถว = ยังไม่ PASS" — นับเป็น ✅ ได้ต่อเมื่อทดสอบด้วย user ธรรมดาจริงแล้วเท่านั้น

**L1** ปิดฝั่ง Supabase แล้ว (2026-08-09) · FlutterFlow ค้างที่ Confirm Email — ลิงก์ (D-19) ใช้ไม่ได้เพราะ Microsoft Safe Links ดึง token ทิ้งก่อนคนกด → เปลี่ยนเป็น OTP (D-20) แต่อีเมลไปไม่ถึงกล่อง (deliverability ฝั่ง tenant) รายละเอียด `DECISIONS.md` **D-20** · 🔴 พบ 2 บัญชีจริงที่ `handle_new_user()` ไม่ทำงาน (D-32) ยังไม่ปิดสนิท

**L2** ปิดไม่ได้เพราะยังไม่เคยเทสอัปไฟล์เกิน 5MB/ผิดชนิดผ่านแอปจริง (บังคับที่ Storage API ไม่ใช่ Postgres ทดสอบจาก DB แทนไม่ได้) — อัปสำเร็จ + path ถูกต้องยืนยันแล้ว (`VERIFICATION.md` V-08)

**L4** Supabase ปิดแล้ว (D-29, 2026-08-16) — `chat_summary.member_names` พิสูจน์แล้วว่าไม่เป็น NULL ด้วย user ธรรมดาจริง (มีห้องแชท 1 ห้อง 2 สมาชิกจากการทดสอบ) FlutterFlow ปิดไม่ได้เพราะยังไม่มี Realtime — ข้อความ/รูป/bubble UI ทดสอบผ่านแอปจริงแล้ว (D-40/D-41) รายละเอียด `layers/L4-chat.md`

---

## ❓ คำถามที่ยังไม่ตัดสินใจ (รวมทุก layer)

**🔴 รอ pete ตอบ**
1. **D-20 — OTP เสร็จ ติด email deliverability** ดู `DECISIONS.md` **D-20** — ไม่ใช่คำถามค้าง เป็นบล็อกทางเทคนิค
2. **รับข้อเสนอ P-11/P-12 ไหม** — unique index บน `lower(email)` + เก็บกวาดไฟล์กำพร้า ยังไม่ตอบรับ อยู่ใน `PROPOSED_SQL.md`

**Layer 1** — role-based redirect ที่ Splash/Initial (auto-login) ด้วยไหม · `handle_new_user()` ยังไม่มี `ON CONFLICT`

**Layer 2** — เปิด browse ก่อนล็อกอินไหม (ต้องเพิ่ม policy ให้ `anon` ทั้ง `"CAT"`/`products`) · บังคับ `category_id` ห้าม null ไหม

**Layer 3** — FlutterFlow built-in filter พอไหม หรือต้องสร้าง RPC `search_products` (P-05)

**Layer 4** — ตอบแล้วทั้งหมด (D-29): realtime ต้องฟังที่ table `chat_message` ไม่ใช่ view (ยังไม่ได้ต่อจริง), ไม่ต้อง array-contains เพราะ RLS กรองให้แล้ว, trigger auto-update `last_message` apply แล้ว — คำถามใหม่ที่เหลือ: จะแก้ปุ่ม "แชทกับผู้ขาย" ให้ส่ง `memberNames`/`userIds` ได้ไหม (ดู `layers/L4-chat.md` ข้อ 3-4)

**Layer 5** — ต้องการ `status` กี่แบบจริง ๆ, เก็บประวัติ transaction แยกไหม หรือใช้ `products.status` พอ

**Layer 6** — ยังไม่ทำ: notification จาก `chat_message` insert (P-04), unread badge, realtime

**Layer 7** — รองรับรีพอร์ต "ผู้ใช้" ด้วยไหม (P-09) · `reviews` ใช้ RLS allow-all หรือ restrictive

**Layer 8** — RLS admin-only เต็มรูปแบบยังไม่ทำ (`products` ยัง allow-all, D-03 — `chat`/`chat_user`/`chat_message` ปิดหนี้นี้แล้ว D-29) · หน้า `Inspect` แยกยังไม่มีใน v2 (คิวรอตรวจอยู่ใน `HomeAdmin` มีปุ่มอนุมัติ/ปฏิเสธจริงแล้ว) · `"CAT"` ยังจัดการผ่าน UI ไม่ได้ ต้อง seed ด้วยมือ · `admin_sales_by_seller` อ้าง `products.status='sold'` ชั่วคราวเพราะยังไม่มี `transactions` (L5) — ถ้า L5 เริ่มจริงต้องตัดสินใจย้ายไปอ้าง `transactions` ไหม

---

## 💣 หนี้ทางเทคนิคที่ต้องใช้คืนก่อน production

- [ ] 🆕 **[D-32] 2 บัญชี `auth.users` ไม่มีแถวใน `"Profile"`** (`mju6606105382@mju.ac.th` ยืนยันอีเมลแล้ว ใช้แอปไม่ได้ตอนนี้ + `mju6606105386@mju.ac.th`) — สาเหตุยังไม่ทราบ ไม่มี UNIQUE ชนกัน ดู `layers/L1-auth-profile.md`
- [ ] 🆕 **[D-32] จุดแดง unread (D-31) มีบั๊ก stale-state** บน `chatList`/`Notifications`/`ReportsFeedback` — ไม่หายทันทีตอนกลับมาหน้าเดิม (list ไม่ refetch ก่อน navigate ออก) ต้องออกจากหน้าจริงก่อนถึงจะหาย — ดู `layers/L4-chat.md` ข้อ 3
- [ ] `products` เป็น allow-all RLS นอกเหนือ 2 คอลัมน์ moderation — non-admin ยัง `UPDATE`/`DELETE` คอลัมน์อื่น (ราคา/รูป/ชื่อ) ของสินค้าคนอื่นได้ (คิวอนุมัติเองถูกปิดแล้วจริงด้วย trigger `enforce_moderation_admin_only`, D-23 — ยืนยัน live ว่าบล็อก non-admin จริง `chat`/`chat_user`/`chat_message` ก็ปิดหนี้นี้แล้ว D-29)
- [ ] ไม่มีระบบกันกดปุ่มลบซ้ำ/popup ค้างใน reject flow (ยอมรับเป็น MVP)
- [ ] `"Profile".id` มี default `gen_random_uuid()` ทั้งที่เป็นคอลัมน์ FK — ควรถอด default ออก (ยังไม่ทำ)
- [ ] ข้อมูลทดสอบค้างใน DB: `"Profile"` มี 7 แถว — 4 แถวมี `full_name` ปลอม (`ทดสอบ นักศึกษาหนึ่ง/สอง/สาม`, `สมชาย ใจดี`) ต้องล้างก่อน production
- [ ] 🆕 **พบบัญชี admin `mju6500000001@mju.ac.th` ที่ไม่มีบันทึกที่มา** (ตรวจพบ 2026-08-15 ตอน sync เอกสาร) — `created_at` = `email_confirmed_at` เป๊ะ (ไม่ผ่าน OTP flow จริง เพราะ confirm-email ยังไม่เคยทำงาน) ไม่อยู่ในตารางบัญชีทดสอบด้านล่าง — ต้องหาว่าใครสร้าง/ทำไม แล้วบันทึกหรือลบทิ้ง
- [ ] `"CAT"` ไม่มี UNIQUE บน `name` — seed ซ้ำได้
- [ ] `"Profile".is_banned` มีคอลัมน์แล้วแต่ไม่มี enforcement เลย — login/โพสต์/แชทได้ปกติแม้ `is_banned = true` ยังไม่มี UI ให้แอดมินกดแบน (แก้ได้แค่ผ่าน SQL ตรง ๆ)
- [ ] ไฟล์กำพร้าใน `avatars`/`product-images` — เปลี่ยน/ลบแล้วไฟล์เก่าไม่ถูกลบ (D-15) ยังไม่มีระบบเก็บกวาด (P-12 ยังไม่เลือกแนวทาง)
- [ ] รูปของประกาศ `pending`/`rejected` เปิดดูได้ถ้ารู้ URL (public bucket, D-12) — ห้ามเก็บของอ่อนไหวในนี้
- [ ] `Profile_email_key` เป็น unique ธรรมดา ไม่ใช่ index บน `lower(email)` — ยังไม่มีปัญหาจริงเพราะ trigger `lower()` ให้ก่อน insert (P-11 ยังไม่ตอบรับ)
- [ ] repo private (D-13) ไม่ใช่การปิดช่องโหว่ — ของจริงที่ต้องปิดคือ 2 ข้อบนสุดของรายการนี้

**บัญชีทดสอบที่ credential ถูกแก้ตรงด้วย SQL (ไม่ใช่สภาพ user จริง — ห้ามใช้เทสอย่างอื่นโดยไม่รู้ตัว):**

| อีเมล | role | แก้อะไร | ใช้เทสอะไรได้ | ห้ามเทส |
|---|---|---|---|---|
| `mju6577778888@mju.ac.th` | admin | `email_confirmed_at` patch ด้วย SQL | auth/role routing, ทุก layer อื่น | "สมัครแล้วต้องยืนยันอีเมล" |
| `mju6512345678@mju.ac.th` | user | `encrypted_password` เขียนทับด้วย SQL | Test Pilot login | เหมือนกัน |
| `mju6500000002@mju.ac.th` (สร้าง 2026-08-15) | user | insert ตรงเข้า `auth.users`+`auth.identities` (PT-20) | L7 report-a-listing ด้วย non-admin | "สมัครแล้วต้องยืนยันอีเมล" |

🔴 **บัญชีทดสอบสดสำหรับ confirm-email เดิมถูกลบไปแล้ว 2026-08-10** (`mju6500000099`+อีก 3 บัญชี) — ไม่มีบัญชีสดพร้อมใช้ ต้องสมัครใหม่เมื่อกลับมาทำ D-20 ต่อ

---

## 📋 แม่แบบเปิด session กับ Claude Code

```
[git pull ก่อนเสมอ]
Layer ที่ทำอยู่: [เช่น Layer 1 — trigger auto-insert Profile]
อ่านก่อน: CLAUDE.md → docs/STATUS.md → [ไฟล์ตามตาราง router ใน CLAUDE.md]
Supabase objects ที่เกี่ยวข้อง: [ชื่อ table/column/FK จริง — ดู docs/SCHEMA.md ห้ามพิมพ์จากความจำ]
FlutterFlow page/state ที่เกี่ยวข้อง: [ชื่อ Page, Page/App State, widget parameter]
สิ่งที่ต้องการ: [ระบุให้ชัด]
Error / screenshot Action Flow (ถ้ามี): [แนบ]
```

> ถ้ามี `flutterflow ai` (MCP) ให้สั่งใช้ `inspect`/`search`/`status` ดึงชื่อจริงมาก่อน แทนพิมพ์เอง

---

## 🔚 เช็คลิสต์ปิด session (ห้ามข้าม)

- [ ] `INBOX.md` ว่างแล้ว (ของที่ pete เขียนมาถูกกระจายเข้าที่หมดแล้ว)
- [ ] `SCHEMA.md` ตรงกับ DB จริง (สั่ง `db-verifier` ตรวจให้ก็ได้)
- [ ] SQL ที่ apply ไปแล้ว ย้ายออกจาก `PROPOSED_SQL.md` เข้า `SCHEMA.md` แล้ว
- [ ] ตาราง "สถานะ 8 Layers" ด้านบนอัปเดตแล้ว
- [ ] "คิวถัดไป" อัปเดตแล้ว
- [ ] ตัดสินใจใหม่ (ถ้ามี) บันทึกลง `DECISIONS.md` แล้ว
- [ ] doc-syncer รายงานว่าไม่มีไฟล์ไหนเกินเพดาน (หรือรับทราบที่เกินแล้ว)
- [ ] **`git add -A && git commit && git push`** — ไม่ push = เครื่องอื่นทำงานกับข้อมูลเก่า
