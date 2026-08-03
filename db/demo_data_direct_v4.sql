-- ============================================
-- 异采 YiCai 演示数据 - 完整版 v4
-- 覆盖：公司/品牌方/供应商/商品/询价/报价/订单/收藏/关系
-- ============================================

-- ========== 清理旧演示数据（按依赖顺序） ==========
-- 1. 先删最底层的关联表
DELETE FROM buyer_supplier_relations WHERE buyer_user_id = 'f7478991-2b89-45b7-aae8-62f58b8ffe35';
DELETE FROM supplier_favorites WHERE user_id = 'f7478991-2b89-45b7-aae8-62f58b8ffe35';
DELETE FROM product_favorites WHERE user_id = 'f7478991-2b89-45b7-aae8-62f58b8ffe35';
-- 2. 删订单/报价（引用suppliers和inquiries）
DELETE FROM buyer_orders WHERE buyer_user_id = 'f7478991-2b89-45b7-aae8-62f58b8ffe35';
DELETE FROM supplier_quotes WHERE inquiry_created_by = 'f7478991-2b89-45b7-aae8-62f58b8ffe35';
-- 3. 删询价
DELETE FROM buyer_inquiries WHERE created_by = 'f7478991-2b89-45b7-aae8-62f58b8ffe35';
-- 4. 删品牌方
DELETE FROM buyers WHERE user_id = 'f7478991-2b89-45b7-aae8-62f58b8ffe35';
-- 5. 删商品（引用suppliers）
DELETE FROM products WHERE supplier_id IN (
  SELECT id FROM suppliers WHERE user_id IN (
    'cce118c5-78f5-4977-9822-87fe74085b1d',
    'b56016f2-4daa-4dbd-a14c-a76bb94bb644',
    '0bd203b0-a44b-4cec-a49d-e0a377c81034'
  )
);
-- 6. 删供应商（引用companies）
DELETE FROM suppliers WHERE user_id IN (
  'cce118c5-78f5-4977-9822-87fe74085b1d',
  'b56016f2-4daa-4dbd-a14c-a76bb94bb644',
  '0bd203b0-a44b-4cec-a49d-e0a377c81034'
);
-- 7. 最后删公司（只删没有被其他supplier引用的演示公司）
DELETE FROM companies WHERE name IN (
  '星辰美妆（演示）','广州美肤化妆品有限公司','上海丝芙瑞生物科技有限公司','杭州妍妆科技有限公司'
) AND id NOT IN (SELECT company_id FROM suppliers);

-- ========== 1. 公司 ==========
INSERT INTO companies (name, type, status, industry, contact_email) VALUES
('星辰美妆（演示）', 'buyer', 'active', '美妆个护', 'demo_buyer@yicai.demo'),
('广州美肤化妆品有限公司', 'supplier', 'active', '护肤', 'demo_gz@yicai.demo'),
('上海丝芙瑞生物科技有限公司', 'supplier', 'active', '彩妆', 'demo_sh@yicai.demo'),
('杭州妍妆科技有限公司', 'supplier', 'active', '面膜精华', 'demo_hz@yicai.demo'),
('广州白云化妆品工厂', 'supplier', 'active', '洗护', 'contact@baiyun.example'),
('义乌彩妆供应商', 'supplier', 'active', '彩妆', 'contact@yiwu.example');

-- ========== 2. 品牌方 ==========
INSERT INTO buyers (user_id, company_name, short_name, industry, brand_name, contact_name, contact_email, description, is_verified) VALUES
('f7478991-2b89-45b7-aae8-62f58b8ffe35', '星辰美妆（演示）', '星辰美妆', '美妆个护', '星辰STARCHARM', '林采购', 'demo_buyer@yicai.demo', '国内新锐美妆品牌，专注Z世代彩妆与护肤，年销售额2亿+', true);

