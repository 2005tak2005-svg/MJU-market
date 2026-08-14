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
