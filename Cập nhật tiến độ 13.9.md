# CommerceHub — Cập nhật tiến độ và kế hoạch nước rút ngày 13/09/2026

> Ngày lập: **13/09/2026**  
> Deadline mục tiêu: **15/09/2026**  
> Mục tiêu thực tế: hoàn thành **CommerceHub MVP/Release Candidate có thể demo end-to-end để đưa vào hồ sơ xin thực tập**.  
> Trạng thái: **giai đoạn nước rút — đóng phạm vi, ưu tiên tính đúng và khả năng demo hơn số lượng tính năng**.

---

## 1. Kết luận nhanh

CommerceHub đã vượt qua giai đoạn dựng khung. Phần lõi BUYER và SELLER hiện đã có nhiều luồng dùng dữ liệu thật: đăng nhập, Google login, profile, đăng ký seller, sản phẩm, kho digital asset, hai loại đơn, ví, SePay, phí sàn, khiếu nại, dashboard seller và notification badge.

Baseline mới nhất ngày 13/09/2026:

| Hạng mục | Kết quả |
|---|---|
| Backend full test | **PASS — 115/115**, 0 failure, 0 error, 0 skipped |
| Frontend lint | **PASS** |
| Frontend production build | **PASS** |
| Route được Next.js build | **33 route** |
| OpenAPI/Swagger | Đã có |
| CI backend/frontend | Đã có workflow; cần xác nhận trên GitHub sau khi push |

Điểm nghẽn không còn nằm ở seller product hoặc seller order. Bốn điểm chặn release hiện tại là:

1. **Admin MVP chưa hoàn chỉnh**, hiện frontend admin chủ yếu mới có dispute.
2. **Chưa có UAT end-to-end đủ ba role** trên một bộ dữ liệu cố định.
3. **SePay Test Mode, R2, CORS, domain và webhook chưa được smoke test trọn luồng trên môi trường public.**
4. **Migration, backup/restore và deploy chưa được chốt thành quy trình phát hành lặp lại được.**

Ước lượng ở thời điểm 13/09:

| Khu vực | Mức sẵn sàng MVP ước lượng | Nhận định |
|---|---:|---|
| Backend nghiệp vụ lõi | 85–90% | Nhiều test quan trọng đã có; admin/audit/migration còn thiếu |
| Buyer frontend | 85% | Luồng chính đã có; cần UAT, xử lý lỗi và SePay public smoke test |
| Seller frontend | 85–90% | Dashboard, product, inventory, order, dispute, fee đã có dữ liệu thật |
| Admin frontend | 20–30% | Dispute có; shop/user/category/withdrawal/fee còn thiếu UI vận hành |
| Production readiness | 40–50% | Có env/R2/CI/OpenAPI nhưng chưa deploy, backup/restore, monitoring và UAT |
| Tổng thể để demo xin thực tập | **khoảng 80%** | Có thể về đích nếu đóng băng tính năng ngay |

Các tỷ lệ trên là ước lượng quản lý tiến độ, không thay thế checklist nghiệm thu ở cuối tài liệu.

---

## 2. Những phần đã hoàn thành đến 13/09/2026

### 2.1. Nền tảng và contract

- Chuẩn hóa route API về `/api/v1/**`.
- Loại bỏ route lặp `/products/products` và `/checkout/checkout`.
- Chuẩn hóa `ApiResponse`, `PageResponse` và global error handler.
- Không trả trực tiếp cấu trúc `PageImpl` không ổn định cho frontend.
- Thêm OpenAPI/Swagger và contract test.
- Sửa Maven Wrapper và thêm CI cho backend/frontend.
- Frontend đã đồng bộ service với contract mới.

### 2.2. Auth, user và seller identity

