-- ============================================
-- 异采 YiCai 演示数据 - 一键部署 v3
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
BEGIN
  -- ============================================
  -- 0a. 确保依赖表存在
  -- ============================================
  CREATE TABLE IF NOT EXISTS buyer_inquiries (
    id BIGSERIAL PRIMARY KEY, company_id BIGINT, created_by UUID NOT NULL,
    title TEXT NOT NULL, category TEXT, description TEXT, quantity INTEGER,
    target_price DECIMAL(12,2), deadline DATE, is_public BOOLEAN DEFAULT true,
    status TEXT DEFAULT 'open', created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
  );
  CREATE TABLE IF NOT EXISTS buyers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY, user_id UUID UNIQUE,
    company_name TEXT NOT NULL, short_name TEXT, industry TEXT DEFAULT '',
    brand_name TEXT DEFAULT '', contact_name TEXT DEFAULT '', contact_phone TEXT DEFAULT '',
    contact_email TEXT DEFAULT '', address TEXT DEFAULT '', description TEXT DEFAULT '',
    is_verified BOOLEAN DEFAULT false, created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
  );
  CREATE TABLE IF NOT EXISTS supplier_favorites (
    id BIGSERIAL PRIMARY KEY, user_id UUID NOT NULL, supplier_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(), UNIQUE(user_id, supplier_id)
  );
  CREATE TABLE IF NOT EXISTS product_favorites (
    id BIGSERIAL PRIMARY KEY, user_id UUID NOT NULL, product_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(), UNIQUE(user_id, product_id)
  );
  CREATE TABLE IF NOT EXISTS buyer_supplier_relations (
    id BIGSERIAL PRIMARY KEY, buyer_user_id UUID NOT NULL, supplier_id UUID NOT NULL,
    buyer_company_id BIGINT, status TEXT DEFAULT 'potential', tags TEXT[] DEFAULT '{}',
    notes TEXT DEFAULT '', source TEXT DEFAULT 'discovery',
    created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(buyer_user_id, supplier_id)
  );

  -- ============================================
  -- 0b. 清理旧演示数据
  -- ============================================
  DELETE FROM buyer_supplier_relations WHERE buyer_user_id = p_buyer_user_id;
  DELETE FROM supplier_favorites WHERE user_id = p_buyer_user_id;
  DELETE FROM product_favorites WHERE user_id = p_buyer_user_id;
  DELETE FROM buyer_inquiries WHERE created_by = p_buyer_user_id;
  DELETE FROM buyers WHERE user_id = p_buyer_user_id;

  FOR v_sid IN SELECT id FROM suppliers WHERE user_id IN (p_supplier1_user_id, p_supplier2_user_id, p_supplier3_user_id)
  LOOP
    DELETE FROM product_favorites WHERE product_id IN (SELECT id FROM products WHERE supplier_id = v_sid);
    DELETE FROM products WHERE supplier_id = v_sid;
  END LOOP;
  DELETE FROM suppliers WHERE user_id IN (p_supplier1_user_id, p_supplier2_user_id, p_supplier3_user_id);
  DELETE FROM companies WHERE name IN (
    '广州美肤化妆品有限公司','上海丝芙瑞生物科技有限公司','杭州妍妆科技有限公司',
    '山东瑞安日化集团','福建清源生物科技有限公司','成都锦绣美妆有限公司','星辰美妆（演示）'
  );

  -- ============================================
  -- 1. 创建公司
  -- ============================================
  INSERT INTO companies (name, short_name, type, region, status) VALUES
    ('广州美肤化妆品有限公司','广州美肤','supplier','广东','active'),
    ('上海丝芙瑞生物科技有限公司','上海丝芙瑞','supplier','上海','active'),
    ('杭州妍妆科技有限公司','杭州妍妆','supplier','浙江','active'),
    ('山东瑞安日化集团','山东瑞安','supplier','山东','active'),
    ('福建清源生物科技有限公司','福建清源','supplier','福建','active'),
    ('成都锦绣美妆有限公司','成都锦绣','supplier','四川','active'),
    ('星辰美妆（演示）','星辰美妆','buyer','广东','active');

  -- ============================================
  -- 2. 创建供应商档案
  -- ============================================
  -- 供应商1：广州美肤（精选+认证，有账号）
  INSERT INTO suppliers (company_id,user_id,company_name,short_name,category,region,description,established_year,employee_count,factory_area,is_verified,is_featured,featured_order,rating,certifications,contact_name,contact_email)
  VALUES (
    (SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'), p_supplier1_user_id,
    '广州美肤化妆品有限公司','广州美肤','护肤,面膜,精华','广东',
    '专注护肤品研发生产15年，拥有10万级净化车间和全自动化生产线。通过ISO22716/GMPC双认证，年产能超5000万件。',
    2009,350,12000,true,true,1,4.8,
    ARRAY['ISO22716','GMPC','FDA注册','ISO9001'],'张经理','demo_gz@yicai.demo'
  ) RETURNING id INTO v_sid;
  v_supplier_ids := array_append(v_supplier_ids, v_sid);

  -- 供应商2：上海丝芙瑞（认证，有账号）
  INSERT INTO suppliers (company_id,user_id,company_name,short_name,category,region,description,established_year,employee_count,factory_area,is_verified,is_featured,rating,certifications,contact_name,contact_email)
  VALUES (
    (SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'), p_supplier2_user_id,
    '上海丝芙瑞生物科技有限公司','上海丝芙瑞','彩妆,唇部,香氛','上海',
    '中法合资高端彩妆制造商，拥有国际一流的研发团队和实验室。主打高端彩妆线，与多个国际品牌有合作经验。',
    2015,180,6500,true,false,4.5,
    ARRAY['ISO22716','GMP'],'Sophie 李','demo_sh@yicai.demo'
  ) RETURNING id INTO v_sid;
  v_supplier_ids := array_append(v_supplier_ids, v_sid);

  -- 供应商3：杭州妍妆（精选+认证，有账号）
  INSERT INTO suppliers (company_id,user_id,company_name,short_name,category,region,description,established_year,employee_count,factory_area,is_verified,is_featured,featured_order,rating,certifications,contact_name,contact_email)
  VALUES (
    (SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'), p_supplier3_user_id,
    '杭州妍妆科技有限公司','杭州妍妆','洗护,防晒,身体护理','浙江',
    '绿色洗护专家，专注天然植物配方。拥有自主知识产权的草本提取技术，产品通过欧盟ECOCERT有机认证。',
    2012,220,8000,true,true,2,4.6,
    ARRAY['ECOCERT有机认证','ISO22716','SGS检测'],'王总监','demo_hz@yicai.demo'
  ) RETURNING id INTO v_sid;
  v_supplier_ids := array_append(v_supplier_ids, v_sid);

  -- 供应商4：山东瑞安（认证，纯展示无账号）
  INSERT INTO suppliers (company_id,company_name,short_name,category,region,description,established_year,employee_count,factory_area,is_verified,is_featured,rating,certifications,contact_name,contact_email)
  VALUES (
    (SELECT id FROM companies WHERE name='山东瑞安日化集团'),
    '山东瑞安日化集团','山东瑞安','个护,洗护,身体护理','山东',
    '华北地区最大的日化生产基地之一，拥有完整的产业链布局。日产能超20万件，产品远销30+国家和地区。',
    2005,500,25000,true,false,4.3,
    ARRAY['ISO9001','ISO22716','BSCI'],'刘部长','sales@sdruihua.example.com'
  ) RETURNING id INTO v_sid;
  v_supplier_ids := array_append(v_supplier_ids, v_sid);

  -- 供应商5：福建清源（纯展示无账号）
  INSERT INTO suppliers (company_id,company_name,short_name,category,region,description,established_year,employee_count,factory_area,is_verified,is_featured,rating,certifications,contact_name,contact_email)
  VALUES (
    (SELECT id FROM companies WHERE name='福建清源生物科技有限公司'),
    '福建清源生物科技有限公司','福建清源','香氛,身体护理,精华','福建',
    '天然植物精油提取专家，拥有自有茶园和草药种植基地。专注芳香疗法和天然护肤领域。',
    2016,85,3000,true,false,4.7,
    ARRAY['USDA有机','HALAL','ISO22716'],'陈师傅','info@fqby.example.com'
  ) RETURNING id INTO v_sid;
  v_supplier_ids := array_append(v_supplier_ids, v_sid);

  -- 供应商6：成都锦绣（精选，纯展示无账号）
  INSERT INTO suppliers (company_id,company_name,short_name,category,region,description,established_year,employee_count,factory_area,is_verified,is_featured,featured_order,rating,certifications,contact_name,contact_email)
  VALUES (
    (SELECT id FROM companies WHERE name='成都锦绣美妆有限公司'),
    '成都锦绣美妆有限公司','成都锦绣','彩妆,护肤','四川',
    '西南地区彩妆领军企业，以蜀绣文化为灵感打造国潮彩妆IP。年开发新色号200+。',
    2018,120,4500,true,true,3,4.4,
    ARRAY['ISO22716','NMPA备案'],'赵经理','contact@jjinmei.example.com'
  ) RETURNING id INTO v_sid;
  v_supplier_ids := array_append(v_supplier_ids, v_sid);

  -- ============================================
  -- 3. 创建商品（26款）
  -- ============================================
  INSERT INTO products (supplier_id,company_id,name,category,description,moq,price_min,price_max,price_unit,lead_time,custom_capability,sample_available,sample_price,status) VALUES
  -- 广州美肤 6款
  (v_supplier_ids[1],(SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'),'氨基酸温和洁面乳 120ml','护肤','采用椰油酰甘氨酸钾为主要表活剂，pH5.5弱酸性配方，温和不紧绷。添加透明质酸钠和积雪草提取物。',1000,8.50,15.00,'支','15-20天',true,true,'25','active'),
  (v_supplier_ids[1],(SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'),'玻尿酸保湿面膜 5片/盒','面膜','三重玻尿酸搭配神经酰胺，深层补水修护。日本进口铜氨纤维膜布，每片精华液含量≥25ml。',500,12.00,28.00,'盒','12-18天',true,true,'15','active'),
  (v_supplier_ids[1],(SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'),'烟酰胺亮肤精华液 30ml','精华','5%烟酰胺+α-熊果苷+VC衍生物三重亮肤配方，有效改善暗沉均匀肤色。质地清爽不黏腻。',1000,18.00,45.00,'瓶','15-25天',true,true,'30','active'),
  (v_supplier_ids[1],(SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'),'清爽防晒乳 SPF50+ PA++++','防晒','物化结合防晒体系，广谱防护UVA/UVB。添加红没药醇舒缓成分，防水抗汗配方。',2000,10.00,22.00,'支','15-20天',true,true,'20','active'),
  (v_supplier_ids[1],(SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'),'视黄醇抗皱面霜 50g','护肤','0.3%包裹型视黄醇+胜肽复合物，渐进式抗皱不刺激。搭配角鲨烷和乳木果油深层滋养。',500,25.00,68.00,'瓶','20-30天',true,false,'','active'),
  (v_supplier_ids[1],(SELECT id FROM companies WHERE name='广州美肤化妆品有限公司'),'积雪草修护凝胶 100g','护肤','高纯度积雪草苷+泛醇+尿囊素三重修护配方。适用于医美后修护、换季敏感、痘印淡化。',1000,9.00,18.00,'罐','12-15天',true,true,'12','active'),
  -- 上海丝芙瑞 5款
  (v_supplier_ids[2],(SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'),'丝绒哑光唇釉 #A01复古红','唇部','法国进口原料，高显色一发上色。丝绒哑光质地不拔干不卡纹，持妆12小时+。',300,15.00,38.00,'支','10-15天',true,true,'20','active'),
  (v_supplier_ids[2],(SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'),'持妆无瑕粉底液 30ml','彩妆','微米级粉体技术，24小时持妆配方。20个色号可选，添加透明质酸和甘油。',500,22.00,55.00,'瓶','15-20天',true,true,'35','active'),
  (v_supplier_ids[2],(SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'),'星空梦幻眼影盘 12色','彩妆','哑光+珠光+闪片三种质地组合，粉质细腻飞粉少。磁吸翻盖包装高级感十足。',300,28.00,68.00,'盘','15-25天',true,true,'40','active'),
  (v_supplier_ids[2],(SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'),'花漾倾心香水 50ml EDP','香氛','前调佛手柑/黑加仑，中调大马士革玫瑰/茉莉，基调白麝香/檀香。法国格拉斯香精，留香6-8小时。',200,45.00,120.00,'瓶','20-30天',true,true,'60','active'),
  (v_supplier_ids[2],(SELECT id FROM companies WHERE name='上海丝芙瑞生物科技有限公司'),'眉笔三色合一 0.9g','彩妆','砍刀头+螺旋刷+眉粉三合一设计。防水防汗持久不晕染，旋转出芯无需削笔。',1000,5.00,12.00,'支','7-10天',true,true,'8','active'),
  -- 杭州妍妆 5款
  (v_supplier_ids[3],(SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'),'氨基酸洗发露 500ml 控油蓬松','洗护','椰油酰胺丙基甜菜碱+氨基酸双重表活，添加侧柏叶提取物和PCA锌控油去屑。无硅油配方。',2000,6.00,15.00,'瓶','10-15天',true,true,'10','active'),
  (v_supplier_ids[3],(SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'),'烟酰胺美白身体乳 400ml','身体护理','3%烟酰胺+VC乙基醚+光甘草定三重美白配方。质地如奶油般丝滑，淡雅铃兰香型。',1000,8.00,22.00,'瓶','10-15天',true,true,'12','active'),
  (v_supplier_ids[3],(SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'),'清透水感防晒喷雾 SPF50+','防晒','高压喷雾360度均匀喷洒，轻薄水感质地。添加芦荟和黄瓜提取物，150ml便携装。',3000,8.00,18.00,'罐','12-18天',true,true,'12','active'),
  (v_supplier_ids[3],(SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'),'茶树精油沐浴露 750ml','洗护','澳洲茶树精油+迷迭香+薄荷三重植物配方，丰富泡沫易冲洗。天然抗菌控油。',2000,5.00,12.00,'瓶','10-12天',true,false,'','active'),
  (v_supplier_ids[3],(SELECT id FROM companies WHERE name='杭州妍妆科技有限公司'),'护手霜套装 30ml×6支','身体护理','6种香型组合：玫瑰/薰衣草/樱花/蜂蜜/牛油果/绿茶。乳木果油+甘油+角鲨烷深层滋养。',500,12.00,28.00,'套','10-15天',true,true,'18','active'),
  -- 山东瑞安 3款
  (v_supplier_ids[4],(SELECT id FROM companies WHERE name='山东瑞安日化集团'),'抑菌洗手液 500ml','个护','对氯间二甲苯抑菌配方，抑菌率99.9%。温和PH平衡不伤手，清新柠檬香型。',5000,2.50,6.00,'瓶','7-10天',false,true,'5','active'),
  (v_supplier_ids[4],(SELECT id FROM companies WHERE name='山东瑞安日化集团'),'酵素洗衣液 2L 去渍增亮','洗护','复合酵素配方深层分解顽固污渍，低泡易漂洗省水环保。不含荧光增白剂。',5000,4.00,10.00,'瓶','7-10天',false,false,'','active'),
  (v_supplier_ids[4],(SELECT id FROM companies WHERE name='山东瑞安日化集团'),'竹炭牙膏 120g 三重美白','个护','竹炭微粒+水合硅石双重摩擦剂，温和去除牙渍。氟化钠防蛀，薄荷+绿茶双重口味。',10000,1.80,4.50,'支','7-10天',true,true,'3','active'),
  -- 福建清源 3款
  (v_supplier_ids[5],(SELECT id FROM companies WHERE name='福建清源生物科技有限公司'),'玫瑰精油 10ml 天然蒸馏','香氛','山东平阴重瓣红玫瑰，水蒸气蒸馏法提取。每10ml需约3000朵玫瑰，通过GC-MS纯度检测。',200,35.00,88.00,'瓶','7-12天',false,true,'45','active'),
  (v_supplier_ids[5],(SELECT id FROM companies WHERE name='福建清源生物科技有限公司'),'薰衣草香薰蜡烛 200g','香氛','天然大豆蜡+蜂蜡，法国薰衣草精油。手工浇注玻璃杯装，燃烧约40小时。木芯设计氛围感十足。',500,15.00,38.00,'罐','10-15天',true,true,'22','active'),
  (v_supplier_ids[5],(SELECT id FROM companies WHERE name='福建清源生物科技有限公司'),'茉莉纯露 200ml 补水喷雾','香氛','广西横县茉莉花蒸馏提取，无酒精无香精。可作爽肤水、定妆喷雾、香薰加湿多用途。',1000,8.00,20.00,'瓶','7-10天',false,true,'12','active'),
  -- 成都锦绣 3款
  (v_supplier_ids[6],(SELECT id FROM companies WHERE name='成都锦绣美妆有限公司'),'蜀韵国潮口红 #S01海棠红','唇部','灵感源自蜀绣海棠花纹，独特色号显白不挑皮。丝绸哑光质地，磁吸方管蜀绣纹理浮雕工艺。',500,18.00,48.00,'支','12-18天',true,true,'28','active'),
  (v_supplier_ids[6],(SELECT id FROM companies WHERE name='成都锦绣美妆有限公司'),'锦绣腮红盘 4色 032#桃花坞','彩妆','4色渐变腮红，哑光+珠光双质地。粉质细腻如丝绸，熊猫元素浮雕盘盖获红点奖。',500,15.00,42.00,'盘','12-20天',true,true,'25','active'),
  (v_supplier_ids[6],(SELECT id FROM companies WHERE name='成都锦绣美妆有限公司'),'鎏金高光修容盘','彩妆','高光+修容+古铜三合一，金色偏光高光细腻闪片不显毛孔。磁吸翻盖+镜子补妆方便。',300,20.00,55.00,'盘','15-20天',true,true,'35','active');

  -- ============================================
  -- 4. 创建品牌方档案
  -- ============================================
  INSERT INTO buyers (user_id,company_name,short_name,industry,brand_name,contact_name,contact_email,description,is_verified)
  VALUES (
    p_buyer_user_id,'星辰美妆（演示）','星辰美妆','美妆个护','星辰STARCHARM',
    '林经理','demo_buyer@yicai.demo',
    '星辰美妆是一家新锐国货美妆品牌，主打Z世代年轻消费群体。目前正在寻找优质的OEM/ODM供应商。',
    true
  ) RETURNING id INTO v_buyer_id;

  -- ============================================
  -- 5. 创建品牌方询价记录
  -- ============================================
  INSERT INTO buyer_inquiries (company_id,created_by,title,category,description,quantity,target_price,deadline,is_public,status,created_at) VALUES
  ((SELECT id FROM companies WHERE name='星辰美妆（演示）'),p_buyer_user_id,
   '寻找氨基酸洁面乳OEM供应商','护肤',
   '我司星辰美妆计划推出一款氨基酸洁面乳新品，目标零售价39.9元/120ml。需要OEM合作，MOQ 3000支以内，交期20天以内。',
   3000,12.00,CURRENT_DATE+INTERVAL '30 days',true,'open',CURRENT_DATE-INTERVAL '3 days'),
  ((SELECT id FROM companies WHERE name='星辰美妆（演示）'),p_buyer_user_id,
   '定制国潮系列眼影盘','彩妆',
   '品牌新品开发项目，计划推出蜀风雅韵系列眼影盘。4-6色组合，哑光+珠光搭配。目标零售价79元/盘。',
   2000,25.00,CURRENT_DATE+INTERVAL '45 days',true,'open',CURRENT_DATE-INTERVAL '7 days'),
  ((SELECT id FROM companies WHERE name='星辰美妆（演示）'),p_buyer_user_id,
   '采购天然植物精油一批','香氛',
   '为品牌香薰线采购天然精油原料。玫瑰精油、薰衣草精油、茶树精油各500瓶（10ml）。要求100%纯天然。',
   1500,40.00,CURRENT_DATE+INTERVAL '20 days',false,'awarded',CURRENT_DATE-INTERVAL '15 days'),
  ((SELECT id FROM companies WHERE name='星辰美妆（演示）'),p_buyer_user_id,
   '防晒霜新品开发询价','防晒',
   '开发SPF50+ PA++++清透防晒乳，水感不油腻适合油皮。容量50ml，目标零售价59.9元。',
   5000,10.00,CURRENT_DATE+INTERVAL '60 days',true,'open',CURRENT_DATE-INTERVAL '1 day');

  SELECT ARRAY(SELECT id FROM buyer_inquiries WHERE created_by = p_buyer_user_id ORDER BY created_at) INTO v_inquiry_ids;

  -- ============================================
  -- 6. 创建品牌方收藏
  -- ============================================
  INSERT INTO supplier_favorites (user_id,supplier_id,created_at)
  SELECT p_buyer_user_id, s.id, CURRENT_DATE - (random()*10)::INT
  FROM suppliers s WHERE s.id IN (v_supplier_ids[1],v_supplier_ids[2],v_supplier_ids[3]);

  INSERT INTO product_favorites (user_id,product_id,created_at)
  SELECT p_buyer_user_id, p.id, CURRENT_DATE - (random()*10)::INT
  FROM products p WHERE p.supplier_id IN (v_supplier_ids[1],v_supplier_ids[2]) ORDER BY random() LIMIT 6;

  -- ============================================
  -- 7. 创建品牌方-供应商关系
  -- ============================================
  INSERT INTO buyer_supplier_relations (buyer_user_id,supplier_id,buyer_company_id,status,tags,notes,source,created_at) VALUES
  (p_buyer_user_id,v_supplier_ids[1],(SELECT id FROM companies WHERE name='星辰美妆（演示）'),'cooperating',
   ARRAY['核心供应商','护肤品类'],'已合作洁面乳和面膜两个品类，品质稳定交期准时。','order',CURRENT_DATE-INTERVAL '60 days'),
  (p_buyer_user_id,v_supplier_ids[2],(SELECT id FROM companies WHERE name='星辰美妆（演示）'),'contacted',
   ARRAY['彩妆供应商','洽谈中'],'已对接彩妆项目负责人，正在讨论口红和眼影盘的定制方案。','discovery',CURRENT_DATE-INTERVAL '10 days'),
  (p_buyer_user_id,v_supplier_ids[3],(SELECT id FROM companies WHERE name='星辰美妆（演示）'),'potential',
   ARRAY['洗护备选'],'在发现页找到，初步了解产品线和报价，待进一步沟通。','discovery',CURRENT_DATE-INTERVAL '3 days');

  -- ============================================
  -- 完成
  -- ============================================
  RETURN format('✅ 演示数据部署完成！%s家公司、%s个供应商、%s款商品、%s条询价。',
    6, array_length(v_supplier_ids,1),
    (SELECT count(*) FROM products WHERE supplier_id = ANY(v_supplier_ids)),
    array_length(v_inquiry_ids,1));
END;
$$;

GRANT EXECUTE ON FUNCTION setup_demo_data(UUID,UUID,UUID,UUID) TO authenticated, anon;
