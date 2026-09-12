-- ============================================================
-- COMMERCEHUB — SCHEMA v8 (FILE DUY NHẤT)
-- ============================================================
-- Nguồn: schema DB live + tài liệu v8 + quyết định nghiệp vụ đã chốt.
--
-- QUYẾT ĐỊNH:
--   [DEL] favorite_shops — không còn shop/sản phẩm yêu thích
--   [ADD] carts + cart_items — giỏ hàng (1 user = 1 cart)
--   [DEL] Waive phí sàn — KHÔNG có status WAIVED / total_waived / waived_at
--   [FEE] Mặc định 4% (0.0400), làm tròn CEILING đồng nguyên
--   [PAY] Mua hàng luôn trừ WALLET (nạp trước — mua sau)
--   [PRE] PRE_ORDER trừ ví NGAY lúc checkout (không chờ shop accept)
--   [HOLD] 1 OrderItem = 1 HoldRelease = 1 FeeLedger
--   [SHOP] 1 User = 1 Shop; level giới hạn số sản phẩm (allowed_product_count)
--   [IMG] 1 Product = 1 ảnh tại products.thumbnail_url; variant không có ảnh riêng.
--         Ảnh R2 mới lưu object key (shops/{shopId}/products/...), backend ghép
--         MEDIA_PUBLIC_BASE_URL khi trả response để đổi domain không phải UPDATE DB.
--         URL tuyệt đối cũ vẫn được backend đọc tương thích.
--   [VIS] Sản phẩm công khai chỉ khi Product + Shop + chủ Shop cùng ACTIVE;
--         ban/unban không ghi đè status riêng của từng Product
--   [VAR] Tên variant duy nhất trong từng Product sau khi TRIM và bỏ phân biệt hoa/thường
--   [IDEM] Một checkout = một idempotency_keys; nhiều orders cùng tham chiếu checkout_request_id
--   [DLV] Nội dung giao khách thống nhất tên delivery_content:
--         INSTANT   : import TXT, 1 dòng = 1 asset → digital_assets.delivery_content;
--                     khi giao SNAPSHOT nguyên văn vào asset_delivery_logs.delivery_content_snapshot
--                     → buyer xem lại TỪ SNAPSHOT, không đọc lại kho
--         PRE_ORDER : shop nhập account/key/tin nhắn → pre_order_items.delivery_content
--                     (+ delivery_content_type ACCOUNT|KEY|MESSAGE|OTHER)
--         seller_notes = ghi chú NỘI BỘ của shop, KHÔNG dùng để giao hàng
--   [INV] SHA-256 content_hash duy nhất toàn sàn. Với ACCOUNT, định danh là username
--         trước dấu | (không phân biệt hoa/thường), nên đổi password vẫn không thể bán lần hai.
--         Loại khác dùng cả dòng; bản ghi SOLD được giữ lại để chặn nhập lại.
--
-- Cách dùng:
--   psql -h localhost -p 5678 -U postgres -d commercehub_db -f schema-v8.sql
--   File idempotent — chạy lại an toàn, KHÔNG mất dữ liệu wallet_transactions
--   (bảng cũ chưa partition được ĐỔI TÊN thành wallet_transactions_legacy đúng 1 lần,
--    dữ liệu giữ nguyên — không DROP; đối soát xong tự DROP bảng legacy thủ công).
-- ============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- MODULE 1: AUTH & USER
-- ============================================================