- Đăng ký, đăng nhập, refresh token, logout.
- Google login và lưu URL avatar Google vào database.
- Upload avatar cá nhân lên R2, chuẩn hóa WebP và validation kích thước/dung lượng.
- Frontend có fallback ảnh và xử lý avatar Google không gửi referrer.
- Username chỉ đổi một lần.
- Đăng ký seller lưu `contact_info`, `application_reason` và dùng optimistic locking `version`.
- Shop chỉ nhận role SELLER sau khi admin duyệt `ACTIVE`.
- Backend đã có logic đồng bộ `users.full_name = shops.name` khi duyệt shop qua API.
- Có script sửa dữ liệu seller cũ đã ACTIVE nhưng tên profile chưa khớp tên shop.

Việc cần làm ngay: chạy `commercehub-backend/sql/2026-09-sync-approved-shop-identities.sql` trên database local, đăng nhập lại và xác nhận `tienmmoshop` hiển thị cùng một tên ở header, profile và shop.

### 2.3. Public/buyer

- Trang chủ dùng sản phẩm mới và sản phẩm bán chạy từ API thật.
- Có quy trình mua hàng, danh sách người bán, chính sách bảo hành và điều khoản sử dụng.
- Có trang 404 dùng layout đầu/cuối trang chung.
- Danh sách sản phẩm, danh mục dịch vụ và chi tiết sản phẩm.
- Hiển thị tên shop và avatar seller thay cho username tại khu vực mua hàng.
- Rating sản phẩm/shop có `rating_avg`, `rating_count` và fallback “Mới/Chưa có đánh giá”.
- Giỏ hàng, checkout, lịch sử đơn và chi tiết đơn.
- Hai loại giao hàng thống nhất:
  - `INSTANT` → **Giao ngay**;
  - `PRE_ORDER` → **Đặt hàng**.
- Buyer tạo khiếu nại, theo dõi bảo hành, xác nhận kết quả hoặc rút khiếu nại.

### 2.4. Seller product và inventory

- Dashboard seller dùng dữ liệu thật, biểu đồ đủ số ngày của tháng và có bộ lọc tháng.
- Danh sách sản phẩm đúng shop hiện tại; tìm kiếm, lọc, phân trang.
- Tạo sản phẩm Giao ngay hoặc Đặt hàng.
- Chỉnh sửa sản phẩm với dữ liệu cũ.
- Quản lý tối đa số biến thể theo policy hiện tại.
- Quản lý kho digital asset theo biến thể:
  - nhập từng dòng;
  - kéo/thêm file TXT;
  - xem danh sách;
  - tải xuống;
  - xóa asset khả dụng;
  - chống nhập và bán trùng tài khoản.
- Upload ảnh sản phẩm trực tiếp lên Cloudflare R2.
- Backend kiểm tra ảnh 4:3, kích thước, dung lượng, WebP, metadata và lifecycle ảnh cũ.

### 2.5. Seller order, fee và notification

- Có ba màn hình:
  - tất cả đơn hàng;
  - đơn Giao ngay;
  - đơn Đặt hàng.
- Có danh sách, bộ lọc, tìm theo mã đơn và trang chi tiết.
- Đơn Giao ngay hiển thị nội dung tài khoản đã bán trong phạm vi đúng quyền.
- Đơn Đặt hàng hỗ trợ nhận, từ chối, hoàn thành và hủy theo trạng thái.
- Thời hạn shop nhận đơn: **24 giờ**.
- Thời hạn hoàn thành sau khi nhận: **24 giờ**.
- Scheduler hủy đơn quá hạn và hoàn tiền buyer.
- Chuẩn hóa vòng đời order, payment, hold, dispute và cancellation reason.
- Hiển thị mã đơn, tên sản phẩm và biến thể trong order/dispute/fee.
- Trang phí sàn seller lấy cấu hình phí admin đặt từ backend.
- Badge thông báo dùng số liệu thật cho Giao ngay, Đặt hàng và Khiếu nại.
- Badge hỗ trợ trạng thái đã đọc và hiển thị `1` đến `9+`.
- Có ghi chú seller khi đã hoàn tất bảo hành nhưng buyer chưa xác nhận.

### 2.6. Wallet, SePay và dòng tiền

