# CommerceHub — Update v8 Pack

Thư mục này chứa **1 file database**, **cấu trúc backend (DONE + TODO)**, **cấu trúc frontend (scaffold 3 portal)** đã chỉnh theo code thật + quyết định nghiệp vụ.

## Quyết định đã chốt

| Hạng mục | Quyết định |
|----------|------------|
| Favorite shop | **XÓA** hoàn toàn |
| Giỏ hàng | **THÊM** — backend `cart/` đã DONE + bảng `carts`/`cart_items` |
| Waive phí sàn | **KHÔNG** — dispute buyer-win → ledger `CANCELLED` |
| Fee rate mặc định | **4%** (`0.0400`), làm tròn **CEILING** |
| PRE_ORDER tiền | Trừ ví **ngay lúc checkout** |
| Thanh toán mua hàng | Luôn **WALLET** (nạp trước — mua sau) |
| Nội dung giao khách | Thống nhất **`delivery_content`** — INSTANT: 1 dòng TXT = 1 asset, giao thì **snapshot** vào `asset_delivery_logs`; PRE_ORDER: shop nhập account/key/tin nhắn vào `pre_order_items` (+ loại ACCOUNT/KEY/MESSAGE/OTHER). Buyer xem lại vĩnh viễn từ snapshot/cột đơn, **không đọc lại kho** |

## Cấu trúc thư mục

```
V2/
├── README.md                    ← file này
├── backend-structure.md         ← code thật [DONE] + module chưa làm [TODO]
├── frontend-structure.md        ← scaffold 3 portal (chưa có src/)
└── schema-v8.sql                ← FILE SQL DUY NHẤT (schema + seed)
```

## Database — 1 file duy nhất

```bash
# DB mới hoặc reset: tạo DB trống rồi chạy
psql -h localhost -p 5678 -U postgres -d commercehub_db -f "schema-v8.sql"
```

File **idempotent — chạy lại an toàn**: nếu gặp `wallet_transactions` cũ chưa partition
(migrate từ v7), bảng cũ được **đổi tên thành `wallet_transactions_legacy`** (giữ nguyên
dữ liệu, không DROP) rồi tạo bảng partition mới — đối soát xong tự DROP bảng legacy.
Các lần chạy lại sau không đụng dữ liệu.

**Phạm vi file**: đây là **schema đầy đủ cho DB mới** (hoặc chạy lại trên DB đã tạo bằng
chính file này) — **không phải** bộ migration tăng dần: bảng đã tồn tại với định nghĩa cũ
sẽ không được ALTER (`CREATE TABLE IF NOT EXISTS` bỏ qua bảng có sẵn). Nâng cấp DB v7
đang chạy cần script ALTER riêng.

Không có `psql` → dùng `sql/RunSql.java` trong repo backend:

```bash
java -cp "%USERPROFILE%\.m2\repository\org\postgresql\postgresql\42.7.10\postgresql-42.7.10.jar" ^
  sql\RunSql.java "D:\LuuCode1\Project\V2\schema-v8.sql"
```

### File SQL gồm

- Toàn bộ bảng module (auth → wallet → shop → product → voucher → **cart** → order → fee → dispute → chat → notification → audit → fraud → outbox → idempotency → shedlock)
- `DROP favorite_shops` (cleanup legacy)
- Seed: roles, level_configs, categories, ví platform
- Seed fee 4% **chỉ khi đã có ít nhất 1 user** (FK `created_by`)
- Cột giao hàng v8: `digital_assets.delivery_content`, `asset_delivery_logs.delivery_content_snapshot`, `pre_order_items.delivery_content` + `delivery_content_type` + `accepted_at`/`delivered_at` (kèm khối ALTER idempotent cho DB tạo bằng bản cũ)
- Ràng buộc bổ sung: UNIQUE `(user_id, idempotency_key)` cho `orders`; UNIQUE chat room (kể cả khi `shop_id` NULL); `orders.payment_method` chỉ cho phép `WALLET`

### Kiểm tra nhanh

```sql
SELECT COUNT(*) FROM information_schema.tables
WHERE table_schema='public' AND table_name='favorite_shops';  -- 0

SELECT COUNT(*) FROM information_schema.tables
WHERE table_schema='public' AND table_name IN ('carts','cart_items');  -- 2

SELECT fee_rate, is_active FROM platform_fee_configs WHERE is_active = true;  -- 0.0400 (sau khi có user)

SELECT id FROM wallets WHERE is_platform = true;  -- 1 row
```

## Cách đọc structure MD

| File | Ý nghĩa |
|------|---------|
| `backend-structure.md` | Module `[DONE]` khớp repo; `[TODO]` lấy từ tài liệu v8 để làm tiếp |
| `frontend-structure.md` | Cây mục tiêu đầy đủ 3 portal; **không** Favorite; **có** Cart; **không** Waive |

## Liên kết code

- Backend: `D:\LuuCode1\Project\commercehub-backend`
- Frontend: `D:\LuuCode1\Project\commercehub-frontend`
- Package Java: `com.commercehub.backend` (giữ nguyên)
"# BE-FE-DATABASE-Ecommer" 
