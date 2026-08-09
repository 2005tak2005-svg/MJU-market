# PATTERNS.md — pattern ที่ใช้ซ้ำข้าม layer

> ไฟล์นี้มีไว้กันการเล่าเรื่องเดิมซ้ำในหลาย layer — layer ไฟล์ให้อ้างรหัส `PT-xx` แทนคัดลอกเนื้อหามาวาง

---

## PT-01 — เข้าถึงชื่อ/รูปผู้ใช้ ผ่าน `public_profiles` เท่านั้น

**ปัญหา:** `"Profile"` มี RLS จำกัด SELECT เฉพาะแถวของตัวเอง (+ admin เห็นหมด) → view ใดก็ตามที่ join `"Profile"` เพื่อดึงชื่อ จะคืน NULL เมื่อ user ธรรมดาเปิดดูข้อมูลคนอื่น

**วิธีแก้:** join `public.public_profiles` (id / full_name / avatar_url) แทน — view นี้ไม่มี `security_invoker` จึงรันด้วยสิทธิ์ owner (`postgres`, `rolbypassrls = true`) ข้าม RLS ของ `"Profile"` ได้ โดย `email`/`phone`/`student_id`/`role` ยังถูกซ่อนเพราะไม่ได้อยู่ใน view

**ใช้ที่ไหนแล้ว:** `products_review_view` (seller_name) · `chat_summary` (member_names) · `chat_messages_view` (sender_name)

**🔴 กฎ:** view/query ใหม่ที่ต้องการชื่อผู้ใช้ ต้องใช้ pattern นี้เสมอ
**🔴 วิธีตรวจ:** ทดสอบด้วยบัญชี user ธรรมดาที่**ไม่ใช่**เจ้าของข้อมูล — ถ้าเทสด้วย admin จะไม่มีวันเจอบั๊กนี้

---

## PT-02 — find-or-create ห้องแชท (ปุ่ม "แชทกับผู้ขาย")

**ใช้ที่:** `MaterialCard` ใน Admin Inspect (L2) · `ProductDetail` ของผู้ซื้อ (L3) · ทางเข้าห้องแชท (L4)
**บริบทต่างกันแค่ admin→seller vs buyer→seller — โค้ดเดียวกันใช้ซ้ำได้ทั้งหมด**

Action Flow:
1. เรียก RPC `find_or_create_chat(user_a, user_b)` ผ่าน action type **"Supabase Function Call"**
   - `user_a = currentUserId`, `user_b = seller_id` (จาก parameter ที่ widget รับมา)
2. ได้ `chat_id` กลับมา
3. **Navigate To** หน้า `chat messages` ส่ง `chat_id` เป็น Page Parameter

> ⚠️ RPC ตัวนี้ **ยังไม่ apply** — ดู `PROPOSED_SQL.md` P-03
> เหตุผลที่ต้องใช้ RPC: หาห้องที่ทั้งคู่เป็นสมาชิกคือ self-join ข้าม 2 แถวใน `chat_user` FlutterFlow query builder ทำเองไม่ได้

---

## PT-03 — popup + ส่ง Supabase Row ทั้งแถวเป็น parameter

**ใช้ที่:** DataTable → `MaterialCard` (L2 Inspect) · `MaterialCard` → `reason` (L2 reject) · Browse card → `ProductDetail` (L3) · chat list → `chat messages` (L4)

วิธี: ผูก Backend Query กับ **view** (ไม่ใช่ตารางดิบ) แล้วส่ง Row ทั้งแถวไปเป็น component/page parameter — ปลายทาง bind ทุก field ได้เลยโดยไม่ต้อง query ซ้ำ

ข้อดี: query ครั้งเดียว, ชื่อ field ตรงกับ view จึงลดโอกาสผิดกฎ "ชื่อตรง 3 จุด"

---

## PT-04 — realtime alert popup (ผู้ใช้ต้องเปิดหน้าค้างอยู่)

**ใช้ที่:** reject alert ฝั่งผู้ขายใน `MyPost` (L2)

1. เปิด Realtime บนตารางต้นทาง (ทำแล้วกับ `products`, `chat`, `chat_message`)
2. เปิด **"Listen for realtime updates"** บน Backend Query ของหน้านั้น
3. **On Data Change** → เช็คเงื่อนไข → เปิด popup component ส่ง row เป็น parameter

