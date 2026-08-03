-- 修复 RLS 策略：允许供应商查看自己的订单/报价，以及查看所有公开询价
-- 执行方式：Supabase SQL Editor 执行

-- 1. buyer_orders: 供应商可看自己相关的订单
DROP POLICY IF EXISTS "buyer_orders_select" ON buyer_orders;
CREATE POLICY "buyer_orders_select" ON buyer_orders
  FOR SELECT USING (
    company_id = (SELECT get_user_company_id())
    OR buyer_user_id = auth.uid()
    OR supplier_id IN (SELECT id FROM suppliers WHERE user_id = auth.uid())
  );

-- 2. supplier_quotes: 供应商可看自己的报价
DROP POLICY IF EXISTS "supplier_quotes_select" ON supplier_quotes;
CREATE POLICY "supplier_quotes_select" ON supplier_quotes
  FOR SELECT USING (
    inquiry_company_id = (SELECT get_user_company_id())
    OR inquiry_created_by = auth.uid()
    OR supplier_id IN (SELECT id FROM suppliers WHERE user_id = auth.uid())
  );

-- 3. buyer_inquiries: 所有认证用户可查看公开询价（需求大厅）
DROP POLICY IF EXISTS "buyer_inquiries_select" ON buyer_inquiries;
CREATE POLICY "buyer_inquiries_select" ON buyer_inquiries
  FOR SELECT USING (
    company_id = (SELECT get_user_company_id())
    OR created_by = auth.uid()
    OR is_public = true
  );

-- 4. buyer_orders UPDATE: 供应商可更新自己相关的订单状态
DROP POLICY IF EXISTS "buyer_orders_update" ON buyer_orders;
CREATE POLICY "buyer_orders_update" ON buyer_orders
  FOR UPDATE USING (
    company_id = (SELECT get_user_company_id())
    OR buyer_user_id = auth.uid()
    OR supplier_id IN (SELECT id FROM suppliers WHERE user_id = auth.uid())
  );

-- 5. supplier_quotes INSERT: 供应商可提交报价
DROP POLICY IF EXISTS "supplier_quotes_insert" ON supplier_quotes;
CREATE POLICY "supplier_quotes_insert" ON supplier_quotes
  FOR INSERT WITH CHECK (
    supplier_id IN (SELECT id FROM suppliers WHERE user_id = auth.uid())
  );

-- 6. supplier_quotes UPDATE: 供应商可更新自己的报价
DROP POLICY IF EXISTS "supplier_quotes_update" ON supplier_quotes;
CREATE POLICY "supplier_quotes_update" ON supplier_quotes
  FOR UPDATE USING (
    supplier_id IN (SELECT id FROM suppliers WHERE user_id = auth.uid())
    OR inquiry_company_id = (SELECT get_user_company_id())
    OR inquiry_created_by = auth.uid()
  );

-- 7. products: 确认公开可读（已存在，这里确保一下）
-- USING (true) 已设置，无需修改

-- 验证：检查策略是否生效
SELECT tablename, policyname, cmd, qual
FROM pg_policies
WHERE tablename IN ('buyer_orders', 'supplier_quotes', 'buyer_inquiries')
AND cmd = 'SELECT'
ORDER BY tablename;