CREATE TABLE IF NOT EXISTS roles (
    id          BIGSERIAL    PRIMARY KEY,
    name        VARCHAR(50)  NOT NULL UNIQUE,
    description VARCHAR(255),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS level_configs (
    level                 INT           PRIMARY KEY,
    label                 VARCHAR(50)   NOT NULL,
    min_spent             NUMERIC(18,2) NOT NULL DEFAULT 0,
    allowed_product_count INT           NOT NULL DEFAULT 0,
    description           VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS users (
    id                 BIGSERIAL     PRIMARY KEY,
    email              VARCHAR(255)  NOT NULL UNIQUE,
    phone              VARCHAR(20)   UNIQUE,
    username           VARCHAR(100)  UNIQUE,
    username_changed_at TIMESTAMPTZ,
    password_hash      VARCHAR(255)  NOT NULL,
    full_name          VARCHAR(255)  NOT NULL,
    avatar_url         VARCHAR(500),
    status             VARCHAR(30)   NOT NULL DEFAULT 'ACTIVE'
                           CHECK (status IN ('ACTIVE','BANNED','SUSPENDED')),
    ban_reason         TEXT,
    last_active_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    user_level         INT           NOT NULL DEFAULT 1 REFERENCES level_configs(level),
    accumulated_spent  NUMERIC(18,2) NOT NULL DEFAULT 0,
    accumulated_earned NUMERIC(18,2) NOT NULL DEFAULT 0,
    is_email_verified  BOOLEAN       NOT NULL DEFAULT FALSE,
    is_phone_verified  BOOLEAN       NOT NULL DEFAULT FALSE,
    provider           VARCHAR(30),
    created_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_roles (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id),
    CONSTRAINT uq_user_roles_one_role_per_user UNIQUE (user_id)
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id         BIGSERIAL   PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      TEXT        NOT NULL UNIQUE,
    device_id  VARCHAR(255),
    ip_address VARCHAR(45),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked    BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id) WHERE revoked = FALSE;

CREATE TABLE IF NOT EXISTS email_verification_tokens (
    id         BIGSERIAL   PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      TEXT        NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used       BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id         BIGSERIAL   PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      TEXT        NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used       BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- MODULE 2: WALLET & MONEY FLOW
-- ============================================================

CREATE TABLE IF NOT EXISTS wallets (
    id                BIGSERIAL     PRIMARY KEY,
    user_id           BIGINT        UNIQUE REFERENCES users(id),
    available_balance NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (available_balance >= 0),
    hold_balance      NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (hold_balance >= 0),
    status            VARCHAR(30)   NOT NULL DEFAULT 'ACTIVE'
                          CHECK (status IN ('ACTIVE','LOCKED','FROZEN')),
    is_platform       BOOLEAN       NOT NULL DEFAULT FALSE,
    version           BIGINT        NOT NULL DEFAULT 0,
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_one_platform_wallet ON wallets(is_platform) WHERE is_platform = TRUE;

CREATE TABLE IF NOT EXISTS deposits (
    id               BIGSERIAL     PRIMARY KEY,
    user_id          BIGINT        NOT NULL REFERENCES users(id),
    wallet_id        BIGINT        NOT NULL REFERENCES wallets(id),
    amount           NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    provider         VARCHAR(30)   NOT NULL CHECK (provider IN ('SEPAY','VNPAY','MOMO','ZALOPAY')),
    transaction_code VARCHAR(100)  UNIQUE,
    provider_transaction_id VARCHAR(100),
    idempotency_key  VARCHAR(100)  UNIQUE,
    status           VARCHAR(30)   NOT NULL DEFAULT 'PENDING'
                         CHECK (status IN ('PENDING','SUCCESS','FAILED','EXPIRED','REVIEW_REQUIRED')),
    expires_at       TIMESTAMPTZ   NOT NULL,
    paid_at          TIMESTAMPTZ,
    processed_at     TIMESTAMPTZ,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_deposits_user ON deposits(user_id, created_at DESC);

-- Nâng cấp database đã tồn tại từ VNPay sang SePay; giữ VNPAY để đọc lịch sử cũ.
ALTER TABLE deposits
    ADD COLUMN IF NOT EXISTS provider_transaction_id VARCHAR(100);
ALTER TABLE deposits
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
ALTER TABLE deposits
    ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;
ALTER TABLE deposits
    DROP CONSTRAINT IF EXISTS deposits_status_check;

-- QR SePay chỉ có hiệu lực 15 phút. Dữ liệu cũ được suy ra từ created_at,
-- các mã PENDING đã quá hạn được đóng lại nhưng không xóa lịch sử.
UPDATE deposits
SET expires_at = created_at + INTERVAL '15 minutes'
WHERE expires_at IS NULL;

UPDATE deposits
SET status = 'EXPIRED', processed_at = COALESCE(processed_at, NOW())
WHERE status = 'PENDING' AND expires_at <= NOW();

-- Nếu dữ liệu cũ từng tạo nhiều PENDING cho cùng user, chỉ giữ mã mới nhất.
WITH duplicate_pending AS (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC, id DESC) AS row_number
    FROM deposits
    WHERE status = 'PENDING'
)
UPDATE deposits d
SET status = 'EXPIRED', processed_at = COALESCE(d.processed_at, NOW())
FROM duplicate_pending p
WHERE d.id = p.id AND p.row_number > 1;

ALTER TABLE deposits
    ALTER COLUMN expires_at SET NOT NULL;
ALTER TABLE deposits
    DROP CONSTRAINT IF EXISTS deposits_provider_check;
ALTER TABLE deposits
    ADD CONSTRAINT deposits_provider_check
        CHECK (provider IN ('SEPAY','VNPAY','MOMO','ZALOPAY'));
ALTER TABLE deposits
    ADD CONSTRAINT deposits_status_check
        CHECK (status IN ('PENDING','SUCCESS','FAILED','EXPIRED','REVIEW_REQUIRED'));
CREATE UNIQUE INDEX IF NOT EXISTS uq_deposits_provider_transaction
    ON deposits(provider_transaction_id)
    WHERE provider_transaction_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_deposits_one_pending_per_user
    ON deposits(user_id)
    WHERE status = 'PENDING';
CREATE INDEX IF NOT EXISTS idx_deposits_pending_expiry
    ON deposits(status, expires_at)
    WHERE status = 'PENDING';

CREATE TABLE IF NOT EXISTS withdrawals (
    id              BIGSERIAL     PRIMARY KEY,
    wallet_id       BIGINT        NOT NULL REFERENCES wallets(id),
    amount          NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    fee             NUMERIC(18,2) NOT NULL DEFAULT 0,
    bank_name       VARCHAR(100)  NOT NULL,
    account_number  VARCHAR(50)   NOT NULL,
    account_name    VARCHAR(100)  NOT NULL,
    idempotency_key VARCHAR(100)  UNIQUE,
    status          VARCHAR(30)   NOT NULL DEFAULT 'PENDING'
                        CHECK (status IN ('PENDING','APPROVED','REJECTED','DONE')),
    admin_note      TEXT,
    processor_id    BIGINT        REFERENCES users(id),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    processed_at    TIMESTAMPTZ,
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_withdrawals_status ON withdrawals(status, created_at DESC);

-- wallet_transactions (partitioned)
-- Migrate legacy đúng 1 lần: nếu bảng cũ tồn tại mà CHƯA partition thì ĐỔI TÊN thành
-- wallet_transactions_legacy (GIỮ NGUYÊN dữ liệu — KHÔNG drop lịch sử giao dịch),
-- kèm đổi tên index cũ để không đụng tên index của bảng partition mới.
-- Dữ liệu cũ KHÔNG tự copy sang bảng mới (khác cấu trúc/UUID) — đối soát xong,
-- tự chuyển những gì cần rồi DROP wallet_transactions_legacy thủ công.
-- Chạy lại file này sau đó sẽ KHÔNG đụng gì nữa (bảng chính đã là partition).
DO $$
DECLARE
    idx RECORD;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = current_schema()
          AND c.relname = 'wallet_transactions'
          AND c.relkind = 'r'   -- bảng thường (chưa partition)
    ) THEN
        IF EXISTS (
            SELECT 1
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = current_schema()
              AND c.relname = 'wallet_transactions_legacy'
        ) THEN
            RAISE EXCEPTION 'wallet_transactions_legacy đã tồn tại — đối soát và DROP bảng backup này trước khi migrate lại';
        END IF;

        ALTER TABLE wallet_transactions RENAME TO wallet_transactions_legacy;

        FOR idx IN
            SELECT indexname
            FROM pg_indexes
            WHERE schemaname = current_schema()
              AND tablename = 'wallet_transactions_legacy'
        LOOP
            EXECUTE format('ALTER INDEX %I RENAME TO %I',
                           idx.indexname, left(idx.indexname || '_legacy', 63));
        END LOOP;

        RAISE NOTICE 'wallet_transactions cũ đã đổi tên thành wallet_transactions_legacy (dữ liệu giữ nguyên)';
    END IF;
END$$;

CREATE TABLE IF NOT EXISTS wallet_transactions (
    id               UUID          NOT NULL DEFAULT gen_random_uuid(),
    wallet_id        BIGINT        NOT NULL,
    transaction_type VARCHAR(30)   NOT NULL
                         CHECK (transaction_type IN (
                             'DEPOSIT','ORDER_PAYMENT','SALE_HOLD',
                             'HOLD_RELEASE','HOLD_RELEASE_NET','PLATFORM_FEE',
                             'ORDER_REFUND','DISPUTE_REFUND','REFUND',
                             'WITHDRAW_PENDING','WITHDRAW_DONE','WITHDRAW_CANCEL',
                             'CANCEL_HOLD','ADMIN_ADJUST'
                         )),
    balance_type     VARCHAR(20)   NOT NULL DEFAULT 'AVAILABLE'
                         CHECK (balance_type IN ('AVAILABLE','HOLD')),
    amount           NUMERIC(18,2) NOT NULL,
    balance_before   NUMERIC(18,2) NOT NULL,
    balance_after    NUMERIC(18,2) NOT NULL,
    reference_id     BIGINT,
    reference_type   VARCHAR(30),
    description      TEXT,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS wt_2025_01 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE IF NOT EXISTS wt_2025_02 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE IF NOT EXISTS wt_2025_03 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE IF NOT EXISTS wt_2025_04 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
CREATE TABLE IF NOT EXISTS wt_2025_05 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');
CREATE TABLE IF NOT EXISTS wt_2025_06 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');
CREATE TABLE IF NOT EXISTS wt_2025_07 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
CREATE TABLE IF NOT EXISTS wt_2025_08 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE IF NOT EXISTS wt_2025_09 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE IF NOT EXISTS wt_2025_10 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE IF NOT EXISTS wt_2025_11 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE IF NOT EXISTS wt_2025_12 PARTITION OF wallet_transactions FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
CREATE TABLE IF NOT EXISTS wt_2026_01 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE IF NOT EXISTS wt_2026_02 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE IF NOT EXISTS wt_2026_03 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS wt_2026_04 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE IF NOT EXISTS wt_2026_05 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE IF NOT EXISTS wt_2026_06 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS wt_2026_07 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS wt_2026_08 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS wt_2026_09 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS wt_2026_10 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE IF NOT EXISTS wt_2026_11 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE IF NOT EXISTS wt_2026_12 PARTITION OF wallet_transactions FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE IF NOT EXISTS wt_2027_01 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');
CREATE TABLE IF NOT EXISTS wt_2027_02 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-02-01') TO ('2027-03-01');
CREATE TABLE IF NOT EXISTS wt_2027_03 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-03-01') TO ('2027-04-01');
CREATE TABLE IF NOT EXISTS wt_2027_04 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-04-01') TO ('2027-05-01');
CREATE TABLE IF NOT EXISTS wt_2027_05 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-05-01') TO ('2027-06-01');
CREATE TABLE IF NOT EXISTS wt_2027_06 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-06-01') TO ('2027-07-01');
CREATE TABLE IF NOT EXISTS wt_2027_07 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');
CREATE TABLE IF NOT EXISTS wt_2027_08 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-08-01') TO ('2027-09-01');
CREATE TABLE IF NOT EXISTS wt_2027_09 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-09-01') TO ('2027-10-01');
CREATE TABLE IF NOT EXISTS wt_2027_10 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-10-01') TO ('2027-11-01');
CREATE TABLE IF NOT EXISTS wt_2027_11 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-11-01') TO ('2027-12-01');
CREATE TABLE IF NOT EXISTS wt_2027_12 PARTITION OF wallet_transactions FOR VALUES FROM ('2027-12-01') TO ('2028-01-01');
CREATE TABLE IF NOT EXISTS wt_default  PARTITION OF wallet_transactions DEFAULT;
-- LƯU Ý VẬN HÀNH: partition tháng chỉ tạo sẵn đến hết 2027-12. PartitionCreateScheduler (backend)
-- phải tạo wt_YYYY_MM TRƯỚC khi sang tháng mới. Nếu để giao dịch rơi vào wt_default, lệnh tạo
-- partition cho khoảng đó sẽ LỖI cho đến khi chuyển các dòng đó ra khỏi wt_default
-- (trong 1 transaction: DELETE ... RETURNING ra bảng tạm → tạo partition → INSERT lại).

CREATE INDEX IF NOT EXISTS idx_wt_wallet_created ON wallet_transactions(wallet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wt_type ON wallet_transactions(transaction_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wt_reference ON wallet_transactions(reference_type, reference_id, created_at DESC)
    WHERE reference_id IS NOT NULL;

-- ============================================================
-- MODULE 3: SHOP (KHÔNG có favorite_shops)
-- ============================================================

CREATE TABLE IF NOT EXISTS shops (
    id               BIGSERIAL     PRIMARY KEY,
    owner_id         BIGINT        NOT NULL UNIQUE REFERENCES users(id),
    name             VARCHAR(255)  NOT NULL,
    slug             VARCHAR(255)  NOT NULL UNIQUE,
    shop_avatar_url  VARCHAR(500),
    shop_cover_url   VARCHAR(500),
    description      TEXT,
    contact_info     VARCHAR(255),
    application_reason VARCHAR(500),
    total_orders     INT           NOT NULL DEFAULT 0,
    total_disputes   INT           NOT NULL DEFAULT 0,
    dispute_rate     NUMERIC(5,2)  NOT NULL DEFAULT 0,
    status           VARCHAR(30)   NOT NULL DEFAULT 'PENDING'
                         CHECK (status IN ('PENDING','ACTIVE','REJECTED','BANNED')),
    rating_avg       NUMERIC(3,2)  NOT NULL DEFAULT 0,
    rating_count     BIGINT        NOT NULL DEFAULT 0,
    rating_sum       BIGINT        NOT NULL DEFAULT 0,
    version          BIGINT        NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Migration idempotent cho database đã có bảng shops từ phiên bản trước.
ALTER TABLE shops ALTER COLUMN status SET DEFAULT 'PENDING';
ALTER TABLE shops ADD COLUMN IF NOT EXISTS contact_info VARCHAR(255);
ALTER TABLE shops ADD COLUMN IF NOT EXISTS application_reason VARCHAR(500);
ALTER TABLE shops ADD COLUMN IF NOT EXISTS rating_count BIGINT NOT NULL DEFAULT 0;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS rating_sum BIGINT NOT NULL DEFAULT 0;
-- Tách thành nhiều bước để chạy an toàn cả khi Hibernate đã tạo dở cột version.
ALTER TABLE shops ADD COLUMN IF NOT EXISTS version BIGINT;
UPDATE shops SET version = 0 WHERE version IS NULL;
ALTER TABLE shops ALTER COLUMN version SET DEFAULT 0;
ALTER TABLE shops ALTER COLUMN version SET NOT NULL;
ALTER TABLE shops DROP CONSTRAINT IF EXISTS shops_status_check;
-- Các trạng thái khóa/ngừng cũ đều chuyển về BANNED để tiếp tục ẩn shop
-- và cho phép admin mở lại bằng ACTIVE.
UPDATE shops
SET status = 'BANNED'
WHERE status IN ('INACTIVE', 'SUSPENDED', 'CLOSED');
ALTER TABLE shops ADD CONSTRAINT shops_status_check
    CHECK (status IN ('PENDING','ACTIVE','REJECTED','BANNED'));

CREATE INDEX IF NOT EXISTS idx_shops_public_status_created
    ON shops(status, created_at DESC);

CREATE TABLE IF NOT EXISTS shop_images (
    id         BIGSERIAL    PRIMARY KEY,
    shop_id    BIGINT       NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    image_url  VARCHAR(500) NOT NULL,
    image_type VARCHAR(30)  NOT NULL DEFAULT 'GALLERY'
                   CHECK (image_type IN ('GALLERY','LICENSE','VERIFY','OTHER')),
    sort_order INT          NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shop_reports (
    id           BIGSERIAL    PRIMARY KEY,
    reporter_id  BIGINT       NOT NULL REFERENCES users(id),
    shop_id      BIGINT       NOT NULL REFERENCES shops(id),
    reason       TEXT         NOT NULL,
    evidence_url VARCHAR(500),
    status       VARCHAR(30)  NOT NULL DEFAULT 'PENDING'
                     CHECK (status IN ('PENDING','RESOLVED','DISMISSED')),
    admin_notes  TEXT,
    processor_id BIGINT       REFERENCES users(id),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    resolved_at  TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_shop_reports_shop_status ON shop_reports(shop_id, status);

-- ============================================================
-- MODULE 4: CATEGORY / PRODUCT / ASSET
-- ============================================================

CREATE TABLE IF NOT EXISTS categories (
    id         BIGSERIAL    PRIMARY KEY,
    parent_id  BIGINT,
    name       VARCHAR(255) NOT NULL,
    slug       VARCHAR(255) NOT NULL UNIQUE,
    icon_url   VARCHAR(500),
    is_active  BOOLEAN      NOT NULL DEFAULT TRUE,
    sort_order INT          NOT NULL DEFAULT 0,
    CONSTRAINT fk_categories_parent
        FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE RESTRICT,
    CONSTRAINT chk_categories_parent_not_self
        CHECK (parent_id IS NULL OR parent_id <> id)
);

-- Migration an toàn khi chạy file này trên database đã có bảng categories.
ALTER TABLE categories ADD COLUMN IF NOT EXISTS parent_id BIGINT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_categories_parent'
          AND conrelid = 'categories'::regclass
    ) THEN
        ALTER TABLE categories
            ADD CONSTRAINT fk_categories_parent
            FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE RESTRICT;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_categories_parent_not_self'
          AND conrelid = 'categories'::regclass
    ) THEN
        ALTER TABLE categories
            ADD CONSTRAINT chk_categories_parent_not_self
            CHECK (parent_id IS NULL OR parent_id <> id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_categories_parent_active_sort
    ON categories(parent_id, is_active, sort_order);

CREATE TABLE IF NOT EXISTS products (
    id                   BIGSERIAL     PRIMARY KEY,
    shop_id              BIGINT        NOT NULL REFERENCES shops(id),
    category_id          BIGINT        NOT NULL REFERENCES categories(id),
    name                 VARCHAR(255)  NOT NULL,
    slug                 VARCHAR(255)  NOT NULL UNIQUE,
    thumbnail_url        VARCHAR(500),
    short_description    VARCHAR(200),
    description          TEXT,
    product_type         VARCHAR(30)   NOT NULL DEFAULT 'ACCOUNT'
                             CHECK (product_type IN ('ACCOUNT','LICENSE','GIFTCARD','COOKIE','OTHER')),
    delivery_type        VARCHAR(20)   NOT NULL DEFAULT 'INSTANT'
                             CHECK (delivery_type IN ('INSTANT','PRE_ORDER')),
    status               VARCHAR(30)   NOT NULL DEFAULT 'ACTIVE'
                             CHECK (status IN ('ACTIVE','INACTIVE','DELETED')),
    sold_count           BIGINT        NOT NULL DEFAULT 0,
    failed_dispute_count BIGINT        NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Migration cho database cũ: ảnh duy nhất nằm trực tiếp trên products.
ALTER TABLE products ADD COLUMN IF NOT EXISTS thumbnail_url VARCHAR(500);

-- Product.stock_count không còn là nguồn dữ liệu; tổng tồn kho được tính từ
-- SUM(product_variants.stock_count) của các variant ACTIVE.
ALTER TABLE products DROP COLUMN IF EXISTS stock_count;

-- Nếu database cũ còn product_images, chọn ảnh đầu tiên làm thumbnail rồi đổi tên
-- bảng thành legacy để bảo toàn dữ liệu thay vì xóa ngay.
DO $$
BEGIN
    IF to_regclass('public.product_images') IS NOT NULL THEN
        EXECUTE $migration$
            UPDATE products p
            SET thumbnail_url = first_image.image_url
            FROM (
                SELECT DISTINCT ON (product_id)
                       product_id,
                       image_url
                FROM product_images
                WHERE NULLIF(BTRIM(image_url), '') IS NOT NULL
                ORDER BY product_id, sort_order ASC, id ASC
            ) AS first_image
            WHERE p.id = first_image.product_id
              AND NULLIF(BTRIM(p.thumbnail_url), '') IS NULL
        $migration$;

        IF to_regclass('public.product_images_legacy') IS NULL THEN
            EXECUTE 'ALTER TABLE public.product_images RENAME TO product_images_legacy';
        END IF;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_products_shop ON products(shop_id, status);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id, status);
CREATE INDEX IF NOT EXISTS idx_products_delivery ON products(delivery_type, status);
CREATE INDEX IF NOT EXISTS idx_products_public_created
    ON products(created_at DESC) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_products_public_best_selling
    ON products(sold_count DESC, created_at DESC, id DESC)
    WHERE status = 'ACTIVE' AND sold_count > 0;

CREATE TABLE IF NOT EXISTS pre_order_configs (
    id                         BIGSERIAL   PRIMARY KEY,
    product_id                 BIGINT      NOT NULL UNIQUE REFERENCES products(id) ON DELETE CASCADE,
    max_processing_hours       INT         NOT NULL DEFAULT 24
                                           CONSTRAINT chk_pre_order_processing_hours_24
                                           CHECK (max_processing_hours = 24),
    order_instructions         TEXT,
    buyer_input_fields         JSONB,
    auto_reject_if_unavailable BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS product_variants (
    id            BIGSERIAL     PRIMARY KEY,
    product_id    BIGINT        NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    name          VARCHAR(100)  NOT NULL
                      CONSTRAINT chk_product_variants_name_not_blank CHECK (BTRIM(name) <> ''),
    duration_days INT
                      CONSTRAINT chk_product_variants_duration_positive
                      CHECK (duration_days IS NULL OR duration_days > 0),
    price         NUMERIC(18,2) NOT NULL
                      CONSTRAINT chk_product_variants_price_positive CHECK (price > 0),
    sort_order    INT           NOT NULL DEFAULT 0,
    status        VARCHAR(30)   NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE')),
    stock_count   INT           NOT NULL DEFAULT 0
                      CONSTRAINT chk_product_variants_stock_nonnegative CHECK (stock_count >= 0)
);

-- CREATE TABLE IF NOT EXISTS không bổ sung constraint cho bảng đã tồn tại,
-- nên cần migration idempotent riêng cho database đang chạy.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_product_variants_name_not_blank'
          AND conrelid = 'product_variants'::regclass
    ) THEN
        ALTER TABLE product_variants
            ADD CONSTRAINT chk_product_variants_name_not_blank
            CHECK (BTRIM(name) <> '');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_product_variants_duration_positive'
          AND conrelid = 'product_variants'::regclass
    ) THEN
        ALTER TABLE product_variants
            ADD CONSTRAINT chk_product_variants_duration_positive
            CHECK (duration_days IS NULL OR duration_days > 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_product_variants_price_positive'
          AND conrelid = 'product_variants'::regclass
    ) THEN
        ALTER TABLE product_variants
            ADD CONSTRAINT chk_product_variants_price_positive
            CHECK (price > 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_product_variants_stock_nonnegative'
          AND conrelid = 'product_variants'::regclass
    ) THEN
        ALTER TABLE product_variants
            ADD CONSTRAINT chk_product_variants_stock_nonnegative
            CHECK (stock_count >= 0);
    END IF;
END $$;

-- Một sản phẩm không được có hai biến thể trùng tên sau khi bỏ khoảng trắng
-- đầu/cuối và không phân biệt hoa/thường. Đây là lớp chống race-condition tại DB.
CREATE UNIQUE INDEX IF NOT EXISTS uq_product_variants_product_name_normalized
    ON product_variants(product_id, LOWER(BTRIM(name)));

CREATE TABLE IF NOT EXISTS digital_assets (
    id                  BIGSERIAL    PRIMARY KEY,
    product_variant_id  BIGINT       NOT NULL REFERENCES product_variants(id),
    asset_type          VARCHAR(50)  NOT NULL
                            CHECK (asset_type IN ('ACCOUNT','LICENSE','GIFTCARD','COOKIE','OTHER')),
    -- v8-DLV: NGUYÊN VĂN 1 dòng TXT giao cho khách (1 dòng TXT = 1 asset khi import).
    delivery_content    TEXT,
    -- asset_data: dữ liệu cũ/metadata — TEXT khớp entity DigitalAsset (Hibernate validate)
    asset_data          TEXT         NOT NULL,
    asset_identifier    VARCHAR(500),
    -- Fingerprint SHA-256 của asset_type + định danh chuẩn hóa; không log credential.
    content_hash        VARCHAR(64),
    status              VARCHAR(30)  NOT NULL DEFAULT 'AVAILABLE'
                            CHECK (status IN ('AVAILABLE','RESERVED','SOLD','DISPUTED','REVOKED')),
    reserved_at         TIMESTAMPTZ,
    reserved_expires_at TIMESTAMPTZ,
    order_item_id       BIGINT,
    is_delivered        BOOLEAN      NOT NULL DEFAULT FALSE,
    delivered_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Upgrade DB cũ trước khi tạo unique index. ACCOUNT dùng username trước dấu |
-- làm định danh; vì vậy đổi password không biến cùng account thành hàng mới.
ALTER TABLE digital_assets ADD COLUMN IF NOT EXISTS content_hash VARCHAR(64);
ALTER TABLE digital_assets ALTER COLUMN content_hash TYPE VARCHAR(64) USING BTRIM(content_hash);

UPDATE digital_assets
SET asset_identifier = LEFT(
        LOWER(BTRIM(SPLIT_PART(BTRIM(COALESCE(NULLIF(delivery_content, ''), asset_data)), '|', 1))),
        500
    )
WHERE asset_type = 'ACCOUNT'
  AND BTRIM(COALESCE(NULLIF(delivery_content, ''), asset_data)) <> '';

-- Nếu lịch sử trùng định danh, ưu tiên row SOLD; các row AVAILABLE dư được
-- chuyển REVOKED để không còn khả năng giao tiếp cho buyer.
DROP INDEX IF EXISTS uq_digital_assets_content_hash;
UPDATE digital_assets SET content_hash = NULL;

WITH normalized_assets AS (
    SELECT id,
           status,
           ENCODE(DIGEST(
               asset_type || E'\n' || CASE
                   WHEN asset_type = 'ACCOUNT' THEN
                       LOWER(BTRIM(SPLIT_PART(BTRIM(COALESCE(NULLIF(delivery_content, ''), asset_data)), '|', 1)))
                   ELSE BTRIM(COALESCE(NULLIF(delivery_content, ''), asset_data))
               END,
               'sha256'
           ), 'hex') AS fingerprint
    FROM digital_assets
    WHERE BTRIM(COALESCE(NULLIF(delivery_content, ''), asset_data)) <> ''
), ranked_assets AS (
    SELECT id,
           fingerprint,
           ROW_NUMBER() OVER (
               PARTITION BY fingerprint
               ORDER BY CASE status
                            WHEN 'SOLD' THEN 0
                            WHEN 'RESERVED' THEN 1
                            WHEN 'DISPUTED' THEN 2
                            WHEN 'AVAILABLE' THEN 3
                            ELSE 4
                        END,
                        CASE WHEN status = 'AVAILABLE' THEN id END DESC,
                        id
           ) AS fingerprint_order
    FROM normalized_assets
)
UPDATE digital_assets asset
SET content_hash = CASE WHEN ranked.fingerprint_order = 1 THEN ranked.fingerprint ELSE NULL END,
    status = CASE
        WHEN ranked.fingerprint_order > 1 AND asset.status = 'AVAILABLE' THEN 'REVOKED'
        ELSE asset.status
    END,
    updated_at = CASE
        WHEN ranked.fingerprint_order > 1 AND asset.status = 'AVAILABLE' THEN NOW()
        ELSE asset.updated_at
    END
FROM ranked_assets ranked
WHERE asset.id = ranked.id;

-- stock_count là cache; tái đồng bộ theo số row AVAILABLE thực tế sau cleanup.
WITH actual_stock AS (
    SELECT variant.id AS variant_id,
           COUNT(asset.id) FILTER (WHERE asset.status = 'AVAILABLE')::INT AS available_count
    FROM product_variants variant
    JOIN products product ON product.id = variant.product_id
    LEFT JOIN digital_assets asset ON asset.product_variant_id = variant.id
    WHERE product.delivery_type = 'INSTANT'
    GROUP BY variant.id
)
UPDATE product_variants variant
SET stock_count = actual.available_count
FROM actual_stock actual
WHERE variant.id = actual.variant_id
  AND variant.stock_count IS DISTINCT FROM actual.available_count;

CREATE UNIQUE INDEX IF NOT EXISTS uq_digital_assets_content_hash
    ON digital_assets(content_hash);
CREATE INDEX IF NOT EXISTS idx_digital_assets_available
    ON digital_assets(product_variant_id, status) WHERE status = 'AVAILABLE';
CREATE INDEX IF NOT EXISTS idx_digital_assets_order_item
    ON digital_assets(order_item_id) WHERE order_item_id IS NOT NULL;

-- Mỗi sản phẩm chỉ dùng một ảnh tại products.thumbnail_url.
-- Bảng product_images không còn thuộc mô hình; dữ liệu cũ (nếu có) đã được giữ
-- trong product_images_legacy bởi block migration phía trên.

CREATE TABLE IF NOT EXISTS asset_delivery_logs (
    id                        BIGSERIAL   PRIMARY KEY,
    asset_id                  BIGINT      NOT NULL REFERENCES digital_assets(id),
    order_item_id             BIGINT      NOT NULL,
    buyer_id                  BIGINT      NOT NULL REFERENCES users(id),
    -- v8-DLV: bản chụp CỐ ĐỊNH nội dung đã giao — buyer mở lại đơn đọc từ đây,
    -- KHÔNG đọc lại digital_assets (kho có thể bị sửa/thu hồi sau khi bán)
    delivery_content_snapshot TEXT,
    asset_data_snapshot       JSONB       NOT NULL,
    delivery_method           VARCHAR(30) NOT NULL DEFAULT 'AUTO'
                                  CHECK (delivery_method IN ('AUTO','MANUAL','RESEND')),
    status                    VARCHAR(30) NOT NULL DEFAULT 'SUCCESS'
                                  CHECK (status IN ('SUCCESS','FAILED','RESENT')),
    error_message             TEXT,
    delivered_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_adl_order_item ON asset_delivery_logs(order_item_id);
CREATE INDEX IF NOT EXISTS idx_adl_buyer ON asset_delivery_logs(buyer_id, delivered_at DESC);

CREATE TABLE IF NOT EXISTS asset_access_logs (
    id          BIGSERIAL   PRIMARY KEY,
    asset_id    BIGINT      NOT NULL REFERENCES digital_assets(id),
    user_id     BIGINT      NOT NULL REFERENCES users(id),
    ip_address  VARCHAR(45),
    user_agent  TEXT,
    accessed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- MODULE 5: VOUCHER
-- ============================================================

CREATE TABLE IF NOT EXISTS vouchers (
    id                  BIGSERIAL     PRIMARY KEY,
    shop_id             BIGINT        NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    code                VARCHAR(50)   NOT NULL,
    description         VARCHAR(255),
    discount_type       VARCHAR(20)   NOT NULL CHECK (discount_type IN ('PERCENT','FIXED')),
    discount_value      NUMERIC(18,2) NOT NULL CHECK (discount_value > 0),
    max_discount_amount NUMERIC(18,2),
    min_order_amount    NUMERIC(18,2) NOT NULL DEFAULT 0,
    apply_all_products  BOOLEAN       NOT NULL DEFAULT TRUE,
    starts_at           TIMESTAMPTZ   NOT NULL,
    expires_at          TIMESTAMPTZ   NOT NULL,
    usage_limit         INT           NOT NULL DEFAULT 1,
    used_count          INT           NOT NULL DEFAULT 0,
    is_active           BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_voucher_shop_code UNIQUE (shop_id, code),
    CONSTRAINT chk_voucher_dates CHECK (expires_at > starts_at)
);

CREATE TABLE IF NOT EXISTS voucher_products (
    voucher_id BIGINT NOT NULL REFERENCES vouchers(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    PRIMARY KEY (voucher_id, product_id)
);

CREATE TABLE IF NOT EXISTS voucher_usages (
    id              BIGSERIAL     PRIMARY KEY,
    voucher_id      BIGINT        NOT NULL REFERENCES vouchers(id),
    user_id         BIGINT        NOT NULL REFERENCES users(id),
    order_id        BIGINT        NOT NULL,
    discount_amount NUMERIC(18,2) NOT NULL,
    used_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_voucher_user UNIQUE (voucher_id, user_id)
);

-- ============================================================
-- MODULE 6: CART (THAY THẾ FAVORITE)
-- ============================================================

CREATE TABLE IF NOT EXISTS carts (
    id         BIGSERIAL   PRIMARY KEY,
    user_id    BIGINT      NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cart_items (
    id                 BIGSERIAL   PRIMARY KEY,
    cart_id            BIGINT      NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
    product_variant_id BIGINT      NOT NULL REFERENCES product_variants(id),
    quantity           INT         NOT NULL CHECK (quantity > 0 AND quantity <= 1000),
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_cart_item_variant UNIQUE (cart_id, product_variant_id)
);
CREATE INDEX IF NOT EXISTS idx_cart_items_cart ON cart_items(cart_id);

-- ============================================================
-- MODULE 7: ORDER
-- ============================================================

CREATE TABLE IF NOT EXISTS orders (
    id                     BIGSERIAL     PRIMARY KEY,
    order_code             VARCHAR(50)   NOT NULL UNIQUE,
    user_id                BIGINT        NOT NULL REFERENCES users(id),
    shop_id                BIGINT        NOT NULL REFERENCES shops(id),
    cart_session_id        VARCHAR(100),
    voucher_id             BIGINT        REFERENCES vouchers(id),
    voucher_discount       NUMERIC(18,2) NOT NULL DEFAULT 0,
    delivery_type          VARCHAR(20)   NOT NULL DEFAULT 'INSTANT'
                               CHECK (delivery_type IN ('INSTANT','PRE_ORDER')),
    status                 VARCHAR(30)   NOT NULL DEFAULT 'PENDING',
    payment_status         VARCHAR(30)   NOT NULL DEFAULT 'UNPAID'
                               CHECK (payment_status IN ('UNPAID','PAID','REFUNDED','PARTIAL_REFUND')),
    -- v8: mua hàng CHỈ WALLET (SEPAY/VNPAY lịch sử/MOMO/ZALOPAY chỉ dùng để NẠP ví)
    payment_method         VARCHAR(30)   NOT NULL DEFAULT 'WALLET'
                               CHECK (payment_method = 'WALLET'),
    subtotal_amount        NUMERIC(18,2) NOT NULL,
    total_amount           NUMERIC(18,2) NOT NULL,
    placed_at              TIMESTAMPTZ,
    approved_at            TIMESTAMPTZ,
    rejected_at            TIMESTAMPTZ,
    delivered_at           TIMESTAMPTZ,
    approval_deadline_at   TIMESTAMPTZ,
    processing_deadline_at TIMESTAMPTZ,
    rejection_reason       TEXT,
    idempotency_key        VARCHAR(100),
    checkout_request_id    BIGINT,
    version                BIGINT        NOT NULL DEFAULT 0,
    created_at             TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_shop ON orders(shop_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_shop_placed_at
    ON orders(shop_id, placed_at DESC, id DESC);
-- Keyset/cursor pagination cho lịch sử mua hàng: không COUNT, không OFFSET sâu.
CREATE INDEX IF NOT EXISTS idx_orders_user_cursor
    ON orders(user_id, placed_at DESC, id DESC);
DROP INDEX IF EXISTS idx_orders_user_placed_at;
DROP INDEX IF EXISTS idx_orders_user_idem_key;
DROP INDEX IF EXISTS uq_orders_user_idem_key;
CREATE INDEX IF NOT EXISTS idx_orders_processing_deadline
    ON orders(processing_deadline_at, id) WHERE status = 'PROCESSING';
CREATE INDEX IF NOT EXISTS idx_orders_approval_deadline
    ON orders(approval_deadline_at, id) WHERE status = 'WAITING_APPROVAL';

CREATE TABLE IF NOT EXISTS order_items (
    id                 BIGSERIAL     PRIMARY KEY,
    order_id           BIGINT        NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_variant_id BIGINT        NOT NULL REFERENCES product_variants(id),
    product_name       VARCHAR(255)  NOT NULL,
    variant_name       VARCHAR(100)  NOT NULL,
    product_type       VARCHAR(30)   NOT NULL,
    delivery_type      VARCHAR(20)   NOT NULL CHECK (delivery_type IN ('INSTANT','PRE_ORDER')),
    unit_price         NUMERIC(18,2) NOT NULL,
    quantity           INT           NOT NULL DEFAULT 1 CHECK (quantity > 0),
    line_total         NUMERIC(18,2) NOT NULL,
    -- Snapshot phí sàn chốt lúc buyer thanh toán
    fee_config_id      BIGINT,
    fee_rate_snapshot  NUMERIC(5,4),
    fee_amount         NUMERIC(18,2),
    seller_net_amount  NUMERIC(18,2),
    refund_status      VARCHAR(20) NOT NULL DEFAULT 'NONE'
                           CHECK (refund_status IN ('NONE','REFUNDED')),
    refunded_at        TIMESTAMPTZ,
    created_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_refund ON order_items(order_id, refund_status);

-- v8-DLV: delivery_content = nội dung shop giao khách (account/key/tin nhắn), buyer xem lại
-- vĩnh viễn từ cột này. seller_notes = ghi chú NỘI BỘ, không bao giờ trả cho buyer.
-- Đã bỏ delivered_asset_data + shop_note (thay bằng delivery_content + seller_notes).
CREATE TABLE IF NOT EXISTS pre_order_items (
    id                    BIGSERIAL    PRIMARY KEY,
    order_item_id         BIGINT       NOT NULL UNIQUE REFERENCES order_items(id) ON DELETE CASCADE,
    buyer_inputs          TEXT,        -- JSON string — TEXT khớp entity PreOrderItem (Hibernate validate)
    buyer_note            TEXT,
    status                VARCHAR(30)  NOT NULL DEFAULT 'PENDING'
                              CHECK (status IN ('PENDING','ACCEPTED','PROCESSING','DELIVERED','REJECTED','CANCELLED')),
    delivery_content      TEXT,
    delivery_content_type VARCHAR(20),
    seller_notes          TEXT,
    accepted_at           TIMESTAMPTZ,
    delivered_at          TIMESTAMPTZ,
    completed_at          TIMESTAMPTZ,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_status_logs (
    id          BIGSERIAL   PRIMARY KEY,
    order_id    BIGINT      NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    from_status VARCHAR(30),
    to_status   VARCHAR(30) NOT NULL,
    changed_by  BIGINT      REFERENCES users(id),
    note        TEXT,
    -- Entity Java dùng String + @JdbcTypeCode(SqlTypes.JSON), nếu chỉ khai báo
    -- columnDefinition mà thiếu JdbcTypeCode thì Hibernate sẽ bind VARCHAR và PostgreSQL từ chối.
    meta        JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- FK ngược
ALTER TABLE digital_assets DROP CONSTRAINT IF EXISTS fk_da_order_item;
ALTER TABLE digital_assets ADD CONSTRAINT fk_da_order_item
    FOREIGN KEY (order_item_id) REFERENCES order_items(id);
ALTER TABLE voucher_usages DROP CONSTRAINT IF EXISTS fk_vu_order;
ALTER TABLE voucher_usages ADD CONSTRAINT fk_vu_order
    FOREIGN KEY (order_id) REFERENCES orders(id);
ALTER TABLE asset_delivery_logs DROP CONSTRAINT IF EXISTS fk_adl_order_item;
ALTER TABLE asset_delivery_logs ADD CONSTRAINT fk_adl_order_item
    FOREIGN KEY (order_item_id) REFERENCES order_items(id);

-- ============================================================
-- MODULE 8: PLATFORM FEE (KHÔNG WAIVE)
-- Status ledger: PENDING | COLLECTED | CANCELLED | ADJUSTED
-- ============================================================

CREATE TABLE IF NOT EXISTS platform_fee_configs (
    id              BIGSERIAL     PRIMARY KEY,
    fee_rate        NUMERIC(5,4)  NOT NULL CHECK (fee_rate >= 0 AND fee_rate <= 1),
    min_fee_amount  NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (min_fee_amount >= 0),
    max_fee_amount  NUMERIC(18,2),
    description     VARCHAR(255),
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    effective_from  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    effective_until TIMESTAMPTZ,
    created_by      BIGINT        NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_fee_dates CHECK (effective_until IS NULL OR effective_until > effective_from),
    CONSTRAINT chk_fee_min_max CHECK (max_fee_amount IS NULL OR max_fee_amount >= min_fee_amount)
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_active_fee_config ON platform_fee_configs(is_active) WHERE is_active = TRUE;

CREATE TABLE IF NOT EXISTS hold_releases (
    id                     BIGSERIAL     PRIMARY KEY,
    wallet_id              BIGINT        NOT NULL REFERENCES wallets(id),
    order_id               BIGINT        NOT NULL REFERENCES orders(id),
    order_item_id          BIGINT        NOT NULL UNIQUE REFERENCES order_items(id),  -- v8: 1 OrderItem = 1 HoldRelease
    hold_amount            NUMERIC(18,2) NOT NULL CHECK (hold_amount > 0),
    fee_amount             NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (fee_amount >= 0),
    seller_net_amount      NUMERIC(18,2) NOT NULL CHECK (seller_net_amount >= 0),
    fee_ledger_id          BIGINT,
    status                 VARCHAR(30)   NOT NULL DEFAULT 'HOLDING'
                               CHECK (status IN (
                                   'HOLDING','COMPLAINED','WARRANTY_IN_PROGRESS',
                                   'WAITING_BUYER_CONFIRMATION','DISPUTED','RELEASED','REFUNDED'
                               )),
    scheduled_release_at   TIMESTAMPTZ   NOT NULL,
    released_at            TIMESTAMPTZ,
    complaint_reason       TEXT,
    complained_at          TIMESTAMPTZ,
    remaining_hold_seconds BIGINT,
    warranty_started_at    TIMESTAMPTZ,
    created_at             TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_hold_fee_net CHECK (hold_amount = fee_amount + seller_net_amount)
);
CREATE INDEX IF NOT EXISTS idx_hold_releases_job ON hold_releases(scheduled_release_at)
    WHERE status = 'HOLDING';

CREATE TABLE IF NOT EXISTS platform_fee_ledgers (
    id                   BIGSERIAL     PRIMARY KEY,
    order_item_id        BIGINT        NOT NULL UNIQUE REFERENCES order_items(id),
    order_id             BIGINT        NOT NULL REFERENCES orders(id),
    shop_id              BIGINT        NOT NULL REFERENCES shops(id),
    seller_wallet_id     BIGINT        NOT NULL REFERENCES wallets(id),
    fee_config_id        BIGINT        NOT NULL REFERENCES platform_fee_configs(id),
    fee_rate_snapshot    NUMERIC(5,4)  NOT NULL,
    sale_amount          NUMERIC(18,2) NOT NULL CHECK (sale_amount > 0),
    fee_amount           NUMERIC(18,2) NOT NULL CHECK (fee_amount >= 0),
    seller_net_amount    NUMERIC(18,2) NOT NULL CHECK (seller_net_amount >= 0),
    adjusted_sale_amount NUMERIC(18,2),
    adjusted_fee_amount  NUMERIC(18,2),
    adjusted_seller_net  NUMERIC(18,2),
    adjustment_reason    TEXT,
    status               VARCHAR(20)   NOT NULL DEFAULT 'PENDING'
                             CHECK (status IN ('PENDING','COLLECTED','CANCELLED','ADJUSTED')),
    fee_incurred_at      TIMESTAMPTZ   NOT NULL,
    collected_at         TIMESTAMPTZ,
    cancelled_at         TIMESTAMPTZ,
    hold_release_id      BIGINT,
    dispute_id           BIGINT,
    created_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_fee_sale_net CHECK (sale_amount = fee_amount + seller_net_amount)
);
CREATE INDEX IF NOT EXISTS idx_fee_ledger_shop ON platform_fee_ledgers(shop_id, status, fee_incurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_fee_ledger_pending ON platform_fee_ledgers(fee_incurred_at) WHERE status = 'PENDING';

CREATE TABLE IF NOT EXISTS platform_fee_logs (
    id            BIGSERIAL     PRIMARY KEY,
    fee_ledger_id BIGINT        NOT NULL REFERENCES platform_fee_ledgers(id),
    from_status   VARCHAR(20),
    to_status     VARCHAR(20)   NOT NULL,
    fee_amount    NUMERIC(18,2) NOT NULL CHECK (fee_amount >= 0),
    changed_by    BIGINT        REFERENCES users(id),
    reason        TEXT,
    -- Đồng bộ với PlatformFeeLog.meta: String + @JdbcTypeCode(SqlTypes.JSON).
    meta          JSONB,
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shop_fee_summaries (
    id             BIGSERIAL     PRIMARY KEY,
    shop_id        BIGINT        NOT NULL REFERENCES shops(id),
    period_year    INT           NOT NULL,
    period_month   INT           NOT NULL CHECK (period_month BETWEEN 1 AND 12),
    total_sales    NUMERIC(18,2) NOT NULL DEFAULT 0,
    total_fee      NUMERIC(18,2) NOT NULL DEFAULT 0,
    total_net      NUMERIC(18,2) NOT NULL DEFAULT 0,
    total_refunded NUMERIC(18,2) NOT NULL DEFAULT 0,
    order_count    INT           NOT NULL DEFAULT 0,
    dispute_count  INT           NOT NULL DEFAULT 0,
    updated_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_shop_fee_period UNIQUE (shop_id, period_year, period_month)
);

-- Circular FK fee ↔ hold
ALTER TABLE platform_fee_ledgers DROP CONSTRAINT IF EXISTS fk_fee_hold_release;
ALTER TABLE platform_fee_ledgers ADD CONSTRAINT fk_fee_hold_release
    FOREIGN KEY (hold_release_id) REFERENCES hold_releases(id);
ALTER TABLE hold_releases DROP CONSTRAINT IF EXISTS fk_hold_fee_ledger;
ALTER TABLE hold_releases ADD CONSTRAINT fk_hold_fee_ledger
    FOREIGN KEY (fee_ledger_id) REFERENCES platform_fee_ledgers(id);

-- ============================================================
-- MODULE 9: DISPUTE & REVIEW
-- ============================================================

CREATE TABLE IF NOT EXISTS order_disputes (
    id                 BIGSERIAL     PRIMARY KEY,
    order_id           BIGINT        NOT NULL REFERENCES orders(id),
    order_item_id      BIGINT        NOT NULL UNIQUE REFERENCES order_items(id),
    user_id            BIGINT        NOT NULL REFERENCES users(id),
    shop_id            BIGINT        NOT NULL REFERENCES shops(id),
    reason             TEXT          NOT NULL,
    evidence_urls      TEXT[],
    shop_response      TEXT,
    shop_evidence_urls TEXT[],
    status             VARCHAR(30)   NOT NULL DEFAULT 'OPEN'
                           CHECK (status IN (
                               'OPEN','WARRANTY_IN_PROGRESS','WAITING_BUYER_CONFIRMATION',
                               'PROCESSING','BUYER_WIN','SELLER_WIN','CLOSED'
                           )),
    refund_amount      NUMERIC(18,2),
    admin_note         TEXT,
    resolver_id        BIGINT        REFERENCES users(id),
    closed_reason      VARCHAR(40),
    created_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    deadline_at        TIMESTAMPTZ   NOT NULL,
    resolved_at        TIMESTAMPTZ,
    updated_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT order_disputes_closed_reason_check CHECK (
        (status = 'CLOSED'
            AND closed_reason IS NOT NULL
            AND closed_reason IN (
                'BUYER_WITHDREW','BUYER_ACCEPTED_WARRANTY','BUYER_CONFIRMATION_TIMEOUT'
            ))
        OR (status <> 'CLOSED' AND closed_reason IS NULL)
    )
);
CREATE INDEX IF NOT EXISTS idx_disputes_status_deadline
    ON order_disputes(status, deadline_at, id);
CREATE INDEX IF NOT EXISTS idx_disputes_user_created
    ON order_disputes(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_disputes_shop_created
    ON order_disputes(shop_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_disputes_order_status
    ON order_disputes(order_id, status);

ALTER TABLE platform_fee_ledgers DROP CONSTRAINT IF EXISTS fk_fee_dispute;
ALTER TABLE platform_fee_ledgers ADD CONSTRAINT fk_fee_dispute
    FOREIGN KEY (dispute_id) REFERENCES order_disputes(id);

CREATE TABLE IF NOT EXISTS product_reviews (
    id            BIGSERIAL   PRIMARY KEY,
    product_id    BIGINT      NOT NULL REFERENCES products(id),
    order_item_id BIGINT      NOT NULL UNIQUE REFERENCES order_items(id),
    user_id       BIGINT      NOT NULL REFERENCES users(id),
    rating        INT         NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment       TEXT,
    is_visible    BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ
);
-- Bản cũ từng cho phép một user đánh giá cùng sản phẩm nhiều lần qua nhiều item.
-- Giữ bản ghi cũ nhất trước khi thêm ràng buộc mới để file nâng cấp không bị dừng.
DELETE FROM product_reviews duplicate_review
USING product_reviews kept_review
WHERE duplicate_review.product_id = kept_review.product_id
  AND duplicate_review.user_id = kept_review.user_id
  AND duplicate_review.id > kept_review.id;
CREATE UNIQUE INDEX IF NOT EXISTS uq_product_reviews_product_user
    ON product_reviews(product_id, user_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_public
    ON product_reviews(product_id, created_at DESC) WHERE is_visible = TRUE;

-- product_reviews là nguồn dữ liệu gốc. Backfill lại cache đánh giá shop để
-- database cũ không tiếp tục dùng rating_avg được nhập tay hoặc dữ liệu seed.
WITH shop_rating_stats AS (
    SELECT p.shop_id,
           COUNT(r.id)::BIGINT AS rating_count,
           COALESCE(SUM(r.rating), 0)::BIGINT AS rating_sum
    FROM products p
    JOIN product_reviews r
      ON r.product_id = p.id
     AND r.is_visible = TRUE
    GROUP BY p.shop_id
)
UPDATE shops shop
SET rating_count = COALESCE(stats.rating_count, 0),
    rating_sum = COALESCE(stats.rating_sum, 0),
    rating_avg = CASE
        WHEN COALESCE(stats.rating_count, 0) = 0 THEN 0
        ELSE ROUND(stats.rating_sum::NUMERIC / stats.rating_count, 2)
    END,
    updated_at = NOW()
FROM (
    SELECT shop_id, rating_count, rating_sum FROM shop_rating_stats
    UNION ALL
    SELECT shop.id, 0::BIGINT, 0::BIGINT
    FROM shops shop
    WHERE NOT EXISTS (
        SELECT 1 FROM shop_rating_stats stats WHERE stats.shop_id = shop.id
    )
) stats
WHERE stats.shop_id = shop.id;

-- ============================================================
-- MODULE 10: CHAT / NOTIFICATION / AUDIT / FRAUD / OPS
-- ============================================================

CREATE TABLE IF NOT EXISTS chat_rooms (
    id               BIGSERIAL   PRIMARY KEY,
    participant_a    BIGINT      NOT NULL REFERENCES users(id),
    participant_b    BIGINT      NOT NULL REFERENCES users(id),
    shop_id          BIGINT      REFERENCES shops(id),
    related_order_id BIGINT      REFERENCES orders(id),
    last_message_at  TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_participants CHECK (participant_a < participant_b)
);
-- UNIQUE (a,b,shop_id) KHÔNG chặn trùng khi shop_id IS NULL (NULL != NULL trong UNIQUE)
-- → thay bằng 2 partial unique index để chặn trùng cả 2 trường hợp
ALTER TABLE chat_rooms DROP CONSTRAINT IF EXISTS uq_chat_room;
CREATE UNIQUE INDEX IF NOT EXISTS uq_chat_room_shop
    ON chat_rooms(participant_a, participant_b, shop_id) WHERE shop_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_chat_room_direct
    ON chat_rooms(participant_a, participant_b) WHERE shop_id IS NULL;

CREATE TABLE IF NOT EXISTS chat_messages (
    id              BIGSERIAL   PRIMARY KEY,
    room_id         BIGINT      NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
    sender_id       BIGINT      NOT NULL REFERENCES users(id),
    content         TEXT        NOT NULL,
    attachment_url  VARCHAR(500),
    attachment_type VARCHAR(30),
    is_read         BOOLEAN     NOT NULL DEFAULT FALSE,
    sent_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_chat_messages_room ON chat_messages(room_id, sent_at DESC);

CREATE TABLE IF NOT EXISTS notifications (
    id          BIGSERIAL    PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type        VARCHAR(50)  NOT NULL,
    title       VARCHAR(255) NOT NULL,
    content     TEXT         NOT NULL,
    ref_id      BIGINT,
    ref_type    VARCHAR(30),
    is_read     BOOLEAN      NOT NULL DEFAULT FALSE,
    expires_at  TIMESTAMPTZ,
    archived_at TIMESTAMPTZ,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read, created_at DESC)
    WHERE archived_at IS NULL;

-- Mốc đã xem badge trong Seller Center. Lưu ở database để đồng bộ giữa các
-- trình duyệt/thiết bị và để badge không xuất hiện vĩnh viễn sau khi đã xem.
CREATE TABLE IF NOT EXISTS seller_notification_reads (
    seller_id               BIGINT      PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    instant_orders_read_at  TIMESTAMPTZ NOT NULL DEFAULT TIMESTAMPTZ 'epoch',
    pre_orders_read_at      TIMESTAMPTZ NOT NULL DEFAULT TIMESTAMPTZ 'epoch',
    disputes_read_at        TIMESTAMPTZ NOT NULL DEFAULT TIMESTAMPTZ 'epoch',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id          BIGSERIAL    PRIMARY KEY,
    actor_id    BIGINT       NOT NULL REFERENCES users(id),
    actor_role  VARCHAR(50)  NOT NULL,
    action      VARCHAR(100) NOT NULL,
    target_type VARCHAR(50)  NOT NULL,
    target_id   BIGINT       NOT NULL,
    old_value   JSONB,
    new_value   JSONB,
    reason      TEXT,
    ip_address  VARCHAR(45),
    user_agent  TEXT,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON audit_logs(target_type, target_id, created_at DESC);

CREATE TABLE IF NOT EXISTS user_login_logs (
    id             BIGSERIAL    PRIMARY KEY,
    user_id        BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ip_address     VARCHAR(45)  NOT NULL,
    user_agent     TEXT,
    device_id      VARCHAR(255),
    country_code   VARCHAR(10),
    status         VARCHAR(30)  NOT NULL CHECK (status IN ('SUCCESS','FAILED','BLOCKED')),
    failure_reason VARCHAR(100),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_user_login_logs_user ON user_login_logs(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS risk_flags (
    id           BIGSERIAL    PRIMARY KEY,
    entity_type  VARCHAR(30)  NOT NULL CHECK (entity_type IN ('USER','SHOP','WALLET')),
    entity_id    BIGINT       NOT NULL,
    flag_type    VARCHAR(100) NOT NULL,
    severity     VARCHAR(20)  NOT NULL DEFAULT 'MEDIUM'
                     CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    description  TEXT,
    is_resolved  BOOLEAN      NOT NULL DEFAULT FALSE,
    resolved_by  BIGINT       REFERENCES users(id),
    resolved_at  TIMESTAMPTZ,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_risk_flags_open ON risk_flags(entity_type, entity_id) WHERE is_resolved = FALSE;

CREATE TABLE IF NOT EXISTS outbox_events (
    id             UUID         NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    aggregate_type VARCHAR(50)  NOT NULL,
    aggregate_id   BIGINT       NOT NULL,
    event_type     VARCHAR(100) NOT NULL,
    payload        JSONB        NOT NULL,
    status         VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
                       CHECK (status IN ('PENDING','PUBLISHED','FAILED')),
    retry_count    INT          NOT NULL DEFAULT 0,
    last_error     TEXT,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    published_at   TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_outbox_pending ON outbox_events(created_at) WHERE status = 'PENDING';

CREATE TABLE IF NOT EXISTS idempotency_keys (
    id             BIGSERIAL    PRIMARY KEY,
    key_value      VARCHAR(100) NOT NULL,
    operation_type VARCHAR(100) NOT NULL,
    user_id        BIGINT       NOT NULL REFERENCES users(id),
    request_hash   VARCHAR(64)  NOT NULL,
    response_body  JSONB,
    status         VARCHAR(20)  NOT NULL DEFAULT 'PROCESSING'
                       CHECK (status IN ('PROCESSING','DONE','FAILED')),
    expires_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW() + INTERVAL '24 hours',
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_idempotency_user_operation_key
        UNIQUE (user_id, operation_type, key_value)
);
CREATE INDEX IF NOT EXISTS idx_idempotency_expiry ON idempotency_keys(expires_at);

CREATE TABLE IF NOT EXISTS job_logs (
    id              BIGSERIAL    PRIMARY KEY,
    job_type        VARCHAR(100) NOT NULL,
    status          VARCHAR(20)  NOT NULL DEFAULT 'RUNNING'
                        CHECK (status IN ('RUNNING','SUCCESS','FAILED','PARTIAL')),
    started_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    finished_at     TIMESTAMPTZ,
    processed_count INT          NOT NULL DEFAULT 0,
    error_message   TEXT,
    meta            JSONB
);

CREATE TABLE IF NOT EXISTS shedlock (
    name       VARCHAR(64)  NOT NULL PRIMARY KEY,
    lock_until TIMESTAMP    NOT NULL,
    locked_at  TIMESTAMP    NOT NULL,
    locked_by  VARCHAR(255) NOT NULL
);

-- ============================================================
-- UPGRADE (DB đã tạo bằng bản cũ của file này) + CLEANUP LEGACY
-- ============================================================
-- Idempotent: DB mới thì các cột đã có sẵn trong CREATE TABLE, ALTER bên dưới bị bỏ qua.
ALTER TABLE digital_assets      ADD COLUMN IF NOT EXISTS delivery_content TEXT;
ALTER TABLE digital_assets      ADD COLUMN IF NOT EXISTS content_hash VARCHAR(64);
-- DB cũ tạo cột dạng JSONB → đổi sang TEXT khớp entity (Hibernate validate)
ALTER TABLE digital_assets      ALTER COLUMN asset_data   TYPE TEXT USING asset_data::text;
ALTER TABLE pre_order_items     ALTER COLUMN buyer_inputs TYPE TEXT USING buyer_inputs::text;
ALTER TABLE asset_delivery_logs ADD COLUMN IF NOT EXISTS delivery_content_snapshot TEXT;
ALTER TABLE pre_order_items     ADD COLUMN IF NOT EXISTS delivery_content TEXT;
ALTER TABLE pre_order_items     ADD COLUMN IF NOT EXISTS delivery_content_type VARCHAR(20);
ALTER TABLE pre_order_items     ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ;
ALTER TABLE pre_order_items     ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;

ALTER TABLE pre_order_items DROP CONSTRAINT IF EXISTS chk_pre_order_delivery_content_type;
ALTER TABLE pre_order_items ADD CONSTRAINT chk_pre_order_delivery_content_type
    CHECK (delivery_content_type IS NULL
           OR delivery_content_type IN ('ACCOUNT','KEY','MESSAGE','OTHER'));

-- Checkout/idempotency mới: một request có thể tách thành nhiều order.
ALTER TABLE orders ADD COLUMN IF NOT EXISTS checkout_request_id BIGINT;
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS refund_status VARCHAR(20) NOT NULL DEFAULT 'NONE';
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ;
ALTER TABLE order_disputes ADD COLUMN IF NOT EXISTS closed_reason VARCHAR(40);
ALTER TABLE idempotency_keys ADD COLUMN IF NOT EXISTS request_hash VARCHAR(64);
UPDATE idempotency_keys SET request_hash = REPEAT('0', 64) WHERE request_hash IS NULL;
ALTER TABLE idempotency_keys ALTER COLUMN request_hash SET NOT NULL;
-- Chuỗi 0 chỉ là sentinel cho dữ liệu legacy không còn payload để băm lại.
-- Checkout mới luôn truyền SHA-256 thật; không để database tự sinh hash giả.
ALTER TABLE idempotency_keys ALTER COLUMN request_hash DROP DEFAULT;

ALTER TABLE idempotency_keys DROP CONSTRAINT IF EXISTS idempotency_keys_key_value_key;
ALTER TABLE idempotency_keys DROP CONSTRAINT IF EXISTS uq_idempotency_user_operation_key;
ALTER TABLE idempotency_keys ADD CONSTRAINT uq_idempotency_user_operation_key
    UNIQUE (user_id, operation_type, key_value);

ALTER TABLE orders DROP CONSTRAINT IF EXISTS fk_orders_checkout_request;
ALTER TABLE orders ADD CONSTRAINT fk_orders_checkout_request
    FOREIGN KEY (checkout_request_id) REFERENCES idempotency_keys(id);

ALTER TABLE order_items DROP CONSTRAINT IF EXISTS order_items_refund_status_check;
ALTER TABLE order_items ADD CONSTRAINT order_items_refund_status_check
    CHECK (refund_status IN ('NONE','REFUNDED'));

ALTER TABLE hold_releases DROP CONSTRAINT IF EXISTS hold_releases_status_check;
ALTER TABLE hold_releases ADD CONSTRAINT hold_releases_status_check
    CHECK (status IN (
        'HOLDING','COMPLAINED','WARRANTY_IN_PROGRESS','WAITING_BUYER_CONFIRMATION',
        'DISPUTED','RELEASED','REFUNDED'
    ));

ALTER TABLE order_disputes DROP CONSTRAINT IF EXISTS order_disputes_status_check;
ALTER TABLE order_disputes ADD CONSTRAINT order_disputes_status_check
    CHECK (status IN (
        'OPEN','WARRANTY_IN_PROGRESS','WAITING_BUYER_CONFIRMATION',
        'PROCESSING','BUYER_WIN','SELLER_WIN','CLOSED'
    ));

-- Các bản CLOSED cũ chưa lưu lý do: nhận diện timeout qua system note, còn lại là buyer chấp nhận.
UPDATE order_disputes
SET closed_reason = CASE
    WHEN admin_note = 'Hệ thống đóng do buyer không phản hồi đúng hạn'
        THEN 'BUYER_CONFIRMATION_TIMEOUT'
    ELSE 'BUYER_ACCEPTED_WARRANTY'
END
WHERE status = 'CLOSED'
  AND closed_reason IS NULL;
UPDATE order_disputes
SET closed_reason = NULL
WHERE status <> 'CLOSED'
  AND closed_reason IS NOT NULL;

ALTER TABLE order_disputes DROP CONSTRAINT IF EXISTS order_disputes_closed_reason_check;
ALTER TABLE order_disputes ADD CONSTRAINT order_disputes_closed_reason_check
    CHECK (
        (status = 'CLOSED'
            AND closed_reason IS NOT NULL
            AND closed_reason IN (
                'BUYER_WITHDREW','BUYER_ACCEPTED_WARRANTY','BUYER_CONFIRMATION_TIMEOUT'
            ))
        OR (status <> 'CLOSED' AND closed_reason IS NULL)
    );

DROP INDEX IF EXISTS uq_orders_user_idem_key;
CREATE INDEX IF NOT EXISTS idx_orders_processing_deadline
    ON orders(processing_deadline_at, id) WHERE status = 'PROCESSING';
CREATE INDEX IF NOT EXISTS idx_orders_approval_deadline
    ON orders(approval_deadline_at, id) WHERE status = 'WAITING_APPROVAL';
CREATE INDEX IF NOT EXISTS idx_order_items_refund ON order_items(order_id, refund_status);
CREATE INDEX IF NOT EXISTS idx_disputes_status_deadline
    ON order_disputes(status, deadline_at, id);
CREATE INDEX IF NOT EXISTS idx_disputes_user_created
    ON order_disputes(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_disputes_shop_created
    ON order_disputes(shop_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_disputes_order_status
    ON order_disputes(order_id, status);
DELETE FROM product_reviews duplicate_review
USING product_reviews kept_review
WHERE duplicate_review.product_id = kept_review.product_id
  AND duplicate_review.user_id = kept_review.user_id
  AND duplicate_review.id > kept_review.id;
CREATE UNIQUE INDEX IF NOT EXISTS uq_product_reviews_product_user
    ON product_reviews(product_id, user_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_public
    ON product_reviews(product_id, created_at DESC) WHERE is_visible = TRUE;
CREATE INDEX IF NOT EXISTS idx_idempotency_expiry ON idempotency_keys(expires_at);

-- DB cũ có thể còn cột delivered_asset_data / shop_note trên pre_order_items:
-- giữ nguyên để đối soát, chuyển dữ liệu sang delivery_content xong thì DROP thủ công.

DROP TABLE IF EXISTS favorite_shops CASCADE;

-- ============================================================
-- SEED DATA
-- ============================================================

INSERT INTO roles (name, description) VALUES
    ('SUPER_ADMIN', 'Quyền cao nhất'),
    ('ADMIN',       'Quản trị viên'),
    ('SELLER',      'Người bán hàng'),
    ('BUYER',       'Người mua hàng')
ON CONFLICT (name) DO NOTHING;

-- Mỗi tài khoản chỉ giữ một role. Khi nâng cấp database cũ có nhiều role,
-- giữ role có quyền cao nhất theo thứ tự SUPER_ADMIN > ADMIN > SELLER > BUYER.
DELETE FROM user_roles lower_role
USING user_roles higher_role, roles lower_definition, roles higher_definition
WHERE lower_role.user_id = higher_role.user_id
  AND lower_role.role_id = lower_definition.id
  AND higher_role.role_id = higher_definition.id
  AND CASE lower_definition.name
        WHEN 'SUPER_ADMIN' THEN 4
        WHEN 'ADMIN' THEN 3
        WHEN 'SELLER' THEN 2
        WHEN 'BUYER' THEN 1
        ELSE 0
      END
      < CASE higher_definition.name
          WHEN 'SUPER_ADMIN' THEN 4
          WHEN 'ADMIN' THEN 3
          WHEN 'SELLER' THEN 2
          WHEN 'BUYER' THEN 1
          ELSE 0
        END;

CREATE UNIQUE INDEX IF NOT EXISTS uq_user_roles_one_role_per_user
    ON user_roles(user_id);

INSERT INTO level_configs (level, label, min_spent, allowed_product_count, description) VALUES
    (1, 'Đồng',      0,           5,   'Shop đăng tối đa 5 sản phẩm'),
    (2, 'Bạc',       5000000,     20,  'Shop đăng tối đa 20 sản phẩm'),
    (3, 'Vàng',      20000000,    100, 'Shop đăng tối đa 100 sản phẩm'),
    (4, 'Kim Cương', 100000000,   500, 'Shop đăng tối đa 500 sản phẩm')
ON CONFLICT (level) DO UPDATE SET
    allowed_product_count = EXCLUDED.allowed_product_count,
    label = EXCLUDED.label,
    min_spent = EXCLUDED.min_spent,
    description = EXCLUDED.description;

-- Danh mục cấp 1: chỉ dùng để gom nhóm và lọc toàn bộ danh mục con.
INSERT INTO categories (name, slug, sort_order, is_active, parent_id) VALUES
    ('Giải trí',          'giai-tri',        1,  true, NULL),
    ('AI & Công việc',    'ai-cong-viec',    2,  true, NULL),
    ('Trò chơi',          'tro-choi',        3,  true, NULL),
    ('Khác & tổng hợp',   'khac-tong-hop',   99, true, NULL)
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    sort_order = EXCLUDED.sort_order;

-- Danh mục cấp 2: sản phẩm bắt buộc gắn trực tiếp vào một danh mục cấp này.
-- Giữ nguyên các slug cũ để không làm mất liên kết của sản phẩm hiện có.
INSERT INTO categories (name, slug, sort_order, is_active) VALUES
    ('Netflix',         'netflix',          1,  true),
    ('Spotify',         'spotify',          2,  true),
    ('YouTube Premium', 'youtube-premium',  3,  true),
    ('ChatGPT Plus',    'chatgpt-plus',     1,  true),
    ('Canva Pro',       'canva-pro',        2,  true),
    ('Adobe Creative',  'adobe-creative',   3,  true),
    ('Microsoft 365',   'microsoft-365',    4,  true),
    ('Steam',           'steam',            1,  true),
    ('Game Account',    'game-account',     2,  true),
    ('Khác',            'other',            1,  true)
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    sort_order = EXCLUDED.sort_order;

UPDATE categories AS child
SET parent_id = parent.id
FROM categories AS parent
WHERE parent.slug = 'giai-tri'
  AND child.slug IN ('netflix', 'spotify', 'youtube-premium')
  AND child.parent_id IS DISTINCT FROM parent.id;

UPDATE categories AS child
SET parent_id = parent.id
FROM categories AS parent
WHERE parent.slug = 'ai-cong-viec'
  AND child.slug IN ('chatgpt-plus', 'canva-pro', 'adobe-creative', 'microsoft-365')
  AND child.parent_id IS DISTINCT FROM parent.id;

UPDATE categories AS child
SET parent_id = parent.id
FROM categories AS parent
WHERE parent.slug = 'tro-choi'
  AND child.slug IN ('steam', 'game-account')
  AND child.parent_id IS DISTINCT FROM parent.id;

UPDATE categories AS child
SET parent_id = parent.id
FROM categories AS parent
WHERE parent.slug = 'khac-tong-hop'
  AND child.slug = 'other'
  AND child.parent_id IS DISTINCT FROM parent.id;

INSERT INTO wallets (user_id, available_balance, hold_balance, status, is_platform, version, updated_at)
SELECT NULL, 0, 0, 'ACTIVE', true, 0, NOW()
WHERE NOT EXISTS (SELECT 1 FROM wallets WHERE is_platform = true)
ON CONFLICT (is_platform) WHERE is_platform = TRUE DO NOTHING;  -- chống race khi 2 tiến trình cùng seed

-- Fee 4% — cần ít nhất 1 user (FK created_by). Chạy lại sau khi có admin.
INSERT INTO platform_fee_configs
    (fee_rate, min_fee_amount, max_fee_amount, description, is_active, effective_from, created_by, created_at)
SELECT 0.0400, 0, NULL, 'Phí sàn mặc định 4% (v8)', true, NOW(), seed_user.id, NOW()
FROM (
    SELECT u.id FROM users u
    ORDER BY (EXISTS (
        SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id
        WHERE ur.user_id = u.id AND r.name IN ('ADMIN','SUPER_ADMIN')
    )) DESC, u.id ASC
    LIMIT 1
) seed_user
WHERE NOT EXISTS (SELECT 1 FROM platform_fee_configs WHERE is_active = true)
ON CONFLICT (is_active) WHERE is_active = TRUE DO NOTHING;  -- chống race khi 2 tiến trình cùng seed

COMMIT;

-- ============================================================
-- TỔNG KẾT LUỒNG TIỀN v8
-- ============================================================
-- A. NẠP TIỀN: VietQR → SePay Bank Webhook (HMAC + chống lặp) → DEPOSIT vào ví buyer
-- B. CHECKOUT (cart hoặc buy-now): luôn WALLET
--      buyer.available -= total
--      seller.hold     += total
--      mỗi item: snapshot fee (4%, CEILING) → HoldRelease + FeeLedger PENDING
-- C. PRE_ORDER: trừ ví NGAY lúc checkout; reject/cancel → hoàn tiền
-- D. T+7: seller.available += net; platform += fee; ledger COLLECTED
-- E. DISPUTE buyer win: refund buyer, cancel hold, ledger CANCELLED (không waive)
-- F. ĐỐI SOÁT (fee 4%, CEILING):
--      sale 19500 → fee 780, net 18720   (780 + 18720 = 19500)
--      sale 100   → fee 4,   net 96      (4 + 96 = 100)
--      subtotal 20000, voucher 400 → sale 19600 → fee 784, net 18816
--      (voucher 400 + net 18816 + fee 784 = 20000)
-- G. GIAO HÀNG (delivery_content):
--      INSTANT   : import TXT (1 dòng = 1 asset AVAILABLE) → mua: lock + RESERVED
--                  → thanh toán OK: snapshot nguyên văn vào asset_delivery_logs
--                  → asset SOLD; buyer xem lại TỪ delivery_content_snapshot (không đọc kho)
--      PRE_ORDER : PENDING → ACCEPTED (accepted_at) → PROCESSING
--                  → shop nhập delivery_content (+type) → DELIVERED (delivered_at)
--                  hoặc PENDING → REJECTED / CANCELLED (hoàn tiền)
--      BẢO MẬT   : không log nội dung; chỉ trả trong API chi tiết đơn (buyer sở hữu,
--                  shop bán — phục vụ bảo hành, admin); Cache-Control: no-store;
--                  không đưa nội dung vào URL; cân nhắc mã hóa at-rest (AES-GCM/pgcrypto)
-- ============================================================
