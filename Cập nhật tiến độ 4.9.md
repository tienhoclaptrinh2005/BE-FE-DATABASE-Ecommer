# CommerceHub — Cập nhật tiến độ mốc 4.9

> Ngày chốt tài liệu: **04/09/2026** (GMT+7)  
> Phạm vi đối chiếu: `V2/*.md`, `schema-v8.sql`, source backend và source frontend hiện tại.  
> Mục đích: xác định phần đã làm, phần còn thiếu, thứ tự phát triển và lịch hoàn thành dự kiến.

## 1. Kết luận nhanh

| Mức đánh giá | Tiến độ ước tính | Nhận định |
|---|---:|---|
| Chức năng MVP tổng thể | **khoảng 70%** | Luồng buyer và lõi giao dịch backend đã khá đầy đủ; seller và admin còn thiếu nhiều màn hình vận hành. |
| Backend lõi marketplace | **khoảng 82%** | Đã có auth, shop, sản phẩm, giỏ hàng, checkout, đơn hàng, ví, phí, dispute và scheduler. |
| Frontend buyer | **khoảng 80%** | Các trang mua hàng chính đang dùng API thật; còn một số luồng phụ và kiểm thử E2E. |
| Frontend seller | **khoảng 40%** | Có khung dashboard, ví, rút tiền và dispute; dashboard còn dữ liệu minh họa, chưa có trang quản lý sản phẩm/đơn hàng đầy đủ. |
| Frontend admin | **khoảng 25%** | Hiện mới có trang tổng quan đơn giản và xử lý dispute; thiếu phần quản lý shop, user, danh mục, rút tiền, phí và dashboard. |
| Mức sẵn sàng production | **khoảng 50%** | Cần hoàn thiện test, bảo mật, lưu file, monitoring, backup, CI/CD và cấu hình production. |

Mốc dự kiến nếu một người phát triển tập trung khoảng 6–8 giờ/ngày:

- **23/10/2026:** hoàn thành Release Candidate của MVP.
- **24–25/10/2026:** chạy UAT và sửa lỗi chặn phát hành.
- **26/10/2026:** có thể đưa MVP lên production nếu SePay, domain, SSL, email và máy chủ đã sẵn sàng.
- **30/11/2026:** hoàn thành nhóm tính năng mở rộng chưa cần thiết cho MVP như chat realtime, Super Admin quản lý admin, marketing nâng cao và risk/audit nâng cao.

Các tỷ lệ trên là ước tính theo tính năng và độ sẵn sàng vận hành, không phải tỷ lệ số dòng code.

---

## 2. Nguồn sự thật và lưu ý về tài liệu cũ

Các tài liệu đã đọc:

- `README.md`
- `backend-structure.md`
- `frontend-structure.md`
- `Cập nhật tiến đọ 7.8.md`
- `Cập nhật tiến đọ 26.8.md`

Một số nội dung trong các file cũ không còn đúng với source hiện tại:

- `frontend-structure.md` còn ghi frontend chưa có `src/`, nhưng frontend hiện đã có đầy đủ App Router, component, service và type.
- `backend-structure.md` còn đánh dấu dispute là TODO, nhưng hiện backend đã có luồng buyer, seller, admin và scheduler xử lý deadline.
- Nhiều URL trong tài liệu cũ đã đổi, ví dụ refresh token hiện là `/api/v1/auth/refresh-token`, chi tiết đơn buyer dùng `orderCode` thay vì ID số.

Vì vậy, trong tài liệu này:

1. **Source code hiện tại là nguồn sự thật cho API và luồng chạy.**
2. `schema-v8.sql` là nguồn sự thật cho cấu trúc database V2.
3. Các file Markdown cũ chỉ được dùng để đối chiếu quyết định nghiệp vụ và kế hoạch ban đầu.

---

## 3. Kiến trúc và công nghệ hiện tại

### Backend

- Java 21.
- Spring Boot 3.5.13.
- Spring Security + JWT.
- Spring Data JPA/Hibernate.
- PostgreSQL.
- ShedLock cho các scheduler nhiều instance.
- MapStruct, Bean Validation.
- `spring.jpa.open-in-view: false` để tránh lazy query ngoài transaction.
- Giới hạn pageable toàn cục tối đa 100 bản ghi/lần.
- Job xử lý theo batch, cấu hình hiện tại 200 bản ghi/lượt.

### Frontend

- Next.js 16.3.0 App Router.
- React 19.2.8.
- TypeScript 5.
- Tailwind CSS 4.
- Axios.
- Zustand.
- React Hook Form + Zod.

### Xác thực hiện tại

