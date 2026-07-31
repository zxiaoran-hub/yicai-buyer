/**
 * 异采 YiCai 品牌方端 - 主应用入口
 * 负责: Supabase初始化、认证、RBAC、路由、公共方法
 */

// ===== Supabase 初始化 =====
const { createClient } = supabase;
const db = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ===== 全局状态 =====
const appState = {
  user: null,
  userPermissions: null,  // RBAC 权限数据
  companyId: null,
  isIndividual: false,     // 是否个人用户
  isCompanyAdmin: false,   // 是否公司管理员
  isPlatformAdmin: false,  // 是否平台管理员
  roles: [],
  permissions: [],
  currentPage: 'dashboard'
};

// 全局权限对象（供各模块使用）
window.userPermissions = null;

// ===== 状态映射 =====
const STATUS_MAP = {
  open: { label: '询价中', color: 'success' },
  closed: { label: '已关闭', color: 'info' },
  awarded: { label: '已定标', color: 'gold' },
  pending: { label: '待确认', color: 'warning' },
  confirmed: { label: '已确认', color: 'info' },
  producing: { label: '生产中', color: 'info' },
  completed: { label: '已完成', color: 'success' },
  cancelled: { label: '已取消', color: 'danger' }
};

// ===== 认证模块 =====
const auth = {
  // 公司用户登录
  async signIn(email, password) {
    const data = await supabase.signIn(email, password);
    if (data.access_token) {
      localStorage.setItem('yicai_buyer_token', data.access_token);
      localStorage.setItem('yicai_buyer_refresh', data.refresh_token);
    }
    appState.user = data.user;
    await this.loadPermissions();
    return data;
  },

  // 个人用户登录
  async signInIndividual(email, password) {
    return this.signIn(email, password);
  },

  // 公司用户注册（通过 supabase.auth.signUp + RPC）
  async registerCompany(email, password, companyName, adminName) {
    // 先注册 auth
    const signUpData = await supabase.signUp(email, password);

    if (signUpData.user) {
      // 登录获取token
      const signInData = await supabase.signIn(email, password);
      localStorage.setItem('yicai_buyer_token', signInData.access_token);
      localStorage.setItem('yicai_buyer_refresh', signInData.refresh_token);
      appState.user = signInData.user;

      // 调用RPC创建公司及管理员角色（需要后端有对应的RPC）
      try {
        await supabase.rpc('register_company_buyer', {
          p_email: email,
          p_password: password,
          p_company_name: companyName,
          p_admin_name: adminName
        });
      } catch (e) {
        console.warn('Company registration RPC not available, trying direct insert...');
        // 回退方案：直接插入数据
        await this.fallbackCompanyRegister(email, companyName, adminName);
      }

      await this.loadPermissions();
    }
    return signUpData;
  },

  // 回退方案：直接通过REST API创建公司
  async fallbackCompanyRegister(email, companyName, adminName) {
    try {
      // 创建公司记录
      const companyResult = await supabase.insert('companies', {
        name: companyName,
        type: 'buyer',
        status: 'active'
      });

      if (companyResult && companyResult[0]) {
        const companyId = companyResult[0].id;

        // 获取系统管理员角色
        const roles = await supabase.query('roles', {
          select: 'id',
          filter: { is_system: true, company_id: null },
          like: { name: '%admin%' }
        });

        // 创建 user_roles 关联
        if (appState.user) {
          await supabase.insert('user_roles', {
            user_id: appState.user.id,
            company_id: companyId,
            user_email: email,
            role_id: roles && roles[0] ? roles[0].id : null
          });
        }
      }
    } catch (e) {
      console.error('Fallback registration error:', e);
    }
  },

  // 个人用户注册
  async registerIndividual(email, password, name) {
    try {
      // 调用RPC注册个人买家
      const result = await supabase.rpc('register_individual_buyer', {
        p_email: email,
        p_password: password,
        p_name: name
      });

      // 登录
      const signInData = await supabase.signIn(email, password);
      localStorage.setItem('yicai_buyer_token', signInData.access_token);
      localStorage.setItem('yicai_buyer_refresh', signInData.refresh_token);
      appState.user = signInData.user;
      appState.isIndividual = true;

      await this.loadPermissions();
      return result;
    } catch (e) {
      // RPC不可用时回退
      console.warn('Individual registration RPC not available, trying direct...');
      const signUpData = await supabase.signUp(email, password);

      if (signUpData.user) {
        const signInData = await supabase.signIn(email, password);
        localStorage.setItem('yicai_buyer_token', signInData.access_token);
      localStorage.setItem('yicai_buyer_refresh', signInData.refresh_token);
        appState.user = signInData.user;
        appState.isIndividual = true;

        // 尝试关联默认角色
        try {
          const defaultRole = await supabase.query('roles', {
            select: 'id',
            filter: { is_system: true },
            like: { name: '%individual%' }
          });

          if (defaultRole && defaultRole[0]) {
            await supabase.insert('user_roles', {
              user_id: appState.user.id,
              company_id: null,
              user_email: email,
              role_id: defaultRole[0].id
            });
          }
        } catch (err) {
          console.warn('Could not assign default role:', err);
        }

        await this.loadPermissions();
      }
      return signUpData;
    }
  },

  // 加载权限
  async loadPermissions() {
    if (!appState.user) return;

    try {
      const result = await supabase.rpc('get_user_permissions', {
        p_user_id: appState.user.id
      });

      if (result && result[0]) {
        const perms = result[0];
        appState.userPermissions = perms;
        window.userPermissions = perms;
        appState.companyId = perms.company_id;
        appState.isCompanyAdmin = perms.is_company_admin || false;
        appState.isPlatformAdmin = perms.is_platform_admin || false;
        appState.roles = perms.roles || [];
        appState.permissions = perms.permissions || [];
        appState.isIndividual = !perms.company_id;
      }
    } catch (e) {
      console.warn('Failed to load permissions via RPC, trying alternative...');
      await this.loadPermissionsFallback();
    }
  },

  // 回退方案：直接查询权限
  async loadPermissionsFallback() {
    try {
      const userRoles = await supabase.query('user_roles', {
        select: 'id,role_id,company_id,user_email',
        filter: { user_id: appState.user.id }
      });

      if (userRoles && userRoles[0]) {
        const ur = userRoles[0];
        appState.companyId = ur.company_id;
        appState.isIndividual = !ur.company_id;

        if (ur.role_id) {
          const rolePerms = await supabase.query('role_permissions', {
            select: '*',
            filter: { role_id: ur.role_id }
          });

          const permIds = (rolePerms || []).map(rp => rp.permission_id);
          if (permIds.length > 0) {
            const perms = await supabase.query('permissions', {
              select: '*',
              in: { id: permIds.join(',') }
            });
            appState.permissions = perms || [];
          }
        }

        // 获取角色名
        if (ur.role_id) {
          const roles = await supabase.query('roles', {
            select: '*',
            filter: { id: ur.role_id }
          });
          appState.roles = roles || [];
          if (roles && roles[0]) {
            appState.isCompanyAdmin = roles[0].name.toLowerCase().includes('admin');
          }
        }

        window.userPermissions = {
          user_id: appState.user.id,
          company_id: appState.companyId,
          is_company_admin: appState.isCompanyAdmin,
          is_platform_admin: appState.isPlatformAdmin,
          roles: appState.roles,
          permissions: appState.permissions
        };
      }
    } catch (e) {
      console.error('Fallback permission load error:', e);
    }
  },

  // 获取company_id（通过RPC或备用方式）
  async getCompanyId() {
    if (appState.companyId) return appState.companyId;
    try {
      const result = await supabase.rpc('get_user_company_id');
      if (result) {
        appState.companyId = result;
        return result;
      }
    } catch (e) {
      // 从user_roles中获取
      const userRoles = await supabase.query('user_roles', {
        select: 'company_id',
        filter: { user_id: appState.user.id }
      });
      if (userRoles && userRoles[0]) {
        appState.companyId = userRoles[0].company_id;
        return userRoles[0].company_id;
      }
    }
    return null;
  },

  // 检查是否有某权限
  hasPermission(resource, action) {
    if (appState.isPlatformAdmin || appState.isCompanyAdmin) return true;
    return appState.permissions.some(p =>
      p.resource === resource && p.action === action && p.effect === 'allow'
    );
  },

  // 登出
  async signOut() {
    try {
      await db.auth.signOut();
    } catch (e) {
      console.warn('Sign out error:', e);
    }
    localStorage.removeItem('yicai_buyer_token');
    localStorage.removeItem('yicai_buyer_refresh');
    appState.user = null;
    appState.userPermissions = null;
    window.userPermissions = null;
    appState.companyId = null;
    appState.isIndividual = false;
    appState.isCompanyAdmin = false;
    appState.isPlatformAdmin = false;
    appState.roles = [];
    appState.permissions = [];
    showLogin();
  },

  // 检查登录状态
  async checkSession() {
    const { data: { session } } = await db.auth.getSession();
    if (session) {
      appState.user = session.user;
      await this.loadPermissions();
      return true;
    }
    return false;
  }
};

