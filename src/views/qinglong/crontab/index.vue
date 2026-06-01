<template>
  <div class="ql-page">
    <!-- 工具栏 -->
    <div class="ql-toolbar">
      <div class="ql-toolbar-left">
        <ElInput v-model="searchText" placeholder="搜索任务名称/命令" clearable style="width:260px" @change="loadData">
          <template #prefix><ArtSvgIcon icon="ri:search-line" class="text-g-400" /></template>
        </ElInput>
        <ElButton type="primary" @click="showEdit(null)"><ArtSvgIcon icon="ri:add-line" class="mr-1" />创建任务</ElButton>
        <ElButton @click="loadData" :loading="loading"><ArtSvgIcon icon="ri:refresh-line" class="mr-1" />刷新</ElButton>
      </div>
      <span class="text-sm text-g-400">{{ cronList.length }} 个任务</span>
    </div>

    <!-- 自定义视图 -->
    <div class="ql-view-tabs">
      <span
        v-for="v in views" :key="v.id"
        class="ql-view-tab" :class="{ active: activeView === v.id }"
        @click="switchView(v)"
      >
        <ArtSvgIcon v-if="v.type === 1" icon="ri:star-fill" class="text-xs mr-1" />
        {{ v.name }}
        <ElDropdown v-if="v.type !== 1" trigger="click" @command="(cmd: string) => viewAction(cmd, v)">
          <span class="ql-view-more" @click.stop><ArtSvgIcon icon="ri:more-fill" class="text-xs" /></span>
          <template #dropdown>
            <ElDropdownItem command="edit"><ArtSvgIcon icon="ri:edit-line" class="mr-1" />编辑</ElDropdownItem>
            <ElDropdownItem command="del"><ArtSvgIcon icon="ri:delete-bin-line" class="mr-1 text-danger" />删除</ElDropdownItem>
          </template>
        </ElDropdown>
      </span>
      <ElButton size="small" circle @click="showViewEdit(null)"><ArtSvgIcon icon="ri:add-line" /></ElButton>
    </div>

    <!-- 批量操作 -->
    <div v-if="selectedIds.length" class="ql-batch-bar">
      <ArtSvgIcon icon="ri:checkbox-multiple-line" class="text-sm text-primary" />
      <span class="text-sm font-medium">已选 {{ selectedIds.length }} 项</span>
      <ElDivider direction="vertical" />
      <ElButton size="small" @click="batchOp('run')"><ArtSvgIcon icon="ri:play-line" class="mr-1" />运行</ElButton>
      <ElButton size="small" @click="batchOp('stop')"><ArtSvgIcon icon="ri:stop-line" class="mr-1" />停止</ElButton>
      <ElButton size="small" @click="batchOp('enable')">启用</ElButton>
      <ElButton size="small" @click="batchOp('disable')">禁用</ElButton>
      <ElButton size="small" @click="batchOp('pin')">置顶</ElButton>
      <ElButton size="small" @click="batchOp('unpin')">取消置顶</ElButton>
      <ElDivider direction="vertical" />
      <ElButton size="small" type="danger" @click="batchDelete"><ArtSvgIcon icon="ri:delete-bin-line" class="mr-1" />删除</ElButton>
    </div>

    <!-- 表格 -->
    <div class="art-card">
      <ElTable :data="cronList" v-loading="loading" stripe row-key="id" @selection-change="onSelect" max-height="600" size="small">
        <ElTableColumn type="selection" width="36" />
        <ElTableColumn label="任务名" prop="name" min-width="140" show-overflow-tooltip>
          <template #default="{ row }"><span class="font-medium">{{ row.name }}</span></template>
        </ElTableColumn>
        <ElTableColumn label="命令" prop="command" min-width="160" show-overflow-tooltip>
          <template #default="{ row }"><code class="text-xs text-g-500">{{ row.command }}</code></template>
        </ElTableColumn>
        <ElTableColumn label="定时规则" prop="schedule" width="130">
          <template #default="{ row }">
            <ElTag size="small" effect="plain" type="info">{{ row.schedule }}</ElTag>
          </template>
        </ElTableColumn>
        <ElTableColumn label="状态" width="90" align="center">
          <template #default="{ row }">
            <ElTag size="small" effect="plain" :type="row.isDisabled ? 'danger' : row.status === 0 ? 'warning' : row.status === 0.5 ? 'info' : 'success'">
              {{ statusText(row) }}
            </ElTag>
          </template>
        </ElTableColumn>
        <ElTableColumn label="上次执行" width="160">
          <template #default="{ row }">
            <span class="text-sm text-g-500">{{ row.last_execution_time ? formatTime(new Date(row.last_execution_time)) : '-' }}</span>
          </template>
        </ElTableColumn>
        <ElTableColumn label="标签" min-width="120">
          <template #default="{ row }">
            <ElTag v-for="(l, i) in (row.labels || [])" :key="i" size="small" class="mr-1">{{ l }}</ElTag>
          </template>
        </ElTableColumn>
        <ElTableColumn label="操作" width="280" fixed="right">
          <template #default="{ row }">
            <ElButton size="small" @click="toggleRun(row)" :type="row.status === 0 ? 'warning' : 'primary'">
              <ArtSvgIcon :icon="row.status === 0 ? 'ri:stop-line' : 'ri:play-line'" class="mr-1" />{{ row.status === 0 ? '停止' : '运行' }}
            </ElButton>
            <ElButton size="small" @click="showEdit(row)"><ArtSvgIcon icon="ri:edit-line" class="mr-1" />编辑</ElButton>
            <ElButton size="small" @click="showLog(row)"><ArtSvgIcon icon="ri:file-text-line" class="mr-1" />日志</ElButton>
            <ElButton size="small" @click="showDetail(row)">详情</ElButton>
            <ElButton size="small" type="danger" plain @click="delCron(row)"><ArtSvgIcon icon="ri:delete-bin-line" /></ElButton>
          </template>
        </ElTableColumn>
      </ElTable>
    </div>

    <!-- 编辑弹窗 -->
    <ElDialog v-model="editVisible" :title="editId ? '编辑任务' : '创建任务'" width="600px" @closed="editId = null">
      <ElForm ref="editFormRef" :model="editForm" label-width="90px">
        <ElFormItem label="任务名" required><ElInput v-model="editForm.name" placeholder="输入任务名称" /></ElFormItem>
        <ElFormItem label="命令" required><ElInput v-model="editForm.command" placeholder="输入执行命令" /></ElFormItem>
        <ElFormItem label="定时类型">
          <ElRadioGroup v-model="scheduleType" @change="onSchedTypeChange">
            <ElRadio label="normal">常规定时</ElRadio>
            <ElRadio label="once">手动运行 (@once)</ElRadio>
            <ElRadio label="boot">开机运行 (@boot)</ElRadio>
          </ElRadioGroup>
        </ElFormItem>
        <ElFormItem v-if="scheduleType === 'normal'" label="定时规则">
          <ElInput v-model="editForm.schedule" placeholder="如: 0 8 * * *" />
          <div v-if="cronError" class="text-danger text-xs mt-1">{{ cronError }}</div>
          <div v-else-if="editForm.schedule" class="text-success text-xs mt-1">{{ cronNext }}</div>
        </ElFormItem>
        <ElFormItem label="标签">
          <ElTag v-for="(tag, i) in editLabels" :key="i" closable size="small" class="mr-1" @close="editLabels.splice(i, 1)">{{ tag }}</ElTag>
          <ElInput v-if="showTagInput" ref="tagInputRef" v-model="newTag" size="small" style="width:80px" @keyup.enter="addTag" @blur="addTag" />
          <ElButton v-else size="small" @click="showTagInput = true"><ArtSvgIcon icon="ri:add-line" class="mr-1" />标签</ElButton>
        </ElFormItem>
      </ElForm>
      <template #footer>
        <ElButton @click="editVisible = false">取消</ElButton>
        <ElButton type="primary" @click="saveCron" :loading="saving">保存</ElButton>
      </template>
    </ElDialog>

    <!-- 日志弹窗 -->
    <ElDialog v-model="logVisible" title="任务日志" width="800px" top="3vh" @close="stopLogPoll">
      <div class="ql-log-viewer"><pre>{{ logContent || '加载中...' }}</pre></div>
    </ElDialog>

    <!-- 详情抽屉 -->
    <ElDrawer v-model="detailVisible" title="任务详情" size="480px">
      <template v-if="detailRow">
        <ElDescriptions :column="1" border size="small" class="mb-4">
          <ElDescriptionsItem label="名称">{{ detailRow.name }}</ElDescriptionsItem>
          <ElDescriptionsItem label="命令"><code>{{ detailRow.command }}</code></ElDescriptionsItem>
          <ElDescriptionsItem label="定时">{{ detailRow.schedule }}</ElDescriptionsItem>
          <ElDescriptionsItem label="状态">
            <ElTag size="small" :type="detailRow.isDisabled ? 'danger' : detailRow.status === 0 ? 'warning' : 'success'">{{ statusText(detailRow) }}</ElTag>
          </ElDescriptionsItem>
          <ElDescriptionsItem label="标签">{{ (detailRow.labels || []).join(', ') || '-' }}</ElDescriptionsItem>
          <ElDescriptionsItem label="上次运行">{{ detailRow.last_running_time ? formatTime(new Date(detailRow.last_running_time)) : '-' }}</ElDescriptionsItem>
          <ElDescriptionsItem label="上次执行">{{ detailRow.last_execution_time ? formatTime(new Date(detailRow.last_execution_time)) : '-' }}</ElDescriptionsItem>
        </ElDescriptions>
        <ElDivider><ArtSvgIcon icon="ri:file-text-line" class="mr-1" />日志文件</ElDivider>
        <div v-if="logFiles.length === 0" class="text-center text-g-400 py-8"><ElEmpty description="暂无日志" :image-size="60" /></div>
        <div v-for="f in logFiles" :key="f" class="ql-file-item" @click="viewLogFile(f)">
          <ArtSvgIcon icon="ri:file-text-line" class="mr-2 text-g-400" />{{ f }}
        </div>
      </template>
    </ElDrawer>

    <!-- 视图编辑弹窗 -->
    <ElDialog v-model="viewEditVisible" :title="viewEditId ? '编辑视图' : '新建视图'" width="420px">
      <ElForm label-width="80px">
        <ElFormItem label="名称"><ElInput v-model="viewForm.name" placeholder="视图名称" /></ElFormItem>
        <ElFormItem label="条件关系">
          <ElRadioGroup v-model="viewForm.filterRelation">
            <ElRadio label="and">且 (AND)</ElRadio>
            <ElRadio label="or">或 (OR)</ElRadio>
          </ElRadioGroup>
        </ElFormItem>
      </ElForm>
      <template #footer>
        <ElButton @click="viewEditVisible = false">取消</ElButton>
        <ElButton type="primary" @click="saveView" :loading="viewSaving">保存</ElButton>
      </template>
    </ElDialog>
  </div>