- Đăng nhập hỗ trợ **email hoặc username**.
- Access token có thời hạn **15 phút**.
- Refresh token có thời hạn **7 ngày** và được lưu bằng cookie HttpOnly.
- Access token được giữ ở bộ nhớ frontend và khôi phục qua refresh khi tải lại trang.
- JWT filter lấy danh tính từ token rồi tải lại user từ database, vì vậy quyền backend phản ánh role hiện tại ở request kế tiếp. Frontend vẫn cần tải lại `/api/v1/users/me` để cập nhật menu sau khi admin duyệt seller.

### Phân quyền hiện tại

Mỗi user chỉ giữ một role nghiệp vụ:

```text
BUYER
SELLER > BUYER
ADMIN > BUYER
SUPER_ADMIN > ADMIN > BUYER
```

- SELLER vẫn có chức năng mua hàng.
- ADMIN và SUPER_ADMIN có chức năng buyer nhưng **không kế thừa SELLER** và không được mở shop.
- Controller seller được chặn bằng role SELLER.
- Controller admin được chặn bằng ADMIN hoặc SUPER_ADMIN.
- Service tiếp tục kiểm tra quyền sở hữu; không chỉ dựa vào role.

---

## 4. Những phần đã hoàn thành đến 04/09/2026

### 4.1. Luồng user/buyer

- Đăng ký tài khoản và gán BUYER mặc định.
- Đăng nhập bằng email hoặc username, đăng nhập Google, refresh token và logout.
- Điều hướng user đã đăng nhập ra khỏi trang login.
- Hồ sơ cá nhân, sửa hồ sơ, đổi avatar, đổi mật khẩu và đổi username theo giới hạn nghiệp vụ.
- Trang công khai `/users/{username}`.
- Danh sách danh mục và sản phẩm công khai.
- Trang `/products` có tìm kiếm, lọc, phân trang, lọc giá đã validate và định dạng tiền.
- Trang `/categories/dich-vu` lấy riêng sản phẩm `PRE_ORDER`.
- Trang chi tiết sản phẩm có biến thể, mô tả, đánh giá thật và sản phẩm liên quan.
- Số sao trung bình lấy từ review thật; sản phẩm chưa có đánh giá hiển thị mặc định 5 sao theo quyết định hiện tại.
- Tên và avatar người bán ở dữ liệu công khai đã được đồng bộ theo danh tính gian hàng; avatar gian hàng dùng avatar của owner.
- Giỏ hàng có thêm, cộng dồn, sửa số lượng, xóa mục, xóa toàn bộ và checkout toàn bộ.
- Giỏ hàng/checkout hỗ trợ cả `INSTANT` và `PRE_ORDER`, đồng thời nhận thông tin buyer gửi shop cho đơn đặt trước.
- Checkout tự nhóm theo shop và delivery type.
- Trang lịch sử đơn mua dùng dữ liệu database thật, có tìm kiếm/lọc và phân trang không đếm tổng theo hướng tránh COUNT/OFFSET sâu.
- URL chi tiết đơn buyer đã chuyển sang `/orders/{orderCode}` và service kiểm tra ownership.
- Tải tài sản số dạng TXT cho đơn giao ngay đã mua.
- Buyer có thể tạo, xem, chuyển admin, xác nhận bảo hành và tự rút khiếu nại theo state machine.
- Ví buyer hiển thị số dư thật, lịch sử biến động số dư và lịch sử nạp tiền thật.
- Trang nạp tiền đã dùng VietQR + SePay Bank Webhook: QR 15 phút, polling trạng thái,
  HMAC raw body, chống lặp và chỉ cộng ví sau khi đối chiếu đúng tài khoản/số tiền/thời gian.
- Trang đăng ký seller `/seller-register` đã kết nối backend.
- Trang liên hệ và trang 404 đã có giao diện; form liên hệ hiện vẫn là mock.

### 4.2. Luồng đăng ký và vận hành shop

Luồng hiện tại:

```text
BUYER gửi đăng ký
  -> shop PENDING
  -> admin duyệt ACTIVE
  -> user đổi từ BUYER sang SELLER
  -> tên hiển thị user đồng bộ với tên shop
```

Quy tắc đã triển khai:

- Chỉ BUYER được gửi đăng ký shop.
- Gửi đơn chưa làm user thành SELLER.
- Admin chỉ cấp SELLER khi chuyển shop từ `PENDING` sang `ACTIVE`.
- `REJECTED` là trạng thái kết thúc, không được gửi lại đơn.
- `BANNED` ẩn shop và sản phẩm công khai; admin có thể chuyển lại `ACTIVE`.
- ADMIN/SUPER_ADMIN không được mở shop hay bán hàng.
- Có `version` để chống hai admin duyệt cùng một hồ sơ.
- Hồ sơ đăng ký đã có `contact_info` và `application_reason`.
- Tên shop được kiểm tra trùng; sau khi duyệt, tên nhận diện seller/shop bị khóa theo nghiệp vụ hiện tại.
- Ảnh gian hàng sử dụng avatar của tài khoản owner, không duy trì một ảnh đại diện độc lập khác.

