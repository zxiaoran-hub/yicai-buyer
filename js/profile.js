/**
 * 个人中心模块
 */
const profile = {
  async load() {
    // 用户基本信息
    const userName = appState.user?.email?.split('@')[0] || '用户';
    document.getElementById('profile-avatar-text').textContent = userName[0].toUpperCase();
    document.getElementById('profile-user-name').textContent = userName;

    // 角色显示
    const roleNames = appState.roles.map(r => r.name).join('、') || (appState.isIndividual ? '个人用户' : '用户');
    document.getElementById('profile-user-role').textContent = roleNames;

    // 公司信息
    if (appState.companyId) {
      try {
        const companies = await supabase.query('companies', {
          select: 'name',
          filter: { id: appState.companyId }
        });
        if (companies && companies[0]) {
          document.getElementById('profile-company-info').textContent = companies[0].name;
        }
      } catch (e) {
        document.getElementById('profile-company-info').textContent = `公司ID: ${appState.companyId}`;
      }
    } else {
      document.getElementById('profile-company-info').textContent = '个人用户';
    }

    // 账号信息
    document.getElementById('info-name').textContent = userName;
    document.getElementById('info-email').textContent = appState.user?.email || '-';
    document.getElementById('info-company').textContent = appState.companyId ? (document.getElementById('profile-company-info').textContent) : '无（个人用户）';
    document.getElementById('info-role').textContent = roleNames;
    document.getElementById('info-user-type').textContent = appState.isIndividual ? '个人用户' : '公司用户';

    // 权限列表
    this.renderPermissions();
  },

  renderPermissions() {
    const container = document.getElementById('permissions-list');
    if (!container) return;

    if (appState.isPlatformAdmin) {
      container.innerHTML = '<div class="perm-tag system">平台管理员 - 拥有全部权限</div>';
      return;
    }

    if (appState.isCompanyAdmin) {
      container.innerHTML = '<div class="perm-tag system">公司管理员 - 拥有公司全部权限</div>';
      // 仍然显示具体权限列表
    }

    const perms = appState.permissions || [];
    if (perms.length === 0) {
      container.innerHTML += '<div style="font-size:13px;color:var(--text-secondary);margin-top:8px;">暂无功能权限（仅可查看公开数据）</div>';
      return;
    }

    // 按resource分组显示
    const grouped = {};
    perms.forEach(p => {
      if (p.effect !== 'allow') return;
      const resource = p.resource || 'other';
      if (!grouped[resource]) grouped[resource] = [];
      grouped[resource].push(p);
    });

    let html = '';
    for (const [resource, permList] of Object.entries(grouped)) {
      html += `<div style="margin-bottom:12px;">`;
      html += `<div style="font-size:13px;font-weight:600;margin-bottom:6px;color:var(--dark);">${this.getResourceLabel(resource)}</div>`;
      html += permList.map(p => `
        <span class="perm-tag">${p.display_name || p.action}</span>
      `).join('');
      html += `</div>`;
    }

    container.innerHTML = html;
  },

  getResourceLabel(resource) {
    const labels = {
      inquiry: '📋 询价管理',
      quote: '💰 报价管理',
      order: '📦 订单管理',
      supplier: '🏭 供应商',
      role: '⚙️ 角色管理',
      user: '👥 员工管理',
      dashboard: '🏠 工作台',
      profile: '👤 个人中心'
    };
    return labels[resource] || resource;
  },

  switchTab(tab) {
    document.querySelectorAll('#page-profile .profile-tab').forEach(t => t.classList.remove('active'));
    event.target.classList.add('active');

    document.getElementById('profile-tab-info').style.display = tab === 'info' ? 'block' : 'none';
    document.getElementById('profile-tab-permissions').style.display = tab === 'permissions' ? 'block' : 'none';
    document.getElementById('profile-tab-settings').style.display = tab === 'settings' ? 'block' : 'none';
  },

  showPasswordChange() {
    document.getElementById('new-password').value = '';
    document.getElementById('confirm-password').value = '';
    showModal('password-modal');
  },

  async changePassword() {
    const newPwd = document.getElementById('new-password').value;
    const confirmPwd = document.getElementById('confirm-password').value;

    if (!newPwd || newPwd.length < 6) {
      showToast('密码至少6位');
      return;
    }
    if (newPwd !== confirmPwd) {
      showToast('两次密码不一致');
      return;
    }

    try {
      const { error } = await db.auth.updateUser({
        password: newPwd
      });
      if (error) throw error;
      showToast('密码修改成功 ✅');
      hideModal('password-modal');
    } catch (e) {
      showToast('修改失败: ' + e.message);
    }
  }
};
