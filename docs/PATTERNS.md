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

**อาการ:** custom action ที่รับ argument ผ่าน `CallCustomAction` — ไม่ว่าจะผูกจาก `State(...)` หรือ `WidgetState(...)` — **compile ออกมาว่างเปล่าเสมอ** (`''`) แม้ `validate` ผ่านและ `inspect` ดูสมบูรณ์

🔴 **กฎ: ห้ามเชื่อ `inspect` ว่า argument ผูกถูก** — ต้องเปิด `generated_code/lib/custom_code/actions/<action>.dart` ดูว่า argument ที่ generate เป็นค่าจริงหรือ literal ว่าง

**ทางแก้:** custom action **รับ 0 argument** แล้วอ่านเอง — TextField/ฟอร์ม → เขียนลง **App State** ก่อน (`UpdateAppState.set`) แล้วอ่าน `FFAppState()` ในโค้ด action, ค่าจาก Supabase → เรียก `Supabase.instance.client` ตรง ๆ ในโค้ด action เลย (return value/`outputAs` ไม่มีบั๊ก ปัญหามีแค่ฝั่งขาเข้า)

**ใช้แล้วที่ (L1):** `SignUpWithProfile`, `IsCurrentUserAdmin` (0 arg ทั้งคู่) — **เจอซ้ำได้ทุก layer ที่ใช้ custom action รับ argument จาก UI**

🔴 **เพิ่มเติม (พบทำ L4 `findOrCreateChatWithSeller` 2026-08-16):** custom action ที่เรียก `Supabase.instance.client` ตรง ๆ ต้องใส่ `import 'package:supabase_flutter/supabase_flutter.dart';` เป็นบรรทัดแรกของ `code:` เอง — ไม่ได้อยู่ใน "Automatic FlutterFlow imports" ที่ codegen แปะให้อัตโนมัติ (ต่างจาก `/backend/supabase/supabase.dart` ที่แปะให้) ขาดแล้ว **`flutterflow ai run`/validate ไม่จับ** (ไม่ใช่ full Dart compile เหมือนเดิม) แต่ FlutterFlow Desktop/web editor's ตัว Issues panel จับได้ (pete เห็นจากในแอปเป็นคนแรก ไม่ใช่จาก CLI) ยืนยันต้นเหตุจากการเทียบกับ `IsCurrentUserAdmin` ที่มี import นี้อยู่แล้วตั้งแต่แรก แก้ผ่าน `custom_code_helpers.updateCustomAction(project, name:, code:)`

---

## PT-10 — 🔴 `PostgresQuery` output type เป็น list เสมอ แม้ `isSingleRow: true` — `FieldAccess` ดึงค่าฟิลด์เดียวไม่ได้ (พบ 2026-08-09 ทำ L1)

**อาการ:** `outputAs: 'x'` มี type เป็น `List<table>` เสมอไม่ว่า `isSingleRow` จะ true หรือไม่ (hardcode ในตัว SDK) → `FieldAccess(ActionOutput('x'), 'col')` compile ไม่ผ่าน (`Field access requires a struct or document target, got ListType(...)`) และ DSL ไม่มีวิธี index เข้า list นอก `ForEach`/`ListView`

**กระทบ:** ทุกกรณีที่ต้องการ "ดึงค่าฟิลด์เดียวจากแถวเดียวมาเช็คเงื่อนไขใน action chain" (ไม่กระทบการผูกแสดงผลทั้งแถว/หลายแถวแบบ **PT-03**)

**ทางแก้:** ใช้ custom action 0 argument query Supabase ตรง ๆ คืนค่า scalar แทน (เหมือน **PT-09** — ตัวอย่าง `IsCurrentUserAdmin`)

**ต้องเช็คก่อน:** L2 (`products.image_urls` หรือฟิลด์เดี่ยวอื่นแบบ programmatic) · L4 (`chat_summary.member_names`/`user_ids` แบบ "array contains" — อาจต้องทำ RPC `get_my_chats(uid)` แทน)

---

## PT-11 — 🔴 แทนที่ built-in Sign In/Sign Up action ด้วย custom action ต้อง sync `AppStateNotifier` เอง เพราะ auth stream ของแอปถูก `debounce` ไว้ (พบ 2026-08-09 ทำ D-17)

**บริบท:** ต้องเลิกใช้ built-in `LoginEmailPassword` (ไม่มี output บอก error, snackbar ของ framework โชว์ error ดิบไปแล้วก่อนโค้ดเรารู้ตัว) → เรียก `Supabase.instance.client.auth.signInWithPassword(...)` เองในนั้น custom action (pattern เดียวกับ PT-09)

**กับดัก:** login สำเร็จจริง (มี session) แต่บางครั้ง navigate ไป `Home`/`HomeAdmin` แล้วโดนเด้งกลับ `Login` ทันที — สาเหตุ: `supabase_user_provider.dart` มี `onAuthStateChange.debounce(...)` ป้อนค่าเข้า `AppStateNotifier` ทำให้ `loggedIn` (ที่ GoRouter `redirect:` เช็ค) ยังเป็น `false` ชั่วขณะหลัง sign-in — built-in action sync ค่านี้ synchronous แต่ custom action ไม่ทำให้อัตโนมัติ

**ทางแก้:** sync เองหลัง sign-in สำเร็จ ก่อน return:
```dart
import '/auth/supabase_auth/auth_util.dart';
import '/auth/supabase_auth/supabase_user_provider.dart';
import '/flutter_flow/nav/nav.dart';

final response = await Supabase.instance.client.auth.signInWithPassword(...);
if (response.user != null) {
  final authUser = MJUMarketV2SupabaseUser(response.user!); // ชื่อ class เช็คจาก generated_code ก่อนใช้ (กฎข้อ 3)
  authManager.currentUser = authUser;
  AppStateNotifier.instance.update(authUser);
}
```

**ใช้แล้วที่:** `LoginWithEmailPassword` (L1) — **เช็คก่อนทำ layer อื่นที่แทนที่ built-in auth action** (social login, sign-out เอง ฯลฯ)

---

## PT-12 — 🔴 กับดัก `flutterflow ai run` DSL (พบทำ L2 `addproduct`)

🔴 `validate`/`run` ไม่รัน Dart analyzer จริง (`flutter` ไม่อยู่บน PATH) — ผ่านไม่ได้แปลว่า Dart compile ผ่าน ต้องอ่าน `generated_code/` เสมอ

1. **`UploadData` ไม่มีช่องตั้ง Supabase bucket/path** → `app.raw` + `findByKey` เซ็ต `rootAction.action.uploadData.supabase.storageBucket`/`storageFolderPath` ตรง ๆ เป็น `FFValue` (path ผูก `auth.uid()`: `FFVariable(source: SUPABASE_AUTH_USER, baseVariable: FFBaseVariable(auth: FFAuthVariable(property: USER_ID)))`)
2. **อ่าน URL ไฟล์ที่เพิ่งอัป** → `var_helpers.varFromWidgetState(type: UPLOAD_DATA_URL, actionKeyRef: ...)` **ต้องเซ็ต `.nodeKeyRef` ด้วยเสมอ** ไม่งั้น validate ผ่านแต่ fail semantic validation (`update value that is not properly set`)
3. **DropDown label ต้องใช้ `FFParameterValue.translatableText` ไม่ใช่ `serializedValue`** — ใช้ `serializedValue` แล้ว generate เป็น `options: ['', '', ...]` ว่างเปล่า
4. **`FlutterFlowDropDown<String>` ไม่มี value list แยกจาก label** — `_model.dropDownValue` เป็นค่า label เสมอ ต้อง map label→id เองผ่าน custom function (ห้าม parse label เป็นเลข)
5. **`ChoiceChips` ไม่รองรับ `WidgetState(..., .value)`** (รองรับแค่ Toggle/Checkbox/Dropdown/Slider/RadioGroup/PinCode) → prepend action ผ่าน `app.raw` คัด live value เข้า page state ด้วย `varFromWidgetValue(nodeKey, stringType)` ก่อน แล้วให้ chain หลักอ่านจาก `State(...)`
6. **`addCustomFunction`'s `code:` คือเนื้อฟังก์ชันเท่านั้น ไม่ใช่ signature เต็ม** (ตรงข้าม `addCustomAction`) — ใส่ signature เต็มผิด จะได้ฟังก์ชันซ้อนฟังก์ชันที่คืน `null` เสมอ ทั้งที่ compile ผ่าน
7. **parameter ของ custom function generate เป็น `String?` เสมอ** ไม่ว่าประกาศ type อะไร — ต้อง `?? ''` ก่อนเรียก method เสมอ ไม่งั้นไม่ compile
8. **`EditWidgetPatch.visible(false)` เซ็ต proto flag ถูก แต่ไม่ทำให้ widget หายจาก generated code** (ต่าง `bindVisible` ที่ compile เป็น `if(...)` จริง) — ต้องการซ่อนถาวรใช้ `page.ensureRemoved(selector)` แทน (ระวัง: ไม่ rerun-safe เอง ต้องลบบรรทัดออกหลังรันสำเร็จครั้งแรก)
9. 🔴 **`if (rootAction.hasFollowUpAction()) continue;` ทำให้แก้ follow-up chain ทีหลังไม่ถูกเขียนเลย ทั้งที่ validate/run ผ่าน** — `app.raw` ต้อง converge ไปที่ desired state ปัจจุบันทุกครั้งที่รัน ไม่ใช่ตั้งครั้งเดียวแล้วข้าม → เขียนทับ (`rootAction.followUpAction = ...`) ใหม่ทุกครั้งแทน guard ด้วย "เคยมีมาก่อนไหม"
10. **`actionKeyRef` ต้องชี้ `rootAction.action.key` (key ของ `FFAction` ข้างใน) ไม่ใช่ `rootAction.key` (key ของ `FFActionNode` ที่ห่ออยู่)** — ใส่ผิดตัว validate ฟ้อง `update value that is not properly set` (พบตอนผูก avatar upload, ยืนยันโดยเทียบกับ shape ของ addproduct ที่ทำงานอยู่จริง)
11. 🔴 **`bindVisible(true/false)` (ค่า literal) ถูก codegen เมินเงียบ ๆ เมื่อ widget อยู่ใน parent ที่มีเงื่อนไขอยู่แล้ว** — proto เซ็ตถูก (`visibility.visibleValue.inputValue`) แต่ generated code render ออกมาแบบไม่มีเงื่อนไขเลย
    → ต้องใช้ **เงื่อนไขแบบ dynamic** แทน: `Equals(field, null)` compile เป็น `FFVariable(source: FUNCTION_CALL, functionCall: FFFunctionCall(condition: FFCondition(relation: EQUAL_TO), values: [field, '']))` แล้ว codegen ออกมาเป็น `if (x?.field == '')` จริง (กลับด้านด้วย `FFVariableOperation(negate: FFNegateBoolean())`)
    ⚠️ **คอลัมน์ Postgres ที่ nullable ถูก map เป็น Dart `String` ไม่ใช่ `String?` โดยใช้ `''` แทน null** — เงื่อนไข null จึงต้องเทียบกับ `''` ไม่ใช่ `null`

**ใช้แล้วที่:** L2 (`addproduct`) · L1 (`ProfileUser` — ข้อ 10/11) **เช็คก่อนทำ layer อื่นที่มี** DropDown/ChoiceChips ที่ต้องอ่านค่า, widget upload รูปใหม่, หรือ custom function ใหม่ (ข้อ 6/7 เจอทุกครั้ง)

---

## PT-13 — 🔴 Authentication backend ของโปรเจกต์ต้องเป็น **Supabase** ไม่ใช่ Firebase (แก้แล้ว 2026-08-14)