Trạng thái shop đã được rút gọn còn:

```text
PENDING | ACTIVE | REJECTED | BANNED
```

### 4.3. Sản phẩm và tồn kho

- Admin quản lý danh mục qua backend; seller chỉ chọn danh mục đã tồn tại.
- Seller có API tạo, sửa, xóa sản phẩm.
- Mỗi sản phẩm dùng một ảnh đại diện; variant không cần ảnh riêng.
- Có variant và ràng buộc chống variant trùng.
- Có hai delivery type: `INSTANT` và `PRE_ORDER`.
- `INSTANT` quản lý kho digital asset và giao tự động.
- `PRE_ORDER` lưu cấu hình thời gian xử lý và nội dung buyer gửi shop.
- Danh sách sản phẩm công khai chỉ lấy shop/user hợp lệ và sản phẩm được phép hiển thị.
- Sản phẩm mới nhất ở trang chủ gọi API thật, sắp xếp theo `createdAt DESC`; không dùng mock.

### 4.4. Checkout, đơn hàng và tiền

- Thanh toán bằng số dư ví.
- Có idempotency cho checkout.
- Có kiểm tra và khóa dữ liệu quan trọng để hạn chế checkout đồng thời làm âm kho hoặc trừ tiền hai lần.
- `INSTANT`: lấy asset, tạo snapshot giao hàng, chuyển tiền vào trạng thái giữ.
- `PRE_ORDER`: trừ tiền ngay, seller nhận/từ chối/hoàn thành; quá hạn chưa nhận được scheduler hủy và hoàn tiền.
- Buyer có thể hủy PRE_ORDER trước khi shop tiếp nhận theo điều kiện service.
- Seller có thể nhận, từ chối, hoàn thành hoặc hủy đơn thuộc shop của mình.
- Order code thật được sinh ở backend và dùng thống nhất trong thông báo/URL buyer.
- Dòng tiền buyer và tài chính seller đã được tách thành hai API/view khác nhau.
- Có fee ledger, cấu hình phí và cơ chế giữ tiền T+7.
- Scheduler nhả tiền, hủy đơn quá hạn và xử lý deadline dispute chạy lại sau khi ứng dụng khởi động; công việc dựa vào trạng thái/deadline lưu trong database, không chỉ dựa vào timer trong RAM.

### 4.5. Dispute/bảo hành/tranh chấp

State machine chính đã có:

```text
HOLDING
  -> COMPLAINED
      -> buyer rút: CLOSED / BUYER_WITHDREW -> tiếp tục thời gian giữ còn lại
      -> seller nhận: WARRANTY_IN_PROGRESS
          -> seller báo xong: WAITING_BUYER_CONFIRMATION
              -> buyer đồng ý: CLOSED / BUYER_ACCEPTED_WARRANTY
              -> buyer từ chối: DISPUTED -> admin xử lý
              -> buyer quá hạn: CLOSED / BUYER_CONFIRMATION_TIMEOUT
          -> seller quá hạn bảo hành: BUYER_WIN -> REFUNDED
      -> seller từ chối hoặc buyer escalate: DISPUTED -> admin xử lý
      -> seller không phản hồi 24h: BUYER_WIN -> REFUNDED
```

Đã có:

- Mỗi order item chỉ được mở khiếu nại một lần trong thời gian giữ tiền.
- Deadline seller phản hồi 24 giờ.
- Deadline seller bảo hành 24 giờ.
- Deadline buyer xác nhận 24 giờ.
- Buyer thắng được hoàn 100% theo logic hiện tại và fee bị hủy.
- Seller thắng đưa tiền về luồng HOLDING còn lại.
- Có phân biệt `closedReason` cho CLOSED.
- Resolve dùng khóa/kiểm tra trạng thái để chống xử lý hai lần.
- Có test concurrency cho xử lý dispute.

### 4.6. Giao diện và trải nghiệm đã bổ sung

- Header dùng avatar thật, username và role thật.
- Menu user theo role; nút mở shop/quản trị dư thừa ngoài header đã được dọn.
- Role badge được phân biệt màu.
- Seller shell/dashboard, sidebar, wallet, withdrawal và dispute đã có giao diện.
- Success/Error/Confirm modal đã được áp dụng cho nhiều thao tác quan trọng.
- Trang nạp tiền, biến động số dư, lịch sử đơn, chi tiết đơn và trang dịch vụ đã có.
- Trang 404 dùng lại header/footer của dự án.

### 4.7. Thay đổi nổi bật từ 26/08 đến 04/09

Theo lịch sử commit của hai repository:

- 26/08: bổ sung model/luồng dispute và cập nhật trang chủ/schema.
- 27/08: thêm lịch sử đơn mua.
- 28/08: thêm bộ lọc đơn, bỏ COUNT tổng và OFFSET sâu; cập nhật holding/dispute.
- 03/09: thêm biến động số dư thật; tách ví buyer và tài chính seller.
- 04/09: thêm trang dịch vụ PRE_ORDER; chuyển chi tiết đơn sang order code; thêm đăng ký shop; đồng bộ tên và avatar gian hàng.

