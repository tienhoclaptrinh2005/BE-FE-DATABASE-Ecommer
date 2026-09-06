# CommerceHub — Lộ trình nước rút hoàn thành dự án đến 15/09/2026

> Ngày bắt đầu: **05/09/2026**  
> Deadline cố định: **15/09/2026**  
> Thời gian còn lại: **11 ngày theo lịch**  
> Tài liệu nền: `Cập nhật tiến độ 4.9.md` và toàn bộ tài liệu trong thư mục `V2`.

## 1. Mục tiêu của đợt nước rút

Đến hết ngày **15/09/2026**, CommerceHub phải đạt trạng thái **MVP 1.0 có thể chạy thử nghiệm thật** với ba luồng khép kín:

```text
BUYER đăng ký/đăng nhập
  -> nạp tiền
  -> xem sản phẩm
  -> mua INSTANT hoặc đặt PRE_ORDER
  -> xem đơn
  -> nhận hàng/khiếu nại/hoàn tiền

BUYER đăng ký bán hàng
  -> ADMIN duyệt
  -> trở thành SELLER
  -> đăng sản phẩm
  -> nhận và xử lý đơn
  -> theo dõi doanh thu
  -> yêu cầu rút tiền

ADMIN đăng nhập
  -> quản lý user/shop/category
  -> xử lý withdrawal/fee/dispute
  -> khóa/mở khóa đối tượng vi phạm
  -> theo dõi số liệu vận hành chính
```

Đây là kế hoạch deadline cứng. Từ 05/09 đến 15/09 **không thêm yêu cầu giao diện hoặc module lớn ngoài danh sách trong tài liệu này**.

---

## 2. “Xong hết” được hiểu như thế nào

### Phải hoàn thành trước deadline

- Luồng BUYER, SELLER và ADMIN chạy khép kín bằng dữ liệu thật.
- Không còn mock data trong dashboard hoặc luồng nghiệp vụ chính.
- Backend và frontend dùng cùng URL, request, response và enum trạng thái.
- Các thao tác liên quan tiền, tồn kho, role và dispute có kiểm tra quyền sở hữu và chống xử lý hai lần.
- Database có script cập nhật an toàn, không bắt buộc xóa dữ liệu cũ.
- Frontend lint/build thành công.
- Backend unit/integration test quan trọng thành công.
- Có môi trường staging hoặc production chạy được, backup được và có smoke test.

### Không tính là điều kiện chặn MVP ngày 15/09

Các ý tưởng dưới đây là phần mở rộng sau bản 1.0, không thể làm an toàn cùng lúc trong 11 ngày nếu chỉ có một người phát triển:

- Chat realtime/WebSocket hoàn chỉnh.
- Đấu giá.
- Quảng cáo.
- Affiliate.
- Super Admin thêm/sửa/xóa tài khoản admin.
- Fraud/risk engine nâng cao.
- Hệ thống marketing và voucher nâng cao.

Nếu UI đang có nút cho tính năng chưa làm, phải **ẩn hoặc ghi “Sắp ra mắt”**, tuyệt đối không để mock data khiến người dùng hiểu nhầm là chức năng thật.

---

## 3. Nguyên tắc thực hiện trong 11 ngày

1. Mỗi ngày chỉ có một mục tiêu chính và một điều kiện nghiệm thu rõ ràng.
2. Backend contract làm trước, frontend gọi sau.
3. Không tính là hoàn thành nếu chỉ có giao diện nhưng chưa gọi API thật.
4. Không tính là hoàn thành nếu API có nhưng chưa kiểm tra role và ownership.
5. Mọi thay đổi database phải cập nhật vào `V2/schema-v8.sql` hoặc migration được chốt cho môi trường triển khai.
6. Sau 20:00 mỗi ngày chỉ sửa lỗi của phần vừa làm, không mở thêm module mới.
7. Từ tối 13/09 bắt đầu đóng băng tính năng; ngày 14–15/09 chỉ test và sửa lỗi.
8. Lỗi tiền, quyền, mất dữ liệu, bán trùng asset hoặc IDOR luôn là P0 và chặn phát hành.

---

## 4. Lịch trình chi tiết từng ngày

## Ngày 05/09/2026 — Chốt contract và làm sạch nền tảng

### Mục tiêu

Đưa backend/frontend/database về cùng một contract trước khi xây tiếp trang seller và admin.

### Công việc buổi sáng

