-- ============================================================
-- COMMERCEHUB — DỮ LIỆU TEST LOCAL
-- Chạy SAU schema-v8.sql. Có thể chạy lại mà không tạo trùng dữ liệu.
-- Tất cả tài khoản test dùng mật khẩu: Test@123456
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. TÀI KHOẢN TEST
-- ------------------------------------------------------------

INSERT INTO users (
    email, phone, username, password_hash, full_name, avatar_url,
    status, last_active_at, user_level, accumulated_spent,
    accumulated_earned, is_email_verified, is_phone_verified,
    provider, created_at, updated_at
) VALUES
    (
        'admin@commercehub.test', NULL, 'admin_demo',
        crypt('Test@123456', gen_salt('bf', 10)),
        'Quản trị viên Demo',
        'https://api.dicebear.com/9.x/initials/svg?seed=Admin%20Demo',
        'ACTIVE', NOW(), 4, 0, 0, true, false, 'LOCAL', NOW(), NOW()
    ),
    (
        'seller@commercehub.test', '0900000001', 'seller_demo',
        crypt('Test@123456', gen_salt('bf', 10)),
        'Nguyễn Văn Seller',
        'https://api.dicebear.com/9.x/initials/svg?seed=Seller%20Demo',
        'ACTIVE', NOW(), 2, 0, 0, true, true, 'LOCAL', NOW(), NOW()
    ),
    (
        'vpn.seller@commercehub.test', '0900000002', 'vpn_seller',
        crypt('Test@123456', gen_salt('bf', 10)),
        'Trần Văn VPN',
        'https://api.dicebear.com/9.x/initials/svg?seed=VPN%20Seller',
        'ACTIVE', NOW(), 2, 0, 0, true, true, 'LOCAL', NOW(), NOW()
    ),
    (
        'buyer@commercehub.test', '0900000003', 'buyer_demo',
        crypt('Test@123456', gen_salt('bf', 10)),
        'Lê Văn Buyer',
        'https://api.dicebear.com/9.x/initials/svg?seed=Buyer%20Demo',
        'ACTIVE', NOW(), 1, 0, 0, true, true, 'LOCAL', NOW(), NOW()
    )
ON CONFLICT (email) DO UPDATE SET
    password_hash = EXCLUDED.password_hash,
    full_name = EXCLUDED.full_name,
    avatar_url = EXCLUDED.avatar_url,
    status = 'ACTIVE',
    accumulated_spent = 0,
    accumulated_earned = 0,
    updated_at = NOW();

-- Mỗi tài khoản chỉ có một role. Role hierarchy giúp ADMIN mua/bán và SELLER mua hàng.
DELETE FROM user_roles
WHERE user_id IN (
    SELECT id FROM users
    WHERE username IN ('admin_demo', 'seller_demo', 'vpn_seller', 'buyer_demo')
);

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u
JOIN roles r ON (
       (u.username = 'admin_demo' AND r.name = 'ADMIN')
    OR (u.username IN ('seller_demo', 'vpn_seller') AND r.name = 'SELLER')
    OR (u.username = 'buyer_demo'  AND r.name = 'BUYER')
)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 2. VÍ VÀ CẤU HÌNH PHÍ
-- ------------------------------------------------------------

INSERT INTO wallets (
    user_id, available_balance, hold_balance, status,
    is_platform, version, created_at, updated_at
)
SELECT
    u.id,
    CASE u.username
        WHEN 'admin_demo'  THEN 500000
        WHEN 'seller_demo' THEN 3000000
        WHEN 'vpn_seller'  THEN 2000000
        WHEN 'buyer_demo'  THEN 10000000
    END,
    0,
    'ACTIVE', false, 0, NOW(), NOW()
FROM users u
WHERE u.username IN ('admin_demo', 'seller_demo', 'vpn_seller', 'buyer_demo')
ON CONFLICT (user_id) DO NOTHING;

-- Ví platform không thuộc user nào. Backend cũng tự khởi tạo ví này, nhưng seed
-- vẫn bảo đảm tồn tại để có thể chạy độc lập ngay sau schema-v8.sql.
INSERT INTO wallets (
    user_id, available_balance, hold_balance, status,
    is_platform, version, created_at, updated_at
)
SELECT NULL, 0, 0, 'ACTIVE', true, 0, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM wallets WHERE is_platform = true);

-- Sổ cái số dư mở đầu của các ví test. Dòng này chỉ mô tả nguồn tiền test ban
-- đầu; chạy lại seed không cộng tiền lần nữa.
INSERT INTO wallet_transactions (
    wallet_id, transaction_type, balance_type, amount,
    balance_before, balance_after, reference_id, reference_type,
    description, created_at
)
SELECT
    w.id, 'ADMIN_ADJUST', 'AVAILABLE', seed.opening_balance,
    0, seed.opening_balance, u.id, 'SEED_OPENING',
    'Số dư mở đầu dành riêng cho tài khoản kiểm thử',
    NOW() - INTERVAL '90 days'
FROM (
    VALUES
        ('admin_demo',  500000::NUMERIC),
        ('seller_demo', 3000000::NUMERIC),
        ('vpn_seller',  2000000::NUMERIC),
        ('buyer_demo', 10000000::NUMERIC)
) AS seed(username, opening_balance)
JOIN users u ON u.username = seed.username
JOIN wallets w ON w.user_id = u.id
WHERE NOT EXISTS (
    SELECT 1
    FROM wallet_transactions existing
    WHERE existing.wallet_id = w.id
      AND existing.reference_type = 'SEED_OPENING'
      AND existing.reference_id = u.id
);