---

## 5. API hiện có

Source hiện có **25 controller và 90 mapping method**. Bảng dưới đây liệt kê toàn bộ nhóm API đã triển khai ở mức route.

### 5.1. Auth — 5 API

| Method | Endpoint | Chức năng |
|---|---|---|
| POST | `/api/v1/auth/register` | Đăng ký buyer |
| POST | `/api/v1/auth/login` | Đăng nhập email/username |
| POST | `/api/v1/auth/refresh-token` | Đổi refresh cookie lấy access token mới |
| POST | `/api/v1/auth/logout` | Thu hồi refresh token, xóa cookie |
| POST | `/api/v1/auth/google` | Đăng nhập Google |

### 5.2. User và profile — 7 API

| Method | Endpoint |
|---|---|
| GET | `/api/v1/users/{username}` |
| POST | `/api/v1/users/me/change-password` |
| GET | `/api/v1/users/levels` |
| PUT | `/api/v1/users/me/username` |
| GET | `/api/v1/users/me` |
| PUT | `/api/v1/users/me` |
| PATCH | `/api/v1/users/me/avatar` |

### 5.3. Shop — 7 API

| Method | Endpoint | Quyền/chức năng |
|---|---|---|
| GET | `/api/v1/shops` | Danh sách shop active công khai |
| GET | `/api/v1/shops/{slug}` | Chi tiết shop công khai |
| GET | `/api/v1/shops/me/application` | Trạng thái đơn đăng ký của user hiện tại |
| POST | `/api/v1/shops` | BUYER gửi đăng ký seller |
| PUT | `/api/v1/shops/{id}` | SELLER sửa shop theo ownership |
| GET | `/api/v1/shops/admin/all` | Admin xem danh sách shop |
| PATCH | `/api/v1/shops/admin/{shopId}/status` | Admin duyệt/từ chối/ban/unban |

### 5.4. Category — 5 API

- `GET /api/v1/categories`
- `GET /api/v1/categories/{slug}`
- `POST /api/v1/categories`
- `PUT /api/v1/categories/{id}`
- `DELETE /api/v1/categories/{id}`

Ba API thay đổi dữ liệu dành cho ADMIN/SUPER_ADMIN.

### 5.5. Product, variant, asset, PRE_ORDER và review — 17 API

Public/catalog:

- `GET /api/v1/products`
- `POST /api/v1/products/search`
- `GET /api/v1/products/slug/{slug}`
- `GET /api/v1/products/shop/{shopId}`
- `GET /api/v1/products/{productId}/variants`
- `GET /api/v1/product-reviews/product/{productId}`
- `POST /api/v1/product-reviews`

Seller:

- `POST /api/v1/seller/products`
- `PUT /api/v1/seller/products/{productId}`
- `DELETE /api/v1/seller/products/{productId}`
- `POST /api/v1/seller/products/assets/inventory`
- `POST /api/v1/seller/product-variants`
- `PUT /api/v1/seller/product-variants/{variantId}`
- `GET /api/v1/seller/digital-assets/variant/{variantId}`
- `DELETE /api/v1/seller/digital-assets/{assetId}`
- `POST /api/v1/seller/pre-order-configs`
- `GET /api/v1/seller/pre-order-configs/product/{productId}`

### 5.6. Cart — 6 API

- `GET /api/v1/cart`
- `POST /api/v1/cart/items`
- `PUT /api/v1/cart/items/{itemId}`
- `DELETE /api/v1/cart/items/{itemId}`
- `DELETE /api/v1/cart`
- `POST /api/v1/cart/checkout`

### 5.7. Checkout và order — 11 API

Buyer:

- `POST /api/v1/checkout`
- `GET /api/v1/orders`
- `GET /api/v1/orders/{orderCode}`
- `GET /api/v1/orders/{orderCode}/assets`
- `POST /api/v1/orders/{orderCode}/cancel`

Seller:

- `GET /api/v1/seller/orders`
- `GET /api/v1/seller/orders/{id}`
- `POST /api/v1/seller/orders/{id}/accept`
- `POST /api/v1/seller/orders/{id}/reject`
- `POST /api/v1/seller/orders/{id}/complete`
- `POST /api/v1/seller/orders/{id}/cancel`

### 5.8. Wallet, deposit và withdrawal — 9 API

- `GET /api/v1/wallet`
- `GET /api/v1/wallet/transactions`
- `GET /api/v1/seller/wallet/transactions`
- `GET /api/v1/wallet/deposits`
- `POST /api/v1/wallet/deposits`
- `GET /api/v1/wallet/deposits/{transactionCode}`
- `POST /api/v1/payments/sepay/webhook`
- `POST /api/v1/wallet/withdraw`
- `PUT /api/v1/admin/withdrawals/{id}/process`

