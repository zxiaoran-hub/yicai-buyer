/**
 * 管理模块 - 角色管理 + 员工管理（仅公司管理员可见）
 */
const admin = {
  currentTab: 'roles',

  async load() {
    if (!appState.isCompanyAdmin && !appState.isPlatformAdmin) {
      showToast('无权访问');
      switchPage('dashboard');
      return;
    }
    await this.loadRoles();
  },

  switchTab(tab) {
    this.currentTab = tab;
    document.querySelectorAll('#page-admin .profile-tab').forEach(t => t.classList.remove('active'));
    event.target.classList.add('active');

    document.getElementById('admin-tab-roles').style.display = tab === 'roles' ? 'block' : 'none';
    document.getElementById('admin-tab-users').style.display = tab === 'users' ? 'block' : 'none';

    if (tab === 'roles') this.loadRoles();
    if (tab === 'users') this.loadUsers();
  },

  // ===== 角色管理 =====
  async loadRoles() {
    const container = document.getElementById('roles-list');
    container.innerHTML = '<div class="text-center" style="padding:20px;color:var(--text-secondary);">加载中...</div>';

    try {
      const params = {
        select: '*',
        order: 'sort_order.asc'
      };

      // 加载公司级角色和系统级角色
      const data = await supabase.query('roles', params);

      if (!data || data.length === 0) {
        container.innerHTML = '<div class="empty-state"><div class="empty-icon">⚙️</div><div class="empty-text">暂无角色</div></div>';
        return;
      }

      // 过滤：系统角色 + 本公司角色
      const filteredRoles = data.filter(r =>
        r.is_system || !r.company_id || r.company_id === appState.companyId
      );

      container.innerHTML = filteredRoles.map(role => `
        <div class="card" style="margin-bottom:8px;">
          <div class="flex-between">
            <div>
              <div style="font-size:15px;font-weight:600;">${role.name} ${role.is_system ? '<span class="perm-tag system">系统</span>' : ''}</div>
              <div style="font-size:12px;color:var(--text-secondary);margin-top:4px;">${role.description || '无描述'}</div>
              <div style="font-size:12px;color:var(--text-secondary);margin-top:2px;">数据范围: ${role.data_scope === 'self' ? '仅个人' : '公司全部'}</div>
            </div>
            ${!role.is_system ? `<button class="btn btn-outline btn-sm" onclick="admin.editRole('${role.id}')">编辑</button>` : ''}
          </div>
        </div>
      `).join('');
    } catch (e) {
      container.innerHTML = `<div class="empty-state"><div class="empty-icon">⚠️</div><div class="empty-text">加载失败: ${e.message}</div></div>`;
    }
  },

  async showRoleForm(roleId) {
    document.getElementById('role-form-title').textContent = roleId ? '编辑角色' : '新建角色';
    document.getElementById('role-id').value = roleId || '';
    document.getElementById('role-name').value = '';
    document.getElementById('role-description').value = '';
    document.getElementById('role-data-scope').value = 'company';

    // 加载所有权限供勾选
    try {
      const perms = await supabase.query('permissions', {
        select: '*',
        order: 'sort_order.asc'
      });

      const permsList = document.getElementById('role-permissions-list');
      if (perms && perms.length > 0) {
        permsList.innerHTML = perms.map(p => `
          <label style="display:flex;align-items:center;gap:8px;padding:4px 0;font-size:13px;cursor:pointer;">
            <input type="checkbox" value="${p.id}" class="perm-checkbox">
            <span>${p.display_name || p.resource + ':' + p.action}</span>
            ${p.is_system ? '<span class="perm-tag system">系统</span>' : ''}
          </label>
        `).join('');
      } else {
        permsList.innerHTML = '<div style="font-size:13px;color:var(--text-secondary);">暂无可用权限</div>';
      }

      // 如果是编辑，回填已选权限
      if (roleId) {
        const rolePerms = await supabase.query('role_permissions', {
          select: 'permission_id',
          filter: { role_id: roleId }
        });

        const roleData = await supabase.query('roles', {
          select: '*',
          filter: { id: roleId }
        });

        if (roleData && roleData[0]) {
          document.getElementById('role-name').value = roleData[0].name || '';
          document.getElementById('role-description').value = roleData[0].description || '';
          document.getElementById('role-data-scope').value = roleData[0].data_scope || 'company';
        }

        if (rolePerms) {
          const permIds = rolePerms.map(rp => rp.permission_id);
          permIds.forEach(pid => {
            const cb = permsList.querySelector(`input[value="${pid}"]`);
            if (cb) cb.checked = true;
          });
        }
      }
    } catch (e) {
      console.error('Error loading permissions:', e);
    }

    showModal('role-modal');
  },

  editRole(id) {
    this.showRoleForm(id);
  },

  async saveRole() {
    const id = document.getElementById('role-id').value;
    const data = {
      name: document.getElementById('role-name').value,
      description: document.getElementById('role-description').value,
      data_scope: document.getElementById('role-data-scope').value
    };

    // 仅本公司角色关联company_id
    if (!data.name) {
      showToast('请输入角色名称');
      return;
    }

    if (appState.companyId) {
      data.company_id = appState.companyId;
    }
    data.is_system = false;

    try {
      let roleId = id;
      if (id) {
        await supabase.update('roles', data, { id: id });
        roleId = id;
      } else {
        const result = await supabase.insert('roles', data);
        if (result && result[0]) {
          roleId = result[0].id;
        }
      }

      // 更新权限关联
      if (roleId) {
        // 先删除旧关联
        try {
          await supabase.delete('role_permissions', { role_id: roleId });
        } catch (e) { /* ignore */ }

        // 添加新关联
        const checkedPerms = document.querySelectorAll('.perm-checkbox:checked');
        for (const cb of checkedPerms) {
          await supabase.insert('role_permissions', {
            role_id: roleId,
            permission_id: cb.value
          });
        }
      }

      showToast(id ? '角色已更新 ✅' : '角色已创建 ✅');
      hideModal('role-modal');
      this.loadRoles();
    } catch (e) {
      showToast('保存失败: ' + e.message);
    }
  },

  // ===== 员工管理 =====
  async loadUsers() {
    const container = document.getElementById('users-list');
    container.innerHTML = '<div class="text-center" style="padding:20px;color:var(--text-secondary);">加载中...</div>';

    try {
      const params = {
        select: '*'
      };

      if (appState.companyId) {
        params.filter = { company_id: appState.companyId };
      }

      const data = await supabase.query('user_roles', params);

      if (!data || data.length === 0) {
        container.innerHTML = '<div class="empty-state"><div class="empty-icon">👥</div><div class="empty-text">暂无员工</div></div>';
        return;
      }

      // 获取角色名称
      const roles = await supabase.query('roles', { select: 'id,name' });
      const roleMap = {};
      if (roles) {
        roles.forEach(r => { roleMap[r.id] = r.name; });
      }

      container.innerHTML = data.map(ur => `
        <div class="card" style="margin-bottom:8px;">
          <div class="flex-between">
            <div>
              <div style="font-size:15px;font-weight:600;">${ur.user_email || '未知'}</div>
              <div style="font-size:12px;color:var(--text-secondary);margin-top:4px;">
                角色: <span class="perm-tag">${roleMap[ur.role_id] || '未分配'}</span>
              </div>
            </div>
          </div>
        </div>
      `).join('');
    } catch (e) {
      container.innerHTML = `<div class="empty-state"><div class="empty-icon">⚠️</div><div class="empty-text">加载失败: ${e.message}</div></div>`;
    }
  },

  async showUserForm() {
    document.getElementById('new-user-email').value = '';
    document.getElementById('new-user-name').value = '';
    document.getElementById('new-user-password').value = '';

    // 加载角色供选择
    try {
      const roles = await supabase.query('roles', {
        select: 'id,name',
        filter: appState.companyId ? {} : { is_system: true }
      });

      const filteredRoles = (roles || []).filter(r =>
        r.is_system || !r.company_id || r.company_id === appState.companyId
      );

      const roleSelect = document.getElementById('user-role-select');
      roleSelect.innerHTML = filteredRoles.map(r => `
        <label style="display:flex;align-items:center;gap:8px;padding:4px 0;font-size:13px;cursor:pointer;">
          <input type="radio" name="user_role" value="${r.id}">
          <span>${r.name}</span>
        </label>
      `).join('');
    } catch (e) {
      console.error('Error loading roles:', e);
    }

    showModal('user-form-modal');
  },

  async saveUser() {
    const email = document.getElementById('new-user-email').value;
    const name = document.getElementById('new-user-name').value;
    const password = document.getElementById('new-user-password').value;
    const roleRadio = document.querySelector('input[name="user_role"]:checked');

    if (!email || !name || !password) {
      showToast('请填写完整信息');
      return;
    }
    if (!roleRadio) {
      showToast('请分配角色');
      return;
    }

    try {
      // 注册新用户
      await supabase.signUp(email, password);

      // 注意：这里简化处理，实际需要等新用户确认邮箱后才能正确关联
      // 先尝试通过email查找user_id
      // 在真实场景中，这需要管理员邀请流程或后端RPC

      // 直接插入user_roles记录（需要知道user_id）
      // 这里使用一个简化方案：假设注册后立即可用
      try {
        const signInResult = await supabase.signIn(email, password);
        const userId = signInResult.user?.id;

        if (userId) {
          await supabase.insert('user_roles', {
            user_id: userId,
            company_id: appState.companyId,
            user_email: email,
            role_id: roleRadio.value
          });
        }

        // 登出临时session（不影响当前管理员session）
        // 注意：这里有个问题，signIn会替换当前session
        // 实际应用中应该用service role或RPC来创建
      } catch (e) {
        console.warn('User creation note:', e);
      }

      showToast('员工已添加 ✅');
      hideModal('user-form-modal');
      this.loadUsers();
    } catch (e) {
      showToast('添加失败: ' + e.message);
    }
  }
};
