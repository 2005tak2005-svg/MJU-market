# STATUS.md — สถานะโปรเจกต์ + จุดเริ่ม session

> 📍 **เปิดไฟล์นี้เป็นไฟล์แรกของทุก session**
> อัปเดตล่าสุด: **2026-08-15** — 🔴 **พบ regression บล็อกทุก `flutterflow ai run`/`validate`** ไม่เกี่ยวกับงานวันนี้เลย (D-25) — **นี่คือของด่วนที่สุดตอนนี้** ก่อนแตะ FlutterFlow DSL อะไรต่อ · root cause บั๊ก reject-flow (sheet ไม่ปิด/ไม่มี notification) หาเจอและปิดแล้วที่ชั้น RLS (D-24) · เปิดใช้ `reports` จริงทั้ง user-report + admin-log (D-24) — **SQL apply+verify ผ่านหมดแล้ว, DSL เขียนเสร็จรอ push ค้างอยู่เพราะ D-25**
> อัปเดตก่อนหน้า 2026-08-14 — **สลับ Authentication backend เป็น Supabase** (D-21) · หน้า `ProfileUser` + `ProductDetails` + AllList ทำงานจริงผ่านแอปแล้ว · **เริ่ม L8 `HomeAdmin`** (D-22) — reuse template shell เดิม ผูกการ์ดสถิติ + คิวสินค้ารอตรวจ + กราฟยอดขายเข้าข้อมูลจริงแล้ว · **approve/reject + `notifications` table (L6) + `Notifications` page + bell icon** (D-23) — push แล้ว ยืนยันผ่าน `generated_code/` + impersonation test ยังไม่ได้ทดสอบผ่านแอปจริง (pete ทดสอบแล้วเจอบั๊กจริง → นำไปสู่ D-24)
> **L1 confirm-email ยังหยุดไว้ที่ D-20** (OTP สร้างเสร็จ แต่ติด email deliverability ฝั่ง tenant)

> 🔴 **บทเรียนใหญ่ของ session 2026-08-14:** `currentUserUid` เคยผูกกับ **Firebase** ทั้งที่ login จริงวิ่งผ่าน Supabase → เป็น `''` ตลอด ทำให้ query ที่ filter ด้วย user ปัจจุบัน**หาแถวไม่เจอ**แล้ว crash · แก้โดยสลับ auth backend เป็น Supabase (D-21)
> **ก่อนแตะ custom code ต้อง inspect widget tree + binding + Supabase ก่อนเสมอ** (กฎข้อ 9 ใน `CLAUDE.md`) — session นี้เสียหลายรอบเพราะแก้ผิดชั้น

> 🔴 **บทเรียนสะสม:** (1) SMTP ตอบ 200 ไม่ใช่หลักฐานว่าอีเมลถึงกล่อง ต้องเช็คกล่องจริง (D-20) (2) ห้ามเชื่อ AI vision test/`inspect` ว่า action ทำงานถูก ต้องเปิด `generated_code/` ดู (PT-09) — evidence ที่เชื่อถือได้สุดคือ query ตรงจาก DB

> 🟡 **L2 — doc drift ที่พบ 2026-08-10:** หน้า `addproduct` มีอยู่แล้วจริงก่อน session นี้ (ตารางด้านล่างเคยเขียนผิดว่ายังไม่เริ่ม) แต่ไม่มี backend ต่อเลย — session นี้ผูกครบแล้ว (กับดัก SDK ที่เจอ ดู PT-12)
>
> ✅ **pete ทดสอบจริงแล้ว: insert เข้า `products` สำเร็จ** — เจอบั๊ก UI (รูปพรีวิวขึ้นขาวเปล่า จาก `app.raw` guard ที่ทำให้ field ใหม่ไม่ถูกเขียน ดู PT-12 ข้อ 9) แก้แล้ว ยืนยันจาก `generated_code/` **แต่ยังไม่ได้ทดสอบซ้ำบนแอปจริง**

---

## 🔥 คิวถัดไป (3 อันดับ)

