# commercehub-backend — Cấu trúc thư mục v8 (DONE + TODO)

> **Package gốc:** `com.commercehub.backend` (KHÔNG đổi thành `com.commercehub`).
>
> **Chú thích trạng thái**
> - `[DONE]` — đã có trong repo `commercehub-backend` (đối chiếu 2026-08-04)
> - `[TODO]` — module/file theo tài liệu v8, **chưa implement** — giữ trong cây để scaffold tiếp
> - `[DEL]` — đã loại bỏ, **không tạo lại**
>
> ## Quyết định nghiệp vụ đã chốt
> - `[DEL]` Favorite shop / `favorite_shops` / `FavoriteShop*`
> - `[DONE]` Module `cart/` (giỏ hàng)
> - `[DEL]` Waive phí sàn (`WAIVED`, `WaiveFee*`, `total_waived`) — dispute buyer-win → ledger `CANCELLED`
> - Fee mặc định **4%**, làm tròn **CEILING** đồng nguyên
> - PRE_ORDER trừ ví **ngay lúc checkout**
> - Mua hàng luôn **WALLET** (nạp trước — mua sau)
> - Fee nằm ở package `fee/` (không nhét entity fee vào `wallet/`)
> - **[DLV]** Nội dung giao khách thống nhất `delivery_content`:
>   INSTANT = `digital_assets.delivery_content` → snapshot `asset_delivery_logs.delivery_content_snapshot`;
>   PRE_ORDER = shop nhập `pre_order_items.delivery_content` (+ `delivery_content_type`).
>   `seller_notes` chỉ là ghi chú nội bộ, không dùng để giao hàng.

