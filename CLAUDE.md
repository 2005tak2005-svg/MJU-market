# MJU Marketplace — กฎการทำงาน (อ่านไฟล์นี้ก่อนเสมอ)

แอปซื้อ–ขายมือสองสำหรับนักศึกษา/บุคลากร ม.แม่โจ้ ยืนยันตัวตนผ่าน `@mju.ac.th`
Stack: **FlutterFlow** (UI/Action Flow) + **Supabase PostgreSQL** `MJU market` (`rooydbxgcsybyanwsewv`) + **Claude Code** (SQL/RLS/Edge Function/custom Dart)

---

## 🔴 กฎห้ามข้าม

1. **ห้ามเขียน SQL หรือ Action Flow จากความจำ** — query schema จริงหรืออ่าน `docs/SCHEMA.md` ก่อนทุกครั้ง
2. **ห้ามสมมติว่า SQL ใน `docs/PROPOSED_SQL.md` มีอยู่จริงใน DB** — ทุกอย่างในไฟล์นั้นยังไม่ apply
3. **ชื่อต้องตรงเป๊ะ 3 จุด**: ชื่อคอลัมน์ Supabase ↔ ชื่อ Page/App State variable ↔ ชื่อ parameter ของ widget ที่ผูก Action — พลาดจุดเดียว Action Flow พังทันที
4. **Supabase-first** — schema + RLS ต้องสร้างและทดสอบผ่านก่อน ค่อยแตะ FlutterFlow UI
5. **ตารางว่าง + ปลอดภัย = apply เลย** ไม่ต้องขออนุญาต แล้วอัปเดตเอกสารตามทันที (อย่าเสนอแล้วรอ)
6. **`export-code` = diagnostic เท่านั้น** ห้าม edit โค้ดที่ export แล้ว re-import กลับ
7. **จบทุก session ต้องอัปเดต `docs/STATUS.md` + `docs/SCHEMA.md`** — ข้อนี้ถูกลืมบ่อยที่สุด และเป็นสาเหตุที่ session ถัดไปทำงานผิดมาตรฐาน
8. **`P` ตัวใหญ่ใน `"Profile"`** — ใน SQL ต้อง double-quote เสมอ ไม่งั้น Postgres หาไม่เจอ

---

## 🔧 กับดัก tool ที่เจอมาแล้ว (อย่าเสียเวลาซ้ำ)

| กับดัก | ทางแก้ |
|---|---|
| `execute_sql` หลายคำสั่งในครั้งเดียว | คืนผลแค่คำสั่ง**สุดท้าย** — verification query ต้องแยกรัน |
| `list_tables` (verbose) | ได้ระดับคอลัมน์ แต่**ไม่มี RLS policy** — ต้อง query `pg_policies` เอา `qual` + `with_check` |
| ชื่อ mixed-case ใน regclass | ต้อง quote ข้างใน: `'public."Profile"'::regclass` |
| FlutterFlow เทียบ string | **case-sensitive** — `"admin"` ≠ `"Admin"` |
| Realtime บน view | ทำงานที่ table level (Postgres replication) — ยังไม่ยืนยันว่า FlutterFlow listen บน view ได้จริง |
| plugin hook เป็น POSIX shell | Windows ต้องมี bash บน PATH (Git Bash / WSL) |
| Supabase Storage public bucket เสิร์ฟ `.html` | บังคับ `content-type: text/plain` เสมอ (anti-XSS) ต่อให้ `metadata.mimetype` ใน `storage.objects` บอกว่า `text/html` ก็ไม่ช่วย — เจอกับ `static-pages/email-confirmed.html` (D-19) แก้ด้วยการเปลี่ยนเป็น `.txt` ล้วนแทน อย่าพยายามโฮสต์หน้าเว็บ HTML ผ่าน Storage bucket |
| Site URL / Redirect URL / Email Templates ของ Auth | ไม่อยู่ใน Postgres เลย (`auth.config` ไม่มีจริง) เป็น platform config เข้าได้แค่ Dashboard หรือ Management API token (ไม่มีให้ผ่าน MCP) — แก้ email template ต้องเปิด custom SMTP ก่อนเสมอทุก plan (ดู D-19) |

**คำสั่ง `flutterflow ai` ที่ใช้ได้จริง:** `status <id>` / `inspect <id>` / `validate <file>` / `run <file>`
(`plan` / `trace` เป็นชื่อเก่า เลิกใช้แล้ว)
ใช้ `inspect` / `search` ดึงชื่อจริงจากโปรเจกต์ แทนพิมพ์ชื่อเอง — ลดโอกาสผิดกฎข้อ 3