### 5.9. Fee — 10 API

Admin:

- `GET /api/v1/admin/fee-configs`
- `GET /api/v1/admin/fee-configs/active`
- `POST /api/v1/admin/fee-configs`
- `PUT /api/v1/admin/fee-configs/change-rate`
- `GET /api/v1/admin/fee-configs/ledgers`
- `GET /api/v1/admin/fee-configs/ledgers/{ledgerId}`
- `GET /api/v1/admin/fee-configs/summaries`

Seller:

- `GET /api/v1/seller/fees`
- `GET /api/v1/seller/fees/summary`
- `GET /api/v1/seller/fees/{ledgerId}`

### 5.10. Dispute — 14 API

Buyer:

- `POST /api/v1/orders/{orderCode}/items/{itemId}/complain`
- `POST /api/v1/disputes/{disputeId}/escalate`
- `POST /api/v1/disputes/{disputeId}/confirm-warranty`
- `POST /api/v1/disputes/{disputeId}/withdraw`
- `GET /api/v1/disputes/{disputeId}`
- `GET /api/v1/disputes`

Seller:

- `POST /api/v1/seller/orders/{orderId}/items/{itemId}/warranty-start`
- `POST /api/v1/seller/orders/{orderId}/items/{itemId}/warranty-complete`
- `POST /api/v1/seller/orders/{orderId}/items/{itemId}/dispute`
- `GET /api/v1/seller/disputes`
- `GET /api/v1/seller/disputes/{disputeId}`

Admin:

- `GET /api/v1/admin/disputes`
- `GET /api/v1/admin/disputes/{disputeId}`
- `POST /api/v1/admin/disputes/{disputeId}/resolve`

---

## 6. Các trang frontend hiện có

### Buyer/public

- `/`
- `/login`, `/register`
- `/products`, `/products/[slug]`
- `/categories/dich-vu`
- `/cart`
- `/orders`, `/orders/[orderCode]`
- `/orders/[orderCode]/items/[itemId]/complain`
- `/disputes`, `/disputes/[id]`
- `/wallet/deposit`, `/wallet/transactions`
- `/profile`, `/profile/edit`, `/profile/change-password`
- `/users/[username]`
- `/seller-register`
- `/contact`
- Trang 404 qua `src/app/not-found.tsx`

### Seller

- `/seller`
- `/seller/wallet`
- `/seller/wallet/withdraw`
- `/seller/disputes`
- `/seller/disputes/[id]`

### Admin

- `/admin`
- `/admin/disputes`
- `/admin/disputes/[id]`

---

## 7. Phần còn thiếu hoặc chưa hoàn chỉnh

### P0 — Trạng thái sau baseline 05/09/2026

Đã hoàn thành và được ghi nhận trong `Baseline kiểm thử 05.09.2026.md`:

1. **Đã chuẩn hóa URL API** cho checkout, upload inventory và fee về `/api/v1/**`.
2. **Đã chuẩn hóa dispute response/pagination và global error envelope.**
3. **Đã thêm OpenAPI/Swagger và contract test** để kiểm tra route chuẩn/route cũ.
4. **Đã sửa Maven Wrapper và thêm CI** cho backend/frontend; 47 test nền và 3 contract test mới đều xanh.

Việc còn mở: **chốt chiến lược schema/migration production.** `schema-v8.sql` hiện là full schema và có một số ALTER idempotent, nhưng chưa có version migration chính thức.

### P1 — Hoàn thiện admin MVP

Backend đã có một phần nhưng frontend còn thiếu:

- Dashboard admin với số user, shop, order, GMV, tiền giữ, dispute đang mở.
- Danh sách/chi tiết/duyệt/từ chối/ban/unban shop.
- Quản lý user: danh sách, tìm kiếm, khóa/mở khóa; backend hiện chưa có API đầy đủ.
- Quản lý danh mục; backend đã có CRUD nhưng chưa có trang admin.
- Quản lý yêu cầu rút tiền: backend mới có API xử lý một yêu cầu, chưa có list/detail đầy đủ.
- Quản lý fee config và fee ledger; backend đã có API nhưng chưa có UI.
- Audit log cho thao tác admin liên quan tiền, shop và tài khoản.
- Super Admin thêm/sửa/khóa admin: để sau MVP nhưng phải ghi rõ phạm vi.

### P1 — Hoàn thiện seller MVP

- Thay toàn bộ dashboard mock bằng API thật:
  - doanh thu từng ngày/tháng;
  - số đơn theo trạng thái;
  - số dư khả dụng/đang giữ;
  - sản phẩm bán chạy và đơn gần đây.
