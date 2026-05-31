<template>
  <div class="dep-page">
    <ElTabs v-model="depType" @tab-change="onTypeChange">
      <ElTabPane label="NodeJs" name="nodejs" />
      <ElTabPane label="Python3" name="python3" />
      <ElTabPane label="Linux" name="linux" />
    </ElTabs>

    <div class="toolbar">
      <ElInput v-model="searchText" placeholder="请输入名称" clearable style="width:200px" @change="loadData" />
      <ElButton type="primary" @click="showAddDialog">创建依赖</ElButton>
    </div>

    <div v-if="selectedIds.length" class="batch-bar">
      <ElButton size="small" @click="batchReinstall">批量安装</ElButton>
      <ElButton size="small" @click="batchRemove">批量删除</ElButton>
      <ElButton size="small" @click="batchForceRemove">批量强制删除</ElButton>
      <span class="ml-2">已选择 <b>{{ selectedIds.length }}</b> 项</span>
    </div>

    <ElTable :data="depList" v-loading="loading" stripe empty-text="暂无依赖" @selection-change="onSelectChange">
      <ElTableColumn type="selection" width="40" />
      <ElTableColumn label="序号" width="70">
        <template #default="{ $index }">{{ $index + 1 }}</template>
      </ElTableColumn>
      <ElTableColumn prop="name" label="名称" min-width="140" />
      <ElTableColumn label="状态" width="110">
        <template #default="{ row }">
          <span :style="{ color: statusColorMap[row.status] || '#999' }">{{ statusLabel(row.status) }}</span>
        </template>
      </ElTableColumn>
      <ElTableColumn prop="remark" label="备注" min-width="100" />
      <ElTableColumn label="更新时间" width="160">
        <template #default="{ row }">{{ formatTime(row.updatedAt) }}</template>
      </ElTableColumn>
      <ElTableColumn label="创建时间" width="160">
        <template #default="{ row }">{{ formatTime(row.createdAt) }}</template>
      </ElTableColumn>
      <ElTableColumn label="操作" width="200">
        <template #default="{ row }">
          <span style="display:inline-flex;gap:4px">
            <ElButton v-show="row.status != 6 && row.status != 7" size="small" type="primary" plain @click="openLog(row)">日志</ElButton>
            <template v-if="row.status === 0 || row.status === 3 || row.status === 6">
              <ElButton size="small" type="warning" @click="cancelDep(row)">取消安装</ElButton>
            </template>
            <template v-else>
              <ElButton size="small" @click="reinstall(row)">重新安装</ElButton>
              <ElButton v-show="row.status === 1" size="small" type="danger" @click="removeDep(row)">删除</ElButton>
              <ElButton size="small" type="danger" @click="forceRemove(row)">强制删除</ElButton>
            </template>
          </span>
        </template>
      </ElTableColumn>
    </ElTable>

    <ElDialog v-model="dialogVisible" title="创建依赖" width="420px">
      <ElForm ref="depFormRef" :model="depForm" :rules="depRules" label-width="60px">
        <ElFormItem label="类型" prop="type">
          <ElRadioGroup v-model="depForm.type">
            <ElRadio label="nodejs">NodeJs</ElRadio>
            <ElRadio label="python3">Python3</ElRadio>
            <ElRadio label="linux">Linux</ElRadio>
          </ElRadioGroup>
        </ElFormItem>
        <ElFormItem label="名称" prop="name">
          <ElInput v-model="depForm.name" placeholder="请输入名称" />
        </ElFormItem>
        <ElFormItem label="备注">
          <ElInput v-model="depForm.remark" placeholder="可选" />
        </ElFormItem>
      </ElForm>
      <template #footer>
        <ElButton @click="dialogVisible=false">取消</ElButton>
        <ElButton type="primary" @click="handleAddDep" :loading="depSaving">确定</ElButton>
      </template>
    </ElDialog>

    <ElDialog v-model="logVisible" :title="'日志 - ' + (logDepName || '')" width="700px" top="5vh">
      <div class="log-viewer">
        <div v-if="logLines.length === 0" style="text-align:center;color:#999;padding:40px">暂无日志</div>
        <pre v-else>{{ logLines.join('\n') }}</pre>
      </div>
    </ElDialog>
  </div>
</template>

<script setup lang="ts">
import request from '@/utils/http'
import { ElMessage, ElMessageBox } from 'element-plus'

defineOptions({ name: 'QlDependence' })