INSERT INTO platform_fee_configs (
    fee_rate, min_fee_amount, max_fee_amount, description,
    is_active, effective_from, created_by, created_at
)
SELECT 0.0400, 0, NULL, 'Phí sàn test mặc định 4%',
       true, NOW(), u.id, NOW()
FROM users u
WHERE u.username = 'admin_demo'
  AND NOT EXISTS (
      SELECT 1 FROM platform_fee_configs WHERE is_active = true
  );

-- ------------------------------------------------------------
-- 3. SHOP TEST
-- ------------------------------------------------------------

INSERT INTO shops (
    owner_id, name, slug, shop_avatar_url, shop_cover_url,
    description, total_orders, total_disputes, dispute_rate,
    status, rating_avg, created_at, updated_at
)
SELECT
    u.id, 'CommerceHub Demo Store', 'commercehub-demo-store',
    'https://api.dicebear.com/9.x/initials/svg?seed=CommerceHub%20Store',
    'https://images.unsplash.com/photo-1497366811353-6870744d04b2?auto=format&fit=crop&w=1600&q=80',
    'Gian hàng dữ liệu mẫu dùng để kiểm tra sản phẩm giao ngay và đặt trước.',
    0, 0, 0, 'ACTIVE', 5.00, NOW() - INTERVAL '8 months', NOW()
FROM users u
WHERE u.username = 'seller_demo'
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    status = 'ACTIVE',
    updated_at = NOW();

INSERT INTO shops (
    owner_id, name, slug, shop_avatar_url, shop_cover_url,
    description, total_orders, total_disputes, dispute_rate,
    status, rating_avg, created_at, updated_at
)
SELECT
    u.id, 'VPN Test Store', 'vpn-test-store',
    'https://api.dicebear.com/9.x/initials/svg?seed=VPN%20Store',
    'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?auto=format&fit=crop&w=1600&q=80',
    'Gian hàng VPN mẫu để kiểm tra profile và thống kê mua bán chéo.',
    0, 0, 0, 'ACTIVE', 5.00, NOW() - INTERVAL '5 months', NOW()
FROM users u
WHERE u.username = 'vpn_seller'
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    status = 'ACTIVE',
    updated_at = NOW();

-- ------------------------------------------------------------
-- 4. SẢN PHẨM: MỖI SẢN PHẨM CHỈ CÓ MỘT thumbnail_url
-- ------------------------------------------------------------

INSERT INTO products (
    shop_id, category_id, name, slug, thumbnail_url,
    short_description, description, product_type, delivery_type,
    status, sold_count, failed_dispute_count, created_at, updated_at
)
SELECT
    s.id, c.id, seed.name, seed.slug, seed.thumbnail_url,
    seed.short_description, seed.description, seed.product_type,
    seed.delivery_type, 'ACTIVE', seed.sold_count, 0,
    NOW() - seed.age, NOW()
FROM (
    VALUES
        (
            'commercehub-demo-store', 'chatgpt-plus',
            'ChatGPT Plus chính chủ', 'chatgpt-plus-demo',
            'https://images.unsplash.com/photo-1677442136019-21780ecad995?auto=format&fit=crop&w=1200&q=85',
            'Tài khoản ChatGPT Plus dành cho học tập và công việc.',
            'Tài khoản được kiểm tra trước khi giao. Chọn thời hạn phù hợp ở phần biến thể.',
            'ACCOUNT', 'INSTANT', 0::BIGINT, INTERVAL '60 days'
        ),
        (
            'commercehub-demo-store', 'netflix',
            'Netflix Premium 4K', 'netflix-premium-demo',
            'https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?auto=format&fit=crop&w=1200&q=85',
            'Tài khoản xem phim Netflix chất lượng cao.',
            'Giao tài khoản tự động sau khi thanh toán thành công.',
            'ACCOUNT', 'INSTANT', 0::BIGINT, INTERVAL '45 days'
        ),
        (
            'commercehub-demo-store', 'adobe-creative',
            'CapCut Pro bản quyền', 'capcut-pro-demo',
            'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=1200&q=85',
            'CapCut Pro phục vụ chỉnh sửa video.',
            'Sản phẩm giao ngay, có nhiều gói thời hạn và hỗ trợ trong thời gian sử dụng.',
            'ACCOUNT', 'INSTANT', 0::BIGINT, INTERVAL '30 days'
        ),
        (
            'commercehub-demo-store', 'canva-pro',
            'Canva Pro nâng cấp chính chủ', 'canva-pro-demo',
            'https://images.unsplash.com/photo-1558655146-d09347e92766?auto=format&fit=crop&w=1200&q=85',
            'Nâng cấp Canva Pro theo email của người mua.',
            'Đây là sản phẩm đặt trước. Shop xử lý thủ công sau khi nhận email Canva của khách.',
            'ACCOUNT', 'PRE_ORDER', 0::BIGINT, INTERVAL '20 days'
        ),
        (
            'vpn-test-store', 'other',
            'NordVPN tốc độ cao', 'nordvpn-demo',
            'https://images.unsplash.com/photo-1563013544-824ae1b704d3?auto=format&fit=crop&w=1200&q=85',
            'Tài khoản VPN hỗ trợ nhiều thiết bị.',
            'Tài khoản test phục vụ kiểm tra trang chi tiết và mua bán chéo giữa hai shop.',
            'OTHER', 'INSTANT', 0::BIGINT, INTERVAL '25 days'
        )
) AS seed(
    shop_slug, category_slug, name, slug, thumbnail_url,
    short_description, description, product_type, delivery_type,
    sold_count, age
)
JOIN shops s ON s.slug = seed.shop_slug
JOIN categories c ON c.slug = seed.category_slug
ON CONFLICT (slug) DO UPDATE SET
    shop_id = EXCLUDED.shop_id,
    category_id = EXCLUDED.category_id,
    name = EXCLUDED.name,
    thumbnail_url = EXCLUDED.thumbnail_url,
    short_description = EXCLUDED.short_description,
    description = EXCLUDED.description,
    product_type = EXCLUDED.product_type,
    delivery_type = EXCLUDED.delivery_type,
    status = 'ACTIVE',
    sold_count = EXCLUDED.sold_count,
    updated_at = NOW();