- Đã thay luồng nạp tiền VNPay bằng SePay/VietQR.
- Buyer tạo `Deposit PENDING`, nhận mã giao dịch và QR có thời hạn 15 phút.
- SePay webhook xác minh request, chống xử lý trùng và đối chiếu giao dịch.
- Giao dịch hợp lệ chuyển deposit sang `SUCCESS`, tạo wallet transaction và cộng số dư đúng user.
- Có giới hạn tạo QR để tránh spam và không tạo nhiều deposit còn hiệu lực.
- Có wallet balance, wallet transaction và seller withdrawal flow nền tảng.
- Có hold T+7, refund, buyer/seller dispute resolution và chống xử lý hai lần tại các điểm quan trọng.

### 2.7. Chất lượng hiện tại

- Backend có **115 test** đang xanh, gồm các test liên quan:
  - OpenAPI contract;
  - checkout idempotency/concurrency;
  - order ownership;
  - deadline order;
  - dispute và resolve concurrency;
  - digital asset;
  - seller dashboard;
  - SePay webhook/deposit;
  - hold release;
  - R2 config, rate limit, WebP và image lifecycle;
  - shop approval và seller identity.
- Frontend lint và TypeScript production build đang xanh.
- Những log ERROR/WARN được tạo có chủ đích trong test scheduler/R2 failure-path không phải test thất bại; suite kết thúc `BUILD SUCCESS`.

---

## 3. Việc còn thiếu — xếp theo mức độ chặn release

## P0 — Phải xử lý trước khi tuyên bố MVP hoàn thành

### P0.1. Chốt seller identity và migration local

- Chạy script đồng bộ tên seller đã ACTIVE.
- Kiểm tra role chỉ có SELLER, không giữ đồng thời BUYER/ADMIN sai policy.
- Kiểm tra header cập nhật sau refresh/login lại.
- Commit migration và test đang còn thay đổi trong backend.
- Bảo đảm admin sau này duyệt qua API, không sửa trực tiếp nhiều bảng trong database.

### P0.2. Admin MVP

Frontend admin hiện chưa đủ để vận hành sàn. Tối thiểu phải có:

1. Danh sách hồ sơ shop, lọc trạng thái.
2. Duyệt/từ chối/ban/unban shop bằng API.
3. Duyệt shop phải đồng bộ role SELLER và tên profile/tên shop.
4. Danh sách user, tìm kiếm, khóa/mở khóa và bảo vệ SUPER_ADMIN.
5. CRUD category cơ bản.
6. Danh sách/chi tiết/xử lý withdrawal.
7. Xem và đổi cấu hình phí sàn.
8. Trang dispute admin hiện có phải nằm trong menu admin thống nhất.

Nếu backend của mục nào chưa có list/detail thì phải bổ sung API trước, sau đó frontend mới gọi. Không tính giao diện tĩnh là hoàn thành.

### P0.3. UAT ba role và dòng tiền

- BUYER: login → nạp tiền → mua Giao ngay → nhận asset → khiếu nại.
- BUYER: đặt hàng → shop nhận → hoàn thành → buyer xác nhận.
- SELLER: đăng ký → admin duyệt → tạo sản phẩm → thêm kho → bán → xem phí/tiền.
- ADMIN: duyệt shop → xử lý dispute → xử lý withdrawal → khóa đối tượng vi phạm.
- Test hủy/quá hạn phải hoàn đúng tiền.
- Test webhook lặp không cộng ví hai lần.
- Test hai buyer không nhận cùng digital asset.
- Test seller/buyer không xem được đơn, ví, asset và dispute của người khác.

### P0.4. Release/deploy

- Chốt môi trường staging/production.
- Khai báo secrets ngoài Git.
- Chạy migration trên database đích, sau đó `ddl-auto=validate`.
- Backup database trước migration; thử restore ít nhất một lần.
- Cấu hình HTTPS, CORS, refresh cookie và domain frontend/backend.
- Kiểm tra custom domain R2 và CORS cho bucket.
- Cấu hình URL webhook SePay public.
- Có health check, log cơ bản và rollback version trước.

## P1 — Nên hoàn thiện ngay sau Release Candidate

