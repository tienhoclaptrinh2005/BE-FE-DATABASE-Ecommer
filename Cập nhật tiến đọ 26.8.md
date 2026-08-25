# 📊 Cập Nhật Tiến Độ Dự Án CommerceHub Backend
## Ngày: 26/08/2026

---

## ✅ Tổng Quan Tiến Độ

> **So sánh với lần cập nhật 07/08:** Đã hoàn thành thêm module **Complaint/Dispute** (6 APIs + scheduler + entity) — đây là mục tiêu "bước tiếp theo" của lần trước.

| Hạng mục | Số API đã có | Trạng thái |
|----------|-------------|------------|
| Auth | 5 | ✅ Hoàn thành |
| User & Profile | 7 | ✅ Hoàn thành |
| Category | 5 | ✅ Hoàn thành |
| Shop | 4 | ✅ Hoàn thành |
| Product + Asset | 18 | ✅ Hoàn thành |
| Review | 2 | ✅ Hoàn thành |
| Wallet + VNPay | 7 | ✅ Hoàn thành |
| Cart | 6 | ✅ Hoàn thành |
| Order + PRE_ORDER | 11 | ✅ Hoàn thành |
| Fee Module | 10 | ✅ Hoàn thành |
| **Complaint/Dispute** | **~11** | ✅ **HOÀN THÀNH MỚI** |
| Voucher | 0 | ❌ Chưa làm |
| Chat | 0 | ❌ Chưa làm |
| Notification | 0 | ❌ Chưa làm |
| Admin Dashboard | 0 | ❌ Chưa làm |
| Deploy | 0 | ❌ Chưa làm |
| **Tổng** | **~86** | ~77% hoàn thành |

---

## ✅ Đã Hoàn Thành (Tính Đến 26/08/2026)

### 1. Auth - 5 APIs ✅
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| POST | `/api/v1/auth/register` | Đăng ký tài khoản |
| POST | `/api/v1/auth/login` | Đăng nhập (email/password) |
| POST | `/api/v1/auth/google` | Đăng nhập Google OAuth |
| POST | `/api/v1/auth/refresh` | Làm mới Access Token |
| POST | `/api/v1/auth/logout` | Đăng xuất + thu hồi token |

### 2. User & Profile - 7 APIs ✅
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| GET | `/api/v1/users/me` | Xem thông tin cá nhân |
| PUT | `/api/v1/users/me` | Cập nhật hồ sơ |
| PUT | `/api/v1/users/me/password` | Đổi mật khẩu |
| GET | `/api/v1/users/{userId}/profile` | Xem profile công khai |
| GET | `/api/v1/users/me/username-change-status` | Kiểm tra còn đổi username không |
| PATCH | `/api/v1/users/me/username` | Đổi username (1 lần duy nhất) |
| GET | `/api/v1/users` | Admin xem danh sách users |

### 3. Category - 5 APIs ✅
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| GET | `/api/v1/categories` | Danh sách danh mục |
| GET | `/api/v1/categories/{id}` | Chi tiết danh mục |
| POST | `/api/v1/admin/categories` | Tạo danh mục (Admin) |
| PUT | `/api/v1/admin/categories/{id}` | Sửa danh mục (Admin) |
| DELETE | `/api/v1/admin/categories/{id}` | Xóa danh mục (Admin) |

### 4. Shop - 4 APIs ✅
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| POST | `/api/v1/shops` | Tạo gian hàng |
| GET | `/api/v1/shops/{shopId}` | Xem thông tin shop |
| PUT | `/api/v1/seller/shops/me` | Cập nhật shop |
| GET | `/api/v1/seller/shops/me` | Seller xem shop của mình |