-- ------------------------------------------------------------
-- 5. BIẾN THỂ: KHÔNG CÓ ẢNH, KHÔNG TRÙNG TÊN TRONG MỘT SẢN PHẨM
-- ------------------------------------------------------------

INSERT INTO product_variants (
    product_id, name, duration_days, price, sort_order, status, stock_count
)
SELECT p.id, seed.variant_name, seed.duration_days, seed.price,
       seed.sort_order, 'ACTIVE', 0
FROM (
    VALUES
        ('chatgpt-plus-demo',    'Gói 1 tháng',  30,  199000::NUMERIC, 1),
        ('chatgpt-plus-demo',    'Gói 3 tháng',  90,  549000::NUMERIC, 2),
        ('netflix-premium-demo', 'Gói tiêu chuẩn', 30, 79000::NUMERIC, 1),
        ('netflix-premium-demo', 'Gói Premium', 30, 129000::NUMERIC, 2),
        ('capcut-pro-demo',      'Gói 1 tháng',  30,   45000::NUMERIC, 1),
        ('capcut-pro-demo',      'Gói 1 năm',   365,  399000::NUMERIC, 2),
        ('canva-pro-demo',       'Nâng cấp 1 năm', 365, 149000::NUMERIC, 1),
        ('nordvpn-demo',         'Gói 1 tháng',  30,   80000::NUMERIC, 1),
        ('nordvpn-demo',         'Gói 1 năm',   365,  599000::NUMERIC, 2)
) AS seed(product_slug, variant_name, duration_days, price, sort_order)
JOIN products p ON p.slug = seed.product_slug
WHERE NOT EXISTS (
    SELECT 1
    FROM product_variants existing
    WHERE existing.product_id = p.id
      AND LOWER(BTRIM(existing.name)) = LOWER(BTRIM(seed.variant_name))
);

-- Kho giả cho các sản phẩm giao ngay: mỗi variant có 5 tài khoản test.
INSERT INTO digital_assets (
    product_variant_id, asset_type, delivery_content, asset_data,
    asset_identifier, status, is_delivered, created_at, updated_at
)
SELECT
    v.id,
    CASE WHEN p.product_type = 'OTHER' THEN 'OTHER' ELSE 'ACCOUNT' END,
    FORMAT('seed-%s-%s@example.test|TestPass!%s', p.slug, v.id, series.asset_no),
    jsonb_build_object('seed', true, 'product', p.slug, 'variant', v.name)::TEXT,
    FORMAT('SEED-%s-%s-%s', p.slug, v.id, series.asset_no),
    'AVAILABLE', false, NOW(), NOW()
FROM products p
JOIN product_variants v ON v.product_id = p.id
CROSS JOIN generate_series(1, 5) AS series(asset_no)
WHERE p.delivery_type = 'INSTANT'
  AND p.slug IN (
      'chatgpt-plus-demo', 'netflix-premium-demo',
      'capcut-pro-demo', 'nordvpn-demo'
  )
  AND NOT EXISTS (
      SELECT 1
      FROM digital_assets existing
      WHERE existing.asset_identifier =
            FORMAT('SEED-%s-%s-%s', p.slug, v.id, series.asset_no)
  );

-- Đồng bộ tồn kho hiển thị với số asset AVAILABLE thực tế.
UPDATE product_variants v
SET stock_count = stock.available_count
FROM (
    SELECT product_variant_id, COUNT(*)::INT AS available_count
    FROM digital_assets
    WHERE status = 'AVAILABLE'
    GROUP BY product_variant_id
) stock
WHERE v.id = stock.product_variant_id;

-- Cấu hình cho sản phẩm đặt trước Canva.
INSERT INTO pre_order_configs (
    product_id, max_processing_hours, order_instructions,
    buyer_input_fields, auto_reject_if_unavailable,
    created_at, updated_at
)
SELECT
    p.id, 24,
    'Nhập email Canva cần nâng cấp. Không gửi mật khẩu email.',
    '{"fields":[{"name":"canvaEmail","label":"Email Canva","required":true}]}'::JSONB,
    true, NOW(), NOW()
FROM products p
WHERE p.slug = 'canva-pro-demo'
ON CONFLICT (product_id) DO UPDATE SET
    max_processing_hours = EXCLUDED.max_processing_hours,
    order_instructions = EXCLUDED.order_instructions,
    buyer_input_fields = EXCLUDED.buyer_input_fields,
    auto_reject_if_unavailable = EXCLUDED.auto_reject_if_unavailable,
    updated_at = NOW();

-- ------------------------------------------------------------
-- 6. VOUCHER VÀ GIỎ HÀNG TEST
-- ------------------------------------------------------------

INSERT INTO vouchers (
    shop_id, code, description, discount_type, discount_value,
    max_discount_amount, min_order_amount, apply_all_products,
    starts_at, expires_at, usage_limit, used_count, is_active,
    created_at, updated_at
)
SELECT
    s.id, 'TEST10', 'Giảm 10% cho dữ liệu test', 'PERCENT', 10,
    50000, 50000, true,
    NOW() - INTERVAL '1 day', NOW() + INTERVAL '90 days',
    100, 0, true, NOW(), NOW()
