/**
 * 报价管理模块
 */
const quotes = {
  currentFilter: 'all',

  async load() {
    await this.render(this.currentFilter);
  },

  filter(status) {
    this.currentFilter = status;
    document.querySelectorAll('#page-quotes .filter-tab').forEach(t => t.classList.remove('active'));
    event.target.classList.add('active');
    this.render(status);
  },

  async render(filter) {
    const container = document.getElementById('quotes-list');
    container.innerHTML = '<div class="text-center" style="padding:20px;color:var(--text-secondary);">加载中...</div>';

    try {
      const params = {
        select: '*',
        order: 'created_at.desc'
      };

      // 公司用户看公司收到的报价，个人用户看自己的
      if (appState.companyId) {
        params.filter = { inquiry_company_id: appState.companyId };
      } else {
        params.filter = { inquiry_created_by: appState.user?.id };
      }

      if (filter && filter !== 'all') {
        params.filter.status = filter;
      }

      const data = await supabase.query('supplier_quotes', params);

      if (!data || data.length === 0) {
        container.innerHTML = '<div class="empty-state"><div class="empty-icon">💰</div><div class="empty-text">暂无报价记录</div></div>';
        return;
      }

      container.innerHTML = data.map(item => `
        <div class="quote-card">
          <div class="quote-header">
            <div>
              <div class="quote-supplier">${item.supplier_name || '供应商'}</div>
              <div style="font-size:12px;color:var(--text-secondary);">${item.inquiry_title || ''}</div>
            </div>
            <div class="quote-price">${formatMoney(item.unit_price)}</div>
          </div>
          <div class="quote-details">
            <span>📦 起订量: ${item.moq || '-'}</span>
            <span>📅 交期: ${item.lead_time || '-'}</span>
            <span>📊 状态: ${this.getQuoteStatusLabel(item.status)}</span>
          </div>
          ${item.message ? `<div style="font-size:13px;color:var(--text-secondary);margin-bottom:12px;padding:8px;background:var(--bg);border-radius:6px;">💬 ${item.message}</div>` : ''}
          <div class="quote-actions">
            ${item.status === 'pending' ? `
              <button class="btn btn-success btn-sm" onclick="quotes.acceptQuote('${item.id}')">接受</button>
              <button class="btn btn-sm" style="color:var(--danger);border:1px solid var(--danger);" onclick="quotes.rejectQuote('${item.id}')">拒绝</button>
            ` : ''}
            <span style="font-size:12px;color:var(--text-secondary);align-self:center;">${formatDateTime(item.created_at)}</span>
          </div>
        </div>
      `).join('');
    } catch (e) {
      container.innerHTML = `<div class="empty-state"><div class="empty-icon">⚠️</div><div class="empty-text">加载失败: ${e.message}</div></div>`;
    }
  },

  getQuoteStatusLabel(status) {
    const map = {
      pending: '待评审',
      accepted: '已接受',
      rejected: '已拒绝'
    };
    return map[status] || status;
  },

  async acceptQuote(id) {
    if (!confirm('确认接受此报价？')) return;
    try {
      await supabase.update('supplier_quotes', { status: 'accepted' }, { id: id });
      showToast('已接受报价 ✅');
      this.load();
    } catch (e) {
      showToast('操作失败: ' + e.message);
    }
  },

  async rejectQuote(id) {
    if (!confirm('确认拒绝此报价？')) return;
    try {
      await supabase.update('supplier_quotes', { status: 'rejected' }, { id: id });
      showToast('已拒绝报价');
      this.load();
    } catch (e) {
      showToast('操作失败: ' + e.message);
    }
  }
};