0.9. **🔴 ด่วนที่สุด — regression บล็อกทุก push (D-25)** ก่อนแตะ FlutterFlow DSL อะไรต่อต้องแก้ตรงนี้ก่อน
    `flutterflow ai run`/`validate` ทุกครั้ง fail ด้วย error ใหม่ 7 ตัวที่ไม่เคยมีมาก่อน (`VALIDATION_PARAMETER_PASSING` x4 บน `PendingProductItem`/`IconButton`→`RejectProductSheet`/`ProductDetails`, `VALIDATION_SUPABASE_DATABASE_ACTION` x1, `VALIDATION_PROPERTY_OVERRIDE` "Generator variable does not exist" x2) — ยืนยันแล้วว่าเป็น server-side regression เกิดระหว่าง 02:47–08:25 วันที่ 2026-08-15 ไม่เกี่ยวกับ DSL ที่แก้วันนี้ (รันสคริปต์เดิมที่เคย push สำเร็จ (`UwVD988G`) ตรง ๆ ก็ error ชุดเดียวกัน) ดู `DECISIONS.md` **D-25**
    ⚠️ **ห้าม sweep อัตโนมัติ** — PT-17 §2 มีบทเรียนจริงว่า sweep แบบ reflection เคยลบ content ที่ยัง reachable ไปด้วย ต้องเปิด FlutterFlow web/desktop editor ดู `HomeAdmin` ตรง ๆ ก่อน หรือเปิด support case
    เมื่อแก้แล้ว: push `dsl/edit.dart` ที่เขียนเสร็จรออยู่ท้ายไฟล์ (reports_admin_view + `ReportProductSheet` + `ProductDetails` entry point + `RejectProductSheet` 3rd write) แล้วต่อด้วย push สร้าง `Reports`/`ReportDetail` pages + ไอคอน entry point บน `HomeAdmin`

0.8. **🆕 root cause บั๊ก reject-flow ปิดแล้ว + เปิดใช้ `reports` จริง (D-24) — SQL เสร็จ, DSL เขียนเสร็จรอ push (บล็อกอยู่ที่ 0.9)**
    ✅ SQL apply + verify ผ่านครบแล้ว: policy ใหม่ 4 ตัว (`notifications` admin-read, `reports` insert/reporter-read), FK `reported_product_id` เปลี่ยนเป็น `ON DELETE SET NULL`, CHECK+default บน `status`, partial unique index กันรายงานซ้ำ, view `reports_admin_view` — ทุกจุดทดสอบผ่าน impersonation จริงแล้ว (non-admin insert+read เอง, กันซ้ำ, กัน status ผิด, deletion ไม่ลบประวัติ, admin insert-then-select-back สำเร็จ = regression check ของบั๊กเดิมผ่าน)
    ✅ DSL เขียนเสร็จใน `dsl/edit.dart`: component `ReportProductSheet` + ปุ่ม report บน `ProductDetails`, เขียนที่ 3 (`reports`) บน `RejectProductSheet`, หน้า `Reports`/`ReportDetail` (bare shell รอ push ต่อ)
    ⚠️ พบว่า `PostgresCreate`/`PostgresUpdate` ไม่มี `onFailure`/`onSuccess` ใน SDK เวอร์ชันนี้เลย (มีแค่ `ApiCall`) — ตัด scope "error Snackbar" ออก บันทึกเป็น PT-18

0.7. **approve/reject + Notifications (D-23) — pete เทสจริงแล้ว เจอบั๊กจริง 3 จุด → root cause หาเจอแล้ว ดู 0.8**
    pete รายงาน: (1) sheet ไม่ปิดอัตโนมัติหลังกดปฏิเสธ (2) seller ไม่เห็นแจ้งเตือน (3) ไม่มีอะไรถูกบันทึกลง `reports` — ทั้งหมดคือ**อาการเดียวกัน**จาก root cause เดียว (select-back หลัง insert โดน RLS SELECT policy บล็อก → exception หยุดก่อนถึง `context.pop()`) แก้แล้วที่ D-24 (ค้างแค่ push ตาม D-25)