FROM shops s
WHERE s.slug = 'commercehub-demo-store'
ON CONFLICT (shop_id, code) DO UPDATE SET
    starts_at = EXCLUDED.starts_at,
    expires_at = EXCLUDED.expires_at,
    is_active = true,
    updated_at = NOW();

INSERT INTO carts (user_id, created_at, updated_at)
SELECT u.id, NOW(), NOW()
FROM users u
WHERE u.username = 'buyer_demo'
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO cart_items (
    cart_id, product_variant_id, quantity, created_at, updated_at
)
SELECT c.id, v.id, 1, NOW(), NOW()
FROM carts c
JOIN users u ON u.id = c.user_id AND u.username = 'buyer_demo'
JOIN products p ON p.slug = 'chatgpt-plus-demo'
JOIN product_variants v
  ON v.product_id = p.id AND v.name = 'Gói 1 tháng'
ON CONFLICT (cart_id, product_variant_id) DO NOTHING;

-- ------------------------------------------------------------
-- 7. BỐN ĐƠN ĐÃ GIAO VÀ QUYẾT TOÁN THẬT
-- 001: buyer_demo mua Netflix từ seller_demo (INSTANT)
-- 002: seller_demo mua NordVPN từ vpn_seller (INSTANT)
-- 003: vpn_seller mua ChatGPT từ seller_demo (INSTANT)
-- 004: buyer_demo mua Canva từ seller_demo (PRE_ORDER)
-- Mỗi đơn có đầy đủ item, hold RELEASED, fee COLLECTED, giao dịch ví và log.
-- ------------------------------------------------------------

INSERT INTO orders (
    order_code, user_id, shop_id, delivery_type, status,
    payment_status, payment_method, subtotal_amount, total_amount,
    placed_at, delivered_at, created_at, updated_at
)
SELECT
    seed.order_code, buyer.id, p.shop_id, p.delivery_type,
    'DELIVERED', 'PAID', 'WALLET', v.price, v.price,
    NOW() - INTERVAL '15 days', NOW() - INTERVAL '14 days',
    NOW() - INTERVAL '15 days', NOW() - INTERVAL '14 days'
FROM (
    VALUES
        ('SEED-ORDER-001', 'buyer_demo',  'netflix-premium-demo', 'Gói tiêu chuẩn'),
        ('SEED-ORDER-002', 'seller_demo', 'nordvpn-demo',         'Gói 1 tháng'),
        ('SEED-ORDER-003', 'vpn_seller',  'chatgpt-plus-demo',    'Gói 1 tháng'),
        ('SEED-ORDER-004', 'buyer_demo',  'canva-pro-demo',       'Nâng cấp 1 năm')
) AS seed(order_code, buyer_username, product_slug, variant_name)
JOIN users buyer ON buyer.username = seed.buyer_username
JOIN products p ON p.slug = seed.product_slug
JOIN product_variants v
  ON v.product_id = p.id AND v.name = seed.variant_name
ON CONFLICT (order_code) DO NOTHING;

INSERT INTO order_items (
    order_id, product_variant_id, product_name, variant_name,
    product_type, delivery_type, unit_price, quantity, line_total,
    fee_config_id, fee_rate_snapshot, fee_amount, seller_net_amount,
    created_at
)
SELECT
    o.id, v.id, p.name, v.name, p.product_type, p.delivery_type,
    v.price, 1, v.price,
    fee.id, fee.fee_rate,
    CEIL(v.price * fee.fee_rate),
    v.price - CEIL(v.price * fee.fee_rate),
    o.created_at
FROM (
    VALUES
        ('SEED-ORDER-001', 'netflix-premium-demo', 'Gói tiêu chuẩn'),
        ('SEED-ORDER-002', 'nordvpn-demo',         'Gói 1 tháng'),
        ('SEED-ORDER-003', 'chatgpt-plus-demo',    'Gói 1 tháng'),
        ('SEED-ORDER-004', 'canva-pro-demo',       'Nâng cấp 1 năm')
) AS seed(order_code, product_slug, variant_name)
JOIN orders o ON o.order_code = seed.order_code
JOIN products p ON p.slug = seed.product_slug
JOIN product_variants v
  ON v.product_id = p.id AND v.name = seed.variant_name
CROSS JOIN LATERAL (
    SELECT id, fee_rate
    FROM platform_fee_configs
    WHERE is_active = true
    ORDER BY effective_from DESC
    LIMIT 1
) fee
WHERE NOT EXISTS (
    SELECT 1 FROM order_items existing WHERE existing.order_id = o.id
);

INSERT INTO platform_fee_ledgers (
    order_item_id, order_id, shop_id, seller_wallet_id,
    fee_config_id, fee_rate_snapshot, sale_amount, fee_amount,
    seller_net_amount, status, fee_incurred_at, collected_at,
    created_at, updated_at
)
SELECT
    oi.id, o.id, o.shop_id, seller_wallet.id,
    oi.fee_config_id, oi.fee_rate_snapshot, oi.line_total,
    oi.fee_amount, oi.seller_net_amount,
    'COLLECTED', o.created_at, o.delivered_at, o.created_at, o.updated_at
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
JOIN shops s ON s.id = o.shop_id
JOIN wallets seller_wallet ON seller_wallet.user_id = s.owner_id
WHERE o.order_code IN ('SEED-ORDER-001', 'SEED-ORDER-002', 'SEED-ORDER-003', 'SEED-ORDER-004')
  AND NOT EXISTS (
      SELECT 1 FROM platform_fee_ledgers existing
      WHERE existing.order_item_id = oi.id
  );

