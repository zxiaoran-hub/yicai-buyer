-- ============================================================
-- 异采 YiCai 品牌方端 - 数据库表结构
-- 依赖: permissions, roles, role_permissions, user_roles, companies 表已存在
-- ============================================================

-- 询价表
CREATE TABLE IF NOT EXISTS buyer_inquiries (
  id BIGSERIAL PRIMARY KEY,
  company_id BIGINT REFERENCES companies(id),
  created_by UUID NOT NULL,
  title TEXT NOT NULL,
  category TEXT,
  description TEXT,
  quantity INTEGER,
  target_price DECIMAL(12,2),
  deadline DATE,
  is_public BOOLEAN DEFAULT true,
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'closed', 'awarded')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 订单表
CREATE TABLE IF NOT EXISTS buyer_orders (
  id BIGSERIAL PRIMARY KEY,
  company_id BIGINT REFERENCES companies(id),
  buyer_user_id UUID NOT NULL,
  inquiry_id BIGINT REFERENCES buyer_inquiries(id),
  supplier_id BIGINT REFERENCES suppliers(id),
  supplier_name TEXT,
  product_name TEXT NOT NULL,
  quantity INTEGER DEFAULT 0,
  unit_price DECIMAL(12,2) DEFAULT 0,
  delivery_date DATE,
  notes TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'producing', 'completed', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 供应商报价表（品牌方视角查看）
CREATE TABLE IF NOT EXISTS supplier_quotes (
  id BIGSERIAL PRIMARY KEY,
  inquiry_id BIGINT REFERENCES buyer_inquiries(id),
  inquiry_company_id BIGINT,
  inquiry_created_by UUID,
  inquiry_title TEXT,
  supplier_id BIGINT REFERENCES suppliers(id),
  supplier_name TEXT,
  unit_price DECIMAL(12,2),
  moq INTEGER,
  lead_time TEXT,
  message TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_buyer_inquiries_company ON buyer_inquiries(company_id);
CREATE INDEX IF NOT EXISTS idx_buyer_inquiries_created_by ON buyer_inquiries(created_by);
CREATE INDEX IF NOT EXISTS idx_buyer_inquiries_status ON buyer_inquiries(status);
CREATE INDEX IF NOT EXISTS idx_buyer_orders_company ON buyer_orders(company_id);
CREATE INDEX IF NOT EXISTS idx_buyer_orders_buyer ON buyer_orders(buyer_user_id);
CREATE INDEX IF NOT EXISTS idx_buyer_orders_status ON buyer_orders(status);
CREATE INDEX IF NOT EXISTS idx_supplier_quotes_inquiry ON supplier_quotes(inquiry_id);
CREATE INDEX IF NOT EXISTS idx_supplier_quotes_inquiry_company ON supplier_quotes(inquiry_company_id);
CREATE INDEX IF NOT EXISTS idx_supplier_quotes_status ON supplier_quotes(status);

-- ============================================================
-- RPC 函数
-- ============================================================

-- 获取用户权限（如不存在则创建）
CREATE OR REPLACE FUNCTION get_user_permissions(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
  v_company_id BIGINT;
  v_is_platform_admin BOOLEAN := false;
  v_is_company_admin BOOLEAN := false;
  v_roles JSONB;
  v_permissions JSONB;
BEGIN
  -- 获取用户的company_id
  SELECT company_id INTO v_company_id
  FROM user_roles
  WHERE user_id = p_user_id
  LIMIT 1;

  -- 检查是否平台管理员
  SELECT EXISTS(
    SELECT 1 FROM user_roles ur
    JOIN roles r ON ur.role_id = r.id
    WHERE ur.user_id = p_user_id
    AND r.is_system = true
    AND r.name ILIKE '%platform%admin%'
  ) INTO v_is_platform_admin;

  -- 检查是否公司管理员
  SELECT EXISTS(
    SELECT 1 FROM user_roles ur
    JOIN roles r ON ur.role_id = r.id
    WHERE ur.user_id = p_user_id
    AND (r.name ILIKE '%admin%' OR r.is_system = true)
    AND (r.company_id = v_company_id OR r.company_id IS NULL)
  ) INTO v_is_company_admin;

  -- 获取角色列表
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', r.id,
    'name', r.name,
    'description', r.description,
    'data_scope', r.data_scope
  )), '[]'::jsonb) INTO v_roles
  FROM user_roles ur
  JOIN roles r ON ur.role_id = r.id
  WHERE ur.user_id = p_user_id;

  -- 获取权限列表
  SELECT COALESCE(jsonb_agg(DISTINCT jsonb_build_object(
    'id', p.id,
    'resource', p.resource,
    'action', p.action,
    'effect', p.effect,
    'display_name', p.display_name,
    'menu_path', p.menu_path,
    'button_key', p.button_key
  )), '[]'::jsonb) INTO v_permissions
  FROM role_permissions rp
  JOIN roles r ON rp.role_id = r.id
  JOIN permissions p ON rp.permission_id = p.id
  WHERE r.id IN (
    SELECT role_id FROM user_roles WHERE user_id = p_user_id
  )
  AND p.effect = 'allow';

  -- 构建返回结果
  v_result := jsonb_build_object(
    'user_id', p_user_id,
    'company_id', v_company_id,
    'is_platform_admin', v_is_platform_admin,
    'is_company_admin', v_is_company_admin,
    'roles', v_roles,
    'permissions', v_permissions
  );

  RETURN v_result;