### 5. Product + Asset - 18 APIs ✅
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| GET | `/api/v1/products` | Danh sách sản phẩm |
| GET | `/api/v1/products/{productId}` | Chi tiết sản phẩm |
| POST | `/api/v1/seller/products` | Tạo sản phẩm |
| PUT | `/api/v1/seller/products/{productId}` | Sửa sản phẩm |
| DELETE | `/api/v1/seller/products/{productId}` | Xóa sản phẩm |
| POST | `/api/v1/seller/products/assets/inventory` | Upload kho tài khoản |
| POST | `/api/v1/seller/product-variants` | Tạo variant |
| PUT | `/api/v1/seller/product-variants/{variantId}` | Sửa variant |
| GET | `/api/v1/products/{productId}/variants` | Danh sách variant |
| POST | `/api/v1/seller/products/{productId}/images` | Thêm ảnh |
| DELETE | `/api/v1/seller/products/images/{imageId}` | Xóa ảnh |
| GET | `/api/v1/products/{productId}/images` | Danh sách ảnh |
| POST | `/api/v1/seller/pre-order-configs` | Tạo/cập nhật config PRE_ORDER |
| GET | `/api/v1/seller/pre-order-configs/product/{productId}` | Xem config |
| GET | `/api/v1/seller/digital-assets/variant/{variantId}` | Xem kho tài khoản |
| DELETE | `/api/v1/seller/digital-assets/{assetId}` | Xóa asset |

### 6. Review - 2 APIs ✅
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| POST | `/api/v1/product-reviews` | Tạo đánh giá |
| GET | `/api/v1/product-reviews/product/{productId}` | Xem đánh giá |

### 7. Wallet + VNPay - 7 APIs ✅
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| GET | `/api/v1/wallet` | Xem số dư ví |
| GET | `/api/v1/wallet/transactions` | Lịch sử giao dịch |
| POST | `/api/v1/wallet/deposit` | Tạo link nạp tiền VNPay |
| GET | `/api/v1/wallet/deposit/vnpay-ipn` | ✅ VNPay IPN Callback (HMAC-SHA512) |
| POST | `/api/v1/wallet/withdraw` | Yêu cầu rút tiền |
| PUT | `/api/v1/admin/withdrawals/{id}/process` | Admin duyệt/từ chối rút tiền |

### 8. Cart - 6 APIs ✅
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| GET | `/api/v1/cart` | Xem giỏ hàng |
| POST | `/api/v1/cart/items` | Thêm sản phẩm vào giỏ |
| PUT | `/api/v1/cart/items/{itemId}` | Đổi số lượng |
| DELETE | `/api/v1/cart/items/{itemId}` | Xóa 1 sản phẩm khỏi giỏ |
| DELETE | `/api/v1/cart` | Xóa sạch giỏ |
| POST | `/api/v1/cart/checkout` | Checkout toàn bộ giỏ (tự tách đơn theo shop) |

### 9. Order & Checkout - 11 APIs ✅
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| POST | `/api/v1/checkout/checkout` | Checkout đơn lẻ (INSTANT hoặc PRE_ORDER) |
| GET | `/api/v1/orders` | Danh sách đơn của buyer |
| GET | `/api/v1/orders/{id}` | Chi tiết đơn |
| GET | `/api/v1/orders/{id}/assets` | Tài khoản đã mua |
| POST | `/api/v1/orders/{id}/cancel` | Buyer hủy đơn |
| GET | `/api/v1/seller/orders` | Danh sách đơn của shop |
| GET | `/api/v1/seller/orders/{id}` | Chi tiết đơn (seller) |
| POST | `/api/v1/seller/orders/{id}/accept` | Seller duyệt PRE_ORDER |
| POST | `/api/v1/seller/orders/{id}/reject` | Seller từ chối PRE_ORDER |
| POST | `/api/v1/seller/orders/{id}/complete` | Seller giao hàng PRE_ORDER |
| POST | `/api/v1/seller/orders/{id}/cancel` | Seller hủy đơn PROCESSING |

### 10. Fee Module - 10 APIs ✅
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| GET | `/api/v1/seller/fees` | Seller xem danh sách phí sàn |
| GET | `/api/v1/seller/fees/summary` | Seller xem tổng hợp phí |
| GET | `/api/v1/seller/fees/{ledgerId}` | Seller xem chi tiết phí 1 đơn |
| GET | `/api/v1/admin/fee-configs` | Admin xem cấu hình phí |
| GET | `/api/v1/admin/fee-configs/active` | Xem cấu hình phí đang hoạt động |
| POST | `/api/v1/admin/fee-configs` | Admin tạo cấu hình phí mới |
| PUT | `/api/v1/admin/fee-configs/change-rate` | Admin thay đổi % phí sàn |
| GET | `/api/v1/admin/fee-configs/ledgers` | Admin xem toàn bộ ledger |
| GET | `/api/v1/admin/fee-configs/ledgers/{ledgerId}` | Admin xem chi tiết ledger |
| GET | `/api/v1/admin/fee-configs/summaries` | Admin xem tổng hợp phí tất cả shop |

