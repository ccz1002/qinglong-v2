<!-- 菜单管理 - 树形列表 + 按钮排序 -->
<template>
  <div class="menu-page">
    <ElCard>
      <template #header>
        <div class="flex items-center justify-between">
          <span>菜单管理</span>
          <div class="flex gap-2">
            <ElButton type="primary" @click="handleAdd(null)">+ 添加顶级菜单</ElButton>
            <ElButton @click="getMenuList" :loading="loading">刷新</ElButton>
          </div>
        </div>
      </template>

      <!-- 树形菜单列表 -->
      <div v-if="flatList.length" class="menu-list">
        <div
          v-for="(menu, index) in flatList"
          :key="menu.id"
          class="menu-row"
          :style="{ paddingLeft: menu._level * 28 + 12 + 'px' }"
        >
          <span class="menu-sort-btns">
            <ElButton size="small" text :disabled="index === 0" @click="moveUp(index)" title="上移">↑</ElButton>
            <ElButton size="small" text :disabled="index === flatList.length - 1" @click="moveDown(index)" title="下移">↓</ElButton>
            <ElButton size="small" text :disabled="menu._level === 0" @click="outdent(index)" title="升级">←</ElButton>
            <ElButton size="small" text :disabled="index === 0 || flatList[index-1]._level < menu._level" @click="indent(index)" title="缩进（变成上一个菜单的子菜单）">→</ElButton>
          </span>
          <span class="menu-icon"><i :class="menu.meta?.icon || 'ri:file-line'" style="font-size:16px"></i></span>
          <span class="menu-title">{{ formatMenuTitle(menu.meta?.title) || menu.name }}</span>
          <span class="menu-path">{{ menu.path }}</span>
          <ElTag v-if="menu.children?.length" size="small" type="info">目录({{ menu.children.length }})</ElTag>
          <ElTag v-else-if="menu.component" size="small" type="primary">页面</ElTag>
          <ElTag v-else size="small" type="warning">空目录</ElTag>
          <div class="menu-actions">
            <ElButton size="small" text type="primary" @click="handleAdd(menu)">+ 子项</ElButton>
            <ElButton size="small" text @click="handleEdit(menu)">编辑</ElButton>
            <ElButton size="small" text type="danger" @click="handleDelete(menu)">删除</ElButton>
          </div>
        </div>
      </div>
      <ElEmpty v-else description="暂无菜单" />
    </ElCard>

    <!-- 编辑弹窗 -->
    <ElDialog v-model="dialogVisible" :title="editId ? '编辑菜单' : '新增菜单'" width="500px">
      <ElForm :model="formData" label-width="80px">
        <ElFormItem label="菜单名称">
          <ElInput v-model="formData.title" placeholder="如：定时任务" />
        </ElFormItem>
        <ElFormItem label="路由名称">
          <ElInput v-model="formData.name" placeholder="如：Crontab（英文唯一标识）" />
        </ElFormItem>
        <ElFormItem label="路由路径">
          <ElInput v-model="formData.path" placeholder="顶级：/crontab  子级：console" />
        </ElFormItem>
        <ElFormItem label="组件路径">
          <ElInput v-model="formData.component" placeholder="父菜单留空，页面：/qinglong/crontab/index" />
          <div style="color:#999;font-size:12px;margin-top:4px">有子菜单时留空，单独页面填完整路径</div>
        </ElFormItem>
        <ElFormItem label="图标">
          <ElInput v-model="formData.icon" placeholder="ri:timer-line（Remix Icon）" />
        </ElFormItem>
        <ElFormItem label="排序">
          <ElInputNumber v-model="formData.sort" :min="0" />
        </ElFormItem>
      </ElForm>
      <template #footer>
        <ElButton @click="dialogVisible = false">取消</ElButton>
        <ElButton type="primary" @click="handleSave" :loading="saving">保存</ElButton>
      </template>
    </ElDialog>
  </div>
</template>

<script setup lang="ts">
import { formatMenuTitle } from '@/utils/router'
import { fetchGetMenuList, fetchCreateMenu, fetchUpdateMenu, fetchDeleteMenu } from '@/api/system-manage'
import { ElMessage, ElMessageBox } from 'element-plus'

defineOptions({ name: 'Menus' })

interface FlatMenu {
  id: number
  name: string
  path: string
  component: string
  meta: any
  children?: any[]
  _level: number
  _parentId: number | null
}

const loading = ref(false)
const saving = ref(false)
const treeData = ref<any[]>([])
const flatList = computed<FlatMenu[]>(() => {
  const result: FlatMenu[] = []
  const flatten = (items: any[], level: number, parentId: number | null) => {
    items.forEach((item) => {
      result.push({ ...item, _level: level, _parentId: parentId })
      if (item.children?.length) {
        flatten(item.children, level + 1, item.id)
      }
    })
  }
  flatten(treeData.value, 0, null)
  return result
})

const dialogVisible = ref(false)
const editId = ref<number | null>(null)
const parentMenu = ref<any>(null)
const formData = reactive({ title: '', name: '', path: '', component: '', icon: '', sort: 0 })