- Tạo snapshot trạng thái hiện tại của backend, frontend và `schema-v8.sql`.
- Lập danh sách toàn bộ route đang được frontend gọi.
- Sửa các URL chưa nhất quán:
  - `/api/v1/seller/products/products/assets/inventory`;
  - `/api/v1/checkout/checkout`;
  - `/api/admin/**` và `/api/seller/**` chưa cùng chuẩn `/api/v1/**`.
- Chọn một response envelope thống nhất cho API thành công và lỗi.

### Công việc buổi chiều

- Thêm hoặc hoàn thiện OpenAPI/Swagger.
- Cập nhật toàn bộ frontend service theo contract mới.
- Sửa Maven Wrapper để chạy test ổn định trên Windows và CI.
- Kiểm tra các enum đang trùng hoặc thừa giữa Java, TypeScript và PostgreSQL.

### Công việc buổi tối

- Chạy backend test.
- Chạy `npm run lint` và `npm run build`.
- Ghi lại danh sách lỗi P0/P1 còn mở.

### Điều kiện hoàn thành ngày 05/09

- [x] Không còn URL bị lặp segment.
- [x] Swagger phản ánh đúng route thực tế.
- [x] Frontend không còn gọi route cũ.
- [x] Maven Wrapper chạy được.
- [x] Có baseline test/lint/build rõ ràng.

---

## Ngày 06/09/2026 — Hoàn thiện backend ADMIN

### Mục tiêu

Admin có đủ API để quản trị MVP, không cần thao tác SQL thủ công.

### Công việc

- Hoàn thiện API quản lý user:
  - danh sách có phân trang giới hạn;
  - tìm theo ID, username hoặc email;
  - lọc role/status;
  - khóa và mở khóa user;
  - không cho ADMIN thường khóa SUPER_ADMIN.
- Rà soát API shop:
  - list/filter `PENDING`, `ACTIVE`, `REJECTED`, `BANNED`;
  - duyệt shop đồng thời đổi BUYER thành SELLER;
  - từ chối là trạng thái kết thúc;
  - ban/unban shop đồng bộ khả năng hiển thị sản phẩm;
  - optimistic locking bằng `version`.
- Bổ sung API danh sách/chi tiết withdrawal cho admin.
- Rà soát CRUD category và fee config/ledger.
- Thêm audit log tối thiểu cho khóa user, đổi trạng thái shop, xử lý withdrawal và resolve dispute.

### Test bắt buộc

- Hai admin duyệt cùng một shop chỉ một request thành công.
- Duyệt `ACTIVE` tạo đúng role SELLER.
- REJECTED không gửi lại đăng ký.
- BANNED làm shop và sản phẩm biến mất khỏi public API.
- User thường không gọi được admin API.

### Điều kiện hoàn thành ngày 06/09

- [ ] Backend admin đủ cho shop, user, category, withdrawal, fee và dispute.
- [ ] Mọi list API có page-size cap.
- [ ] Mọi mutation admin có phân quyền và audit tối thiểu.

---

## Ngày 07/09/2026 — Hoàn thiện frontend ADMIN

### Mục tiêu

Admin vận hành được hệ thống bằng giao diện.

### Công việc

- Tạo layout/menu admin thống nhất.
- Tạo dashboard dùng dữ liệu thật:
  - số user;
  - số shop chờ duyệt;
  - số đơn theo trạng thái;
  - tiền đang giữ;
  - dispute và withdrawal đang chờ.
- Tạo trang quản lý shop và form duyệt/từ chối/ban/unban.
- Tạo trang quản lý user và thao tác khóa/mở khóa.
- Tạo trang CRUD category.
- Tạo trang danh sách/chi tiết/xử lý withdrawal.
- Tạo trang fee config và fee ledger.
- Giữ lại và tích hợp trang admin dispute hiện có vào menu mới.

### Quy tắc giao diện

- Mutation nguy hiểm phải có Confirm Modal.
- Thành công/thất bại phải dùng Success/Error Modal.
- Không dùng `alert()` và không hiển thị thông báo thô dưới form.
- Không tự tính tổng bằng cách tải toàn bộ dữ liệu về trình duyệt.

### Điều kiện hoàn thành ngày 07/09

- [ ] Admin xử lý được toàn bộ công việc MVP trên UI.
- [ ] Không có dữ liệu mock trong trang admin.
- [ ] Route guard hoạt động với BUYER, SELLER và ADMIN.

---

## Ngày 08/09/2026 — Hoàn thiện backend sản phẩm SELLER

### Mục tiêu

Seller có đủ API riêng để quản trị sản phẩm, variant, kho và PRE_ORDER.