---

## 🗺️ อ่านไฟล์ไหน

| งานที่จะทำ | อ่าน |
|---|---|
| เริ่ม session ใหม่ | `docs/STATUS.md` (มีแม่แบบเปิด session อยู่ท้ายไฟล์) |
| pete เขียนสเปคใหม่มา / สั่ง "จัดของใน INBOX" | `docs/INBOX.md` (มีวิธีกระจายอยู่ในไฟล์) |
| เขียน SQL / RLS / view / trigger | `docs/SCHEMA.md` → แล้วเช็คว่ามีข้อเสนอค้างไหมใน `docs/PROPOSED_SQL.md` |
| ทำ FlutterFlow UI / Action Flow | `docs/layers/Lx-*.md` + `docs/PATTERNS.md` |
| จะใช้ pattern ที่เคยทำแล้ว | `docs/PATTERNS.md` |
| "ทำไมถึงตัดสินใจแบบนี้" | `docs/DECISIONS.md` |
| "เคยทดสอบอะไรไปแล้วบ้าง / ผล advisor" | `docs/VERIFICATION.md` (append-only เรียงตามวันที่) |
| ตรวจงานที่ทำเสร็จ | `docs/checks/Lx.sql` |
| จะเรียก subagent | `docs/AGENTS.md` → นิยามตัวจริงอยู่ `.claude/agents/` เท่านั้น |

> ไม่ต้องอ่านทุกไฟล์ทุกครั้ง — เปิดเท่าที่ตารางบอก

---

## 📤 Git workflow

### 🔴 repo นี้มี clone เดียวเท่านั้น

```
~/Documents/ทักทาย 🤪/CLAUDE CODE      ← clone เดียวของ repo เอกสาร (Cowork mount ที่นี่)
~/Documents/flutterflow-export/        ← export ของ FlutterFlow อยู่ "นอก" repo
```

**ห้าม clone repo นี้ซ้ำที่อื่นบนเครื่องเดียวกัน** และ **ห้ามเอา export ของ FlutterFlow มาไว้ในโฟลเดอร์ repo**

เหตุผล: เคยมี clone ที่ 2 แล้ว 2 session commit สวนกันโดยไม่รู้ตัว (เกิดขึ้นจริง 2026-08-09) · `export-code` เป็น diagnostic (กฎข้อ 6) สร้างใหม่ได้เสมอ ไม่มีเหตุผลให้อยู่ใน repo

**ถ้าเจอ clone ที่ 2 โผล่มาอีก:** ตรวจ `git log origin/main..HEAD` ในอันนั้นก่อนว่าว่าง (= ไม่มี commit ค้าง) แล้วค่อยลบทิ้ง ย้ายเข้า Trash ไม่ใช่ `rm -rf`

⚠️ **ถ้า `git pull` ขึ้น `Unable to create .git/index.lock: File exists`** — เป็น lock ค้างจาก process ที่ตายไปแล้ว (เคยเกิดจาก agent รัน git ใน sandbox) เช็คว่าไม่มี git รันอยู่จริง แล้ว `rm .git/index.lock` ได้เลย

---

repo นี้เก็บเอกสารอย่างเดียว **commit ตรงเข้า `main`** ไม่ต้องทำ branch/PR

**Claude ต้อง commit เองทุกครั้งที่แก้เอกสารเสร็จเป็นก้อน** ไม่ต้องรอให้สั่ง — แต่**ต้องบอกสรุปว่า commit อะไรไปทุกครั้ง**

```bash
git add -A && git commit -m "..." && git push
```

**รูปแบบ commit message:**

```
<ประเภท>(<ขอบเขต>): <สรุปสั้น>

<รายละเอียด ถ้าจำเป็น>
```

