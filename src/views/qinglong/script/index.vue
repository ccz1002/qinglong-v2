<template>
  <div class="ql-script-page">
    <!-- 工具栏 -->
    <div class="ql-script-toolbar">
      <div class="flex items-center gap-2 flex-1 min-w-0">
        <ArtSvgIcon icon="ri:code-box-line" class="text-lg text-primary" />
        <span class="font-medium truncate">{{ currentFile || '脚本管理' }}</span>
        <span v-if="currentNode?.size" class="text-xs text-g-400">{{ formatSize(currentNode.size) }}</span>
      </div>
      <div class="flex items-center gap-1.5 flex-shrink-0">
        <template v-if="isEditing">
          <ElButton type="primary" size="small" @click="saveFile"><ArtSvgIcon icon="ri:save-line" class="mr-1" />保存</ElButton>
          <ElButton size="small" @click="cancelEdit">退出编辑</ElButton>
        </template>
        <template v-else>
          <ElButton size="small" @click="addFile"><ArtSvgIcon icon="ri:add-line" class="mr-1" />创建</ElButton>
          <ElButton size="small" :disabled="!currentNode" @click="editFile"><ArtSvgIcon icon="ri:edit-line" class="mr-1" />编辑</ElButton>
          <ElButton size="small" :disabled="!currentNode" @click="renameFile"><ArtSvgIcon icon="ri:edit-2-line" class="mr-1" />重命名</ElButton>
          <ElButton size="small" :disabled="!currentNode || currentNode.type === 'directory'" @click="downloadFile"><ArtSvgIcon icon="ri:download-2-line" class="mr-1" />下载</ElButton>
          <ElButton size="small" :disabled="!currentNode" type="danger" plain @click="deleteFile"><ArtSvgIcon icon="ri:delete-bin-line" /></ElButton>
        </template>
      </div>
    </div>

    <!-- 主体 -->
    <div class="ql-script-body">
      <div class="ql-script-tree">
        <div class="p-2">
          <ElInput v-model="searchText" placeholder="搜索脚本名" size="small" clearable>
            <template #prefix><ArtSvgIcon icon="ri:search-line" class="text-g-400" /></template>
          </ElInput>
        </div>
        <ElTree
          :data="filteredTree"
          :props="{ children: 'children', label: 'title' }"
          node-key="key"
          highlight-current
          @node-click="onNodeClick"
          @node-dblclick="(n: any) => n.type === 'file' && (currentNode = n, currentFile = n.title, isEditing = true, loadContent(n))"
          :default-expanded-keys="expandedKeys"
        />
      </div>

      <div class="ql-script-editor">
        <div v-if="!currentFile" class="flex-cc h-full text-g-400 flex-col gap-3">
          <ArtSvgIcon icon="ri:code-line" class="text-5xl opacity-30" />
          <span>请选择脚本文件</span>
        </div>
        <div v-else-if="!canPreview" class="flex-cc h-full text-g-400 flex-col gap-3">
          <ArtSvgIcon icon="ri:file-warning-line" class="text-4xl opacity-30" />
          <p>不支持预览此文件类型</p>
          <ElButton size="small" @click="canPreview = true; loadContent(currentNode)">强制打开</ElButton>
        </div>
        <VueMonacoEditor
          v-else
          v-model:value="content"
          :language="editorLang"
          :theme="editorTheme"
          :options="editorOpts"
          height="100%"
          @mount="onEditorMount"
        />
      </div>
    </div>

    <!-- 创建弹窗 -->
    <ElDialog v-model="createVisible" title="创建" width="450px">
      <ElForm label-width="70px">
        <ElFormItem label="类型">
          <ElRadioGroup v-model="createType">
            <ElRadio label="blank">空文件</ElRadio>
            <ElRadio label="upload">上传文件</ElRadio>
            <ElRadio label="directory">文件夹</ElRadio>
          </ElRadioGroup>
        </ElFormItem>
        <ElFormItem v-if="createType === 'blank'" label="文件名"><ElInput v-model="createName" placeholder="example.js" /></ElFormItem>
        <ElFormItem v-if="createType === 'upload'" label="选择文件"><input type="file" ref="fileInputRef" @change="onFilePicked" /></ElFormItem>
        <ElFormItem v-if="createType === 'directory'" label="文件夹名"><ElInput v-model="createDir" placeholder="mydir" /></ElFormItem>
        <ElFormItem label="父目录">
          <ElTreeSelect v-model="createPath" :data="dirTree" :props="{ children: 'children', label: 'title', value: 'key' }" placeholder="根目录" check-strictly clearable />
        </ElFormItem>
      </ElForm>
      <template #footer><ElButton @click="createVisible = false">取消</ElButton><ElButton type="primary" @click="doCreate" :loading="opLoading">确定</ElButton></template>
    </ElDialog>

    <!-- 重命名弹窗 -->
    <ElDialog v-model="renameVisible" title="重命名" width="400px">
      <ElFormItem label="新名称"><ElInput v-model="renameNewName" /></ElFormItem>
      <template #footer><ElButton @click="renameVisible = false">取消</ElButton><ElButton type="primary" @click="doRename" :loading="opLoading">确定</ElButton></template>
    </ElDialog>
  </div>