- Trang danh sách/tạo/sửa/ẩn sản phẩm.
- Trang quản lý variant, tồn kho digital asset và cấu hình PRE_ORDER.
- Trang danh sách/chi tiết đơn seller.
- UI nhận, từ chối, giao kết quả, hủy đơn PRE_ORDER.
- Hiển thị deadline còn lại rõ ràng và cảnh báo đơn sắp quá hạn.
- Lịch sử rút tiền seller.
- Bổ sung API lấy danh sách sản phẩm thuộc chính seller nếu API public theo shop chưa đủ cho trang quản trị.

### P1 — Hoàn thiện buyer và thanh toán

- Hoàn thiện forgot password, reset password và verify email. Security config đã whitelist route nhưng chưa có controller tương ứng.
- Chốt nghiệp vụ voucher: database có bảng nhưng Java module/API chưa được triển khai. Nếu chưa làm voucher ở MVP thì phải bỏ/ẩn ô voucher trên UI.
- Kết nối URL webhook public vào SePay Test Mode và smoke test giao dịch thật; code đã có
  HMAC, idempotency, chống duplicate, hết hạn 15 phút và trạng thái cần đối soát.
- Lịch sử withdrawal/deposit nên có trạng thái và trang chi tiết nhất quán.
- Chuẩn hóa modal thành công/lỗi/xác nhận cho mọi thao tác ghi dữ liệu.

### P2 — Module database đã có bảng nhưng code chưa hoàn chỉnh

Không được coi là “đã làm” chỉ vì schema có bảng. Các nhóm dưới đây còn thiếu module/backend/frontend tương ứng:

- Voucher và redemption/reservation.
- Chat conversation/message realtime.
- Notification và user notification preference.
- Shop report/moderation workflow.
- Audit log đầy đủ.
- Login security log và risk flag xử lý nghiệp vụ.
- Outbox/event processing.
- File/object storage abstraction.
- Contact/support ticket thật.

### P2 — Production readiness

- Tách cấu hình `local`, `test`, `staging`, `prod`; không dùng password/JWT secret mặc định ở production.
- Thêm rate limiting cho login, refresh, checkout, dispute, deposit và API public search.
- Bổ sung security headers, CSP, kiểm soát Origin/CSRF phù hợp với refresh cookie.
- Kiểm tra `email_verified` Google end-to-end và log sự kiện xác thực quan trọng.
- Lưu ảnh/file trên S3/MinIO/CDN; validate MIME, dung lượng và quyền truy cập.
- Log có cấu trúc và che token, secret, buyer input, delivery content.
- Metrics/alert cho lỗi thanh toán, scheduler, deadlock, queue/outbox và callback SePay.
- Backup PostgreSQL tự động và diễn tập restore.
- CI/CD, Docker, health/readiness probe và rollback.
- Kế hoạch tạo partition mới cho `wallet_transactions`; schema hiện có partition theo tháng và default partition nhưng chưa thấy job xoay partition tự động.

---

## 8. Dữ liệu mock còn tồn tại

Những vị trí được xác nhận vẫn là dữ liệu minh họa:

- Seller dashboard overview cards.
- Biểu đồ doanh thu seller (`createMockDailyRevenue`).
- Đơn hàng gần đây và thống kê trạng thái trên seller dashboard.
- Thông báo ở seller header.
- Form liên hệ chỉ giả lập gửi thành công.
- Một phần thông tin liên hệ/social trên trang contact là nội dung giao diện tĩnh.

Các phần quan trọng đã dùng dữ liệu thật:

- Sản phẩm mới nhất trang chủ.
- Danh sách/chi tiết sản phẩm, review và rating.
- Giỏ hàng và checkout.
- Lịch sử/chi tiết đơn buyer.
- Số dư và biến động ví.
- Nạp tiền và lịch sử nạp tiền.
- Dispute buyer/seller/admin.
- Hồ sơ user và hồ sơ đăng ký seller.

---

## 9. Rủi ro kỹ thuật cần theo dõi

| Rủi ro | Mức độ | Việc cần làm |
|---|---|---|
| API route/DTO không đồng nhất | Cao | Chuẩn hóa `/api/v1`, OpenAPI và contract test trước khi thêm màn hình mới. |
| Giao dịch tiền chạy đồng thời | Cao | Tiếp tục test checkout, refund, release, withdrawal và resolve bằng concurrent integration test trên PostgreSQL thật. |
| Scheduler dừng nhiều ngày | Cao | Test restart/catch-up với dữ liệu deadline quá hạn; đảm bảo batch lặp đến khi hết backlog. |
| Thiếu admin vận hành | Cao | Không thể launch marketplace khi chưa có user/shop/withdrawal moderation đầy đủ. |
| Dashboard seller đang mock | Trung bình | Tạo API aggregate tối ưu thay vì tải toàn bộ order về frontend để tính. |
| N+1 và tải dữ liệu lớn | Cao | Dùng projection/entity graph, keyset pagination, page-size cap và kiểm tra query plan. |
| Cấu hình secret mặc định | Cao | Bắt buộc env secret ở staging/prod và fail-fast nếu thiếu. |
| Chưa có frontend automated test | Cao | Thêm unit/component và Playwright cho các luồng tiền/quyền. |
| Schema full script, chưa có migration version | Trung bình | Dùng Flyway/Liquibase trước production; tuyệt đối không xóa database production để cập nhật schema. |
| File/ảnh phụ thuộc URL ngoài | Trung bình | Dùng object storage, upload policy và ảnh fallback. |