**อาการที่เจอ:** หน้า `ProfileUser` crash `Unexpected null value` ที่ `FutureBuilder` แบบสุ่ม — เปิดครั้งแรกหลัง login ได้ แต่พอออกไปหน้าอื่นแล้วกลับมา/reload แล้วพัง

**ต้นเหตุ:** query ที่ filter ด้วย "ผู้ใช้ปัจจุบัน" compile เป็น `currentUserUid` ซึ่งอ่านจาก `currentUser` ของ FlutterFlow — เดิมผูกกับ **Firebase** แต่**ไม่มีใคร login เข้า Firebase เลย** (โปรเจกต์ Firebase ที่ต่อไว้ว่างเปล่า) การ login จริงวิ่งผ่าน Supabase ทั้งหมด
→ `currentUserUid` เป็น `''` ตลอด ยกเว้นช่วงสั้น ๆ หลัง custom action `LoginWithEmailPassword` เซ็ต `currentUser` เอง · พอ reload แล้ว session ของ Supabase ยังอยู่ (ดูเหมือน login อยู่) แต่ `currentUser` reset เป็น Firebase-null → `currentUserUid = ''` → query หา `"Profile"` ไม่เจอสักแถว → `profileUserProfileRow!.fullName!` throw

**กระทบทั้งแอป ไม่ใช่แค่หน้าเดียว** — `storageFolderPath: currentUserUid` ของ `addproduct`/avatar ก็จะเขียนลงโฟลเดอร์ `''` ซึ่งผิด policy ของ Storage (ดู `SCHEMA.md` — path ต้องขึ้นต้นด้วย `auth.uid()`)

**ทางแก้ที่ใช้:** เปลี่ยน Authentication backend เป็น Supabase (`project.ensureAuthentication().ensureSupabase()` — `firebase`/`supabase`/`custom` เป็น protobuf `oneof` จึงตัด firebase ทิ้งอัตโนมัติ) แล้ว `currentUserUid` = Supabase uid ตรงกับ `"Profile".id` จริง

🔴 **สลับ backend แล้ว reference เดิม "พังยกชุด" ต้องกวาดพร้อมกันใน push เดียว** — ทุก `FFVariable(source: FIREBASE_AUTH_USER)` ต้องเปลี่ยนเป็น `SUPABASE_AUTH_USER` ไม่งั้น validate ฟ้องรัว ๆ (`Storage folder path not properly set`, `invalid value for field "seller_id"`, `One or more filters is invalid`)
วิธีที่ใช้: เดิน proto ทั้งต้นแบบ generic ด้วย protobuf reflection (`message.info_.fieldInfo.values` + `getField`/`hasField`) แทนไล่แก้ทีละจุดแล้วตกหล่น — ต้องเพิ่ม `protobuf` เป็น direct dependency ใน `pubspec.yaml` ก่อน (SDK barrel ไม่ได้ re-export `GeneratedMessage`)

⚠️ **`DISPLAY_NAME` / `PHOTO_URL` ไม่มีใน Supabase auth user** (มีแค่ id/email/phone) — binding เดิมที่ใช้จะ invalid (`A component in the string interpolation is invalid`) ต้อง remap เป็น `EMAIL` หรือดึงจาก `"Profile"` ผ่าน query แทน
> ผลข้างเคียงที่ยังค้าง: คำทักทายหน้า Home ตอนนี้โชว์ **อีเมล** แทนชื่อ — ถ้าอยากได้ `full_name` ต้องผูก page-level query บน Home แบบเดียวกับ `ProfileUser`

📌 `configureSupabaseAuth()` อยู่ใน `auth_helpers.dart` ซึ่ง **ไม่ได้ export ออกมาที่ barrel สาธารณะ** — ต้องเขียน proto เองใน `app.raw` (เซ็ต `active`, `ensureSupabase().providers`, `ensureAuthPageInfo().homePageNodeKeyRef`/`signInPageNodeKeyRef`)

---

## PT-14 — 🔴 ผูกข้อมูล "user ที่ล็อกอิน" เข้าหน้าจอ (พบทำ `ProfileUser` 2026-08-14)

**ท่ามาตรฐาน:** page-level Backend Query บน Scaffold + bind widget ตรง ๆ — **ไม่ต้องใช้ ListView/page state**
```
node.databaseRequest = FFDatabaseRequest(
  returnParameter: FFParameter(dataType: FFDataTypeV2(
    scalarType: PostgresRow, subType: FFSubType(tableIdentifier: FFIdentifier(name: 'Profile')))),
  postgres: FFPostgresQuery(filters: [id EQUAL_TO SUPABASE_AUTH_USER.USER_ID],
                            isSingleRow: true, hideOnEmpty: true),
)
```
bind: `FFVariable(source: POSTGRES_QUERY, baseVariable: postgresQuery, operations:[accessPostgresRowField(<col>)], nodeKeyRef: <Scaffold key>)`

1. 🔴 **`hideOnEmpty: true` บังคับใส่** — query คืน **list**; ว่างเมื่อไหร่ codegen ได้ row เป็น `null` แล้ว force-unwrap (`row!.field!`) → crash `Unexpected null value` ที่ `FutureBuilder`
   ใส่แล้ว codegen เพิ่ม `if (snapshot.data!.isEmpty) return Container();` ก่อนแตะ row
   ⚠️ **เฟรมแรก row ว่างเป็นเรื่องปกติ** — auth stream ยิง user = null ก่อน restore session → `currentUserUid` เป็น `''` ชั่วขณะ
2. 🔴 **เช็ค null ของ field ต้องใช้ `EXISTS_AND_NON_EMPTY` / `DOES_NOT_EXIST_OR_IS_EMPTY`** (`FFCondition_Relation`)
   **ห้ามใช้ `EQUAL_TO ''`** — คอลัมน์ที่เป็น NULL ไม่เท่ากับ `''` → guard แบบ negate ยังหลุดเข้าไปเจอ `row!.field!` อยู่ดี
   (relation ที่ถูกต้อง generate เป็น `if (row?.f != null && row?.f != '')`)
3. **upload รูปต้องตั้ง `settings.maxResolution` + `settings.imageQuality`** ไม่งั้นส่งไฟล์ต้นฉบับ → **413 Payload too large** (`avatars` = 2 MB, `product-images` = 5 MB) · avatar ใช้ 512×512 / quality 80
4. 🔴 **selector ต้องเป็น key เสมอ ห้าม positional path** — `ensureRemoved`/`ensureInserted*` ใน block เดียวกันทำ index เลื่อน แล้ว `byPath('...children[5]')` ไปโดน widget อื่น
   **เคยเกิดจริง:** toggle "Edit Profile" ไปแปะทับปุ่ม Log Out → Log Out เสียแอ็กชัน sign-out ไปเงียบ ๆ กลายเป็นเปิดช่องเปลี่ยนชื่อแทน

**ใช้แล้วที่:** L1 (`ProfileUser`) · **ใช้ซ้ำได้ทุกหน้าที่แสดงข้อมูลของ user ปัจจุบัน** (Edit Profile, MyPost, ฯลฯ)

---

## PT-15 — 🔴 ผูก query เข้า view/table ใหม่ที่เพิ่งสร้างใน Supabase + selector พังหลัง `ensureRemoved` (พบทำ L8 `HomeAdmin` 2026-08-14)

**1. `ff.Pages.X.widgets.byKey(key).single` (typed SDK, static) ไม่ปลอดภัยเมื่อผสมกับ `ensureRemoved`/`ensureReplaced` ของ sibling ที่อยู่ "ก่อนหน้า" ใน block เดียวกัน**

อาการ: `Bad state: page X findByPath("X.body[0]...children[N]...") found no matches.` ทั้งที่โค้ดเขียนด้วย `.byKey(...)` ไม่ใช่ `.byPath(...)` เลย

สาเหตุ: `.widgets.byKey(key)` (เมธอดบน `ProjectWidgetTree` ที่มาจาก `lib/flutterflow_project/pages/*.dart` — สแนปช็อตนิ่ง) รีโซลฟ์ผ่าน path ที่ฝังมาตอน generate ไฟล์ ไม่ใช่ค้นหา key สดในทรีปัจจุบัน — ต่างจาก `page.findByKey(key)` (เมธอดบน `EditPageBuilder` ที่ได้จาก `app.editPage(page, (page) {...})`) ซึ่งค้นสดจริง
พอ `ensureRemoved`/`ensureReplaced` ของ sibling ที่มา "ก่อน" ใน execution order ลบ/แทนที่โหนดออกไป ดัชนีของพี่น้องที่เหลือเลื่อน → path ที่ฝังไว้ใน `.byKey(...)` ของ typed SDK ชี้ผิดที่ทันที (เหมือน PT-14 ข้อ 4 แต่คนละกลไก — ข้อ 4 คือ `.byPath(...)` ตรง ๆ, ข้อนี้คือ `.byKey(...)` ที่ดูปลอดภัยแต่ไม่ใช่)

**ทางแก้:** ใช้ `page.findByKey(key)` (ของ `EditPageBuilder`) แทน `ff.Pages.X.widgets.byKey(key).single` (ของ typed SDK) ทุกจุดที่อยู่ใน scope เดียวกับการ `ensureRemoved`/`ensureReplaced` — โดยเฉพาะเมื่อมีการลบ widget ที่อยู่ "ก่อน" widget อื่นในลิสต์พี่น้องเดียวกัน (ancestor chain เดียวกัน)

**2. ผูก query เข้า table/view ที่เพิ่งสร้างใน Supabase ตรง ๆ (ยังไม่เคยผ่าน `flutterflow ai refresh-context`) จะ validate fail แม้ compile ผ่าน**

อาการ: `Table is not properly set in database query for <Page>` + `Invalid postgres row field operation` ที่ทุก Text ที่ผูกกับ field ของ table นั้น

สาเหตุ: compiler validate `FFIdentifier(name: 'ชื่อ table/view')` เทียบกับ **ลิสต์ table ที่โปรเจกต์รู้จักเอง** (เก็บใน proto ของโปรเจกต์) ไม่ใช่เช็คกับ Postgres สด — สร้างแค่ `PostgresTableHandle('ชื่อ', {...}, isView: true)` ในเครื่องแล้วยัดใส่ `PostgresQuery(...)` compile ผ่านเฉย ๆ (syntax ถูก) แต่ validate ตอน push ไม่ผ่าน
`flutterflow ai refresh-context` ไม่ช่วย — รันแล้ว `lib/flutterflow_project/schemas.dart` ก็ยังไม่เห็น table ใหม่ (ยังไม่รู้กลไกที่แท้จริงว่า FF sync schema จาก Postgres ตอนไหน)

🔴 **ห้ามแก้ด้วย `app.table(...)`** — เมธอดนี้เช็ค `_ensureSqlBackendConfigured` ซึ่งบังคับให้เรียก `app.supabase(url:, anonKey:)` **ในสคริปต์เดียวกัน** ก่อน ถ้าโปรเจกต์ Supabase ต่ออยู่แล้ว (เคสเกือบทุกครั้งของโปรเจกต์นี้) การ re-declare `app.supabase(...)` มีความเสี่ยงเขียนทับ config auth จริงโดยไม่ตั้งใจ (ดู PT-13 ที่เจอปัญหาจากการสลับ backend มาแล้วครั้งหนึ่ง) — ไม่คุ้มเสี่ยงสำหรับแค่จะเพิ่ม table หนึ่งตัว

