-- ============================================
-- 异采 YiCai 演示数据 - 直接插入版 v3
-- 修复：certifications/tags 用 JSON 数组语法
-- ============================================

-- ========== 清理旧数据 ==========
DELETE FROM buyer_supplier_relations WHERE buyer_user_id = 'f7478991-2b89-45b7-aae8-62f58b8ffe35';
DELETE FROM supplier_favorites WHERE user_id = 'f7478991-2b89-45b7-aae8-62f58b8ffe35';
DELETE FROM product_favorites WHERE user_id = 'f7478991-2b89-45b7-aae8-62f58b8ffe35';
DELETE FROM buyer_inquiries WHERE created_by = 'f7478991-2b89-45b7-aae8-62f58b8ffe35';
DELETE FROM buyers WHERE user_id = 'f7478991-2b89-45b7-aae8-62f58b8ffe35';

DELETE FROM products WHERE supplier_id IN (
  SELECT id FROM suppliers WHERE user_id IN (
    'cce118c5-78f5-4977-9822-87fe74085b1d',
    'b56016f2-4daa-4dbd-a14c-a76bb94bb644',
    '0bd203b0-a44b-4cec-a49d-e0a377c81034'
  )
);
DELETE FROM suppliers WHERE user_id IN (
  'cce118c5-78f5-4977-9822-87fe74085b1d',
  'b56016f2-4daa-4dbd-a14c-a76bb94bb644',
  '0bd203b0-a44b-4cec-a49d-e0a377c81034'
);

DELETE FROM companies WHERE name IN (
  '广州美肤化妆品有限公司','上海丝芙瑞生物科技有限公司','杭州妍妆科技有限公司',
  '星辰美妆（演示）','广州白云化妆品工厂','义乌彩妆供应商'
);

-- ========== 1. 插入公司 ==========
INSERT INTO companies (name, type, status, industry, contact_email) VALUES
('星辰美妆（演示）', 'buyer', 'active', '美妆个护', 'demo_buyer@yicai.demo'),
('广州美肤化妆品有限公司', 'supplier', 'active', '护肤', 'demo_gz@yicai.demo'),
('上海丝芙瑞生物科技有限公司', 'supplier', 'active', '彩妆', 'demo_sh@yicai.demo'),
('杭州妍妆科技有限公司', 'supplier', 'active', '面膜精华', 'demo_hz@yicai.demo'),
('广州白云化妆品工厂', 'supplier', 'active', '洗护', 'contact@baiyun.example'),
('义乌彩妆供应商', 'supplier', 'active', '彩妆', 'contact@yiwu.example');

-- ========== 2. 插入品牌方 ==========
INSERT INTO buyers (user_id, company_name, short_name, industry, brand_name, contact_name, contact_email, description, is_verified) VALUES
('f7478991-2b89-45b7-aae8-62f58b8ffe35', '星辰美妆（演示）', '星辰美妆', '美妆个护', '星辰STARCHARM', '林采购', 'demo_buyer@yicai.demo', '国内新锐美妆品牌，专注Z世代彩妆', true);

-- ========== 3. 插入供应商 ==========
-- category: TEXT[] 用 '{"值"}' 语法
-- certifications: JSON 用 '["值1","值2"]' 语法
INSERT INTO suppliers (company_id, user_id, company_name, short_name, category, region, description, established_year, employee_count, factory_area, is_verified, is_featured, featured_order, rating, certifications, contact_name, contact_email) VALUES
((SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), 'cce118c5-78f5-4977-9822-87fe74085b1d',
 '广州美肤化妆品有限公司', '广州美肤', '{"护肤"}', '华南', '专业护肤产品代工，10年GMP经验', 2015, 200, 5000, true, true, 1, 4.8, '["ISO22716","GMPC"]', '张经理', 'demo_gz@yicai.demo'),
((SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), 'b56016f2-4daa-4dbd-a14c-a76bb94bb644',
 '上海丝芙瑞生物科技有限公司', '上海丝芙瑞', '{"彩妆"}', '华东', '高端彩妆研发制造，国际品牌代工', 2012, 350, 8000, true, true, 2, 4.6, '["ISO22716","FDA"]', '李总监', 'demo_sh@yicai.demo'),
((SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '0bd203b0-a44b-4cec-a49d-e0a377c81034',
 '杭州妍妆科技有限公司', '杭州妍妆', '{"面膜"}', '华东', '面膜精华专业工厂，支持ODM', 2018, 120, 3000, true, true, 3, 4.5, '["ISO22716"]', '王主管', 'demo_hz@yicai.demo'),
((SELECT id FROM companies WHERE name='广州白云化妆品工厂'), NULL,
 '广州白云化妆品工厂', '白云工厂', '{"洗护"}', '华南', '洗护产品OEM，产能充足', 2016, 180, 4500, false, false, NULL, 4.2, '["GMPC"]', '陈厂长', 'contact@baiyun.example'),
((SELECT id FROM companies WHERE name='义乌彩妆供应商'), NULL,
 '义乌彩妆供应商', '义乌彩妆', '{"彩妆"}', '华东', '彩妆出口贸易，性价比优', 2019, 80, 2000, false, false, NULL, 4.0, '[]', '赵经理', 'contact@yiwu.example');

-- ========== 4. 插入商品 ==========
INSERT INTO products (supplier_id, company_id, name, category, description, moq, price_min, price_max, price_unit, lead_time, sample_available, sample_price, custom_capability) VALUES
-- 广州美肤（6款）
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '玻尿酸保湿精华液', '精华', '30ml高浓度玻尿酸精华，深层补水锁水', 100, 18.50, 35.00, '瓶', '15天', true, '¥88', true),
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '烟酰胺亮肤面膜', '面膜', '5片/盒 烟酰胺+VC双重美白', 200, 12.00, 25.00, '盒', '12天', true, '¥45', true),
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '氨基酸温和洁面乳', '洁面', '120ml 氨基酸配方 温和不紧绷', 500, 8.00, 15.00, '支', '10天', true, '¥28', false),
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '防晒霜SPF50+', '防晒', '50ml 清透不油腻 防水防汗', 300, 15.00, 28.00, '支', '12天', true, '¥58', true),
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '神经酰胺修护面霜', '面霜', '50g 敏感肌适用 修复肌肤屏障', 200, 22.00, 42.00, '瓶', '15天', true, '¥128', true),
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '茶树控油爽肤水', '化妆水', '200ml 控油收敛 清爽不黏腻', 300, 10.00, 20.00, '瓶', '10天', true, '¥38', false),
-- 上海丝芙瑞（6款）
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '丝绒哑光唇釉', '唇部', '3.5ml 不拔干 持久显色', 500, 9.00, 18.00, '支', '20天', true, '¥68', true),
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '持妆粉底液', '底妆', '30ml 遮瑕持妆12h 色号可选', 300, 25.00, 48.00, '瓶', '18天', true, '¥158', true),
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '多色眼影盘', '眼部', '12色大地色系 珠光哑光', 200, 20.00, 38.00, '盘', '25天', true, '¥98', true),
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '柔焦定妆散粉', '定妆', '10g 细腻控油 轻薄透气', 500, 12.00, 22.00, '盒', '15天', true, '¥58', false),
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '眉笔三件套', '眉部', '极细+砍刀+眉粉 防水持久', 1000, 6.00, 12.00, '套', '10天', true, '¥35', false),
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '腮红高光盘', '面部', '双色拼接 自然提气色', 300, 15.00, 28.00, '盘', '18天', true, '¥78', true),
-- 杭州妍妆（6款）
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '胶原蛋白面膜', '面膜', '5片/盒 深海鱼胶原蛋白 紧致抗皱', 100, 15.00, 30.00, '盒', '10天', true, '¥68', true),
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '烟酰胺焕亮安瓶', '精华', '2mlx28支 提亮肤色 淡化色斑', 200, 20.00, 45.00, '盒', '12天', true, '¥168', true),
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '积雪草舒缓贴片', '面膜', '10片/盒 敏感肌修护 舒缓泛红', 300, 8.00, 18.00, '盒', '8天', true, '¥38', false),
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '玻尿酸补水面膜', '面膜', '5片/盒 三层玻尿酸 深层保湿', 500, 6.00, 15.00, '盒', '8天', true, '¥28', false),
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '视黄醇抗皱精华', '精华', '30ml A醇+VE 淡化细纹', 100, 28.00, 55.00, '瓶', '15天', true, '¥198', true),
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '酵素洁面粉', '洁面', '60g 木瓜酵素 温和去角质', 200, 12.00, 25.00, '罐', '10天', true, '¥58', true),
-- 补充商品（6款）
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '身体乳清爽型', '身体护理', '300ml 烟酰胺+乳木果 24h保湿', 200, 12.00, 25.00, '瓶', '12天', true, '¥48', false),
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '护手霜套装', '手部', '3支装 植物精华 滋润不黏腻', 500, 8.00, 16.00, '套', '10天', true, '¥38', false),
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '修容高光笔', '面部', '双头设计 自然立体', 500, 7.00, 14.00, '支', '12天', true, '¥45', false),
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '持妆喷雾', '定妆', '100ml 控油定妆 持久不脱妆', 300, 10.00, 20.00, '瓶', '10天', true, '¥58', true),
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '眼霜抗蓝光', '眼部', '15g 抗蓝光+淡化黑眼圈', 200, 25.00, 50.00, '瓶', '15天', true, '¥168', true),
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '卸妆油', '卸妆', '200ml 温和卸妆 以油溶油', 300, 10.00, 22.00, '瓶', '10天', true, '¥48', false);

