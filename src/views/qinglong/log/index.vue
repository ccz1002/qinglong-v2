<template>
  <div class="ql-log-page">
    <div class="ql-log-tree-panel art-card">
      <div class="ql-panel-header"><ArtSvgIcon icon="ri:folder-open-line" class="mr-2" />日志目录</div>
      <ElTree
        :data="treeData"
        :props="{ children: 'children', label: 'title' }"
        node-key="key"
        highlight-current
        @node-click="(node: any) => openFile(node)"
        :filter-node-method="filterTree"
        default-expand-all
      />
    </div>

    <div class="ql-log-viewer-panel art-card">
      <div class="ql-panel-header">
        <span class="flex items-center gap-2 truncate">
          <ArtSvgIcon icon="ri:file-text-line" class="flex-shrink-0" />
          <span class="truncate">{{ currentFile || '请选择日志文件' }}</span>
        </span>
        <ElButton v-if="currentFile" size="small" type="danger" plain @click="handleDelete">
          <ArtSvgIcon icon="ri:delete-bin-line" class="mr-1" />删除
        </ElButton>
      </div>
      <div v-if="currentFile" class="ql-log-content">
        <pre>{{ logContent }}</pre>
      </div>
      <div v-else class="flex-cc h-full text-g-400 flex-col gap-3">
        <ArtSvgIcon icon="ri:file-search-line" class="text-5xl opacity-30" />
        <span>选择左侧文件查看日志</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { qlLogApi } from '@/api/modules/qinglong'
import { ElMessage, ElMessageBox } from 'element-plus'
defineOptions({ name: 'QlLog' })

const treeData = ref<any[]>([]); const currentFile = ref(''); const logContent = ref('')

const buildTree = (data: any): any[] => {
  if (!data) return []
  if (Array.isArray(data)) {
    return data.map((item: any) => ({
      title: item.title || item.name || item,
      key: item.key || item.path || item,
      type: item.type, parent: item.parent || '',
      size: item.size, createTime: item.createTime,
      children: item.children ? buildTree(item.children) : undefined
    }))
  }
  return Object.entries(data).map(([k, v]: [string, any]) => ({
    title: v.title || k, key: v.key || k, type: v.type, parent: v.parent || '',
    children: typeof v === 'object' && !Array.isArray(v) ? buildTree(v) : undefined
  }))
}

const filterTree = (value: string, data: any) => { if (!value) return true; return data.title?.toLowerCase().includes(value.toLowerCase()) }

const openFile = async (node: any) => {
  if (!node || node.type === 'directory') return
  currentFile.value = node.title
  try { const res = await qlLogApi.detail(node.title, node.parent || ''); logContent.value = typeof res === 'string' ? res : res?.content || res?.data || JSON.stringify(res) }
  catch (e: any) { logContent.value = '加载失败: ' + (e?.message || '') }
}

const handleDelete = async () => {
  try {
    await ElMessageBox.confirm(`确定删除 "${currentFile.value}"？`, '警告', { type: 'warning' })
    const findNode = (nodes: any[]): any => {
      for (const n of nodes) { if (n.title === currentFile.value) return n; if (n.children) { const found = findNode(n.children); if (found) return found } }
      return null
    }
    const node = findNode(treeData.value)
    await qlLogApi.remove(currentFile.value, node?.parent || ''); ElMessage.success('已删除')
    currentFile.value = ''; logContent.value = ''; loadTree()
  } catch { }
}

const loadTree = async () => { const res = await qlLogApi.list(); treeData.value = buildTree(res) }

onMounted(loadTree)
</script>

<style scoped>
.ql-log-page { display: flex; gap: 12px; height: 100%; }
.ql-log-tree-panel { width: 260px; flex-shrink: 0; display: flex; flex-direction: column; overflow: hidden; }
.ql-log-tree-panel :deep(.el-tree) { flex: 1; overflow: auto; padding: 4px; }
.ql-log-viewer-panel { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
.ql-panel-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 10px 14px; border-bottom: 1px solid var(--art-card-border, #eee);
  font-size: 14px; font-weight: 500; flex-shrink: 0;
}
.ql-log-content { flex: 1; overflow: auto; }
.ql-log-content pre {
  margin: 0; padding: 14px; font-family: 'Consolas', 'Courier New', monospace;
  font-size: 13px; line-height: 1.5; white-space: pre-wrap; word-break: break-all;
  background: #1e1e1e; color: #d4d4d4; min-height: 100%;
}
@media (max-width: 768px) {
  .ql-log-page { flex-direction: column; }
  .ql-log-tree-panel { width: 100%; max-height: 220px; }
}
</style>
