<template>
  <div class="ql-page">
    <div class="art-card">
      <div class="ql-card-header">
        <span class="font-medium"><ArtSvgIcon icon="ri:file-list-3-line" class="mr-2" />配置文件</span>
        <div class="flex items-center gap-3">
          <ElSelect v-model="currentFile" placeholder="选择配置文件" style="width:300px" filterable>
            <ElOption v-for="f in files" :key="f.value || f" :label="f.title || f" :value="(f.value || f) as string" />
          </ElSelect>
          <ElButton type="primary" @click="handleSave" :loading="saving" :disabled="!currentFile">
            <ArtSvgIcon icon="ri:save-line" class="mr-1" />保存 <span class="text-xs opacity-70 ml-1">Ctrl+S</span>
          </ElButton>
          <ElButton @click="loadFiles"><ArtSvgIcon icon="ri:refresh-line" class="mr-1" />刷新</ElButton>
        </div>
      </div>
      <div v-if="currentFile" class="p-0">
        <ElInput
          v-model="content"
          type="textarea"
          :rows="25"
          placeholder="加载中..."
          class="ql-code-editor"
          @keydown.ctrl.s.prevent="handleSave"
        />
      </div>
      <ElEmpty v-else description="请选择一个配置文件" :image-size="80" class="py-12" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { qlConfigApi } from '@/api/modules/qinglong'
import { ElMessage } from 'element-plus'
defineOptions({ name: 'QlConfig' })

const files = ref<string[]>([])
const currentFile = ref('')
const content = ref('')
const saving = ref(false)

const loadFiles = async () => { const res = await qlConfigApi.files(); files.value = res || [] }

watch(currentFile, async (f) => {
  if (!f) { content.value = ''; return }
  const res = await qlConfigApi.detail(f); content.value = res?.content || res || ''
})

const handleSave = async () => {
  if (!currentFile.value) return
  saving.value = true
  try { await qlConfigApi.save({ name: currentFile.value, content: content.value }); ElMessage.success('保存成功') }
  catch (e: any) { ElMessage.error(e?.message || '保存失败') }
  finally { saving.value = false }
}

onMounted(loadFiles)
</script>

<style scoped>
.ql-page { display: flex; flex-direction: column; gap: 10px; }
.ql-card-header { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px; padding: 14px 18px; border-bottom: 1px solid var(--art-card-border, #eee); }
.ql-code-editor :deep(textarea) { font-family: 'Consolas', 'Courier New', monospace; font-size: 13px; line-height: 1.6; tab-size: 2; }
@media (max-width: 768px) { .ql-card-header { flex-direction: column; align-items: flex-start; } .ql-card-header .el-select { width: 100% !important; } }
</style>
