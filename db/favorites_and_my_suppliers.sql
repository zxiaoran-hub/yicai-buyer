-- favorites_and_my_suppliers.sql
-- 品牌方：供应商收藏 + 我的供应商管理

-- ============================================
-- 1. supplier_favorites 供应商收藏表
-- ============================================
CREATE TABLE IF NOT EXISTS supplier_favorites (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, supplier_id)
);

CREATE INDEX idx_supplier_favorites_user ON supplier_favorites(user_id);
CREATE INDEX idx_supplier_favorites_supplier ON supplier_favorites(supplier_id);

ALTER TABLE supplier_favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "supplier_favorites_select" ON supplier_favorites;
DROP POLICY IF EXISTS "supplier_favorites_insert" ON supplier_favorites;
DROP POLICY IF EXISTS "supplier_favorites_delete" ON supplier_favorites;

CREATE POLICY "supplier_favorites_select" ON supplier_favorites FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "supplier_favorites_insert" ON supplier_favorites FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "supplier_favorites_delete" ON supplier_favorites FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- 2. buyer_supplier_relations 品牌方-供应商关系表
-- ============================================
CREATE TABLE IF NOT EXISTS buyer_supplier_relations (
  id BIGSERIAL PRIMARY KEY,
  buyer_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
  buyer_company_id BIGINT REFERENCES companies(id),
  status TEXT DEFAULT 'potential' CHECK (status IN ('potential', 'contacted', 'cooperating', 'blacklisted')),
  tags TEXT[] DEFAULT '{}',
  notes TEXT DEFAULT '',
  source TEXT DEFAULT 'discovery' CHECK (source IN ('discovery', 'inquiry', 'order', 'manual')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(buyer_user_id, supplier_id)
);

CREATE INDEX idx_bsr_buyer ON buyer_supplier_relations(buyer_user_id);
CREATE INDEX idx_bsr_supplier ON buyer_supplier_relations(supplier_id);
CREATE INDEX idx_bsr_status ON buyer_supplier_relations(status);

ALTER TABLE buyer_supplier_relations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "bsr_select" ON buyer_supplier_relations;
DROP POLICY IF EXISTS "bsr_insert" ON buyer_supplier_relations;
DROP POLICY IF EXISTS "bsr_update" ON buyer_supplier_relations;
DROP POLICY IF EXISTS "bsr_delete" ON buyer_supplier_relations;

CREATE POLICY "bsr_select" ON buyer_supplier_relations FOR SELECT USING (auth.uid() = buyer_user_id);
CREATE POLICY "bsr_insert" ON buyer_supplier_relations FOR INSERT WITH CHECK (auth.uid() = buyer_user_id);
CREATE POLICY "bsr_update" ON buyer_supplier_relations FOR UPDATE USING (auth.uid() = buyer_user_id);
CREATE POLICY "bsr_delete" ON buyer_supplier_relations FOR DELETE USING (auth.uid() = buyer_user_id);

-- ============================================
-- 3. 检查供应商是否已收藏 RPC
-- ============================================
CREATE OR REPLACE FUNCTION check_supplier_favorite(p_supplier_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM supplier_favorites WHERE user_id = auth.uid() AND supplier_id = p_supplier_id
  );
END;
$$;
GRANT EXECUTE ON FUNCTION check_supplier_favorite(UUID) TO authenticated;

-- ============================================
-- 4. 获取我的供应商列表（含供应商详情）RPC
-- ============================================
CREATE OR REPLACE FUNCTION get_my_suppliers(p_user_id UUID, p_status TEXT DEFAULT NULL)
RETURNS TABLE (
  relation_id BIGINT,
  supplier_id UUID,
  status TEXT,
  tags TEXT[],
  notes TEXT,
  source TEXT,
  company_name TEXT,
  region TEXT,
  category TEXT[],
  is_verified BOOLEAN,
  rating NUMERIC,
  contact_name TEXT,
  contact_email TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT r.id AS relation_id, r.supplier_id, r.status, r.tags, r.notes, r.source,
         s.company_name, s.region, s.category, s.is_verified, s.rating,
         s.contact_name, s.contact_email,
         r.created_at, r.updated_at
  FROM buyer_supplier_relations r
  LEFT JOIN suppliers s ON r.supplier_id = s.id
  WHERE r.buyer_user_id = p_user_id
    AND (p_status IS NULL OR r.status = p_status)
  ORDER BY r.updated_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION get_my_suppliers(UUID, TEXT) TO authenticated;
