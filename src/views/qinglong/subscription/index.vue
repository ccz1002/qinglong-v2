<template>
  <div class="sub-page">
    <div class="toolbar">
      <ElInput v-model="searchText" placeholder="搜索订阅" clearable style="width:240px" @change="loadData" />
      <ElButton type="primary" @click="showEdit(null)">创建订阅</ElButton>
      <ElButton @click="loadData" :loading="loading">刷新</ElButton>
    </div>
    <ElTable :data="subList" v-loading="loading" stripe empty-text="暂无订阅">
      <ElTableColumn prop="name" label="名称" min-width="120" />
      <ElTableColumn prop="url" label="仓库地址" min-width="200" show-overflow-tooltip />
      <ElTableColumn label="类型" width="100">
        <template #default="{ row }">{{ row.type || '-' }}</template>
      </ElTableColumn>
      <ElTableColumn label="状态" width="100">
        <template #default="{ row }">
          <ElTag :type="row.status===0?'warning':row.status===1?'success':row.status===2?'danger':'info'">
            {{ ['运行中','空闲','已禁用'][row.status] || row.status }}
          </ElTag>
        </template>
      </ElTableColumn>
      <ElTableColumn prop="schedule" label="定时规则" width="130" />
      <ElTableColumn label="操作" width="180">
        <template #default="{ row }">
          <ElButton size="small" @click="toggleRun(row)">{{ row.status===0?'停止':'运行' }}</ElButton>
          <ElButton size="small" @click="showEdit(row)">编辑</ElButton>
          <ElButton size="small" type="danger" @click="delSub(row)">删除</ElButton>
        </template>
      </ElTableColumn>
    </ElTable>

    <ElDialog v-model="editVisible" :title="editId?'编辑订阅':'创建订阅'" width="550px" @close="editId=null">
      <ElForm ref="editFormRef" :model="editForm" label-width="90px">
        <ElFormItem label="名称" required><ElInput v-model="editForm.name" placeholder="订阅名称" /></ElFormItem>
        <ElFormItem label="类型" required>
          <ElSelect v-model="editForm.type"><ElOption label="公开仓库" value="public-repo" /><ElOption label="私有仓库" value="private-repo" /><ElOption label="单文件" value="file" /></ElSelect>
        </ElFormItem>
        <ElFormItem label="仓库地址"><ElInput v-model="editForm.url" placeholder="git URL 或文件 URL" /></ElFormItem>
        <ElFormItem label="分支"><ElInput v-model="editForm.branch" placeholder="默认 main" /></ElFormItem>
        <ElFormItem label="定时规则"><ElInput v-model="editForm.schedule" placeholder="如 0 8 * * *" /></ElFormItem>
        <ElFormItem label="定时类型" required>
          <ElSelect v-model="editForm.schedule_type">
            <ElOption label="Crontab" value="crontab" />
            <ElOption label="Interval" value="interval" />
          </ElSelect>
        </ElFormItem>
      </ElForm>
      <template #footer>
        <ElButton @click="editVisible=false">取消</ElButton>
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
  catch {} finally { loading.value = false }
}

const toggleRun = async (row: any) => {
  const action = row.status===0?'stop':'run'
  try { await request.put({ url: `/api/subscriptions/${action}`, data: [row.id] }); loadData() }
  catch (e:any) { ElMessage.error(e?.message||'操作失败') }
}

const editVisible = ref(false); const saving = ref(false); const editId = ref<number|null>(null)
const editForm = reactive({ name:'',type:'public-repo',url:'',branch:'',schedule:'',schedule_type:'crontab',alias:'' })
const showEdit = (row: any|null) => {
  editId.value = row?.id||null; editForm.name=row?.name||''; editForm.type=row?.type||'public-repo'
  editForm.url=row?.url||''; editForm.branch=row?.branch||''; editForm.schedule=row?.schedule||''
  editForm.schedule_type=row?.schedule_type||'crontab'; editForm.alias=row?.alias||row?.name||''
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
  } catch (e:any) { ElMessage.error(e?.message||'保存失败') }
  finally { saving.value = false }
}

const delSub = async (row: any) => {
  try { await ElMessageBox.confirm(`删除 "${row.name}"？`, '警告', { type: 'warning' }); await request.del({ url: '/api/subscriptions', data: [row.id] }); loadData() }
  catch {}
}

onMounted(loadData)
</script>

<style scoped>
.toolbar { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; }
</style>
@media (max-width: 768px) {
  .toolbar { flex-wrap: wrap; gap: 6px; }
  .toolbar .el-input { width: 100% !important; }
}