- Forgot password, reset password và verify email.
- Contact/support ticket thật; hiện form contact vẫn mô phỏng submit.
- Notification chung cho buyer/admin; seller badge hiện mới là notification nghiệp vụ tối thiểu.
- Audit log đầy đủ cho thao tác admin và dòng tiền.
- Frontend automated E2E bằng Playwright.
- Rate limit dùng Redis khi chạy nhiều backend instance.
- Flyway/Liquibase thay cho các script migration chạy thủ công.
- Monitoring/metrics/alert cho webhook, refund, scheduler và lỗi R2.
- Email thông báo các sự kiện quan trọng.

## P2 — Đóng băng, không làm trước deadline

- Chat realtime/WebSocket hoàn chỉnh.
- Voucher/marketing nâng cao.
- Quảng cáo, affiliate, đấu giá.
- Fraud engine nâng cao, Kafka, outbox tổng quát.
- Chức năng “Sắp có” trong sidebar/profile.
- Làm lại giao diện chỉ vì thẩm mỹ khi không ảnh hưởng luồng demo.

Nếu một chức năng P2 đang có nút nhưng chưa hoạt động, hãy ẩn hoặc ghi rõ “Sắp ra mắt”; không dùng mock data để giả hoàn thành.

---

## 4. Lộ trình tăng tốc từ tối 13/09 đến 15/09

Kế hoạch này chỉ khả thi nếu **không nhận thêm tính năng ngoài P0**. Mỗi khối công việc phải kết thúc bằng test, commit và ghi lỗi còn mở.

## Tối 13/09 — Đóng phạm vi và dọn đường cho admin

### 19:00–20:00 — Chốt trạng thái an toàn

- [ ] Backup database local.
- [ ] Chạy migration đồng bộ seller identity.
- [ ] Kiểm tra `tienmmoshop`: role, shop status, full name, header và profile.
- [ ] Commit migration/test đang treo.
- [ ] Tạo một nhánh/release checklist duy nhất; không trộn refactor ngoài phạm vi.

### 20:00–22:00 — Admin shop end-to-end

- [ ] Chốt API list/filter/status shop.
- [ ] Làm trang admin danh sách hồ sơ shop.
- [ ] Confirm modal trước duyệt/từ chối/ban/unban.
- [ ] Sau duyệt, kiểm tra SELLER role và tên đồng bộ.
- [ ] Test quyền ADMIN/SUPER_ADMIN và optimistic locking.

### 22:00–23:30 — Inventory admin còn thiếu

- [ ] Liệt kê chính xác API thiếu cho user/category/withdrawal/fee.
- [ ] Viết contract request/response trước khi làm UI.
- [ ] Không bắt đầu module chat/voucher/email.
- [ ] Chạy test liên quan và commit admin shop.

### Gate kết thúc 13/09

- Không còn dữ liệu seller ACTIVE lệch tên.
- Admin duyệt shop được bằng UI hoặc tối thiểu API đã có test đầy đủ và UI đang là việc đầu tiên sáng 14/09.
- Backend test liên quan xanh; frontend lint/build không bị phá.
- Có danh sách P0 duy nhất, không thêm ý tưởng mới.

## Ngày 14/09 — Hoàn thiện admin, sau đó UAT

### 06:30–09:30 — Admin user và category

- [ ] Backend list/search/filter/lock/unlock user nếu còn thiếu.
- [ ] Không cho ADMIN thường khóa SUPER_ADMIN.
- [ ] Frontend danh sách user và thao tác khóa/mở khóa.
- [ ] Frontend CRUD category tối thiểu.
- [ ] Test role và validation.

### 09:45–12:30 — Admin withdrawal và fee

- [ ] Bổ sung list/detail withdrawal nếu backend còn thiếu.
- [ ] UI duyệt/từ chối withdrawal với confirm modal.
- [ ] Chống xử lý withdrawal hai lần.
- [ ] UI xem/đổi cấu hình phí và xem ledger cơ bản.
- [ ] Không cho tạo hai cấu hình phí ACTIVE.