-- ========== 5. 询价 ==========
INSERT INTO buyer_inquiries (company_id, created_by, title, category, description, quantity, target_price, deadline, is_public, status) VALUES
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35', '寻面膜代工厂-月产10万片', '面膜', '需具备GMPC资质，支持ODM配方定制', 100000, 5.00, '2026-12-31', true, 'open'),
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35', '采购唇釉包材+灌装', '唇部', '现有配方，需灌装+包材供应', 50000, 8.00, '2026-10-15', true, 'open'),
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35', '精华液配方定制合作', '精华', '希望开发一款抗蓝光精华，需ODM能力', 20000, 15.00, '2027-01-30', true, 'open'),
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35', '采购防晒霜SPF50+现货', '防晒', '急需现货5000支，可接受现有配方', 5000, 12.00, '2026-08-30', true, 'closed');

-- ========== 6. 收藏数据 ==========
INSERT INTO supplier_favorites (user_id, supplier_id)
SELECT 'f7478991-2b89-45b7-aae8-62f58b8ffe35', id FROM suppliers
WHERE user_id IN ('cce118c5-78f5-4977-9822-87fe74085b1d','b56016f2-4daa-4dbd-a14c-a76bb94bb644','0bd203b0-a44b-4cec-a49d-e0a377c81034')
ON CONFLICT DO NOTHING;

INSERT INTO product_favorites (user_id, product_id)
SELECT 'f7478991-2b89-45b7-aae8-62f58b8ffe35', id FROM products
WHERE supplier_id IN (SELECT id FROM suppliers WHERE user_id IN ('cce118c5-78f5-4977-9822-87fe74085b1d','b56016f2-4daa-4dbd-a14c-a76bb94bb644','0bd203b0-a44b-4cec-a49d-e0a377c81034'))
ON CONFLICT DO NOTHING;

-- ========== 7. 供应商关系 ==========
-- tags 列是 TEXT[] 类型，用 PostgreSQL 数组语法
INSERT INTO buyer_supplier_relations (buyer_user_id, supplier_id, buyer_company_id, status, tags, notes, source) VALUES
('f7478991-2b89-45b7-aae8-62f58b8ffe35', (SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'cooperating', '{"核心供应商","面膜"}', '长期合作，品质稳定', 'discovery'),
('f7478991-2b89-45b7-aae8-62f58b8ffe35', (SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'contacted', '{"彩妆","新供应商"}', '已沟通，待打样', 'manual'),
('f7478991-2b89-45b7-aae8-62f58b8ffe35', (SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'potential', '{"精华","备选"}', '正在了解中', 'discovery')
ON CONFLICT DO NOTHING;

-- ========== 验证 ==========
SELECT '✅ 演示数据插入完成' AS result;
SELECT 'companies' AS tbl, COUNT(*) AS cnt FROM companies WHERE name LIKE '%演示%' OR name LIKE '%美肤%' OR name LIKE '%丝芙瑞%' OR name LIKE '%妍妆%'
UNION ALL SELECT 'suppliers', COUNT(*) FROM suppliers WHERE company_name LIKE '%美肤%' OR company_name LIKE '%丝芙瑞%' OR company_name LIKE '%妍妆%'
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'buyers', COUNT(*) FROM buyers
UNION ALL SELECT 'inquiries', COUNT(*) FROM buyer_inquiries;
