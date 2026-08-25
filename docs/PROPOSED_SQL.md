# PROPOSED_SQL.md — SQL ที่ยังไม่ apply

> 🚧 **ทุกอย่างในไฟล์นี้ยังไม่มีอยู่จริงในฐานข้อมูล**
> ห้าม reference ในโค้ด/Action Flow จนกว่าจะ apply แล้วย้ายไป `SCHEMA.md`
> เมื่อ apply แล้ว: ลบออกจากไฟล์นี้ → เพิ่มเข้า `SCHEMA.md` → บันทึกเหตุผลที่ `DECISIONS.md`

> 📌 **P-01 / P-02 ถูกลบออกจากไฟล์นี้แล้ว** — apply อยู่ใน DB จริง (`handle_new_user()` + trigger `on_auth_user_created`) อ่านที่ `SCHEMA.md` แทน
> เลข P-01/P-02 **เลิกใช้ ห้ามเอากลับมาใช้ซ้ำ** · ประวัติเต็มอยู่ใน git และ `DECISIONS.md` D-11
>
> 📌 **P-07 ถูกลบออกจากไฟล์นี้แล้ว** — apply อยู่ใน DB จริง (ตาราง `notifications` + RLS + trigger `enforce_moderation_admin_only`) อ่านที่ `SCHEMA.md` แทน
> เลข P-07 **เลิกใช้ ห้ามเอากลับมาใช้ซ้ำ** · เหตุผลออกแบบเต็มอยู่ `DECISIONS.md` **D-23**
>
> 📌 **P-10 ถูกลบออกจากไฟล์นี้แล้ว** — apply อยู่ใน DB จริง (`reports` มี 3 policy: admin-read, reporter-read-own, authenticated-insert) อ่านที่ `SCHEMA.md` แทน
> เลข P-10 **เลิกใช้ ห้ามเอากลับมาใช้ซ้ำ** · เหตุผลออกแบบเต็มอยู่ `DECISIONS.md` **D-24**
>
> 📌 **P-03 / P-04 ถูกลบออกจากไฟล์นี้แล้ว** — apply อยู่ใน DB จริง (`find_or_create_chat`/`update_chat_last_message`/`is_chat_member`/`get_my_chats` + trigger + RLS membership-based) อ่านที่ `SCHEMA.md` แทน โค้ดจริงต่างจากดราฟต์เดิม (เพิ่ม impersonation guard, `is_chat_member` helper, ค่า default `last_message`, COALESCE รูปภาพ)
> เลข P-03/P-04 **เลิกใช้ ห้ามเอากลับมาใช้ซ้ำ** · เหตุผลออกแบบเต็มอยู่ `DECISIONS.md` **D-29**
>
> 📌 **P-06 ถูกลบออกจากไฟล์นี้แล้ว** — apply อยู่ใน DB จริง (ตาราง `transactions` + RLS + RPC `mark_product_sold` + trigger `enforce_sale_via_rpc_only`) อ่านที่ `SCHEMA.md` แทน โค้ดจริงต่างจากดราฟต์เดิม (`status` เหลือค่าเดียว `'completed'` ไม่ใช่ pending/completed/cancelled, เพิ่ม `chat_id`, FK ทุกตัวเป็น `ON DELETE SET NULL`)
> เลข P-06 **เลิกใช้ ห้ามเอากลับมาใช้ซ้ำ** · เหตุผลออกแบบเต็มอยู่ `DECISIONS.md` **D-59**
>
> 📌 **P-05 ถูกลบออกจากไฟล์นี้แล้ว** — apply อยู่ใน DB จริง (`search_products()`) อ่านที่ `SCHEMA.md` แทน โค้ดจริงต่างจากดราฟต์เดิม (`FROM products_review_view` ไม่ใช่ `products` ตรง ๆ ตามที่ draft แนะนำไว้, เพิ่ม `status <> 'sold'`, revoke `anon`/PUBLIC)
> เลข P-05 **เลิกใช้ ห้ามเอากลับมาใช้ซ้ำ** · เหตุผลออกแบบเต็มอยู่ `DECISIONS.md` **D-62**
>
> 📌 **P-08 ถูกลบออกจากไฟล์นี้แล้ว** — apply อยู่ใน DB จริง (ตาราง `reviews` + RLS 3 policy) อ่านที่ `SCHEMA.md` แทน โค้ดจริงต่างจากดราฟต์เดิม (ผูก `transaction_id` REFERENCES `transactions` แทน `product_id` ตรง ๆ, `UNIQUE(transaction_id, reviewer_id)` แทน `UNIQUE(reviewer_id, product_id)`, ไม่มี UPDATE/DELETE policy เลย)
> เลข P-08 **เลิกใช้ ห้ามเอากลับมาใช้ซ้ำ** · เหตุผลออกแบบเต็มอยู่ `DECISIONS.md` **D-64**
>
> 📌 **P-09 ถูกลบออกจากไฟล์นี้แล้ว** — apply อยู่ใน DB จริง (`reports.reported_user_id` + 2 CHECK constraints + unique partial index + `reports_admin_view` 4 คอลัมน์ใหม่) อ่านที่ `SCHEMA.md` แทน โค้ดจริงต่างจากดราฟต์เดิม (เพิ่ม `reports_no_self_report` CHECK ที่ draft ไม่มี, `ON DELETE SET NULL` แทนไม่ระบุ)
> เลข P-09 **เลิกใช้ ห้ามเอากลับมาใช้ซ้ำ** · เหตุผลออกแบบเต็มอยู่ `DECISIONS.md` **D-65**
>
> 📌 **P-12 ถูกลบออกจากไฟล์นี้แล้ว** — apply อยู่ใน DB จริง (ตาราง `storage_cleanup_config`/`storage_cleanup_log` + Edge Function `cleanup-orphan-storage` + cron job รายวัน) อ่านที่ `SCHEMA.md` แทน (หมวด `## Scheduled Jobs (pg_cron)`) — เลือกแนวทาง "Edge Function รันเป็นรอบ" ตามที่ pete ตอบรับ ไม่ใช่ trigger `AFTER DELETE`
> เลข P-12 **เลิกใช้ ห้ามเอากลับมาใช้ซ้ำ** · เหตุผลออกแบบเต็มอยู่ `DECISIONS.md` **D-66**

