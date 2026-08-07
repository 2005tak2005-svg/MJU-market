# AGENTS.md — บทบาท agent และสิทธิ์เขียนไฟล์

> โมเดลที่เลือก: **implementer ตัวเดียวไล่ L1→L8 + subagent read-only ไว้ตรวจ**
> เหตุผลที่ไม่ใช้ agent ต่อ layer อยู่ที่ `DECISIONS.md` D-08

---

## ⚠️ ข้อจำกัดจริงที่เจอตอนใช้งาน (2026-08-07) — อ่านก่อนวางแผนพึ่ง subagent

### 1. subagent เรียกได้เฉพาะบน Claude Code CLI

ไฟล์ใน `.claude/agents/` ติดตั้งครบแล้ว แต่**เรียกไม่ได้ทุกสภาพแวดล้อม**

| สภาพแวดล้อม | เรียก `db-verifier` ได้ไหม |
|---|---|
| `claude` ในเทอร์มินัล | ✅ ได้ |
| Cowork / เดสก์ท็อป | ❌ **ไม่ได้** — รายชื่อ agent ถูกล็อกไว้ตายตัว ขึ้น `Agent type 'db-verifier' not found` |

**ทางแก้เมื่อเรียกไม่ได้:** implementer รันเองตาม checklist ใน `.claude/agents/db-verifier.md` เป๊ะ ๆ
ได้ผลเท่ากัน เสียแค่ context isolation — **สิ่งที่ห้ามเสียคือความเข้มของการตรวจ ไม่ใช่ว่าใครรัน**

### 2. บรรทัด `tools:` — ห้าม hardcode ชื่อ Supabase MCP

โปรเจกต์นี้**ไม่มี `.mcp.json`** ชื่อ Supabase MCP จึงไม่คงที่:

- ผ่าน Cowork connector = UUID ที่เปลี่ยนทุก session
- ผ่าน CLI = แล้วแต่ `.mcp.json` ที่ยังไม่มี

ชื่อ `mcp__supabase__*` ที่เขียนไว้ในไฟล์รุ่นแรกเป็นแค่ **placeholder ที่ไม่เคยมีจริง** — hardcode ไว้แล้ว agent จะเรียก tool ไม่ได้แบบเงียบ ๆ

จึง**ตัดบรรทัด `tools:` ออก**จาก `db-verifier` / `doc-syncer` ให้ inherit จาก session แม่
(`ui-checker` คงไว้ได้ เพราะใช้ `Read, Glob, Grep, Bash` เป็น built-in ล้วน)

> 🔴 **ผลข้างเคียงที่ต้องรู้:** พอ inherit ทั้งหมด `db-verifier` จะได้ `Write`/`Edit` ติดมาด้วย
> กติกา **READ-ONLY จึงบังคับด้วย prompt เท่านั้น ไม่มีรั้วระดับ tool แล้ว**
> ถ้าอยากได้รั้วจริงคืนมา ต้องสร้าง `.mcp.json` ชื่อ `supabase` (ต้องใช้ Supabase access token ซึ่ง pete ต้องเป็นคนใส่) แล้วค่อย pin `tools:` กลับ

### 3. นิยาม subagent อยู่ที่เดียว

> 🔴 นิยาม subagent อยู่ที่ `.claude/agents/` **ที่เดียว**
> ห้ามทำสำเนาไว้ใน `docs/` — Claude Code โหลดจาก `.claude/` เท่านั้น
> สำเนาที่ไหนก็ตามจะกลายเป็นของเก่าที่ดูเหมือนของจริง

---

## บทบาท

| บทบาท | ใคร | ทำอะไร |
|---|---|---|
| **implementer** | Claude Code session หลัก | เขียน SQL / apply migration / เขียน Action Flow spec / แก้เอกสาร |
| **db-verifier** | subagent (read-only) | ตรวจ schema drift, RLS, รัน `checks/Lx.sql`, ทดสอบสิทธิ์ user ธรรมดา |
| **ui-checker** | subagent (read-only) | ตรวจชื่อตรง 3 จุด ระหว่าง Supabase ↔ FlutterFlow |
| **doc-syncer** | subagent (เขียนได้เฉพาะ STATUS.md) | ปิด session: sync เอกสารให้ตรงกับของจริง |
| **มนุษย์ (pete)** | — | ตัดสินใจ, ทำ FlutterFlow GUI, รัน migration ที่เสี่ยง |

---

## 🔒 Write-ownership (สำคัญ — กันเอกสารพังจากการเขียนชนกัน)

