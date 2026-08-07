# Layer 8 — Admin Dashboard

> schema → `../SCHEMA.md` · ตรวจ → `../checks/L8.sql`
> **สถานะ: ⬜ ยังไม่เริ่ม — ยังไม่ได้คุยรายละเอียด**

## 🎯 เป้าหมาย

Admin จัดการผู้ใช้ / สินค้า / รายงาน / หมวดหมู่ ได้ครบ ผู้ใช้ทั่วไปเข้าไม่ได้ **แม้จะยิง API ตรง**

> 🔴 layer นี้คือที่ที่ต้องใช้คืนหนี้ D-03 — ตอนนี้หน้า `Inspect` กันด้วย UI เท่านั้น ไม่ใช่ RLS

## 🧩 ขั้นตอน Supabase

1. สร้าง view/RPC สรุปสำหรับ dashboard: จำนวนผู้ใช้ · สินค้ารอตรวจ · รายงานค้าง · ยอดขาย
2. RLS ระดับ admin-only — pattern:
   ```sql
   USING (EXISTS (SELECT 1 FROM public."Profile" WHERE id = auth.uid() AND role = 'admin'))
   ```
3. **จัดการ `"CAT"`** — CRUD หมวดหมู่ (ตอนนี้ seed ด้วยมือ)
4. (พิจารณา) หน้าจัดการ role แทนการรัน SQL มือ — `DECISIONS.md` D-02 ระบุว่ายังไม่ทำในเฟสนี้

## 🎨 ขั้นตอน FlutterFlow

- Admin panel page ซ่อนจาก user ทั่วไปด้วย conditional visibility ตาม `currentUserRole`
- รวมหน้า `Inspect` (L2) เข้ามาเป็นส่วนหนึ่งของ dashboard

## 🧪 Definition of Done

- [ ] Admin เห็น/จัดการข้อมูลได้ครบ
- [ ] **user ทั่วไปเข้า route หรือยิง query ของ admin ไม่ได้ แม้จะยิง Supabase API ตรง ๆ** ← ข้อนี้คือหัวใจของ layer นี้
- [ ] user ทั่วไปเปลี่ยน `role` ตัวเองไม่ได้ (มี `WITH CHECK` คุ้มครองอยู่แล้ว — ยืนยันซ้ำ)
- [ ] + DoD ร่วมใน `CLAUDE.md`

## ❓ ค้างอยู่

ยังไม่ได้เริ่มคุยรายละเอียด — รอถึงคิว