**ทางแก้ที่ปลอดภัย:** เรียก `postgres_helpers.addTable(project, name:, fields:, isView:)` ตรง ๆ ใน `app.raw` — ฟังก์ชันนี้เขียนเข้า `project.currentSupabaseConfig`/`postgresConfig` ที่มีอยู่แล้วโดยตรง ไม่แตะ credential ใด ๆ
```dart
import 'package:flutterflow_ai/src/helpers/postgres_helpers.dart' as postgres_helpers;
// ...
app.raw((project) {
  if (postgres_helpers.findTable(project, name: 'ชื่อ_view') == null) {
    postgres_helpers.addTable(project, name: 'ชื่อ_view', isView: true, fields: [
      postgres_helpers.postgresField('col', type: FFDataTypeV2(scalarType: FFBaseDataType.Integer), postgresType: 'int8'),
      // ...
    ]);
  }
  // ตามด้วย databaseRequest/query ปกติ (PT-14) — ตอนนี้ FFIdentifier(name: 'ชื่อ_view') validate ผ่านแล้ว
});
```
⚠️ `postgres_helpers.dart` อยู่ใต้ `src/` ของแพ็กเกจ — import ตรงด้วย path เต็ม (`package:flutterflow_ai/src/helpers/postgres_helpers.dart`) ได้จริง ไม่ถูกบล็อก แค่ไม่อยู่ใน barrel สาธารณะ `flutterflow_ai.dart`
`addTable` throw ถ้าชื่อซ้ำ — ต้อง guard ด้วย `findTable(...) == null` เสมอเพื่อให้ rerun ได้ (เหมือน PT-12 ข้อ 9)

**3. `PostgresOrderBy('col', ascending: false)` ไม่ generate `ascending` ใน `.order(...)` เลย (พบว่าเป็นมาแล้วตั้งแต่ `AllList`)**

โค้ดที่ออกมาคือ `.order('created_at')` เฉย ๆ ไม่มี flag ทิศทางใด ๆ — เป็น gap เดิมของ SDK เวอร์ชันนี้ ไม่ใช่บั๊กที่เพิ่งเกิด (เช็คแล้วว่า `AllList` ที่ deploy จริงก็เป็นแบบนี้เหมือนกัน) ถ้าลำดับ (ใหม่สุดก่อน/เก่าสุดก่อน) สำคัญกับ feature ที่ทำ ต้องเปิด `generated_code/` ยืนยันเองทุกครั้ง ห้ามเชื่อว่า `ascending: false` ทำงานจากแค่โค้ด DSL

**ใช้แล้วที่:** L8 (`HomeAdmin` — `admin_dashboard_stats`) · เช็คก่อนทุกครั้งที่ผูกหน้าใหม่เข้า view/table ที่สร้างเองใน Supabase ระหว่าง session เดียวกัน (ไม่ใช่ table เดิมที่มีอยู่แล้วใน `ff.Tables`)

---

## PT-16 — 🔴 อย่าใช้ `ListView` แทน "การ์ดค่าเดียว" + `ensureReplaced` ไม่ rerun-safe ถ้า target เป็น key ที่ operation ก่อนหน้าใน**สคริปต์เดียวกัน**เพิ่งกินไป (พบทำ L8 `HomeAdmin` 2026-08-14)

**1. ห้ามห่อ "การ์ดแสดงค่าตัวเลขตัวเดียว" ด้วย `ListView(source: State('xxx'), itemBuilder: ...)` เพื่อเลี่ยงข้อจำกัดที่ query แบบ scalar ทำไม่ได้ (ดู PT-10)**

อาการ: compile/push ผ่านเฉย ๆ, `generated_code/` ก็ดูถูกต้อง แต่เปิด **FF Desktop canvas** (`ide.screenshot_canvas`) แล้วเห็นการ์ดซ้ำเป็น 4 ก๊อปปี้ซ้อนกัน (placeholder mock ของ ListView ตอน design-time) แล้วดัน sibling อื่นในแถวเดียวกันหายไปจากมุมมอง — ทั้งที่ proto จริงถูกต้องครบ (ยืนยันด้วย `ide.query_nodes` ว่า sibling ยังอยู่ใน tree ปกติ)
สาเหตุ: canvas ของ FF Desktop render ListView เป็น "รายการที่ repeat" เสมอ ไม่สนใจว่า runtime จะมีจริงกี่ item — เอาไปใช้แสดงค่าเดียวจึงดู "พัง" ใน editor ทั้งที่ apk/web จริงจะแสดงถูก (เพราะ query จริงคืนแค่ 1 row)

**ทางแก้ที่ถูกต้อง:** สร้างเป็น widget นิ่ง (`Container`/`Text` ธรรมดา ไม่ใช่ `ListView`) ด้วยค่า placeholder ไปก่อน แล้วผูกค่าจริงทีหลังด้วย raw-proto `nodeKeyRef` แบบเดียวกับการ์ดอื่น (PT-14) — ไม่ใช่ผ่าน `item['field']`

**2. `page.ensureReplaced(page.findByKey('key ที่ยังไม่เคยมี ณ ตอนสคริปต์เริ่มรัน'), ...)` ไม่ rerun-safe ถ้า key นั้นถูก op ก่อนหน้าใน**สคริปต์เดียวกัน**สร้างขึ้นมาเอง**

เจอจริงตอนแก้ข้อ 1: push ครั้งแรกสร้าง `ListView_h65u06bk` แล้วเอาไป `ensureReplaced` ด้วย `Container` ใหม่ (คนละ key, auto-gen) — พอรัน**สคริปต์เดิมซ้ำ**ในการ push ครั้งถัดไป (มี `ensureReplaced(findByKey('ListView_h65u06bk'), Container(...))` เหลืออยู่) `ListView_h65u06bk` ไม่มีอยู่แล้วในโปรเจกต์ (ถูกแทนที่ไปตั้งแต่ครั้งก่อน) — compiler ไม่ error แต่กลับ **สร้าง `Container` ใหม่อีกชุดด้วย key อื่น** ซ้อนขึ้นมาแทน ในขณะที่การ bind ค่าที่เขียนไว้ (`bindText('Text_bvmb7v87', ...)`) ยังชี้ไปที่ key เก่าที่ถูกทิ้งไปแล้ว → ค่าบนหน้าจอไม่ขึ้น ทั้งที่ `flutterflow ai run` รายงานผ่านทุกครั้ง
ตรวจพบได้จาก `generated_code/` (ไม่มี `.bannedUsers` เลยทั้งไฟล์ ทั้งที่เขียน `bindText` ไว้แล้ว) + ยืนยัน key จริงด้วย `ide.query_nodes` (ค้นด้วย `name:` ที่ตั้งไว้ตอนสร้าง widget) แล้วพบว่า key เปลี่ยนไปจริง

**ทางแก้:** operation ที่สร้าง widget ใหม่ (`ensureReplaced`/`ensureInsertedInto`) ให้ถือเป็น**ของใช้ครั้งเดียว** — พอ push สำเร็จแล้วให้ **ลบ operation นั้นออกจากสคริปต์** เปลี่ยนเป็นคอมเมนต์อธิบายว่าทำไปแล้ว (ทำตามธรรมเนียมที่ไฟล์นี้ทำอยู่แล้วกับปุ่ม FAB ของ `Home`) แล้วค่อยตามด้วย op ที่ target key จริงที่เพิ่งสร้าง (เจอผ่าน `ide.query_nodes` หรือ `flutterflow ai inspect --outline`) — **ห้ามปล่อย `ensureReplaced`/`ensureInsertedInto` ที่เคยรันสำเร็จแล้วค้างในสคริปต์** เพราะรันซ้ำแล้วไม่ error แต่ผลลัพธ์ผิด (ต่างจาก `ensureRemoved` ที่ PT-12 ข้อ 9 บอกว่า rerun ไม่ได้เหมือนกันแต่ อย่างน้อย fail ชัดเจน)

**เครื่องมือตรวจที่ใช้ได้จริงระหว่างทำ (ไม่ต้องรอ local run):**
- `ide.screenshot_canvas` (ต้องมี FF Desktop เปิดโปรเจกต์อยู่ — เช็ค `live.status` ก่อน) — เห็นภาพจริงของ design-time canvas ไม่ใช่แค่เดาจาก proto
- `ide.query_nodes` ค้นด้วย `name:` ที่ตั้งไว้เอง — หา key จริงหลัง push โดยไม่ต้องเดา **แต่ผลลัพธ์ scope อยู่แค่ "หน้าที่เปิดอยู่ใน Desktop ตอนนั้น"** ถ้า pete สลับหน้าอยู่ (เป็น session ที่ share กับ pete แบบ live) จะได้ผลว่างเปล่าทั้งที่ node มีจริง — สับสนกับ "ไม่มีจริง" ได้ง่าย ให้ตรวจซ้ำด้วย `flutterflow ai inspect <id> --page <ชื่อ> --outline` (query ตรงจาก server ไม่ผ่าน Desktop) เป็นหลักฐานสุดท้ายเสมอ
- `flutterflow ai inspect <id> --page <ชื่อ> --outline` — ยืนยันโครงสร้าง tree ปัจจุบันจริงจากเซิร์ฟเวอร์ (ไม่สน state ของ Desktop) เชื่อถือได้สุดในบรรดา 3 อย่างนี้

**ใช้แล้วที่:** L8 (`HomeAdmin` — การ์ดผู้ใช้ถูกระงับ) · เช็คทุกครั้งที่จะ "ผูกค่าเดียวแบบ scalar" ด้วยลูกเล่น ListView-1-item หรือจะรัน `ensureReplaced`/`ensureInsertedInto` ซ้ำในสคริปต์ที่เคย push สำเร็จมาก่อนแล้ว

---

## PT-17 — 🔴 `app.raw` table registration compile หลัง `app.component`/`ensurePage`/`editPage*` เสมอ + orphan node สะสมจาก `ensureReplaced` ซ้ำ (พบทำ L6/L8 2026-08-14)

**1. Compile order:** `_compileComponents`/`_compilePages` รันก่อน `app.rawMutations` เสมอ (`compiler.dart` ~3546-3560) ไม่ขึ้นกับลำดับ statement ในสคริปต์ — ตารางที่เพิ่ง `postgres_helpers.addTable` ใน push เดียวกันอ้างจาก page/component ใหม่ไม่ได้ (error: "Table X was not compiled")
**ทางแก้:** แยก push 2 รอบ — รอบแรก register ตารางอย่างเดียว รอบสองค่อยเติมส่วนที่เหลือ

**2. Orphan node:** `ensureReplaced` ที่ยิงซ้ำข้าม session (ค้างในสคริปต์ตาม PT-16) สร้าง node กำพร้าสะสมทุก push — ไม่ error, ตรวจไม่เจอผ่าน `--outline`/`--deep`/`--dsl-json` (เดินแค่ reachable tree)
**ทางแก้:** เขียน utility เดิน proto ด้วย reflection (`message.info_.fieldInfo.values`, pattern เดียวกับ `_rewriteFirebaseAuthToSupabase`) discover+remove ในการเรียกเดียว (แยก 2 call แล้ว closure ที่สองเห็น list ว่าง) — ยืนยัน key ล่าสุดด้วย `--outline` ก่อนเขียนเสมอ ปลอดภัยสุดคือสร้าง widget เป้าหมายใหม่ทั้งชุดด้วย `ensureReplaced` รอบเดียว ไม่พึ่งว่า node ที่กวาดไม่โดนจะยัง reachable แน่นอน

**ใช้แล้วที่:** L6/L8 (notifications table registration, `HomeAdmin` itemBuilder rebuild)

**ใช้แล้วที่:** L6/L8 (`notifications` table registration + `HomeAdmin` approve/reject itemBuilder rebuild) — เช็คทุกครั้งที่ push เดียวกันทั้งสร้างตาราง/view ใหม่ **และ** อ้างมันจาก page/component ใหม่ หรือสงสัยว่ามี `ensureReplaced`/`ensureInsertedInto` ค้างจากหลาย session ก่อนหน้าที่ไม่เคยถูกลบออกจากสคริปต์ตาม PT-16

---