### 11. ✅ Complaint/Dispute - ~11 APIs (HOÀN THÀNH MỚI KỂ TỪ 7/8)

> **Đây là module hoàn toàn mới được hoàn thành sau ngày 07/08.**  
> Bao gồm: Buyer khiếu nại → Seller bảo hành → Buyer xác nhận / leo thang → Admin phán xử.

| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| POST | `/api/v1/orders/{orderId}/items/{itemId}/complain` | Buyer tạo khiếu nại |
| POST | `/api/v1/disputes/{disputeId}/escalate` | Buyer leo thang lên Admin |
| POST | `/api/v1/disputes/{disputeId}/confirm-warranty` | Buyer xác nhận kết quả bảo hành |
| GET | `/api/v1/disputes/{disputeId}` | Buyer xem chi tiết dispute |
| GET | `/api/v1/disputes` | Buyer xem danh sách dispute |
| POST | `/api/v1/seller/orders/{orderId}/items/{itemId}/warranty-start` | Seller bắt đầu bảo hành |
| POST | `/api/v1/seller/orders/{orderId}/items/{itemId}/warranty-complete` | Seller hoàn thành bảo hành |
| POST | `/api/v1/seller/orders/{orderId}/items/{itemId}/dispute` | Seller leo thang lên Admin |
| GET | `/api/v1/seller/disputes` | Seller xem danh sách dispute |
| GET | `/api/v1/seller/disputes/{disputeId}` | Seller xem chi tiết dispute |
| GET | `/api/v1/admin/disputes` | Admin xem toàn bộ dispute (filter by status) |
| GET | `/api/v1/admin/disputes/{disputeId}` | Admin xem chi tiết dispute |
| POST | `/api/v1/admin/disputes/{disputeId}/resolve` | Admin phán quyết (buyer_win/seller_win) |

**Files đã tạo:**
- `dispute/entity/OrderDispute.java` — Entity lưu thông tin khiếu nại/tranh chấp
- `dispute/service/DisputeService.java` — Toàn bộ luồng buyer & seller
- `dispute/service/DisputeResolutionService.java` — Admin phán xử + hoàn tiền
- `dispute/controller/DisputeController.java` — Buyer APIs
- `dispute/controller/SellerDisputeController.java` — Seller APIs  
- `admin/controller/AdminDisputeController.java` — Admin APIs
- `dispute/scheduler/DisputeDeadlineScheduler.java` — Auto-xử lý dispute quá hạn
- `dispute/repository/OrderDisputeRepository.java` — Repository với các query phức tạp
- `dispute/dto/request/` — CreateDisputeRequest, SellerRespondRequest, AdminResolveDisputeRequest
- `dispute/dto/response/DisputeResponse.java`
- `dispute/mapper/DisputeMapper.java`

---

## ✅ Hệ Thống Background (Non-API)

| Component | Chức năng | Trạng thái |
|-----------|-----------|------------|
| `HoldReleaseScheduler` | Chạy mỗi 5 phút - nhả tiền Hold sau 7 ngày cho Seller | ✅ Hoạt động |
| `OrderCronJobService` (ShedLock) | Chạy mỗi 30 phút - Auto-cancel đơn `PROCESSING` quá 24h | ✅ Hoạt động |
| `OrderCronJobService` (ShedLock) | Chạy mỗi 30 phút - Auto-cancel đơn `WAITING_APPROVAL` quá 48h | ✅ Hoạt động |
| `PreOrderApprovalService` | Accept, Reject, Complete, Cancel với hoàn tiền đầy đủ | ✅ Hoạt động |
| `DisputeDeadlineScheduler` | Auto xử lý dispute quá hạn chưa được Admin giải quyết | ✅ **MỚI** |

---

## ✅ Stack Kỹ Thuật Đang Dùng

| Thành phần | Công nghệ |
|------------|-----------|
| Framework | Spring Boot 3.5.13, Java 21 |
| Database | PostgreSQL + Spring Data JPA |
| Security | Spring Security + JWT (jjwt 0.11.5) |
| Mapping | MapStruct 1.5.5 |
| Distributed Lock | ShedLock 7.7.0 |
| Payment | VNPay IPN (HMAC-SHA512) |
| Auth OAuth | Google API Client 2.2.0 |
| Validation | Spring Validation |