| # | ของ | Layer | สถานะ |
|---|---|---|---|
| P-11 | unique index บน `lower("Profile".email)` | L1 | **ข้อเสนอของ Claude pete ยังไม่ตอบรับ** |

---

## P-11 — unique index บน `lower("Profile".email)` (L1)

> 🚧 **ข้อเสนอของ Claude — pete ยังไม่ตอบรับ ห้ามถือว่าตกลงแล้ว**

```sql
CREATE UNIQUE INDEX profile_email_lower_unique
  ON public."Profile" (lower(email));
```

**ที่มา:** `Profile_email_key` เป็น UNIQUE ธรรมดาบนคอลัมน์ดิบ ไม่ใช่ index บน `lower()`
ตอนนี้ `handle_new_user()` `lower()` ให้ก่อน insert อยู่แล้ว (D-14) จึงยัง**ไม่มีปัญหาจริง** — ข้อเสนอนี้เป็นชั้นกันเผื่อเส้นทางเขียนอื่นที่ไม่ผ่าน trigger (`service_role` / SQL ตรง)

**ที่ต้องตัดสินใจก่อน apply:**
- คุ้มไหมที่จะเพิ่ม index อีกตัวเพื่อกันเคสที่ trigger กันอยู่แล้ว
- ถ้าเอา ควรถอด `Profile_email_key` ตัวเดิมทิ้งไหม หรือเก็บทั้งคู่

**ตรวจว่ายังไม่มีปัญหาอยู่หรือเปล่า:** `checks/L1.sql` [1.9]
