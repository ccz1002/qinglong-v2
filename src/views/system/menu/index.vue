<!-- 菜单管理 -->
<template>
  <div class="menu-page">
    <div class="art-card">
      <div class="flex items-center justify-between px-5 py-3 border-b border-g-200">
        <span class="font-medium"><ArtSvgIcon icon="ri:menu-line" class="mr-2" />菜单管理</span>
        <div class="flex gap-2">
          <ElButton type="primary" size="small" @click="handleAdd(null)"><ArtSvgIcon icon="ri:add-line" class="mr-1" />顶级菜单</ElButton>
          <ElButton size="small" @click="getMenuList" :loading="loading"><ArtSvgIcon icon="ri:refresh-line" class="mr-1" />刷新</ElButton>
        </div>
      </div>

      <div v-if="flatList.length" class="menu-list">
        <div v-for="(menu, index) in flatList" :key="menu.id" class="menu-row" :style="{ paddingLeft: menu._level * 28 + 12 + 'px' }">
          <span class="menu-sort-btns">
            <ElButton size="small" text :disabled="index === 0" @click="moveUp(index)" title="上移">↑</ElButton>
            <ElButton size="small" text :disabled="index === flatList.length - 1" @click="moveDown(index)" title="下移">↓</ElButton>
            <ElButton size="small" text :disabled="menu._level === 0" @click="outdent(index)" title="升级">←</ElButton>
            <ElButton size="small" text :disabled="index === 0 || flatList[index - 1]._level < menu._level" @click="indent(index)" title="缩进">→</ElButton>
          </span>
          <span class="menu-icon"><ArtSvgIcon :icon="menu.meta?.icon || 'ri:file-line'" /></span>
          <span class="menu-title">{{ menu.meta?.title || menu.name }}</span>
          <span class="menu-path">{{ menu.path }}</span>
          <ElTag v-if="menu.children?.length" size="small" effect="plain" type="info">目录({{ menu.children.length }})</ElTag>
          <ElTag v-else-if="menu.component" size="small" effect="plain" type="primary">页面</ElTag>
          <ElTag v-else size="small" effect="plain" type="warning">空目录</ElTag>
          <div class="menu-actions">
            <ElButton size="small" text type="primary" @click="handleAdd(menu)">+ 子项</ElButton>
            <ElButton size="small" text @click="handleEdit(menu)">编辑</ElButton>
            <ElButton size="small" text type="danger" @click="handleDelete(menu)">删除</ElButton>
          </div>
        </div>
      </div>
      <ElEmpty v-else description="暂无菜单" :image-size="60" class="py-10" />
    </div>

    <ElDialog v-model="dialogVisible" :title="editId ? '编辑菜单' : '新增菜单'" width="500px">
      <ElForm :model="formData" label-width="80px">
        <ElFormItem label="菜单名称"><ElInput v-model="formData.title" placeholder="如：定时任务" /></ElFormItem>
        <ElFormItem label="路由名称"><ElInput v-model="formData.name" placeholder="英文唯一标识，如 Crontab" /></ElFormItem>
        <ElFormItem label="路由路径"><ElInput v-model="formData.path" placeholder="顶级 /crontab，子级 console" /></ElFormItem>
        <ElFormItem label="组件路径"><ElInput v-model="formData.component" placeholder="父菜单留空，页面 /qinglong/crontab/index" /></ElFormItem>
        <ElFormItem label="图标"><ElInput v-model="formData.icon" placeholder="ri:timer-line" /></ElFormItem>
        <ElFormItem label="排序"><ElInputNumber v-model="formData.sort" :min="0" /></ElFormItem>
      </ElForm>
      <template #footer>
        <ElButton @click="dialogVisible = false">取消</ElButton>
        <ElButton type="primary" @click="handleSave" :loading="saving">保存</ElButton>
      </template>
    </ElDialog>
  </div>
</template>