**⚠️ ข้อจำกัดที่ต้องยอมรับ:** event fire เฉพาะตอนผู้ใช้เปิดหน้านั้นค้างอยู่พอดี — ถ้าปิดแอปอยู่จะไม่เห็น popup (เห็นเป็นข้อมูลปกติเมื่อเปิดครั้งถัดไป) ถ้าต้องแจ้งได้แม้ปิดแอป ต้องรอ Layer 6

---

## PT-05 — conditional update กัน race condition

**ใช้ที่:** ปุ่ม "จองสินค้า" (L5)

```sql
UPDATE products SET status = 'reserved' WHERE id = ? AND status = 'available';
-- ถ้า 0 แถวถูกอัปเดต = มีคนจองไปแล้ว
```

อย่าเช็คก่อนแล้วค่อย update แยก 2 คำสั่ง — กดพร้อมกันจะได้ทั้งคู่

---

## PT-06 — Custom Function `getOtherUsers` (ชื่อห้องแชท)

- Custom Function ชื่อ `getOtherUsers`, Return Type `String`
- Arguments: `nicknamesList: List<String>`, `userIdsList: List<String>`, `authUser: String`
- Logic: loop `userIdsList` คู่กับ `nicknamesList` ตัดตำแหน่งที่ `user_id == authUser` ออก แล้ว join ด้วย `", "`
- Map argument: `chat_summary.member_names` → `nicknamesList`, `chat_summary.user_ids` → `userIdsList`, Authenticated User ID → `authUser`
- **Type casting:** FlutterFlow cast จาก Supabase Row เป็น `String` ให้อัตโนมัติ แม้คอลัมน์จริงเป็น `uuid[]` — ไม่ต้อง cast เอง (ยืนยันแล้ว)
- ทดสอบ: `['John','Joe','Mike']` + `['user1','user2','user3']` + authUser `'user2'` → ต้องได้ `"John, Mike"`

---

## PT-07 — role-based navigation

```
Action 1: Supabase Auth → Sign In
Action 2: Backend Query → Query Row บน "Profile" filter id = Authenticated User UID
Action 3: Conditional
  ถ้า profileRow.role == "admin"  → Navigate To `HomeAdmin`
  Else (ครอบคลุม "user" + null)   → Navigate To `home`
```

- เทียบ string **case-sensitive** พิมพ์ `"admin"`/`"user"` ให้ตรงเป๊ะ
- ถ้าต้องรองรับ **auto-login** (เปิดแอปตอนมี session ค้าง) ต้องทำ logic เดียวกันซ้ำที่ **on Page Load ของหน้า Splash/Initial** ไม่งั้นไม่ถูก route ตาม role
- `role` มี CHECK constraint คุ้มครองค่าเพี้ยนอยู่แล้ว

---

## PT-08 — upload รูปเข้า Storage

**ใช้ที่:** `AddProduct` (L2) · แก้ไขประกาศ (L2/L5) · รูปโปรไฟล์ใน Edit Profile (L1)

| bucket | ใช้กับ | ขนาดสูงสุด | จำนวน |
|---|---|---|---|
| `product-images` | รูปสินค้า | 5 MB | 3 รูป (CHECK บนตาราง) |
| `avatars` | รูปโปรไฟล์ | 2 MB | 1 รูป (เก็บลง `avatar_url` ทับของเดิม) |

ท่าเหมือนกันทุกอย่าง ต่างแค่ชื่อ bucket และปลายทางที่เก็บ URL — เหตุผลที่แยก bucket: **D-15**

**🔴 path ต้องขึ้นต้นด้วย `auth.uid()` เสมอ** — `<currentUserId>/<ชื่อไฟล์>`
policy อ่าน `(storage.foldername(name))[1]` มาเทียบกับ `auth.uid()` ตั้งผิด = อัปไม่ผ่านทันที (ไม่ fail เงียบ)

Action Flow:

1. **Upload Media to Supabase** → bucket `product-images`, ตั้ง upload path ให้ขึ้นต้นด้วย `currentUserId`
2. เก็บ URL ที่ได้สะสมไว้ใน **Page State** `List<String>` (เช่น `uploadedImageUrls`)
3. ปุ่ม "ลงขายสินค้า" → Insert Row `products` ผูก `image_urls = uploadedImageUrls`

