-- ============================================
-- 异采 YiCai 演示数据 - 一键部署
-- ============================================
-- 使用方式：通过 setup_demo.html 页面自动创建账号并调用 setup_demo_data 函数
-- 也可手动执行：先创建 auth 用户获取 UUID，再调用函数
--
-- SELECT setup_demo_data(
--   '品牌方演示用户UUID',
--   '广州供应商UUID',
--   '上海供应商UUID',
--   '杭州供应商UUID'
-- );

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
  v_product_ids UUID[];
  v_buyer_id UUID;
  v_inquiry_ids BIGINT[];
  v_sid UUID;
  v_pid UUID;
  v_cid BIGINT;
  i INT;
BEGIN
  -- ============================================
  -- 0a. 确保依赖表存在
  -- ============================================
  CREATE TABLE IF NOT EXISTS buyer_inquiries (
    id BIGSERIAL PRIMARY KEY,
    company_id BIGINT,
    created_by UUID NOT NULL,
    title TEXT NOT NULL,
    category TEXT,
    description TEXT,
    quantity INTEGER,
    target_price DECIMAL(12,2),
    deadline DATE,
    is_public BOOLEAN DEFAULT true,
    status TEXT DEFAULT 'open',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
  );

  CREATE TABLE IF NOT EXISTS buyers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID UNIQUE,
    company_name TEXT NOT NULL,
    short_name TEXT,
    industry TEXT DEFAULT '',
    brand_name TEXT DEFAULT '',
    contact_name TEXT DEFAULT '',
    contact_phone TEXT DEFAULT '',
    contact_email TEXT DEFAULT '',
    address TEXT DEFAULT '',
    description TEXT DEFAULT '',
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
  );

  CREATE TABLE IF NOT EXISTS supplier_favorites (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    supplier_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, supplier_id)
  );

  CREATE TABLE IF NOT EXISTS product_favorites (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    product_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, product_id)
  );

  CREATE TABLE IF NOT EXISTS buyer_supplier_relations (
    id BIGSERIAL PRIMARY KEY,
    buyer_user_id UUID NOT NULL,
    supplier_id UUID NOT NULL,
    buyer_company_id BIGINT,
    status TEXT DEFAULT 'potential',
    tags TEXT[] DEFAULT '{}',
    notes TEXT DEFAULT '',
    source TEXT DEFAULT 'discovery',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(buyer_user_id, supplier_id)
  );

  -- ============================================
  -- 0b. 清理旧演示数据（按依赖顺序）
  -- ============================================
  DELETE FROM buyer_supplier_relations WHERE buyer_user_id = p_buyer_user_id;
  DELETE FROM supplier_favorites WHERE user_id = p_buyer_user_id;
  DELETE FROM product_favorites WHERE user_id = p_buyer_user_id;
  DELETE FROM buyer_inquiries WHERE created_by = p_buyer_user_id;
  DELETE FROM buyers WHERE user_id = p_buyer_user_id;

  -- 删除演示供应商关联数据
  FOR v_sid IN SELECT id FROM suppliers WHERE user_id IN (p_supplier1_user_id, p_supplier2_user_id, p_supplier3_user_id)
  LOOP
    DELETE FROM product_favorites WHERE product_id IN (SELECT id FROM products WHERE supplier_id = v_sid);
    DELETE FROM products WHERE supplier_id = v_sid;
  END LOOP;
  DELETE FROM suppliers WHERE user_id IN (p_supplier1_user_id, p_supplier2_user_id, p_supplier3_user_id);

  -- 删除演示公司
  DELETE FROM companies WHERE name IN (
    '广州美肤化妆品有限公司','上海丝芙瑞生物科技有限公司','杭州妍妆科技有限公司',
    '山东瑞安日化集团','福建清源生物科技有限公司','成都锦绣美妆有限公司',
    '星辰美妆（演示）'
  );

  -- ============================================
  -- 1. 创建公司
  -- ============================================
  INSERT INTO companies (name, short_name, type, region, status) VALUES
    ('广州美肤化妆品有限公司', '广州美肤', 'supplier', '广东', 'active'),
    ('上海丝芙瑞生物科技有限公司', '上海丝芙瑞', 'supplier', '上海', 'active'),
    ('杭州妍妆科技有限公司', '杭州妍妆', 'supplier', '浙江', 'active'),
    ('山东瑞安日化集团', '山东瑞安', 'supplier', '山东', 'active'),
    ('福建清源生物科技有限公司', '福建清源', 'supplier', '福建', 'active'),
    ('成都锦绣美妆有限公司', '成都锦绣', 'supplier', '四川', 'active'),
    ('星辰美妆（演示）', '星辰美妆', 'buyer', '广东', 'active')
  RETURNING id INTO v_company_ids;

  -- 获取各公司ID
  SELECT id INTO v_cid FROM companies WHERE name = '星辰美妆（演示）';
  UPDATE companies SET id = v_cid WHERE name = '星辰美妆（演示）';

  -- 重新获取所有公司ID（按名称）
  DECLARE
    c1 BIGINT; c2 BIGINT; c3 BIGINT; c4 BIGINT; c5 BIGINT; c6 BIGINT; c7 BIGINT;
  BEGIN
    SELECT id INTO c1 FROM companies WHERE name = '广州美肤化妆品有限公司';
    SELECT id INTO c2 FROM companies WHERE name = '上海丝芙瑞生物科技有限公司';
    SELECT id INTO c3 FROM companies WHERE name = '杭州妍妆科技有限公司';
    SELECT id INTO c4 FROM companies WHERE name = '山东瑞安日化集团';
    SELECT id INTO c5 FROM companies WHERE name = '福建清源生物科技有限公司';
    SELECT id INTO c6 FROM companies WHERE name = '成都锦绣美妆有限公司';
    SELECT id INTO c7 FROM companies WHERE name = '星辰美妆（演示）';
    v_company_ids := ARRAY[c1, c2, c3, c4, c5, c6, c7];
  END;

  -- ============================================
  -- 2. 创建供应商档案
  -- ============================================

  -- 供应商1：广州美肤（精选 + 认证）
  INSERT INTO suppliers (
    company_id, user_id, company_name, short_name, category, region,
    description, established_year, employee_count, factory_area,
    is_verified, is_featured, featured_order, rating,
    certifications, contact_name, contact_email,
  ) VALUES (
    v_company_ids[1], p_supplier1_user_id,
    '广州美肤化妆品有限公司', '广州美肤',
    '护肤,面膜,精华', '广东',
    '专注护肤品研发生产15年，拥有10万级净化车间和全自动化生产线。通过ISO22716/GMPC双认证，年产能超5000万件。擅长氨基酸洁面、玻尿酸精华、面膜贴等品类，支持OEM/ODM全链路定制服务。',
    2009, 350, 12000,
    true, true, 1, 4.8,
    ARRAY['ISO22716', 'GMPC', 'FDA注册', 'ISO9001'],
    '张经理', 'demo_gz@yicai.demo',
    '氨基酸洁面乳,玻尿酸面膜,烟酰胺精华液,防晒霜', '500-5000', '¥8-120'
  ) RETURNING id INTO v_sid;
  v_supplier_ids := array_append(v_supplier_ids, v_sid);

  -- 供应商2：上海丝芙瑞（认证）
  INSERT INTO suppliers (
    company_id, user_id, company_name, short_name, category, region,
    description, established_year, employee_count, factory_area,
    is_verified, is_featured, rating,
    certifications, contact_name, contact_email,
  ) VALUES (
    v_company_ids[2], p_supplier2_user_id,
    '上海丝芙瑞生物科技有限公司', '上海丝芙瑞',
    '彩妆,唇部,香氛', '上海',
    '中法合资高端彩妆制造商，拥有国际一流的研发团队和实验室。主打高端彩妆线，产品涵盖口红、粉底液、眼影盘、香水等。与多个国际品牌有合作经验，支持小批量定制。',
    2015, 180, 6500,
    true, false, 4.5,
    ARRAY['ISO22716', 'GMP'],
    'Sophie 李', 'demo_sh@yicai.demo',
    '哑光口红,粉底液,眼影盘,香水', '300-3000', '¥15-280'
  ) RETURNING id INTO v_sid;
  v_supplier_ids := array_append(v_supplier_ids, v_sid);

  -- 供应商3：杭州妍妆（精选 + 认证）
  INSERT INTO suppliers (
    company_id, user_id, company_name, short_name, category, region,
    description, established_year, employee_count, factory_area,
    is_verified, is_featured, featured_order, rating,
    certifications, contact_name, contact_email,
  ) VALUES (
    v_company_ids[3], p_supplier3_user_id,
    '杭州妍妆科技有限公司', '杭州妍妆',
    '洗护,防晒,身体护理', '浙江',
    '绿色洗护专家，专注天然植物配方。拥有自主知识产权的草本提取技术，产品通过欧盟ECOCERT有机认证。主打洗发水、沐浴露、防晒霜、身体乳等品类，远销东南亚和日韩市场。',
    2012, 220, 8000,
    true, true, 2, 4.6,
    ARRAY['ECOCERT有机认证', 'ISO22716', 'SGS检测'],
    '王总监', 'demo_hz@yicai.demo',
    '氨基酸洗发水,沐浴露,防晒霜,身体乳', '1000-10000', '¥5-68'
  ) RETURNING id INTO v_sid;
  v_supplier_ids := array_append(v_supplier_ids, v_sid);

  -- 供应商4：山东瑞安（认证，无user_id - 纯展示）
  INSERT INTO suppliers (
    company_id, company_name, short_name, category, region,
    description, established_year, employee_count, factory_area,
    is_verified, is_featured, rating,
    certifications, contact_name, contact_email,
  ) VALUES (
    v_company_ids[4],
    '山东瑞安日化集团', '山东瑞安',
    '个护,洗护,身体护理', '山东',
    '华北地区最大的日化生产基地之一，拥有完整的产业链布局。从原料生产到成品灌装全链覆盖，日产能超20万件。通过BSCI社会责任审计，产品远销30+国家和地区。',
    2005, 500, 25000,
    true, false, 4.3,
    ARRAY['ISO9001', 'ISO22716', 'BSCI'],
    '刘部长', 'sales@sdruihua.example.com',
    '洗手液,牙膏,洗衣液,柔顺剂', '3000-30000', '¥2-35'
  ) RETURNING id INTO v_sid;
  v_supplier_ids := array_append(v_supplier_ids, v_sid);

  -- 供应商5：福建清源（无user_id - 纯展示）
  INSERT INTO suppliers (
    company_id, company_name, short_name, category, region,
    description, established_year, employee_count, factory_area,
    is_verified, is_featured, rating,
    certifications, contact_name, contact_email,
  ) VALUES (
    v_company_ids[5],
    '福建清源生物科技有限公司', '福建清源',
    '香氛,身体护理,精华', '福建',
    '天然植物精油提取专家，拥有自有茶园和草药种植基地。专注芳香疗法和天然护肤领域，产品通过USDA有机认证和HALAL认证。',
    2016, 85, 3000,
    true, false, 4.7,
    ARRAY['USDA有机', 'HALAL', 'ISO22716'],
    '陈师傅', 'info@fqby.example.com',
    '精油,香薰蜡烛,纯露,面膜', '200-2000', '¥12-180'
  ) RETURNING id INTO v_sid;
  v_supplier_ids := array_append(v_supplier_ids, v_sid);

  -- 供应商6：成都锦绣（精选，无user_id - 纯展示）
  INSERT INTO suppliers (
    company_id, company_name, short_name, category, region,
    description, established_year, employee_count, factory_area,
    is_verified, is_featured, featured_order, rating,
    certifications, contact_name, contact_email,
  ) VALUES (
    v_company_ids[6],
    '成都锦绣美妆有限公司', '成都锦绣',
    '彩妆,护肤', '四川',
    '西南地区彩妆领军企业，以蜀绣文化为灵感打造国潮彩妆IP。拥有自有色彩实验室，年开发新色号200+。主打口红、腮红、眼影等国潮系列。',
    2018, 120, 4500,
    true, true, 3, 4.4,
    ARRAY['ISO22716', 'NMPA备案'],
    '赵经理', 'contact@jjinmei.example.com',
    '口红,腮红,眼影,高光', '500-5000', '¥8-98'
  ) RETURNING id INTO v_sid;
  v_supplier_ids := array_append(v_supplier_ids, v_sid);

  -- ============================================
  -- 3. 创建商品（30+款）
  -- ============================================

  -- === 广州美肤的商品 (supplier_ids[1]) ===
  INSERT INTO products (supplier_id, company_id, name, category, description, moq, price_min, price_max, price_unit, lead_time, custom_capability, sample_available, sample_price, status)
  VALUES
  (v_supplier_ids[1], v_company_ids[1], '氨基酸温和洁面乳 120ml', '护肤', '采用椰油酰甘氨酸钾为主要表活剂，pH5.5弱酸性配方，温和不紧绷。添加透明质酸钠和积雪草提取物，洁面同时保湿修护。适合敏感肌和干性肌肤日常使用。', 1000, 8.50, 15.00, '支', '15-20天', true, true, '25', 'active'),
  (v_supplier_ids[1], v_company_ids[1], '玻尿酸保湿面膜 5片/盒', '面膜', '三重玻尿酸（大分子锁水+中分子保湿+小分子渗透）搭配神经酰胺，深层补水修护。膜布采用日本进口铜氨纤维，轻薄服帖。每片精华液含量≥25ml。', 500, 12.00, 28.00, '盒', '12-18天', true, true, '15', 'active'),
  (v_supplier_ids[1], v_company_ids[1], '烟酰胺亮肤精华液 30ml', '精华', '5%烟酰胺+α-熊果苷+VC衍生物三重亮肤配方，有效改善暗沉、均匀肤色。质地清爽不黏腻，适合所有肤质。通过人体功效测试，28天肤色提亮可见。', 1000, 18.00, 45.00, '瓶', '15-25天', true, true, '30', 'active'),
  (v_supplier_ids[1], v_company_ids[1], '清爽防晒乳 SPF50+ PA++++', '防晒', '物化结合防晒体系，氧化锌+4种化学防晒剂，广谱防护UVA/UVB。添加红没药醇舒缓成分，防晒同时镇静肌肤。防水抗汗配方，适合户外场景。', 2000, 10.00, 22.00, '支', '15-20天', true, true, '20', 'active'),
  (v_supplier_ids[1], v_company_ids[1], '视黄醇抗皱面霜 50g', '护肤', '0.3%包裹型视黄醇+胜肽复合物，渐进式抗皱不刺激。搭配角鲨烷和乳木果油深层滋养。真空泵包装，保持成分活性。适合25岁以上初抗老需求。', 500, 25.00, 68.00, '瓶', '20-30天', true, false, '', 'active'),
  (v_supplier_ids[1], v_company_ids[1], '积雪草修护凝胶 100g', '护肤', '高纯度积雪草苷（纯度≥90%）+泛醇+尿囊素三重修护配方。轻薄凝胶质地，快速吸收不黏腻。适用于医美后修护、换季敏感、痘印淡化等场景。', 1000, 9.00, 18.00, '罐', '12-15天', true, true, '12', 'active'),

  -- === 上海丝芙瑞的商品 (supplier_ids[2]) ===
  (v_supplier_ids[2], v_company_ids[2], '丝绒哑光唇釉 #A01复古红', '唇部', '法国进口原料配方，高显色一发上色。丝绒哑光质地，不拔干不卡纹。添加荷荷巴油和维生素E，长效保湿8小时。不沾杯不脱色，持妆12小时+。', 300, 15.00, 38.00, '支', '10-15天', true, true, '20', 'active'),
  (v_supplier_ids[2], v_company_ids[2], '持妆无瑕粉底液 30ml', '彩妆', '微米级粉体技术，轻薄遮瑕不假面。24小时持妆配方，控油抗汗。20个色号可选，覆盖白皙到健康肤色。添加透明质酸和甘油，妆感水润不干燥。', 500, 22.00, 55.00, '瓶', '15-20天', true, true, '35', 'active'),
  (v_supplier_ids[2], v_company_ids[2], '星空梦幻眼影盘 12色', '彩妆', '哑光+珠光+闪片三种质地组合，日常到派对全场景覆盖。粉质细腻飞粉少，显色度高易晕染。含天然云母和珍珠粉，温和不刺激眼部肌肤。磁吸翻盖包装，高级感十足。', 300, 28.00, 68.00, '盘', '15-25天', true, true, '40', 'active'),
  (v_supplier_ids[2], v_company_ids[2], '花漾倾心香水 50ml EDP', '香氛', '前调：佛手柑/黑加仑；中调：大马士革玫瑰/茉莉；基调：白麝香/檀香。法国格拉斯香精原料，浓度15-20%持久留香6-8小时。手工吹制玻璃瓶身，每支独立编号。', 200, 45.00, 120.00, '瓶', '20-30天', true, true, '60', 'active'),
  (v_supplier_ids[2], v_company_ids[2], '眉笔三色合一 0.9g', '彩妆', '砍刀头+螺旋刷+眉粉三合一设计。防水防汗配方，持久不晕染。笔芯软硬适中，画出根根分明自然眉形。旋转出芯设计，无需削笔。', 1000, 5.00, 12.00, '支', '7-10天', true, true, '8', 'active'),

  -- === 杭州妍妆的商品 (supplier_ids[3]) ===
  (v_supplier_ids[3], v_company_ids[3], '氨基酸洗发露 500ml 控油蓬松', '洗护', '椰油酰胺丙基甜菜碱+氨基酸双重表活，温和清洁不伤头皮。添加侧柏叶提取物和PCA锌，控油去屑。无硅油配方，洗后蓬松不塌。清新白茶香调。', 2000, 6.00, 15.00, '瓶', '10-15天', true, true, '10', 'active'),
  (v_supplier_ids[3], v_company_ids[3], '烟酰胺美白身体乳 400ml', '身体护理', '3%烟酰胺+VC乙基醚+光甘草定三重美白配方。质地如奶油般丝滑，涂抹即化不黏腻。400ml大容量，全身可用。淡雅铃兰香型，留香持久。', 1000, 8.00, 22.00, '瓶', '10-15天', true, true, '12', 'active'),
  (v_supplier_ids[3], v_company_ids[3], '清透水感防晒喷雾 SPF50+', '防晒', '高压喷雾罐装，360度均匀喷洒。轻薄水感质地，喷完无需涂抹。物化结合防晒体系，广谱防护。添加芦荟和黄瓜提取物，防晒同时舒缓保湿。150ml便携装，可带上飞机。', 3000, 8.00, 18.00, '罐', '12-18天', true, true, '12', 'active'),
  (v_supplier_ids[3], v_company_ids[3], '茶树精油沐浴露 750ml', '洗护', '澳洲茶树精油+迷迭香+薄荷三重植物配方。丰富泡沫易冲洗，洗后清爽不假滑。天然抗菌控油，适合背部痘痘肌肤。大容量家庭装。', 2000, 5.00, 12.00, '瓶', '10-12天', true, false, '', 'active'),
  (v_supplier_ids[3], v_company_ids[3], '护手霜套装 30ml×6支', '身体护理', '6种香型组合：玫瑰/薰衣草/樱花/蜂蜜/牛油果/绿茶。乳木果油+甘油+角鲨烷深层滋养。清爽不黏腻配方，涂完即可触碰手机。精美礼盒包装，送礼自用两相宜。', 500, 12.00, 28.00, '套', '10-15天', true, true, '18', 'active'),

  -- === 山东瑞安的商品 (supplier_ids[4]) ===
  (v_supplier_ids[4], v_company_ids[4], '抑菌洗手液 500ml', '个护', '对氯间二甲苯抑菌配方，抑菌率99.9%。温和PH平衡配方，不伤手。泵头设计，使用方便。清新柠檬香型，有效去除异味。适用于家庭、办公、公共场所。', 5000, 2.50, 6.00, '瓶', '7-10天', false, true, '5', 'active'),
  (v_supplier_ids[4], v_company_ids[4], '酵素洗衣液 2L 去渍增亮', '洗护', '复合酵素配方（蛋白酶+脂肪酶+淀粉酶），深层分解顽固污渍。低泡易漂洗，省水环保。不含荧光增白剂，婴幼儿衣物也可使用。薰衣草持久留香。', 5000, 4.00, 10.00, '瓶', '7-10天', false, false, '', 'active'),
  (v_supplier_ids[4], v_company_ids[4], '竹炭牙膏 120g 三重美白', '个护', '竹炭微粒+水合硅石双重摩擦剂，温和去除牙渍。氟化钠防蛀配方，含氟量0.10%-0.15%。薄荷+绿茶双重口味，清新口气持久。', 10000, 1.80, 4.50, '支', '7-10天', true, true, '3', 'active'),

  -- === 福建清源的商品 (supplier_ids[5]) ===
  (v_supplier_ids[5], v_company_ids[5], '玫瑰精油 10ml 天然蒸馏', '香氛', '采用山东平阴重瓣红玫瑰，清晨手工采摘。水蒸气蒸馏法提取，100%纯天然。每10ml需要约3000朵玫瑰。可用于香薰、调配香水、护肤添加。通过GC-MS纯度检测。', 200, 35.00, 88.00, '瓶', '7-12天', false, true, '45', 'active'),
  (v_supplier_ids[5], v_company_ids[5], '薰衣草香薰蜡烛 200g', '香氛', '天然大豆蜡+蜂蜡混合基底，燃烧均匀无烟。添加法国薰衣草精油，舒缓助眠。手工浇注玻璃杯装，燃烧时间约40小时。木芯设计，燃烧时有噼啪声响，氛围感满满。', 500, 15.00, 38.00, '罐', '10-15天', true, true, '22', 'active'),
  (v_supplier_ids[5], v_company_ids[5], '茉莉纯露 200ml 补水喷雾', '香氛', '广西横县茉莉花蒸馏提取，无酒精无香精。天然花香补水喷雾，随时随地refresh。可作爽肤水、定妆喷雾、香薰加湿等多种用途。食品级原料，温和不刺激。', 1000, 8.00, 20.00, '瓶', '7-10天', false, true, '12', 'active'),

  -- === 成都锦绣的商品 (supplier_ids[6]) ===
  (v_supplier_ids[6], v_company_ids[6], '蜀韵国潮口红 #S01海棠红', '唇部', '灵感源自蜀绣海棠花纹，独特色号显白不挑皮。丝绸哑光质地，一抹上色不反复。添加维生素E和荷荷巴油，不拔干。磁吸方管包装，蜀绣纹理浮雕工艺。', 500, 18.00, 48.00, '支', '12-18天', true, true, '28', 'active'),
  (v_supplier_ids[6], v_company_ids[6], '锦绣腮红盘 4色 032#桃花坞', '彩妆', '4色渐变腮红，可单色可混合。哑光+珠光双质地，自然好气色。粉质细腻如丝绸，上脸服帖不飞粉。熊猫元素浮雕盘盖，国风设计获红点奖。含角鲨烷成分，亲肤不干燥。', 500, 15.00, 42.00, '盘', '12-20天', true, true, '25', 'active'),
  (v_supplier_ids[6], v_company_ids[6], '鎏金高光修容盘', '彩妆', '高光+修容+古铜三合一，立体小V脸一盘搞定。金色偏光高光，细腻闪片不显毛孔。哑光修容自然不脏，适合亚洲肤色。磁吸翻盖+镜子，补妆方便。', 300, 20.00, 55.00, '盘', '15-20天', true, true, '35', 'active');

  -- ============================================
  -- 4. 创建品牌方档案
  -- ============================================
  INSERT INTO buyers (user_id, company_name, short_name, industry, brand_name, contact_name, contact_email, description, is_verified)
  VALUES (
    p_buyer_user_id,
    '星辰美妆（演示）', '星辰美妆',
    '美妆个护', '星辰STARCHARM',
    '林经理', 'demo_buyer@yicai.demo',
    '星辰美妆是一家新锐国货美妆品牌，主打Z世代年轻消费群体。目前正在寻找优质的OEM/ODM供应商，重点关注护肤和彩妆品类。',
    true
  ) RETURNING id INTO v_buyer_id;

  -- ============================================
  -- 5. 创建品牌方询价记录
  -- ============================================
  INSERT INTO buyer_inquiries (company_id, created_by, title, category, description, quantity, target_price, deadline, is_public, status, created_at)
  VALUES
  (v_company_ids[7], p_buyer_user_id,
   '寻找氨基酸洁面乳OEM供应商', '护肤',
   '我司星辰美妆计划推出一款氨基酸洁面乳新品，目标零售价39.9元/120ml。需要寻找有相关经验的供应商进行OEM合作。要求：1. 支持定制配方和包装 2. MOQ 3000支以内 3. 交期20天以内 4. 具备GMPC或ISO22716认证',
   3000, 12.00, CURRENT_DATE + INTERVAL '30 days', true, 'open',
   CURRENT_DATE - INTERVAL '3 days'),

  (v_company_ids[7], p_buyer_user_id,
   '定制国潮系列眼影盘', '彩妆',
   '品牌新品开发项目，计划推出蜀风雅韵系列眼影盘。设计要求：中国风元素，4-6色组合，哑光+珠光搭配。目标零售价79元/盘。需要有国潮彩妆生产经验的供应商。',
   2000, 25.00, CURRENT_DATE + INTERVAL '45 days', true, 'open',
   CURRENT_DATE - INTERVAL '7 days'),

  (v_company_ids[7], p_buyer_user_id,
   '采购天然植物精油一批', '香氛',
   '为品牌香薰线采购天然精油原料。需求品类：玫瑰精油、薰衣草精油、茶树精油各500瓶（10ml）。要求100%纯天然，有GC-MS检测报告。优先考虑有有机认证的供应商。',
   1500, 40.00, CURRENT_DATE + INTERVAL '20 days', false, 'awarded',
   CURRENT_DATE - INTERVAL '15 days'),

  (v_company_ids[7], p_buyer_user_id,
   '防晒霜新品开发询价', '防晒',
   '开发一款SPF50+ PA++++的清透防晒乳，目标肤感：水感不油腻，适合油皮和混合皮。容量50ml，目标零售价59.9元。需要供应商提供配方打样和功效测试报告。',
   5000, 10.00, CURRENT_DATE + INTERVAL '60 days', true, 'open',
   CURRENT_DATE - INTERVAL '1 day');

  -- 获取询价IDs
  SELECT ARRAY(SELECT id FROM buyer_inquiries WHERE created_by = p_buyer_user_id ORDER BY created_at)
  INTO v_inquiry_ids;

  -- ============================================
  -- 6. 创建品牌方收藏
  -- ============================================
  -- 收藏供应商（收藏前3个有user_id的供应商）
  INSERT INTO supplier_favorites (user_id, supplier_id, created_at)
  SELECT p_buyer_user_id, s.id, CURRENT_DATE - (random() * 10)::INT
  FROM suppliers s
  WHERE s.id IN (v_supplier_ids[1], v_supplier_ids[2], v_supplier_ids[3]);

  -- 收藏商品（收藏前6个商品）
  INSERT INTO product_favorites (user_id, product_id, created_at)
  SELECT p_buyer_user_id, p.id, CURRENT_DATE - (random() * 10)::INT
  FROM products p
  WHERE p.supplier_id IN (v_supplier_ids[1], v_supplier_ids[2])
  ORDER BY random()
  LIMIT 6;

  -- ============================================
  -- 7. 创建品牌方-供应商关系
  -- ============================================
  INSERT INTO buyer_supplier_relations (buyer_user_id, supplier_id, buyer_company_id, status, tags, notes, source, created_at)
  VALUES
  (p_buyer_user_id, v_supplier_ids[1], v_company_ids[7], 'cooperating',
   ARRAY['核心供应商', '护肤品类'], '已合作洁面乳和面膜两个品类，品质稳定，交期准时。', 'order',
   CURRENT_DATE - INTERVAL '60 days'),
  (p_buyer_user_id, v_supplier_ids[2], v_company_ids[7], 'contacted',
   ARRAY['彩妆供应商', '洽谈中'], '已对接彩妆项目负责人，正在讨论口红和眼影盘的定制方案。', 'discovery',
   CURRENT_DATE - INTERVAL '10 days'),
  (p_buyer_user_id, v_supplier_ids[3], v_company_ids[7], 'potential',
   ARRAY['洗护备选'], '在发现页找到，初步了解产品线和报价，待进一步沟通。', 'discovery',
   CURRENT_DATE - INTERVAL '3 days');

  -- ============================================
  -- 8. 为供应商创建一些收到的询盘（inquiries表，供应商侧）
  -- ============================================
  BEGIN
    INSERT INTO inquiries (supplier_id, buyer_company_name, buyer_contact_name, buyer_contact_email, title, category, description, quantity, status, created_at)
    SELECT v_supplier_ids[1], '星辰美妆', '林经理', 'demo_buyer@yicai.demo',
      '氨基酸洁面乳OEM合作', '护肤',
      '希望合作开发一款氨基酸洁面乳，目标零售价39.9元/120ml，需要定制配方和包装设计。',
      3000, 'open', CURRENT_DATE - INTERVAL '3 days';

    INSERT INTO inquiries (supplier_id, buyer_company_name, buyer_contact_name, buyer_contact_email, title, category, description, quantity, status, created_at)
    SELECT v_supplier_ids[2], '星辰美妆', '林经理', 'demo_buyer@yicai.demo',
      '国潮口红定制', '彩妆',
      '希望定制一款中国风口红，色号参考海棠红，需要定制包装（磁吸管+蜀绣纹理）。',
      2000, 'quoted', CURRENT_DATE - INTERVAL '5 days';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '跳过供应商询盘创建（inquiries表结构不匹配）: %', SQLERRM;
  END;

  -- ============================================
  -- 完成
  -- ============================================
  RETURN format(
    '✅ 演示数据部署完成！创建 %s 家公司、%s 个供应商、%s 款商品、%s 条询价记录。',
    array_length(v_company_ids, 1),
    array_length(v_supplier_ids, 1),
    (SELECT count(*) FROM products WHERE supplier_id = ANY(v_supplier_ids)),
    array_length(v_inquiry_ids, 1)
  );
END;
$$;

-- 授权
GRANT EXECUTE ON FUNCTION setup_demo_data(UUID, UUID, UUID, UUID) TO authenticated, anon;