// 获取菜单树
const getMenuList = async () => {
  loading.value = true
  try {
    treeData.value = await fetchGetMenuList()
  } catch (err: any) {
    ElMessage.error('获取菜单失败: ' + (err.message || ''))
  } finally {
    loading.value = false
  }
}

// 添加
const handleAdd = (parent: any | null) => {
  editId.value = null
  parentMenu.value = parent
  formData.title = ''
  formData.name = ''
  formData.path = parent ? '' : '/'
  formData.component = ''
  formData.icon = ''
  formData.sort = 0
  dialogVisible.value = true
}

// 编辑
const handleEdit = (menu: any) => {
  editId.value = menu.id
  parentMenu.value = null
  formData.title = formatMenuTitle(menu.meta?.title) || menu.name || ''
  formData.name = menu.name || ''
  formData.path = menu.path || ''
  formData.component = menu.component || ''
  formData.icon = menu.meta?.icon || ''
  formData.sort = menu.meta?.sort ?? 0
  dialogVisible.value = true
}

// 保存
const handleSave = async () => {
  saving.value = true
  try {
    const payload = {
      name: formData.name || formData.title,
      path: formData.path,
      component: formData.component,
      title: formData.title,
      icon: formData.icon,
      parentId: parentMenu.value?.id || null,
      sort: formData.sort
    }
    if (editId.value) {
      await fetchUpdateMenu(editId.value, payload)
      ElMessage.success('已更新')
    } else {
      await fetchCreateMenu(payload)
      ElMessage.success('已创建')
    }
    dialogVisible.value = false
    getMenuList()
  } catch (err: any) {
    ElMessage.error(err?.message || '保存失败')
  } finally {
    saving.value = false
  }
}

// 删除
const handleDelete = async (menu: any) => {
  if (!menu.id) return
  try {
    const msg = menu.children?.length
      ? `删除 "${menu.meta?.title || menu.name}" 及其所有子菜单？`
      : `确定删除 "${menu.meta?.title || menu.name}"？`
    await ElMessageBox.confirm(msg, '警告', { type: 'warning' })
    await fetchDeleteMenu(menu.id)
    ElMessage.success('已删除')
    getMenuList()
  } catch {}
}

// 上移
const moveUp = async (index: number) => {
  if (index === 0) return
  await swapSort(index, index - 1)
}

// 下移
const moveDown = async (index: number) => {
  if (index >= flatList.value.length - 1) return
  await swapSort(index, index + 1)
}

// 交换两个同级菜单的排序
const swapSort = async (i: number, j: number) => {
  const a = flatList.value[i]
  const b = flatList.value[j]
  if (a._parentId !== b._parentId || a._level !== b._level) {
    ElMessage.warning('只能与同级的菜单交换位置')
    return
  }
  // 交换 sort 值
  const sortA = a.meta?.sort ?? i
  const sortB = b.meta?.sort ?? j
  await fetchUpdateMenu(a.id, { sort: sortB })
  await fetchUpdateMenu(b.id, { sort: sortA })
  getMenuList()
}

// 缩进：变成上一个菜单的子菜单
const indent = async (index: number) => {
  if (index === 0) return
  const prev = flatList.value[index - 1]
  const current = flatList.value[index]
  if (prev._level > current._level) return // 只能缩进到同级或上级
  await fetchUpdateMenu(current.id, { parentId: prev.id, sort: 0 })
  ElMessage.success(`"${current.meta?.title || current.name}" 已变为 "${prev.meta?.title || prev.name}" 的子菜单`)
  getMenuList()
}

// 升级：移出父菜单变成同级
const outdent = async (index: number) => {
  const current = flatList.value[index]
  if (current._level === 0) return
  // 找到父菜单的父菜单
  let grandparent: number | null = null
  for (let i = index - 1; i >= 0; i--) {
    if (flatList.value[i].id === current._parentId) {
      grandparent = flatList.value[i]._parentId
      break
    }
  }
  await fetchUpdateMenu(current.id, { parentId: grandparent, sort: 0 })
  ElMessage.success(`"${current.meta?.title || current.name}" 已升级`)
  getMenuList()
}

onMounted(() => getMenuList())
</script>

<style scoped lang="scss">
.menu-list {
  border: 1px solid #f0f0f0;
  border-radius: 8px;
}

.menu-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  border-bottom: 1px solid #f5f5f5;
  transition: background 0.15s;

  &:hover {
    background: #f9fafb;
  }

  &:last-child { border-bottom: none; }
}

.menu-sort-btns {
  display: flex;
  gap: 0;

  .el-button { padding: 2px 4px; font-size: 14px; }
}

.menu-icon {
  width: 24px;
  text-align: center;
  color: var(--el-color-primary);
}

.menu-title {
  flex: 1;
  font-size: 14px;
  font-weight: 500;
  min-width: 80px;
}

.menu-path {
  font-size: 12px;
  color: #999;
  font-family: monospace;
}

.menu-actions {
  display: flex;
  gap: 2px;
  flex-shrink: 0;
}
</style>