**ข้อจำกัดที่ต้อง handle ใน UI ไม่ใช่ปล่อยให้ไปตายที่ DB:**

| กติกา | บังคับที่ไหน | ถ้า UI ไม่กัน |
|---|---|---|
| สูงสุด **3 รูป** | CHECK `products_image_urls_max_3` | อัปครบ 4 ไฟล์เสียเน็ตฟรี แล้วโดนปฏิเสธตอนกดบันทึก + เหลือไฟล์กำพร้าใน bucket |
| ไฟล์ ≤ **5 MB** | `file_size_limit` ของ bucket | Storage API ตีกลับตอนอัป |
| เฉพาะ **jpeg / png / webp** | `allowed_mime_types` ของ bucket | Storage API ตีกลับตอนอัป |

> ⚠️ **ยังไม่มีระบบเก็บกวาดไฟล์กำพร้า** — ถ้าผู้ใช้อัปรูปแล้วไม่กดบันทึก หรือลบประกาศทีหลัง ไฟล์ยังค้างใน bucket (หนี้ใน `STATUS.md`)
> ใช้กับ `avatars` ด้วย — เปลี่ยนรูปโปรไฟล์แล้วไฟล์เก่าไม่ถูกลบ
> รายละเอียดการตัดสินใจ: `DECISIONS.md` **D-12** / **D-15** · ค่าจริงของ bucket/policy: `SCHEMA.md` หัวข้อ Storage

---

## PT-09 — 🔴 `CallCustomAction` argument เสียในเวอร์ชัน FlutterFlow AI SDK นี้ (พบ 2026-08-09 ทำ L1)

**อาการ:** custom action ที่รับ argument ผ่าน `CallCustomAction` / `.named(...)` — ไม่ว่าจะผูกค่าจาก page state (`State(...)`) หรือ `WidgetState(...)` (ทั้งแบบชื่อ string ตรง ๆ และแบบ typed handle จาก `ff.Pages.x.widgets.byKey(...)`) — **ทุก argument compile ออกมาผิด/ว่างเปล่าเสมอ** โค้ด Dart ที่ generate จริงเรียก action ด้วย argument ว่างเปล่าหมด (`''`, `''`, ...) แม้ `flutterflow ai validate` จะผ่านและ proto ที่ `flutterflow ai inspect` เห็นจะดูถูกต้องสมบูรณ์ก็ตาม ลองมาแล้ว 3 วิธีต่างกัน (page state, `WidgetState` ชื่อ string, `WidgetState` typed handle) — พังเหมือนกันหมด ทั้ง 3 ครั้ง

**🔴 กฎ: ห้ามเชื่อ `flutterflow ai inspect` ว่า argument ผูกถูกแล้ว** — proto ที่เห็นดูสมบูรณ์ได้ทั้งที่ codegen จริงพัง ต้องเปิด `generated_code/lib/custom_code/actions/<action>.dart` และไฟล์หน้าที่เรียก action นั้น (เช่น `generated_code/lib/pages/<page>/<page>_widget.dart`) ไปดูว่า argument ที่ generate ออกมาเป็นค่าจริงหรือ literal ว่าง — นี่คือวิธีเดียวที่จับบั๊กนี้ได้ก่อน push จริงไปเทสแล้วงง

**ทางแก้ที่ยืนยันแล้วว่าใช้ได้จริง (ทดสอบผ่าน end-to-end):** อย่าส่ง argument เข้า custom action เลย — ให้ custom action **รับ 0 argument** แล้วอ่านค่าที่ต้องการ**เอง**จากข้างในโค้ด Dart:

- ค่าจาก TextField/ฟอร์ม → ให้ TextField เขียนลง **App State** (ไม่ใช่ page state) ผ่าน `UpdateAppState.set('field', const TextValue())` แล้วให้ custom action อ่าน `FFAppState().field` ตรง ๆ
- ค่าจาก Supabase (current user, แถวในตาราง) → เรียก `Supabase.instance.client` ตรง ๆ ในโค้ด action เลย ไม่ต้อง query แล้วส่งผลเป็น argument
- **ค่าที่ action ส่ง _กลับ_ (return value / `outputAs`) ใช้งานได้ปกติ ไม่มีบั๊ก** — เอาไปเทียบด้วย `Equals(ActionOutput('x'), ...)` ได้ตามปกติ ปัญหามีแค่ฝั่ง**ขาเข้า** (argument) เท่านั้น

