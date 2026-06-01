<template>
  <div class="config-page">
    <ElCard>
      <template #header>
        <div class="flex items-center justify-between">
          <span>配置文件</span>
          <div class="flex gap-2">
            <ElSelect v-model="currentFile" placeholder="选择配置文件" style="width:300px" filterable>
              <ElOption v-for="f in files" :key="f.value || f" :label="f.title || f" :value="(f.value || f) as string" />
            </ElSelect>
            <ElButton type="primary" @click="handleSave" :loading="saving" :disabled="!currentFile">保存 (Ctrl+S)</ElButton>
            <ElButton @click="loadFiles">刷新</ElButton>
          </div>
        </div>
      </template>
      <div v-if="currentFile">
        <ElInput v-model="content" type="textarea" :rows="25" placeholder="加载中..." style="font-family:monospace;font-size:13px" @keydown.ctrl.s.prevent="handleSave" />
      </div>
      <ElEmpty v-else description="请选择一个配置文件" />
    </ElCard>
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

const loadFiles = async () => {
  const res = await qlConfigApi.files()
  files.value = res || []
}

watch(currentFile, async (f) => {
  if (!f) { content.value = ''; return }
  const res = await qlConfigApi.detail(f)
  content.value = res?.content || res || ''
})

const handleSave = async () => {
  if (!currentFile.value) return
  saving.value = true
  try {
    await qlConfigApi.save({ name: currentFile.value, content: content.value })
    ElMessage.success('保存成功')
  } catch (e: any) { ElMessage.error(e?.message || '保存失败') }
  finally { saving.value = false }
}

onMounted(loadFiles)
</script>
