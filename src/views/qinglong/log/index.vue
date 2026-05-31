<template>
  <div class="log-page flex h-full gap-4">
    <ElCard class="log-tree" style="width:280px;flex-shrink:0">
      <template #header><span>日志目录</span></template>
      <ElTree
        :data="treeData"
        :props="{ children: 'children', label: 'name' }"
        node-key="path"
        highlight-current
        @node-click="(node: any) => openFile(node.path)"
        :filter-node-method="filterTree"
        default-expand-all
      >
        <template #default="{ node }">
          <span>{{ node.label }}</span>
        </template>
      </ElTree>
    </ElCard>

    <ElCard class="flex-1 flex flex-col">
      <template #header>
        <div class="flex items-center justify-between">
          <span>{{ currentFile || '请选择日志文件' }}</span>
          <ElButton v-if="currentFile" size="small" type="danger" @click="handleDelete">删除</ElButton>
        </div>
      </template>
      <div class="log-content" v-if="currentFile">
        <pre>{{ logContent }}</pre>
      </div>
      <ElEmpty v-else description="选择左侧文件查看日志" />
    </ElCard>
  </div>
</template>

<script setup lang="ts">
import { qlLogApi } from '@/api/modules/qinglong'
import { ElMessage, ElMessageBox } from 'element-plus'

defineOptions({ name: 'QlLog' })

const treeData = ref<any[]>([])
const currentFile = ref('')
const logContent = ref('')

const buildTree = (data: any): any[] => {
  if (!data) return []
  if (Array.isArray(data)) {
    return data.map((item: any) => ({
      name: item.name || item,
      path: item.path || item,
      children: item.children ? buildTree(item.children) : undefined
    }))
  }
  return Object.entries(data).map(([key, val]: [string, any]) => ({
    name: key,
    path: val.path || key,
    children: typeof val === 'object' && !Array.isArray(val) ? buildTree(val) : undefined
  }))
}

const filterTree = (value: string, data: any) => {
  if (!value) return true
  return data.name?.toLowerCase().includes(value.toLowerCase())
}

const openFile = async (path: string) => {
  if (!path) return
  currentFile.value = path
  try {
    const res = await qlLogApi.detail(path)
    logContent.value = typeof res === 'string' ? res : res?.content || res?.data || JSON.stringify(res)
  } catch (e: any) {
    logContent.value = '加载失败: ' + (e?.message || '')
  }
}

const handleDelete = async () => {
  try {
    await ElMessageBox.confirm(`确定删除 "${currentFile.value}"？`, '警告', { type: 'warning' })
    await qlLogApi.remove(currentFile.value)
    ElMessage.success('已删除')
    currentFile.value = ''
    logContent.value = ''
    loadTree()
  } catch {}
}

const loadTree = async () => {
  const res = await qlLogApi.list()
  treeData.value = buildTree(res)
}

onMounted(loadTree)
</script>

<style scoped>
.log-content {
  flex: 1;
  overflow: auto;
  background: #1e1e1e;
  color: #d4d4d4;
  padding: 12px;
  border-radius: 6px;
}
.log-content pre {
  margin: 0;
  font-family: 'Consolas', 'Courier New', monospace;
  font-size: 13px;
  line-height: 1.5;
  white-space: pre-wrap;
}
</style>