// ===== 路由 =====
function switchPage(page) {
  // 权限检查：管理页面仅管理员可见
  if (page === 'admin' && !appState.isCompanyAdmin && !appState.isPlatformAdmin) {
    showToast('无权访问管理页面');
    return;
  }

  appState.currentPage = page;
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.tab-item').forEach(t => t.classList.remove('active'));

  const pageEl = document.getElementById(`page-${page}`);
  const tabEl = document.querySelector(`.tab-item[data-page="${page}"]`);
  if (pageEl) pageEl.classList.add('active');
  if (tabEl) tabEl.classList.add('active');

  // 触发页面数据加载
  switch (page) {
    case 'dashboard': dashboard.load(); break;
    case 'inquiries': inquiries.load(); break;
    case 'quotes': quotes.load(); break;
    case 'orders': orders.load(); break;
    case 'suppliers': suppliers.load(); break;
    case 'admin': admin.load(); break;
    case 'profile': profile.load(); break;
  }
}

// ===== UI 工具 =====
function showLogin() {
  document.getElementById('login-page').style.display = 'flex';
  document.getElementById('main-app').style.display = 'none';
}

function showApp() {
  document.getElementById('login-page').style.display = 'none';
  document.getElementById('main-app').style.display = 'block';

  // 设置头部角色标签
  const roleNames = appState.roles.map(r => r.name).join('、') || '用户';
  document.getElementById('header-role-badge').textContent = roleNames;

  // 管理员Tab显示控制
  const adminTab = document.getElementById('tab-admin');
  const adminPage = document.getElementById('page-admin');
  if (appState.isCompanyAdmin || appState.isPlatformAdmin) {
    if (adminTab) adminTab.style.display = '';
    if (adminPage) adminPage.style.display = '';
  } else {
    if (adminTab) adminTab.style.display = 'none';
    if (adminPage) adminPage.style.display = 'none';
  }

  switchPage('dashboard');
}