| ไฟล์ | เขียนได้ |
|---|---|
| `CLAUDE.md` | มนุษย์เท่านั้น |
| `docs/SCHEMA.md` | implementer |
| `docs/PROPOSED_SQL.md` | implementer |
| `docs/PATTERNS.md` | implementer |
| `docs/DECISIONS.md` | implementer (append only — ห้ามลบ D เก่า) |
| `docs/layers/*` | implementer |
| `docs/checks/*.sql` | implementer |
| `docs/STATUS.md` | implementer + doc-syncer (เฉพาะตอน implementer ว่าง) |
| **ทุกไฟล์** | verifier ทั้งหมด = **read-only ล้วน** คืนรายงานอย่างเดียว ห้ามแก้ไฟล์ |

**ห้าม verifier แก้ไฟล์เอง** — ถ้าเจอปัญหาให้รายงานกลับ ให้ implementer เป็นคนแก้ ไม่งั้นสองตัวเขียนทับกันแล้วเอกสารเพี้ยนแบบเงียบ ๆ

---

## จังหวะที่ควรเรียก subagent

| เมื่อไหร่ | เรียกใคร |
|---|---|
| ก่อนเริ่ม layer ใหม่ | `db-verifier` — ยืนยันว่า SCHEMA.md ตรงกับ DB จริงก่อนลงมือ |
| หลัง apply migration | `db-verifier` — ตรวจว่า apply ติดจริงและ RLS ไม่พัง |
| ปิด layer (ก่อนขึ้น layer ถัดไป) | `db-verifier` + `ui-checker` **พร้อมกัน** (ยิงขนานได้ เพราะไม่มีตัวไหนเขียน) |
| ก่อนจบ session | `doc-syncer` |

**จุดเดียวที่ขนานได้จริง** คือขั้นตรวจ — เพราะทุก verifier เป็น read-only จึงไม่มี conflict

---

## รูปแบบรายงานที่ verifier ต้องคืน

```
## ผลตรวจ Layer X — [PASS / FAIL]

### ✅ ผ่าน
- ...

### ❌ ไม่ผ่าน
- [หัวข้อ] คาดว่า: ... | พบจริง: ... | ไฟล์ที่ต้องแก้: ...

### ⚠️ ต้องดูเพิ่ม
- ...
```

ห้ามสรุปว่า "น่าจะโอเค" — ทุกข้อต้องมีผลจาก query จริงหรือ `flutterflow ai inspect` จริงมาอ้าง

### 🔴 3 คำที่ห้ามใช้ผิด (บทเรียนจากการตรวจจริงครั้งแรก 2026-08-07)

| อย่าเขียน | เขียนแบบนี้แทน | เพราะ |
|---|---|---|
| "PASS" ทั้งที่รันแค่ role `postgres` | "ยังไม่ได้ตรวจมุมมอง user" | `postgres` bypass RLS — ผ่านทุกข้ออัตโนมัติ |
| "PASS" ทั้งที่ตารางว่าง | "ตรวจไม่ได้ ยังไม่มีข้อมูล" | เช็ค "ห้ามมี NULL" กับ 0 แถวผ่านเสมอ |
| "apply แล้ว" = "ใช้งานได้" | แยกเป็น 2 ข้อ | P-01 อยู่ใน DB มานาน แต่ไม่เคยรันจริงจนกระทั่งมี user คนแรก |

**และห้ามอนุมานผลจากการไม่มีข้อมูล** — ตอนตรวจ P-02 การที่ `test@gmail.com` ไม่มีใน `auth.users` ตีความได้ทั้ง "ถูกปฏิเสธ" และ "ไม่ได้ลอง" ต้องไปดู auth log ถึงจะสรุปได้ว่าล้มเพราะ trigger เราจริง

---

## ทำไมไม่แตก agent ต่อ layer (สรุปย่อ)

layer พึ่งพากันจริง — `public_profiles` แก้ทีเดียวกระทบ L1/L2/L4, `find_or_create_chat` ใช้ร่วม L2/L3/L4, `products` แชร์ระหว่าง L2/L5, L6 trigger บนตารางของ L2/L4
บวกกับมี Supabase project เดียวและ FlutterFlow project เดียว ไม่มี branch ที่ merge ได้จริง → agent ขนานกันจะกลายเป็นงาน resolve conflict ของมนุษย์แทนที่จะเร็วขึ้น

**ข้อยกเว้นในอนาคต:** L6 (notifications) / L7 (reviews) / L8 (admin) สร้างตารางใหม่ที่ไม่ทับของเดิม — พอ L1–L5 นิ่งแล้วค่อยพิจารณาแตกขนานเฉพาะ 3 อันนี้