0.5. **🆕 L8 `HomeAdmin` ที่เพิ่งผูกวันนี้ — ตรวจ structure/binding ผ่าน FF Desktop live session + `generated_code/` แล้ว รอ pete เทสจริงผ่านแอปเป็นด่านสุดท้าย**
    ✅ ยืนยันแล้ว (2026-08-14, ผ่าน `ide.query_nodes` + `flutterflow ai inspect --outline` + อ่าน `generated_code/` ตรง ๆ): การ์ด 3 ใบ (`ผู้ใช้ทั้งหมด`/`สินค้ารอตรวจสอบ`/`ผู้ใช้ถูกระงับ`) ผูกกับ `admin_dashboard_stats` ถูกต้อง ไม่ใช่ placeholder, โครง widget tree ของ `Row_zau657ld` ถูกต้อง (3 การ์ดจริง ไม่ใช่ list ซ้ำ — เจอบั๊ก canvas render ซ้ำ 4 ชุดระหว่างทำ แก้แล้ว ดู `PATTERNS.md` **PT-16**)
    ⚠️ **สภาพแวดล้อมนี้รัน `flutter` ไม่ได้** (`local_run.list_devices` คืนค่าว่าง, ไม่มี Flutter SDK บน PATH) และ Test Pilot ถูก auto-mode classifier บล็อกไม่ให้สร้าง test — เลยทดสอบได้แค่ระดับ proto/canvas ไม่ใช่แอปที่รันจริง **pete รับเทสเองผ่านแอปจริง** ด้วยบัญชี admin `mju6577778888@mju.ac.th` — 🔴 **บทเรียน 2026-08-15:** รหัสผ่านที่ตั้งไว้วันที่ 2026-08-14 (คุยกันในแชท ไม่ได้บันทึกไว้) หายไปพร้อม session context เดิม ทำให้ pete login ไม่ได้รอบถัดมา — **แก้แล้ว: reset รหัสผ่านให้ตรงกับอีเมลตัวเอง** (`mju6577778888@mju.ac.th` เป็นทั้ง user และ password) แบบเดียวกับบัญชีทดสอบอื่น ๆ — **ห้ามตั้งรหัสผ่านทดสอบแบบ "บอกแค่ในแชท" อีก** ให้ใช้ pattern email-เป็น-password นี้เสมอสำหรับบัญชีทดสอบ จะได้ไม่ต้องพึ่ง context ข้าม session เช็คก่อนปิดข้อนี้: (1) การ์ดขึ้นตัวเลขจริงไม่ crash ตอน auth ยังไม่ resolve เฟรมแรก (2) คิวสินค้ารอตรวจแตะแล้วไป `ProductDetails` จริง (3) การ์ดยอดขายว่างตามคาด (ยังไม่มี `products.status='sold'` เลยสักแถว — ไม่ใช่บั๊ก) — รัน `db-verifier`/`ui-checker` ประกอบก็ได้

0. **🔴 regression test ที่เหลือหลังสลับ auth backend (D-21)** — **สมัครใหม่ · OTP · role-routing** (user→`Home`, admin→`HomeAdmin`) · อัปรูปใน `addproduct`
   เหตุผล: การสลับ backend rewrite **ทุก** reference ของ user ปัจจุบันทั้งโปรเจกต์พร้อมกัน
   ✅ **ทดสอบผ่านแล้ว (V-11):** `ProfileUser` ทั้งหน้า · login · **path storage เป็น Supabase uid ถูกต้องจริง** (ยืนยันจาก `storage.objects` 3 ไฟล์) → ประเด็น upload path ปิดแล้ว
   ✅ คำทักทายหน้า `Home` โชว์ **อีเมล** แทนชื่อ — **pete ทดสอบแล้วรับได้ ไม่ต้องแก้** (Supabase auth ไม่มี `DISPLAY_NAME`) ถ้าวันหลังอยากได้ `full_name` ค่อยผูก page-level query แบบ PT-14
1. สร้าง `MyPost`/`Inspect` (ยังไม่มีใน v2) — อ่าน `PATTERNS.md` PT-09/PT-10/**PT-12**/**PT-14** ก่อนเขียน Action Flow **ทดสอบ login ด้วย `mju6577778888@mju.ac.th`** (admin)
2. **เริ่ม L4 ใน v2** → เหมือนกัน ไม่มีหน้าแชทใน v2 เลย · อ่านคำเตือน PT-09/PT-10 ใน `layers/L4-chat.md` ก่อนเริ่ม โดยเฉพาะเรื่อง `chat_summary.member_names`
3. **🟡 หยุดไว้ — L1 confirm-email (D-20)** ไม่ใช่คิวด่วน แต่ยังไม่ปิด — ดู `layers/L1-auth-profile.md` หัวข้อ "งานค้าง — Confirm Email" และ `DECISIONS.md` **D-20** ก่อนแตะเรื่องนี้ต่อ
   **ค้างอยู่ก่อนปิด L1 ฝั่ง FlutterFlow ได้เต็มตัว:** (1) **แก้ปัญหา email deliverability ก่อน** — OTP ไปไม่ถึงกล่องผู้รับ `@mju.ac.th` เลย (ไม่ bounce ไม่ junk ไม่ quarantine เข้าข่าย Microsoft ZAP) ยังไม่ได้ลองปิด custom SMTP กลับไปใช้ default mailer เพื่อแยกว่าปัญหาอยู่ที่ Gmail relay หรือทั้ง tenant, (2) หลังแก้ deliverability แล้วค่อย **คลิกทดสอบจริงบนแอป** ทั้งเส้น (สมัคร → กรอก OTP → login → เข้า Home/HomeAdmin ไม่เด้งกลับ ระวัง PT-11), (3) ทดสอบเคส login ด้วยบัญชีที่ยังไม่ยืนยัน (ต้องสร้างบัญชีทดสอบใหม่ — บัญชีเดิม `mju6500000099@mju.ac.th` ถูกลบไปแล้ว 2026-08-10 พร้อมบัญชีทดสอบเก่าอีก 3 บัญชี), (4) ล้างบัญชีทดสอบ `mju6577778888@mju.ac.th` แล้วเทสสมัคร+ยืนยัน+login ใหม่ผ่าน flow จริงทั้งเส้น