---

## 10. Thứ tự phát triển đề xuất và mốc ngày cụ thể

### Đợt 0 — Chốt nền tảng: 04/09–06/09/2026

Mục tiêu: không xây tiếp trên contract đang lệch.

- 04/09: chốt tài liệu tiến độ, inventory API/trang/schema.
- 05/09: sửa ba route bất nhất, chuẩn hóa response/error và cập nhật frontend service.
- 06/09: thêm OpenAPI, sửa Maven Wrapper/CI và chạy lại toàn bộ test.

Tiêu chí hoàn thành:

- Frontend lint/build xanh.
- Backend test xanh.
- Swagger hiển thị đúng API thực tế.
- Không còn route lặp `/products/products` hoặc `/checkout/checkout`.

### Đợt 1 — Admin vận hành tối thiểu: 07/09–13/09/2026

- 07–08/09: API + trang danh sách/duyệt/ban/unban shop.
- 09–10/09: API + trang quản lý user, tìm kiếm và khóa/mở khóa.
- 11/09: trang CRUD category.
- 12/09: list/detail/process withdrawal.
- 13/09: trang fee config/ledger và test phân quyền admin.

Tiêu chí hoàn thành: admin có thể vận hành toàn bộ vòng đời user, shop, danh mục, tiền rút, phí và dispute mà không cần chạy SQL thủ công.

### Đợt 2 — Seller vận hành thật: 14/09–21/09/2026

- 14–15/09: API dashboard aggregate/revenue thật.
- 16–17/09: danh sách, tạo, sửa, ẩn sản phẩm và variant.
- 18/09: quản lý digital asset và PRE_ORDER config.
- 19–20/09: danh sách/chi tiết và xử lý đơn seller.
- 21/09: deadline UI, withdrawal history và test ownership seller.

Tiêu chí hoàn thành: seller có thể từ đăng ký shop đến đăng sản phẩm, nhận đơn, giao hàng, xem tiền và rút tiền hoàn toàn qua UI.

### Đợt 3 — Khép kín buyer/payment: 22/09–28/09/2026

- 22/09: forgot/reset password và verify email.
- 23–24/09: SePay callback/IPN/idempotency/reconciliation.
- 25–26/09: quyết định làm voucher MVP hoặc ẩn hoàn toàn UI voucher; nếu làm thì hoàn thiện reservation/consume/release.
- 27/09: đồng bộ modal và trạng thái lỗi toàn bộ thao tác ghi.
- 28/09: test E2E buyer từ nạp tiền đến mua, nhận hàng, khiếu nại và hoàn tiền.

### Đợt 4 — Notification, file và support: 29/09–04/10/2026

- 29–30/09: notification lưu database + polling trước, chưa bắt buộc WebSocket.
- 01–02/10: upload ảnh qua S3/MinIO, validation và CDN URL.
- 03/10: contact/support ticket thật.
- 04/10: email thông báo cho các sự kiện quan trọng.

### Đợt 5 — Bảo mật và hiệu năng: 05/10–10/10/2026

- 05/10: rate limit và chống brute force.
- 06/10: production secrets, CORS/Origin, cookie và security headers.
- 07/10: audit log cho admin và dòng tiền.
- 08/10: audit N+1, projection, index và `EXPLAIN ANALYZE` các query nóng.
- 09/10: test tải lịch sử order/wallet lớn và pagination sâu.
- 10/10: test scheduler catch-up, batch, deadlock và retry sau downtime.

### Đợt 6 — Test hệ thống: 11/10–16/10/2026

- 11–12/10: Testcontainers cho PostgreSQL và integration test transaction.
- 13–14/10: Playwright cho BUYER/SELLER/ADMIN.
- 15/10: test concurrent checkout/refund/resolve/withdrawal.
- 16/10: test IDOR, role bypass, dữ liệu nhạy cảm và file upload.

### Đợt 7 — Triển khai staging: 17/10–20/10/2026

- 17/10: Docker/CI/CD và environment staging.
- 18/10: monitoring, log, alert và health check.
- 19/10: backup/restore database và rollback release.
- 20/10: smoke test staging với SePay sandbox.

### Đợt 8 — Release Candidate và phát hành: 21/10–26/10/2026

- 21–23/10: UAT đủ ba role, sửa lỗi P0/P1, đóng Release Candidate.
- 24–25/10: buffer và kiểm tra dữ liệu production.
- 26/10: phát hành MVP nếu checklist bên dưới đạt 100%.

