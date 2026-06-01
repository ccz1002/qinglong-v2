<template>
  <div class="ql-page">
    <ElTabs v-model="depType" @tab-change="onTypeChange" class="ql-tabs">
      <ElTabPane label="NodeJs" name="nodejs" />
      <ElTabPane label="Python3" name="python3" />
      <ElTabPane label="Linux" name="linux" />
    </ElTabs>

    <div class="ql-toolbar">
      <div class="ql-toolbar-left">
        <ElInput v-model="searchText" placeholder="搜索依赖名称" clearable style="width:220px" @change="loadData">
          <template #prefix><ArtSvgIcon icon="ri:search-line" class="text-g-400" /></template>
        </ElInput>
        <ElButton type="primary" @click="showAddDialog"><ArtSvgIcon icon="ri:add-line" class="mr-1" />创建依赖</ElButton>
      </div>
      <span class="text-sm text-g-400">{{ depList.length }} 个依赖</span>
    </div>

    <div v-if="selectedIds.length" class="ql-batch-bar">
      <ArtSvgIcon icon="ri:checkbox-multiple-line" class="text-sm text-primary" />
      <span class="text-sm font-medium">已选 {{ selectedIds.length }} 项</span>
      <ElDivider direction="vertical" />
      <ElButton size="small" @click="batchReinstall">批量安装</ElButton>
      <ElButton size="small" @click="batchRemove">批量删除</ElButton>
      <ElButton size="small" type="danger" plain @click="batchForceRemove">强制删除</ElButton>
    </div>

    <div class="art-card">
      <ElTable :data="depList" v-loading="loading" stripe size="small" empty-text="暂无依赖" @selection-change="onSelectChange">
        <ElTableColumn type="selection" width="36" />
        <ElTableColumn label="#" width="50" align="center">
          <template #default="{ $index }"><span class="text-g-400 text-sm">{{ $index + 1 }}</span></template>
        </ElTableColumn>
        <ElTableColumn label="名称" min-width="160">
          <template #default="{ row }"><span class="font-medium">{{ row.name }}</span></template>
        </ElTableColumn>
        <ElTableColumn label="状态" width="110" align="center">
          <template #default="{ row }">
            <ElTag size="small" effect="plain" :type="statusTagType(row.status)">{{ statusLabel(row.status) }}</ElTag>
          </template>
        </ElTableColumn>
        <ElTableColumn prop="remark" label="备注" min-width="120">
          <template #default="{ row }"><span class="text-g-500 text-sm">{{ row.remark || '-' }}</span></template>
        </ElTableColumn>
        <ElTableColumn label="更新时间" width="160">
          <template #default="{ row }"><span class="text-sm text-g-500">{{ formatTime(row.updatedAt) }}</span></template>
        </ElTableColumn>
        <ElTableColumn label="创建时间" width="160">
          <template #default="{ row }"><span class="text-sm text-g-500">{{ formatTime(row.createdAt) }}</span></template>
        </ElTableColumn>
        <ElTableColumn label="操作" width="220" fixed="right">
          <template #default="{ row }">
            <ElButton v-show="row.status !== 6 && row.status !== 7" size="small" @click="openLog(row)">
              <ArtSvgIcon icon="ri:file-text-line" class="mr-1" />日志
            </ElButton>
            <template v-if="row.status === 0 || row.status === 3 || row.status === 6">
              <ElButton size="small" type="warning" plain @click="cancelDep(row)">取消</ElButton>
            </template>
            <template v-else>
              <ElButton size="small" @click="reinstall(row)">重装</ElButton>
              <ElButton v-show="row.status === 1" size="small" type="danger" plain @click="removeDep(row)">
                <ArtSvgIcon icon="ri:delete-bin-line" />
              </ElButton>
              <ElButton size="small" type="danger" plain @click="forceRemove(row)">强制删</ElButton>
            </template>
          </template>
        </ElTableColumn>
      </ElTable>
    </div>

    <ElDialog v-model="dialogVisible" title="创建依赖" width="420px">
      <ElForm ref="depFormRef" :model="depForm" :rules="depRules" label-width="50px">
        <ElFormItem label="类型" prop="type">
          <ElRadioGroup v-model="depForm.type">
            <ElRadio label="nodejs">NodeJs</ElRadio>
            <ElRadio label="python3">Python3</ElRadio>
            <ElRadio label="linux">Linux</ElRadio>
          </ElRadioGroup>
        </ElFormItem>
        <ElFormItem label="名称" prop="name"><ElInput v-model="depForm.name" placeholder="依赖名称" /></ElFormItem>
        <ElFormItem label="备注"><ElInput v-model="depForm.remark" placeholder="可选" /></ElFormItem>
      </ElForm>
      <template #footer>
        <ElButton @click="dialogVisible = false">取消</ElButton>
        <ElButton type="primary" @click="handleAddDep" :loading="depSaving">确定</ElButton>
      </template>
    </ElDialog>

    <ElDialog v-model="logVisible" :title="'日志 - ' + (logDepName || '')" width="700px" top="5vh">
      <div class="ql-log-viewer">
        <div v-if="logLines.length === 0" class="text-center text-g-400 py-10">暂无日志</div>
        <pre v-else>{{ logLines.join('\n') }}</pre>
      </div>
    </ElDialog>
  </div>
