# commercehub-frontend — Cấu trúc thư mục v8 (scaffold đầy đủ)

> Stack: **Next.js 14 (App Router) + TypeScript + Tailwind CSS + shadcn/ui**
>
> Repo hiện tại: `D:\LuuCode1\Project\commercehub-frontend` — **chưa có `src/`**, file này là **cây mục tiêu** để scaffold.
>
> **Chú thích**
> - `[TODO]` — chưa có code frontend (toàn bộ scaffold đều TODO cho đến khi implement)
> - `[DEL]` — không tạo: Favorite, WaiveFeeDialog
> - `[ADD]` — bắt buộc có: Cart (page/components/store/service)
>
> ## 3 portal
> - `/` → Buyer (trang chủ do `(buyer)/page.tsx` đảm nhiệm — không có `app/page.tsx` để tránh 2 page cùng resolve về `/`)
> - `/seller` → Seller
> - `/admin` → Admin
>
> ## Quyết định đã chốt
> - Không Favorite shop
> - Có giỏ hàng đầy đủ
> - Không admin waive phí
> - Checkout mua hàng chỉ **WALLET** (nạp qua VNPay/MoMo — gateway chỉ dùng để nạp)
> - Fee status: `PENDING | COLLECTED | CANCELLED | ADJUSTED`

