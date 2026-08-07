# AGENTS.md — บทบาท agent และสิทธิ์เขียนไฟล์

> โมเดลที่เลือก: **implementer ตัวเดียวไล่ L1→L8 + subagent read-only ไว้ตรวจ**
> เหตุผลที่ไม่ใช้ agent ต่อ layer อยู่ที่ `DECISIONS.md` D-08

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

---

## ทำไมไม่แตก agent ต่อ layer (สรุปย่อ)

layer พึ่งพากันจริง — `public_profiles` แก้ทีเดียวกระทบ L1/L2/L4, `find_or_create_chat` ใช้ร่วม L2/L3/L4, `products` แชร์ระหว่าง L2/L5, L6 trigger บนตารางของ L2/L4
บวกกับมี Supabase project เดียวและ FlutterFlow project เดียว ไม่มี branch ที่ merge ได้จริง → agent ขนานกันจะกลายเป็นงาน resolve conflict ของมนุษย์แทนที่จะเร็วขึ้น

**ข้อยกเว้นในอนาคต:** L6 (notifications) / L7 (reviews) / L8 (admin) สร้างตารางใหม่ที่ไม่ทับของเดิม — พอ L1–L5 นิ่งแล้วค่อยพิจารณาแตกขนานเฉพาะ 3 อันนี้
