# 📊 Cập Nhật Tiến Độ Dự Án — 07/08/2026

---

## Tổng Quan

| Chỉ số | Giá trị |
|--------|---------|
| **Tổng API đã làm** | **~72 endpoints** |
| **Tiến độ tổng thể** | **~70%** |
| **Modules hoàn thành mới** | Cart, PRE_ORDER, VNPay thực, Fee APIs, Admin Withdrawal, Order Schedulers |
| **Module tiếp theo** | 🔜 Complaint/Dispute + Voucher |

---

## ✅ Tất Cả API Đã Làm (~72 endpoints)

### 1. Auth — 5 APIs ✅
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| POST | `/api/v1/auth/register` | Đăng ký |
| POST | `/api/v1/auth/login` | Đăng nhập JWT |
| POST | `/api/v1/auth/refresh-token` | Refresh token |
| POST | `/api/v1/auth/logout` | Đăng xuất |
| POST | `/api/v1/auth/google` | Đăng nhập Google OAuth2 |

### 2. User & Profile — 7 APIs ✅
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| GET | `/api/v1/users/{username}` | Xem profile public |
| POST | `/api/v1/users/me/change-password` | Đổi mật khẩu |
| GET | `/api/v1/users/levels` | Danh sách cấp độ |
| PUT | `/api/v1/users/me/username` | Cập nhật username |
| GET | `/api/v1/users/me` | Xem profile bản thân |
| PUT | `/api/v1/users/me` | Cập nhật profile |
| PATCH | `/api/v1/users/me/avatar` | Cập nhật avatar |

### 3. Category — 5 APIs ✅
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| GET | `/api/v1/categories` | Danh sách danh mục |
| GET | `/api/v1/categories/{slug}` | Chi tiết danh mục |
| POST | `/api/v1/categories` | Tạo danh mục |
| PUT | `/api/v1/categories/{id}` | Sửa danh mục |
| DELETE | `/api/v1/categories/{id}` | Xóa danh mục |

### 4. Shop — 4 APIs ✅
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| GET | `/api/v1/shops` | Danh sách shop |
| GET | `/api/v1/shops/{slug}` | Chi tiết shop |
| POST | `/api/v1/shops` | Tạo shop |
| PUT | `/api/v1/shops/{id}` | Cập nhật shop |

### 5. Product + Asset — 18 APIs ✅
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| GET | `/api/v1/products` | Danh sách sản phẩm |
| GET | `/api/v1/products/slug/{slug}` | Chi tiết sản phẩm |
| GET | `/api/v1/products/shop/{shopId}` | Sản phẩm của shop |
| POST | `/api/v1/products/search` | Tìm kiếm & filter |
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

### 6. Review — 2 APIs ✅
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| POST | `/api/v1/product-reviews` | Tạo đánh giá |
| GET | `/api/v1/product-reviews/product/{productId}` | Xem đánh giá |

### 7. Wallet — 7 APIs ✅ (bổ sung VNPay IPN + Admin)
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| GET | `/api/v1/wallet` | Xem số dư ví |
| GET | `/api/v1/wallet/transactions` | Lịch sử giao dịch |
| POST | `/api/v1/wallet/deposit` | Tạo link nạp tiền VNPay |
| GET | `/api/v1/wallet/deposit/vnpay-ipn` | ✅ **VNPay IPN Callback** (xác thực chữ ký HMAC-SHA512) |
| POST | `/api/v1/wallet/withdraw` | Yêu cầu rút tiền |
| PUT | `/api/v1/admin/withdrawals/{id}/process` | ✅ **Admin duyệt/từ chối rút tiền** |

### 8. Cart — 6 APIs ✅ **HOÀN TOÀN MỚI**
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| GET | `/api/v1/cart` | Xem giỏ hàng |
| POST | `/api/v1/cart/items` | Thêm sản phẩm vào giỏ |
| PUT | `/api/v1/cart/items/{itemId}` | Đổi số lượng |
| DELETE | `/api/v1/cart/items/{itemId}` | Xóa 1 sản phẩm khỏi giỏ |
| DELETE | `/api/v1/cart` | Xóa sạch giỏ |
| POST | `/api/v1/cart/checkout` | **Checkout toàn bộ giỏ** (tự tách đơn theo shop) |

### 9. Order & Checkout — 10 APIs ✅ (mở rộng với PRE_ORDER)
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| POST | `/api/v1/checkout/checkout` | Checkout đơn lẻ (INSTANT hoặc PRE_ORDER) |
| GET | `/api/v1/orders` | Danh sách đơn của buyer |
| GET | `/api/v1/orders/{id}` | Chi tiết đơn |
| GET | `/api/v1/orders/{id}/assets` | Tài khoản đã mua |
| POST | `/api/v1/orders/{id}/cancel` | ✅ **Buyer hủy đơn** (PRE_ORDER đang chờ) |
| GET | `/api/v1/seller/orders` | Danh sách đơn của shop |
| GET | `/api/v1/seller/orders/{id}` | Chi tiết đơn (seller) |
| POST | `/api/v1/seller/orders/{id}/accept` | ✅ **Seller duyệt PRE_ORDER** |
| POST | `/api/v1/seller/orders/{id}/reject` | ✅ **Seller từ chối PRE_ORDER** |
| POST | `/api/v1/seller/orders/{id}/complete` | ✅ **Seller giao hàng PRE_ORDER** (nhập thủ công) |
| POST | `/api/v1/seller/orders/{id}/cancel` | ✅ **Seller hủy đơn PROCESSING** |