### 13:30–15:00 — Chốt admin navigation

- [ ] Menu admin: Tổng quan, Shop, User, Danh mục, Rút tiền, Phí sàn, Khiếu nại.
- [ ] Route guard đầy đủ.
- [ ] Không có mock data trong admin.
- [ ] Ẩn chức năng chưa làm.

### 15:15–18:30 — UAT BUYER và SELLER

- [ ] Google login/avatar/profile.
- [ ] Seller registration → admin approval → seller session refresh.
- [ ] Tạo sản phẩm Giao ngay, upload ảnh R2, tạo biến thể, thêm kho TXT.
- [ ] Buyer mua và nhận đúng một asset.
- [ ] Tạo/nhận/hoàn thành đơn Đặt hàng.
- [ ] Kiểm tra badge, deadline, phí và doanh thu.

### 19:30–22:30 — UAT tiền, dispute và scheduler

- [ ] SePay Test Mode: QR, webhook đúng, sai chữ ký và webhook lặp.
- [ ] Hủy đơn trước/sau nhận và kiểm tra refund.
- [ ] Khiếu nại/bảo hành/buyer win/seller win.
- [ ] Giả lập deadline quá hạn cho order/dispute/hold.
- [ ] Ghi tất cả lỗi thành P0, P1 hoặc P2; sửa P0 trước.

### 22:30–23:15 — Baseline Release Candidate

- [ ] Chạy toàn bộ backend test.
- [ ] Chạy frontend lint/build.
- [ ] Commit/tag tạm `rc-1` nếu không còn P0.
- [ ] Backup database và ghi migration đã chạy.

### Gate kết thúc 14/09

- Ba role chạy được luồng chính bằng UI và dữ liệu thật.
- Không còn lỗi P0 đã biết.
- Lỗi P1 còn lại có chủ sở hữu và thời gian sửa sáng 15/09.
- Có Release Candidate cố định; không thêm tính năng.

## Ngày 15/09 — Deploy, smoke test và hoàn thiện hồ sơ xin thực tập

### 06:30–09:30 — Sửa P1 chặn demo

- [ ] Chỉ sửa lỗi từ UAT.
- [ ] Mỗi lỗi có test hồi quy hoặc checklist tái hiện.
- [ ] Không refactor kiến trúc lớn.

### 09:45–12:00 — Chuẩn bị phát hành

- [ ] Kiểm tra `.env` production và secret không nằm trong Git.
- [ ] Backup database.
- [ ] Chạy migration với `ON_ERROR_STOP`.
- [ ] Build backend/frontend bản release.
- [ ] Ghi lệnh rollback và phiên bản trước.

### 13:00–15:30 — Deploy/staging

- [ ] Deploy backend, frontend và database.
- [ ] Cấu hình domain, HTTPS, CORS, cookie và SePay webhook.
- [ ] Kiểm tra R2 public URL/upload CORS.
- [ ] Kiểm tra Swagger chỉ bật theo chính sách môi trường.

### 15:45–18:00 — Production smoke test

- [ ] Login thường và Google.
- [ ] Admin duyệt shop.
- [ ] Seller tạo sản phẩm và thêm kho.
- [ ] Buyer nạp tiền test, mua Giao ngay và đặt hàng.
- [ ] Refund/dispute/fee/wallet cập nhật đúng.
- [ ] Scheduler và log không phát sinh lỗi chặn.

### 18:30–21:00 — Chốt phiên bản để xin thực tập

- [ ] Chạy lại backend 115+ test, frontend lint/build.
- [ ] Cập nhật README: bài toán, kiến trúc, stack, cách chạy, env example.
- [ ] Chuẩn bị 6–10 ảnh chụp luồng BUYER/SELLER/ADMIN.
- [ ] Quay demo 3–5 phút: đăng nhập → duyệt shop → đăng sản phẩm → mua → xử lý đơn.
- [ ] Viết mục “Điểm kỹ thuật nổi bật”: idempotency, concurrency, ownership, SePay webhook, R2, scheduler, hold/refund.
- [ ] Ghi rõ hạn chế đã biết, không tuyên bố tính năng chưa làm.
- [ ] Tag `v1.0.0-rc1` hoặc `v1.0.0` tùy kết quả release gate.