INSERT INTO hold_releases (
    wallet_id, order_id, order_item_id, hold_amount,
    fee_amount, seller_net_amount, fee_ledger_id, status,
    scheduled_release_at, released_at, created_at
)
SELECT
    ledger.seller_wallet_id, ledger.order_id, ledger.order_item_id,
    ledger.sale_amount, ledger.fee_amount, ledger.seller_net_amount,
    ledger.id, 'RELEASED',
    o.delivered_at + INTERVAL '7 days',
    o.delivered_at + INTERVAL '7 days', o.created_at
FROM platform_fee_ledgers ledger
JOIN orders o ON o.id = ledger.order_id
WHERE o.order_code IN ('SEED-ORDER-001', 'SEED-ORDER-002', 'SEED-ORDER-003', 'SEED-ORDER-004')
  AND NOT EXISTS (
      SELECT 1 FROM hold_releases existing
      WHERE existing.order_item_id = ledger.order_item_id
  );

UPDATE platform_fee_ledgers ledger
SET hold_release_id = hold.id,
    updated_at = NOW()
FROM hold_releases hold
WHERE hold.fee_ledger_id = ledger.id
  AND ledger.hold_release_id IS NULL;

-- Hoàn thiện vòng đời riêng của đơn PRE_ORDER.
UPDATE orders
SET approved_at = COALESCE(approved_at, placed_at + INTERVAL '1 hour'),
    approval_deadline_at = COALESCE(approval_deadline_at, placed_at + INTERVAL '48 hours'),
    processing_deadline_at = COALESCE(processing_deadline_at, placed_at + INTERVAL '25 hours'),
    updated_at = delivered_at
WHERE order_code = 'SEED-ORDER-004';

INSERT INTO pre_order_items (
    order_item_id, buyer_inputs, buyer_note, status,
    delivery_content, delivery_content_type, seller_notes,
    accepted_at, delivered_at, completed_at, created_at, updated_at
)
SELECT
    oi.id,
    '{"canvaEmail":"buyer.demo@commercehub.test"}',
    'Đơn test luồng đặt trước',
    'DELIVERED',
    'Canva Pro đã được nâng cấp cho buyer.demo@commercehub.test',
    'MESSAGE',
    'Seed: shop đã xử lý và giao thành công',
    o.approved_at, o.delivered_at, o.delivered_at,
    o.created_at, o.updated_at
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
WHERE o.order_code = 'SEED-ORDER-004'
  AND NOT EXISTS (
      SELECT 1 FROM pre_order_items existing
      WHERE existing.order_item_id = oi.id
  );

-- Log trạng thái thật của ba đơn giao ngay.
INSERT INTO order_status_logs (
    order_id, from_status, to_status, changed_by, note, meta, created_at
)
SELECT
    o.id, NULL, 'DELIVERED', o.user_id,
    'Seed: thanh toán ví và giao tài sản tức thì thành công',
    jsonb_build_object('seed', true, 'deliveryType', 'INSTANT'),
    o.delivered_at
FROM orders o
WHERE o.order_code IN ('SEED-ORDER-001', 'SEED-ORDER-002', 'SEED-ORDER-003')
  AND NOT EXISTS (
      SELECT 1 FROM order_status_logs existing
      WHERE existing.order_id = o.id AND existing.to_status = 'DELIVERED'
  );

-- Log đủ WAITING_APPROVAL -> PROCESSING -> DELIVERED cho đơn đặt trước.
INSERT INTO order_status_logs (
    order_id, from_status, to_status, changed_by, note, meta, created_at
)
SELECT
    o.id,
    flow.from_status,
    flow.to_status,
    CASE WHEN flow.step_no = 1 THEN o.user_id ELSE s.owner_id END,
    flow.note,
    jsonb_build_object('seed', true, 'deliveryType', 'PRE_ORDER'),
    o.created_at + flow.age
FROM orders o
JOIN shops s ON s.id = o.shop_id
CROSS JOIN (
    VALUES
        (1, NULL::VARCHAR,       'WAITING_APPROVAL'::VARCHAR, 'Seed: buyer đã thanh toán, chờ shop duyệt', INTERVAL '0 minute'),
        (2, 'WAITING_APPROVAL',  'PROCESSING',                'Seed: shop đã nhận xử lý đơn',             INTERVAL '1 hour'),
        (3, 'PROCESSING',        'DELIVERED',                 'Seed: shop đã giao hàng thành công',       INTERVAL '1 day')
) AS flow(step_no, from_status, to_status, note, age)
WHERE o.order_code = 'SEED-ORDER-004'
  AND NOT EXISTS (
      SELECT 1 FROM order_status_logs existing
      WHERE existing.order_id = o.id
        AND existing.to_status = flow.to_status
  );

-- Mỗi đơn INSTANT lấy đúng một asset AVAILABLE, đánh dấu SOLD và gắn vào item.
WITH target_items AS (
    SELECT
        oi.id AS order_item_id,
        o.delivered_at,
        (
            SELECT da.id
            FROM digital_assets da
            WHERE da.product_variant_id = oi.product_variant_id
              AND da.status = 'AVAILABLE'
            ORDER BY da.id
            LIMIT 1
        ) AS asset_id
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.id
    WHERE o.order_code IN ('SEED-ORDER-001', 'SEED-ORDER-002', 'SEED-ORDER-003')
      AND NOT EXISTS (
          SELECT 1 FROM digital_assets assigned
          WHERE assigned.order_item_id = oi.id
      )
)
UPDATE digital_assets asset
SET status = 'SOLD',
    order_item_id = target.order_item_id,
    is_delivered = true,
    delivered_at = target.delivered_at,
    updated_at = NOW()
FROM target_items target
WHERE asset.id = target.asset_id;