</template>

<script setup lang="ts">
import request from '@/utils/http'
import { ElMessage, ElMessageBox } from 'element-plus'

defineOptions({ name: 'QlDependence' })

const statusLabel = (s: number) => ['安装中', '已安装', '安装失败', '删除中', '已删除', '删除失败', '队列中', '已取消'][s] ?? s
const statusTagType = (s: number) => [0, 3].includes(s) ? 'warning' : [1, 4].includes(s) ? 'success' : [2, 5].includes(s) ? 'danger' : 'info'
const formatTime = (t: string) => {
  if (!t) return '-'
  const d = new Date(t), p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`
}

const loading = ref(false); const depType = ref('nodejs'); const searchText = ref('')
const depList = ref<any[]>([]); const selectedIds = ref<number[]>([])

const loadData = async () => {
  loading.value = true
  try {
    const res = await request.get<any>({ url: '/api/dependencies', params: { searchValue: searchText.value, type: depType.value } })
    depList.value = Array.isArray(res) ? res : []
  } catch (e) { console.error(e); depList.value = [] }
  finally { loading.value = false }
}
const onTypeChange = () => { selectedIds.value = []; loadData() }
const onSelectChange = (rows: any[]) => { selectedIds.value = rows.map((r: any) => r.id) }

const dialogVisible = ref(false); const depSaving = ref(false); const depFormRef = ref()
const depForm = reactive({ type: 'nodejs', name: '', remark: '' })
const depRules = { type: [{ required: true, message: '请选择类型', trigger: 'change' }], name: [{ required: true, message: '请输入名称', trigger: 'blur' }] }

const showAddDialog = () => { depForm.type = depType.value; depForm.name = ''; depForm.remark = ''; depFormRef.value?.clearValidate(); dialogVisible.value = true }
const handleAddDep = async () => {
  if (!depFormRef.value) return
  try { await depFormRef.value.validate() } catch { return }
  depSaving.value = true
  try { await request.post({ url: '/api/dependencies', data: [{ name: depForm.name, type: ({ nodejs: 0, python3: 1, linux: 2 } as any)[depForm.type], remark: depForm.remark || '' }] }); dialogVisible.value = false; ElMessage.success('创建成功'); loadData() }
  catch (e: any) { ElMessage.error(e?.message || '创建失败') }
  finally { depSaving.value = false }
}

const logVisible = ref(false); const logLines = ref<string[]>([]); const logDepName = ref('')
const openLog = async (row: any) => {
  logDepName.value = row.name || ''; logVisible.value = true; logLines.value = []
  try { const r = await request.get<any>({ url: `/api/dependencies/${row.id}` }); logLines.value = (Array.isArray(r?.log) ? r.log : []).map((l: string) => l.replace(/\x1b\[[\d;]*m/g, '')) } catch { logLines.value = [] }
}

const c = (msg: string, t: string) => ElMessageBox.confirm(msg, t, { type: 'warning' })
const reinstall = (row: any) => c(`确认重新安装 "${row.name}"？`, '重装').then(() => request.put({ url: '/api/dependencies/reinstall', data: [row.id] }).then(() => { ElMessage.success('开始重装'); loadData() })).catch(() => { })
const cancelDep = (row: any) => c(`确认取消安装 "${row.name}"？`, '取消').then(() => request.put({ url: '/api/dependencies/cancel', data: [row.id] }).then(() => { ElMessage.success('已取消'); loadData() })).catch(() => { })
const removeDep = (row: any) => c(`确认删除 "${row.name}"？`, '删除').then(() => request.del({ url: '/api/dependencies', data: [row.id] }).then(() => { ElMessage.success('已删除'); loadData() })).catch(() => { })
const forceRemove = (row: any) => c(`确认强制删除 "${row.name}"？`, '强制删除').then(() => request.del({ url: '/api/dependencies/force', data: [row.id] }).then(() => loadData())).catch(() => { })
const batchReinstall = () => c('确认重装选中依赖？', '确认').then(() => request.put({ url: '/api/dependencies/reinstall', data: selectedIds.value }).then(() => { selectedIds.value = []; loadData() })).catch(() => { })
const batchRemove = () => c('确认删除选中依赖？', '确认').then(() => request.del({ url: '/api/dependencies', data: selectedIds.value }).then(() => { selectedIds.value = []; loadData() })).catch(() => { })
const batchForceRemove = () => c('确认强制删除选中依赖？', '确认').then(() => request.del({ url: '/api/dependencies/force', data: selectedIds.value }).then(() => { selectedIds.value = []; loadData() })).catch(() => { })

const handleWSMessage = (msg: any) => {
  const { message, references } = msg
  let status: number | undefined
  if (message?.includes('开始时间') && references?.length > 0) status = message.includes('安装') ? 0 : 3
  if (message?.includes('结束时间') && references?.length > 0) {
    if (message.includes('安装')) status = message.includes('成功') ? 1 : 2
    else status = message.includes('成功') ? 4 : 5
    if (status === 4) { setTimeout(() => { depList.value = depList.value.filter(d => !references.includes(d.id)) }, 300); return }
  }
  if (typeof status === 'number') depList.value = depList.value.map(d => references.includes(d.id) ? { ...d, status } : d)
}

let wsManager: any = null
onMounted(async () => {
  loadData()
  try { const mod = await import('@/utils/websocket'); wsManager = mod.default.getInstance(); wsManager.connect(); wsManager.subscribe('installDependence', handleWSMessage); wsManager.subscribe('uninstallDependence', handleWSMessage) } catch (e) { console.warn('WebSocket 不可用:', e) }
})
onUnmounted(() => {
  if (wsManager) { wsManager.unsubscribe('installDependence', handleWSMessage); wsManager.unsubscribe('uninstallDependence', handleWSMessage) }
})
</script>

<style scoped>
.ql-page { display: flex; flex-direction: column; gap: 10px; }
.ql-tabs :deep(.el-tabs__header) { margin-bottom: 0; }
.ql-toolbar { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 10px; }
.ql-toolbar-left { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
.ql-batch-bar {
  display: flex; align-items: center; gap: 6px;
  background: var(--el-color-primary-light-9, #ecf5ff);
  border: 1px solid var(--el-color-primary-light-7, #b3d4fc);
  border-radius: 8px; padding: 8px 14px;
}
.ql-log-viewer {
  background: #1e1e1e; color: #d4d4d4; border-radius: 8px;
  padding: 14px; max-height: 500px; overflow: auto;
}
.ql-log-viewer pre { margin: 0; font-family: 'Consolas', 'Courier New', monospace; font-size: 13px; line-height: 1.5; white-space: pre-wrap; word-break: break-all; }
@media (max-width: 768px) {
  .ql-toolbar { flex-direction: column; align-items: flex-start; }
  .ql-toolbar-left { flex-wrap: wrap; }
  .ql-toolbar-left .el-input { width: 100% !important; }
}
</style>
