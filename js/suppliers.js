/**
 * 供应商浏览模块
 */
const suppliers = {
  searchTimer: null,

  async load() {
    await this.render('');
  },

  search(keyword) {
    clearTimeout(this.searchTimer);
    this.searchTimer = setTimeout(() => {
      this.render(keyword);
    }, 300);
  },

  async render(keyword) {
    const container = document.getElementById('suppliers-list');
    container.innerHTML = '<div class="text-center" style="padding:20px;color:var(--text-secondary);">加载中...</div>';

    try {
      // 加载所有供应商
      const params = {
        select: '*',
        filter: { status: 'active' },
        order: 'company_name.asc'
      };

      if (keyword) {
        params.like = { company_name: `%${keyword}%` };
      }

      const data = await supabase.query('suppliers', params);

      if (!data || data.length === 0) {
        container.innerHTML = '<div class="empty-state"><div class="empty-icon">🏭</div><div class="empty-text">暂无供应商</div></div>';
        return;
      }

      // 分离精选和普通供应商
      const featured = data.filter(s => s.is_featured === true);
      const regular = data.filter(s => s.is_featured !== true);

      // 精选供应商排序：featured_order 升序，然后 featured_at 降序
      featured.sort((a, b) => {
        const orderDiff = (a.featured_order || 0) - (b.featured_order || 0);
        if (orderDiff !== 0) return orderDiff;
        return new Date(b.featured_at || 0) - new Date(a.featured_at || 0);
      });

      let html = '';

      // 渲染精选供应商区域
      if (featured.length > 0) {
        html += `
          <div style="margin-bottom:20px;">
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:12px;">
              <span style="font-size:16px;font-weight:600;color:var(--text-primary);">⭐ 平台精选</span>
              <span style="font-size:12px;color:var(--text-secondary);background:var(--bg-secondary);padding:2px 8px;border-radius:10px;">${featured.length}家</span>
            </div>
            ${featured.map(item => this.renderSupplierCard(item, true)).join('')}
          </div>
        `;
      }

      // 渲染普通供应商区域
      if (regular.length > 0) {
        if (featured.length > 0) {
          html += `
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:12px;margin-top:20px;">
              <span style="font-size:14px;font-weight:500;color:var(--text-secondary);">全部供应商</span>
              <span style="font-size:12px;color:var(--text-secondary);">(${regular.length})</span>
            </div>
          `;
        }
        html += regular.map(item => this.renderSupplierCard(item, false)).join('');
      }

      container.innerHTML = html;
    } catch (e) {
      container.innerHTML = `<div class="empty-state"><div class="empty-icon">⚠️</div><div class="empty-text">加载失败: ${e.message}</div></div>`;
    }
  },

  renderSupplierCard(item, isFeatured) {
    return `
      <div class="supplier-card" style="${isFeatured ? 'border:1px solid #f59e0b;background:linear-gradient(135deg,#fffbeb 0%,#ffffff 100%);' : ''}">
        <div class="supplier-avatar">${(item.company_name || '供')[0]}</div>
        <div class="supplier-info">
          <div class="supplier-name">
            ${item.company_name || '未命名'}
            ${isFeatured ? '<span style="background:#f59e0b;color:white;font-size:10px;padding:2px 6px;border-radius:8px;margin-left:6px;font-weight:500;">⭐ 精选</span>' : ''}
            ${item.verified ? '<span class="verified-badge">✓ 已认证</span>' : ''}
          </div>
          <div class="supplier-meta">
            ${item.region ? `<span>📍 ${item.region}</span>` : ''}
            ${item.category ? `<span>📁 ${Array.isArray(item.category) ? item.category.join('、') : item.category}</span>` : ''}
            ${item.established_year ? `<span>📅 ${item.established_year}年成立</span>` : ''}
          </div>
          ${item.main_products ? `
            <div class="supplier-tags">
              ${item.main_products.split(',').slice(0, 3).map(p => `<span class="supplier-tag">${p.trim()}</span>`).join('')}
            </div>
          ` : ''}
          ${item.description ? `<div style="font-size:12px;color:var(--text-secondary);margin-top:8px;">${item.description.substring(0, 60)}${item.description.length > 60 ? '...' : ''}</div>` : ''}
        </div>
      </div>
    `;
  }
};