function showToast(msg, duration = 2500) {
  const toast = document.getElementById('toast');
  toast.textContent = msg;
  toast.classList.add('show');
  setTimeout(() => toast.classList.remove('show'), duration);
}

function showModal(id) {
  document.getElementById(id).classList.add('active');
}

function hideModal(id) {
  document.getElementById(id).classList.remove('active');
}

function formatMoney(n) {
  if (!n && n !== 0) return '¥0';
  return '¥' + Number(n).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function formatDate(d) {
  if (!d) return '-';
  const date = new Date(d);
  return `${date.getMonth()+1}/${date.getDate()}`;
}

function formatDateTime(d) {
  if (!d) return '-';
  const date = new Date(d);
  return `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')} ${String(date.getHours()).padStart(2,'0')}:${String(date.getMinutes()).padStart(2,'0')}`;
}

function getStatusLabel(status) {
  return STATUS_MAP[status]?.label || status;
}

function getStatusClass(status) {
  return `status-${status}`;
}

// ===== 权限检查辅助 =====
function hasMenuAccess(menuPath) {
  if (appState.isPlatformAdmin || appState.isCompanyAdmin) return true;
  return appState.permissions.some(p => p.menu_path === menuPath);
}

function hasButtonAccess(buttonKey) {
  if (appState.isPlatformAdmin || appState.isCompanyAdmin) return true;
  return appState.permissions.some(p => p.button_key === buttonKey);
}

// ===== Dashboard =====
const dashboard = {
  async load() {
    const userName = appState.user?.email?.split('@')[0] || '用户';
    document.getElementById('user-greeting').textContent = `你好，${userName} 👋`;

    try {
      // 加载统计数据
      const companyId = appState.companyId;

      // 询价统计
      const inquiryParams = companyId ? { filter: { company_id: companyId } } : { filter: { created_by: appState.user?.id } };
      const inquiryCount = await supabase.getCount('buyer_inquiries', inquiryParams.filter || {});
      document.getElementById('stat-inquiries').textContent = inquiryCount || 0;

      // 报价统计
      let quoteCount = 0;
      if (companyId) {
        quoteCount = await supabase.getCount('supplier_quotes', { inquiry_company_id: companyId });
      }
      document.getElementById('stat-quotes-received').textContent = quoteCount || 0;

      // 订单统计
      const orderFilter = companyId ? { company_id: companyId } : { buyer_user_id: appState.user?.id };
      const orderCount = await supabase.getCount('buyer_orders', orderFilter);
      document.getElementById('stat-orders').textContent = orderCount || 0;

      // 供应商数
      const supplierCount = await supabase.getCount('suppliers', { status: 'active' });
      document.getElementById('stat-suppliers').textContent = supplierCount || 0;

      // 最近询价
      const recentInquiries = await supabase.query('buyer_inquiries', {
        select: 'id,title,status,created_at',
        filter: companyId ? { company_id: companyId } : { created_by: appState.user?.id },
        order: 'created_at.desc',
        limit: 3
      });

      const recentInqEl = document.getElementById('recent-inquiries');
      if (recentInquiries && recentInquiries.length > 0) {
        recentInqEl.innerHTML = recentInquiries.map(i => `
          <div class="inquiry-card ${getStatusClass(i.status)}" style="margin-bottom:8px;cursor:pointer;" onclick="switchPage('inquiries')">
            <div class="inquiry-header">
              <div class="inquiry-title" style="font-size:14px;">${i.title || '未命名询价'}</div>
              <span class="inquiry-badge">${getStatusLabel(i.status)}</span>
            </div>
            <div style="font-size:12px;color:var(--text-secondary);">${formatDateTime(i.created_at)}</div>
          </div>
        `).join('');
      } else {
        recentInqEl.innerHTML = '<div class="empty-state"><div class="empty-icon">📋</div><div class="empty-text">暂无询价</div></div>';
      }

      // 最近订单
      const recentOrders = await supabase.query('buyer_orders', {
        select: 'id,product_name,status,created_at',
        filter: orderFilter,
        order: 'created_at.desc',
        limit: 3
      });

      const recentOrdEl = document.getElementById('recent-orders');
      if (recentOrders && recentOrders.length > 0) {
        recentOrdEl.innerHTML = recentOrders.map(o => `
          <div class="order-card ${getStatusClass(o.status)}" style="margin-bottom:8px;cursor:pointer;" onclick="switchPage('orders')">
            <div class="order-header">
              <div class="order-product" style="font-size:14px;">${o.product_name || '未命名'}</div>
              <span class="order-status">${getStatusLabel(o.status)}</span>
            </div>
            <div style="font-size:12px;color:var(--text-secondary);">${formatDateTime(o.created_at)}</div>
          </div>
        `).join('');
      } else {
        recentOrdEl.innerHTML = '<div class="empty-state"><div class="empty-icon">📦</div><div class="empty-text">暂无订单</div></div>';
      }
    } catch (e) {
      console.error('Dashboard load error:', e);
    }
  }
};

// ===== 表单切换 =====
function toggleAuthForm(form) {
  const forms = ['login-form', 'register-company-form', 'login-individual-form', 'register-individual-form'];
  forms.forEach(f => {
    document.getElementById(f).style.display = 'none';
  });

  switch (form) {
    case 'login':
      document.getElementById('login-form').style.display = 'block';
      break;
    case 'register-company':
      document.getElementById('register-company-form').style.display = 'block';
      break;
    case 'login-individual':
      document.getElementById('login-individual-form').style.display = 'block';
      break;
    case 'register-individual':
      document.getElementById('register-individual-form').style.display = 'block';
      break;
  }
}

// ===== 初始化 =====
async function init() {
  try {
    const loggedIn = await auth.checkSession();
    if (loggedIn && appState.user) {
      showApp();
    } else {
      showLogin();
    }
  } catch (e) {
    console.error('Init error:', e);
    showLogin();
  }
}

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', init);

// ===== 表单提交处理 =====
document.addEventListener('submit', async (e) => {
  e.preventDefault();
  const form = e.target;

  // 公司用户登录
  if (form.id === 'login-form') {
    const email = form.querySelector('[name=email]').value;
    const password = form.querySelector('[name=password]').value;
    const btn = form.querySelector('button[type=submit]');
    btn.disabled = true;
    btn.textContent = '登录中...';
    try {
      await auth.signIn(email, password);
      showApp();
      showToast('欢迎回来 👋');
    } catch (err) {
      showToast('登录失败: ' + err.message);
    }
    btn.disabled = false;
    btn.textContent = '登录';
  }

  // 公司用户注册
  if (form.id === 'register-company-form') {
    const companyName = form.querySelector('[name=company_name]').value;
    const email = form.querySelector('[name=email]').value;
    const adminName = form.querySelector('[name=admin_name]').value;
    const password = form.querySelector('[name=password]').value;
    const btn = form.querySelector('button[type=submit]');
    btn.disabled = true;
    btn.textContent = '注册中...';
    try {
      await auth.registerCompany(email, password, companyName, adminName);
      showApp();
      showToast('企业注册成功 🎉');
    } catch (err) {
      showToast('注册失败: ' + err.message);
    }
    btn.disabled = false;
    btn.textContent = '注册企业';
  }

  // 个人用户登录
  if (form.id === 'login-individual-form') {
    const email = form.querySelector('[name=email]').value;
    const password = form.querySelector('[name=password]').value;
    const btn = form.querySelector('button[type=submit]');
    btn.disabled = true;
    btn.textContent = '登录中...';
    try {
      await auth.signInIndividual(email, password);
      showApp();
      showToast('欢迎回来 👋');
    } catch (err) {
      showToast('登录失败: ' + err.message);
    }
    btn.disabled = false;
    btn.textContent = '个人用户登录';
  }

  // 个人用户注册
  if (form.id === 'register-individual-form') {
    const name = form.querySelector('[name=name]').value;
    const email = form.querySelector('[name=email]').value;
    const password = form.querySelector('[name=password]').value;
    const btn = form.querySelector('button[type=submit]');
    btn.disabled = true;
    btn.textContent = '注册中...';
    try {
      await auth.registerIndividual(email, password, name);
      showApp();
      showToast('注册成功 🎉');
    } catch (err) {
      showToast('注册失败: ' + err.message);
    }
    btn.disabled = false;
    btn.textContent = '注册';
  }
});
