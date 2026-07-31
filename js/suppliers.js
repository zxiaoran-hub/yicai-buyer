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

      container.innerHTML = data.map(item => `
        <div class="supplier-card">
          <div class="supplier-avatar">${(item.company_name || '供')[0]}</div>
          <div class="supplier-info">
            <div class="supplier-name">
              ${item.company_name || '未命名'}
              ${item.verified ? '<span class="verified-badge">✓ 已认证</span>' : ''}
            </div>
            <div class="supplier-meta">
              ${item.region ? `<span>📍 ${item.region}</span>` : ''}
              ${item.category ? `<span>📁 ${item.category}</span>` : ''}
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
      `).join('');
    } catch (e) {
      container.innerHTML = `<div class="empty-state"><div class="empty-icon">⚠️</div><div class="empty-text">加载失败: ${e.message}</div></div>`;
    }
  }
};