---

## ❌ Chưa Làm - Cần Triển Khai Tiếp

### 🔥 Bước tiếp theo: VOUCHER (ưu tiên cao nhất)

> **Lý do:** Voucher là tính năng thường gặp trên các sàn TMĐT, ảnh hưởng trực tiếp đến checkout flow hiện có.

| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| POST | `/api/v1/seller/vouchers` | Seller tạo voucher |
| GET | `/api/v1/seller/vouchers` | Seller xem vouchers của mình |
| PUT | `/api/v1/seller/vouchers/{id}` | Seller sửa voucher |
| DELETE | `/api/v1/seller/vouchers/{id}` | Seller xóa voucher |
| GET | `/api/v1/shops/{shopId}/vouchers` | Buyer xem voucher của shop |
| POST | `/api/v1/vouchers/validate` | Kiểm tra mã voucher có hợp lệ không |
| POST | `/api/v1/vouchers/apply` | Áp dụng voucher vào checkout |

**Cần tạo:**
- `voucher/entity/Voucher.java` — Entity voucher (code, discountType, amount, minOrderValue, expiresAt, usageLimit, usedCount)
- `voucher/entity/VoucherUsage.java` — Lịch sử dùng voucher (ai dùng, đơn nào)
- `voucher/service/VoucherService.java` — Validate + Apply
- `voucher/controller/VoucherController.java` (Buyer) + `SellerVoucherController.java`
- SQL migration: `2026-08-voucher-migration.sql`
- Tích hợp `CheckoutService.java` để áp dụng voucher khi checkout

**Ước tính:** 2-3 ngày

---

### 📢 Bước 5: NOTIFICATION (ưu tiên trung bình)

> Notification cơ bản (không real-time) — lưu DB, user poll hoặc đọc khi mở app.

| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| GET | `/api/v1/notifications` | Danh sách thông báo |
| PATCH | `/api/v1/notifications/{id}/read` | Đánh dấu đã đọc |
| PATCH | `/api/v1/notifications/read-all` | Đánh dấu tất cả đã đọc |
| GET | `/api/v1/notifications/unread-count` | Đếm chưa đọc |

**Cần tạo:**
- `notification/entity/Notification.java` — Entity (userId, type, title, body, referenceId, referenceType, isRead)
- `notification/service/NotificationService.java` — createNotification() + getByUser()
- `notification/controller/NotificationController.java`
- Tích hợp vào các luồng: Order tạo → thông báo, Dispute resolve → thông báo, PRE_ORDER accept/reject → thông báo

**Ước tính:** 1-2 ngày

---

### 💬 Bước 6: CHAT (ưu tiên trung bình - phức tạp)

> WebSocket STOMP real-time. Buyer ↔ Seller nhắn tin trực tiếp.

| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| POST | `/api/v1/chat/rooms` | Tạo phòng chat |
| GET | `/api/v1/chat/rooms` | Danh sách phòng chat |
| GET | `/api/v1/chat/rooms/{id}/messages` | Lịch sử tin nhắn (phân trang) |
| WS | `/ws/chat/{roomId}` | Gửi/nhận real-time (WebSocket STOMP) |

