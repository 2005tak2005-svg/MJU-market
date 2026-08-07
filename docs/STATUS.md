# STATUS.md — สถานะโปรเจกต์ + จุดเริ่ม session

> 📍 **เปิดไฟล์นี้เป็นไฟล์แรกของทุก session**
> อัปเดตล่าสุด: **2026-08-02**

---

## 🔥 คิวถัดไป (3 อันดับ)

1. **P-01** สร้าง trigger auto-insert `Profile` → ปิด Layer 1 ฝั่ง Supabase
2. **Seed ตาราง `CAT`** (ยังว่าง 0 แถว) → ปลดล็อก dropdown หมวดหมู่ใน `AddProduct`
3. **สร้าง Storage bucket `product-images`** + policy → ปลดล็อกอัปโหลดรูปใน L2

---

## สถานะ 8 Layers

| L | ชื่อ | Supabase | FlutterFlow | หมายเหตุ |
|---|---|---|---|---|
| 1 | Auth & User Profiles | 🟨 เหลือ trigger auto-insert | ⬜ ยังไม่สร้างหน้า | schema/RLS ครบแล้ว |
| 2 | Product Listings + Storage | 🟨 เหลือ Storage bucket + seed CAT | 🟨 approve/reject ปุ่มเริ่มทำแล้วบางส่วน | schema/RLS/view/realtime เสร็จ |
| 3 | Browse / Search / Filter | ⬜ | ⬜ | ใช้ view เดิม ไม่มีตารางใหม่ |
| 4 | Chat & Messaging | ✅ 100% | ⬜ ยังไม่เริ่ม | RLS เป็น allow-all ชั่วคราว |
| 5 | Transaction & Status | ⬜ ยังไม่มีตาราง `transactions` | ⬜ | |
| 6 | Notifications | ⬜ ยังไม่มีตาราง | ⬜ | |
| 7 | Reviews & Reports | 🟨 `reports` มีแล้ว (ไม่มี policy) / `reviews` ยังไม่มี | ⬜ | |
| 8 | Admin Dashboard | ⬜ | ⬜ | |

✅ เสร็จ · 🟨 กำลังทำ · ⬜ ยังไม่เริ่ม

---

## ❓ คำถามที่ยังไม่ตัดสินใจ (รวมทุก layer)

**Layer 1**
- จะทำ role-based redirect ซ้ำที่หน้า Splash/Initial (กรณี auto-login) ด้วยไหม
- จะทำ server-side validate โดเมน `@mju.ac.th` (P-02) จริงไหม หรือ validate แค่ฝั่ง client พอ

**Layer 2**
- จะบังคับ `category_id` ห้าม null ไหม
- ผู้ขายไม่ได้เปิดแอปตอน admin กด reject → รอ Layer 6 มาช่วย หรือปล่อยตามนี้

**Layer 3**
- FlutterFlow built-in filter พอไหม หรือต้องสร้าง RPC `search_products` (P-05) — รอทดสอบจริง

**Layer 4**
- FlutterFlow เปิด "Listen for realtime updates" บน **view** ได้จริงไหม (ต้องทดสอบ)
- FlutterFlow query builder รองรับ operator "array contains" บน `chat_summary.user_ids` ไหม ถ้าไม่ ต้องทำ RPC `get_my_chats(uid)`
- จะสร้าง trigger auto-update `chat.last_message` (P-04) หรือให้ Action Flow อัปเดต 2 ที่เอง

**Layer 5**
- ต้องการ `status` กี่แบบจริง ๆ, ต้องเก็บประวัติ transaction แยกไหม หรือใช้ `products.status` พอ

**Layer 6**
- Supabase table + Realtime พอไหม หรือต้องต่อ push จริง (FCM)
- 🔴 `notifications.ref_id` ร่างเป็น uuid แต่ `chat.id` เป็น bigint → อ้าง chat ไม่ได้ ต้องเลือก design ก่อน apply (P-07)

**Layer 7**
- รองรับรีพอร์ต "ผู้ใช้" ด้วยไหม (P-09)
- `reviews` ใช้ RLS allow-all หรือ restrictive

**Layer 8**
- ยังไม่ได้เริ่มคุยรายละเอียด

---

## 💣 หนี้ทางเทคนิคที่ต้องใช้คืนก่อน production

- [ ] `products` / `chat` / `chat_user` / `chat_message` เป็น **allow-all RLS** — เปลี่ยนเป็น restrictive ตาม `chat_user` membership
- [ ] `reports` เปิด RLS แต่ไม่มี policy = deny-all — ยังใช้งานไม่ได้เลย
- [ ] หน้า `Inspect` กันด้วย UI เท่านั้น ไม่ใช่ RLS — user ยิง API ตรงยัง approve สินค้าเองได้
- [ ] ไม่มีระบบกันกดปุ่มลบซ้ำ/popup ค้างใน reject flow (ยอมรับเป็น MVP)

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
- [ ] **`git add -A && git commit && git push`** — ไม่ push = เครื่องอื่นทำงานกับข้อมูลเก่า