## PT-18 — 🔴 `PostgresCreate`/`PostgresUpdate`/`PostgresQuery`/`PostgresDelete` ไม่มี `onSuccess`/`onFailure` เลย (พบทำ L7 reports feature 2026-08-15)

`onSuccess`/`onFailure` (ตัวอย่างที่เห็นใน `references/shopflow_dsl.dart`, `references/multi_api_call_dsl.dart`) มีประกาศอยู่ **แค่บน `ApiCall`** เท่านั้น — เช็ค SDK source (`flutterflow_ai/lib/src/dsl/actions.dart`) แล้วยืนยันว่า `PostgresCreate`/`PostgresUpdate`/`PostgresQuery`/`PostgresDelete` ไม่มี parameter นี้เลยสักตัว และไม่มี chain-level try/catch หรือ error-handling wrapper อื่นใดใน SDK เวอร์ชันนี้ (0.0.40) สำหรับ Postgres/Supabase write action โดยเฉพาะ

**ผลที่ตามมา:** ถ้า Postgres action ล้มเหลว (RLS ปฏิเสธ, constraint violation ฯลฯ) exception จะหลุดออกจาก action chain แบบไม่มีการดักจับใด ๆ — ไม่มีทาง surface error ให้ user เห็นผ่าน DSL ได้เลยในตอนนี้ (นี่คือกลไกที่ทำให้บั๊ก `RejectProductSheet` เงียบ — ดู `DECISIONS.md` D-24)

**ทางแก้ที่มี (ทั้งคู่ยังไม่ได้ลองทำจริง):**
1. ปิด root cause ที่ RLS/constraint แทน (สิ่งที่ D-24 ทำจริง) — ไม่ใช่ error handling แต่ตัดโอกาส error ตั้งแต่ต้น
2. เขียน `CustomAction` เอง เรียก Supabase client ตรง ๆ ด้วย try/catch — ได้ error handling จริง แต่เสียประโยชน์ของ `PostgresCreate`/`PostgresUpdate` ที่ codegen ให้ฟรี ต้อง maintain เอง

**ใช้แล้วที่:** L7 (`RejectProductSheet` 3rd write, `ReportProductSheet`) — ก่อนเสนอ error-handling ผ่าน Postgres action ใด ๆ ให้เช็ค SDK source ก่อนเสมอ อย่าเดาจากตัวอย่าง `ApiCall`

---

## PT-19 — 🔴 root cause แท้จริงของ D-25: `HomeAdmin`'s `PendingProductsList` validate ผ่านเฉพาะตอน authored สดในสคริปต์เดียวกัน ไม่ผ่านถ้าเช็คกับของที่ push ไปแล้ว (2026-08-15)

**นี่คือคำอธิบายที่แท้จริงของ saga ทั้งชุดที่เคยบันทึกไว้ใน PT-16/PT-17/D-25** (`ListView` เปลี่ยน key ไปเรื่อย ๆ 3bb20t2z → 394zgxi8 → mctnycd6 → 8rll5xbc → g0lsh0pi → 1lqaxuzf → ol78bkha) — ไม่ใช่ orphan node สะสมอย่างที่เข้าใจตอนแรก แต่คือ:

**`PendingProductsList` (ListView ที่มี itemBuilder ผูก `item['id']`/`item['seller_id']` ฯลฯ) validate ผ่าน (`[OK]`) ก็ต่อเมื่อสคริปต์ authored มัน** สด**ในพุชนั้นเอง (ผ่าน `ensureReplaced`) เท่านั้น — ถ้าลบ `ensureReplaced` ออกจากสคริปต์ (ปล่อยให้ validate เทียบกับของที่ push ไปแล้วซึ่งใช้งานได้จริงบนแอปปกติทุกอย่าง) validate จะ fail ทันทีด้วย `"Parameter productId... not properly set"` + `"Generator variable does not exist"` x2 — ยืนยันซ้ำแล้วซ้ำอีกในเซสชันเดียวกัน (ลบแล้ว fail, ใส่กลับพร้อม key ใหม่แล้วผ่าน, ลบอีกครั้ง fail อีก) ไม่ใช่ความผิดพลาดของสคริปต์เรา

**ผลที่ตามมาที่สำคัญที่สุด:** **ทุก push ที่แตะไฟล์นี้ (ไม่ใช่แค่ push ที่แก้ `HomeAdmin`) จะ validate fail ถ้าไม่มี `ensureReplaced` ของ `PendingProductsList` อยู่ในสคริปต์** — ต่างจาก orphan/stale-key ธรรมดาที่ PT-16 สอนให้ลบทิ้งหลังใช้เสร็จ **ก้อนนี้ห้ามลบ** ต้องเก็บไว้ถาวรและอัปเดต `key:` ใน `findByKey(...)` ให้ตรงกับของจริงก่อน push ทุกครั้ง (เช็คด้วย `flutterflow ai inspect --page HomeAdmin --outline`) — เป็นภาระถาวรจนกว่า FlutterFlow จะแก้ที่ต้นตอ (ยังไม่รู้ว่าทำไม เข้าข่าย SDK/validator bug ไม่ใช่บั๊กจากฝั่งเรา)

**ใช้แล้วที่:** L8 `HomeAdmin` — ก่อน push ใด ๆ ที่แตะ `dsl/edit.dart` เช็ค `PendingProductsList`'s `ensureReplaced` (มี comment เตือนกำกับอยู่) ว่า key ยังตรงกับของจริงไหม

---

## PT-20 — 🔴 สร้าง Supabase auth user ด้วย SQL ตรง (`INSERT INTO auth.users`) ล็อกอินไม่ได้ถ้าไม่ทำ 2 อย่างนี้เพิ่ม (2026-08-15)

สร้าง user ทดสอบใหม่ด้วย `INSERT INTO auth.users (...)` ตรง ๆ (ไม่ผ่าน signup flow จริง หรือ Admin API) — `handle_new_user()` trigger สร้างแถว `"Profile"` ให้ถูกต้อง แต่ **ล็อกอินผ่าน `/auth/v1/token?grant_type=password` fail ด้วย `500 Database error querying schema`** ทั้งที่ password ถูก แม้ `email_confirmed_at` ตั้งไว้แล้วก็ตาม

**สาเหตุจริง (ยืนยันจาก `auth_logs` ไม่ใช่เดา) — ขาด 2 อย่าง:**

1. **ไม่มีแถวคู่กันใน `auth.identities`** — GoTrue ต้องการ identity row (provider `email`) ผูกกับ `user_id` เสมอ ไม่ใช่แค่แถวใน `auth.users` เพียว ๆ (`provider_id` = `user_id` สำหรับ email provider, `identity_data` เป็น jsonb มี `sub`/`email`, คอลัมน์ `email` ของตารางนี้เป็น generated column `lower(identity_data->>'email')` ห้าม insert ตรง)
2. **คอลัมน์ `*_token` เป็น NULL แทนที่จะเป็น `''`** — `confirmation_token`/`recovery_token`/`email_change_token_new`/`email_change`/`phone_change`/`phone_change_token`/`reauthentication_token`/`email_change_token_current` ทั้งหมดต้องเป็น empty string ไม่ใช่ NULL (ค่า default ของคอลัมน์ตอน INSERT แบบไม่ระบุ) — GoTrue (Go) scan คอลัมน์พวกนี้เป็น `string` ธรรมดา ไม่ใช่ `sql.NullString` ได้ NULL มาแล้ว panic ที่ scan layer พอดี error จริงคือ `"error finding user: sql: Scan error on column index 3, name \"confirmation_token\": converting NULL to string is unsupported"` — GoTrue ครอบ error นี้เป็น `500 Database error querying schema` ที่ REST response เห็นข้อความจริงไม่ได้ ต้องดูจาก `auth_logs` (`query_logs` MCP tool, `source = 'auth_logs'`) เท่านั้น

**วิธีตรวจ error จริงเมื่อ login พังแบบ generic:** `curl -X POST '<PROJECT_URL>/auth/v1/token?grant_type=password' -H "apikey: <anon key>" -d '{"email":...,"password":...}'` แล้วดู `auth_logs` ถ้า response แค่ `500 unexpected_failure` — REST response ไม่มีรายละเอียดพอ

**ทางแก้:** หลัง `INSERT INTO auth.users` ต้อง (1) `INSERT INTO auth.identities (id, provider_id, user_id, identity_data, provider, ...)` คู่กันเสมอ (2) explicit ใส่ `''` ให้ทุกคอลัมน์ `*_token`/`email_change`/`phone_change` แทนปล่อย default — สองข้อนี้ signup ผ่านแอปจริง/Admin API ทำให้อัตโนมัติอยู่แล้ว มีปัญหาเฉพาะตอน insert ตรงด้วย SQL เท่านั้น

**ใช้แล้วที่:** L1 (สร้างบัญชีทดสอบ `mju6500000002@mju.ac.th` สำหรับเทส L7 report-a-listing) — ก่อนบอกว่าบัญชีทดสอบที่สร้างด้วย SQL "ใช้ได้" ต้อง curl ทดสอบ login จริงก่อนเสมอ อย่าเชื่อแค่ว่า insert สำเร็จ + trigger สร้าง Profile ได้

---

## PT-21 — 🔴 `ensure*` ที่ "ยังแมตช์อยู่" ก็อันตรายได้พอกับที่ key ตายไปแล้ว — ต้อง retire ทุกครั้งหลังสำเร็จ ไม่มีข้อยกเว้น (2026-08-15)

PT-16/17/19 พูดถึงกรณี `ensureReplaced`/`ensureInsertedInto` ที่ key **ตายไปแล้ว** (ทำให้ validate fail หรือสร้าง orphan) — นี่คือกรณีที่ 3 ที่อันตรายไม่แพ้กัน: **`ensureReplaced` ที่ key ยังแมตช์ถูกต้องทุกครั้ง แต่เนื้อหาที่มัน replace เข้าไปเป็นเวอร์ชัน**เก่า**ที่ไม่รวมของที่เพิ่มเข้าไปทีหลัง**

**เคสจริง:** `ProductDetailsBody`'s `ensureReplaced` (สร้างตอน L3 ยุคแรก) ถูกทิ้งไว้ active เดินทุก push โดยไม่มีใครสังเกต — พัง 1 push ให้หลังตอนเพิ่ม `ContactAdminButton` เข้าไปเป็น **child ของ subtree เดียวกัน** ผ่าน `ensureInsertedInto` แยกต่างหาก: ทุกครั้งที่ push ใด ๆ ก็ตาม (ไม่ต้องเกี่ยวกับ `ProductDetails` เลย) สคริปต์รันทั้งไฟล์ ทำให้ `ensureReplaced` ตัวเก่าคืนค่า subtree กลับไปเป็นเวอร์ชันดั้งเดิม (ไม่มีปุ่ม) ทับของใหม่ทุกครั้ง — ปุ่มหายไปเงียบ ๆ โดยไม่มี error ใด ๆ เลย ทั้ง validate และ push ผ่านปกติทุกรอบ

**ทำไมเพิ่งเจอตอนนี้:** ตรวจสอบ `Reports`/`ReportDetail`/`Home` bell icon (ที่มี `ensureReplaced`/`ensureInsertedInto` เก่าทิ้งไว้ active เหมือนกัน) แล้วพบว่า**ไม่มีปัญหา** เพราะไม่เคยมีอะไรถูกเพิ่มเข้าไปใน subtree ของมันทีหลัง — สิ่งที่ทำให้ `ProductDetailsBody` ต่างออกไปคือมี `ensureInsertedInto` แยกต่างหากมาแตะ child ของมันในภายหลัง เป็น**combo**ที่อันตราย ไม่ใช่แค่การทิ้ง `ensureReplaced` ไว้เฉย ๆ