```
commercehub-frontend/                                 -- [TODO] scaffold
├── .env.local
├── .env.example                                      -- NEXT_PUBLIC_API_URL=http://localhost:8080
├── .gitignore
├── next.config.mjs                                   -- Next 14 KHÔNG hỗ trợ next.config.ts (TS config chỉ từ Next 15)
├── tailwind.config.ts
├── tsconfig.json
├── postcss.config.js
├── components.json
├── package.json
├── README.md
│
├── public/
│   ├── favicon.ico
│   ├── logo.svg
│   ├── logo-dark.svg
│   ├── placeholder-product.png
│   ├── placeholder-avatar.png
│   ├── placeholder-shop.png
│   └── icons/
│       ├── vnpay.svg
│       ├── momo.svg
│       └── zalopay.svg
│
├── tests/
│   ├── unit/
│   ├── integration/
│   │   ├── checkout-instant.test.tsx
│   │   ├── checkout-preorder.test.tsx
│   │   ├── cart-flow.test.tsx                        -- [ADD]
│   │   └── dispute-flow.test.tsx
│   └── e2e/
│       ├── auth.spec.ts
│       ├── buyer-purchase.spec.ts
│       ├── seller-manage.spec.ts
│       └── admin-fee.spec.ts                         -- config phí (không waive)
│
└── src/
    ├── app/
    │   ├── layout.tsx                                -- root layout (KHÔNG đặt page.tsx ở đây — trang chủ là (buyer)/page.tsx, tránh trùng route "/")
    │   ├── not-found.tsx
    │   ├── error.tsx
    │   ├── loading.tsx
    │   │
    │   ├── (auth)/
    │   │   ├── layout.tsx
    │   │   ├── login/page.tsx
    │   │   ├── register/page.tsx
    │   │   ├── forgot-password/page.tsx
    │   │   ├── reset-password/page.tsx
    │   │   └── verify-email/page.tsx
    │   │
    │   ├── (buyer)/
    │   │   ├── layout.tsx                            -- Header (CartIcon) + Footer
    │   │   ├── page.tsx
    │   │   ├── products/
    │   │   │   ├── page.tsx
    │   │   │   └── [productId]/page.tsx
    │   │   ├── categories/[slug]/page.tsx
    │   │   ├── shops/[slug]/page.tsx                 -- KHÔNG nút yêu thích
    │   │   ├── search/page.tsx
    │   │   ├── cart/page.tsx                          -- [ADD] Giỏ hàng
    │   │   ├── checkout/
    │   │   │   ├── page.tsx                          -- từ giỏ hoặc buy-now
    │   │   │   └── result/page.tsx
    │   │   ├── orders/
    │   │   │   ├── page.tsx
    │   │   │   └── [orderId]/
    │   │   │       ├── page.tsx
    │   │   │       └── dispute/page.tsx
    │   │   ├── wallet/
    │   │   │   ├── page.tsx
    │   │   │   ├── deposit/page.tsx                  -- nạp VNPay/MoMo (không thanh toán order)
    │   │   │   └── withdraw/page.tsx
    │   │   ├── notifications/page.tsx
    │   │   ├── chat/
    │   │   │   ├── page.tsx
    │   │   │   └── [roomId]/page.tsx
    │   │   └── profile/
    │   │       ├── page.tsx
    │   │       ├── edit/page.tsx
    │   │       └── change-password/page.tsx
    │   │
    │   ├── seller/
    │   │   ├── layout.tsx
    │   │   ├── page.tsx                              -- Dashboard
    │   │   ├── shop/
    │   │   │   ├── page.tsx
    │   │   │   ├── setup/page.tsx
    │   │   │   └── edit/page.tsx
    │   │   ├── products/
    │   │   │   ├── page.tsx
    │   │   │   ├── create/page.tsx
    │   │   │   └── [productId]/
    │   │   │       ├── page.tsx
    │   │   │       ├── variants/page.tsx
    │   │   │       ├── assets/page.tsx
    │   │   │       └── pre-order-config/page.tsx
    │   │   ├── orders/
    │   │   │   ├── page.tsx
    │   │   │   └── [orderId]/page.tsx
    │   │   ├── pre-orders/
    │   │   │   ├── page.tsx
    │   │   │   └── [orderId]/page.tsx               -- duyệt / từ chối / hoàn thành
    │   │   ├── disputes/
    │   │   │   ├── page.tsx
    │   │   │   └── [disputeId]/page.tsx
    │   │   ├── vouchers/
    │   │   │   ├── page.tsx
    │   │   │   ├── create/page.tsx
    │   │   │   └── [voucherId]/page.tsx
    │   │   ├── wallet/
    │   │   │   ├── page.tsx
    │   │   │   └── withdraw/page.tsx
    │   │   ├── fees/
    │   │   │   ├── page.tsx                          -- shop_fee_summaries
    │   │   │   └── [year]/[month]/page.tsx         -- chi tiết ledger
    │   │   ├── chat/
    │   │   │   ├── page.tsx
    │   │   │   └── [roomId]/page.tsx
    │   │   └── notifications/page.tsx
    │   │
    │   └── admin/
    │       ├── layout.tsx
    │       ├── page.tsx
    │       ├── users/
    │       │   ├── page.tsx
    │       │   └── [userId]/page.tsx
    │       ├── shops/
    │       │   ├── page.tsx
    │       │   └── [shopId]/page.tsx
    │       ├── products/
    │       │   ├── page.tsx
    │       │   └── [productId]/page.tsx
    │       ├── orders/
    │       │   ├── page.tsx
    │       │   └── [orderId]/page.tsx
    │       ├── pre-orders/
    │       │   ├── page.tsx
    │       │   └── [orderId]/page.tsx
    │       ├── disputes/
    │       │   ├── page.tsx
    │       │   └── [disputeId]/page.tsx
    │       ├── wallets/
    │       │   ├── page.tsx
    │       │   └── [walletId]/page.tsx
    │       ├── withdrawals/
    │       │   ├── page.tsx
    │       │   └── [withdrawalId]/page.tsx
    │       ├── fees/
    │       │   ├── page.tsx                          -- tổng quan phí sàn
    │       │   ├── config/page.tsx                   -- đổi tỷ lệ (KHÔNG waive)
    │       │   └── ledgers/
    │       │       ├── page.tsx
    │       │       └── [ledgerId]/page.tsx          -- không nút waive
    │       ├── categories/
    │       │   ├── page.tsx
    │       │   └── [categoryId]/page.tsx
    │       ├── reports/
    │       │   ├── page.tsx
    │       │   └── [reportId]/page.tsx
    │       ├── risk-flags/
    │       │   ├── page.tsx
    │       │   └── [flagId]/page.tsx
    │       └── audit-logs/page.tsx
    │
    ├── components/
    │   ├── ui/                                       -- shadcn/ui
    │   │   ├── button.tsx
    │   │   ├── input.tsx
    │   │   ├── dialog.tsx
    │   │   ├── card.tsx
    │   │   ├── table.tsx
    │   │   ├── badge.tsx
    │   │   ├── form.tsx
    │   │   ├── skeleton.tsx
    │   │   ├── toast.tsx
    │   │   └── …
    │   │
    │   ├── layout/
    │   │   ├── buyer/
    │   │   │   ├── Header.tsx                        -- logo, search, CartIcon, user menu
    │   │   │   ├── Footer.tsx
    │   │   │   ├── MobileNav.tsx
    │   │   │   └── CategoryBar.tsx
    │   │   ├── seller/
    │   │   │   ├── SellerHeader.tsx
    │   │   │   ├── SellerSidebar.tsx                 -- + menu Phí sàn
    │   │   │   └── SellerBreadcrumb.tsx
    │   │   └── admin/
    │   │       ├── AdminHeader.tsx
    │   │       ├── AdminSidebar.tsx
    │   │       └── AdminBreadcrumb.tsx
    │   │
    │   ├── common/
    │   │   ├── AppProviders.tsx
    │   │   ├── ConfirmDialog.tsx
    │   │   ├── EmptyState.tsx
    │   │   ├── LoadingSpinner.tsx
    │   │   ├── DataTable.tsx
    │   │   ├── Pagination.tsx
    │   │   ├── SearchInput.tsx
    │   │   ├── CurrencyDisplay.tsx
    │   │   ├── StatusBadge.tsx
    │   │   └── ProtectedRoute.tsx
    │   │
    │   ├── auth/
    │   │   ├── LoginForm.tsx
    │   │   ├── RegisterForm.tsx
    │   │   ├── ForgotPasswordForm.tsx
    │   │   ├── ResetPasswordForm.tsx
    │   │   └── VerifyEmailBanner.tsx
    │   │
    │   ├── product/
    │   │   ├── ProductCard.tsx
    │   │   ├── ProductGrid.tsx
    │   │   ├── ProductList.tsx
    │   │   ├── ProductImageSlider.tsx
    │   │   ├── ProductVariantSelector.tsx
    │   │   ├── ProductFilterPanel.tsx
    │   │   ├── ProductSortSelect.tsx
    │   │   ├── ProductReviewList.tsx
    │   │   ├── ProductReviewForm.tsx
    │   │   ├── ProductStockBadge.tsx
    │   │   ├── DeliveryTypeBadge.tsx
    │   │   ├── PreOrderInfoBox.tsx
    │   │   ├── AddToCartButton.tsx                  -- [ADD]
    │   │   └── BuyNowButton.tsx                     -- [ADD] → checkout
    │   │
    │   ├── shop/
    │   │   ├── ShopCard.tsx                         -- KHÔNG dùng cho favorite list
    │   │   ├── ShopHeader.tsx                       -- KHÔNG còn FavoriteShopButton [DEL]
    │   │   ├── ShopRatingBadge.tsx
    │   │   ├── ShopDisputeRateBadge.tsx
    │   │   └── ReportShopDialog.tsx
    │   │
    │   ├── cart/                                    -- [ADD]
    │   │   ├── CartItem.tsx
    │   │   ├── CartSummary.tsx
    │   │   ├── CartEmpty.tsx
    │   │   └── CartIcon.tsx                          -- badge số lượng header
    │   │
    │   ├── checkout/
    │   │   ├── CheckoutItemList.tsx
    │   │   ├── CheckoutInstantItem.tsx
    │   │   ├── CheckoutPreOrderItem.tsx              -- form buyer_inputs
    │   │   ├── VoucherInput.tsx
    │   │   ├── CheckoutSummary.tsx                   -- chỉ WALLET (không PaymentMethodSelect mua hàng)
    │   │   └── CheckoutResultCard.tsx
    │   │
    │   ├── order/
    │   │   ├── OrderCard.tsx
    │   │   ├── OrderStatusStepper.tsx
    │   │   ├── OrderStatusBadge.tsx
    │   │   ├── OrderItemDetail.tsx
    │   │   ├── DeliveredAssetBox.tsx
    │   │   ├── PreOrderItemDetail.tsx
    │   │   ├── OrderStatusLog.tsx
    │   │   ├── PreOrderApprovalTimer.tsx
    │   │   └── ReviewOrderButton.tsx
    │   │
    │   ├── dispute/
    │   │   ├── DisputeCreateForm.tsx
    │   │   ├── DisputeStatusBadge.tsx
    │   │   ├── DisputeTimeline.tsx
    │   │   ├── DisputeEvidenceUpload.tsx
    │   │   └── DisputeDeadlineTimer.tsx
    │   │
    │   ├── wallet/
    │   │   ├── WalletBalanceCard.tsx
    │   │   ├── TransactionItem.tsx
    │   │   ├── TransactionList.tsx
    │   │   ├── DepositForm.tsx                       -- chọn cổng nạp
    │   │   ├── WithdrawForm.tsx
    │   │   ├── HoldReleaseInfo.tsx
    │   │   └── PaymentProviderButton.tsx             -- chỉ dùng cho DEPOSIT
    │   │
    │   ├── fee/
    │   │   ├── FeeSummaryCard.tsx
    │   │   ├── FeeBreakdownTable.tsx
    │   │   ├── FeeLedgerStatusBadge.tsx              -- PENDING|COLLECTED|CANCELLED|ADJUSTED
    │   │   ├── FeeMonthSelector.tsx
    │   │   └── FeeChartMonthly.tsx
    │   │
    │   ├── notification/
    │   │   ├── NotificationItem.tsx
    │   │   ├── NotificationList.tsx
    │   │   ├── NotificationBell.tsx
    │   │   └── NotificationTypeIcon.tsx
    │   │
    │   ├── chat/
    │   │   ├── ChatRoomList.tsx
    │   │   ├── ChatRoomItem.tsx
    │   │   ├── ChatWindow.tsx
    │   │   ├── ChatMessage.tsx
    │   │   ├── ChatInput.tsx
    │   │   ├── ChatAttachment.tsx
    │   │   └── ChatTypingIndicator.tsx
    │   │
    │   ├── seller/
    │   │   ├── dashboard/
    │   │   │   ├── RevenueChart.tsx
    │   │   │   ├── OrderStatsCard.tsx
    │   │   │   ├── ProductLimitBar.tsx
    │   │   │   └── LevelUpgradeAlert.tsx
    │   │   ├── product/
    │   │   │   ├── ProductForm.tsx
    │   │   │   ├── VariantForm.tsx
    │   │   │   ├── VariantList.tsx
    │   │   │   ├── AssetUploadForm.tsx
    │   │   │   ├── AssetTable.tsx
    │   │   │   └── PreOrderConfigForm.tsx
    │   │   ├── order/
    │   │   │   ├── SellerOrderTable.tsx
    │   │   │   ├── PreOrderTable.tsx
    │   │   │   ├── ApprovePreOrderDialog.tsx
    │   │   │   ├── RejectPreOrderDialog.tsx
    │   │   │   └── CompletePreOrderForm.tsx
    │   │   ├── dispute/
    │   │   │   ├── DisputeResponseForm.tsx
    │   │   │   └── DisputeEvidenceList.tsx
    │   │   └── voucher/
    │   │       ├── VoucherForm.tsx
    │   │       └── VoucherTable.tsx
    │   │
    │   └── admin/
    │       ├── dashboard/
    │       │   ├── SystemStatsCards.tsx
    │       │   ├── RevenueOverviewChart.tsx
    │       │   ├── PlatformFeeChart.tsx
    │       │   └── DisputeStatsCard.tsx
    │       ├── user/
    │       │   ├── UserTable.tsx
    │       │   ├── BanUserDialog.tsx
    │       │   └── UserRoleEditor.tsx
    │       ├── shop/
    │       │   ├── ShopTable.tsx
    │       │   └── SuspendShopDialog.tsx
    │       ├── dispute/
    │       │   ├── DisputeResolveForm.tsx
    │       │   └── DisputeTable.tsx
    │       ├── withdrawal/
    │       │   ├── WithdrawalTable.tsx
    │       │   └── ProcessWithdrawalDialog.tsx
    │       ├── fee/
    │       │   ├── FeeConfigForm.tsx                 -- đổi rate
    │       │   ├── FeeConfigHistory.tsx
    │       │   └── FeeLedgerTable.tsx
    │       │   # [DEL] WaiveFeeDialog.tsx
    │       └── audit/
    │           └── AuditLogTable.tsx
    │
    ├── hooks/
    │   ├── auth/
    │   │   ├── useAuth.ts
    │   │   ├── useRole.ts
    │   │   └── usePermission.ts
    │   ├── api/
    │   │   ├── useProducts.ts
    │   │   ├── useProduct.ts
    │   │   ├── useShop.ts
    │   │   ├── useCategories.ts
    │   │   ├── useCart.ts                             -- [ADD]
    │   │   ├── useOrders.ts
    │   │   ├── useOrder.ts
    │   │   ├── useSellerOrders.ts
    │   │   ├── usePreOrders.ts
    │   │   ├── useDisputes.ts
    │   │   ├── useWallet.ts
    │   │   ├── useNotifications.ts
    │   │   ├── useFee.ts
    │   │   ├── useAdminUsers.ts
    │   │   ├── useAdminShops.ts
    │   │   ├── useAdminFee.ts                         -- NO waive
    │   │   └── useAdminWithdrawals.ts
    │   ├── realtime/
    │   │   ├── useWebSocket.ts
    │   │   ├── useChat.ts
    │   │   └── useNotificationSocket.ts
    │   └── ui/
    │       ├── useDebounce.ts
    │       ├── useLocalStorage.ts
    │       ├── useMediaQuery.ts
    │       ├── useInfiniteScroll.ts
    │       └── useCopyToClipboard.ts
    │
    ├── stores/
    │   ├── authStore.ts
    │   ├── cartStore.ts                              -- [ADD] items, count, sync API
    │   ├── notificationStore.ts
    │   ├── chatStore.ts
    │   └── uiStore.ts
    │   # [DEL] favoriteStore.ts
    │
    ├── services/
    │   ├── api.ts                                    -- axios + refresh token
    │   ├── auth.service.ts
    │   ├── user.service.ts
    │   ├── shop.service.ts                           -- KHÔNG favoriteShop()
    │   ├── category.service.ts
    │   ├── product.service.ts
    │   ├── variant.service.ts
    │   ├── asset.service.ts
    │   ├── voucher.service.ts
    │   ├── cart.service.ts                           -- [ADD] get/add/update/remove/checkout
    │   ├── checkout.service.ts
    │   ├── order.service.ts
    │   ├── preorder.service.ts
    │   ├── dispute.service.ts
    │   ├── wallet.service.ts
    │   ├── payment.service.ts                        -- chỉ tạo URL nạp tiền
    │   ├── notification.service.ts
    │   ├── chat.service.ts
    │   ├── fee.service.ts
    │   └── admin/
    │       ├── adminUser.service.ts
    │       ├── adminShop.service.ts
    │       ├── adminOrder.service.ts
    │       ├── adminDispute.service.ts
    │       ├── adminWallet.service.ts
    │       ├── adminWithdrawal.service.ts
    │       └── adminFee.service.ts                   -- getLedgers, changeConfig (NO waiveFee)
    │
    ├── types/
    │   ├── index.ts
    │   ├── auth.types.ts
    │   ├── user.types.ts
    │   ├── shop.types.ts
    │   ├── category.types.ts
    │   ├── product.types.ts
    │   ├── variant.types.ts
    │   ├── asset.types.ts
    │   ├── voucher.types.ts
    │   ├── cart.types.ts                             -- [ADD]
    │   ├── order.types.ts
    │   ├── preorder.types.ts
    │   ├── dispute.types.ts
    │   ├── wallet.types.ts
    │   ├── fee.types.ts                              -- FeeLedgerStatus không có WAIVED
    │   ├── notification.types.ts
    │   ├── chat.types.ts
    │   └── common.types.ts
    │
    ├── lib/
    │   ├── utils.ts
    │   ├── format.ts                                 -- formatCurrency(VND)
    │   ├── constants.ts
    │   ├── validations/
    │   │   ├── auth.schema.ts
    │   │   ├── product.schema.ts
    │   │   ├── shop.schema.ts
    │   │   ├── cart.schema.ts                        -- [ADD]
    │   │   ├── checkout.schema.ts
    │   │   ├── dispute.schema.ts
    │   │   ├── wallet.schema.ts
    │   │   └── voucher.schema.ts
    │   ├── auth.ts                                   -- auth helper client (JWT do backend cấp; Google chỉ lấy id_token gửi BE — không dùng next-auth quản lý session, tránh trùng với authStore + axios refresh)
    │   ├── queryClient.ts
    │   ├── websocket.ts
    │   └── seo.ts
    │
    └── styles/
        ├── globals.css
        └── fonts.ts
```

## Ánh xạ API Cart (backend đã DONE)

| Frontend | Backend |
|----------|---------|
| `GET cart` | `GET /api/v1/cart` |
| `addItem` | `POST /api/v1/cart/items` |
| `updateQty` | `PUT /api/v1/cart/items/{id}` |
| `removeItem` | `DELETE /api/v1/cart/items/{id}` |
| `clear` | `DELETE /api/v1/cart` |
| `checkout` | `POST /api/v1/cart/checkout` |

## Thứ tự scaffold gợi ý

1. `npx create-next-app@14 … --typescript --tailwind --app --src-dir`
2. Cài: shadcn/ui, axios, zustand, @tanstack/react-query, zod, react-hook-form, dayjs, numeral, lucide-react, recharts
3. Auth → buyer products/cart/checkout/wallet → seller → admin
4. **Không** tạo Favorite / WaiveFee*
5. Admin fees: chỉ config rate + xem ledgers