-- Snapshot cố định nội dung đã giao, giống AssetDeliveryService của backend.
INSERT INTO asset_delivery_logs (
    asset_id, order_item_id, buyer_id,
    delivery_content_snapshot, asset_data_snapshot,
    delivery_method, status, delivered_at
)
SELECT
    asset.id, oi.id, o.user_id,
    COALESCE(NULLIF(asset.delivery_content, ''), asset.asset_data),
    jsonb_build_object('raw', COALESCE(asset.asset_data, '')),
    'AUTO', 'SUCCESS', o.delivered_at
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
JOIN digital_assets asset ON asset.order_item_id = oi.id
WHERE o.order_code IN ('SEED-ORDER-001', 'SEED-ORDER-002', 'SEED-ORDER-003')
  AND NOT EXISTS (
      SELECT 1 FROM asset_delivery_logs existing
      WHERE existing.asset_id = asset.id
        AND existing.order_item_id = oi.id
  );

-- Audit việc phí sàn đã được thu sau khi hết T+7.
INSERT INTO platform_fee_logs (
    fee_ledger_id, from_status, to_status, fee_amount,
    changed_by, reason, meta, created_at
)
SELECT
    ledger.id, 'PENDING', 'COLLECTED', ledger.fee_amount,
    NULL, 'Seed: thu phí tự động sau khi hết thời gian hold',
    jsonb_build_object('seed', true, 'holdReleaseId', hold.id),
    ledger.collected_at
FROM platform_fee_ledgers ledger
JOIN hold_releases hold ON hold.id = ledger.hold_release_id
JOIN orders o ON o.id = ledger.order_id
WHERE o.order_code IN ('SEED-ORDER-001', 'SEED-ORDER-002', 'SEED-ORDER-003', 'SEED-ORDER-004')
  AND NOT EXISTS (
      SELECT 1 FROM platform_fee_logs existing
      WHERE existing.fee_ledger_id = ledger.id
        AND existing.to_status = 'COLLECTED'
  );

-- Áp dụng chuyển động tiền đúng như WalletService. Marker ORDER_PAYMENT làm cho
-- block này idempotent: mỗi đơn seed chỉ tác động số dư đúng một lần.
DO $$
DECLARE
    item RECORD;
    buyer_before NUMERIC(18,2);
    seller_hold_before NUMERIC(18,2);
    seller_available_before NUMERIC(18,2);
    platform_before NUMERIC(18,2);
    platform_wallet_id BIGINT;
BEGIN
    SELECT id INTO platform_wallet_id
    FROM wallets
    WHERE is_platform = true;

    FOR item IN
        SELECT
            o.id AS order_id,
            o.total_amount,
            o.user_id AS buyer_id,
            buyer_wallet.id AS buyer_wallet_id,
            seller_wallet.id AS seller_wallet_id,
            hold.id AS hold_release_id,
            oi.seller_net_amount,
            oi.fee_amount
        FROM orders o
        JOIN order_items oi ON oi.order_id = o.id
        JOIN shops shop ON shop.id = o.shop_id
        JOIN wallets buyer_wallet ON buyer_wallet.user_id = o.user_id
        JOIN wallets seller_wallet ON seller_wallet.user_id = shop.owner_id
        JOIN hold_releases hold ON hold.order_item_id = oi.id
        WHERE o.order_code IN ('SEED-ORDER-001', 'SEED-ORDER-002', 'SEED-ORDER-003', 'SEED-ORDER-004')
        ORDER BY o.id
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM wallet_transactions tx
            WHERE tx.wallet_id = item.buyer_wallet_id
              AND tx.transaction_type = 'ORDER_PAYMENT'
              AND tx.reference_type = 'ORDER'
              AND tx.reference_id = item.order_id
        ) THEN
            SELECT available_balance INTO buyer_before
            FROM wallets WHERE id = item.buyer_wallet_id FOR UPDATE;

            IF buyer_before < item.total_amount THEN
                RAISE EXCEPTION 'Ví buyer không đủ tiền để tạo đơn seed %, cần %, hiện có %',
                    item.order_id, item.total_amount, buyer_before;
            END IF;

            UPDATE wallets
            SET available_balance = buyer_before - item.total_amount,
                version = version + 1,
                updated_at = NOW()
            WHERE id = item.buyer_wallet_id;

            INSERT INTO wallet_transactions (
                wallet_id, transaction_type, balance_type, amount,
                balance_before, balance_after, reference_id, reference_type,
                description, created_at
            ) VALUES (
                item.buyer_wallet_id, 'ORDER_PAYMENT', 'AVAILABLE', -item.total_amount,
                buyer_before, buyer_before - item.total_amount,
                item.order_id, 'ORDER', 'Seed: buyer thanh toán đơn hàng', NOW()
            );

            SELECT hold_balance INTO seller_hold_before
            FROM wallets WHERE id = item.seller_wallet_id FOR UPDATE;

            UPDATE wallets
            SET hold_balance = seller_hold_before + item.total_amount,
                version = version + 1,
                updated_at = NOW()
            WHERE id = item.seller_wallet_id;

            INSERT INTO wallet_transactions (
                wallet_id, transaction_type, balance_type, amount,
                balance_before, balance_after, reference_id, reference_type,
                description, created_at
            ) VALUES (
                item.seller_wallet_id, 'SALE_HOLD', 'HOLD', item.total_amount,
                seller_hold_before, seller_hold_before + item.total_amount,
                item.order_id, 'ORDER', 'Seed: giữ tiền bán hàng T+7', NOW()
            );

            UPDATE wallets
            SET hold_balance = seller_hold_before,
                version = version + 1,
                updated_at = NOW()
            WHERE id = item.seller_wallet_id;

            INSERT INTO wallet_transactions (
                wallet_id, transaction_type, balance_type, amount,
                balance_before, balance_after, reference_id, reference_type,
                description, created_at
            ) VALUES (
                item.seller_wallet_id, 'HOLD_RELEASE', 'HOLD', -item.total_amount,
                seller_hold_before + item.total_amount, seller_hold_before,
                item.hold_release_id, 'HOLD_RELEASE', 'Seed: hết T+7, giải phóng tiền hold', NOW()
            );

            SELECT available_balance INTO seller_available_before
            FROM wallets WHERE id = item.seller_wallet_id FOR UPDATE;

            UPDATE wallets
            SET available_balance = seller_available_before + item.seller_net_amount,
                version = version + 1,
                updated_at = NOW()
            WHERE id = item.seller_wallet_id;

            INSERT INTO wallet_transactions (
                wallet_id, transaction_type, balance_type, amount,
                balance_before, balance_after, reference_id, reference_type,
                description, created_at
            ) VALUES (
                item.seller_wallet_id, 'HOLD_RELEASE_NET', 'AVAILABLE', item.seller_net_amount,
                seller_available_before, seller_available_before + item.seller_net_amount,
                item.hold_release_id, 'HOLD_RELEASE', 'Seed: tiền thực nhận của seller', NOW()
            );

            SELECT available_balance INTO platform_before
            FROM wallets WHERE id = platform_wallet_id FOR UPDATE;

            UPDATE wallets
            SET available_balance = platform_before + item.fee_amount,
                version = version + 1,
                updated_at = NOW()
            WHERE id = platform_wallet_id;

            INSERT INTO wallet_transactions (
                wallet_id, transaction_type, balance_type, amount,
                balance_before, balance_after, reference_id, reference_type,
                description, created_at
            ) VALUES (
                platform_wallet_id, 'PLATFORM_FEE', 'AVAILABLE', item.fee_amount,
                platform_before, platform_before + item.fee_amount,
                item.hold_release_id, 'FEE_LEDGER', 'Seed: phí sàn đã quyết toán', NOW()
            );
        END IF;
    END LOOP;