<script setup lang="ts">
import { fetchGetMenuList, fetchCreateMenu, fetchUpdateMenu, fetchDeleteMenu } from '@/api/system-manage'
import { ElMessage, ElMessageBox } from 'element-plus'

defineOptions({ name: 'Menus' })

interface FlatMenu {
  id: number; name: string; path: string; component: string
  meta: any; children?: any[]; _level: number; _parentId: number | null
}

const loading = ref(false); const saving = ref(false)
const treeData = ref<any[]>([])
const apiOnline = ref(true)
const LS_KEY = 'ql_menu_backup'

const flatList = computed<FlatMenu[]>(() => {
  const result: FlatMenu[] = []
  const flatten = (items: any[], level: number, parentId: number | null) => {
    items.forEach((item) => {
      result.push({ ...item, _level: level, _parentId: parentId })
      if (item.children?.length) flatten(item.children, level + 1, item.id)
    })
  }
  flatten(treeData.value, 0, null)
  return result
})

const dialogVisible = ref(false); const editId = ref<number | null>(null)
const parentMenu = ref<any>(null)
const formData = reactive({ title: '', name: '', path: '', component: '', icon: '', sort: 0 })

// ── 默认菜单 ──
const defaultMenus = (): any[] => {
  const id = (n: string) => Math.abs(n.split('').reduce((a: number, c: string) => a + c.charCodeAt(0), 0))
  return [
    { id: id('dash'), name: 'Dashboard', path: '/dashboard', component: '/qinglong/dashboard/index', meta: { title: '仪表盘', icon: 'ri:dashboard-line' } },
    { id: id('cron'), name: 'Crontab', path: '/crontab', component: '/qinglong/crontab/index', meta: { title: '定时任务', icon: 'ri:timer-line' } },
    { id: id('sub'), name: 'Subscription', path: '/subscription', component: '/qinglong/subscription/index', meta: { title: '订阅管理', icon: 'ri:git-repository-line' } },
    { id: id('env'), name: 'Env', path: '/env', component: '/qinglong/env/index', meta: { title: '环境变量', icon: 'ri:settings-3-line' } },
    { id: id('cfg'), name: 'Config', path: '/config', component: '/qinglong/config/index', meta: { title: '配置文件', icon: 'ri:file-list-3-line' } },
    { id: id('scr'), name: 'Script', path: '/script', component: '/qinglong/script/index', meta: { title: '脚本管理', icon: 'ri:code-box-line' } },
    { id: id('dep'), name: 'Dependence', path: '/dependence', component: '/qinglong/dependence/index', meta: { title: '依赖管理', icon: 'ri:archive-line' } },
    { id: id('log'), name: 'Log', path: '/log', component: '/qinglong/log/index', meta: { title: '日志管理', icon: 'ri:file-text-line' } },
    { id: id('diff'), name: 'Diff', path: '/diff', component: '/qinglong/diff/index', meta: { title: '对比工具', icon: 'ri:sparkling-line' } },
    { id: id('set'), name: 'Setting', path: '/setting', component: '/qinglong/setting/index', meta: { title: '系统设置', icon: 'ri:settings-2-line' } },
    { id: id('sys'), name: 'System', path: '/system', component: '/index/index', meta: { title: '菜单管理', icon: 'ri:settings-line' }, children: [
      { id: id('menu'), name: 'MenuManage', path: 'menu', component: '/system/menu/index', meta: { title: '配置菜单', icon: 'ri:menu-line' } }
    ]},
  ]
}

// ── localStorage 读写 ──
const loadFromLocal = () => {
  try {
    const raw = localStorage.getItem(LS_KEY)
    return raw ? JSON.parse(raw) : null
  } catch { return null }
}
const saveToLocal = (data: any[]) => {
  try { localStorage.setItem(LS_KEY, JSON.stringify(data)) } catch { /* quota exceeded */ }
}