</template>

<script setup lang="ts">
import request from '@/utils/http'
import { ElMessage, ElMessageBox } from 'element-plus'
import { VueMonacoEditor } from '@guolao/vue-monaco-editor'

defineOptions({ name: 'QlScript' })

const editorLang = computed(() => {
  const name = currentNode.value?.title || ''
  const ext = name.split('.').pop()?.toLowerCase()
  const map: Record<string, string> = { js: 'javascript', ts: 'typescript', py: 'python', sh: 'shell', json: 'json', md: 'markdown', html: 'html', css: 'css', yml: 'yaml', yaml: 'yaml', xml: 'xml', sql: 'sql', go: 'go', rs: 'rust', java: 'java', c: 'c', cpp: 'cpp', php: 'php', rb: 'ruby', swift: 'swift', kt: 'kotlin', vue: 'html', lua: 'lua', ini: 'ini', toml: 'toml', bat: 'bat', ps1: 'powershell', dockerfile: 'dockerfile' }
  return map[ext || ''] || 'plaintext'
})
const editorTheme = ref('vs'); const editorRef = ref<any>(null)
const editorOpts = computed(() => ({ readOnly: !isEditing.value, fontSize: 13, minimap: { enabled: false }, lineNumbersMinChars: 3, scrollBeyondLastLine: false, automaticLayout: true }))
const onEditorMount = (editor: any) => { editorRef.value = editor }

const treeData = ref<any[]>([]); const searchText = ref(''); const currentNode = ref<any>(null)
const currentFile = ref(''); const content = ref(''); const originalContent = ref('')
const isEditing = ref(false); const canPreview = ref(true); const expandedKeys = ref<string[]>([]); const opLoading = ref(false)

const filteredTree = computed(() => {
  if (!searchText.value) return treeData.value
  const filter = (items: any[]): any[] => items.reduce((acc: any[], item: any) => {
    const match = item.title?.toLowerCase().includes(searchText.value.toLowerCase())
    const filteredChildren = item.children ? filter(item.children) : []
    if (match || filteredChildren.length) acc.push({ ...item, children: filteredChildren.length ? filteredChildren : item.children })
    return acc
  }, [])
  return filter(treeData.value)
})

const dirTree = computed(() => {
  const filter = (items: any[]): any[] => items.filter(x => x.type === 'directory').map(x => ({ ...x, children: filter(x.children || []) }))
  return filter(treeData.value)
})

const loadTree = async () => { try { treeData.value = await request.get<any>({ url: '/api/scripts' }) || [] } catch { } }

const loadContent = async (node: any) => {
  try {
    const file = node.title || node.name || node.label || ''
    const parentPath = node.parent || ''
    const data = await request.get<any>({ url: '/api/scripts/detail', params: { file, path: parentPath } })
    content.value = typeof data === 'string' ? data : data?.content || data || ''
    originalContent.value = content.value
  } catch (e) { content.value = '// 加载失败: ' + (e?.message || '未知错误') }
}

const onNodeClick = (node: any) => {
  currentNode.value = node; currentFile.value = node.title
  if (node.type === 'directory') { content.value = ''; return }
  if (!canPreviewFile(node.title)) { canPreview.value = false; return }
  canPreview.value = true; loadContent(node)
}

const editFile = () => { isEditing.value = true }
const cancelEdit = () => { isEditing.value = false; content.value = originalContent.value }

const saveFile = async () => {
  if (!currentNode.value) return
  try { await ElMessageBox.confirm(`确认保存 "${currentNode.value.title}"，保存后不可恢复`, '确认保存') } catch { return }
  opLoading.value = true
  try {
    const c = content.value.replace(/\r\n/g, '\n')
    await request.put({ url: '/api/scripts', data: { filename: currentNode.value.title, path: currentNode.value.parent || '', content: c } })
    ElMessage.success('保存成功'); originalContent.value = c; isEditing.value = false
  } catch (e: any) { ElMessage.error(e?.message || '保存失败') }
  finally { opLoading.value = false }
}

const createVisible = ref(false); const createType = ref('blank')
const createName = ref(''); const createDir = ref(''); const createPath = ref('')
const uploadFile = ref<File | null>(null); const fileInputRef = ref()

const addFile = () => { createType.value = 'blank'; createName.value = ''; createDir.value = ''; createPath.value = ''; uploadFile.value = null; createVisible.value = true }
const onFilePicked = (e: any) => { uploadFile.value = e.target.files?.[0] || null }