**ใช้แล้วที่ (L1):** `SignUpWithProfile` (0 arg, อ่าน `FFAppState()` 4 ตัว: email/password/fullName/phone) · `IsCurrentUserAdmin` (0 arg, query Supabase ตรง ๆ คืน `bool`)

**ต้องเจออีกแน่ในทุก layer ที่จะใช้ custom action รับ argument จาก UI** — เช็คด้วยวิธีข้างบนก่อนเชื่อว่า action ทำงานถูก ก่อนไป debug ที่อื่น

---

## PT-10 — 🔴 `PostgresQuery` output type เป็น list เสมอ แม้ `isSingleRow: true` — `FieldAccess` ดึงค่าฟิลด์เดียวไม่ได้ (พบ 2026-08-09 ทำ L1)

**อาการ:** `PostgresQuery(table, outputAs: 'x', query: PostgresQuerySpec(isSingleRow: true, ...))` — `x` มี type เป็น `List<table>` เสมอไม่ว่า `isSingleRow` จะ true หรือไม่ (`outputType => listOf(table)` ถูก hardcode ไว้ในตัว SDK เอง ไม่ใช่ปัญหาที่วิธีเขียนของเรา) ทำให้ `FieldAccess(ActionOutput('x'), 'someColumn')` compile **ไม่ผ่านเลย** — error ตรง ๆ ว่า `Field access requires a struct or document target, got ListType(...)` และ DSL นี้**ไม่มีวิธี index เข้า list** (ไม่มี `[0]`/`.first`) ที่ใช้ได้นอก `ForEach`/`ListView`

**กระทบทุกกรณีที่ต้องการ "ดึงค่าฟิลด์เดียวจากแถวเดียวมาเช็คเงื่อนไขใน action chain"** ไม่ใช่แค่คอลัมน์ array (`text[]`/`uuid[]`) — แต่คอลัมน์ array มีความเสี่ยงเพิ่มอีกชั้นที่ยังไม่ได้ทดสอบ เพราะตัว value เองก็เป็น list ซ้อนอยู่แล้ว **ยังไม่ยืนยันว่า `FieldAccess` อ่านคอลัมน์ array ออกมาได้ปกติไหมแม้จะอยู่ในบริบทที่ target เป็น struct ถูกต้อง**

**ทางแก้ที่ยืนยันแล้วว่าใช้ได้จริง:** ถ้าต้องการแค่ **เช็คเงื่อนไขจากฟิลด์เดียวของแถวเดียว** (เช่น "ของ user คนนี้ role คืออะไร") — อย่าใช้ `PostgresQuery` + `FieldAccess` เลย ใช้ custom action 0 argument ที่ query Supabase ตรง ๆ แล้ว return ค่า scalar ที่ต้องการแทน (pattern เดียวกับ **PT-09** — ดูตัวอย่าง `IsCurrentUserAdmin`)

ถ้าต้องการ**แสดงข้อมูลทั้งแถว/หลายแถวในหน้าจอ** (DataTable, ListView, popup ที่ผูกทั้ง row แบบ **PT-03**) **ไม่กระทบ** — นั่นคือการใช้งานปกติของ `PostgresQuery` ที่ FlutterFlow ผูก UI กับทั้ง row ให้เองโดยไม่ผ่าน `FieldAccess`

**ต้องเช็คก่อนเริ่มลงมือ:**

- **L2** (`AddProduct`/`Inspect`) — ถ้าจะมี action chain ที่เช็คเงื่อนไขจาก `image_urls` หรือฟิลด์เดียวอื่นของ `products` แบบ programmatic (ไม่ใช่แค่ผูกแสดงผลทั้งแถวแบบ PT-03) จะเจอบั๊กนี้ ดู `layers/L2-listings.md`
- **L4** (`chat`/`chat messages`) — ถ้าจะเช็คเงื่อนไขจาก `chat_summary.member_names` / `user_ids` แบบ programmatic เช่น "array contains currentUserId" (คำถามค้างใน `layers/L4-chat.md`) จะเจอบั๊กนี้แน่ — นี่อาจเป็นเหตุผลเพิ่มที่สนับสนุนให้ทำ RPC `get_my_chats(uid)` แทน query builder ธรรมดา ดู `layers/L4-chat.md`