### Công việc

- Thêm/chuẩn hóa API danh sách sản phẩm thuộc seller hiện tại.
- Tìm kiếm/lọc theo tên, category, trạng thái và delivery type.
- Rà soát API tạo/sửa/ẩn/xóa sản phẩm.
- Chỉ cho seller thao tác sản phẩm thuộc shop của mình.
- Rà soát unique constraint chống variant trùng.
- Rà soát upload/delete digital asset và chống asset trùng.
- Đồng bộ `stock_count` trong transaction.
- Hoàn thiện PRE_ORDER config và giới hạn buyer input 100 ký tự.
- Chỉ dùng một ảnh đại diện sản phẩm; variant không lưu ảnh riêng.
- Chuẩn hóa validation giá `0 <= price <= 500.000.000`.

### Test bắt buộc

- Seller A không sửa/xóa sản phẩm hoặc asset của Seller B.
- Hai request mua cùng asset không nhận cùng dữ liệu.
- Variant trùng bị từ chối ở service và database.
- Shop/user bị ban không thể tạo/sửa sản phẩm để public lại.

### Điều kiện hoàn thành ngày 08/09

- [ ] API seller product hoàn chỉnh và có ownership test.
- [ ] Stock/asset đúng khi chạy concurrent test.
- [ ] Swagger và TypeScript type đã cập nhật.

---

## Ngày 09/09/2026 — Hoàn thiện frontend sản phẩm SELLER

### Mục tiêu

Seller đăng và quản lý sản phẩm hoàn toàn trên UI.

### Công việc

- Trang danh sách sản phẩm seller, tìm kiếm và lọc.
- Form tạo/sửa sản phẩm.
- Chọn category do admin tạo.
- Chọn `INSTANT` hoặc `PRE_ORDER`.
- Quản lý variant.
- Quản lý kho digital asset cho INSTANT.
- Cấu hình thời gian xử lý cho PRE_ORDER.
- Upload/chọn một ảnh đại diện sản phẩm.
- Xác nhận trước khi ẩn/xóa sản phẩm.
- Hiển thị lỗi validation backend đúng trường nhập liệu.

### Điều kiện hoàn thành ngày 09/09

- [ ] Seller tạo được sản phẩm INSTANT thật.
- [ ] Seller tạo được sản phẩm PRE_ORDER thật.
- [ ] Dữ liệu vừa tạo xuất hiện đúng ở trang public.
- [ ] Không còn nút seller product dẫn tới trang trống.

---

## Ngày 10/09/2026 — Hoàn thiện đơn hàng SELLER

### Mục tiêu

Seller xem và xử lý đúng mọi trạng thái đơn thuộc shop của mình.

### Công việc backend

- Chuẩn hóa seller order list/detail/filter/search.
- Cân nhắc dùng `orderCode` ở response/UI; ID nội bộ không được dùng để bỏ qua ownership.
- Kiểm tra transaction cho nhận, từ chối, giao kết quả và hủy PRE_ORDER.
- Quá hạn shop chưa nhận: scheduler hủy và hoàn tiền.
- Quá hạn bảo hành 24 giờ: buyer thắng và hoàn 100%.
- Mọi chuyển trạng thái phải tạo status log.

### Công việc frontend

- Trang danh sách đơn seller.
- Tìm theo order code, lọc ngày/trạng thái/delivery type.
- Trang chi tiết đơn.
- Nút nhận, từ chối, giao kết quả và hủy theo đúng trạng thái.
- Hiển thị nội dung buyer gửi shop.
- Hiển thị deadline còn lại và cảnh báo sắp quá hạn.
- Liên kết đúng tới hồ sơ buyer nếu nghiệp vụ cho phép.

### Điều kiện hoàn thành ngày 10/09

- [ ] Seller xử lý được PRE_ORDER từ PENDING đến hoàn thành.
- [ ] Seller không xem/xử lý đơn của shop khác.
- [ ] Đơn quá hạn hiển thị đúng `CANCELLED_BY_SYSTEM` và hoàn tiền đúng.

---

## Ngày 11/09/2026 — Dashboard, ví và tài chính SELLER dùng dữ liệu thật

### Mục tiêu

Xóa toàn bộ mock data khỏi seller dashboard.

### Công việc

- Tạo API aggregate cho seller dashboard:
  - doanh thu từng ngày;
  - khoảng ngày 1–15 và 16–cuối tháng;
  - chuyển tháng/năm;
  - số đơn theo trạng thái;
  - số dư khả dụng;
  - tiền đang giữ;
  - tổng đã rút;
  - đơn gần đây;
  - sản phẩm bán chạy.
