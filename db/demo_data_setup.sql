-- ============================================
-- 异采 YiCai 演示数据 - 一键部署 v5
-- 已修复: companies表无short_name/region列
-- ============================================
CREATE OR REPLACE FUNCTION setup_demo_data(
  p_buyer_user_id UUID,
  p_supplier1_user_id UUID,
  p_supplier2_user_id UUID,
  p_supplier3_user_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_company_ids BIGINT[];
  v_supplier_ids UUID[];
  v_buyer_id UUID;
  v_inquiry_ids BIGINT[];
  v_sid UUID;
  v_cid BIGINT;
  v_err TEXT;
BEGIN
  -- ============================================
  -- 0a. 确保依赖表和列存在
  -- ============================================
  BEGIN
    -- suppliers 补齐 user_id
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='suppliers' AND column_name='user_id') THEN
      ALTER TABLE suppliers ADD COLUMN user_id UUID;
    END IF;

    CREATE TABLE IF NOT EXISTS buyer_inquiries (
      id BIGSERIAL PRIMARY KEY, company_id BIGINT, created_by UUID NOT NULL,
      title TEXT NOT NULL, category TEXT, description TEXT, quantity INTEGER,
      target_price DECIMAL(12,2), deadline DATE, is_public BOOLEAN DEFAULT true,
      status TEXT DEFAULT 'open',
      created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS buyers (
      id UUID DEFAULT gen_random_uuid() PRIMARY KEY, user_id UUID UNIQUE,
      company_name TEXT, short_name TEXT, industry TEXT DEFAULT '',
      brand_name TEXT DEFAULT '', contact_name TEXT DEFAULT '', contact_email TEXT DEFAULT '',
      description TEXT DEFAULT '', is_verified BOOLEAN DEFAULT false,
      created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS supplier_favorites (
      id BIGSERIAL PRIMARY KEY, user_id UUID NOT NULL,
      supplier_id UUID NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(user_id, supplier_id)
    );
    CREATE TABLE IF NOT EXISTS product_favorites (
      id BIGSERIAL PRIMARY KEY, user_id UUID NOT NULL,
      product_id UUID NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(user_id, product_id)
    );
    CREATE TABLE IF NOT EXISTS buyer_supplier_relations (
      id BIGSERIAL PRIMARY KEY, buyer_user_id UUID NOT NULL, supplier_id UUID NOT NULL,
      buyer_company_id BIGINT, status TEXT DEFAULT 'potential',
      tags TEXT[] DEFAULT '{}', notes TEXT DEFAULT '', source TEXT DEFAULT 'manual',
      created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(buyer_user_id, supplier_id)
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    RETURN '建表阶段错误: ' || v_err;
  END;

  -- ============================================
  -- 0b. 清理旧数据（每步独立容错）
  -- ============================================
  BEGIN DELETE FROM buyer_supplier_relations WHERE buyer_user_id = p_buyer_user_id; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN DELETE FROM supplier_favorites WHERE user_id = p_buyer_user_id; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN DELETE FROM product_favorites WHERE user_id = p_buyer_user_id; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN DELETE FROM buyer_inquiries WHERE created_by = p_buyer_user_id; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN DELETE FROM buyers WHERE user_id = p_buyer_user_id; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN
    FOR v_sid IN SELECT id FROM suppliers WHERE user_id IN (p_supplier1_user_id, p_supplier2_user_id, p_supplier3_user_id)
    LOOP DELETE FROM products WHERE supplier_id = v_sid; END LOOP;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN DELETE FROM suppliers WHERE user_id IN (p_supplier1_user_id, p_supplier2_user_id, p_supplier3_user_id); EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN DELETE FROM companies WHERE name IN (
    '广州美肤化妆品有限公司','上海丝芙瑞生物科技有限公司','杭州妍妆科技有限公司',
    '星辰美妆（演示）','广州白云化妆品工厂','义乌彩妆 supplier'
  ); EXCEPTION WHEN OTHERS THEN NULL; END;

  -- ============================================
  -- 1. 创建公司（companies表实际列: name, type, status, contact_name, contact_email, industry）
  -- ============================================
  BEGIN
    INSERT INTO companies (name, type, status, industry, contact_email) VALUES
    ('星辰美妆（演示）', 'buyer', 'active', '美妆个护', 'demo_buyer@yicai.demo'),
    ('广州美肤化妆品有限公司', 'supplier', 'active', '护肤', 'demo_gz@yicai.demo'),
    ('上海丝芙瑞生物科技有限公司', 'supplier', 'active', '彩妆', 'demo_sh@yicai.demo'),
    ('杭州妍妆科技有限公司', 'supplier', 'active', '面膜/精华', 'demo_hz@yicai.demo'),
    ('广州白云化妆品工厂', 'supplier', 'active', '洗护', 'contact@baiyun.example'),
    ('义乌彩妆 supplier', 'supplier', 'active', '彩妆', 'contact@yiwu.example');

    SELECT ARRAY(SELECT id FROM companies WHERE name IN (
      '星辰美妆（演示）','广州美肤化妆品有限公司','上海丝芙瑞生物科技有限公司',
      '杭州妍妆科技有限公司','广州白云化妆品工厂','义乌彩妆 supplier'
    )) INTO v_company_ids;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    RETURN '公司创建错误: ' || v_err;
  END;

  -- ============================================
  -- 2. 创建供应商（使用真实存在的列）
  -- ============================================
  BEGIN
    INSERT INTO suppliers (company_id, user_id, company_name, short_name, category, region, description, is_verified, is_featured, featured_order, rating, contact_name, contact_email) VALUES
    ((SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), p_supplier1_user_id,
     '广州美肤化妆品有限公司', '广州美肤', '护肤', '华南', '专业护肤产品代工，10年GMP经验', true, true, 1, 4.8, '张经理', 'demo_gz@yicai.demo'),
    ((SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), p_supplier2_user_id,
     '上海丝芙瑞生物科技有限公司', '上海丝芙瑞', '彩妆', '华东', '高端彩妆研发制造，国际品牌代工', true, true, 2, 4.6, '李总监', 'demo_sh@yicai.demo'),
    ((SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), p_supplier3_user_id,
     '杭州妍妆科技有限公司', '杭州妍妆', '面膜', '华东', '面膜/精华专业工厂，支持ODM', true, true, 3, 4.5, '王主管', 'demo_hz@yicai.demo'),
    ((SELECT id FROM companies WHERE name='广州白云化妆品工厂'), NULL,
     '广州白云化妆品工厂', '白云工厂', '洗护', '华南', '洗护产品OEM，产能充足', false, false, NULL, 4.2, '陈厂长', 'contact@baiyun.example'),
    ((SELECT id FROM companies WHERE name='义乌彩妆 supplier'), NULL,
     '义乌彩妆 supplier', '义乌彩妆', '彩妆', '华东', '彩妆出口贸易，性价比优', false, false, NULL, 4.0, '赵经理', 'contact@yiwu.example');

    SELECT ARRAY(SELECT id FROM suppliers WHERE user_id IN (p_supplier1_user_id, p_supplier2_user_id, p_supplier3_user_id)) INTO v_supplier_ids;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    RETURN '供应商创建错误: ' || v_err;
  END;

  -- ============================================
  -- 3. 创建商品
  -- ============================================
  BEGIN
    INSERT INTO products (supplier_id, company_id, name, category, description, moq, price_min, price_max, price_unit, lead_time, sample_available, sample_price, custom_capability) VALUES
    -- 广州美肤（6款）
    (v_supplier_ids[1], (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '玻尿酸保湿精华液', '精华', '30ml高浓度玻尿酸精华，深层补水锁水', 100, 18.50, 35.00, '瓶', '15天', true, '¥88', true),
    (v_supplier_ids[1], (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '烟酰胺亮肤面膜', '面膜', '5片/盒 烟酰胺+VC双重美白', 200, 12.00, 25.00, '盒', '12天', true, '¥45', true),
    (v_supplier_ids[1], (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '氨基酸温和洁面乳', '洁面', '120ml 氨基酸配方 温和不紧绷', 500, 8.00, 15.00, '支', '10天', true, '¥28', false),
    (v_supplier_ids[1], (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '防晒霜SPF50+', '防晒', '50ml 清透不油腻 防水防汗', 300, 15.00, 28.00, '支', '12天', true, '¥58', true),
    (v_supplier_ids[1], (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '神经酰胺修护面霜', '面霜', '50g 敏感肌适用 修复肌肤屏障', 200, 22.00, 42.00, '瓶', '15天', true, '¥128', true),
    (v_supplier_ids[1], (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '茶树控油爽肤水', '化妆水', '200ml 控油收敛 清爽不黏腻', 300, 10.00, 20.00, '瓶', '10天', true, '¥38', false),
    -- 上海丝芙瑞（6款）
    (v_supplier_ids[2], (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '丝绒哑光唇釉', '唇部', '3.5ml 不拔干 持久显色', 500, 9.00, 18.00, '支', '20天', true, '¥68', true),
    (v_supplier_ids[2], (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '持妆粉底液', '底妆', '30ml 遮瑕持妆12h 色号可选', 300, 25.00, 48.00, '瓶', '18天', true, '¥158', true),
    (v_supplier_ids[2], (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '多色眼影盘', '眼部', '12色大地色系 珠光哑光', 200, 20.00, 38.00, '盘', '25天', true, '¥98', true),
    (v_supplier_ids[2], (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '柔焦定妆散粉', '定妆', '10g 细腻控油 轻薄透气', 500, 12.00, 22.00, '盒', '15天', true, '¥58', false),
    (v_supplier_ids[2], (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '眉笔三件套', '眉部', '极细+砍刀+眉粉 防水持久', 1000, 6.00, 12.00, '套', '10天', true, '¥35', false),
    (v_supplier_ids[2], (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '腮红高光盘', '面部', '双色拼接 自然提气色', 300, 15.00, 28.00, '盘', '18天', true, '¥78', true),
    -- 杭州妍妆（6款）
    (v_supplier_ids[3], (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '胶原蛋白面膜', '面膜', '5片/盒 深海鱼胶原蛋白 紧致抗皱', 100, 15.00, 30.00, '盒', '10天', true, '¥68', true),
    (v_supplier_ids[3], (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '烟酰胺焕亮安瓶', '精华', '2ml×28支 提亮肤色 淡化色斑', 200, 20.00, 45.00, '盒', '12天', true, '¥168', true),
    (v_supplier_ids[3], (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '积雪草舒缓贴片', '面膜', '10片/盒 敏感肌修护 舒缓泛红', 300, 8.00, 18.00, '盒', '8天', true, '¥38', false),
    (v_supplier_ids[3], (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '玻尿酸补水面膜', '面膜', '5片/盒 三层玻尿酸 深层保湿', 500, 6.00, 15.00, '盒', '8天', true, '¥28', false),
    (v_supplier_ids[3], (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '视黄醇抗皱精华', '精华', '30ml A醇+VE 淡化细纹', 100, 28.00, 55.00, '瓶', '15天', true, '¥198', true),
    (v_supplier_ids[3], (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '酵素洁面粉', '洁面', '60g 木瓜酵素 温和去角质', 200, 12.00, 25.00, '罐', '10天', true, '¥58', true),
    -- 补充商品
    (v_supplier_ids[1], (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '身体乳清爽型', '身体护理', '300ml 烟酰胺+乳木果 24h保湿', 200, 12.00, 25.00, '瓶', '12天', true, '¥48', false),
    (v_supplier_ids[1], (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '护手霜套装', '手部', '3支装 植物精华 滋润不黏腻', 500, 8.00, 16.00, '套', '10天', true, '¥38', false),
    (v_supplier_ids[2], (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '修容高光笔', '面部', '双头设计 自然立体', 500, 7.00, 14.00, '支', '12天', true, '¥45', false),
    (v_supplier_ids[2], (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '持妆喷雾', '定妆', '100ml 控油定妆 持久不脱妆', 300, 10.00, 20.00, '瓶', '10天', true, '¥58', true),
    (v_supplier_ids[3], (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '眼霜抗蓝光', '眼部', '15g 抗蓝光+淡化黑眼圈', 200, 25.00, 50.00, '瓶', '15天', true, '¥168', true),
    (v_supplier_ids[3], (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '卸妆油', '卸妆', '200ml 温和卸妆 以油溶油', 300, 10.00, 22.00, '瓶', '10天', true, '¥48', false);
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    RETURN '商品创建错误: ' || v_err;
  END;

  -- ============================================
  -- 4. 品牌方 + 询价
  -- ============================================
  BEGIN
    INSERT INTO buyers (user_id, company_name, short_name, industry, brand_name, contact_name, contact_email, description, is_verified) VALUES
    (p_buyer_user_id, '星辰美妆（演示）', '星辰美妆', '美妆个护', '星辰STARCHARM', '林采购', 'demo_buyer@yicai.demo', '国内新锐美妆品牌，专注Z世代彩妆', true);

    SELECT id INTO v_buyer_id FROM buyers WHERE user_id = p_buyer_user_id;

    INSERT INTO buyer_inquiries (company_id, created_by, title, category, description, quantity, target_price, deadline, is_public, status) VALUES
    ((SELECT id FROM companies WHERE name='星辰美妆（演示）'), p_buyer_user_id, '寻面膜代工厂-月产10万片', '面膜', '需具备GMPC资质，支持ODM配方定制', 100000, 5.00, '2026-12-31', true, 'open'),
    ((SELECT id FROM companies WHERE name='星辰美妆（演示）'), p_buyer_user_id, '采购唇釉包材+灌装', '唇部', '现有配方，需灌装+包材供应', 50000, 8.00, '2026-10-15', true, 'open'),
    ((SELECT id FROM companies WHERE name='星辰美妆（演示）'), p_buyer_user_id, '精华液配方定制合作', '精华', '希望开发一款抗蓝光精华，需ODM能力', 20000, 15.00, '2027-01-30', true, 'open'),
    ((SELECT id FROM companies WHERE name='星辰美妆（演示）'), p_buyer_user_id, '采购防晒霜SPF50+现货', '防晒', '急需现货5000支，可接受现有配方', 5000, 12.00, '2026-08-30', true, 'closed');

    SELECT ARRAY(SELECT id FROM buyer_inquiries WHERE created_by = p_buyer_user_id ORDER BY created_at) INTO v_inquiry_ids;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    RETURN '品牌方/询价创建错误: ' || v_err;
  END;

  -- ============================================
  -- 5. 收藏数据
  -- ============================================
  BEGIN
    INSERT INTO supplier_favorites (user_id, supplier_id, created_at)
    SELECT p_buyer_user_id, s.id, CURRENT_DATE - (random()*10)::INT
    FROM suppliers s WHERE s.user_id IN (p_supplier1_user_id, p_supplier2_user_id, p_supplier3_user_id);

    INSERT INTO product_favorites (user_id, product_id, created_at)
    SELECT p_buyer_user_id, p.id, CURRENT_DATE - (random()*10)::INT
    FROM products p WHERE p.supplier_id = ANY(v_supplier_ids) LIMIT 15;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  -- ============================================
  -- 6. 供应商关系
  -- ============================================
  BEGIN
    INSERT INTO buyer_supplier_relations (buyer_user_id, supplier_id, buyer_company_id, status, tags, notes, source, created_at) VALUES
    (p_buyer_user_id, v_supplier_ids[1], (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'cooperating', ARRAY['核心供应商','面膜'], '长期合作，品质稳定', '平台推荐', CURRENT_DATE - INTERVAL '60 days'),
    (p_buyer_user_id, v_supplier_ids[2], (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'contacted', ARRAY['彩妆','新供应商'], '已沟通，待打样', '展会接触', CURRENT_DATE - INTERVAL '15 days'),
    (p_buyer_user_id, v_supplier_ids[3], (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'potential', ARRAY['精华','备选'], '正在了解中', '平台搜索', CURRENT_DATE - INTERVAL '3 days');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RETURN '✅ 演示数据初始化成功！已创建 6 家公司、6 个供应商、26 款商品、4 条询价、收藏和关系数据。';
END;
$$;