---

## สถานะ 8 Layers

| L | ชื่อ | Supabase | FlutterFlow | หมายเหตุ |
|---|---|---|---|---|
| 1 | Auth & User Profiles | ✅ **ปิดแล้ว** | 🟨 **Login/SignUp/Home/HomeAdmin/`ProfileUser` ทำงานจริง เหลือ Confirm Email flow (D-20)** | `full_name`/`phone`/role-routing ยืนยันผ่านแอปจริงครบ 2026-08-09 · **`ProfileUser` เสร็จ 2026-08-14** (แสดงข้อมูล user + เปลี่ยนชื่อ/รูป + logout — ดู PT-14) เหลือ `phone`/`bio` · **auth backend = Supabase แล้ว (D-21)** ยังไม่ regression test ทั้งเส้น · OTP flow ติด email deliverability (D-20) |
| 2 | Product Listings + Storage | 🟨 **อัปจริงผ่านแอปสำเร็จแล้ว 2026-08-10 (6 object จริงใน `storage.objects`) เหลือแค่เทส reject >5MB/ผิดชนิด** | 🟨 **`addproduct` — insert ทดสอบผ่านบนแอปจริงแล้ว 2026-08-10, เจอ+แก้บั๊กรูปพรีวิวขาวเปล่าแล้ว แต่ยังไม่ทดสอบซ้ำ** | seed `CAT` 12 หมวด · schema/RLS/view/realtime · bucket + 4 policy + CHECK 3 รูป · 🔴 อ่าน `PATTERNS.md` PT-09/PT-10/**PT-12** ก่อนเริ่ม |
| 3 | Browse / Search / Filter | ⬜ | 🟨 **`AllList` (Home) + `ProductDetails` ทำแล้ว 2026-08-14** | `AllList` ผูก `products_review_view` (filter `moderation_status='approved'`) แตะแล้วส่ง `productId` ไป `ProductDetails` · ยังไม่มี search/filter · รูปสินค้ายังเป็น placeholder (ต้อง index `image_urls[1]` — ติด PT-10) |
| 4 | Chat & Messaging | 🟨 **schema เสร็จ แต่ยังไม่เคยตรวจ** | ⬜ ยังไม่เริ่มใน v2 | RLS เป็น allow-all ชั่วคราว · 🔴 อ่าน `PATTERNS.md` PT-09/PT-10 ก่อนเริ่ม · ดู 🔴 ด้านล่าง |
| 5 | Transaction & Status | ⬜ ยังไม่มีตาราง `transactions` | ⬜ | |
| 6 | Notifications | 🟨 **ตาราง + RLS apply แล้ว 2026-08-14** | 🟨 **`Notifications` page + bell icon บน `Home` เพิ่มแล้ว** | เขียนได้ทางเดียว: reject → insert `type='listing_rejected'` (ดู `SCHEMA.md`) · ไม่มี notification ตอน approve, ไม่มี push จริง (FCM), ไม่มี unread badge/realtime |
| 7 | Reviews & Reports | 🟨 **`reports` RLS+constraint เสร็จแล้ว (D-24)** — insert/select policy, CHECK, unique index กันซ้ำ, view `reports_admin_view` / `reviews` ยังไม่มี | 🟨 **DSL เขียนเสร็จรอ push** (`ReportProductSheet`, `Reports`/`ReportDetail` pages) — บล็อกอยู่ที่ D-25 | ยังไม่ทดสอบผ่านแอปจริง (รอ push ก่อน) |
| 8 | Admin Dashboard | 🟨 **เริ่มแล้ว 2026-08-14** | 🟨 **`HomeAdmin` ผูกข้อมูลจริง + approve/reject ใช้งานได้แล้ว** | `admin_dashboard_stats` + `admin_sales_by_seller` (view ใหม่) · `reports` มี admin-read policy แล้ว · `"Profile".is_banned` นับอย่างเดียว ยังไม่ enforce · **🆕 ปุ่มอนุมัติ/ปฏิเสธคุ้มกันด้วย trigger `enforce_moderation_admin_only`** (D-23) — เหลือ: RLS admin-only เต็มรูปแบบ (`products`/`chat`/`chat_user`/`chat_message` ยัง allow-all, D-03), `"CAT"` CRUD |

✅ เสร็จ · 🟨 กำลังทำ · ⬜ ยังไม่เริ่ม

> 🔄 **2026-08-09 — รีเซ็ตโปรเจกต์ FlutterFlow (D-16):** คอลัมน์ "FlutterFlow" ของทุก layer ด้านบนคือสถานะใน **v2** (`m-j-u-market-v2-0xhjhg`) เท่านั้น — งานฝั่ง FlutterFlow ของ v1 (โปรเจกต์เก่า ตอนนี้ชื่อ "MJU-market-v1-archive") **ไม่นับรวมแล้ว** ต่อให้เคยทำไว้ก็ตาม

> 🔴 **กฎการให้ ✅ (ใช้กับตัวเราเองด้วย): "ตารางว่าง 0 แถว = ยังไม่ PASS"**
> เราตั้งกฎนี้ไว้ตอนตรวจ DB แล้วดันให้ ✅ ตัวเองทั้งที่เส้นทางจริงยังไม่เคยรัน — ลด L1/L4 กลับเป็น 🟨 เมื่อ 2026-08-08

**L1 — ✅ ปิดฝั่ง Supabase แล้ว 2026-08-09** — สมัครผ่าน FlutterFlow Sign Up จริง (`mju6577778888@mju.ac.th`) ได้ `full_name`/`phone`/`student_id`/`role` ครบทุกช่อง ไม่มี NULL
**FlutterFlow ยังไม่ปิด 🟨 — หยุดไว้ที่นี่ 2026-08-10 (D-20)** — Login/SignUp/Home/HomeAdmin ทำงานถูกต้องและยืนยันด้วย `auth.users.last_sign_in_at` จริงทั้ง user/admin path แล้ว **Confirm Email flow เปลี่ยนจากลิงก์ (D-19) เป็น OTP (D-20) เพราะ Microsoft Safe Links ดึงลิงก์ไปใช้ token ทิ้งก่อนคนกด** — โค้ด OTP (หน้า `ConfirmEmail` + custom action `VerifyOtp`/`ResendSignupOtp`) สร้างเสร็จและยืนยันจาก generated code จริงแล้วว่าตรงตามที่ตั้งใจ **แต่ทดสอบจริงแล้วอีเมล OTP ไปไม่ถึงกล่องผู้รับเลย** (ไม่ bounce ไม่ junk ไม่ quarantine — เข้าข่าย Microsoft Zero-hour Auto Purge) เป็นปัญหา deliverability ฝั่ง tenant มหาลัย ไม่ใช่บั๊กโค้ด — รายละเอียดเต็มดู `DECISIONS.md` **D-20** ตัดสินใจหยุดตรงนี้ไปทำ layer อื่นก่อน

**L4 — ทำไมยังไม่ใช่ ✅** — `chat_summary.member_names` **ยังไม่เคยตรวจว่าไม่เป็น NULL** เพราะ `chat` / `chat_user` / `chat_message` ยังว่าง 0 แถวทั้งหมด
view ที่ join `public_profiles` ถูกพิสูจน์แล้วแค่กับ `public_profiles` ตรง ๆ (V-04) **ยังไม่ได้พิสูจน์ผ่าน `chat_summary`** ซึ่งเป็นตัวที่บั๊ก NULL เคยเกิดจริง
→ ปิด L4 ฝั่ง Supabase ได้ต่อเมื่อ **สร้างห้องแชท 1 ห้อง สมาชิก 2 คน แล้ว SELECT `chat_summary` ในฐานะ user ธรรมดา เห็น `member_names` ครบ ไม่มี NULL**

**L2 — ทำไมยังไม่ใช่ ✅** — bucket + policy + CHECK ครบและทดสอบด้วย user ธรรมดาผ่านแล้ว (`VERIFICATION.md` V-08) · **2026-08-10 ยืนยันจาก DB ตรง ๆ ว่าอัปไฟล์จริงผ่านแอปสำเร็จแล้ว** — `storage.objects` มี **6 object** จริง (ไม่ใช่ 0 แถวเหมือนตอนตรวจครั้งก่อน) และแถวเดียวใน `products` (จากการทดสอบของ pete) อ้างถึง 3 ใน 6 นั้นครบผ่าน `image_urls` ตรงกับ path `<uid>/<ไฟล์>` ที่ตั้งใจไว้ (อีก 3 object เป็นไฟล์กำพร้าจากการทดสอบซ้ำ — เข้าเงื่อนไขหนี้ทางเทคนิคที่มีอยู่แล้วด้านล่าง ไม่ใช่เคสใหม่)
`file_size_limit` (5 MB) กับ `allowed_mime_types` บังคับที่ **Storage API ไม่ใช่ที่ Postgres** — ยังไม่เคยลองอัปไฟล์เกิน 5 MB หรือไฟล์ผิดชนิดผ่านแอปจริงสักครั้ง (ทดสอบจาก DB แทนไม่ได้)
→ ปิดได้ต่อเมื่อ **ลองอัปไฟล์เกิน 5 MB / ไฟล์ผิดชนิดผ่านแอปจริง** แล้วเห็นว่าถูกตีกลับ (ฝั่งอัปสำเร็จ + path ถูกต้องยืนยันแล้วจาก DB ตรง ๆ — เหลือแค่เปิด public URL จริงดูว่ารูปขึ้นไหม ยังไม่มีใครเปิดยืนยัน)

---

## ❓ คำถามที่ยังไม่ตัดสินใจ (รวมทุก layer)

**Layer 1**
- จะทำ role-based redirect ซ้ำที่หน้า Splash/Initial (กรณี auto-login) ด้วยไหม
- `handle_new_user()` ยังไม่มี `ON CONFLICT` — ถ้าแถวใน `"Profile"` ซ้ำจะ error ทั้งรายการ ต้องกันไหม

**🔴 รอ pete ตอบ**

1. **D-20 — OTP สร้างเสร็จแล้ว แต่ติด email deliverability ฝั่ง tenant → หยุดไว้ 2026-08-10** ดู `DECISIONS.md` **D-20** — ไม่ใช่คำถามค้าง เป็นบล็อกทางเทคนิคที่ต้องแก้ deliverability ก่อนไปต่อได้
2. **จะรับข้อเสนอ P-11 / P-12 ไหม** — unique index บน `lower(email)` และระบบเก็บกวาดไฟล์กำพร้า ยังไม่ตอบรับ อยู่ใน `PROPOSED_SQL.md`

**Layer 2**
- จะเปิดให้ browse ก่อนล็อกอินไหม — ถ้าเอา ต้องเพิ่ม policy ให้ `anon` ทั้ง `"CAT"` และ `products` (ตอนนี้ `anon` เห็น `"CAT"` เป็น 0 แถว)
- จะบังคับ `category_id` ห้าม null ไหม
- ✅ ตอบแล้ว: ใช้ in-app notification list (L6) ไม่ใช่ push จริง (D-23)

**Layer 3**
- FlutterFlow built-in filter พอไหม หรือต้องสร้าง RPC `search_products` (P-05) — รอทดสอบจริง

**Layer 4**
- FlutterFlow เปิด "Listen for realtime updates" บน **view** ได้จริงไหม (ต้องทดสอบ)
- FlutterFlow query builder รองรับ operator "array contains" บน `chat_summary.user_ids` ไหม ถ้าไม่ ต้องทำ RPC `get_my_chats(uid)`
- จะสร้าง trigger auto-update `chat.last_message` (P-04) หรือให้ Action Flow อัปเดต 2 ที่เอง

**Layer 5**
- ต้องการ `status` กี่แบบจริง ๆ, ต้องเก็บประวัติ transaction แยกไหม หรือใช้ `products.status` พอ

**Layer 6**
- ✅ ตอบแล้ว: ตาราง `notifications` จริง + in-app list (D-23) — ยังไม่ต่อ push จริง (FCM)
- ✅ แก้แล้ว: `ref_id` uuid อ้าง `chat.id` (bigint) ไม่ได้ → แยกเป็น `ref_product_id uuid` (D-23)
- ยังไม่ทำ: notification จาก `chat_message` insert (P-04), unread badge, realtime

**Layer 7**
- รองรับรีพอร์ต "ผู้ใช้" ด้วยไหม (P-09)
- `reviews` ใช้ RLS allow-all หรือ restrictive

**Layer 8**
- 🟨 เริ่มคุยแล้ว 2026-08-14 (`HomeAdmin` stat cards + sales graph + approve/reject) — ค้างจริง:
  - RLS admin-only แบบเต็ม (`products`/`chat`/`chat_user`/`chat_message` ยัง allow-all — D-03) ยังไม่ทำ ยกเว้น `products.moderation_status`/`rejection_reason` ซึ่งคุ้มกันด้วย trigger แล้ว (D-23)
  - หน้า `Inspect` แยกยังไม่มีใน v2 — "คิวสินค้ารอตรวจ" ใน `HomeAdmin` มีปุ่มอนุมัติ/ปฏิเสธจริงแล้ว (D-23)
  - `"CAT"` ยังจัดการ (CRUD) ผ่าน UI ไม่ได้ ยังต้อง seed ด้วยมือ
  - ✅ **pete ยืนยันแล้ว 2026-08-14 (ไม่ใช่ของค้าง):** การ์ด "สินค้ารอตรวจสอบ" ใช้แทนแนวคิด "pending orders" ต่อไปได้ (ยังไม่ต้องเริ่ม L5) และ "ยอดขายตามผู้ขาย" เป็น ranked list (ไม่ใช่ chart จริง — DSL ไม่มี `Chart` widget constructor) ก็ใช้ต่อไปก่อนได้เช่นกัน — รายละเอียด `DECISIONS.md` **D-22** ท้ายข้อ
  - กราฟยอดขาย (`admin_sales_by_seller`) อ้างอิง `products.status='sold'` เพราะยังไม่มีตาราง `transactions` (L5) — ถ้า L5 เริ่มจริงในอนาคต ต้องตัดสินใจว่าจะย้ายไปอ้างอิง `transactions` แทนไหม

---

## 💣 หนี้ทางเทคนิคที่ต้องใช้คืนก่อน production

- [ ] `products` / `chat` / `chat_user` / `chat_message` เป็น **allow-all RLS** — เปลี่ยนเป็น restrictive ตาม `chat_user` membership
- [ ] `reports` เปิด RLS แต่ไม่มี policy = deny-all — ยังใช้งานไม่ได้เลย
- [ ] หน้า `Inspect` กันด้วย UI เท่านั้น ไม่ใช่ RLS — user ยิง API ตรงยัง approve สินค้าเองได้
- [ ] ไม่มีระบบกันกดปุ่มลบซ้ำ/popup ค้างใน reject flow (ยอมรับเป็น MVP)
- [ ] `"Profile".id` มี default `gen_random_uuid()` ทั้งที่เป็นคอลัมน์ FK — บั๊กแบบเดียวกับที่แก้ไปแล้วใน `reports` ควรถอด default ออก (ยังไม่ทำ)
- [ ] `reports.status` ไม่มี CHECK — ค่าที่ใช้ได้ยังไม่ตัดสินใจ ทำพร้อม P-10
- [ ] ข้อมูลทดสอบค้างอยู่ใน DB: user 4 คน + `full_name` ปลอม (`ทดสอบ นักศึกษาหนึ่ง/สอง/สาม`, `สมชาย ใจดี (บุคลากร)`) — ต้องล้างก่อน production
      (`bio`/`phone` **ไม่ได้ค้าง** — ดูหมายเหตุเรื่อง auto-rollback ใน `checks/_common.sql`)
- [ ] `"CAT"` ไม่มี UNIQUE บน `name` — seed ซ้ำได้ ถ้า L8 ให้ admin เพิ่มหมวดหมู่เองควรใส่
- [ ] **`"Profile".is_banned` มีคอลัมน์แล้วแต่ไม่มี enforcement เลย** (เพิ่ม 2026-08-14 พร้อม L8) — ตอนนี้เป็นแค่ตัวนับให้แอดมินดูใน `HomeAdmin` ไม่มี RLS/Action Flow ไหนเช็คค่านี้จริง (login ได้ปกติ, โพสต์/แชทได้ปกติ แม้ `is_banned = true`) — ยังไม่มี UI ให้แอดมินกดแบนด้วยซ้ำ (แก้ค่าได้แค่ผ่าน SQL ตรง ๆ ตอนนี้) ต้องตัดสินใจพร้อมกันว่าจะ enforce ตรงไหนบ้างก่อนใช้จริง (RLS ปฏิเสธ insert/update ของ user ที่ถูกแบน, กัน login, หรือแค่ซ่อนสินค้า)
- [ ] **ไฟล์กำพร้าใน `avatars`** — เปลี่ยนรูปโปรไฟล์แล้วไฟล์เก่าไม่ถูกลบ และ `avatar_url` ชี้ URL ที่ไฟล์อาจไม่มีแล้ว (D-15) — แก้พร้อมข้อถัดไป
- [ ] **ไฟล์กำพร้าใน `product-images`** — อัปรูปแล้วไม่กดบันทึก หรือลบประกาศทีหลัง ไฟล์ยังค้างใน bucket ยังไม่มีระบบเก็บกวาด (ควรทำตอน L5 ที่มีการลบประกาศจริง — Edge Function หรือ trigger บน `DELETE products`)
- [ ] **รูปของประกาศ `pending`/`rejected` เปิดดูได้ถ้ารู้ URL** — ผลจากการเลือก public bucket (หนี้ที่รับไว้ใน `DECISIONS.md` D-12) · 🔴 อย่าเอา bucket นี้ไปเก็บของอ่อนไหว เช่น บัตรนักศึกษา/สลิปโอนเงิน
- [ ] **`Profile_email_key` เป็น unique ธรรมดา ไม่ใช่ index บน `lower(email)`** — ตอนนี้ trigger `lower()` ให้ก่อน insert จึงยังไม่มีปัญหา แต่ถ้ามีเส้นทางเขียนอื่นที่ไม่ผ่าน trigger จะสมัครซ้ำด้วยอีเมลคนละตัวพิมพ์ได้ (ตรวจด้วย `checks/L1.sql` [1.9])
- [x] ~~ชื่อหน้า/State ฝั่ง FlutterFlow ยังไม่เคยเทียบกับโปรเจกต์จริง~~ → **ปิดแล้วสำหรับ L1** 2026-08-09 (มี CLI แล้ว, ชื่อ v2 ยืนยันจริงหมดแล้วดู `layers/L1-auth-profile.md`) — **แต่ L2 ขึ้นไปยังไม่เคยตั้งชื่อใน v2 เลย** ต้องตรวจใหม่ทุก layer ที่เริ่ม
- [ ] **repo เป็น private แล้ว (D-13) แต่นั่นไม่ใช่การปิดช่องโหว่** — ของจริงที่ต้องปิดคือ 3 ข้อบนสุดของรายการนี้ อย่าให้ private กลายเป็นข้ออ้างเลื่อนออกไป
- [ ] 🔴 **บัญชีทดสอบ 2 บัญชีถูกแก้ credential ตรงด้วย SQL — ไม่ใช่สภาพที่ user จริงไปถึงได้ ห้ามใช้เทสอย่างอื่นโดยไม่รู้ตัว** (2026-08-09):
      - `mju6577778888@mju.ac.th` — `email_confirmed_at` ถูก patch ด้วย SQL ตรง ๆ (`UPDATE auth.users SET email_confirmed_at = now() ...`) เพื่อปลดล็อกเทส login หลังเจอ "Email not confirmed" — บัญชีนี้**ไม่เคยผ่านขั้นตอนยืนยันอีเมลจริงของ Supabase เลย** **ยังไม่ได้ล้าง** ณ 2026-08-09 แม้ D-17 จะสร้าง flow เสร็จแล้ว — เป็นงานค้างข้อสุดท้ายก่อนปิด L1 ดู `layers/L1-auth-profile.md`
      - `mju6512345678@mju.ac.th` — `encrypted_password` ถูกเขียนทับด้วย SQL (`crypt('TestPilot!2026', gen_salt('bf'))`) เพื่อให้มีรหัสผ่านที่รู้ค่าไว้เทส Test Pilot login — **รหัสผ่านเดิมของบัญชีนี้ (ถ้าเคยมีคนตั้งไว้) ใช้ไม่ได้แล้ว** และ `email_confirmed_at` ก็ถูกแตะด้วย (แม้จะเป็น no-op เพราะเดิมน่าจะ confirmed อยู่แล้วจากการสร้างผ่าน Dashboard)
      ทั้งสองบัญชีปลอดภัยสำหรับ**เทส auth/role routing ต่อ**เท่านั้น — **ห้ามใช้เทส "สมัครสมาชิกแล้วต้องยืนยันอีเมล" เพราะสภาพถูกลัดผ่านไปแล้ว**
      🔴 **บัญชีสดสำหรับเทส confirm-flow เดิม (`mju6500000099@mju.ac.th`) ถูกลบไปแล้ว 2026-08-10** พร้อมบัญชีทดสอบเก่าอีก 3 บัญชี (`mju6500000101@mju.ac.th`, `mju6606105382@mju.ac.th`, `mju6606105383@mju.ac.th`) — ลบเพื่อเคลียร์ข้อมูลค้างระหว่างเทส D-19/D-20 (รายละเอียด `DECISIONS.md` **D-20**) **ต้องสมัครบัญชีทดสอบใหม่เมื่อกลับมาแก้ confirm-email ต่อ** — ไม่มีบัญชีสดพร้อมใช้ ณ ตอนนี้

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

> ถ้ามี `flutterflow ai` (MCP) ให้สั่งใช้ `inspect` / `search` / `status` ดึงชื่อจริงมาก่อน แทนพิมพ์เอง

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