### Sau MVP: 27/10–30/11/2026

- Super Admin quản lý tài khoản admin.
- Chat realtime/WebSocket và moderation chat.
- Voucher/marketing nâng cao.
- Shop report, fraud/risk rule và outbox event hoàn chỉnh.
- Quảng cáo, affiliate, đấu giá hoặc các module mở rộng khác sau khi chốt yêu cầu nghiệp vụ.

---

## 11. Checklist bắt buộc trước khi đưa lên production

### Nghiệp vụ

- [ ] Admin vận hành được user, shop, category, withdrawal, fee và dispute.
- [ ] Seller không còn màn hình/dữ liệu mock trong luồng chính.
- [ ] BUYER/SELLER/ADMIN nhìn thấy đúng menu và không gọi được API ngoài quyền.
- [ ] Tất cả API xem/sửa dữ liệu riêng đều có ownership test.
- [ ] Checkout, refund, hold release, fee và withdrawal đối soát được đến từng giao dịch.
- [ ] Không còn UI voucher nếu backend voucher chưa triển khai.

### Dữ liệu và đồng thời

- [ ] Concurrent checkout không bán trùng digital asset và không âm stock.
- [ ] Refresh rotation, resolve dispute, release tiền và withdrawal không xử lý hai lần.
- [ ] Scheduler bắt kịp deadline sau khi server tắt nhiều ngày.
- [ ] Migration chạy được trên database có dữ liệu, không yêu cầu xóa database.
- [ ] Backup và restore đã được diễn tập.

### Bảo mật

- [ ] Không có secret/password mặc định ở production.
- [ ] Rate limit cho auth và API tiền.
- [ ] Log không lộ token, secret, nội dung asset hoặc buyer input nhạy cảm.
- [ ] Google login chỉ nhận email đã xác minh.
- [ ] Test IDOR cho order, dispute, product, shop, wallet và asset.
- [ ] Upload file kiểm tra MIME, size và quyền sở hữu.

### Chất lượng và vận hành

- [ ] Backend unit/integration test xanh.
- [ ] Frontend lint, build và E2E xanh.
- [ ] Có dashboard log/metrics/alert.
- [ ] Có health/readiness probe.
- [ ] Có rollback release và runbook xử lý sự cố thanh toán.
- [ ] SePay Test Mode đã test webhook đúng/sai HMAC, webhook lặp, QR hết hạn và giao dịch cần đối soát.

---

## 12. Việc nên làm ngay tiếp theo

Thứ tự đề xuất từ ngày 05/09/2026:

1. Sửa contract API bất nhất và tạo OpenAPI.
2. Hoàn thiện admin shop/user/withdrawal trước, vì đây là điểm chặn vận hành lớn nhất.
3. Thay seller dashboard mock bằng API aggregate thật.
4. Xây trang seller quản lý sản phẩm và đơn hàng.
5. Chốt SePay và luồng đối soát tiền.
6. Sau khi ba role chạy khép kín mới triển khai notification, voucher/chat và tính năng mở rộng.

Không nên ưu tiên giao diện marketing mới hoặc module mở rộng trước khi admin và seller có thể vận hành luồng cốt lõi hoàn toàn bằng dữ liệu thật.

---

## 13. Ghi chú database tại mốc 4.9

`schema-v8.sql` đang có thay đổi chưa commit cho bảng `shops`:

- thêm `contact_info VARCHAR(255)`;
- thêm `application_reason VARCHAR(500)`;
- thêm `version BIGINT NOT NULL DEFAULT 0`;
- rút trạng thái shop còn `PENDING`, `ACTIVE`, `REJECTED`, `BANNED`;
- chuyển dữ liệu cũ `INACTIVE`, `SUSPENDED`, `CLOSED` về `BANNED`.

Không cần xóa toàn bộ database chỉ để nhận các thay đổi này nếu đang dùng database phát triển có dữ liệu. Cần chạy phần ALTER/UPDATE tương ứng hoặc dùng migration có version. Với production, nên giữ `ddl-auto: validate` và không dùng `ddl-auto: update` như một cơ chế migration chính.

---

## 14. Điều kiện của lịch dự kiến

Lịch trên chỉ giữ được nếu:

- phạm vi MVP không bổ sung module lớn mới giữa chừng;
- có tài khoản SePay sandbox/merchant, IPN secret và thông tin callback đúng;
- chốt sớm dịch vụ email, object storage, domain và máy chủ;
- một người làm tập trung 6–8 giờ/ngày;
- lỗi P0 phát hiện trong UAT được ưu tiên hơn thay đổi giao diện nhỏ.

Nếu chỉ phát triển bán thời gian 3–4 giờ/ngày, nên dời mốc MVP production từ **26/10/2026** sang khoảng **23/11/2026**.