- Không tải toàn bộ order lên frontend để tính biểu đồ.
- Thay `createMockDailyRevenue` bằng API thật.
- Hoàn thiện seller wallet transaction, withdrawal history và form rút tiền.
- Kiểm tra số dư được lấy đúng user/shop hiện tại.
- Ràng buộc không cho rút số tiền đang HOLDING.

### Điều kiện hoàn thành ngày 11/09

- [ ] Không còn chữ “Dữ liệu minh họa” trong luồng seller chính.
- [ ] Dashboard khớp với dữ liệu order/wallet trong database.
- [ ] Hai request rút tiền đồng thời không làm âm ví.

---

## Ngày 12/09/2026 — Khép kín BUYER, auth và SePay

### Mục tiêu

Buyer đi được toàn bộ hành trình mà không gặp route giả hoặc dữ liệu mock.

### Công việc auth

- Hoàn thiện forgot password, reset password và verify email hoặc tạm ẩn link nếu chưa dùng.
- Kiểm tra Google `email_verified`.
- Kiểm tra refresh token rotation đồng thời.
- F5 không đăng xuất khi refresh cookie còn hợp lệ.
- Sau khi admin duyệt seller, frontend tải lại profile/role ở request kế tiếp.

### Công việc buyer/payment

- Test lại products, services, product detail, cart và checkout.
- Kiểm tra hết kho phải hiển thị “Hết hàng”.
- Kiểm tra order code thống nhất từ modal thành công đến URL lịch sử đơn.
- Kiểm tra ownership của order, asset và dispute.
- Hoàn thiện SePay checkout/callback/IPN/idempotency.
- Lịch sử nạp tiền và biến động số dư phải khớp wallet transaction.
- Chốt voucher:
  - nếu đủ thời gian thì triển khai end-to-end;
  - nếu không thì ẩn hoàn toàn ô voucher ở MVP.
- Form contact: kết nối API support tối thiểu hoặc ghi rõ kênh liên hệ; không giả lập gửi thành công.

### Điều kiện hoàn thành ngày 12/09

- [ ] Buyer nạp tiền sandbox và mua được đơn thật.
- [ ] Refresh/login/logout hoạt động đúng.
- [ ] Buyer không xem được đơn/asset/dispute của người khác.
- [ ] Không còn thành phần mock gây hiểu nhầm trong buyer flow.

---

## Ngày 13/09/2026 — Bảo mật, hiệu năng, database và scheduler

### Mục tiêu

Đóng băng tính năng vào cuối ngày và loại bỏ lỗi có thể gây mất tiền hoặc sập hệ thống.

### Công việc bảo mật

- Rate limit login, refresh, checkout, deposit, dispute và search public.
- Kiểm tra lại role ở controller và ownership ở service.
- Test IDOR cho user, shop, product, order, asset, wallet và dispute.
- Không log access token, refresh token, password, digital asset hoặc buyer input nhạy cảm.
- Cấu hình production bắt buộc dùng environment secret.
- Kiểm tra CORS, Origin, cookie Secure/HttpOnly/SameSite và security headers.

### Công việc hiệu năng/database

- Kiểm tra N+1 bằng query log và test dữ liệu lớn.
- Dùng projection/entity graph cho query nóng.
- Kiểm tra index cho order code, user/shop status, order history, wallet transaction, dispute deadline và scheduler.
- Test pagination lịch sử đơn/ví ở vị trí sâu mà không COUNT toàn bảng hoặc OFFSET không giới hạn.
- Cập nhật `schema-v8.sql` theo entity cuối cùng.
- Chuẩn bị script ALTER/migration chạy được trên database có dữ liệu.
- Không dùng `ddl-auto: update` ở production; giữ `validate` sau migration.

### Công việc scheduler

- Test server dừng nhiều ngày rồi chạy lại.
- Scheduler phải quét được đơn/dispute/hold đã quá deadline.
- Batch phải lặp qua backlog mà không tải toàn bộ dữ liệu vào RAM.
- Test nhiều instance với ShedLock.

### Điều kiện hoàn thành ngày 13/09

- [ ] Không còn lỗ hổng P0 đã biết.
- [ ] Schema và entity khớp.
- [ ] Scheduler catch-up thành công.
- [ ] Từ 20:00 đóng băng tính năng.

---

## Ngày 14/09/2026 — Full test, staging và UAT