// ── 获取菜单 ──
const getMenuList = async () => {
  loading.value = true
  try {
    treeData.value = await fetchGetMenuList()
    apiOnline.value = true
    saveToLocal(treeData.value)
  } catch {
    apiOnline.value = false
    const local = loadFromLocal()
    treeData.value = local || defaultMenus()
  } finally {
    loading.value = false
  }
}

// ── 生成临时 ID ──
const nextLocalId = () => {
  let max = 0
  flatList.value.forEach(m => { if (m.id > max) max = m.id })
  return max + 1
}

// ── 添加 ──
const handleAdd = (parent: any | null) => {
  editId.value = null; parentMenu.value = parent
  formData.title = ''; formData.name = ''; formData.path = parent ? '' : '/'
  formData.component = ''; formData.icon = ''; formData.sort = 0
  dialogVisible.value = true
}

// ── 编辑 ──
const handleEdit = (menu: any) => {
  editId.value = menu.id; parentMenu.value = null
  formData.title = menu.meta?.title || menu.name || ''
  formData.name = menu.name || ''; formData.path = menu.path || ''
  formData.component = menu.component || ''; formData.icon = menu.meta?.icon || ''
  formData.sort = menu.meta?.sort ?? 0
  dialogVisible.value = true
}

// ── 本地增删改 ──
const localAdd = (payload: any) => {
  const newItem: any = {
    id: nextLocalId(), name: payload.name, path: payload.path,
    component: payload.component || '',
    meta: { title: payload.title, icon: payload.icon || '' }
  }
  if (payload.parentId) {
    const addToParent = (items: any[]): boolean => {
      for (const item of items) {
        if (item.id === payload.parentId) {
          if (!item.children) item.children = []
          item.children.push(newItem)
          return true
        }
        if (item.children && addToParent(item.children)) return true
      }
      return false
    }
    addToParent(treeData.value)
  } else {
    treeData.value.push(newItem)
  }
}

const localUpdate = (id: number, payload: any) => {
  const update = (items: any[]) => {
    for (const item of items) {
      if (item.id === id) {
        item.name = payload.name; item.path = payload.path
        item.component = payload.component || ''
        item.meta = { ...item.meta, title: payload.title, icon: payload.icon || '' }
        if (payload.parentId !== undefined) { /* parent change handled separately */ }
        return true
      }
      if (item.children && update(item.children)) return true
    }
    return false
  }
  update(treeData.value)
}

const localDelete = (id: number) => {
  const remove = (items: any[]): boolean => {
    for (let i = 0; i < items.length; i++) {
      if (items[i].id === id) { items.splice(i, 1); return true }
      if (items[i].children && remove(items[i].children)) return true
    }
    return false
  }
  remove(treeData.value)
}

// ── 保存 ──
const handleSave = async () => {
  saving.value = true
  const payload = {
    name: formData.name || formData.title,
    path: formData.path, component: formData.component,
    title: formData.title, icon: formData.icon,
    parentId: parentMenu.value?.id || null, sort: formData.sort
  }
  try {
    if (apiOnline.value) {
      if (editId.value) { await fetchUpdateMenu(editId.value, payload); ElMessage.success('已更新') }
      else { await fetchCreateMenu(payload); ElMessage.success('已创建') }
    } else {
      if (editId.value) { localUpdate(editId.value, payload); ElMessage.success('已更新 (本地)') }
      else { localAdd(payload); ElMessage.success('已创建 (本地)') }
      saveToLocal(treeData.value)
    }
    dialogVisible.value = false; getMenuList()
  } catch (err: any) {
    // API 调用失败，回退到本地
    if (editId.value) { localUpdate(editId.value, payload) }
    else { localAdd(payload) }
    saveToLocal(treeData.value)
    apiOnline.value = false
    ElMessage.success(editId.value ? '已更新 (本地离线模式)' : '已创建 (本地离线模式)')
    dialogVisible.value = false; getMenuList()
  } finally { saving.value = false }
}

