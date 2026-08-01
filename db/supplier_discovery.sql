-- ============================================================
-- 异采 YiCai - 供应商发现与智能匹配
-- 创建 public_supplier_profile 视图 + match_suppliers_for_inquiry RPC
-- ============================================================

-- 1. 供应商公开展示视图（聚合供应商基本信息 + 产品数量）
CREATE OR REPLACE VIEW public_supplier_profile AS
SELECT
  s.id,
  s.company_name,
  s.short_name,
  s.category,
  s.region,
  s.description,
  s.established_year,
  s.employee_count,
  s.factory_area,
  s.is_verified,
  s.is_featured,
  s.featured_order,
  s.rating,
  s.factory_photos,
  s.certifications,
  s.cert_images,
  s.contact_name,
  s.contact_email,
  COUNT(DISTINCT p.id) AS product_count
FROM suppliers s
LEFT JOIN products p ON p.supplier_id = s.id
WHERE s.is_verified = true OR s.is_featured = true
GROUP BY s.id
ORDER BY s.is_featured DESC NULLS LAST, s.rating DESC NULLS LAST, s.company_name;

-- 2. 授权：允许 anon 和 authenticated 角色访问视图
GRANT SELECT ON public_supplier_profile TO anon;
GRANT SELECT ON public_supplier_profile TO authenticated;

-- 3. 智能匹配 RPC 函数
-- 根据品类和地区为询盘推荐匹配的供应商
-- 评分规则：品类匹配+40  地区匹配+20  已认证+20  精选+15  评分×5
CREATE OR REPLACE FUNCTION match_suppliers_for_inquiry(
  p_category TEXT DEFAULT NULL,
  p_region   TEXT DEFAULT NULL,
  p_limit    INTEGER DEFAULT 10
)
RETURNS TABLE (
  id            UUID,
  company_name  TEXT,
  short_name    TEXT,
  category      TEXT,
  region        TEXT,
  description   TEXT,
  is_verified   BOOLEAN,
  is_featured   BOOLEAN,
  rating        NUMERIC,
  product_count BIGINT,
  match_score   NUMERIC
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.id,
    s.company_name::TEXT,
    s.short_name::TEXT,
    s.category::TEXT,
    s.region::TEXT,
    s.description::TEXT,
    s.is_verified,
    s.is_featured,
    s.rating,
    COUNT(DISTINCT p.id) AS product_count,
    (
      CASE WHEN p_category IS NOT NULL AND s.category IS NOT NULL
           AND (s.category = p_category OR s.category ILIKE '%' || p_category || '%')
           THEN 40 ELSE 0 END
      +
      CASE WHEN p_region IS NOT NULL AND s.region IS NOT NULL
           AND s.region = p_region
           THEN 20 ELSE 0 END
      +
      CASE WHEN s.is_verified = true THEN 20 ELSE 0 END
      +
      CASE WHEN s.is_featured = true THEN 15 ELSE 0 END
      +
      COALESCE(s.rating, 0) * 5
    ) AS match_score
  FROM suppliers s
  LEFT JOIN products p ON p.supplier_id = s.id
  WHERE s.is_verified = true OR s.is_featured = true
  GROUP BY s.id
  ORDER BY match_score DESC, s.company_name
  LIMIT p_limit;
END;
$$;

-- 4. 授权：允许 anon 和 authenticated 角色调用 RPC
GRANT EXECUTE ON FUNCTION match_suppliers_for_inquiry(TEXT, TEXT, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION match_suppliers_for_inquiry(TEXT, TEXT, INTEGER) TO authenticated;