---

## 5. Quy tắc tăng ca để không tạo thêm lỗi

Nước rút không có nghĩa là làm liên tục đến mất khả năng kiểm tra. Dự án có dòng tiền, quyền và dữ liệu số nên một lỗi do thiếu ngủ có thể tốn nhiều giờ sửa hơn thời gian tiết kiệm được.

Quy tắc đề xuất:

1. Làm theo block **75–90 phút**, nghỉ 10–15 phút.
2. Sau tối đa 3 block phải ăn/uống và rời màn hình ít nhất 30 phút.
3. Không code nghiệp vụ tiền/quyền sau thời điểm đã quá mệt; buổi muộn chỉ nên test, ghi tài liệu và sửa lỗi nhỏ.
4. Giữ ít nhất 6,5–7 giờ ngủ trong hai đêm 13–14/09.
5. Mỗi tính năng phải đi theo lát cắt: contract → backend → test → frontend → UAT → commit.
6. Không gom một commit chứa admin, payment, schema và giao diện không liên quan.
7. Nếu một việc vượt quá timebox 2 giờ, dừng để xác định blocker; không tiếp tục mò không giới hạn.
8. Không giảm test cho checkout, refund, withdrawal, role, ownership và migration để đổi lấy việc kịp ngày.

---

## 6. Bảng điều hành P0/P1 trong nước rút

| ID | Công việc | Mức | Deadline | Trạng thái 13/09 |
|---|---|---|---|---|
| P0-01 | Chạy migration đồng bộ seller identity | P0 | 13/09 20:00 | Chưa chạy |
| P0-02 | Admin duyệt/từ chối/ban/unban shop trên UI | P0 | 13/09 23:30 | Backend có, frontend thiếu |
| P0-03 | Admin quản lý user/category | P0 | 14/09 09:30 | Chưa đủ end-to-end |
| P0-04 | Admin xử lý withdrawal/fee | P0 | 14/09 12:30 | Backend một phần, frontend thiếu |
| P0-05 | UAT BUYER–SELLER–ADMIN | P0 | 14/09 22:30 | Chưa chạy đầy đủ |
| P0-06 | SePay/R2 public smoke test | P0 | 14/09 22:30 | Code có, external E2E chưa chốt |
| P0-07 | Backup/restore/migration/deploy | P0 | 15/09 15:30 | Chưa nghiệm thu |
| P0-08 | Production smoke test | P0 | 15/09 18:00 | Chưa chạy |
| P1-01 | Forgot/reset/verify email | P1 | Sau RC | Chưa làm |
| P1-02 | Contact/support thật | P1 | Sau RC | Đang mock |
| P1-03 | Playwright E2E tự động | P1 | Sau RC | Chưa có baseline |
| P1-04 | Audit log/monitoring đầy đủ | P1 | Sau RC | Chưa hoàn chỉnh |

Cập nhật bảng này sau mỗi block. Không để trạng thái “đang làm” quá một ngày mà không có blocker cụ thể.

---

## 7. Release gate — khi nào được gọi là hoàn thành

## Gate A — Nghiệp vụ

- [ ] BUYER mua được Giao ngay và nhận đúng asset.
- [ ] BUYER đặt hàng; SELLER nhận và hoàn thành được.
- [ ] Admin duyệt shop làm role/tên đồng bộ.
- [ ] Dispute và bảo hành đi hết vòng đời.
- [ ] Seller xem đúng doanh thu, phí, số dư và đơn của shop mình.
- [ ] Không còn mock data trong luồng demo chính.

## Gate B — Tiền và dữ liệu

- [ ] Webhook lặp không cộng ví hai lần.
- [ ] Hủy/quá hạn hoàn đúng số tiền.
- [ ] Không bán trùng digital asset.
- [ ] Hold/release/refund/fee có wallet transaction đối soát được.
- [ ] Withdrawal không làm âm số dư và không xử lý hai lần.
- [ ] Migration chạy được trên database có dữ liệu.