### Mục tiêu

Chỉ kiểm thử và sửa lỗi; không thêm chức năng mới.

### Bộ dữ liệu UAT phải có

- Một BUYER active có số dư.
- Một SELLER active có shop và avatar.
- Một ADMIN.
- Sản phẩm INSTANT còn hàng, hết hàng và PRE_ORDER.
- Đơn INSTANT thành công.
- PRE_ORDER pending, processing, completed và quá hạn.
- Dispute ở từng trạng thái chính.
- Withdrawal pending/approved/rejected.

### Kịch bản UAT bắt buộc

1. Đăng ký/login/refresh/logout.
2. Buyer đăng ký shop, admin duyệt, role thành SELLER.
3. Seller tạo hai loại sản phẩm.
4. Buyer thêm giỏ và checkout nhiều shop.
5. Giao INSTANT không trùng asset.
6. Seller nhận và hoàn thành PRE_ORDER.
7. Hủy/quá hạn đơn và hoàn tiền.
8. Khiếu nại, bảo hành, buyer rút, admin resolve buyer/seller win.
9. Hold release T+7 và tính fee.
10. Seller yêu cầu rút, admin xử lý.
11. Ban/unban user/shop và kiểm tra public visibility.
12. F5 ở mọi role không làm mất phiên khi refresh token còn hạn.

### Kiểm tra kỹ thuật

- Backend test suite.
- Frontend lint và production build.
- E2E cho ba role.
- Concurrent checkout/refund/resolve/withdrawal.
- SePay IPN đúng, sai secret và gửi lặp.
- Smoke test staging.

### Điều kiện hoàn thành ngày 14/09

- [ ] Không còn lỗi P0.
- [ ] Lỗi P1 còn lại có phương án sửa trong ngày 15/09.
- [ ] Database backup và restore thử thành công.
- [ ] Có bản release candidate cố định.

---

## Ngày 15/09/2026 — Sửa lỗi cuối, phát hành và nghiệm thu

### 06:00–10:00

- Sửa các lỗi P1 còn lại từ UAT.
- Chạy lại test có liên quan sau mỗi thay đổi.
- Không refactor lớn và không thay schema ngoài lỗi chặn phát hành.

### 10:00–13:00

- Chạy toàn bộ backend test.
- Chạy frontend lint, build và E2E.
- Tạo database backup trước deploy.
- Kiểm tra environment variable production.

### 13:00–16:00

- Deploy backend, frontend và database migration.
- Chạy smoke test production bằng tài khoản test.
- Kiểm tra callback SePay, cookie, CORS, domain và HTTPS.

### 16:00–19:00

- Kiểm tra log/metrics/scheduler.
- Đối soát một giao dịch test từ nạp tiền đến hold/release/refund.
- Kiểm tra rollback và restore point.

### 19:00–21:00

- Chốt tài liệu API, database và hướng dẫn vận hành.
- Ghi danh sách hạn chế đã biết.
- Tag phiên bản `v1.0.0` nếu mọi release gate đều đạt.

### Điều kiện tuyên bố hoàn thành

- [ ] Ba luồng BUYER–SELLER–ADMIN chạy khép kín.
- [ ] Không còn mock trong luồng chính.
- [ ] Không còn lỗi P0/P1 mở.
- [ ] Test/lint/build/E2E xanh.
- [ ] Backup, restore và rollback sẵn sàng.
- [ ] Production smoke test thành công.

Nếu còn lỗi liên quan tiền, quyền, mất dữ liệu, asset trùng hoặc database migration, **không được tuyên bố hoàn thành chỉ để kịp ngày**; phải rollback và ghi rõ blocker.

---

## 5. Bảng theo dõi tiến độ hằng ngày

| Ngày | Kết quả bắt buộc | Trạng thái | Lỗi P0 | Lỗi P1 | Ghi chú |
|---|---|---|---:|---:|---|
| 05/09 | Contract/OpenAPI/test baseline | ✅ Hoàn thành | 0 | 0 | 50/50 backend test, frontend lint/build xanh; xem `Baseline kiểm thử 05.09.2026.md`. |
| 06/09 | Backend admin | ⬜ Chưa làm | 0 | 0 | |
| 07/09 | Frontend admin | ⬜ Chưa làm | 0 | 0 | |
| 08/09 | Backend seller product | ⬜ Chưa làm | 0 | 0 | |
| 09/09 | Frontend seller product | ⬜ Chưa làm | 0 | 0 | |
| 10/09 | Seller order end-to-end | ⬜ Chưa làm | 0 | 0 | |
| 11/09 | Dashboard/wallet seller thật | ⬜ Chưa làm | 0 | 0 | |
| 12/09 | Buyer/auth/SePay | ⬜ Chưa làm | 0 | 0 | |
| 13/09 | Security/performance/database | ⬜ Chưa làm | 0 | 0 | |
| 14/09 | Full test/staging/UAT | ⬜ Chưa làm | 0 | 0 | |
| 15/09 | Release/production/sign-off | ⬜ Chưa làm | 0 | 0 | |