**กฎใหม่ (เข้มกว่า PT-16 เดิม):** `ensureReplaced`/`ensureInsertedInto` ทุกตัวที่สำเร็จแล้ว **ต้อง retire ทันที** ไม่ว่า key จะยังแมตช์อยู่หรือไม่ก็ตาม และไม่ว่าจะเคยเห็นปัญหาจริงหรือยัง — "ยังไม่เจอปัญหา" ไม่ใช่ "ปลอดภัย" ถ้ามีอะไรมาแตะ subtree เดียวกันทีหลังเมื่อไหร่ก็พังทันทีแบบไม่มี error เตือน ก่อนแตะ `dsl/edit.dart` ทุกครั้ง: `grep -n "page.ensureReplaced(\|page.ensureInsertedInto("` แล้วเช็คว่าทุกก้อนที่เจอ**ต้องเป็นของ push นี้เท่านั้น** ถ้าเจอก้อนเก่าที่ค้างอยู่ (ไม่ใช่ `PendingProductsList` ที่มีข้อยกเว้นถาวรตาม PT-19) ให้ retire ทิ้งทันทีไม่ต้องรอให้พังก่อน

**ใช้แล้วที่:** L3 `ProductDetails` (D-27) — สำรวจทั้งไฟล์แล้ว retire เพิ่ม `ReportsList`/`ReportDetailContent`/`Home` bell icon/ทิ้ง dead code `PendingProductsList` เวอร์ชันเก่าที่ target key ตายไปนานแล้ว (`ListView_mctnycd6`) ที่ไม่เคยถูกลบออกเลยตั้งแต่หลายรอบก่อนหน้า

---

## PT-22 — 🔴 `ensurePage`'s inline `state:`/`onLoad:` ใช้ไม่ได้ถ้า `body:` เดียวกันอ้างถึง state นั้น — ต้องแยกพุช (พบทำ L4 `chatMessages` 2026-08-16)

สร้างหน้าใหม่ด้วย `app.ensurePage(name, state: {'x': listOf(table)}, onLoad: [PostgresQuery(...), SetState('x', ActionOutput(...))], body: Scaffold(...ListView(source: State('x'))))` **ทั้งหมดในคำสั่งเดียว** — validate fail ด้วย `Field "x" has an update value that is not properly set` (จาก `SetState`) + `Dynamic children variable not properly configured` (จาก `ListView`) แม้โครงสร้างจะเหมือน `HomeAdmin`'s `PendingProductsList` (state.ensureField + editPageOnLoad แยกคำสั่ง) เป๊ะ — ทดสอบแล้วว่าไม่เกี่ยวกับ table vs view (ลองทั้งคู่ พังเหมือนกัน)

**ทางแก้:** พุชแรกสร้างหน้าด้วย `ensurePage` แบบ **ไม่มี** `state:`/`onLoad:` (body ใส่ placeholder เฉย ๆ) พุชสอง (หลังพุชแรกสำเร็จแล้วเท่านั้น) ค่อยเติม `state.ensureField`/`editPageOnLoad`/`editPage` — เหมือนวิธีที่ `chatList`/`HomeAdmin` ที่แก้ "หน้าที่มีอยู่แล้ว" ใช้อยู่แล้ว ต่างกันแค่ต้องรอให้หน้าใหม่ "มีอยู่แล้ว" จากพุชก่อนหน้าก่อน

**กระทบเดียวกัน:** widget ใหม่ (เช่น `TextField`/`IconButton`) ที่ `ensureReplaced`/`ensureInsertedAfter` แทรกเข้าไป **อ้างชื่อตัวเอง** (`WidgetState('name', ...)`/`ClearTextField('name')`) ในพุชเดียวกันไม่ได้เหมือนกัน — error รูปแบบเดียวกัน (`Widget "name" was not found on "Page"`) ทางแก้เดียวกัน: พุชแยก โดยฝั่ง action ให้ใช้ `page.ensureActions(page.findByKey(realKey), triggerType:, actions:)` แทนการฝัง `onTap:` ตรง ๆ ตอนสร้าง widget — `ensureActions` เป็น idempotent จริง (rerun แล้วแทนที่ trigger chain เดิม ไม่ error ไม่ซ้ำ) ต่างจาก `ensureReplaced`/`ensureInsertedInto` จึง **ไม่ต้อง retire ทิ้งตาม PT-16/21** ปล่อยไว้ในสคริปต์ถาวรได้

**ใช้แล้วที่:** L4 `chatMessages` (state `messages` + ListView), ปุ่มส่งข้อความ `SendMessageButton` (แยก `ensureActions` ออกจาก `ensureReplaced` ที่สร้างปุ่ม) — เช็คทุกครั้งที่สร้างหน้า/widget ใหม่ที่มี state-list หรือ action อ้างชื่อตัวเองในคำสั่งเดียวกัน

---

## PT-23 — 🔴 กับดักย่อยตอนเดินสาย entry-point ปุ่มใหม่ที่เรียก RPC + ผ่านค่าข้าม item scope (พบทำ L4 ProductDetails→chatMessages 2026-08-16)

1. **`ItemRef()` field access (`const ItemRef()['col']`) ใช้ได้เฉพาะตอน author `ListView(itemBuilder: (item) => ...)` สด ๆ ในสเตทเมนต์เดียวกันเท่านั้น** — เอาไปใช้ตอน `ensureInsertedAfter`/`ensureReplaced` เข้า itemBuilder scope ที่มีอยู่แล้ว (แม้ตำแหน่งจะอยู่ "ข้างใน" list จริง) compile ไม่ผ่าน: `Item field access "col" used outside a ListView builder` **ไม่มีทางเวิร์กอะราวด์ตรง ๆ** — ถ้าต้องการ field จากแถวของ list ที่มีอยู่แล้ว ต้องหาทางอื่นที่ไม่ใช่แทรก widget เข้าไปข้างใน (เช่น ให้ custom action ไปดึงค่านั้นเองจาก field อื่นที่ไม่ใช่ item-scoped)
2. **ไม่มี DSL action เรียก Postgres RPC ตรง ๆ** ("Supabase Function Call") — เช็คแล้วทั้ง `actions.dart` และทุก reference ที่มีคำว่า Supabase ไม่มี ต้องใช้ custom action 0-argument (**PT-09**) เรียก `Supabase.instance.client.rpc(name, params: {...})` เอง
3. **`CallCustomAction` ผ่านทาง callable-handle sugar (`fn(outputAs: 'x')`) ไม่รู้จัก `outputAs`** เป็นพารามิเตอร์พิเศษ — ตีความเป็น argument ที่ไม่ได้ประกาศแล้ว throw `Unknown argument(s)... Declared args: (none)` ต้องเรียกผ่าน constructor ตรง ๆ แทน: `CallCustomAction(fn, outputAs: 'x')`
4. **`SetState(...)` เขียนได้แค่ page state — เขียน app state ไม่ได้** แม้ resolve field name ผ่านแบบเดียวกัน error ที่ได้คือ `State field "x" not found on "PageName"` (ดูเผิน ๆ เหมือน field ไม่มี ทั้งที่ `app.state(...)` ประกาศไว้แล้วจริง) ต้องใช้ `UpdateAppState.set(field, value)` แทน (คนละคลาสกับ `SetState` แม้ signature คล้ายกัน)
5. **List-typed argument ของ custom function generate เป็น nullable เสมอ** (`List<String>? nicknamesList`) เหมือน scalar params ที่ PT-12 ข้อ 7 เคยเจอ (ขยายกฎ: ไม่ใช่แค่ `String?` แต่ list ก็ nullable ด้วย) — ถ้า body เข้าถึง `.length`/`[i]` โดยไม่ guard `?? []` ก่อน จะ**คอมไพล์ไม่ผ่าน** (`dart analyze` จริง ไม่ใช่แค่ validate ของ `flutterflow ai run` ที่เป็นแค่ shape/format check ข้ามการเช็ค type ข้ามไฟล์) กระทบทั้งโปรเจกต์เพราะ custom function ทุกตัวอยู่ไฟล์เดียวกัน (`custom_functions.dart`) — 1 ฟังก์ชันพังคือทั้งแอปคอมไพล์ไม่ผ่าน
6. **page param ที่ตั้ง `.withDefault(...)` ไม่ได้ทำให้ constructor field ของ widget เป็น non-null** — `int_.withDefault(0)`/`listOf(string).withDefault(<String>[])` ยัง generate เป็น `int? chatId`/`List<String>? memberNames` เฉย ๆ ไม่มี fallback ผูกอยู่ที่ constructor เลย (ต่างจากที่คาดตามกฎ "Default values on params" ใน `CLAUDE.md`) — จุดที่ Navigate ไปโดยไม่ส่ง param บาง key (เช่น ปุ่มจาก `ProductDetails` ที่ส่งแค่ `chatId` ไม่ส่ง `memberNames`/`userIds`) ปลายทางได้ `null` จริง ไม่ใช่ list ว่าง ต้อง guard ที่ปลายทาง (custom function ข้อ 5) ไม่ใช่หวังพึ่ง default ที่ page param
7. **ไม่มี list-literal expression** — `normalizeExpression` รับแค่ `DslExpression`/`null`/`String`/`num`/`bool` ส่ง Dart `List` literal ตรง ๆ เป็นค่า param (เช่น `params: {'x': [a, b]}`) จะได้ `Expected a DSL expression or scalar literal` ไม่มีทางสร้าง array literal ผ่าน DSL นี้ได้เลยในเวอร์ชันนี้ ถ้าต้องส่ง list ต้องมี field ที่เป็น array อยู่แล้วจาก query/state (เช่น `item['some_array_col']`) ไม่ใช่ประกอบขึ้นเองสด ๆ

**ใช้แล้วที่:** L4 `ChatWithSellerButton` (ปุ่ม "แชทกับผู้ขาย" บน `ProductDetails`) — เช็คทุกครั้งที่ต้องเรียก RPC จากปุ่มใหม่ หรือ Navigate ข้าม page พร้อมพารามิเตอร์ที่มาจาก item/list scope

---

## PT-24 — bubble UI + ส่งรูปบน `chatMessages` (พบทำ L4 2026-08-18)

