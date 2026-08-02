-- products_feature.sql
-- 商品管理功能：products 表 + product_favorites 表 + inquiries 扩展 + 搜索RPC

-- ============================================
-- 1. products 商品表（兼容现有供应商端字段）
-- ============================================
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id UUID REFERENCES suppliers(id),
  company_id BIGINT REFERENCES companies(id),
  name TEXT NOT NULL,
  category TEXT DEFAULT '',
  description TEXT DEFAULT '',
  images TEXT[] DEFAULT '{}',
  moq INTEGER DEFAULT 1,
  price_min NUMERIC(10,2),
  price_max NUMERIC(10,2),
  price_unit TEXT DEFAULT '件',
  lead_time TEXT DEFAULT '',
  custom_capability BOOLEAN DEFAULT false,
  sample_available BOOLEAN DEFAULT false,
  sample_price TEXT DEFAULT '',
  specifications JSONB DEFAULT '{}'::jsonb,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_products_supplier_id ON products(supplier_id);
CREATE INDEX IF NOT EXISTS idx_products_company_id ON products(company_id);
CREATE INDEX IF NOT EXISTS idx_products_status ON products(status);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);

-- RLS
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "products_select" ON products;
DROP POLICY IF EXISTS "products_insert" ON products;
DROP POLICY IF EXISTS "products_update" ON products;
DROP POLICY IF EXISTS "products_delete" ON products;

CREATE POLICY "products_select" ON products FOR SELECT USING (true);
CREATE POLICY "products_insert" ON products FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "products_update" ON products FOR UPDATE USING (auth.uid() IS NOT NULL);
CREATE POLICY "products_delete" ON products FOR DELETE USING (auth.uid() IS NOT NULL);

-- ============================================
-- 2. product_favorites 商品收藏表
-- ============================================
CREATE TABLE IF NOT EXISTS product_favorites (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_product_favorites_user ON product_favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_product_favorites_product ON product_favorites(product_id);

ALTER TABLE product_favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "product_favorites_select" ON product_favorites;
DROP POLICY IF EXISTS "product_favorites_insert" ON product_favorites;
DROP POLICY IF EXISTS "product_favorites_delete" ON product_favorites;

CREATE POLICY "product_favorites_select" ON product_favorites FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "product_favorites_insert" ON product_favorites FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "product_favorites_delete" ON product_favorites FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- 3. buyer_inquiries 表扩展（新增 product_id 可选字段）
-- ============================================
ALTER TABLE buyer_inquiries ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES products(id);
CREATE INDEX IF NOT EXISTS idx_buyer_inquiries_product_id ON buyer_inquiries(product_id);

-- ============================================
-- 4. 品牌方搜索商品 RPC（含供应商信息）
-- ============================================
CREATE OR REPLACE FUNCTION search_products(
  p_keyword TEXT DEFAULT NULL,
  p_category TEXT DEFAULT NULL,
  p_sample_available BOOLEAN DEFAULT NULL,
  p_custom_capability BOOLEAN DEFAULT NULL,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  supplier_id UUID,
  company_id BIGINT,
  name TEXT,
  category TEXT,
  description TEXT,
  images TEXT[],
  moq INTEGER,
  price_min NUMERIC(10,2),
  price_max NUMERIC(10,2),
  price_unit TEXT,
  lead_time TEXT,
  custom_capability BOOLEAN,
  sample_available BOOLEAN,
  sample_price TEXT,
  specifications JSONB,
  status TEXT,
  supplier_name TEXT,
  supplier_region TEXT,
  supplier_verified BOOLEAN,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT p.*, s.company_name AS supplier_name, s.region AS supplier_region, s.is_verified AS supplier_verified
  FROM products p
  LEFT JOIN suppliers s ON p.supplier_id = s.id
  WHERE p.status = 'active'
    AND (p_keyword IS NULL OR p.name ILIKE '%' || p_keyword || '%' OR p.description ILIKE '%' || p_keyword || '%' OR p.category ILIKE '%' || p_keyword || '%')
    AND (p_category IS NULL OR p.category = p_category)
    AND (p_sample_available IS NULL OR p.sample_available = p_sample_available)
    AND (p_custom_capability IS NULL OR p.custom_capability = p_custom_capability)
  ORDER BY p.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION search_products(TEXT, TEXT, BOOLEAN, BOOLEAN, INTEGER, INTEGER) TO authenticated, anon;

-- ============================================
-- 5. 检查是否已收藏 RPC
-- ============================================
CREATE OR REPLACE FUNCTION check_product_favorite(p_product_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM product_favorites WHERE user_id = auth.uid() AND product_id = p_product_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION check_product_favorite(UUID) TO authenticated;