-- ========== 3. 供应商 ==========
INSERT INTO suppliers (company_id, user_id, company_name, short_name, category, region, description, established_year, employee_count, factory_area, is_verified, is_featured, featured_order, rating, certifications, contact_name, contact_email) VALUES
((SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), 'cce118c5-78f5-4977-9822-87fe74085b1d',
 '广州美肤化妆品有限公司', '广州美肤', '{"护肤"}', '华南', '专业护肤产品代工厂，10年GMP经验，拥有10万级净化车间，通过ISO22716/GMPC双认证，年产能5000万支', 2015, 200, 5000, true, true, 1, 4.8, '["ISO22716","GMPC","FDA"]', '张经理', 'demo_gz@yicai.demo'),
((SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), 'b56016f2-4daa-4dbd-a14c-a76bb94bb644',
 '上海丝芙瑞生物科技有限公司', '上海丝芙瑞', '{"彩妆"}', '华东', '高端彩妆研发制造企业，国际一线品牌代工经验，自有配方实验室30+，色号数据库10000+', 2012, 350, 8000, true, true, 2, 4.6, '["ISO22716","FDA","SGS"]', '李总监', 'demo_sh@yicai.demo'),
((SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '0bd203b0-a44b-4cec-a49d-e0a377c81034',
 '杭州妍妆科技有限公司', '杭州妍妆', '{"面膜"}', '华东', '面膜/精华专业工厂，支持ODM/OEM，日产面膜100万片，拥有多项植物提取专利', 2018, 120, 3000, true, true, 3, 4.5, '["ISO22716","GMPC"]', '王主管', 'demo_hz@yicai.demo');

-- ========== 4. 商品（30款） ==========
INSERT INTO products (supplier_id, company_id, name, category, description, moq, price_min, price_max, price_unit, lead_time, sample_available, sample_price, custom_capability) VALUES
-- 广州美肤（10款）
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '玻尿酸保湿精华液', '精华', '30ml高浓度玻尿酸精华，深层补水锁水，含三重玻尿酸+神经酰胺', 100, 18.50, 35.00, '瓶', '15天', true, '¥88', true),
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '烟酰胺亮肤面膜', '面膜', '5片/盒 烟酰胺+VC双重美白，提亮肤色淡化暗沉', 200, 12.00, 25.00, '盒', '12天', true, '¥45', true),
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '氨基酸温和洁面乳', '洁面', '120ml 氨基酸配方 温和不紧绷，适合敏感肌', 500, 8.00, 15.00, '支', '10天', true, '¥28', false),
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '防晒霜SPF50+', '防晒', '50ml 清透不油腻 防水防汗，户外通勤两用', 300, 15.00, 28.00, '支', '12天', true, '¥58', true),
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '神经酰胺修护面霜', '面霜', '50g 敏感肌适用 修复肌肤屏障，含角鲨烷', 200, 22.00, 42.00, '瓶', '15天', true, '¥128', true),
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '茶树控油爽肤水', '化妆水', '200ml 控油收敛 清爽不黏腻，油皮挚爱', 300, 10.00, 20.00, '瓶', '10天', true, '¥38', false),
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '身体乳清爽型', '身体护理', '300ml 烟酰胺+乳木果 24h保湿', 200, 12.00, 25.00, '瓶', '12天', true, '¥48', false),
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '护手霜套装', '手部', '3支装 植物精华 滋润不黏腻', 500, 8.00, 16.00, '套', '10天', true, '¥38', false),
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), 'VC美白安瓶精华', '精华', '2ml×28支 高浓度VC 提亮淡斑', 100, 25.00, 48.00, '盒', '15天', true, '¥168', true),
((SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), '眼霜淡化细纹', '眼部', '15g 多肽+咖啡因 淡化细纹消浮肿', 200, 28.00, 52.00, '瓶', '15天', true, '¥158', true),
-- 上海丝芙瑞（10款）
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '丝绒哑光唇釉', '唇部', '3.5ml 不拔干 持久显色，12色可选', 500, 9.00, 18.00, '支', '20天', true, '¥68', true),
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '持妆粉底液', '底妆', '30ml 遮瑕持妆12h 色号可选，养肤配方', 300, 25.00, 48.00, '瓶', '18天', true, '¥158', true),
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '多色眼影盘', '眼部', '12色大地色系 珠光哑光，压粉细腻', 200, 20.00, 38.00, '盘', '25天', true, '¥98', true),
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '柔焦定妆散粉', '定妆', '10g 细腻控油 轻薄透气', 500, 12.00, 22.00, '盒', '15天', true, '¥58', false),
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '眉笔三件套', '眉部', '极细+砍刀+眉粉 防水持久', 1000, 6.00, 12.00, '套', '10天', true, '¥35', false),
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '腮红高光盘', '面部', '双色拼接 自然提气色', 300, 15.00, 28.00, '盘', '18天', true, '¥78', true),
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '修容高光笔', '面部', '双头设计 自然立体，奶油质地', 500, 7.00, 14.00, '支', '12天', true, '¥45', false),
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '持妆喷雾', '定妆', '100ml 控油定妆 持久不脱妆', 300, 10.00, 20.00, '瓶', '10天', true, '¥58', true),
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '遮瑕液', '底妆', '6ml 精准遮瑕 遮盖力强，6色修正', 500, 8.00, 16.00, '支', '15天', true, '¥48', true),
((SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), '唇泥', '唇部', '4g 丝绒质地 显色饱满，热门色号20+', 800, 6.00, 12.00, '支', '15天', true, '¥35', false),
-- 杭州妍妆（10款）
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '胶原蛋白面膜', '面膜', '5片/盒 深海鱼胶原蛋白 紧致抗皱', 100, 15.00, 30.00, '盒', '10天', true, '¥68', true),
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '烟酰胺焕亮安瓶', '精华', '2ml×28支 提亮肤色 淡化色斑', 200, 20.00, 45.00, '盒', '12天', true, '¥168', true),
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '积雪草舒缓贴片', '面膜', '10片/盒 敏感肌修护 舒缓泛红', 300, 8.00, 18.00, '盒', '8天', true, '¥38', false),
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '玻尿酸补水面膜', '面膜', '5片/盒 三层玻尿酸 深层保湿', 500, 6.00, 15.00, '盒', '8天', true, '¥28', false),
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '视黄醇抗皱精华', '精华', '30ml A醇+VE 淡化细纹', 100, 28.00, 55.00, '瓶', '15天', true, '¥198', true),
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '酵素洁面粉', '洁面', '60g 木瓜酵素 温和去角质', 200, 12.00, 25.00, '罐', '10天', true, '¥58', true),
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '眼霜抗蓝光', '眼部', '15g 抗蓝光+淡化黑眼圈', 200, 25.00, 50.00, '瓶', '15天', true, '¥168', true),
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '卸妆油', '卸妆', '200ml 温和卸妆 以油溶油', 300, 10.00, 22.00, '瓶', '10天', true, '¥48', false),
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '二裂酵母精华水', '化妆水', '150ml 二裂酵母+烟酰胺 焕亮保湿', 300, 12.00, 25.00, '瓶', '10天', true, '¥68', true),
((SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), '泥膜清洁面膜', '面膜', '100g 火山泥+水杨酸 深层清洁毛孔', 200, 8.00, 18.00, '罐', '10天', true, '¥48', true);

