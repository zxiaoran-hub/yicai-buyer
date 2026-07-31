/**
 * 订单管理模块
 */
const orders = {
  currentFilter: 'all',

  async load() {
    await this.render(this.currentFilter);
  },

  filter(status) {
    this.currentFilter = status;
    document.querySelectorAll('#page-orders .filter-tab').forEach(t => t.classList.remove('active'));
    event.target.classList.add('active');
    this.render(status);
  },

  async render(filter) {
    const container = document.getElementById('orders-list');
    container.innerHTML = '<div class="text-center" style="padding:20px;color:var(--text-secondary);">加载中...</div>';

    try {
      const params = {
        select: '*',
        order: 'created_at.desc'
      };

      // 公司隔离或个人用户
      if (appState.companyId) {
        params.filter = { company_id: appState.companyId };
      } else {
        params.filter = { buyer_user_id: appState.user?.id };
      }

      if (filter && filter !== 'all') {
        params.filter.status = filter;
      }

      const data = await supabase.query('buyer_orders', params);

      if (!data || data.length === 0) {
        container.innerHTML = '<div class="empty-state"><div class="empty-icon">📦</div><div class="empty-text">暂无订单</div></div>';
        return;
      }

      container.innerHTML = data.map(item => `
        <div class="order-card ${getStatusClass(item.status)}">
          <div class="order-header">
            <div class="order-no">#${item.id || ''}</div>
            <span class="order-status">${getStatusLabel(item.status)}</span>
          </div>
          <div class="order-product">${item.product_name || '未命名'}</div>
          <div class="order-supplier">供应商: ${item.supplier_name || '-'}</div>
          <div class="order-info">
            <span>📦 ${item.quantity || 0}件</span>
            <span>💰 ${formatMoney((item.unit_price || 0) * (item.quantity || 0))}</span>
            <span>📅 ${item.delivery_date || '-'}</span>
          </div>
          <div style="margin-top:12px;display:flex;gap:8px;">
            <button class="btn btn-outline btn-sm" onclick="orders.viewDetail('${item.id}')">详情</button>
            ${item.status === 'pending' ? `<button class="btn btn-sm" style="color:var(--danger);" onclick="orders.cancelOrder('${item.id}')">取消</button>` : ''}
            ${item.status === 'pending' ? `<button class="btn btn-success btn-sm" onclick="orders.confirmOrder('${item.id}')">确认</button>` : ''}
          </div>
        </div>
      `).join('');
    } catch (e) {
      container.innerHTML = `<div class="empty-state"><div class="empty-icon">⚠️</div><div class="empty-text">加载失败: ${e.message}</div></div>`;
    }
  },

  async showCreateForm() {
    // 加载可关联的询价和供应商
    try {
      const inquiriesData = await supabase.query('buyer_inquiries', {
        select: 'id,title',
        filter: appState.companyId ? { company_id: appState.companyId, status: 'awarded' } : { created_by: appState.user?.id, status: 'awarded' }
      });

      const selectEl = document.getElementById('order-inquiry-id');
      selectEl.innerHTML = '<option value="">不关联（手动填写）</option>';
      if (inquiriesData) {
        inquiriesData.forEach(i => {
          selectEl.innerHTML += `<option value="${i.id}">${i.title}</option>`;
        });
      }

      // 加载供应商列表
      const suppliersData = await supabase.query('suppliers', {
        select: 'id,company_name',
        filter: { status: 'active' }
      });

      const supplierSelect = document.getElementById('order-supplier-id');
      supplierSelect.innerHTML = '<option value="">选择供应商</option>';
      if (suppliersData) {
        suppliersData.forEach(s => {
          supplierSelect.innerHTML += `<option value="${s.id}">${s.company_name}</option>`;
        });
      }
    } catch (e) {
      console.warn('Error loading form data:', e);
    }

    // 重置表单
    document.getElementById('order-product-name').value = '';
    document.getElementById('order-quantity').value = '';
    document.getElementById('order-unit-price').value = '';
    document.getElementById('order-delivery-date').value = '';
    document.getElementById('order-notes').value = '';

    showModal('order-create-modal');
  },

  async save() {
    const data = {
      product_name: document.getElementById('order-product-name').value,
      supplier_id: document.getElementById('order-supplier-id').value || null,
      quantity: parseInt(document.getElementById('order-quantity').value) || 0,
      unit_price: parseFloat(document.getElementById('order-unit-price').value) || 0,
      delivery_date: document.getElementById('order-delivery-date').value || null,
      notes: document.getElementById('order-notes').value || null,
      status: 'pending',
      buyer_user_id: appState.user?.id
    };

    const inquiryId = document.getElementById('order-inquiry-id').value;
    if (inquiryId) {
      data.inquiry_id = inquiryId;
    }

    if (appState.companyId) {
      data.company_id = appState.companyId;
    }

    try {
      // 获取供应商名称
      if (data.supplier_id) {
        const supplierData = await supabase.query('suppliers', {
          select: 'company_name',
          filter: { id: data.supplier_id }
        });
        if (supplierData && supplierData[0]) {
          data.supplier_name = supplierData[0].company_name;
        }
      }

      await supabase.insert('buyer_orders', data);
      showToast('订单已创建 ✅');
      hideModal('order-create-modal');
      this.load();
    } catch (e) {
      showToast('创建失败: ' + e.message);
    }
  },

  async viewDetail(id) {
    try {
      const data = await supabase.query('buyer_orders', {
        select: '*',
        filter: { id: id }
      });

      if (!data || !data[0]) {
        showToast('未找到订单');
        return;
      }

      const item = data[0];
      const content = document.getElementById('order-detail-content');
      content.innerHTML = `
        <div class="info-row"><span class="info-label">订单号</span><span class="info-value">#${item.id}</span></div>
        <div class="info-row"><span class="info-label">产品</span><span class="info-value">${item.product_name || '-'}</span></div>
        <div class="info-row"><span class="info-label">供应商</span><span class="info-value">${item.supplier_name || '-'}</span></div>
        <div class="info-row"><span class="info-label">数量</span><span class="info-value">${item.quantity || 0}</span></div>
        <div class="info-row"><span class="info-label">单价</span><span class="info-value">${formatMoney(item.unit_price)}</span></div>
        <div class="info-row"><span class="info-label">总金额</span><span class="info-value" style="font-weight:700;color:var(--primary);">${formatMoney((item.unit_price || 0) * (item.quantity || 0))}</span></div>
        <div class="info-row"><span class="info-label">状态</span><span class="info-value"><span class="badge badge-${STATUS_MAP[item.status]?.color || 'info'}">${getStatusLabel(item.status)}</span></span></div>
        <div class="info-row"><span class="info-label">交货日期</span><span class="info-value">${item.delivery_date || '-'}</span></div>
        <div class="info-row"><span class="info-label">创建时间</span><span class="info-value">${formatDateTime(item.created_at)}</span></div>
        ${item.notes ? `<div style="margin-top:12px;padding:12px;background:var(--bg);border-radius:8px;"><div style="font-size:13px;color:var(--text-secondary);margin-bottom:4px;">备注</div><div style="font-size:14px;">${item.notes}</div></div>` : ''}
        <div style="margin-top:16px;display:flex;gap:8px;">
          ${item.status === 'pending' ? `<button class="btn btn-success btn-sm" onclick="orders.confirmOrder('${item.id}');hideModal('order-detail-modal');">确认订单</button>` : ''}
          ${item.status === 'pending' ? `<button class="btn btn-sm" style="color:var(--danger);border:1px solid var(--danger);" onclick="orders.cancelOrder('${item.id}');hideModal('order-detail-modal');">取消订单</button>` : ''}
        </div>
      `;
      showModal('order-detail-modal');
    } catch (e) {
      showToast('加载失败: ' + e.message);
    }
  },

  async confirmOrder(id) {
    if (!confirm('确认此订单？')) return;
    try {
      await supabase.update('buyer_orders', { status: 'confirmed' }, { id: id });
      showToast('订单已确认 ✅');
      this.load();
    } catch (e) {
      showToast('确认失败: ' + e.message);
    }
  },

  async cancelOrder(id) {
    if (!confirm('确定取消此订单？')) return;
    try {
      await supabase.update('buyer_orders', { status: 'cancelled' }, { id: id });
      showToast('订单已取消');
      this.load();
    } catch (e) {
      showToast('取消失败: ' + e.message);
    }
  }
};