---

## PT-11 — 🔴 แทนที่ built-in Sign In/Sign Up action ด้วย custom action ต้อง sync `AppStateNotifier` เอง เพราะ auth stream ของแอปถูก `debounce` ไว้ (พบ 2026-08-09 ทำ D-17)

**บริบท:** ทำ D-17 (ดัก "email not confirmed" ที่ Login) ต้องเลิกใช้ built-in action `LoginEmailPassword` เพราะมันไม่มี output ให้เช็คว่า error คืออะไร (แค่คืน `user == null`) และ error message ดิบจาก Supabase ("Email not confirmed") ถูกโชว์เป็น snackbar ของ framework เองไปแล้วก่อนที่โค้ดเราจะรู้ตัวด้วยซ้ำ (อยู่ใน `_signInOrCreateAccount` ของ `SupabaseAuthManager` — ไฟล์ `generated_code/lib/auth/supabase_auth/supabase_auth_manager.dart` ซึ่งเป็นโค้ด framework แก้ผ่าน DSL ไม่ได้) ทางแก้เดียวคือเปลี่ยนไปเรียก `Supabase.instance.client.auth.signInWithPassword(...)` ตรง ๆ เองในนั้น custom action (pattern เดียวกับ PT-09)

**กับดักที่เจอ:** ทำแบบนั้นแล้ว login สำเร็จ (มี session จริงใน Supabase) แต่ **บางครั้ง navigate ไป `Home`/`HomeAdmin` แล้วโดนเด้งกลับ `Login` ทันที** — สาเหตุ: `generated_code/lib/auth/supabase_auth/supabase_user_provider.dart` มีบรรทัด
```dart
final supabaseAuthStream = SupaFlow.client.auth.onAuthStateChange.debounce(...)
```
stream นี้เป็นตัวป้อนค่าเข้า `AppStateNotifier.instance.update(user)` ใน `main.dart` — **มี debounce delay อยู่จริง** ทำให้ `AppStateNotifier.instance.loggedIn` (ที่ GoRouter `redirect:` ใช้เช็คว่าเข้าหน้าที่ต้อง auth ได้ไหม) ยังเป็น `false` อยู่ชั่วขณะหลัง sign-in สำเร็จจริง — ต่างจาก built-in action ที่ sync ค่านี้เองแบบ synchronous (`currentUser = authUser; AppStateNotifier.instance.update(authUser);` ใน `_signInOrCreateAccount` — มี comment ในซอร์สยอมรับตรง ๆ ว่านี่คือการกัน race condition ของ stream)

**ทางแก้ที่ยืนยันแล้วว่าใช้ได้จริง:** custom action ที่แทนที่ built-in sign-in action **ต้อง sync ค่านี้เอง** หลัง sign-in สำเร็จ ก่อน return:
```dart
import '/auth/supabase_auth/auth_util.dart';       // ให้ authManager
import '/auth/supabase_auth/supabase_user_provider.dart'; // ให้ <ProjectName>SupabaseUser (ชื่อ class derive จากชื่อโปรเจกต์)
import '/flutter_flow/nav/nav.dart';                // ให้ AppStateNotifier

final response = await Supabase.instance.client.auth.signInWithPassword(...);
if (response.user != null) {
  final authUser = MJUMarketV2SupabaseUser(response.user!); // ชื่อ class เช็คจาก generated_code จริงก่อนใช้ (rule ข้อ 3)
  authManager.currentUser = authUser;
  AppStateNotifier.instance.update(authUser);
}
```
ตรวจพบก่อน push จริงด้วยการ**อ่าน `generated_code/lib/auth/supabase_auth/supabase_user_provider.dart` และ `main.dart` โดยตรง** (ไม่ใช่เดาจาก behavior ที่สังเกตในแอป) ตามกฎ PT-09 ที่ต้องเปิด generated code ดูก่อนเชื่อว่า action ทำงานถูก

**ใช้แล้วที่:** `LoginWithEmailPassword` (L1, Login page)

**ต้องเช็คก่อนทำ layer อื่นที่แทนที่ built-in auth action ด้วย custom action** (เช่นถ้าทำ social login เอง หรือ sign-out เอง) — เจอกับดักเดียวกันแน่
