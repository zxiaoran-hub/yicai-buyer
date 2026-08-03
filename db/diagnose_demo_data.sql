-- 异采演示账号完整诊断 SQL
-- 执行方式：Supabase SQL Editor 执行，然后把结果复制发给我

-- ========== 1. 检查演示账号是否存在 ==========
SELECT 
  id,
  email,
  CASE 
    WHEN email = 'demo_buyer@yicai.demo' THEN '品牌方-星辰美妆'
    WHEN email = 'demo_gz@yicai.demo' THEN '供应商-广州美肤'
    WHEN email = 'demo_sh@yicai.demo' THEN '供应商-上海丝芙瑞'
    WHEN email = 'demo_hz@yicai.demo' THEN '供应商-杭州妍妆'
    ELSE '其他'
  END as expected_role
FROM auth.users
WHERE email LIKE '%@yicai.demo'
ORDER BY email;

-- ========== 2. 检查 user_roles 关联 ==========
SELECT 
  ur.user_id,
  u.email,
  ur.role_id,
  r.name as role_name,
  ur.company_id,
  c.name as company_name
FROM user_roles ur
LEFT JOIN auth.users u ON ur.user_id = u.id
LEFT JOIN roles r ON ur.role_id = r.id
LEFT JOIN companies c ON ur.company_id = c.id
WHERE u.email LIKE '%@yicai.demo'
ORDER BY u.email;

-- ========== 3. 检查 get_user_company_id() 函数是否工作 ==========
-- 注意：这个函数使用 auth.uid()，需要在登录状态下测试
-- 这里我们直接查询函数定义，确认函数存在
SELECT 
  routine_name,
  routine_type,
  data_type
FROM information_schema.routines
WHERE routine_name = 'get_user_company_id';

-- ========== 4. 检查 suppliers 表数据 ==========
SELECT 
  id,
  user_id,
  company_name,
  (SELECT email FROM auth.users WHERE id = suppliers.user_id) as user_email
FROM suppliers
ORDER BY company_name;

-- ========== 5. 检查 buyer_orders 数据 ==========
SELECT 
  id,
  company_id,
  (SELECT name FROM companies WHERE id = buyer_orders.company_id) as buyer_company,
  buyer_user_id,
  (SELECT email FROM auth.users WHERE id = buyer_orders.buyer_user_id) as buyer_email,
  supplier_id,
  (SELECT company_name FROM suppliers WHERE id = buyer_orders.supplier_id) as supplier_name,
  product_name,
  status
FROM buyer_orders
ORDER BY id;

-- ========== 6. 检查 buyer_inquiries 数据 ==========
SELECT 
  id,
  company_id,
  (SELECT name FROM companies WHERE id = buyer_inquiries.company_id) as buyer_company,
  created_by,
  (SELECT email FROM auth.users WHERE id = buyer_inquiries.created_by) as creator_email,
  title,
  status,
  is_public
FROM buyer_inquiries
ORDER BY id;

-- ========== 7. 检查 supplier_quotes 数据 ==========
SELECT 
  id,
  inquiry_id,
  (SELECT title FROM buyer_inquiries WHERE id = supplier_quotes.inquiry_id) as inquiry_title,
  inquiry_company_id,
  (SELECT name FROM companies WHERE id = supplier_quotes.inquiry_company_id) as inquiry_company,
  supplier_id,
  (SELECT company_name FROM suppliers WHERE id = supplier_quotes.supplier_id) as supplier_name,
  unit_price,
  status
FROM supplier_quotes
ORDER BY id;

-- ========== 8. 检查 RLS 策略是否启用 ==========
SELECT 
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename IN ('buyer_orders', 'buyer_inquiries', 'supplier_quotes', 'products', 'suppliers', 'user_roles');

-- ========== 9. 检查 RLS 策略详情 ==========
SELECT 
  tablename,
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE tablename IN ('buyer_orders', 'buyer_inquiries', 'supplier_quotes')
AND cmd = 'SELECT'
ORDER BY tablename, policyname;