```
commercehub-backend/
├── .gitignore
├── .gitattributes
├── mvnw / mvnw.cmd
├── pom.xml
├── README.md
│
├── sql/                                              -- [DONE] script vận hành kèm repo
│   ├── 2026-08-money-fixes.sql
│   └── RunSql.java
│
└── src/
    ├── main/
    │   ├── java/com/commercehub/backend/
    │   │   ├── CommercehubBackendApplication.java    -- [DONE]
    │   │   │
    │   │   ├── common/                               -- [DONE]
    │   │   │   ├── base/
    │   │   │   │   ├── AuditableEntity.java
    │   │   │   │   └── BaseEntity.java
    │   │   │   ├── exception/
    │   │   │   │   ├── AppException.java
    │   │   │   │   ├── ErrorCode.java                -- + CART_*, DEPOSIT_AMOUNT_MISMATCH, fee codes
    │   │   │   │   └── GlobalExceptionHandler.java
    │   │   │   ├── response/
    │   │   │   │   ├── ApiResponse.java
    │   │   │   │   └── PageResponse.java
    │   │   │   └── util/
    │   │   │       ├── OrderCodeGenerator.java
    │   │   │       ├── SecurityUtils.java
    │   │   │       └── SlugUtils.java
    │   │   │
    │   │   ├── config/                               -- [DONE]
    │   │   │   ├── JpaAuditConfig.java
    │   │   │   └── SchedulerConfig.java               -- @EnableScheduling + ShedLock
    │   │   │
    │   │   ├── security/                             -- [DONE]
    │   │   │   ├── CustomUserDetails.java
    │   │   │   ├── CustomUserDetailsService.java
    │   │   │   ├── JwtAccessDeniedHandler.java
    │   │   │   ├── JwtAuthenticationEntryPoint.java
    │   │   │   ├── JwtAuthenticationFilter.java
    │   │   │   ├── JwtTokenProvider.java
    │   │   │   └── SecurityConfig.java
    │   │   │
    │   │   ├── auth/                                 -- [DONE]
    │   │   │   ├── controller/AuthController.java
    │   │   │   ├── dto/request/
    │   │   │   │   ├── ChangePasswordRequest.java
    │   │   │   │   ├── GoogleLoginRequest.java
    │   │   │   │   ├── LoginRequest.java
    │   │   │   │   ├── LogoutRequest.java
    │   │   │   │   ├── RefreshTokenRequest.java
    │   │   │   │   └── RegisterRequest.java
    │   │   │   ├── dto/response/AuthResponse.java
    │   │   │   ├── entity/RefreshToken.java
    │   │   │   ├── mapper/AuthMapper.java
    │   │   │   ├── repository/RefreshTokenRepository.java
    │   │   │   └── service/AuthService.java
    │   │   │   # [TODO] EmailVerificationToken, PasswordResetToken entity/service/API
    │   │   │
    │   │   ├── user/                                 -- [DONE]
    │   │   │   ├── controller/
    │   │   │   │   ├── ProfileController.java
    │   │   │   │   └── UserController.java
    │   │   │   ├── dto/request/
    │   │   │   │   ├── UpdateAvatarRequest.java
    │   │   │   │   └── UpdateProfileRequest.java
    │   │   │   ├── dto/response/
    │   │   │   │   ├── ProfileResponse.java
    │   │   │   │   ├── UserLevelResponse.java
    │   │   │   │   └── UserResponse.java
    │   │   │   ├── entity/
    │   │   │   │   ├── LevelConfig.java
    │   │   │   │   ├── Role.java
    │   │   │   │   └── User.java
    │   │   │   ├── mapper/UserMapper.java
    │   │   │   ├── repository/
    │   │   │   │   ├── LevelConfigRepository.java
    │   │   │   │   ├── RoleRepository.java
    │   │   │   │   └── UserRepository.java
    │   │   │   └── service/
    │   │   │       ├── ProfileService.java
    │   │   │       ├── UserLevelService.java
    │   │   │       └── UserService.java
    │   │   │
    │   │   ├── shop/                                 -- [DONE] (không Favorite)
    │   │   │   ├── controller/ShopController.java
    │   │   │   ├── dto/request/
    │   │   │   │   ├── CreateShopRequest.java
    │   │   │   │   └── UpdateShopRequest.java
    │   │   │   ├── dto/response/ShopResponse.java
    │   │   │   ├── entity/Shop.java
    │   │   │   ├── mapper/ShopMapper.java
    │   │   │   ├── repository/ShopRepository.java
    │   │   │   └── service/ShopService.java
    │   │   │   # [TODO] ShopImage, ShopReport entity/controller/service
    │   │   │   # [DEL] FavoriteShop*
    │   │   │
    │   │   ├── category/                             -- [DONE]
    │   │   │   ├── controller/CategoryController.java
    │   │   │   ├── dto/request/
    │   │   │   │   ├── CreateCategoryRequest.java
    │   │   │   │   └── UpdateCategoryRequest.java
    │   │   │   ├── dto/response/CategoryResponse.java
    │   │   │   ├── entity/Category.java
    │   │   │   ├── mapper/CategoryMapper.java
    │   │   │   ├── repository/CategoryRepository.java
    │   │   │   └── service/CategoryService.java
    │   │   │
    │   │   ├── product/                              -- [DONE]
    │   │   │   ├── controller/
    │   │   │   │   ├── DigitalAssetController.java
    │   │   │   │   ├── PreOrderConfigController.java
    │   │   │   │   ├── ProductController.java
    │   │   │   │   ├── ProductImageController.java
    │   │   │   │   ├── ProductReviewController.java
    │   │   │   │   ├── ProductVariantController.java
    │   │   │   │   └── SellerProductController.java
    │   │   │   ├── dto/request/ …                     -- Create/Update Product, Variant, Asset, Review, Filter
    │   │   │   ├── dto/response/ …
    │   │   │   ├── entity/
    │   │   │   │   ├── AssetAccessLog.java
    │   │   │   │   ├── AssetDeliveryLog.java
    │   │   │   │   ├── DigitalAsset.java
    │   │   │   │   ├── PreOrderConfig.java
    │   │   │   │   ├── Product.java
    │   │   │   │   ├── ProductImage.java
    │   │   │   │   ├── ProductReview.java
    │   │   │   │   └── ProductVariant.java
    │   │   │   ├── mapper/ProductMapper.java
    │   │   │   ├── repository/ …                     -- + ProductSpecification; AssetDeliveryLogRepository.findByOrderId
    │   │   │   └── service/ …                        -- [DONE] DigitalAsset/AssetDelivery/Review/Variant/Search/PreOrderConfig
    │   │   │   # [DONE-DLV] DigitalAsset entity: + deliveryContent (nguyên văn 1 dòng giao khách)
    │   │   │   # [DONE-DLV] uploadAssets: 1 dòng TXT = 1 asset, ghi deliveryContent (không cần AssetImportService riêng)
    │   │   │   # [DONE-DLV] AssetDeliveryLog entity: + deliveryContentSnapshot — chụp nguyên văn lúc giao
    │   │   │   # [DONE-DLV] AssetDeliveryService.logDelivery: snapshot delivery_content (jsonb-safe)
    │   │   │
    │   │   ├── cart/                                 -- [DONE] [ADD v8]
    │   │   │   ├── controller/CartController.java    -- /api/v1/cart
    │   │   │   ├── dto/request/
    │   │   │   │   ├── AddToCartRequest.java
    │   │   │   │   ├── CartCheckoutRequest.java
    │   │   │   │   └── UpdateCartItemRequest.java
    │   │   │   ├── dto/response/
    │   │   │   │   ├── CartItemResponse.java
    │   │   │   │   └── CartResponse.java
    │   │   │   ├── entity/
    │   │   │   │   ├── Cart.java                     -- 1 user = 1 cart
    │   │   │   │   └── CartItem.java
    │   │   │   ├── repository/
    │   │   │   │   ├── CartItemRepository.java
    │   │   │   │   └── CartRepository.java
    │   │   │   └── service/CartService.java           -- checkout → CheckoutService, xóa giỏ nếu OK
    │   │   │
    │   │   ├── voucher/                              -- [TODO]
    │   │   │   ├── controller/VoucherController.java
    │   │   │   ├── dto/request|response/ …
    │   │   │   ├── entity/
    │   │   │   │   ├── Voucher.java
    │   │   │   │   ├── VoucherProduct.java
    │   │   │   │   └── VoucherUsage.java
    │   │   │   ├── repository/ …
    │   │   │   └── service/VoucherService.java
    │   │   │
    │   │   ├── order/                                -- [DONE]
    │   │   │   ├── controller/
    │   │   │   │   ├── CheckoutController.java
    │   │   │   │   ├── OrderController.java           -- [DONE-DLV] GET /{id}/assets đọc SNAPSHOT asset_delivery_logs
    │   │   │   │   │                                  --   (fallback kho cho đơn cũ chưa có log)
    │   │   │   │   └── SellerOrderController.java     -- [DONE] POST /{id}/accept, /{id}/complete
    │   │   │   │                                      -- [DONE-DLV] /complete nhận body DeliverPreOrderRequest
    │   │   │   ├── dto/request/
    │   │   │   │   ├── CheckoutItemRequest.java
    │   │   │   │   ├── CheckoutRequest.java           -- + idempotencyKey; force WALLET
    │   │   │   │   └── DeliverPreOrderRequest.java    -- [DONE-DLV] deliveryContentType + deliveryContent (@NotBlank, max 10000) + sellerNotes
    │   │   │   ├── dto/response/ …
    │   │   │   │   ├── DeliveredAssetResponse.java    -- [DONE-DLV] content từ snapshot (INSTANT)
    │   │   │   │   └── PreOrderItemResponse.java      -- [DONE-DLV] status + deliveryContent trong chi tiết đơn (PRE_ORDER)
    │   │   │   ├── entity/
    │   │   │   │   ├── Order.java
    │   │   │   │   ├── OrderItem.java                 -- fee snapshot fields
    │   │   │   │   ├── OrderStatusLog.java
    │   │   │   │   ├── PreOrderItem.java              -- [DONE-DLV] + status, deliveryContent, deliveryContentType,
    │   │   │   │   │                                  --   acceptedAt, deliveredAt, completedAt
    │   │   │   │   └── DeliveryContentType.java       -- [DONE-DLV] enum ACCOUNT | KEY | MESSAGE | OTHER
    │   │   │   │   # status PreOrderItem dùng String (khớp style codebase): PENDING|ACCEPTED|PROCESSING|DELIVERED|REJECTED|CANCELLED
    │   │   │   ├── mapper/OrderMapper.java
    │   │   │   ├── repository/
    │   │   │   │   ├── OrderRepository.java           -- pessimistic lock, idempotency
    │   │   │   │   ├── OrderItemRepository.java
    │   │   │   │   ├── OrderStatusLogRepository.java
    │   │   │   │   └── PreOrderItemRepository.java
    │   │   │   ├── scheduler/
    │   │   │   │   ├── OrderCancelProcessor.java      -- [DONE] lock + guard
    │   │   │   │   └── OrderCronJobService.java        -- [DONE] @SchedulerLock
    │   │   │   └── service/
    │   │   │       ├── CheckoutService.java
    │   │   │       ├── InstantOrderService.java      -- 1 item = 1 HoldRelease + 1 FeeLedger
    │   │   │       │                                  -- [DONE-DLV] khi bán: snapshot nguyên văn vào asset_delivery_logs
    │   │   │       ├── PreOrderService.java          -- trừ ví ngay + snapshot phí
    │   │   │       ├── PreOrderApprovalService.java  -- [DONE] accept/reject/complete + lock
    │   │   │       │                                  -- [DONE-DLV] accept→ACCEPTED+acceptedAt; complete→deliveryContent+type,
    │   │   │       │                                  --   DELIVERED+deliveredAt; reject/cancel→REJECTED/CANCELLED
    │   │   │       ├── OrderService.java             -- [DONE-DLV] chi tiết đơn gắn PreOrderItemResponse cho item PRE_ORDER
    │   │   │       └── OrderStatusService.java
    │   │   │
    │   │   ├── fee/                                  -- [DONE] (KHÔNG waive)
    │   │   │   ├── controller/
    │   │   │   │   ├── FeeConfigController.java      -- ADMIN fee-configs
    │   │   │   │   └── SellerFeeController.java      -- seller fees (ownership check)
    │   │   │   ├── dto/
    │   │   │   │   ├── FeeResult.java
    │   │   │   │   ├── request/
    │   │   │   │   │   ├── CreateFeeConfigRequest.java
    │   │   │   │   │   └── UpdateFeeConfigRequest.java
    │   │   │   │   │   # [DEL] WaiveFeeRequest
    │   │   │   │   └── response/
    │   │   │   │       ├── FeeBreakdownResponse.java
    │   │   │   │       ├── FeeConfigResponse.java
    │   │   │   │       ├── FeeLedgerResponse.java     -- PENDING|COLLECTED|CANCELLED|ADJUSTED
    │   │   │   │       ├── FeeLogResponse.java
    │   │   │   │       └── ShopFeeSummaryResponse.java
    │   │   │   ├── entity/
    │   │   │   │   ├── PlatformFeeConfig.java
    │   │   │   │   ├── PlatformFeeLedger.java
    │   │   │   │   ├── PlatformFeeLog.java
    │   │   │   │   └── ShopFeeSummary.java
    │   │   │   ├── mapper/FeeMapper.java
    │   │   │   ├── repository/ …
    │   │   │   └── service/
    │   │   │       ├── FeeCalculationService.java   -- 4%, CEILING
    │   │   │       ├── PlatformFeeConfigService.java
    │   │   │       ├── PlatformFeeLedgerService.java -- NO waive; cancel on dispute
    │   │   │       └── ShopFeeSummaryService.java
    │   │   │
    │   │   ├── wallet/                               -- [DONE]
    │   │   │   ├── config/
    │   │   │   │   └── PlatformWalletInitializer.java
    │   │   │   ├── controller/
    │   │   │   │   ├── AdminWithdrawalController.java
    │   │   │   │   ├── DepositController.java         -- VNPay IPN + amount match
    │   │   │   │   ├── WalletController.java
    │   │   │   │   └── WithdrawalController.java
    │   │   │   ├── dto/request|response/ …
    │   │   │   ├── entity/
    │   │   │   │   ├── Deposit.java
    │   │   │   │   ├── HoldRelease.java               -- orderId + orderItemId
    │   │   │   │   ├── Wallet.java                    -- isPlatform
    │   │   │   │   ├── WalletTransaction.java
    │   │   │   │   └── Withdrawal.java
    │   │   │   ├── mapper/WalletMapper.java
    │   │   │   ├── repository/ …
    │   │   │   ├── scheduler/
    │   │   │   │   └── HoldReleaseScheduler.java      -- [DONE] @SchedulerLock
    │   │   │   └── service/
    │   │   │       ├── DepositService.java
    │   │   │       ├── HoldReleaseProcessor.java      -- T+7: net + fee collect
    │   │   │       ├── HoldReleaseService.java        -- dispute freeze/resolve
    │   │   │       ├── WalletService.java
    │   │   │       ├── WalletTransactionService.java
    │   │   │       └── WithdrawalService.java
    │   │   │
    │   │   ├── payment/                              -- [TODO] (hiện VNPay nằm trong DepositController)
    │   │   │   ├── controller/PaymentController.java
    │   │   │   ├── dto/ …
    │   │   │   ├── entity/Payment.java
    │   │   │   ├── service/
    │   │   │   │   ├── PaymentService.java
    │   │   │   │   ├── VnPayService.java
    │   │   │   │   ├── MomoService.java
    │   │   │   │   ├── ZaloPayService.java
    │   │   │   │   └── PaymentCallbackService.java
    │   │   │   └── client/
    │   │   │       ├── VnPayClient.java
    │   │   │       ├── MomoClient.java
    │   │   │       └── ZaloPayClient.java
    │   │   │
    │   │   ├── dispute/                              -- [TODO] (logic một phần ở HoldReleaseService)
    │   │   │   ├── controller/
    │   │   │   │   ├── DisputeController.java
    │   │   │   │   └── SellerDisputeController.java
    │   │   │   ├── dto/request/
    │   │   │   │   ├── CreateDisputeRequest.java
    │   │   │   │   ├── SellerRespondRequest.java
    │   │   │   │   └── AdminResolveDisputeRequest.java
    │   │   │   ├── dto/response/DisputeResponse.java
    │   │   │   ├── entity/OrderDispute.java
    │   │   │   ├── repository/OrderDisputeRepository.java
    │   │   │   ├── service/
    │   │   │   │   ├── DisputeService.java
    │   │   │   │   └── DisputeResolutionService.java  -- BUYER_WIN → CANCELLED ledger (không WAIVED)
    │   │   │   └── mapper/DisputeMapper.java
    │   │   │
    │   │   ├── chat/                                 -- [TODO]
    │   │   │   ├── controller/
    │   │   │   │   ├── ChatRestController.java
    │   │   │   │   └── ChatWebSocketController.java
    │   │   │   ├── dto/ …
    │   │   │   ├── entity/ ChatRoom.java, ChatMessage.java
    │   │   │   ├── repository/ …
    │   │   │   ├── service/ …
    │   │   │   ├── mapper/ChatMapper.java
    │   │   │   └── websocket/ …
    │   │   │
    │   │   ├── notification/                         -- [TODO]
    │   │   │   ├── controller/NotificationController.java
    │   │   │   ├── dto/response/NotificationResponse.java
    │   │   │   ├── entity/Notification.java
    │   │   │   ├── repository/NotificationRepository.java
    │   │   │   ├── service/
    │   │   │   │   ├── NotificationService.java
    │   │   │   │   ├── EmailNotificationService.java
    │   │   │   │   ├── InAppNotificationService.java
    │   │   │   │   └── PushNotificationService.java
    │   │   │   ├── consumer/
    │   │   │   │   ├── OrderNotificationConsumer.java
    │   │   │   │   ├── PreOrderNotificationConsumer.java
    │   │   │   │   ├── PaymentNotificationConsumer.java
    │   │   │   │   ├── DisputeNotificationConsumer.java
    │   │   │   │   └── FeeNotificationConsumer.java   -- FEE_COLLECTED / FEE_CANCELLED
    │   │   │   └── producer/NotificationProducer.java
    │   │   │
    │   │   ├── audit/                                -- [TODO]
    │   │   │   ├── controller/AuditLogController.java
    │   │   │   ├── dto/response/AuditLogResponse.java
    │   │   │   ├── entity/AuditLog.java
    │   │   │   ├── repository/AuditLogRepository.java
    │   │   │   ├── service/AuditLogService.java
    │   │   │   └── mapper/AuditLogMapper.java
    │   │   │
    │   │   ├── fraud/                                -- [TODO]
    │   │   │   ├── controller/RiskFlagController.java
    │   │   │   ├── dto/ …
    │   │   │   ├── entity/ UserLoginLog.java, RiskFlag.java
    │   │   │   ├── repository/ …
    │   │   │   ├── service/
    │   │   │   │   ├── FraudDetectionService.java
    │   │   │   │   ├── LoginLogService.java
    │   │   │   │   └── RiskFlagService.java
    │   │   │   └── mapper/FraudMapper.java
    │   │   │
    │   │   ├── admin/                                -- [TODO] (một phần fee/withdrawal đã nằm module khác)
    │   │   │   ├── controller/
    │   │   │   │   ├── AdminUserController.java
    │   │   │   │   ├── AdminShopController.java
    │   │   │   │   ├── AdminOrderController.java
    │   │   │   │   ├── AdminPreOrderController.java
    │   │   │   │   ├── AdminProductController.java
    │   │   │   │   ├── AdminDisputeController.java
    │   │   │   │   ├── AdminWalletController.java
    │   │   │   │   ├── AdminWithdrawalController.java -- [DONE] hiện ở wallet/
    │   │   │   │   ├── AdminFeeController.java        -- [DONE] tạm = FeeConfigController
    │   │   │   │   └── DashboardController.java
    │   │   │   ├── dto/request/
    │   │   │   │   ├── BanUserRequest.java
    │   │   │   │   ├── SuspendShopRequest.java
    │   │   │   │   ├── AdjustWalletRequest.java
    │   │   │   │   ├── ProcessWithdrawalRequest.java
    │   │   │   │   ├── ForceRejectPreOrderRequest.java
    │   │   │   │   ├── ForceCompletePreOrderRequest.java
    │   │   │   │   └── ChangeFeeConfigRequest.java
    │   │   │   │   # [DEL] WaiveFeeManualRequest
    │   │   │   ├── dto/response/
    │   │   │   │   ├── DashboardSummaryResponse.java
    │   │   │   │   ├── RevenueStatsResponse.java      -- + total_platform_fee
    │   │   │   │   ├── AdminFeeLedgerResponse.java
    │   │   │   │   └── AdminFeeStatsResponse.java     -- total thu / cancelled / adjusted (không waived)
    │   │   │   └── service/
    │   │   │       ├── AdminUserService.java
    │   │   │       ├── AdminShopService.java
    │   │   │       ├── AdminOrderService.java
    │   │   │       ├── AdminPreOrderService.java
    │   │   │       ├── AdminDisputeService.java
    │   │   │       ├── AdminWalletService.java
    │   │   │       ├── AdminWithdrawalService.java
    │   │   │       ├── AdminFeeService.java           -- query + change config (NO waive)
    │   │   │       └── DashboardService.java
    │   │   │
    │   │   ├── file/                                 -- [TODO]
    │   │   │   ├── controller/FileUploadController.java
    │   │   │   ├── dto/response/FileUploadResponse.java
    │   │   │   └── service/
    │   │   │       ├── FileStorageService.java
    │   │   │       ├── LocalFileStorageService.java
    │   │   │       └── MinioFileStorageService.java
    │   │   │
    │   │   ├── cache/                                -- [TODO] Redis
    │   │   │   ├── redis/
    │   │   │   │   ├── RedisKeyGenerator.java
    │   │   │   │   ├── RedisCacheService.java
    │   │   │   │   └── RedisKeyPrefix.java
    │   │   │   └── refresh/RefreshTokenCacheService.java
    │   │   │
    │   │   ├── event/                                -- [TODO] Kafka / messaging
    │   │   │   ├── producer/
    │   │   │   │   ├── OrderEventProducer.java
    │   │   │   │   ├── PreOrderEventProducer.java
    │   │   │   │   ├── PaymentEventProducer.java
    │   │   │   │   ├── DisputeEventProducer.java
    │   │   │   │   ├── WalletEventProducer.java
    │   │   │   │   └── FeeEventProducer.java          -- FEE_COLLECTED, FEE_CANCELLED (không FEE_WAIVED)
    │   │   │   ├── consumer/ …
    │   │   │   └── payload/
    │   │   │       ├── …Order*/PreOrder*/Payment*/Dispute*/HoldReleased…
    │   │   │       ├── FeeCollectedPayload.java
    │   │   │       └── FeeCancelledPayload.java       -- thay FeeWaivedPayload
    │   │   │
    │   │   ├── outbox/                               -- [TODO]
    │   │   │   ├── entity/OutboxEvent.java
    │   │   │   ├── repository/OutboxEventRepository.java
    │   │   │   └── service/
    │   │   │       ├── OutboxEventService.java
    │   │   │       └── OutboxPollerService.java
    │   │   │
    │   │   ├── idempotency/                          -- [TODO] (một phần key đã có trên Order/Deposit/Withdrawal)
    │   │   │   ├── entity/IdempotencyKey.java
    │   │   │   ├── repository/IdempotencyKeyRepository.java
    │   │   │   ├── service/IdempotencyService.java
    │   │   │   └── filter/IdempotencyFilter.java
    │   │   │
    │   │   └── scheduler/                            -- [TODO] gom các job còn thiếu
    │   │       # [DONE] đã nằm ở order/scheduler + wallet/scheduler
    │   │       ├── DisputeDeadlineScheduler.java
    │   │       ├── AssetReservationCleanupScheduler.java
    │   │       ├── PreOrderTimeoutScheduler.java      -- (một phần = OrderCancelProcessor)
    │   │       ├── NotificationArchiveScheduler.java
    │   │       ├── DisputeRateReconcileScheduler.java
    │   │       ├── StockCountSyncScheduler.java
    │   │       ├── ClearExpiredTokenScheduler.java
    │   │       ├── PartitionCreateScheduler.java
    │   │       ├── FeeSummaryReconcileScheduler.java
    │   │       └── JobLogService.java
    │   │
    │   └── resources/
    │       ├── application.yaml                      -- [DONE]
    │       ├── application-dev.yml                   -- [TODO]
    │       ├── application-prod.yml                  -- [TODO]
    │       └── db/migration/                         -- [TODO] Flyway (hiện dùng sql/ + ddl-auto validate)
    │           ├── V1__… → V16__…
    │           ├── V17__platform_fee_tables.sql
    │           └── V18__cart_drop_favorite.sql
    │
    └── test/                                         -- [TODO]
        ├── unit/ fee/, order/, wallet/, cart/
        └── integration/
            ├── FeeCollectionIntegrationTest.java
            ├── FeeDisputeBuyerWinIntegrationTest.java   -- expect CANCELLED (không WAIVED)
            └── FeeDisputePartialRefundIntegrationTest.java
```