END $$;

-- Đánh giá thật gắn với đúng order_item đã mua.
INSERT INTO product_reviews (
    product_id, order_item_id, user_id, rating,
    comment, is_visible, created_at, updated_at
)
SELECT
    p.id, oi.id, o.user_id, review.rating,
    review.comment, true,
    NOW() - INTERVAL '10 days', NOW() - INTERVAL '10 days'
FROM (
    VALUES
        ('SEED-ORDER-001', 5, 'Netflix được giao ngay, thông tin đăng nhập hoạt động tốt.'),
        ('SEED-ORDER-002', 4, 'VPN hoạt động ổn định và đúng gói đã chọn.'),
        ('SEED-ORDER-003', 5, 'Tài khoản ChatGPT được giao nhanh, sử dụng bình thường.'),
        ('SEED-ORDER-004', 5, 'Shop nâng cấp Canva đúng email và đúng thời gian cam kết.')
) AS review(order_code, rating, comment)
JOIN orders o ON o.order_code = review.order_code
JOIN order_items oi ON oi.order_id = o.id
JOIN product_variants v ON v.id = oi.product_variant_id
JOIN products p ON p.id = v.product_id
WHERE NOT EXISTS (
      SELECT 1 FROM product_reviews existing
      WHERE existing.order_item_id = oi.id
  );

-- Tổng hợp phí tháng từ ledger COLLECTED (cùng công thức ShopFeeSummaryService).
INSERT INTO shop_fee_summaries (
    shop_id, period_year, period_month,
    total_sales, total_fee, total_net, total_refunded,
    order_count, dispute_count, updated_at
)
SELECT
    ledger.shop_id,
    EXTRACT(YEAR FROM ledger.fee_incurred_at)::INT,
    EXTRACT(MONTH FROM ledger.fee_incurred_at)::INT,
    SUM(ledger.sale_amount),
    SUM(ledger.fee_amount),
    SUM(ledger.seller_net_amount),
    0, COUNT(*)::INT, 0, NOW()
FROM platform_fee_ledgers ledger
WHERE ledger.status = 'COLLECTED'
  AND ledger.shop_id IN (
      SELECT id FROM shops
      WHERE slug IN ('commercehub-demo-store', 'vpn-test-store')
  )
GROUP BY ledger.shop_id,
         EXTRACT(YEAR FROM ledger.fee_incurred_at),
         EXTRACT(MONTH FROM ledger.fee_incurred_at)
ON CONFLICT (shop_id, period_year, period_month) DO UPDATE SET
    total_sales = EXCLUDED.total_sales,
    total_fee = EXCLUDED.total_fee,
    total_net = EXCLUDED.total_net,
    total_refunded = EXCLUDED.total_refunded,
    order_count = EXCLUDED.order_count,
    dispute_count = EXCLUDED.dispute_count,
    updated_at = NOW();

-- Các chỉ số hiển thị được TÍNH TỪ đơn đã giao + thanh toán + mọi item RELEASED.
-- Không còn gán sold_count / số mua / số bán giả.
UPDATE products
SET sold_count = 0,
    updated_at = NOW()
WHERE slug IN (
    'chatgpt-plus-demo', 'netflix-premium-demo', 'capcut-pro-demo',
    'canva-pro-demo', 'nordvpn-demo'
);

