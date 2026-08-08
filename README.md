# MJU Marketplace — เอกสารโปรเจกต์

เอกสารกำกับการพัฒนา **MJU Marketplace** — แอปซื้อ–ขายมือสองสำหรับนักศึกษา/บุคลากรมหาวิทยาลัยแม่โจ้ ยืนยันตัวตนผ่าน `@mju.ac.th`

Stack: **FlutterFlow** (UI/Action Flow) + **Supabase PostgreSQL** + **Claude Code** (SQL/RLS/Edge Function/custom Dart)

> repo นี้เก็บ **เอกสารอย่างเดียว** ไม่ใช่โค้ดแอป — โค้ด Flutter อยู่ที่ FlutterFlow (ดึงออกมาด้วย `export-code` เพื่อ debug เท่านั้น)

---

## เริ่มตรงไหน

| คุณคือ | อ่าน |
|---|---|
| Claude Code / AI agent | **`CLAUDE.md`** ← กฎการทำงานทั้งหมด อ่านก่อนเสมอ |
| คนที่กลับมาทำต่อ | `docs/STATUS.md` ← สถานะปัจจุบัน + คิวถัดไป |
| อยากรู้ว่า DB หน้าตายังไง | `docs/SCHEMA.md` |
| อยากรู้ว่าทำไมตัดสินใจแบบนี้ | `docs/DECISIONS.md` |
| อยากรู้ว่าเคยทดสอบอะไรไปแล้ว / ผลตรวจเป็นยังไง | `docs/VERIFICATION.md` |

## โครงสร้าง

```
CLAUDE.md              กฎห้ามข้าม + router บอกว่างานไหนอ่านไฟล์ไหน
docs/
├── INBOX.md           ที่ทิ้งสเปคใหม่ที่ยังไม่ได้จัดระเบียบ
├── SCHEMA.md          ⭐ ความจริงของ DB — เฉพาะที่ re-derive จาก catalog ได้เดี๋ยวนี้
├── VERIFICATION.md    🧪 ผลตรวจ/ผลทดสอบที่ผูกกับวันที่ (append-only, V-xx)
├── PROPOSED_SQL.md    🚧 SQL ที่ยังไม่ apply ทั้งหมด
├── PATTERNS.md        pattern ที่ใช้ซ้ำข้าม layer (PT-xx)
├── STATUS.md          สถานะ 8 layers + คำถามค้าง + แม่แบบเปิด session
├── DECISIONS.md       บันทึกการตัดสินใจ (D-xx)
├── AGENTS.md          บทบาท agent + write-ownership
├── layers/L1..L8      วิธีทำแต่ละ layer
└── checks/L1..L8.sql  query ตรวจสอบต่อ layer
.claude/agents/        นิยาม subagent — อยู่ที่นี่ที่เดียว ห้ามทำสำเนาไว้ใน docs/
```

## หลักการที่ทำให้เอกสารชุดนี้ไม่บวม

1. **schema อยู่ที่เดียว** — `SCHEMA.md` เท่านั้น ไฟล์อื่นอ้างอิง ไม่คัดลอกมาวาง
2. **แยก "apply แล้ว" ออกจาก "ยังไม่ apply"** — `SCHEMA.md` vs `PROPOSED_SQL.md` ปนกันเมื่อไหร่ agent จะเขียนโค้ดอ้างของที่ไม่มีอยู่จริง
3. **pattern ที่ใช้ ≥2 layer เขียนครั้งเดียว** ใน `PATTERNS.md` แล้วอ้างรหัส PT-xx
4. **ประวัติการตัดสินใจแยกจากวิธีทำ** — `DECISIONS.md` อ่านเมื่ออยากรู้ "ทำไม" ไม่ต้องอ่านตอนลงมือ
5. **แยก "ความจริงที่ re-derive ได้เดี๋ยวนี้" ออกจาก "ความจริง ณ วันนั้น"** — `SCHEMA.md` ต้อง query catalog ยืนยันได้ทุกบรรทัด ส่วนผลทดสอบ/ผล advisor/จำนวนแถว ไปอยู่ `VERIFICATION.md` แบบ append-only ปนกันเมื่อไหร่ schema จะเก่าโดยไม่มีใครรู้

ผลคืองาน 1 layer อ่าน ~200 บรรทัด แทนที่จะเป็นไฟล์รวม 500+ บรรทัด

## การอัปเดต

ดูหัวข้อ **"📤 Git workflow"** ใน `CLAUDE.md`
