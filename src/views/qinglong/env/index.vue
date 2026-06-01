<template>
  <div class="ql-page">
    <div class="ql-toolbar">
      <div class="ql-toolbar-left">
        <ElInput v-model="searchText" placeholder="搜索名称/值/备注" clearable style="width:260px" @change="loadData">
          <template #prefix><ArtSvgIcon icon="ri:search-line" class="text-g-400" /></template>
        </ElInput>
        <ElButton type="primary" @click="showEdit(null)"><ArtSvgIcon icon="ri:add-line" class="mr-1" />新建变量</ElButton>
        <ElButton @click="importEnv"><ArtSvgIcon icon="ri:upload-2-line" class="mr-1" />导入</ElButton>
        <ElButton @click="exportEnv"><ArtSvgIcon icon="ri:download-2-line" class="mr-1" />导出</ElButton>
        <ElButton @click="loadData" :loading="loading"><ArtSvgIcon icon="ri:refresh-line" class="mr-1" />刷新</ElButton>
      </div>
      <span class="text-sm text-g-400">{{ envList.length }} 个变量</span>
    </div>

    <div v-if="selectedIds.length" class="ql-batch-bar">
      <ArtSvgIcon icon="ri:checkbox-multiple-line" class="text-sm text-primary" />
      <span class="text-sm font-medium">已选 {{ selectedIds.length }} 项</span>
      <ElDivider direction="vertical" />
      <ElButton size="small" @click="batchOp('enable')">启用</ElButton>
      <ElButton size="small" @click="batchOp('disable')">禁用</ElButton>
      <ElButton size="small" @click="batchOp('pin')">置顶</ElButton>
      <ElButton size="small" @click="batchOp('unpin')">取消置顶</ElButton>
      <ElDivider direction="vertical" />
      <ElButton size="small" type="danger" @click="batchDelete">删除</ElButton>
    </div>

    <div class="art-card">
      <ElTable :data="envList" v-loading="loading" stripe size="small" empty-text="暂无数据" row-key="id" @selection-change="onSelect" max-height="600">
        <ElTableColumn type="selection" width="36" />
        <ElTableColumn label="名称" min-width="140">
          <template #default="{ row }"><span class="font-medium">{{ row.name }}</span></template>
        </ElTableColumn>
        <ElTableColumn label="值" min-width="200">
          <template #default="{ row }"><code class="text-xs text-g-500">{{ (row.value || '').substring(0, 80) }}{{ (row.value || '').length > 80 ? '...' : '' }}</code></template>
        </ElTableColumn>
        <ElTableColumn label="备注" min-width="120">
          <template #default="{ row }"><span class="text-sm text-g-500">{{ row.remarks }}</span></template>
        </ElTableColumn>
        <ElTableColumn label="标签" min-width="120">
          <template #default="{ row }">
            <ElTag v-for="(l, i) in (row.labels || [])" :key="i" size="small" class="mr-1">{{ l }}</ElTag>
          </template>
        </ElTableColumn>
        <ElTableColumn label="状态" width="70" align="center">
          <template #default="{ row }">
            <ElTag size="small" effect="plain" :type="row.status === 0 ? 'success' : 'info'">{{ row.status === 0 ? '启用' : '禁用' }}</ElTag>
          </template>
        </ElTableColumn>
        <ElTableColumn label="排序" width="90" align="center">
          <template #default="{ row, $index }">
            <ElButton size="small" circle :disabled="$index === 0" @click="move(row, $index, -1)"><ArtSvgIcon icon="ri:arrow-up-s-line" /></ElButton>
            <ElButton size="small" circle :disabled="$index === envList.length - 1" @click="move(row, $index, 1)"><ArtSvgIcon icon="ri:arrow-down-s-line" /></ElButton>
          </template>
        </ElTableColumn>
        <ElTableColumn label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <ElButton size="small" @click="showEdit(row)"><ArtSvgIcon icon="ri:edit-line" class="mr-1" />编辑</ElButton>
            <ElButton size="small" @click="toggle(row)">{{ row.status === 0 ? '禁用' : '启用' }}</ElButton>
            <ElButton size="small" type="danger" plain @click="delEnv(row)"><ArtSvgIcon icon="ri:delete-bin-line" /></ElButton>
          </template>
        </ElTableColumn>
      </ElTable>
    </div>

    <ElDialog v-model="editVisible" :title="editId ? '编辑变量' : '新建变量'" width="550px" @closed="editId = null">
      <ElForm ref="editFormRef" :model="editForm" label-width="80px">
        <ElFormItem label="名称" required><ElInput v-model="editForm.name" placeholder="以字母或下划线开头" /></ElFormItem>
        <ElFormItem label="值"><ElInput v-model="editForm.value" type="textarea" :rows="4" placeholder="变量值" /></ElFormItem>
        <ElFormItem label="备注"><ElInput v-model="editForm.remarks" placeholder="可选" /></ElFormItem>
        <ElFormItem label="标签">
          <ElTag v-for="(t, i) in editLabels" :key="i" closable size="small" class="mr-1" @close="editLabels.splice(i, 1)">{{ t }}</ElTag>
          <ElInput v-if="showTagInput" ref="tagInputRef" v-model="newTag" size="small" style="width:80px" @keyup.enter="addTag" @blur="addTag" />
          <ElButton v-else size="small" @click="showTagInput = true"><ArtSvgIcon icon="ri:add-line" class="mr-1" />标签</ElButton>
        </ElFormItem>
      </ElForm>
      <template #footer>
        <ElButton @click="editVisible = false">取消</ElButton>
        <ElButton type="primary" @click="saveEnv" :loading="saving">保存</ElButton>
      </template>
    </ElDialog>
  </div>