WITH completed_items AS (
    SELECT oi.id, oi.product_variant_id, oi.quantity
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.id
    WHERE o.status = 'DELIVERED'
      AND o.payment_status = 'PAID'
      AND NOT EXISTS (
          SELECT 1
          FROM order_items every_item
          WHERE every_item.order_id = o.id
            AND NOT EXISTS (
                SELECT 1 FROM hold_releases hr
                WHERE hr.order_item_id = every_item.id
                  AND hr.status = 'RELEASED'
            )
      )
), product_sales AS (
    SELECT variant.product_id, SUM(item.quantity)::BIGINT AS sold_quantity
    FROM completed_items item
    JOIN product_variants variant ON variant.id = item.product_variant_id
    GROUP BY variant.product_id
)
UPDATE products product
SET sold_count = sales.sold_quantity,
    updated_at = NOW()
FROM product_sales sales
WHERE product.id = sales.product_id;

UPDATE shops
SET total_orders = 0,
    updated_at = NOW()
WHERE slug IN ('commercehub-demo-store', 'vpn-test-store');

WITH completed_orders AS (
    SELECT o.id, o.shop_id
    FROM orders o
    WHERE o.status = 'DELIVERED'
      AND o.payment_status = 'PAID'
      AND EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.id)
      AND NOT EXISTS (
          SELECT 1
          FROM order_items oi
          WHERE oi.order_id = o.id
            AND NOT EXISTS (
                SELECT 1 FROM hold_releases hr
                WHERE hr.order_item_id = oi.id
                  AND hr.status = 'RELEASED'
            )
      )
), shop_sales AS (
    SELECT shop_id, COUNT(*)::INT AS total_orders
    FROM completed_orders
    GROUP BY shop_id
)
UPDATE shops shop
SET total_orders = sales.total_orders,
    updated_at = NOW()
FROM shop_sales sales
WHERE shop.id = sales.shop_id;

UPDATE users
SET accumulated_spent = 0,
    accumulated_earned = 0,
    updated_at = NOW()
WHERE username IN ('admin_demo', 'seller_demo', 'vpn_seller', 'buyer_demo');

WITH completed_orders AS (
    SELECT o.id, o.user_id, o.shop_id, o.total_amount
    FROM orders o
    WHERE o.status = 'DELIVERED'
      AND o.payment_status = 'PAID'
      AND EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.id)
      AND NOT EXISTS (
          SELECT 1
          FROM order_items oi
          WHERE oi.order_id = o.id
            AND NOT EXISTS (
                SELECT 1 FROM hold_releases hr
                WHERE hr.order_item_id = oi.id
                  AND hr.status = 'RELEASED'
            )
      )
), buyer_totals AS (
    SELECT user_id, SUM(total_amount) AS spent
    FROM completed_orders
    GROUP BY user_id
), seller_totals AS (
    SELECT shop.owner_id, SUM(oi.seller_net_amount) AS earned
    FROM completed_orders completed
    JOIN order_items oi ON oi.order_id = completed.id
    JOIN shops shop ON shop.id = completed.shop_id
    GROUP BY shop.owner_id
)
UPDATE users account
SET accumulated_spent = COALESCE(buyer.spent, 0),
    accumulated_earned = COALESCE(seller.earned, 0),
    updated_at = NOW()
FROM buyer_totals buyer
FULL JOIN seller_totals seller ON seller.owner_id = buyer.user_id
WHERE account.id = COALESCE(buyer.user_id, seller.owner_id);

-- Stock hiển thị luôn bằng số asset AVAILABLE thực tế, kể cả khi bằng 0.
UPDATE product_variants variant
SET stock_count = (
    SELECT COUNT(*)::INT
    FROM digital_assets asset
    WHERE asset.product_variant_id = variant.id
      AND asset.status = 'AVAILABLE'
)
WHERE variant.product_id IN (
    SELECT id FROM products
    WHERE slug IN (
        'chatgpt-plus-demo', 'netflix-premium-demo', 'capcut-pro-demo',
        'canva-pro-demo', 'nordvpn-demo'
    )
);

COMMIT;

-- Kết quả kiểm tra nhanh được trả ngay trong DBeaver/psql sau khi seed.
SELECT
    u.username,
    u.accumulated_spent,
    u.accumulated_earned,
    w.available_balance,
    w.hold_balance,
    (SELECT COUNT(*) FROM orders o
     WHERE o.user_id = u.id AND o.status = 'DELIVERED' AND o.payment_status = 'PAID'
       AND EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.id)
       AND NOT EXISTS (
           SELECT 1 FROM order_items oi
           WHERE oi.order_id = o.id
             AND NOT EXISTS (
                 SELECT 1 FROM hold_releases hr
                 WHERE hr.order_item_id = oi.id AND hr.status = 'RELEASED'
             )
       )) AS completed_purchase_count,
    (SELECT COUNT(*) FROM orders o
     JOIN shops s ON s.id = o.shop_id
     WHERE s.owner_id = u.id AND o.status = 'DELIVERED' AND o.payment_status = 'PAID'
       AND EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.id)
       AND NOT EXISTS (
           SELECT 1 FROM order_items oi
           WHERE oi.order_id = o.id
             AND NOT EXISTS (
                 SELECT 1 FROM hold_releases hr
                 WHERE hr.order_item_id = oi.id AND hr.status = 'RELEASED'
             )
       )) AS successful_sale_count
FROM users u
JOIN wallets w ON w.user_id = u.id
WHERE u.username IN ('seller_demo', 'vpn_seller', 'buyer_demo')
ORDER BY u.username;

-- ============================================================
-- TÀI KHOẢN SAU KHI SEED
-- admin@commercehub.test      / Test@123456
-- seller@commercehub.test     / Test@123456
-- vpn.seller@commercehub.test / Test@123456
-- buyer@commercehub.test      / Test@123456
--
-- Profile công khai:
-- /users/seller_demo
-- /users/vpn_seller
-- /users/buyer_demo
-- ============================================================