const statusLabel = (s: number) => ['安装中','已安装','安装失败','删除中','已删除','删除失败','队列中','已取消'][s] ?? s
const statusColorMap: Record<number, string> = { 0:'#e6a23c', 1:'#67c23a', 2:'#f56c6c', 3:'#e6a23c', 4:'#67c23a', 5:'#f56c6c', 6:'#909399', 7:'#909399' }
const formatTime = (t: string) => {
  if (!t) return '-'
  const d = new Date(t), p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth()+1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`
}

const loading = ref(false)
const depType = ref('nodejs')
const searchText = ref('')
const depList = ref<any[]>([])
const selectedIds = ref<number[]>([])
const loadData = async () => {
  loading.value = true
  try {
    // type 必须是字符串: nodejs / python3 / linux
    const res = await request.get<any>({ url: '/api/dependencies', params: { searchValue: searchText.value, type: depType.value } })
    depList.value = Array.isArray(res) ? res : []
    // WebSocket 实时更新，不再轮询
  } catch (e) { console.error(e); depList.value = [] }
  finally { loading.value = false }
}

const onTypeChange = () => { selectedIds.value = []; loadData() }
const onSelectChange = (rows: any[]) => { selectedIds.value = rows.map((r: any) => r.id) }

// 创建
const dialogVisible = ref(false)
const depSaving = ref(false)
const depFormRef = ref()
const depForm = reactive({ type: 'nodejs', name: '', remark: '' })
const depRules = { type: [{ required: true, message: '请选择类型', trigger: 'change' }], name: [{ required: true, message: '请输入名称', trigger: 'blur' }] }

const showAddDialog = () => { depForm.type = depType.value; depForm.name = ''; depForm.remark = ''; depFormRef.value?.clearValidate(); dialogVisible.value = true }
const handleAddDep = async () => {
  if (!depFormRef.value) return
  try { await depFormRef.value.validate() } catch { return }
  depSaving.value = true
  try { await request.post({ url: '/api/dependencies', data: [{ name: depForm.name, type: ({nodejs:0,python3:1,linux:2} as any)[depForm.type], remark: depForm.remark || '' }] }); dialogVisible.value = false; ElMessage.success('创建成功'); loadData() }
  catch (e: any) { ElMessage.error(e?.message || '创建失败') }
  finally { depSaving.value = false }
}

// 日志
const logVisible = ref(false); const logLines = ref<string[]>([]); const logDepName = ref('')
const openLog = async (row: any) => {
  logDepName.value = row.name || ''; logVisible.value = true; logLines.value = []
  try { const r = await request.get<any>({ url: `/api/dependencies/${row.id}` }); logLines.value = (Array.isArray(r?.log) ? r.log : []).map((l: string) => l.replace(/\x1b\[[\d;]*m/g, '')) } catch { logLines.value = [] }
}

// 操作
const c = (msg: string, t: string) => ElMessageBox.confirm(msg, t, { type: 'warning' })
const reinstall = (row: any) => c(`确认重新安装 "${row.name}"？`, '重新安装').then(() => request.put({ url: '/api/dependencies/reinstall', data: [row.id] }).then(() => { ElMessage.success('开始重装'); loadData() })).catch(() => {})
const cancelDep = (row: any) => c(`确认取消安装 "${row.name}"？`, '取消安装').then(() => request.put({ url: '/api/dependencies/cancel', data: [row.id] }).then(() => { ElMessage.success('已取消'); loadData() })).catch(() => {})
const removeDep = (row: any) => c(`确认删除 "${row.name}"？`, '删除').then(() => request.del({ url: '/api/dependencies', data: [row.id] }).then(() => { ElMessage.success('已删除'); loadData() })).catch(() => {})
const forceRemove = (row: any) => c(`确认强制删除 "${row.name}"？`, '强制删除').then(() => request.del({ url: '/api/dependencies/force', data: [row.id] }).then(() => loadData())).catch(() => {})
const batchReinstall = () => c('确认重新安装选中依赖？', '确认').then(() => request.put({ url: '/api/dependencies/reinstall', data: selectedIds.value }).then(() => { selectedIds.value = []; loadData() })).catch(() => {})
const batchRemove = () => c('确认删除选中依赖？', '确认').then(() => request.del({ url: '/api/dependencies', data: selectedIds.value }).then(() => { selectedIds.value = []; loadData() })).catch(() => {})
const batchForceRemove = () => c('确认强制删除选中依赖？', '确认').then(() => request.del({ url: '/api/dependencies/force', data: selectedIds.value }).then(() => { selectedIds.value = []; loadData() })).catch(() => {})

// WebSocket 实时更新依赖状态
const handleWSMessage = (msg: any) => {
  const { message, references } = msg
  let status: number | undefined
  if (message?.includes('开始时间') && references?.length > 0) {
    status = message.includes('安装') ? 0 /*安装中*/ : 3 /*删除中*/
  }
  if (message?.includes('结束时间') && references?.length > 0) {
    if (message.includes('安装')) status = message.includes('成功') ? 1 : 2
    else status = message.includes('成功') ? 4 : 5
    if (status === 4) {
      setTimeout(() => {
        depList.value = depList.value.filter(d => !references.includes(d.id))
      }, 300)
      return
    }
  }
  if (typeof status === 'number') {
    depList.value = depList.value.map(d =>
      references.includes(d.id) ? { ...d, status } : d
    )
  }
}

let wsManager: any = null

onMounted(async () => {
  loadData()
  // WebSocket 动态导入，失败不影响页面
  try {
    const mod = await import('@/utils/websocket')
    wsManager = mod.default.getInstance()
    wsManager.connect()
    wsManager.subscribe('installDependence', handleWSMessage)
    wsManager.subscribe('uninstallDependence', handleWSMessage)
  } catch (e) { console.warn('WebSocket 不可用:', e) }
})
onUnmounted(() => {
  if (wsManager) {
    wsManager.unsubscribe('installDependence', handleWSMessage)
    wsManager.unsubscribe('uninstallDependence', handleWSMessage)
  }
})
</script>

<style scoped>
.toolbar { display: flex; align-items: center; gap: 12px; margin: 12px 0; }
.batch-bar { background: #e8f0fe; border: 1px solid #b3d4fc; border-radius: 6px; padding: 8px 12px; margin-bottom: 10px; display: flex; align-items: center; gap: 6px; }
.log-viewer { background: #1e1e1e; color: #d4d4d4; border-radius: 6px; padding: 12px; max-height: 500px; overflow: auto; }
.log-viewer pre { margin: 0; font-family: Consolas, monospace; font-size: 13px; line-height: 1.5; white-space: pre-wrap; word-break: break-all; }
</style>
@media (max-width: 768px) {
  .toolbar { flex-wrap: wrap; gap: 6px; }
  .toolbar .el-input { width: 100% !important; }
  .el-radio-group { flex-wrap: wrap; }
}