</template>

<script setup lang="ts">
import request from '@/utils/http'
import { ElMessage, ElMessageBox } from 'element-plus'
defineOptions({ name: 'QlEnv' })

const loading = ref(false); const searchText = ref(''); const envList = ref<any[]>([]); const selectedIds = ref<number[]>([])
const loadData = async () => {
  loading.value = true
  try { const res = await request.get<any>({ url: '/api/envs', params: { searchValue: searchText.value } }); envList.value = Array.isArray(res) ? res : (res?.data || []) } catch { envList.value = [] }
  finally { loading.value = false }
}
const onSelect = (rows: any[]) => { selectedIds.value = rows.map((r: any) => r.id) }

const editVisible = ref(false); const saving = ref(false); const editId = ref<number | null>(null); const editFormRef = ref()
const editForm = reactive({ name: '', value: '', remarks: '' })
const editLabels = ref<string[]>([]); const showTagInput = ref(false); const newTag = ref(''); const tagInputRef = ref()

const showEdit = (row: any | null) => {
  editId.value = row?.id || null; editForm.name = row?.name || ''; editForm.value = row?.value || ''; editForm.remarks = row?.remarks || ''
  editLabels.value = [...(row?.labels || [])]; showTagInput.value = false; newTag.value = ''
  editVisible.value = true
}
const addTag = () => { const t = newTag.value.trim(); if (t) { editLabels.value.push(t); newTag.value = '' } showTagInput.value = false }

const saveEnv = async () => {
  if (!editForm.name) { ElMessage.warning('名称必填'); return }
  if (!/^[a-zA-Z_][0-9a-zA-Z_]*$/.test(editForm.name)) { ElMessage.warning('名称必须以字母或下划线开头，只能包含字母、数字、下划线'); return }
  saving.value = true
  try {
    const data: any = { name: editForm.name, value: editForm.value || '', remarks: editForm.remarks, labels: editLabels.value }
    if (editId.value) { data.id = editId.value; await request.put({ url: '/api/envs', data }) }
    else { await request.post({ url: '/api/envs', data: [data] }) }
    ElMessage.success('保存成功'); editVisible.value = false; loadData()
  } catch (e: any) { ElMessage.error(e?.message || '保存失败') }
  finally { saving.value = false }
}

const move = async (row: any, index: number, dir: number) => {
  const target = envList.value[index + dir]; if (!target) return
  try { await request.put({ url: `/api/envs/${row.id}/move`, data: { fromIndex: index, toIndex: index + dir } }); loadData() } catch (e: any) { ElMessage.error('排序失败') }
}

const toggle = async (row: any) => {
  const action = row.status === 0 ? 'disable' : 'enable'
  try { await request.put({ url: `/api/envs/${action}`, data: [row.id] }); loadData() } catch (e: any) { ElMessage.error(e?.message || '操作失败') }
}

const delEnv = async (row: any) => {
  try { await ElMessageBox.confirm(`删除 "${row.name}"？`, '警告', { type: 'warning' }); await request.del({ url: '/api/envs', data: [row.id] }); loadData() } catch { }
}

const batchOp = (action: string) => request.put({ url: `/api/envs/${action}`, data: selectedIds.value }).then(() => { ElMessage.success('操作成功'); loadData() }).catch((e: any) => ElMessage.error(e?.message))
const batchDelete = () => ElMessageBox.confirm(`删除选中 ${selectedIds.value.length} 项？`, '警告', { type: 'warning' }).then(() => request.del({ url: '/api/envs', data: selectedIds.value }).then(() => { selectedIds.value = []; loadData() })).catch(() => { })

const importEnv = () => {
  const input = document.createElement('input'); input.type = 'file'; input.accept = '.json'
  input.onchange = async (e: any) => {
    const file = e.target.files?.[0]; if (!file) return
    const text = await file.text()
    try { const data = JSON.parse(text); const list = Array.isArray(data) ? data : (data.data || []); await request.post({ url: '/api/envs/upload', data: list }); ElMessage.success(`导入 ${list.length} 条`); loadData() } catch (e: any) { ElMessage.error('导入失败: ' + (e.message || '格式错误')) }
  }
  input.click()
}

const exportEnv = async () => {
  try {
    const data = await request.get<any>({ url: '/api/envs' }); const list = Array.isArray(data) ? data : (data?.data || [])
    const blob = new Blob([JSON.stringify(list, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob); const a = document.createElement('a'); a.href = url; a.download = 'env_export.json'; a.click()
    URL.revokeObjectURL(url)
  } catch { ElMessage.error('导出失败') }
}

onMounted(loadData)
</script>

<style scoped>
.ql-page { display: flex; flex-direction: column; gap: 10px; }
.ql-toolbar { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 10px; }
.ql-toolbar-left { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
.ql-batch-bar {
  display: flex; align-items: center; gap: 6px;
  background: var(--el-color-primary-light-9, #ecf5ff);
  border: 1px solid var(--el-color-primary-light-7, #b3d4fc);
  border-radius: 8px; padding: 8px 14px;
}
@media (max-width: 768px) {
  .ql-toolbar { flex-direction: column; align-items: flex-start; }
  .ql-toolbar-left { flex-wrap: wrap; }
  .ql-toolbar-left .el-input { width: 100% !important; }
}
</style>