**Cần thêm dependency:**
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-websocket</artifactId>
</dependency>
```

**Ước tính:** 3-5 ngày

---

### 📊 Bước 7: ADMIN DASHBOARD (ưu tiên thấp)

| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| GET | `/api/v1/admin/dashboard` | Thống kê tổng quan (doanh thu, user mới, đơn hàng) |
| GET | `/api/v1/admin/users` | Danh sách users (đã có sẵn) |
| PUT | `/api/v1/admin/users/{id}/ban` | Ban user |
| PUT | `/api/v1/admin/users/{id}/unban` | Unban user |
| GET | `/api/v1/admin/shops` | Danh sách shops |
| PUT | `/api/v1/admin/shops/{id}/suspend` | Tạm khóa shop |
| PUT | `/api/v1/admin/shops/{id}/restore` | Khôi phục shop |

**Ước tính:** 2-3 ngày

---

### 🐳 Bước 8: DEPLOY (ưu tiên cuối)

| File | Nội dung |
|------|----------|
| `Dockerfile` | Multi-stage build (Maven build → JRE runtime) |
| `docker-compose.yml` | PostgreSQL + App + (tùy chọn Redis sau này) |
| `.env.example` | Template biến môi trường |
| `application-prod.yml` | Cấu hình production |

**Ước tính:** 1-2 ngày

---

## 📋 Những Phần Đang Thiếu / Cần Chú Ý

### ⚠️ Thiếu: Redis Cache
- Hiện tại chưa có Redis. Sản phẩm (ProductController) có thể có `cache/` package nhưng chưa kết nối Redis thật.
- Khi deploy production nên thêm Redis để cache danh sách sản phẩm, session, v.v.

### ⚠️ Thiếu: Rate Limiting / Throttling
- Không có giới hạn request. Endpoint thanh toán VNPay, checkout rất dễ bị tấn công.
- Cần thêm `spring-boot-starter-data-redis` + `Bucket4j` hoặc nginx rate limit.

### ⚠️ Thiếu: Search / Filter nâng cao
- `GET /api/v1/products` hiện tại filter cơ bản. Chưa có full-text search, lọc theo giá, sort đa tiêu chí.
- Nếu cần tốt hơn: tích hợp Elasticsearch hoặc PostgreSQL Full-Text Search.

### ⚠️ Thiếu: Email Service
- Chưa có email xác nhận đơn hàng, email đặt lại mật khẩu, email thông báo dispute.
- Cần thêm `spring-boot-starter-mail` + template email (Thymeleaf/Freemarker).

### ⚠️ Thiếu: Upload ảnh thực
- Hiện tại `POST /api/v1/seller/products/{productId}/images` có thể đang lưu URL tĩnh.
- Cần tích hợp Cloudinary / AWS S3 / MinIO để upload ảnh thật.

### ⚠️ Thiếu: Unit Tests & Integration Tests
- Chưa có test cho các service phức tạp (CheckoutService, PreOrderApprovalService, DisputeService).
- Cần bổ sung trước khi deploy production.

### ⚠️ Thiếu: API Documentation (Swagger/OpenAPI)
- Chưa có Swagger UI. Cần thêm `springdoc-openapi-starter-webmvc-ui` để generate API docs tự động.

---

## 🗺️ Roadmap Hoàn Thành Dự Án

```
Tháng 8/2026:
✅ Hoàn thành lõi (Auth, User, Shop, Product, Wallet, Order, Fee)
✅ Complaint/Dispute (hoàn thành ngày ~26/8)

Tháng 9/2026 (Kế hoạch):
[ ] Voucher (2-3 ngày)
[ ] Notification (1-2 ngày)
[ ] Admin Dashboard (2-3 ngày)
[ ] Chat/WebSocket (3-5 ngày)

Tháng 9-10/2026:
[ ] Deploy (Dockerfile + docker-compose)
[ ] Unit Tests
[ ] Swagger/OpenAPI docs
```

---

## 📈 Tổng Kết

| Module | Đã làm | Cần làm |
|--------|--------|---------|
| Auth | 5 | 0 |
| User & Profile | 7 | 0 |
| Category | 5 | 0 |
| Shop | 4 | 0 |
| Product + Asset | 18 | 0 |
| Review | 2 | 0 |
| Wallet + VNPay | 7 | 0 |
| Cart | 6 | 0 |
| Order + PRE_ORDER | 11 | 0 |
| Fee Module | 10 | 0 |
| **Complaint/Dispute** | **~13** | **0** |
| **Voucher** | **0** | **~7** |
| **Notification** | **0** | **~4** |
| **Chat** | **0** | **~4** |
| **Admin Dashboard** | **0** | **~7** |
| **Deploy** | **0** | **~4** |
| **Tổng** | **~88** | **~26** |

> [!IMPORTANT]
> **Bước tiếp theo ngay bây giờ:** VOUCHER — Tạo entity Voucher + VoucherUsage, service validate/apply, controller cho cả buyer & seller, và tích hợp vào `CheckoutService.java`.

> [!NOTE]
> So với ngày 07/08: Đã hoàn thành thêm **~13 APIs Complaint/Dispute** + **DisputeDeadlineScheduler**. Tổng API tăng từ ~75 → ~88.
