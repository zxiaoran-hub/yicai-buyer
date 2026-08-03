-- 诊断：检查演示数据状态
-- 在 Supabase SQL Editor 执行，把全部结果发给我

-- 1. 公司数量
SELECT 'companies' AS table_name, COUNT(*) AS count FROM companies;

-- 2. 供应商数量
SELECT 'suppliers' AS table_name, COUNT(*) AS count FROM suppliers;

-- 3. 商品数量
SELECT 'products' AS table_name, COUNT(*) AS count FROM products;

-- 4. 品牌方数量
SELECT 'buyers' AS table_name, COUNT(*) AS count FROM buyers;

-- 5. 演示数据检查
SELECT 'demo_companies' AS check_name, COUNT(*) AS count FROM companies WHERE name LIKE '%演示%' OR name LIKE '%美肤%' OR name LIKE '%丝芙瑞%' OR name LIKE '%妍妆%';

SELECT 'demo_suppliers' AS check_name, COUNT(*) AS count FROM suppliers WHERE company_name LIKE '%美肤%' OR company_name LIKE '%丝芙瑞%' OR company_name LIKE '%妍妆%';

-- 6. companies 表有哪些列
SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name='companies' ORDER BY ordinal_position;

-- 7. suppliers 表有哪些列
SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name='suppliers' ORDER BY ordinal_position;