| ประเภท | ใช้เมื่อ | ตัวอย่าง |
|---|---|---|
| `schema` | แก้ `SCHEMA.md` (DB เปลี่ยนจริง) | `schema(L1): เพิ่ม trigger handle_new_user` |
| `spec` | เพิ่ม/แก้สเปคใน `layers/*` | `spec(L3): เพิ่มปุ่มบันทึกสินค้าไว้ดูทีหลัง` |
| `sql` | แก้ `PROPOSED_SQL.md` | `sql: เพิ่ม P-10 RLS policy ของ reports` |
| `decision` | เพิ่ม D-xx | `decision: D-09 เลือกใช้ FCM สำหรับ push` |
| `pattern` | เพิ่ม/แก้ PT-xx | `pattern: PT-08 upload รูปเข้า Storage` |
| `status` | อัปเดต `STATUS.md` | `status: ปิด L1 ฝั่ง Supabase` |
| `inbox` | จัดของจาก INBOX เข้าที่ | `inbox: กระจายสเปค 3 รายการเข้า L3/L6` |
| `docs` | README / โครงสร้าง / กฎ | `docs: เพิ่มกฎ git workflow` |

**กฎ:**

1. **1 commit = 1 การเปลี่ยนแปลงเชิงความหมาย** — อย่ารวม "แก้ schema + เพิ่มสเปค 3 อัน" ไว้ commit เดียว ย้อนกลับทีหลังไม่ได้
2. **แก้ `SCHEMA.md` ต้อง commit แยกเสมอ** — เป็นไฟล์ที่ผิดแล้วกระทบทุก session ต้องหาต้นตอได้เร็ว
3. **ของที่จัดจาก INBOX ให้ commit พร้อมกับปลายทาง** — จะได้เห็นว่าสเปคไหนไปอยู่ไหน
4. **🔴 ห้าม commit secret** — Supabase `service_role` key, `FLUTTERFLOW_API_TOKEN`, `.env` (มี `.gitignore` กันไว้แล้ว แต่ให้ตรวจซ้ำก่อน `git add -A` ทุกครั้ง)
   `anon` key เปิดเผยได้ปกติ ไม่ใช่ความลับ แต่ก็ไม่ต้องเอามาใส่ในเอกสารโดยไม่จำเป็น
5. **ปิดทุก session ต้อง commit + push** — เอกสารที่แก้แล้วไม่ push = session ถัดไปในเครื่องอื่นทำงานกับข้อมูลเก่า

**ก่อนเริ่ม session:** `git pull` ก่อนเสมอ ไม่งั้นจะแก้ทับงานที่ push จากเครื่องอื่น

---

## ✅ Definition of Done ร่วม (ใช้กับทุก layer)

- [ ] ทดสอบกับ**ข้อมูลจริง**ใน Supabase ไม่ใช่แค่ schema ถูกต้อง
- [ ] ทดสอบด้วย**บัญชี user ธรรมดา ไม่ใช่แค่ admin** — RLS พังเงียบ ๆ ตรงนี้บ่อยที่สุด (บั๊ก `seller_name` / `member_names` เป็น NULL ทั้งชุดเกิดจากข้อนี้ข้อเดียว)
- [ ] รัน `docs/checks/Lx.sql` ผ่านครบทุกข้อ
- [ ] `docs/SCHEMA.md` + `docs/STATUS.md` อัปเดตแล้ว
- [ ] ถ้ามีการตัดสินใจใหม่ → บันทึกลง `docs/DECISIONS.md`

---

## 📁 โครงเอกสาร

```
CLAUDE.md              ← ไฟล์นี้ (กฎ + router)
docs/
├── INBOX.md           ✍️ pete ทิ้งสเปคใหม่ที่นี่ — Claude เป็นคนกระจายเข้าที่
├── SCHEMA.md          ⭐ ความจริงของ DB — เฉพาะที่ re-derive จาก catalog ได้เดี๋ยวนี้
├── VERIFICATION.md    🧪 ผลตรวจ/ผลทดสอบที่ผูกกับวันที่ (append-only) — ของที่ไม่ใช่ schema มาที่นี่
├── PROPOSED_SQL.md    🚧 SQL ที่ยังไม่ apply ทั้งหมด
├── PATTERNS.md        pattern ที่ใช้ซ้ำข้าม layer
├── STATUS.md          สถานะ 8 layers + คำถามค้าง + แม่แบบเปิด session
├── DECISIONS.md       บันทึกการตัดสินใจ + ความเข้าใจผิดที่แก้แล้ว
├── AGENTS.md          บทบาท agent + write-ownership
├── layers/L1..L8      วิธีทำแต่ละ layer
└── checks/L1..L8.sql  query ตรวจสอบ
.claude/agents/        นิยาม subagent (db-verifier / ui-checker / doc-syncer)
                       🔴 ที่เดียว — ห้ามทำสำเนาไว้ใน docs/
```