## Ma trận module

| Module | Trạng thái | Ghi chú |
|--------|------------|---------|
| auth, user, security, common, config | DONE | |
| shop, category, product | DONE | không favorite |
| cart | DONE | API `/api/v1/cart` |
| order (+ checkout, pre-order, schedulers) | DONE | trừ ví ngay |
| fee | DONE | không waive |
| wallet (+ deposit IPN, hold, withdrawal) | DONE | |
| voucher, dispute, chat, notification | TODO | bảng đã có trong schema SQL |
| audit, fraud, admin, file, payment | TODO | |
| cache/redis, event/kafka, outbox, Flyway | TODO | |
| Favorite | DEL | không tạo lại |

## API Cart (DONE)

| Method | Path | Mô tả |
|--------|------|-------|
| GET | `/api/v1/cart` | Xem giỏ |
| POST | `/api/v1/cart/items` | Thêm (cộng dồn nếu trùng variant) |
| PUT | `/api/v1/cart/items/{itemId}` | Đổi số lượng |
| DELETE | `/api/v1/cart/items/{itemId}` | Xóa 1 dòng |
| DELETE | `/api/v1/cart` | Xóa sạch |
| POST | `/api/v1/cart/checkout` | Checkout → xóa giỏ nếu thành công |

## Luồng tiền (khớp code)