Quy ước trạng thái:

- `⬜ Chưa làm`
- `🟡 Đang làm`
- `🟠 Có blocker`
- `✅ Hoàn thành`

Mỗi cuối ngày phải cập nhật bảng này dựa trên kết quả chạy thật, không cập nhật theo cảm giác.

---

## 6. Quy tắc xử lý khi chậm tiến độ

Nếu chậm quá một ngày:

1. Không cắt các phần liên quan tiền, role, ownership, transaction, database và backup.
2. Không chuyển dữ liệu thật về mock để kịp giao diện.
3. Ưu tiên ẩn chức năng chưa hoàn chỉnh thay vì để nút/API hoạt động một nửa.
4. Cắt theo thứ tự:
   - contact ticket thật;
   - notification realtime, thay bằng polling hoặc email;
   - voucher, ẩn UI;
   - dashboard biểu đồ nâng cao, giữ số liệu chính;
   - tính năng trang trí và animation.
5. Ngày 14–15/09 không được lấy thời gian test để bù cho tính năng mới.

---

## 7. Release gate ngày 15/09

### Gate 1 — Tiền và tồn kho

- [ ] Không âm ví.
- [ ] Không bán trùng digital asset.
- [ ] Không trừ hoặc hoàn tiền hai lần.
- [ ] Fee và hold ledger đối soát được.
- [ ] Withdrawal concurrent an toàn.

### Gate 2 — Quyền và dữ liệu riêng tư

- [ ] BUYER không gọi được seller/admin API.
- [ ] SELLER không thao tác shop/sản phẩm/đơn của seller khác.
- [ ] ADMIN không được bán hàng.
- [ ] User không xem được order, asset, wallet hoặc dispute của người khác.
- [ ] SUPER_ADMIN kế thừa ADMIN nhưng phần quản lý admin được để sau MVP.

### Gate 3 — Độ bền hệ thống

- [ ] Refresh token rotation an toàn.
- [ ] Scheduler bắt kịp sau downtime.
- [ ] Job theo batch và không tải toàn bộ bảng vào RAM.
- [ ] API list có page-size cap.
- [ ] Query nóng không có N+1 nghiêm trọng.

### Gate 4 — Triển khai

- [ ] Không còn secret mặc định.
- [ ] HTTPS/cookie/CORS đúng production.
- [ ] Migration chạy trên bản sao database thật.
- [ ] Có backup, restore và rollback.
- [ ] Log/metrics/alert hoạt động.

Chỉ phát hành khi cả bốn gate đạt.

---

## 8. Ước lượng thời gian và điều kiện để giữ deadline

Kế hoạch này cần khoảng **90–110 giờ làm việc tập trung trong 11 ngày**, tương đương 8–10 giờ/ngày. Deadline 15/09 chỉ khả thi khi:

- khóa phạm vi ngay từ 05/09;
- ưu tiên nghiệp vụ trước tinh chỉnh giao diện;
- không thêm module lớn mới;
- có sẵn PostgreSQL, SePay sandbox, domain/SSL và môi trường deploy;
- mọi ngày đều đạt điều kiện nghiệm thu trước khi chuyển sang ngày tiếp theo.

Nếu chỉ làm 3–4 giờ/ngày, deadline an toàn cần dời thêm ít nhất 2–3 tuần. Việc giữ ngày 15/09 trong trường hợp đó chỉ có thể thực hiện bằng cách giảm phạm vi MVP, không được giảm test cho dòng tiền và phân quyền.

---

## 9. Việc cần bắt đầu ngay hôm nay

Thứ tự thực hiện ngày 05/09:

1. Sửa Maven Wrapper và tạo baseline test.
2. Chốt URL API v1 và response envelope.
3. Sửa các route bị lặp.
4. Sinh OpenAPI.
5. Cập nhật frontend service.
6. Chạy backend test, frontend lint/build.
7. Chỉ khi baseline xanh mới bắt đầu backend admin ngày 06/09.