## Gate C — Quyền và bảo mật

- [ ] BUYER/SELLER/ADMIN không gọi được API ngoài quyền.
- [ ] Ownership đúng cho product, asset, order, wallet và dispute.
- [ ] Secret/token/password không có trong Git hoặc log.
- [ ] Cookie/CORS/HTTPS hoạt động trên domain triển khai.
- [ ] Upload kiểm tra MIME, size, kích thước và ownership.

## Gate D — Chất lượng và vận hành

- [ ] Backend full test xanh.
- [ ] Frontend lint/build xanh.
- [ ] UAT đủ ba role xanh.
- [ ] Backup và restore đã thử.
- [ ] Có rollback procedure.
- [ ] Smoke test môi trường public thành công.

Chỉ tag `v1.0.0` khi bốn gate đạt. Nếu còn lỗi P0, chỉ được tag Release Candidate và ghi blocker; không được đánh đổi an toàn dòng tiền để có chữ “hoàn thành”.

---

## 8. Tiêu chí hoàn thành để đưa vào hồ sơ xin thực tập

Ngoài việc chạy được, repository cần giúp nhà tuyển dụng hiểu giá trị kỹ thuật trong vài phút:

- README có ảnh, kiến trúc và hướng dẫn chạy rõ ràng.
- `.env.example` đủ biến nhưng không chứa secret thật.
- Commit dễ đọc, không có file tạm hoặc dữ liệu nhạy cảm.
- Swagger hoặc danh sách API có thể truy cập ở môi trường demo phù hợp.
- Có tài khoản demo cho BUYER, SELLER và ADMIN nhưng không dùng mật khẩu production.
- Có video demo 3–5 phút và kịch bản ngắn.
- Nêu rõ những vấn đề đã giải quyết:
  - marketplace sản phẩm số;
  - giao asset không trùng;
  - transaction/idempotency;
  - SePay webhook;
  - R2 image upload;
  - seller dashboard dữ liệu thật;
  - dispute, hold T+7, refund và scheduler deadline;
  - role/ownership và optimistic locking.
- Có mục “Known limitations / Next steps” thể hiện khả năng đánh giá phạm vi, không che giấu phần chưa làm.

---

## 9. Lệnh baseline dùng trong nước rút

Backend trên PowerShell:

```powershell
cd D:\LuuCode1\Project\commercehub-backend
$env:MAVEN_OPTS='-Dmaven.repo.local=C:\Users\acer\.m2\repository'
.\mvnw.cmd test
Remove-Item Env:MAVEN_OPTS
```

Frontend:

```powershell
cd D:\LuuCode1\Project\commercehub-frontend
npm run lint
npm run build
```

Kiểm tra thay đổi trước commit:

```powershell
git status --short
git diff --check
```

Không chạy `git reset --hard`, không xóa database để cập nhật schema và không commit `.env` chứa secret.

---

## 10. Quyết định phạm vi cuối cùng

Từ thời điểm lập tài liệu này đến khi có Release Candidate:

- **Được làm:** lỗi P0, admin MVP, UAT, migration, deploy, test, tài liệu demo.
- **Chỉ làm nếu còn thời gian:** lỗi P1 ảnh hưởng trực tiếp buổi demo.
- **Không làm:** chat, voucher, quảng cáo, affiliate, đấu giá, redesign và module mở rộng.

Mốc sớm nhất có thể tuyên bố **“CommerceHub MVP sẵn sàng demo xin thực tập”** là tối **15/09/2026**, với điều kiện không còn P0 và bốn release gate đạt. Mốc production dùng giao dịch thật chỉ được chốt sau khi SePay, backup/restore, bảo mật domain và vận hành được kiểm chứng đầy đủ.

Từ giờ, thành công không được đo bằng số màn hình mới. Thành công được đo bằng việc một nhà tuyển dụng có thể mở dự án, xem demo ba role, đọc code, chạy test và thấy hệ thống xử lý đúng dữ liệu thật.