1. **🔴 PT-12 §11 ("nullable Postgres text column → Dart `String` ไม่ใช่ `String?`, ใช้ `''` แทน null") ใช้ไม่ได้กับ Supabase table/view row model** — `ChatMessagesViewRow.message`/`.imageUrl` เป็น genuine `String?` จริง (`getField<String>(...)`) เทียบ `Equals(item['field'], '')` กับ null จริงได้ `false` (การ์ดเปิดผ่านทั้งที่ยัง null) แล้ว `field!` crash runtime ("Unexpected null value") — PT-12 §11 ใช้ได้เฉพาะ binding path ที่มันถูกพบมาเดิม ไม่ใช่กฎทั่วไป **วิธีเช็คก่อนเชื่อ:** เปิด `generated_code/lib/backend/supabase/database/tables/<table>.dart` ดู getter จริงเสมอ ก่อนใช้ `Equals(item['x'], '')` เป็นตัวเช็ค null
   **ทางแก้ที่ปลอดภัยกว่า:** เพิ่มคอลัมน์ boolean คำนวณ (`(col IS NOT NULL) AS has_x`) เข้า view แล้วใช้เป็น `visible:` ตรง ๆ — SQL เช็ค null ได้ไม่กำกวม ไม่ต้องเดา Dart nullability (pattern เดียวกับ D-38's `first_image_url`)
2. **field ที่เพิ่งลง `postgres_helpers.addTableField` ใช้ผ่าน `item['field']` ในพุชเดียวกันไม่ได้** — ขยาย PT-17 §1 (เดิมพูดถึง table ใหม่) ให้ครอบคลุม **field ใหม่บน table/view ที่มีอยู่แล้วด้วย**: `Bad state: Field "x.y" was not compiled.` เจอซ้ำ 2 ครั้งแล้ว (D-38 `first_image_url`, D-41 `has_message`/`has_image`) ต้องแยกพุชเสมอ: พุชแรกลงทะเบียน field อย่างเดียว ยืนยันจาก `lib/flutterflow_project/schemas.dart` แล้วค่อยพุชที่ใช้ `item['field']`
3. **`Expanded` vs `shrinkWrap: true` แก้คนละปัญหา อย่าจำเป็นสูตรเดียว** — `shrinkWrap: true` (D-40) ใช้เมื่อ `ListView` **ไม่มี** `Expanded` ancestor โดยตั้งใจ (list ควรสูงเท่าเนื้อหา หน้าทั้งหน้าเป็นตัวเลื่อนแทน) ส่วน `Expanded` (ไม่ใส่ `shrinkWrap`) ใช้เมื่อต้องการให้ list ขยายเต็มพื้นที่ที่เหลือระหว่าง header กับ footer ที่ fix ตำแหน่ง (เช่น ComposeBar ต้องติดขอบล่างจอ) — ใส่ `shrinkWrap: true` ผิดที่ (ไม่มี `Expanded`) ทำให้ทั้ง Column หดตัวลอยกลางจอแทนที่จะเต็มจอ
4. **`outputAs` default ของ action (`PostgresCreate` → `'rows'`) ชนกันได้ข้าม **widget คนละตัว** บนหน้าเดียวกัน** ไม่ใช่แค่ chip/loop ซ้ำแบบที่ D-37/D-39 เคยเจอ — error: `Action in <WidgetA> has an output variable with the same name as that of another widget.` ชี้ไปที่ widget อื่นที่ชนด้วย ไม่ใช่ widget ที่เพิ่งแก้ ทำให้เดาผิดจุดได้ง่าย ตั้ง `outputAs` explicit เสมอเมื่อมี Postgres write action มากกว่า 1 จุดบนหน้าเดียวกัน
5. **DSL ไม่มี `onLongPress` เป็น widget constructor property เลยสักตัว** (เช็ค `widgets.dart` ทั้งไฟล์แล้ว มีแค่ `onTap`; `ActionCallbackKind.onLongPress` มีอยู่แต่เป็นแค่ type marker สำหรับ custom-widget param ไม่ใช่ property ที่ตั้งได้ตรง ๆ) และห้ามพยายามผูก `ON_LONG_PRESS` ทีหลังผ่าน `ensureActions` บน per-item node ในพุชถัดไปถ้าต้อง pass ค่า item-scoped (เช่น URL รูป) เข้า action ด้วย — ชน PT-23 §1 (ItemRef ใช้นอก itemBuilder สดไม่ได้) แน่นอน ให้ผูก `onTap` แทนตั้งแต่ตอน author itemBuilder สด (ที่ ItemRef ยังใช้ได้) แทนการไล่หา long-press workaround

**ใช้แล้วที่:** L4 `chatMessages` (bubble UI + ปุ่มแนบรูป + `FullImageViewer` component) — เช็คก่อนแตะ list ที่ render ข้อมูลจาก Supabase table/view row model โดยตรง (ไม่ใช่ query builder ธรรมดา) หรือหน้าที่มี list + footer แบบ compose bar

## PT-25 — 🔴 ขีดจำกัดจริงของ `item[]`/`ItemRef()` ใน itemBuilder: action param, helper function, Image ตัวที่ 2 (พบทำ L3 `ProductDetails` carousel 2026-08-19)

พบ 3 ข้อจากการ isolate ทีละตัวแปรกว่า 20 พุช (ทุกข้อยืนยันแยกกันจริง ไม่ใช่เดารวมกัน) — ขยาย PT-23 §1 ("ItemRef ใช้นอก itemBuilder สดไม่ได้") ให้ครอบคลุมกรณีที่ **อยู่ใน itemBuilder สดจริง** แต่ก็ยังพังอยู่ดี:

1. **`item['field']` ใช้เป็น param/value ของ action ไม่ได้เลยสักตัว** — ลองแล้วพังเหมือนกันหมดทั้ง `Navigate(...).params`, `ShowDialog.component(...).params`, `ShowBottomSheet(...).params`, `SetState(field, item['x'])` แม้โครงสร้างจะ**เหมือนโค้ดที่ push ผ่านจริงอยู่แล้วเป๊ะ** (`MyPostsList`'s `onTap: Navigate(ff.Pages.productDetails, params: {'productId': item['id']})`) — สาเหตุที่โค้ดนั้นดูเหมือนใช้ได้จริงยังไม่ทราบแน่ชัด (อาจเป็นเพราะ `findByKey(...)` เป้าหมายของมัน drift แล้วเลย no-op ไม่ได้ re-validate จริงในพุชที่ทดสอบ — ดู PT-19 เรื่อง key drift) error ที่ได้เสมอ: `Parameter X ... not properly set` + `Generator variable does not exist` ลามไปทุก node ที่เหลือใน itemBuilder เดียวกัน แม้ node ที่ไม่เกี่ยวเลยก็โดน (เช่น Text อื่นๆ ในการ์ดเดียวกัน) — **ถ้าต้องการ item-scoped value เข้า action จริงๆ ให้ทำ scaffold-level `databaseRequest` + `nodeKeyRef` (PT-14/ProfileUser) แทน ไม่ใช่ item[]**
2. **`item['field']` ผ่าน Dart helper function ไม่ได้** — ฟังก์ชันแบบ `Container photoSlot(DslExpression url, ...) => Container(...)` เรียกด้วย `photoSlot(item['x'], ...)` จาก itemBuilder พังทันที**แม้ไม่มี action เลย** (แค่ property ธรรมดาอย่าง `Image`'s src กับ `visible:`) ต้อง inline literal ตรงจุดเรียกเท่านั้น (ซ้ำโค้ดได้ อย่าสกัดเป็นฟังก์ชัน) — เหตุผลลึกไม่ทราบ (compiler ไม่น่าอ่าน Dart source ได้ น่าจะเป็น ambient/thread-local state บางอย่างที่ขาดตอนตรง function boundary)
3. **🔴 มี `Image` widget ที่ผูกกับ `item[]` ได้แค่ 1 ตัวต่อ itemBuilder** — ตัวบล็อกที่แก้ไม่ได้เลยในขอบเขตนี้ ลองใส่ `Image` ตัวที่ 2 (คนละ field, field เดียวกันก็ได้) ทั้งอยู่ใน `Row` และเป็น sibling ตรงๆ, มี/ไม่มี `visible:`, ตั้ง `name:` ไม่ซ้ำกันแล้ว — พังเหมือนเดิมทุกครั้งด้วย error แบบเดียวกับข้อ 1/2 ไม่มีเวิร์กอะราวด์ตรงๆ ในขอบเขต itemBuilder เดียวกัน — ถ้าต้องมีรูปที่ 2/3 ต้องไปทาง scaffold-level `databaseRequest`+`nodeKeyRef` เหมือนข้อ 1

**ใช้แล้วที่:** L3 `ProductDetails` (`ProductDetailsContent`) — multi-photo carousel + tap-to-view-full-image ถูก**ยกเลิก**เพราะข้อ 1/3 บล็อกจริง (D-43) เช็คก่อนพยายามทำ list ที่มีมากกว่า 1 รูป/ปุ่มที่ต้อง pass item-scoped value เข้า action

## PT-26 — scaffold-level `databaseRequest` + `nodeKeyRef` แก้ PT-25 ได้จริง + static `visible:` literal ไม่ซ่อนอะไรเลย (พบทำ L3 `ProductDetails` รูปที่ 2/3 2026-08-19)

**ยืนยันว่า PT-25's ทางแก้ที่แนะไว้ใช้ได้จริง:** เลี่ยง `ListView`/`item[]` ทั้งหมด แล้วผูกรูปที่ 2/3 ผ่าน `page.node.databaseRequest` (raw proto, query แยกอิสระคนละตัวจากที่ list ใช้) + `nodeKeyRef`-based `FFVariable` แบบเดียวกับ `ProfileUser`/`HomeAdmin` (PT-14) — ไม่ชนขีดจำกัดข้อไหนใน PT-25 เลยเพราะไม่มี generator variable/list scoping เกี่ยวข้อง สำเร็จตั้งแต่พุชแรก

1. **filter ด้วย page param ใน raw proto:** ใช้ `FFVariableSource.WIDGET_CLASS_PARAMETER` + `FFBaseVariable(widgetClass: FFWidgetClassVariable(paramIdentifier: FFIdentifier(name:, key:)))` — ยืนยันตรงกับ SDK's เองที่ `variable_helpers.dart`'s `varFromPageParam(paramIdentifier)` helper เป๊ะ (`grep` เจอ implementation ตรงๆ ไม่ต้องเดา) ใช้ `ff.Pages.<page>.params.<param>` (จาก typed SDK) ดึง `.name`/`.key` มาใส่ ไม่ต้อง hardcode string
2. **bind รูปผ่าน raw proto:** `node.props.image.pathValue = FFStringValue(variable: ...)` — ยืนยันจาก compiler.dart:4276 (`node.props.image.pathValue = _compileStringValue(widget.path, env)` คือวิธีที่ typed `Image(path)` compile เองเป๊ะ) ไม่เคยมีตัวอย่างใน `dsl/edit.dart` มาก่อน (ProfileUser's avatar ผูก URL มาจากนอกสคริปต์) เป็นการใช้ shape นี้ครั้งแรกในโปรเจกต์ ยืนยันผลจริงจาก `generated_code/`: `CachedNetworkImage(imageUrl: row.secondImageUrl!, ...)` ตรงตามคาด
3. **🔴 `visible: <literal bool>` (ไม่ผูก variable) ไม่ทำให้ widget หายจริงในโค้ดที่ export** — ใช้ `visible: false` เป็นตัวซ่อนชั่วคราวระหว่างรอพุชถัดไป (เหมือนที่เคยใช้ได้ผลกับ `PageView`/`ProductImageGallery` component pattern อื่นๆ) แต่ครั้งนี้ Container/Image โผล่แบบไม่มี `if (...)` ห่อเลย (`imageUrl: ''` โชว์เป็นกล่องว่างบนแอปจริงช่วงสั้นๆ) เช็ค compiler source แล้วพบ: `visible: <literal bool>` → `setVisibility()` (`FFBooleanValue(inputValue:)`) คนละ path จาก `visible: <DslExpression>` (เช่น `Equals(...)`/`Not(...)`/field access) → `setConditionalVisibility()` (`FFBooleanValue(variable:)`) ที่ได้ `if (...)` จริงเสมอ — **ยังไม่รู้ว่า static `false` ควรจะ render ยังไง (`Visibility`/`Opacity` ที่ export ไม่โชว์?) หรือเป็นบั๊กของ export path** **กฎที่ใช้ได้จริง: ห้ามพึ่ง static `visible: false` เป็นตัวซ่อนชั่วคราว** — ถ้าต้อง 2 พุช (แทรก node ก่อน ผูกข้อมูลทีหลัง) ให้รีบทำพุชที่ผูก conditional (`variable:`-based) visibility จริงทันที อย่าปล่อยให้ static-false ค้างนานกว่าที่จำเป็น

**ใช้แล้วที่:** L3 `ProductDetails` รูปที่ 2/3 (D-44) — เช็คก่อนใช้ scaffold-level query pattern กับหน้าอื่น และก่อนใช้ static `visible: false`/`true` เป็นตัวซ่อน/โชว์ node ชั่วคราวระหว่าง 2 พุช

---

## PT-27 — 🔴 `List<PostgresRow>` state field รับค่าจาก `CustomFunction` ไม่ได้ + เปลี่ยน `orderBys` โดย `outputAs` เดิมไม่มีผล (พบทำ L3 `Home` search/shuffle 2026-08-19)

**1. `SetState('field', CustomFunction(...))` พังเมื่อ custom function รับ `List<PostgresRow>` ActionOutput เป็น argument — ไม่ว่า field ปลายทางจะ type อะไร (แก้ทฤษฎีเดิมแล้ว ดูข้อ 3 ของ D-46)** — compile ผ่านเสมอ (`CustomFunctionInvocation` compile เป็น `FFVariable(source: FUNCTION_CALL, ...)` ถูก type ตามที่ประกาศ) แต่ **push แล้ว validate fail ทุกครั้ง**: `Field "X" has an update value that is not properly set in Update App State action` — ตอนแรก (D-45) เข้าใจว่าปัญหาอยู่ที่ field ปลายทางเป็น `List<PostgresRow>` (`productsList`) แต่ D-46 ทดสอบซ้ำด้วย field ปลายทางเป็น `bool` (`hasNoResults`, custom function `isProductListEmpty(items) => items.isEmpty`) ก็พังด้วย error เดียวกันเป๊ะ **ทั้งที่ target ไม่ใช่ list แล้ว** — จุดร่วมจริงคือ custom function ทั้งสองตัวรับ `List<PostgresRow>` ActionOutput เป็น argument (`shuffleProducts`/`isProductListEmpty`) ส่วน `wrapSearchPattern` (D-46, ใช้ได้จริง) รับ argument เป็น `State(...)` string ธรรมดา ไม่ใช่ list เลย **สรุปที่แม่นกว่าเดิม:** custom function ที่กิน `List<PostgresRow>` ActionOutput เป็น input จะถูกปฏิเสธทุกครั้งที่ผลลัพธ์ไปจบที่ `SetState` (ยังไม่ยืนยัน 100% — ไม่มี local validator เตือนเลยทั้งสองกรณี, เจอแค่ตอน push จริง) **ถ้าต้อง transform/derive อะไรจาก list แบบนี้ (สุ่มลำดับ, เช็คว่าง) ต้องทำที่ SQL/view แทน** (เช่น สุ่ม → เพิ่มคอลัมน์ `random()` แล้ว `ORDER BY`; เช็คว่าง → ยังไม่มีทางออกที่ยืนยันแล้วว่าใช้ได้ ดู D-46 "ทางที่ยังไม่ลอง")

**2. เปลี่ยน `orderBys` ของ trigger ที่เคย push ไปแล้ว โดยใช้ `outputAs` เดิม — push สำเร็จแต่โค้ดที่ export ไม่เปลี่ยนเลย** — เปลี่ยนแค่ `PostgresOrderBy` field (เช่น `created_at` → คอลัมน์อื่น) แล้ว push ผ่าน `app.editPageOnLoad`/`page.ensureActions` compile ผ่าน push สำเร็จ `codegen status` บอก fresh แต่ `generated_code/` ยัง `.order(...)` field เดิมทุกจุด **แก้ได้ทันทีด้วยการเปลี่ยน `outputAs` เป็นชื่อใหม่** (ทดสอบแยกแล้วจริง: เปลี่ยนแค่ `outputAs` โดยไม่แตะอะไรอื่นเลย ก็ทำให้ orderBys ใหม่ปรากฏ) **สรุป:** `ensureActions`/`editPageOnLoad` ดูเหมือนจะ diff/no-op โดยยึด `outputAs` เป็นตัวตัดสินว่า trigger "เหมือนเดิม" ไหม ไม่สนว่า payload อื่น (`orderBys`) เปลี่ยนหรือเปล่า — เป็นกับดักคนละแบบกับ PT-15 §3 (ascending flag หาย แต่ field เปลี่ยนได้) **กฎที่ใช้ได้จริง: แก้ `orderBys` (หรือ payload อื่นของ query) ของ trigger ที่เคย push มาก่อนแล้ว ต้องเปลี่ยน `outputAs` ควบคู่ไปด้วยเสมอ ไม่งั้นการเปลี่ยนแปลงจะไม่ถูก re-emit**

**3. `CustomFunction(...)` ใช้เป็น `PostgresFilter.value` ได้จริง — ไม่ติดข้อจำกัดแบบข้อ 1 (D-46)** — เพราะ compile คนละเส้นทาง: `PostgresFilter.value` ไปทาง `_compileValue`/`_compileVariable` (compiler.dart:8390/8585) เส้นทางทั่วไปเดียวกับที่ `Snackbar` text/`Text` widget ใช้ `CustomFunction(...)` สำเร็จอยู่แล้ว **ไม่ใช่** เส้นทาง "Update App State" ที่ข้อ 1 พัง — ใช้จริงแล้ว: `wrapSearchPattern(keyword) => '%$keyword%'` ผูกเป็น `value:` ของ `PostgresFilter('title', relation: iLike, ...)` เพื่อทำ substring search (DSL ไม่มี string-concat expression ธรรมดาให้ใช้ตรง ๆ ใน filter value)

**4. Custom function parameter เป็น `nullable` เสมอในโค้ดที่ generate จริง ไม่ว่า `args:` จะประกาศ type อะไร** — `args: {'keyword': string}` ก็ยัง generate เป็น `String? keyword` (ยืนยันจาก `generated_code/lib/flutter_flow/custom_functions.dart`) เขียน body แบบไม่ null-check (`keyword.trim()`) แล้ว `flutterflow ai run` push ผ่านเฉย ๆ เพราะ validate แค่ FlutterFlow proto ไม่ได้ dart-compile ตัว custom code body จริง — พังตอน build แอปเท่านั้น จับได้จากอ่าน `generated_code/` เท่านั้น ไม่ใช่จาก push สำเร็จ ตรงกับกับดักเดิมที่เจอกับ `getOtherUsers`/`senderLabel` (chatMessages) **กฎ: เขียน custom function body ให้ null-safe เสมอ (`keyword ?? ''` ก่อนเรียก method) ไม่ว่า DSL type จะดูเหมือน non-nullable แค่ไหน** แก้ payload ที่ deploy ไปแล้วต้องใช้ `custom_code_helpers.updateCustomFunction` ไม่ใช่แก้ `app.customFunction` ซ้ำ (throw ถ้า payload mismatch)

**5. เลิก `app.customFunction(...)` declare ในสคริปต์ ≠ ลบออกจากโปรเจกต์จริง — ต้องเรียก `app.removeCustomFunction(...)` ชัดเจนเสมอ (D-47)** — ลบบรรทัดประกาศออกจาก `dsl/edit.dart` แล้ว push สำเร็จ (`[OK] compileDslApp`) หลอกว่า "เอาออกแล้ว" แต่ entity เดิมยังอยู่บนโปรเจกต์จริง (orphan) **ร้ายแรงกว่า widget เดี่ยว ๆ เพราะ custom function ทุกตัวในโปรเจกต์ compile รวมเป็นไฟล์เดียว (`custom_functions.dart`)** — ถ้าตัวที่ค้างมี type mismatch (เช่น `shuffleProducts` ที่ arg/return ถูกตั้งไม่ตรงกับ `listOf(...)` ที่ประกาศไว้แต่แรก ทั้งที่ body ยังทำเหมือนเป็น list) ทั้งไฟล์ compile ไม่ผ่าน กระทบฟังก์ชันอื่นที่ไม่เกี่ยวข้องเลยด้วย (error โผล่ตอนเปิดฟังก์ชันไหนก็ได้ในไฟล์เดียวกัน ไม่ใช่แค่ตัวที่พัง) **กฎ: เลิกใช้ entity อะไรก็ตาม (custom function/action/widget/page/ฯลฯ) ต้อง `app.removeX(...)` ให้ตรงชนิดเสมอ ไม่ใช่แค่ลบบรรทัด declare ออกจากสคริปต์**

**6. `iLike`/`like`/`contains` filter ไม่มี null-safe codegen — ผูกกับค่าที่เป็น variable (state/custom function) ไม่ได้เลย มีแต่ `equalTo` เท่านั้นที่ปลอดภัย (D-48)** — custom function return value เป็น `String?` เสมอ (ข้อ 4 ข้างบนคุม param, ข้อนี้คือ return) ลองย้ายไปผ่าน page-state field ก่อนคิดว่าจะ non-nullable — **ผิด**: ตรวจ `generated_code/lib/home/home_model.dart` พบว่า **ทุก page-state field เป็น `Type?` หมดไม่ว่า type อะไร** (`int? selectedCategoryId`, `String? searchQuery`) เหตุที่ query อื่นใช้ได้เพราะ `equalTo` compile ผ่าน `.eqOrNull(...)` เสมอ (null-safe โดยตัว relation เอง ไม่เกี่ยวกับที่มาของค่า) แต่ `iLike` ไม่มี "...OrNull" variant แบบนี้เลยในโค้ดที่ generate ออกมา — ผูก `iLike`/`like`/`contains` เข้ากับ `State(...)`/`CustomFunction(...)` จะได้ `dart analyze` error จริง (`argument_type_not_assignable`) แม้ `flutterflow ai run` push ผ่านเงียบ ๆ (ไม่ dart-compile หน้าที่เรียกใช้) **กฎ: ฟิลเตอร์ที่ผูกกับค่าไดนามิก (ไม่ใช่ literal ตรง ๆ) ใช้ได้แค่ `equalTo` เท่านั้นในโปรเจกต์นี้ — ถ้าต้อง substring/fuzzy match ต้องออกนอก typed-filter (RPC ผ่าน custom action เขียน null-handling เอง)**

**7. `Actions.conditional` (raw, `ui/actions.dart`) รับแค่ `FFVariable` ดิบ ไม่รับ `DslExpression` typed — ตัวที่ใช้ได้จริงคือ `If(...)` (`dsl/actions.dart`) (D-48)** — `If(condition, {required then, orElse})` รับ `condition:` เป็น `DslExpression` ตรง ๆ (เช่น `Equals(State('x'), '')`) normalize ให้เองผ่าน `normalizeExpression`, `then:`/`orElse:` รับ `List<DslAction>` ได้ตรง ๆ — ใช้แยก query เป็น 2 กิ่ง (มี filter / ไม่มี filter) ตามเงื่อนไข runtime ได้จริง โดยไม่ต้องยุ่งกับ raw proto เลย

**ใช้แล้วที่:** L3 `Home` — สุ่มลำดับสินค้า (D-45), ค้นหาแบบ substring + trigram index (D-46, ถอนแล้ว) ทั้ง onLoad, search/pull-to-refresh chain, และ 26 category chip ล้วนโดนข้อ 1-2 — `wrapSearchPattern` เจอข้อ 3-4 แล้วโดนข้อ 6 ด้วย (D-48, ถอน `iLike` กลับเป็น `equalTo` + `If` แยกกิ่ง) — `shuffleProducts`/`wrapSearchPattern` orphan (D-47/D-48) โดนข้อ 5 — เช็คก่อนใช้ custom function ป้อน list-typed state field ที่ไหนก็ตาม, ก่อนแก้ `orderBys`/query payload ของ trigger เดิมที่เคย push แล้ว, ก่อนเขียน custom function body แบบไม่ null-check, ก่อนผูก `iLike`/`like`/`contains` กับค่าไดนามิกใดๆ, และทุกครั้งที่ "เลิกใช้" entity ใดในสคริปต์ — เช็คว่าลบออกจริงด้วย `removeX` หรือแค่ลบบรรทัด declare

---

## PT-28 — บังคับกฎทับตารางที่เป็น allow-all: `RESTRICTIVE` policy + gate-in-view (D-52)

**1. `PERMISSIVE` policy ใหม่บนตารางที่มี allow-all อยู่ = ไม่มีผลเลย ต้องใช้ `AS RESTRICTIVE`** — policy ชนิดเดียวกัน **OR** กัน `true OR <เงื่อนไขใหม่>` เป็น `true` เสมอ (D-23 เคยเจอแล้วจึงเลี่ยงไปใช้ trigger) `RESTRICTIVE` อยู่คนละชุด ผลรวมคือ `(OR ของ permissive ทั้งหมด) AND (AND ของ restrictive ทั้งหมด)` จึงบังคับได้จริงโดยไม่ต้องแตะ allow-all เดิม — เหมาะกับกรณีที่ยังปิดหนี้ D-03 ไม่ได้แต่ต้องเพิ่มกฎเดี๋ยวนี้

**2. 🔴 `RESTRICTIVE` ที่ `USING` บล็อกแบบเงียบ — คืน 0 แถว ไม่ raise** ต่างจาก `WITH CHECK` ที่ raise `42501` ชัดเจน แปลว่า:
- `INSERT` (ใช้ `WITH CHECK`) → error จริง เห็นได้
- `UPDATE`/`DELETE` (ใช้ `USING` คัดแถวก่อน) → **สำเร็จ 0 แถว** ฝั่งแอปไม่เห็น error อะไรเลย
- **เทสด้วย "ไม่ error = ผ่าน" จะอ่านผลกลับด้าน** ต้องวัดด้วย `GET DIAGNOSTICS n = ROW_COUNT` เสมอ (D-52 อ่านผิดรอบแรกจริง — สรุปว่าผู้ถูกแบน UPDATE ประกาศได้ ทั้งที่แก้ 0 จาก 4 แถว)
- ผลข้างเคียงกับ FlutterFlow: PT-18 บอกว่า Postgres action ไม่มี `onSuccess`/`onFailure` อยู่แล้ว — เจอ `USING` บล็อกยิ่งเงียบสองชั้น **ต้องปิด affordance ที่ UI ด้วย อย่าพึ่ง RLS อย่างเดียวเป็น UX**

**3. helper function ใหม่ที่ policy เรียกใช้ ต้อง `GRANT EXECUTE TO authenticated` ให้ตรงกับตัวที่มีอยู่** — `REVOKE ... FROM PUBLIC, anon` (ตามกฎ D-29 §6) ตัด `authenticated` ทิ้งไปด้วยเพราะมันสืบทอดจาก `PUBLIC` ทำให้ policy ที่เรียกฟังก์ชันนั้นพังทั้งชุด **เช็คทุกครั้งด้วย `SELECT proname, proacl FROM pg_proc` แล้วเทียบกับ `private.is_admin()`** (ค่าที่ถูกคือ `{postgres=X, authenticated=X, service_role=X}`)

**4. ซ่อนข้อมูลด้วย gate-in-view คุ้มกว่าไปแก้ filter ทีละ query ฝั่ง FlutterFlow (ต่อยอด D-33)** — เติม `WHERE` ในตัว view ครั้งเดียวได้ผลกับ**ทุก** query ที่อ้าง view นั้น (`Home` onLoad + ค้นหา + 26 category chip + pull-to-refresh + `Mypost` + `ProductDetails` + `HomeAdmin`) เทียบกับการใส่ filter ฝั่ง FF ที่ต้องแก้ทุกจุด **และต้องเปลี่ยน `outputAs` ทุกตัวด้วย** (PT-27 §2) — สูตรที่ใช้ได้: `WHERE <ซ่อน> OR <เจ้าของตัวเอง> OR private.is_admin()` ให้เจ้าของยังเห็นของตัวเองและแอดมินยังตรวจงานได้
- 🔴 ฟังก์ชันที่อ่านคอลัมน์ของ**คนอื่น**ใน view ต้องเป็น **SECURITY DEFINER** ไม่งั้น RLS ซ่อนแถวแล้วคืน NULL → เงื่อนไขไม่ทำงาน (view เป็น `security_invoker = true`)
- 🔴 ใส่ `COALESCE(..., false)` เสมอ — มีบัญชี `auth.users` ที่ไม่มีแถว `"Profile"` จริงในระบบนี้ (D-32) NULL จะทำให้เงื่อนไขเพี้ยนทั้งชุด

**5. computed boolean ใน view = ตัวคุม `visible:` ที่ปลอดภัยที่สุด (ต่อยอด PT-24 §1)** — คำนวณเงื่อนไขซับซ้อน (เช่น "แบนได้ไหม" = ไม่ใช่ตัวเอง ∧ ไม่ใช่แอดมิน ∧ ยังไม่ถูกแบน) ที่ SQL แล้ว expose เป็นคอลัมน์ boolean ให้ UI ผูกตรง ๆ — เลี่ยง raw proto แบบ D-51 และเลี่ยง `Equals(item['f'], '')` ที่เทียบผิดกับ `String?` · UI ไม่ต้องรู้เงื่อนไขซ้ำ แก้กฎที่ SQL ที่เดียว

**ใช้แล้วที่:** L8 ระบบ ban user (D-52) — 5 RESTRICTIVE policy บน `products`/`reports`/`chat_message`, `products_review_view` ซ่อนประกาศผู้ถูกแบน, `admin_users_view.can_ban/can_unban/is_self` · เช็คก่อนเพิ่มกฎใด ๆ ทับตารางที่ยัง allow-all, ก่อนสรุปผลเทส `UPDATE`/`DELETE` ว่า "ผ่าน", และก่อนตัดสินใจไปไล่แก้ filter ทีละ query ฝั่ง FlutterFlow

---

## PT-29 — 🔴 ขีดจำกัดที่เจอตอนทำ UI ระบบ ban (D-52 Phase B–D, 2026-08-21)

**1. 🔴 ใน itemBuilder เดียว มี PostgresQuery ได้แค่ "ตัวเดียว" ต่อให้อยู่คนละ widget**
ปุ่ม Ban/Unban อยู่คนละ `IconButton` ใน itemBuilder เดียวกัน แต่ละตัวมี refetch chain ของตัวเอง → validate fail:
`IconButton 'UnbanUserButton' — Name "<outputAs>" already in use.` + `Action in UnbanUserButton has an output variable with the same name as that of another widget`
- ❌ **ตั้ง `outputAs` ไม่ซ้ำกันไม่ช่วย** (ลองแล้ว — D-39 ข้อนี้ไม่พอสำหรับเคสนี้) ลองเปลี่ยนชื่อให้ต่างกันสุด ๆ ก็ยัง fail
- ❌ **ทำให้ query signature ต่างกันก็ไม่ช่วย** (ลองเปลี่ยน `limit` 200→201 ยัง fail) → ไม่ใช่เรื่อง dedupe ตาม signature แบบ PT-24 §4
- ✅ **`CallCustomAction(outputAs:)` ไม่โดนข้อจำกัดนี้** — พิสูจน์แล้วว่า `unbanResult` อยู่ร่วมกับปุ่มอีกตัวที่มี query ได้ปกติ ข้อจำกัดเจาะจงที่ **backend query action** เท่านั้น
- ✅ **ทางแก้: ย้าย query ออกไปนอก itemBuilder** — วางปุ่ม/action ที่ยิง query ไว้ระดับหน้า (เช่นปุ่ม "รีเฟรช" ในหัวตาราง) แล้วให้ในแถวทำแค่ mutate + set App State
- ญาติกับ PT-25 §3 ("มี `item[]`-bound `Image` ได้แค่ 1 ตัวต่อ itemBuilder") — itemBuilder มีโควตาทรัพยากรบางอย่างเป็น 1 เสมอ **ออกแบบแถวโดยตั้งสมมติฐานว่าได้ query เดียว**

**2. 🔴 conditional visibility จาก boolean ของ view คอมไพล์เป็น `?? true` — NULL = โชว์**
`visible: item['can_ban']` ได้โค้ดจริงเป็น `if (userItem.canBan ?? true)` — **fallback เป็น `true` ไม่ใช่ `false`** ถ้าคอลัมน์เป็น NULL ปุ่มจะโผล่ทั้งที่ไม่ควร (เคสจริง: `can_ban` คำนวณจาก `p.role <> 'admin'` แต่ `role` nullable → `NULL <> 'admin'` = NULL → ปุ่มแบนโผล่บนแถวที่ไม่ควรแบน)
**กฎ: boolean ทุกตัวใน view ที่จะเอาไปผูก `visible:` ต้อง `COALESCE(..., false)` เสมอ** — อย่าพึ่งว่า "ข้อมูลจริงไม่มี NULL หรอก" · ใช้ `IS DISTINCT FROM` แทน `<>` เมื่อเทียบกับค่าที่อาจ NULL (`p.id <> auth.uid()` เป็น NULL ตอนยังไม่ล็อกอิน)

**3. typed handle ของ App State ต้องอยู่ "ข้างใน" `AppState(...)` ไม่ใช่แทนที่มัน — error message ชวนเข้าใจผิด**
validator บอก `Use ff.AppState.banTargetUserName instead of AppState("banTargetUserName")` ทำให้เขียนเป็น `ff.AppState.x` เปล่า ๆ แล้วเจอ `Expected a DSL expression or scalar literal` ตัวที่ถูกคือ **`AppState(ff.AppState.x)`** (handle เป็น `ProjectAppStateFieldHandle` ไม่ใช่ `DslExpression`) · ฝั่งเขียนใช้ `UpdateAppState.set(ff.AppState.x, ...)` รับ handle ตรง ๆ ได้
🔴 ข้อนี้โผล่ทันทีที่ app-state field ถูก push ขึ้นไปแล้ว (พุชก่อนหน้าเขียน `AppState('name')` ผ่านได้เพราะ field ยังไม่มีในโปรเจกต์)

**4. ชื่อ DSL ที่เขียนผิดบ่อย (คอมไพล์ไม่ผ่านทันที ไม่ใช่พังเงียบ)**
`Button('label', ...)` label เป็น **positional** ไม่ใช่ `text:` · `Expanded(child)` child เป็น **positional** ไม่ใช่ `child:` · `WidgetState('name', WidgetStateProperty.text)` ต้องมี **2 อาร์กิวเมนต์** · **`Snackbar`** ไม่ใช่ `SnackBar` · **ไม่มี `Actions.chain`** ใน edit flow — `onTap:` รับ `List<DslAction>` ตรง ๆ · `ensureReplaced` ต้องมี **`name:` บน root widget** ที่เอาไปแทน ไม่งั้น `requires an inserted or replacement root widget with a non-empty name`

**5. ยืนยัน PT-19 อีกครั้ง: key ของ `PendingProductsList` ดริฟต์จริงทุกครั้ง** — รอบนี้ `ListView_89z1y0to` → `ListView_qglcpyh5` ต้อง `inspect --page HomeAdmin --outline` แล้วอัปเดต `findByKey` **ก่อน push ทุกครั้ง** ไม่งั้นพังทั้งไฟล์

**6. `dart analyze` custom action แบบ standalone ทำได้จริง และควรทำ** — `flutterflow ai run` ไม่ dart-compile custom code (PT-12) ต้นเหตุ D-46/D-47 คัด body ออกจาก `generated_code/lib/custom_code/actions/*.dart` (ตัดหัว `// DO NOT REMOVE OR MODIFY THE CODE ABOVE!` ทิ้ง) แทน `Supabase.instance.client`/`FFAppState()` ด้วย stub แล้วรัน `dart analyze` ในโปรเจกต์เปล่า — จับ null-safety/syntax ได้ครบก่อนที่ pete จะเปิด Live Test Mode

**ใช้แล้วที่:** L8 `ManageUsers`/`BanUserSheet`/`BannedNoticeDialog`/`ReportDetail` (D-52) — เช็คก่อนออกแบบแถวที่มีปุ่มหลายปุ่มยิง query, ก่อนผูก `visible:` กับ boolean จาก view, และก่อน push แรกหลังเพิ่ม app-state field ใหม่
