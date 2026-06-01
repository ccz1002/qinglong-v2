<template>
  <div class="ql-page">
    <div class="ql-toolbar">
      <div class="ql-toolbar-left">
        <ElInput v-model="searchText" placeholder="搜索订阅" clearable style="width:220px" @change="loadData">
          <template #prefix><ArtSvgIcon icon="ri:search-line" class="text-g-400" /></template>
        </ElInput>
        <ElButton type="primary" @click="showEdit(null)"><ArtSvgIcon icon="ri:add-line" class="mr-1" />创建订阅</ElButton>
        <ElButton @click="loadData" :loading="loading"><ArtSvgIcon icon="ri:refresh-line" class="mr-1" />刷新</ElButton>
      </div>
      <span class="text-sm text-g-400">{{ subList.length }} 个订阅</span>
    </div>

    <div class="art-card">
      <ElTable :data="subList" v-loading="loading" stripe size="small" empty-text="暂无订阅">
        <ElTableColumn label="名称" min-width="140">
          <template #default="{ row }"><span class="font-medium">{{ row.name }}</span></template>
        </ElTableColumn>
        <ElTableColumn label="仓库地址" min-width="220" show-overflow-tooltip>
          <template #default="{ row }"><code class="text-xs text-g-500">{{ row.url }}</code></template>
        </ElTableColumn>
        <ElTableColumn label="类型" width="100" align="center">
          <template #default="{ row }">
            <ElTag size="small" effect="plain" type="info">{{ row.type || '-' }}</ElTag>
          </template>
        </ElTableColumn>
        <ElTableColumn label="状态" width="100" align="center">
          <template #default="{ row }">
            <ElTag size="small" effect="plain" :type="row.status === 0 ? 'warning' : row.status === 1 ? 'success' : row.status === 2 ? 'danger' : 'info'">
              {{ ['运行中', '空闲', '已禁用'][row.status] || row.status }}
            </ElTag>
          </template>
        </ElTableColumn>
        <ElTableColumn label="定时规则" width="130">
          <template #default="{ row }"><span class="text-sm text-g-600">{{ row.schedule }}</span></template>
        </ElTableColumn>
        <ElTableColumn label="操作" width="220" fixed="right">
          <template #default="{ row }">
            <ElButton size="small" @click="toggleRun(row)" :type="row.status === 0 ? 'warning' : 'primary'">
              <ArtSvgIcon :icon="row.status === 0 ? 'ri:stop-line' : 'ri:play-line'" class="mr-1" />{{ row.status === 0 ? '停止' : '运行' }}
            </ElButton>
            <ElButton size="small" @click="showEdit(row)"><ArtSvgIcon icon="ri:edit-line" class="mr-1" />编辑</ElButton>
            <ElButton size="small" type="danger" plain @click="delSub(row)"><ArtSvgIcon icon="ri:delete-bin-line" /></ElButton>
          </template>
        </ElTableColumn>
      </ElTable>
    </div>

    <ElDialog v-model="editVisible" :title="editId ? '编辑订阅' : '创建订阅'" width="550px" @close="editId = null">
      <ElForm ref="editFormRef" :model="editForm" label-width="90px">
        <ElFormItem label="名称" required><ElInput v-model="editForm.name" placeholder="订阅名称" /></ElFormItem>
        <ElFormItem label="类型" required>
          <ElSelect v-model="editForm.type">
            <ElOption label="公开仓库" value="public-repo" /><ElOption label="私有仓库" value="private-repo" /><ElOption label="单文件" value="file" />
          </ElSelect>
        </ElFormItem>
        <ElFormItem label="仓库地址"><ElInput v-model="editForm.url" placeholder="git URL 或文件 URL" /></ElFormItem>
        <ElFormItem label="分支"><ElInput v-model="editForm.branch" placeholder="默认 main" /></ElFormItem>
        <ElFormItem label="定时规则"><ElInput v-model="editForm.schedule" placeholder="如 0 8 * * *" /></ElFormItem>
        <ElFormItem label="定时类型" required>
          <ElSelect v-model="editForm.schedule_type">
            <ElOption label="Crontab" value="crontab" /><ElOption label="Interval" value="interval" />
          </ElSelect>
        </ElFormItem>
      </ElForm>
      <template #footer>
        <ElButton @click="editVisible = false">取消</ElButton>
        <ElButton type="primary" @click="saveSub" :loading="saving">保存</ElButton>
      </template>
    </ElDialog>
  </div>
</template>

<script setup lang="ts">
import request from '@/utils/http'
import { ElMessage, ElMessageBox } from 'element-plus'
defineOptions({ name: 'QlSubscription' })

const loading = ref(false); const searchText = ref(''); const subList = ref<any[]>([])
const loadData = async () => {
  loading.value = true
  try { subList.value = await request.get<any>({ url: '/api/subscriptions', params: { searchValue: searchText.value } }) || [] }
  catch { } finally { loading.value = false }
}

const toggleRun = async (row: any) => {
  const action = row.status === 0 ? 'stop' : 'run'
  try { await request.put({ url: `/api/subscriptions/${action}`, data: [row.id] }); loadData() }
  catch (e: any) { ElMessage.error(e?.message || '操作失败') }
}

const editVisible = ref(false); const saving = ref(false); const editId = ref<number | null>(null)
const editForm = reactive({ name: '', type: 'public-repo', url: '', branch: '', schedule: '', schedule_type: 'crontab', alias: '' })
const showEdit = (row: any | null) => {
  editId.value = row?.id || null; editForm.name = row?.name || ''; editForm.type = row?.type || 'public-repo'
  editForm.url = row?.url || ''; editForm.branch = row?.branch || ''; editForm.schedule = row?.schedule || ''
  editForm.schedule_type = row?.schedule_type || 'crontab'; editForm.alias = row?.alias || row?.name || ''
  editVisible.value = true
}
const saveSub = async () => {
  if (!editForm.name) { ElMessage.warning('名称必填'); return }
  if (!editForm.url) { ElMessage.warning('仓库地址必填'); return }
  saving.value = true
  try {
    const data: any = { ...editForm }
    if (!data.alias) data.alias = data.name
    if (editId.value) { data.id = editId.value; await request.put({ url: '/api/subscriptions', data }) }
    else { await request.post({ url: '/api/subscriptions', data }) }
    ElMessage.success('保存成功'); editVisible.value = false; loadData()
  } catch (e: any) { ElMessage.error(e?.message || '保存失败') }
  finally { saving.value = false }
}

const delSub = async (row: any) => {
  try { await ElMessageBox.confirm(`删除 "${row.name}"？`, '警告', { type: 'warning' }); await request.del({ url: '/api/subscriptions', data: [row.id] }); loadData() } catch { }
}

onMounted(loadData)
</script>

<style scoped>
.ql-page { display: flex; flex-direction: column; gap: 10px; }
.ql-toolbar { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 10px; }
.ql-toolbar-left { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
@media (max-width: 768px) {
  .ql-toolbar { flex-direction: column; align-items: flex-start; }
  .ql-toolbar-left { flex-wrap: wrap; }
  .ql-toolbar-left .el-input { width: 100% !important; }
}
</style>