</template>

<script setup lang="ts">
import request from '@/utils/http'
import { ElMessage, ElMessageBox } from 'element-plus'

defineOptions({ name: 'QlCrontab' })

// ===== 数据 =====
const loading = ref(false); const searchText = ref(''); const cronList = ref<any[]>([]); const selectedIds = ref<number[]>([])

const statusText = (r: any) => {
  if (r.isDisabled) return '已禁用'; if (r.status === 0) return '运行中'; if (r.status === 0.5) return '排队中'; return '空闲'
}

const formatTime = (d: Date) => {
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`
}

const loadData = async () => {
  loading.value = true
  try {
    const res = await request.get<any>({ url: '/api/crons', params: { searchValue: searchText.value } })
    cronList.value = Array.isArray(res) ? res : (res?.data || [])
  } catch { cronList.value = [] }
  finally { loading.value = false }
}
const onSelect = (rows: any[]) => { selectedIds.value = rows.map((r: any) => r.id) }

// ===== 运行/停止 =====
const toggleRun = async (row: any) => {
  const action = row.status === 0 ? 'stop' : 'run'
  try { await request.put({ url: `/api/crons/${action}`, data: [row.id] }); ElMessage.success('操作成功'); loadData() }
  catch (e: any) { ElMessage.error(e?.message || '操作失败') }
}

// ===== 创建/编辑弹窗 =====
const editVisible = ref(false); const saving = ref(false); const editId = ref<number | null>(null); const editFormRef = ref()
const editForm = reactive({ name: '', command: '', schedule: '', allowMulti: false })
const editLabels = ref<string[]>([])
const scheduleType = ref('normal'); const cronError = ref(''); const cronNext = ref('')
const showTagInput = ref(false); const newTag = ref(''); const tagInputRef = ref()

const showEdit = async (row: any | null) => {
  editId.value = row?.id || null
  editForm.name = row?.name || ''; editForm.command = row?.command || ''
  editForm.schedule = row?.schedule || ''; editForm.allowMulti = row?.allow_multiple_instances === 1
  editLabels.value = [...(row?.labels || [])]
  scheduleType.value = row ? getSchedType(row.schedule) : 'normal'
  cronError.value = ''; cronNext.value = ''
  if (row?.schedule) validateCron()
  editVisible.value = true
  await nextTick()
}

const getSchedType = (s: string) => {
  if (s === '@once') return 'once'; if (s === '@boot') return 'boot'; return 'normal'
}

const onSchedTypeChange = () => {
  if (scheduleType.value === 'normal') { editForm.schedule = ''; cronError.value = ''; cronNext.value = '' }
  else { editForm.schedule = scheduleType.value === 'once' ? '@once' : '@boot'; cronError.value = ''; cronNext.value = '' }
}

const validateCron = () => { cronError.value = ''; cronNext.value = editForm.schedule ? '已输入' : '' }
watch(() => editForm.schedule, validateCron)

const addTag = () => {
  const t = newTag.value.trim(); if (t) { editLabels.value.push(t); newTag.value = '' }
  showTagInput.value = false
}

const saveCron = async () => {
  if (!editForm.name || !editForm.command) { ElMessage.warning('任务名和命令必填'); return }
  saving.value = true
  try {
    const data: any = {
      name: editForm.name, command: editForm.command,
      schedule: editForm.schedule || (scheduleType.value === 'once' ? '@once' : scheduleType.value === 'boot' ? '@boot' : '0 8 * * *'),
      labels: editLabels.value,
      allow_multiple_instances: editForm.allowMulti ? 1 : 0
    }
    if (editId.value) { data.id = editId.value; await request.put({ url: '/api/crons', data }) }
    else { await request.post({ url: '/api/crons', data }) }
    ElMessage.success(editId.value ? '更新成功' : '创建成功')
    editVisible.value = false; loadData()
  } catch (e: any) { ElMessage.error(e?.message || '保存失败') }
  finally { saving.value = false }
}

// ===== 日志 =====
const logVisible = ref(false); const logContent = ref(''); let logTimer: any = null
const showLog = async (row: any) => {
  logVisible.value = true; logContent.value = '加载中...'
  const fetchLog = async () => {
    try {
      const res = await request.get<any>({ url: `/api/crons/${row.id}/log` })
      logContent.value = (typeof res === 'string' ? res : res?.data || '').replace(/\x1b\[[\d;]*m/g, '') || '暂无日志'
    } catch { logContent.value = '获取日志失败' }
  }
  await fetchLog(); logTimer = setInterval(fetchLog, 2000)
}
const stopLogPoll = () => { if (logTimer) { clearInterval(logTimer); logTimer = null } }

// ===== 详情 =====
const detailVisible = ref(false); const detailRow = ref<any>(null); const logFiles = ref<string[]>([])
const showDetail = async (row: any) => {
  detailRow.value = row; detailVisible.value = true; logFiles.value = []
  try { const res = await request.get<any>({ url: `/api/crons/${row.id}/logs` }); logFiles.value = Array.isArray(res) ? res : (res?.data || []) } catch {}
}
const viewLogFile = (f: string) => { ElMessageBox.alert(f, '日志文件路径') }

// ===== 删除 =====
const delCron = async (row: any) => {
  try { await ElMessageBox.confirm(`确认删除 "${row.name}"？`, '警告', { type: 'warning' }); await request.del({ url: '/api/crons', data: [row.id] }); ElMessage.success('已删除'); loadData() } catch {}
}

// ===== 批量 =====
const batchOp = async (action: string) => {
  try { await request.put({ url: `/api/crons/${action}`, data: selectedIds.value }); ElMessage.success('操作成功'); loadData() } catch (e: any) { ElMessage.error(e?.message || '操作失败') }
}
const batchDelete = async () => {
  try { await ElMessageBox.confirm(`确认删除选中的 ${selectedIds.value.length} 个任务？`, '警告', { type: 'warning' }); await request.del({ url: '/api/crons', data: selectedIds.value }); ElMessage.success('已删除'); loadData() } catch {}
}

// ===== 自定义视图 =====
const views = ref<any[]>([]); const activeView = ref<number | null>(null)
const viewEditVisible = ref(false); const viewSaving = ref(false); const viewEditId = ref<number | null>(null)
const viewForm = reactive({ name: '', filterRelation: 'and' })

const loadViews = async () => { try { views.value = await request.get<any>({ url: '/api/crons/views' }) || [] } catch {} }
const switchView = (v: any) => { activeView.value = v.id; loadData() }
const showViewEdit = (v: any | null) => { viewEditId.value = v?.id || null; viewForm.name = v?.name || ''; viewForm.filterRelation = v?.filterRelation || 'and'; viewEditVisible.value = true }
const saveView = async () => {
  if (!viewForm.name) { ElMessage.warning('名称必填'); return }
  viewSaving.value = true
  try {
    if (viewEditId.value) await request.put({ url: '/api/crons/views', data: { id: viewEditId.value, ...viewForm } })
    else await request.post({ url: '/api/crons/views', data: viewForm })
    ElMessage.success('保存成功'); viewEditVisible.value = false; loadViews()
  } catch (e: any) { ElMessage.error(e?.message || '保存失败') }
  finally { viewSaving.value = false }
}
const viewAction = async (cmd: string, v: any) => {
  if (cmd === 'edit') showViewEdit(v)
  if (cmd === 'del') { try { await request.del({ url: '/api/crons/views', data: [v.id] }); loadViews() } catch {} }
}

onMounted(() => { loadData(); loadViews() })
onUnmounted(stopLogPoll)
</script>

<style scoped>
/* 通用页面布局 */
.ql-page { display: flex; flex-direction: column; gap: 10px; }

/* 工具栏 */
.ql-toolbar { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 10px; }
.ql-toolbar-left { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }

/* 视图标签 */
.ql-view-tabs { display: flex; align-items: center; gap: 4px; flex-wrap: wrap; }
.ql-view-tab {
  display: inline-flex; align-items: center; gap: 4px;
  padding: 4px 14px; border-radius: 6px; cursor: pointer;
  font-size: 13px; background: var(--art-gray-100, #f5f5f5);
  border: 1px solid transparent; transition: all 0.15s;
}
.ql-view-tab:hover { background: var(--art-gray-200, #e8e8e8); }
.ql-view-tab.active { background: var(--el-color-primary); color: #fff; }
.ql-view-more { opacity: 0.5; }
.ql-view-more:hover { opacity: 1; }

/* 批量操作栏 */
.ql-batch-bar {
  display: flex; align-items: center; gap: 6px;
  background: var(--el-color-primary-light-9, #ecf5ff);
  border: 1px solid var(--el-color-primary-light-7, #b3d4fc);
  border-radius: 8px; padding: 8px 14px;
}

/* 日志查看器 */
.ql-log-viewer {
  background: #1e1e1e; color: #d4d4d4; border-radius: 8px;
  padding: 14px; max-height: 600px; overflow: auto;
}
.ql-log-viewer pre {
  margin: 0; font-family: 'Consolas', 'Courier New', monospace;
  font-size: 13px; line-height: 1.5; white-space: pre-wrap;
}

/* 文件列表项 */
.ql-file-item {
  display: flex; align-items: center; padding: 8px 12px;
  cursor: pointer; border-radius: 6px; font-size: 13px; font-family: monospace;
  transition: background 0.15s;
}
.ql-file-item:hover { background: var(--art-gray-100, #f5f5f5); }

@media (max-width: 768px) {
  .ql-toolbar { flex-direction: column; align-items: flex-start; }
  .ql-toolbar-left { flex-wrap: wrap; }
  .ql-toolbar-left .el-input { width: 100% !important; }
  .ql-view-tab { font-size: 12px; padding: 3px 10px; }
}
</style>