-- ========== 5. 询价（8个） ==========
INSERT INTO buyer_inquiries (company_id, created_by, title, category, description, quantity, target_price, deadline, is_public, status) VALUES
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35', '寻面膜代工厂-月产10万片', '面膜', '需具备GMPC资质，支持ODM配方定制，有深海鱼胶原蛋白面膜经验优先', 100000, 5.00, '2026-12-31', true, 'open'),
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35', '采购唇釉包材+灌装', '唇部', '现有配方，需灌装+包材供应，哑光质地，12色SKU', 50000, 8.00, '2026-10-15', true, 'open'),
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35', '精华液配方定制合作', '精华', '希望开发一款抗蓝光精华，需ODM能力，30ml规格，目标零售价¥198', 20000, 15.00, '2027-01-30', true, 'open'),
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35', '采购防晒霜SPF50+现货', '防晒', '急需现货5000支，可接受现有配方，清透不油腻', 5000, 12.00, '2026-08-30', true, 'closed'),
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35', '粉底液色号扩展-新增8色', '底妆', '现有粉底液产品需要扩展色号，新增8个SKU，含冷暖调', 30000, 20.00, '2026-11-30', true, 'open'),
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35', '寻找身体乳OEM工厂', '身体护理', '300ml规格，烟酰胺+乳木果配方，月需求5万瓶', 50000, 10.00, '2027-02-28', true, 'open'),
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35', '洁面乳配方升级合作', '洁面', '希望将现有氨基酸洁面升级为氨基酸+APG复配，120ml', 80000, 6.00, '2026-12-15', true, 'open'),
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35', '眼影盘定制-9色盘', '眼部', '新系列9色眼影盘，偏光+哑光+珠光混合，需独家配方', 20000, 18.00, '2027-03-30', true, 'open');