const doCreate = async () => {
  if (createType.value === 'upload') { if (!uploadFile.value) { ElMessage.warning('请选择文件'); return } }
  else { const fn = createType.value === 'directory' ? createDir.value : createName.value; if (!fn) { ElMessage.warning('请输入名称'); return } }
  opLoading.value = true
  try {
    if (createType.value === 'upload') {
      const content = await new Promise<string>((resolve, reject) => { const reader = new FileReader(); reader.onload = () => resolve(reader.result as string); reader.onerror = () => reject(new Error('读取文件失败')); reader.readAsText(uploadFile.value!) })
      const safeName = uploadFile.value!.name.replace(/^.*[/\\]/, '')
      const store = (await import('@/store/modules/user')).useUserStore()
      const resp = await fetch('/api/scripts', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: store.accessToken }, body: JSON.stringify({ filename: safeName, content, path: createPath.value || './' }) })
      const json = await resp.json(); if (json.code !== 200) throw new Error(json.message || '创建失败')
    } else {
      const fd = new FormData(); const store = (await import('@/store/modules/user')).useUserStore()
      if (createType.value === 'directory') { fd.append('directory', createDir.value) } else { fd.append('filename', createName.value); fd.append('content', '') }
      fd.append('path', createPath.value || './')
      const resp = await fetch('/api/scripts', { method: 'POST', headers: { Authorization: store.accessToken }, body: fd })
      const json = await resp.json(); if (json.code !== 200) throw new Error(json.message || '创建失败')
    }
    ElMessage.success('创建成功'); createVisible.value = false; loadTree()
  } catch (e: any) { ElMessage.error(e?.message || '创建失败') }
  finally { opLoading.value = false }
}

const renameVisible = ref(false); const renameNewName = ref('')
const renameFile = () => { if (!currentNode.value) return; renameNewName.value = currentNode.value.title; renameVisible.value = true }
const doRename = async () => {
  if (!currentNode.value || !renameNewName.value) return
  opLoading.value = true
  try { await request.put({ url: '/api/scripts/rename', data: { filename: currentNode.value.title, path: currentNode.value.parent || '', newFilename: renameNewName.value } }); ElMessage.success('重命名成功'); renameVisible.value = false; loadTree() }
  catch (e: any) { ElMessage.error(e?.message || '重命名失败') }
  finally { opLoading.value = false }
}

const deleteFile = async () => {
  if (!currentNode.value) return
  const msg = currentNode.value.type === 'directory' ? `删除文件夹及所有子文件"${currentNode.value.title}"？` : `删除文件"${currentNode.value.title}"？`
  try { await ElMessageBox.confirm(msg, '确认删除', { type: 'warning', confirmButtonText: '删除' }) } catch { return }
  try { await request.del({ url: '/api/scripts', data: { filename: currentNode.value.title, path: currentNode.value.parent || '', type: currentNode.value.type } }); ElMessage.success('已删除'); currentFile.value = ''; currentNode.value = null; content.value = ''; loadTree() }
  catch (e: any) { ElMessage.error(e?.message || '删除失败') }
}

const downloadFile = async () => {
  if (!currentNode.value) return
  try {
    const store = (await import('@/store/modules/user')).useUserStore()
    const resp = await fetch('/api/scripts/download', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: store.accessToken }, body: JSON.stringify({ filename: currentNode.value.title, path: currentNode.value.parent || '' }) })
    if (!resp.ok) throw new Error('下载失败')
    const blob = await resp.blob(); const url = URL.createObjectURL(blob)
    const a = document.createElement('a'); a.href = url; a.download = currentNode.value.title; a.click(); URL.revokeObjectURL(url)
  } catch (e: any) { ElMessage.error('下载失败') }
}

const canPreviewFile = (name: string) => { const ext = name.split('.').pop()?.toLowerCase() || ''; return ['js', 'ts', 'py', 'sh', 'json', 'txt', 'md', 'css', 'html', 'xml', 'yaml', 'yml', 'ini', 'env', 'toml', 'sql', 'go', 'java', 'c', 'cpp', 'rs', 'rb', 'php', 'swift', 'kt', 'vue', 'less', 'scss', 'bat', 'ps1', 'conf', 'cfg', 'log'].includes(ext) }
const formatSize = (b: number) => b ? (b < 1024 ? b + ' B' : b < 1048576 ? (b / 1024).toFixed(1) + ' KB' : (b / 1048576).toFixed(1) + ' MB') : ''

onMounted(loadTree)
</script>

<style scoped>
.ql-script-page { height: 100%; display: flex; flex-direction: column; }
.ql-script-toolbar {
  display: flex; align-items: center; justify-content: space-between; gap: 8px;
  padding: 10px 14px; border-bottom: 1px solid var(--art-card-border, #eee);
  background: var(--art-bg-color, #fff); flex-shrink: 0;
}
.ql-script-body { flex: 1; display: flex; overflow: hidden; }
.ql-script-tree {
  width: 240px; flex-shrink: 0; border-right: 1px solid var(--art-card-border, #eee);
  display: flex; flex-direction: column; overflow: hidden; background: var(--art-bg-color, #fff);
}
.ql-script-tree :deep(.el-tree) { flex: 1; overflow: auto; padding: 4px 0; }
.ql-script-editor { flex: 1; overflow: hidden; }
@media (max-width: 768px) {
  .ql-script-body { flex-direction: column; }
  .ql-script-tree { width: 100%; max-height: 200px; border-right: none; border-bottom: 1px solid var(--art-card-border, #eee); }
  .ql-script-toolbar { flex-wrap: wrap; gap: 6px; }
}
</style>