```
Nạp ví (VNPay IPN, đối chiếu amount)
  → Checkout (cart hoặc /checkout) trừ WALLET ngay
  → holdForSeller(total)
  → mỗi OrderItem: HoldRelease + FeeLedger (PENDING), fee snapshot 4% CEILING
  → T+7 HoldReleaseScheduler: seller net + platform fee (COLLECTED)
  → dispute buyer win: cancel hold + refund buyer + ledger CANCELLED
```

## Luồng giao hàng (delivery_content)

```
INSTANT:
  seller import TXT (1 dòng = 1 asset, delivery_content) → AVAILABLE
  → khách mua: lock N dòng AVAILABLE → RESERVED → thanh toán OK
  → snapshot nguyên văn vào asset_delivery_logs.delivery_content_snapshot → asset SOLD
  → buyer xem lại đơn: đọc TỪ SNAPSHOT (không đọc lại kho)

PRE_ORDER:
  khách đặt (trừ ví ngay) → shop accept (acceptedAt, PENDING→ACCEPTED→PROCESSING)
  → shop nhập delivery_content (+ deliveryContentType) → DELIVERED (deliveredAt)
  → buyer xem lại từ pre_order_items.delivery_content
  hoặc PENDING → REJECTED / quá hạn → CANCELLED (hoàn tiền)
```

## Bảo mật delivery content (bắt buộc khi implement)

- **Không ghi** `delivery_content` / snapshot vào log ứng dụng.
- Chỉ trả nội dung trong **API chi tiết đơn** — không bao giờ trong API danh sách.
- Quyền xem: **buyer sở hữu đơn**, **shop bán** (để đối chiếu bảo hành khi khách báo lỗi tài khoản/key), **admin** xử lý dispute.
- Response chi tiết đơn: `Cache-Control: no-store`; không đưa nội dung vào URL/query.
- Roadmap: mã hóa at-rest (AES-GCM ở app layer hoặc pgcrypto) trước khi lưu DB.