-- ========== 6. 报价（10个） ==========
INSERT INTO supplier_quotes (inquiry_id, inquiry_company_id, inquiry_created_by, inquiry_title, supplier_id, supplier_name, unit_price, moq, lead_time, message, status) VALUES
-- 面膜代工厂询价 → 3家报价
((SELECT id FROM buyer_inquiries WHERE title='寻面膜代工厂-月产10万片' AND created_by='f7478991-2b89-45b7-aae8-62f58b8ffe35'),
 (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 '寻面膜代工厂-月产10万片',
 (SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), '杭州妍妆科技有限公司',
 4.50, 100000, '10天', '我们是面膜专业工厂，日产100万片，可提供深海鱼胶原蛋白配方，已有多款成熟配方可选。免费寄样。', 'accepted'),
((SELECT id FROM buyer_inquiries WHERE title='寻面膜代工厂-月产10万片' AND created_by='f7478991-2b89-45b7-aae8-62f58b8ffe35'),
 (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 '寻面膜代工厂-月产10万片',
 (SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), '广州美肤化妆品有限公司',
 5.20, 50000, '12天', '我们有10万级净化车间，GMPC认证，面膜产线月产能200万片。可提供ODM服务。', 'pending'),
-- 唇釉灌装询价 → 1家报价
((SELECT id FROM buyer_inquiries WHERE title='采购唇釉包材+灌装' AND created_by='f7478991-2b89-45b7-aae8-62f58b8ffe35'),
 (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 '采购唇釉包材+灌装',
 (SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), '上海丝芙瑞生物科技有限公司',
 7.50, 30000, '20天', '唇釉是我们核心品类，现有包材库50+款可选。灌装精度±0.1ml，支持小批量试产。已附报价明细。', 'pending'),
-- 精华液定制询价 → 2家报价
((SELECT id FROM buyer_inquiries WHERE title='精华液配方定制合作' AND created_by='f7478991-2b89-45b7-aae8-62f58b8ffe35'),
 (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 '精华液配方定制合作',
 (SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), '广州美肤化妆品有限公司',
 14.00, 10000, '18天', '抗蓝光精华我们有现成配方，主要成分为叶黄素+虾青素，已通过稳定性测试。可提供打样。', 'accepted'),
((SELECT id FROM buyer_inquiries WHERE title='精华液配方定制合作' AND created_by='f7478991-2b89-45b7-aae8-62f58b8ffe35'),
 (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 '精华液配方定制合作',
 (SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), '杭州妍妆科技有限公司',
 16.50, 5000, '15天', '我们有专业的精华研发团队，可完全定制配方。安瓶产线日产能50万支。', 'pending'),
-- 防晒霜现货询价 → 1家报价（已成交）
((SELECT id FROM buyer_inquiries WHERE title='采购防晒霜SPF50+现货' AND created_by='f7478991-2b89-45b7-aae8-62f58b8ffe35'),
 (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 '采购防晒霜SPF50+现货',
 (SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), '广州美肤化妆品有限公司',
 11.50, 5000, '3天', '现货充足，50ml清透款5000支可在3天内发出。已通过人体功效测试SPF50+ PA++++。', 'accepted'),
-- 粉底液色号扩展 → 1家报价
((SELECT id FROM buyer_inquiries WHERE title='粉底液色号扩展-新增8色' AND created_by='f7478991-2b89-45b7-aae8-62f58b8ffe35'),
 (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 '粉底液色号扩展-新增8色',
 (SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), '上海丝芙瑞生物科技有限公司',
 19.00, 20000, '22天', '我们有色号数据库10000+，可根据您的现有产品精准调色。含冷暖调各4色，可做打样确认。', 'pending'),
-- 身体乳OEM → 1家报价
((SELECT id FROM buyer_inquiries WHERE title='寻找身体乳OEM工厂' AND created_by='f7478991-2b89-45b7-aae8-62f58b8ffe35'),
 (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 '寻找身体乳OEM工厂',
 (SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), '广州美肤化妆品有限公司',
 9.80, 30000, '12天', '身体乳我们有3款成熟配方，烟酰胺+乳木果款是我们的爆款配方，可免费提供样品。', 'pending'),
-- 洁面乳升级 → 1家报价（被拒绝）
((SELECT id FROM buyer_inquiries WHERE title='洁面乳配方升级合作' AND created_by='f7478991-2b89-45b7-aae8-62f58b8ffe35'),
 (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 '洁面乳配方升级合作',
 (SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), '广州美肤化妆品有限公司',
 5.50, 50000, '10天', '氨基酸+APG复配配方我们已有，清洁力提升30%但温和度不降。可提供对比测试报告。', 'rejected'),
-- 眼影盘定制 → 1家报价
((SELECT id FROM buyer_inquiries WHERE title='眼影盘定制-9色盘' AND created_by='f7478991-2b89-45b7-aae8-62f58b8ffe35'),
 (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 '眼影盘定制-9色盘',
 (SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), '上海丝芙瑞生物科技有限公司',
 17.00, 15000, '25天', '9色眼影盘可做定制配色，我们的偏光粉体技术是行业领先。含模具费，打样周期7天。', 'pending');

-- ========== 7. 订单（8个，覆盖全部状态） ==========
INSERT INTO buyer_orders (company_id, buyer_user_id, inquiry_id, supplier_id, supplier_name, product_name, quantity, unit_price, delivery_date, notes, status) VALUES
-- 已完成订单
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 (SELECT id FROM buyer_inquiries WHERE title='采购防晒霜SPF50+现货' AND created_by='f7478991-2b89-45b7-aae8-62f58b8ffe35'),
 (SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), '广州美肤化妆品有限公司',
 '防晒霜SPF50+ 50ml', 5000, 11.50, '2026-07-20', '首批现货已验收合格，已入库', 'completed'),
-- 生产中订单
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 (SELECT id FROM buyer_inquiries WHERE title='寻面膜代工厂-月产10万片' AND created_by='f7478991-2b89-45b7-aae8-62f58b8ffe35'),
 (SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), '杭州妍妆科技有限公司',
 '胶原蛋白面膜 5片/盒', 100000, 4.50, '2026-09-15', '首批10万片生产中，预计9月中旬交货', 'producing'),
-- 已确认订单
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 (SELECT id FROM buyer_inquiries WHERE title='精华液配方定制合作' AND created_by='f7478991-2b89-45b7-aae8-62f58b8ffe35'),
 (SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), '广州美肤化妆品有限公司',
 '抗蓝光精华液 30ml', 20000, 14.00, '2026-11-30', '配方已确认，包材设计中，下周提供打样', 'confirmed'),
-- 待处理订单
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 NULL, (SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), '上海丝芙瑞生物科技有限公司',
 '丝绒哑光唇釉 3.5ml x12色', 60000, 7.50, '2026-10-30', '12色唇釉套装订单，待供应商确认交期', 'pending'),
-- 已完成订单2
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 NULL, (SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), '广州美肤化妆品有限公司',
 '玻尿酸保湿精华液 30ml', 10000, 18.50, '2026-06-30', '6月批次已全部交付，品质达标', 'completed'),
-- 已完成订单3
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 NULL, (SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), '上海丝芙瑞生物科技有限公司',
 '多色眼影盘 12色', 5000, 20.00, '2026-05-15', '大地色系眼影盘已入库', 'completed'),
-- 生产中订单2
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 NULL, (SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), '杭州妍妆科技有限公司',
 '烟酰胺焕亮安瓶 2ml×28支', 20000, 20.00, '2026-09-30', '安瓶产线排期中，预计9月底交付', 'producing'),
-- 已取消订单
((SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'f7478991-2b89-45b7-aae8-62f58b8ffe35',
 NULL, (SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), '广州美肤化妆品有限公司',
 '氨基酸洁面乳 120ml（旧配方）', 30000, 8.00, '2026-08-01', '因配方升级，旧版订单取消', 'cancelled');

-- ========== 8. 收藏数据 ==========
INSERT INTO supplier_favorites (user_id, supplier_id)
SELECT 'f7478991-2b89-45b7-aae8-62f58b8ffe35', id FROM suppliers
WHERE user_id IN ('cce118c5-78f5-4977-9822-87fe74085b1d','b56016f2-4daa-4dbd-a14c-a76bb94bb644','0bd203b0-a44b-4cec-a49d-e0a377c81034')
ON CONFLICT DO NOTHING;

INSERT INTO product_favorites (user_id, product_id)
SELECT 'f7478991-2b89-45b7-aae8-62f58b8ffe35', id FROM products
WHERE supplier_id IN (SELECT id FROM suppliers WHERE user_id IN ('cce118c5-78f5-4977-9822-87fe74085b1d','b56016f2-4daa-4dbd-a14c-a76bb94bb644','0bd203b0-a44b-4cec-a49d-e0a377c81034'))
ON CONFLICT DO NOTHING;

-- ========== 9. 供应商关系 ==========
INSERT INTO buyer_supplier_relations (buyer_user_id, supplier_id, buyer_company_id, status, tags, notes, source) VALUES
('f7478991-2b89-45b7-aae8-62f58b8ffe35', (SELECT id FROM suppliers WHERE user_id='cce118c5-78f5-4977-9822-87fe74085b1d'), (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'cooperating', '{"核心供应商","护肤"}', '长期合作，品质稳定，已下3单', 'discovery'),
('f7478991-2b89-45b7-aae8-62f58b8ffe35', (SELECT id FROM suppliers WHERE user_id='b56016f2-4daa-4dbd-a14c-a76bb94bb644'), (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'cooperating', '{"彩妆","核心供应商"}', '彩妆核心代工方，色号定制能力强', 'manual'),
('f7478991-2b89-45b7-aae8-62f58b8ffe35', (SELECT id FROM suppliers WHERE user_id='0bd203b0-a44b-4cec-a49d-e0a377c81034'), (SELECT id FROM companies WHERE name='星辰美妆（演示）'), 'cooperating', '{"面膜","精华"}', '面膜专业工厂，性价比高，正在扩产合作', 'discovery')
ON CONFLICT DO NOTHING;

-- ========== 验证 ==========
SELECT '✅ 演示数据完整版插入完成' AS result;
SELECT 'companies' AS tbl, COUNT(*) AS cnt FROM companies WHERE name LIKE '%演示%' OR name LIKE '%美肤%' OR name LIKE '%丝芙瑞%' OR name LIKE '%妍妆%' OR name LIKE '%白云%' OR name LIKE '%义乌%'
UNION ALL SELECT 'suppliers', COUNT(*) FROM suppliers WHERE company_name LIKE '%美肤%' OR company_name LIKE '%丝芙瑞%' OR company_name LIKE '%妍妆%'
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'buyers', COUNT(*) FROM buyers
UNION ALL SELECT 'inquiries', COUNT(*) FROM buyer_inquiries
UNION ALL SELECT 'quotes', COUNT(*) FROM supplier_quotes
UNION ALL SELECT 'orders', COUNT(*) FROM buyer_orders
UNION ALL SELECT 'favorites_s', COUNT(*) FROM supplier_favorites
UNION ALL SELECT 'favorites_p', COUNT(*) FROM product_favorites
UNION ALL SELECT 'relations', COUNT(*) FROM buyer_supplier_relations;
