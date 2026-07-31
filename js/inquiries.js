/**
 * 询价管理模块
 */
const inquiries = {
  currentFilter: 'all',

  async load() {
    await this.render(this.currentFilter);
  },

  filter(status) {
    this.currentFilter = status;
    // 更新tab样式
    document.querySelectorAll('#page-inquiries .filter-tab').forEach(t => t.classList.remove('active'));
    event.target.classList.add('active');
    this.render(status);
  },

  async render(filter) {
    const container = document.getElementById('inquiries-list');
    container.innerHTML = '<div class="text-center" style="padding:20px;color:var(--text-secondary);">加载中...</div>';

    try {
      const params = {
        select: '*',
        order: 'created_at.desc'
      };

      // 按公司隔离或个人用户只看自己的
      if (appState.companyId) {
        params.filter = { company_id: appState.companyId };
      } else {
        params.filter = { created_by: appState.user?.id };
      }

      if (filter && filter !== 'all') {
        params.filter.status = filter;
      }

      const data = await supabase.query('buyer_inquiries', params);

      if (!data || data.length === 0) {
        container.innerHTML = '<div class="empty-state"><div class="empty-icon">📋</div><div class="empty-text">暂无询价记录</div></div>';
        return;
      }

      container.innerHTML = data.map(item => `
        <div class="inquiry-card ${getStatusClass(item.status)}">
          <div class="inquiry-header">
            <div class="inquiry-title">${item.title || '未命名询价'}</div>
            <span class="inquiry-badge">${getStatusLabel(item.status)}</span>
          </div>
          <div class="inquiry-desc">${item.description ? item.description.substring(0, 80) + (item.description.length > 80 ? '...' : '') : ''}</div>
          <div class="inquiry-meta">
            <span>📁 ${item.category || '-'}</span>
            <span>📊 数量: ${item.quantity || '-'}</span>
            ${item.target_price ? `<span>💰 目标价: ${formatMoney(item.target_price)}</span>` : ''}
            <span>📅 ${formatDateTime(item.created_at)}</span>
          </div>
          <div class="inquiry-actions">
            <button class="btn btn-outline btn-sm" onclick="inquiries.viewDetail('${item.id}')">查看详情</button>
            ${item.status === 'open' ? `<button class="btn btn-primary btn-sm" onclick="inquiries.viewQuotes('${item.id}')">查看报价</button>` : ''}
            ${item.status === 'open' ? `<button class="btn btn-sm" style="color:var(--danger);" onclick="inquiries.closeInquiry('${item.id}')">关闭</button>` : ''}
          </div>
        </div>
      `).join('');
    } catch (e) {
      container.innerHTML = `<div class="empty-state"><div class="empty-icon">⚠️</div><div class="empty-text">加载失败: ${e.message}</div></div>`;
    }
  },

  showCreateForm() {
    document.getElementById('inquiry-form-title').textContent = '发布询价';
    document.getElementById('inquiry-id').value = '';
    document.getElementById('inquiry-title').value = '';
    document.getElementById('inquiry-category').value = '';
    document.getElementById('inquiry-description').value = '';
    document.getElementById('inquiry-quantity').value = '';
    document.getElementById('inquiry-target-price').value = '';
    document.getElementById('inquiry-deadline').value = '';
    document.getElementById('inquiry-public').value = 'true';
    showModal('inquiry-modal');
  },

  async save() {
    const id = document.getElementById('inquiry-id').value;
    const data = {
      title: document.getElementById('inquiry-title').value,
      category: document.getElementById('inquiry-category').value,
      description: document.getElementById('inquiry-description').value,
      quantity: parseInt(document.getElementById('inquiry-quantity').value) || null,
      target_price: parseFloat(document.getElementById('inquiry-target-price').value) || null,
      deadline: document.getElementById('inquiry-deadline').value || null,
      is_public: document.getElementById('inquiry-public').value === 'true',
      status: 'open'
    };

    if (appState.companyId) {
      data.company_id = appState.companyId;
    }
    data.created_by = appState.user?.id;

    try {
      if (id) {
        await supabase.update('buyer_inquiries', data, { id: id });
        showToast('询价已更新 ✅');
      } else {
        await supabase.insert('buyer_inquiries', data);
        showToast('询价已发布 ✅');
      }
      hideModal('inquiry-modal');
      this.load();
    } catch (e) {
      showToast('保存失败: ' + e.message);
    }
  },

  async viewDetail(id) {
    try {
      const data = await supabase.query('buyer_inquiries', {
        select: '*',
        filter: { id: id }
      });

      if (!data || !data[0]) {
        showToast('未找到询价详情');
        return;
      }

      const item = data[0];
      const content = document.getElementById('inquiry-detail-content');
      content.innerHTML = `
        <div class="info-row"><span class="info-label">标题</span><span class="info-value">${item.title}</span></div>
        <div class="info-row"><span class="info-label">品类</span><span class="info-value">${item.category || '-'}</span></div>
        <div class="info-row"><span class="info-label">状态</span><span class="info-value"><span class="badge badge-${STATUS_MAP[item.status]?.color || 'info'}">${getStatusLabel(item.status)}</span></span></div>
        <div class="info-row"><span class="info-label">采购数量</span><span class="info-value">${item.quantity || '-'}</span></div>
        <div class="info-row"><span class="info-label">目标单价</span><span class="info-value">${item.target_price ? formatMoney(item.target_price) : '-'}</span></div>
        <div class="info-row"><span class="info-label">期望交货</span><span class="info-value">${item.deadline || '-'}</span></div>
        <div class="info-row"><span class="info-label">询价方式</span><span class="info-value">${item.is_public ? '公开询价' : '定向询价'}</span></div>
        <div class="info-row"><span class="info-label">发布时间</span><span class="info-value">${formatDateTime(item.created_at)}</span></div>
        <div style="margin-top:12px;padding:12px;background:var(--bg);border-radius:8px;">
          <div style="font-size:13px;color:var(--text-secondary);margin-bottom:4px;">详细描述</div>
          <div style="font-size:14px;line-height:1.6;">${item.description || '-'}</div>
        </div>
      `;
      showModal('inquiry-detail-modal');
    } catch (e) {
      showToast('加载详情失败: ' + e.message);
    }
  },

  async viewQuotes(inquiryId) {
    try {
      const quotesData = await supabase.query('supplier_quotes', {
        select: '*',
        filter: { inquiry_id: inquiryId },
        order: 'created_at.desc'
      });

      if (!quotesData || quotesData.length === 0) {
        showToast('暂无供应商报价');
        return;
      }

      // 显示对比视图
      const content = document.getElementById('compare-content');
      let html = '<div style="margin-bottom:16px;font-size:14px;color:var(--text-secondary);">共收到 ' + quotesData.length + ' 个报价</div>';

      html += '<table class="compare-table"><thead><tr><th>供应商</th><th>单价</th><th>起订量</th><th>交货期</th><th>操作</th></tr></thead><tbody>';

      // 找最低价
      const prices = quotesData.map(q => parseFloat(q.unit_price) || 0).filter(p => p > 0);
      const minPrice = prices.length > 0 ? Math.min(...prices) : 0;

      quotesData.forEach(q => {
        const isBest = parseFloat(q.unit_price) === minPrice && minPrice > 0;
        html += `<tr>
          <td>${q.supplier_name || '供应商'}</td>
          <td class="${isBest ? 'best-price' : ''}">${formatMoney(q.unit_price)}</td>
          <td>${q.moq || '-'}</td>
          <td>${q.lead_time || '-'}</td>
          <td><button class="btn btn-primary btn-sm" onclick="inquiries.acceptQuote('${q.id}','${inquiryId}')">选择</button></td>
        </tr>`;
      });

      html += '</tbody></table>';
      content.innerHTML = html;
      showModal('compare-modal');
    } catch (e) {
      showToast('加载报价失败: ' + e.message);
    }
  },

  async acceptQuote(quoteId, inquiryId) {
    if (!confirm('确认选择此报价？将自动创建订单。')) return;

    try {
      // 更新报价状态
      await supabase.update('supplier_quotes', { status: 'accepted' }, { id: quoteId });

      // 更新询价状态
      await supabase.update('buyer_inquiries', { status: 'awarded' }, { id: inquiryId });

      hideModal('compare-modal');
      showToast('已选择报价 ✅');
      this.load();
    } catch (e) {
      showToast('操作失败: ' + e.message);
    }
  },

  async closeInquiry(id) {
    if (!confirm('确定关闭此询价？')) return;
    try {
      await supabase.update('buyer_inquiries', { status: 'closed' }, { id: id });
      showToast('询价已关闭');
      this.load();
    } catch (e) {
      showToast('关闭失败: ' + e.message);
    }
  }
};