// ── 删除 ──
const handleDelete = async (menu: any) => {
  if (!menu.id) return
  try {
    const msg = menu.children?.length ? `删除 "${menu.meta?.title || menu.name}" 及所有子菜单？` : `确定删除 "${menu.meta?.title || menu.name}"？`
    await ElMessageBox.confirm(msg, '警告', { type: 'warning' })
    if (apiOnline.value) {
      await fetchDeleteMenu(menu.id)
    } else {
      localDelete(menu.id)
      saveToLocal(treeData.value)
    }
    ElMessage.success('已删除')
    getMenuList()
  } catch { }
}

// ── 排序 (本地支持) ──
const swapSort = async (i: number, j: number) => {
  const a = flatList.value[i]; const b = flatList.value[j]
  if (a._parentId !== b._parentId || a._level !== b._level) { ElMessage.warning('只能与同级菜单交换位置'); return }
  if (apiOnline.value) {
    const sortA = a.meta?.sort ?? i; const sortB = b.meta?.sort ?? j
    await fetchUpdateMenu(a.id, { sort: sortB }); await fetchUpdateMenu(b.id, { sort: sortA })
  } else {
    const items = treeData.value
    const swapInTree = (list: any[]) => {
      const ai = list.findIndex((m: any) => m.id === a.id)
      const bi = list.findIndex((m: any) => m.id === b.id)
      if (ai >= 0 && bi >= 0) { [list[ai], list[bi]] = [list[bi], list[ai]] }
      list.forEach((m: any) => { if (m.children) swapInTree(m.children) })
    }
    swapInTree(items); saveToLocal(treeData.value)
    ElMessage.success('已排序')
  }
  getMenuList()
}
const moveUp = (i: number) => { if (i > 0) swapSort(i, i - 1) }
const moveDown = (i: number) => { if (i < flatList.value.length - 1) swapSort(i, i + 1) }

const indent = async (i: number) => {
  if (i === 0) return
  const prev = flatList.value[i - 1]; const cur = flatList.value[i]
  if (apiOnline.value) await fetchUpdateMenu(cur.id, { parentId: prev.id, sort: 0 })
  else { localUpdate(cur.id, { parentId: prev.id }); saveToLocal(treeData.value) }
  ElMessage.success(`"${cur.meta?.title || cur.name}" → "${prev.meta?.title || prev.name}" 的子菜单`)
  getMenuList()
}
const outdent = async (i: number) => {
  const cur = flatList.value[i]; if (cur._level === 0) return
  let gp: number | null = null
  for (let j = i - 1; j >= 0; j--) { if (flatList.value[j].id === cur._parentId) { gp = flatList.value[j]._parentId; break } }
  if (apiOnline.value) await fetchUpdateMenu(cur.id, { parentId: gp, sort: 0 })
  else { localUpdate(cur.id, { parentId: gp }); saveToLocal(treeData.value) }
  ElMessage.success(`"${cur.meta?.title || cur.name}" 已升级`)
  getMenuList()
}

onMounted(() => getMenuList())
</script>

<style scoped lang="scss">
.menu-list { border: 1px solid #f0f0f0; border-radius: 8px; }
.menu-row {
  display: flex; align-items: center; gap: 8px; padding: 8px 12px;
  border-bottom: 1px solid #f5f5f5; transition: background 0.15s;
  &:hover { background: #f9fafb; }
  &:last-child { border-bottom: none; }
}
.menu-sort-btns { display: flex; gap: 0;
  .el-button { padding: 2px 4px; font-size: 14px; }
}
.menu-icon { width: 24px; text-align: center; color: var(--el-color-primary); font-size: 16px; }
.menu-title { flex: 1; font-size: 14px; font-weight: 500; min-width: 80px; }
.menu-path { font-size: 12px; color: #999; font-family: monospace; }
.menu-actions { display: flex; gap: 2px; flex-shrink: 0; }
</style>
