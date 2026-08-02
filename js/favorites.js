/**
 * 异采 YiCai - 我的收藏模块
 * 功能：收藏商品列表、收藏供应商列表、取消收藏、跳转详情
 */
const favorites = {
  currentTab: 'products',

  // ==================== 初始化 ====================
  init() {
    this.switchTab('products');
  },

  switchTab(tab) {
    this.currentTab = tab;
    document.querySelectorAll('#page-favorites .fav-tab').forEach(t => {
      t.classList.toggle('active', t.dataset.tab === tab);
    });
    if (tab === 'products') {
      document.getElementById('fav-products-section').style.display = '';
      document.getElementById('fav-suppliers-section').style.display = 'none';
      this.loadFavoriteProducts();
    } else {
      document.getElementById('fav-products-section').style.display = 'none';
      document.getElementById('fav-suppliers-section').style.display = '';
      this.loadFavoriteSuppliers();
    }
  },

  // ==================== 收藏商品 ====================
  async loadFavoriteProducts() {
    const container = document.getElementById('fav-products-list');
    container.innerHTML = '<div class="loading-spinner">加载中...</div>';

    try {
      if (!currentUser) { container.innerHTML = '<div class="empty-state">请先登录</div>'; return; }

      // 获取收藏的 product_id 列表
      const favs = await supabase.query('product_favorites', {
        select: 'product_id,created_at',
        filter: { user_id: currentUser.id },
        order: 'created_at.desc'
      });

      if (!favs.length) {
        container.innerHTML = '<div class="empty-state"><div style="font-size:48px;margin-bottom:12px;">🤍</div><div>还没有收藏商品</div><div style="font-size:13px;color:#999;margin-top:4px;">在发现页浏览商品时点击❤️即可收藏</div></div>';
        return;
      }

      // 批量获取商品详情
      const productIds = favs.map(f => f.product_id);
      const products = await supabase.query('products', {
        select: 'id,name,category,images,price_min,price_max,price_unit,moq,sample_available,status,supplier_id',
        filter: { id: productIds[0] },
      });

      // 用 IN 查询
      const allProducts = await supabase.query('products', {
        select: 'id,name,category,images,price_min,price_max,price_unit,moq,sample_available,status,supplier_id',
      }).then(prods => prods.filter(p => productIds.includes(p.id)));

      // 获取供应商名称
      const supplierIds = [...new Set(allProducts.map(p => p.supplier_id).filter(Boolean))];
      let supplierMap = {};
      if (supplierIds.length) {
        const supps = await supabase.query('suppliers', {
          select: 'id,company_name,region'
        }).then(s => s.filter(sp => supplierIds.includes(sp.id)));
        supplierMap = Object.fromEntries(supps.map(s => [s.id, s]));
      }

      // 按收藏顺序排列
      const orderedProducts = favs.map(f => allProducts.find(p => p.id === f.product_id)).filter(Boolean);

      container.innerHTML = orderedProducts.map(p => {
        const img = p.images?.[0] || '';
        const supplier = supplierMap[p.supplier_id] || {};
        const priceRange = p.price_min || p.price_max
          ? `¥${p.price_min || '?'} - ¥${p.price_max || '?'}/${p.price_unit || '件'}`
          : '价格面议';
        return `
          <div class="fav-product-card" onclick="favorites.viewProductDetail('${p.id}')">
            <div class="fav-product-img">${img ? `<img src="${escapeHtml(img)}" onerror="this.parentElement.textContent='📷'">` : '📷'}</div>
            <div class="fav-product-info">
              <div class="fav-product-name">${escapeHtml(p.name)}</div>
              <div class="fav-product-meta">
                <span class="fav-product-supplier">${escapeHtml(supplier.company_name || '未知供应商')}</span>
                ${supplier.region ? `<span class="fav-product-region">${escapeHtml(supplier.region)}</span>` : ''}
              </div>
              <div class="fav-product-bottom">
                <span class="fav-product-price">${priceRange}</span>
                <span class="fav-product-moq">起订 ${p.moq || 1}${p.price_unit || '件'}</span>
              </div>
            </div>
            <div class="fav-remove-btn" onclick="event.stopPropagation();favorites.removeProductFavorite('${p.id}')" title="取消收藏">❌</div>
          </div>
        `;
      }).join('');
    } catch (e) {
      console.error('Load favorite products error:', e);
      container.innerHTML = '<div class="empty-state">加载失败，请刷新重试</div>';
    }
  },

  async removeProductFavorite(productId) {
    if (!currentUser) return;
    try {
      await supabase.delete('product_favorites', { user_id: currentUser.id, product_id: productId });
      showToast('已取消收藏');
      this.loadFavoriteProducts();
      // 如果 productDiscovery 模块存在，同步更新其收藏状态
      if (typeof productDiscovery !== 'undefined') {
        productDiscovery.favorites.delete(productId);
      }
    } catch (e) {
      showToast('操作失败');
    }
  },

  viewProductDetail(productId) {
    if (typeof productDiscovery !== 'undefined') {
      switchPage('suppliers');
      setTimeout(() => productDiscovery.showProductDetail(productId), 100);
    }
  },

  // ==================== 收藏供应商 ====================
  async loadFavoriteSuppliers() {
    const container = document.getElementById('fav-suppliers-list');
    container.innerHTML = '<div class="loading-spinner">加载中...</div>';

    try {
      if (!currentUser) { container.innerHTML = '<div class="empty-state">请先登录</div>'; return; }

      const favs = await supabase.query('supplier_favorites', {
        select: 'supplier_id,created_at',
        filter: { user_id: currentUser.id },
        order: 'created_at.desc'
      });

      if (!favs.length) {
        container.innerHTML = '<div class="empty-state"><div style="font-size:48px;margin-bottom:12px;">🤍</div><div>还没有收藏供应商</div><div style="font-size:13px;color:#999;margin-top:4px;">在发现页浏览供应商时点击❤️即可收藏</div></div>';
        return;
      }

      const supplierIds = favs.map(f => f.supplier_id);
      const allSuppliers = await supabase.query('suppliers', {
        select: 'id,company_name,region,category,is_verified,rating,contact_name,contact_email'
      }).then(s => s.filter(sp => supplierIds.includes(sp.id)));

      // 按收藏顺序排列
      const ordered = favs.map(f => allSuppliers.find(s => s.id === f.supplier_id)).filter(Boolean);

      container.innerHTML = ordered.map(s => {
        const cats = Array.isArray(s.category) ? s.category.join('、') : (s.category || '');
        return `
          <div class="fav-supplier-card" onclick="favorites.viewSupplierDetail('${s.id}')">
            <div class="fav-supplier-header">
              <div class="fav-supplier-name">${escapeHtml(s.company_name)}</div>
              ${s.is_verified ? '<span class="fav-verified-badge">✓ 已认证</span>' : ''}
            </div>
            <div class="fav-supplier-meta">
              ${s.region ? `<span>📍 ${escapeHtml(s.region)}</span>` : ''}
              ${cats ? `<span>🏭 ${escapeHtml(cats)}</span>` : ''}
              ${s.rating ? `<span>⭐ ${s.rating}</span>` : ''}
            </div>
            <div class="fav-supplier-contact">
              ${s.contact_name ? `<span>联系人: ${escapeHtml(s.contact_name)}</span>` : ''}
            </div>
            <div class="fav-remove-btn" onclick="event.stopPropagation();favorites.removeSupplierFavorite('${s.id}')" title="取消收藏">❌</div>
          </div>
        `;
      }).join('');
    } catch (e) {
      console.error('Load favorite suppliers error:', e);
      container.innerHTML = '<div class="empty-state">加载失败，请刷新重试</div>';
    }
  },

  async removeSupplierFavorite(supplierId) {
    if (!currentUser) return;
    try {
      await supabase.delete('supplier_favorites', { user_id: currentUser.id, supplier_id: supplierId });
      showToast('已取消收藏');
      this.loadFavoriteSuppliers();
      if (typeof suppliers !== 'undefined' && suppliers.supplierFavorites) {
        suppliers.supplierFavorites.delete(supplierId);
      }
    } catch (e) {
      showToast('操作失败');
    }
  },

  viewSupplierDetail(supplierId) {
    if (typeof suppliers !== 'undefined') {
      suppliers.viewDetail(supplierId);
    }
  }
};