END;
$$;

-- 注册个人买家
CREATE OR REPLACE FUNCTION register_individual_buyer(p_email TEXT, p_password TEXT, p_name TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_role_id BIGINT;
  v_result JSONB;
BEGIN
  -- 获取当前auth用户ID
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 查找个人用户默认角色
  SELECT id INTO v_role_id
  FROM roles
  WHERE is_system = true
  AND name ILIKE '%individual%'
  LIMIT 1;

  -- 如果没有找到个人角色，尝试找默认注册角色
  IF v_role_id IS NULL THEN
    SELECT id INTO v_role_id
    FROM roles
    WHERE is_system = true
    AND (name ILIKE '%buyer%' OR name ILIKE '%register%')
    AND company_id IS NULL
    LIMIT 1;
  END IF;

  -- 创建user_roles记录（个人用户，company_id为NULL）
  INSERT INTO user_roles (user_id, role_id, company_id, user_email)
  VALUES (v_user_id, v_role_id, NULL, p_email)
  ON CONFLICT DO NOTHING;

  v_result := jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'role_id', v_role_id,
    'name', p_name
  );

  RETURN v_result;
END;
$$;

-- 获取用户company_id
CREATE OR REPLACE FUNCTION get_user_company_id()
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_company_id BIGINT;
BEGIN
  SELECT company_id INTO v_company_id
  FROM user_roles
  WHERE user_id = auth.uid()
  LIMIT 1;

  RETURN v_company_id;
END;
$$;

-- 注册企业买家（管理员用）
CREATE OR REPLACE FUNCTION register_company_buyer(p_email TEXT, p_password TEXT, p_company_name TEXT, p_admin_name TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_company_id BIGINT;
  v_admin_role_id BIGINT;
  v_result JSONB;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 创建公司
  INSERT INTO companies (name, type, status)
  VALUES (p_company_name, 'buyer', 'active')
  RETURNING id INTO v_company_id;

  -- 查找或创建公司管理员角色
  SELECT id INTO v_admin_role_id
  FROM roles
  WHERE is_system = true
  AND name ILIKE '%admin%'
  AND company_id IS NULL
  LIMIT 1;

  -- 关联用户到公司（管理员角色）
  INSERT INTO user_roles (user_id, role_id, company_id, user_email)
  VALUES (v_user_id, v_admin_role_id, v_company_id, p_email);

  v_result := jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'company_id', v_company_id,
    'company_name', p_company_name,
    'admin_role_id', v_admin_role_id
  );

  RETURN v_result;
END;
$$;

-- ============================================================
-- RLS 策略（基础版本）
-- ============================================================

ALTER TABLE buyer_inquiries ENABLE ROW LEVEL SECURITY;
ALTER TABLE buyer_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_quotes ENABLE ROW LEVEL SECURITY;

-- 询价：公司用户看本公司数据，个人用户看自己的
CREATE POLICY "buyer_inquiries_select" ON buyer_inquiries
  FOR SELECT USING (
    company_id = (SELECT get_user_company_id())
    OR created_by = auth.uid()
  );

CREATE POLICY "buyer_inquiries_insert" ON buyer_inquiries
  FOR INSERT WITH CHECK (
    created_by = auth.uid()
  );

CREATE POLICY "buyer_inquiries_update" ON buyer_inquiries
  FOR UPDATE USING (
    company_id = (SELECT get_user_company_id())
    OR created_by = auth.uid()
  );

-- 订单
CREATE POLICY "buyer_orders_select" ON buyer_orders
  FOR SELECT USING (
    company_id = (SELECT get_user_company_id())
    OR buyer_user_id = auth.uid()
  );

CREATE POLICY "buyer_orders_insert" ON buyer_orders
  FOR INSERT WITH CHECK (
    buyer_user_id = auth.uid()
  );

CREATE POLICY "buyer_orders_update" ON buyer_orders
  FOR UPDATE USING (
    company_id = (SELECT get_user_company_id())
    OR buyer_user_id = auth.uid()
  );

-- 报价（品牌方查看）
CREATE POLICY "supplier_quotes_select" ON supplier_quotes
  FOR SELECT USING (
    inquiry_company_id = (SELECT get_user_company_id())
    OR inquiry_created_by = auth.uid()
  );