### 10. Fee Module — 10 APIs ✅ **HOÀN TOÀN MỚI**
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

---

## ✅ Hệ Thống Background (Non-API)

| Component | Chức năng |
|-----------|-----------|
| `HoldReleaseScheduler` | Chạy mỗi 5 phút — nhả tiền Hold sau 7 ngày cho Seller |
| `OrderCronJobService` (ShedLock) | Chạy mỗi 30 phút — **Auto-cancel** đơn `PROCESSING` quá 24h |
| `OrderCronJobService` (ShedLock) | Chạy mỗi 30 phút — **Auto-cancel** đơn `WAITING_APPROVAL` quá 48h |
| `PreOrderApprovalService` | Accept, Reject, Complete, Cancel với hoàn tiền đầy đủ |

> [!NOTE]
> ShedLock đã được tích hợp — đảm bảo scheduler chỉ chạy trên 1 node khi deploy multi-instance.

---

## ✅ HoldRelease — Nâng Cấp Complaint/Dispute Workflow

`HoldRelease` entity đã được nâng cấp với 6 trạng thái:

| Status | Ý nghĩa |
|--------|---------|
| `HOLDING` | Đang giam tiền, T+7 đang chạy |
| `COMPLAINED` | Buyer báo lỗi, đồng hồ tạm dừng |
| `WARRANTY_IN_PROGRESS` | Shop đang xử lý bảo hành |
| `DISPUTED` | Leo thang lên Admin phán xử |
| `RELEASED` | Tiền nhả về ví seller |
| `REFUNDED` | Tiền hoàn về ví buyer |

---

## ❌ Chưa Làm — Cần Triển Khai Tiếp

### 🔜 Bước tiếp theo: COMPLAINT / DISPUTE API (~3-4 ngày)

ErrorCode đã có sẵn cho Complaint. HoldRelease entity đã có đầy đủ fields. Chỉ cần tạo controller + service.

| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| POST | `/api/v1/orders/{orderId}/items/{itemId}/complain` | Buyer tạo khiếu nại |
| POST | `/api/v1/seller/orders/{orderId}/items/{itemId}/warranty-start` | Seller bắt đầu bảo hành |
| POST | `/api/v1/seller/orders/{orderId}/items/{itemId}/warranty-complete` | Seller hoàn thành bảo hành |
| POST | `/api/v1/seller/orders/{orderId}/items/{itemId}/dispute` | Seller leo thang lên Admin |
| POST | `/api/v1/admin/disputes/{holdReleaseId}/resolve` | Admin phán quyết (buyer_win/seller_win) |
| GET | `/api/v1/admin/disputes` | Admin xem danh sách dispute |

### Bước 4: VOUCHER (3-4 ngày)
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| POST | `/api/v1/seller/vouchers` | Seller tạo voucher |
| GET | `/api/v1/seller/vouchers` | Seller xem vouchers |
| GET | `/api/v1/shops/{shopId}/vouchers` | Buyer xem voucher shop |
| POST | `/api/v1/vouchers/validate` | Kiểm tra mã |

### Bước 5: CHAT + NOTIFICATION (7-10 ngày)
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| POST | `/api/v1/chat/rooms` | Tạo phòng chat |
| GET | `/api/v1/chat/rooms` | Danh sách phòng chat |
| GET | `/api/v1/chat/rooms/{id}/messages` | Lịch sử tin nhắn |
| WS | `/ws/chat/{roomId}` | Gửi/nhận real-time (WebSocket STOMP) |
| GET | `/api/v1/notifications` | Danh sách thông báo |
| PATCH | `/api/v1/notifications/{id}/read` | Đánh dấu đã đọc |
| GET | `/api/v1/notifications/unread-count` | Đếm chưa đọc |

### Bước 6: ADMIN DASHBOARD + DEPLOY (7 ngày)
| Method | Endpoint | Chức năng |
|--------|----------|-----------|
| GET | `/api/v1/admin/dashboard` | Thống kê tổng quan |
| GET/PUT | `/api/v1/admin/users/**` | Ban/unban user |
| GET/PUT | `/api/v1/admin/shops/**` | Suspend/restore shop |
| `docker-compose.yml` | Deploy | PostgreSQL + Redis + App |
| `Dockerfile` | Deploy | Multi-stage build |

---

## Tổng Kết

| Module | Đã làm | Cần làm |
|--------|--------|---------|
| Auth | 5 | 0 |
| User & Profile | 7 | 0 |
| Category | 5 | 0 |
| Shop | 4 | 0 |
| Product + Asset | 18 | 0 |
| Review | 2 | 0 |
| Wallet + VNPay | 7 | 0 |
| **Cart** | **6** | **0** |
| **Order + PRE_ORDER** | **11** | **0** |
| **Fee Module** | **10** | **0** |
| **Complaint/Dispute** | **0** | **~6** |
| **Voucher** | **0** | **~4** |
| **Chat** | **0** | **~4** |
| **Notification** | **0** | **~3** |
| **Admin Dashboard** | **0** | **~5** |
| **Deploy** | **0** | **~3** |
| **Tổng** | **~75** | **~25** |

> [!IMPORTANT]
> **Bước tiếp theo ngay bây giờ:** Complaint/Dispute API — HoldRelease entity đã có đầy đủ fields (complaintReason, complainedAt, remainingHoldSeconds, warrantyStartedAt), ErrorCode đã có, chỉ cần tạo Service + Controller để kích hoạt workflow.
