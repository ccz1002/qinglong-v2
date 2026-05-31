<template>
  <div class="diff-page">
    <ElCard>
      <template #header>
        <div class="flex items-center gap-4">
          <span>对比工具</span>
          <ElSelect v-model="sampleFile" placeholder="选择示例文件" style="width:200px" @change="loadSample">
            <ElOption v-for="s in samples" :key="s" :label="s" :value="s" />
          </ElSelect>
          <ElSelect v-model="currentFile" placeholder="选择当前文件" style="width:200px" @change="loadCurrent">
            <ElOption v-for="f in files" :key="f" :label="f" :value="f" />
          </ElSelect>
          <ElButton @click="refresh">刷新</ElButton>
        </div>
      </template>

      <div v-if="sampleFile && currentFile" class="diff-container">
        <div class="diff-pane">
          <div class="diff-title">示例: {{ sampleFile }}</div>
          <pre>{{ sampleContent }}</pre>
        </div>
        <div class="diff-pane">
          <div class="diff-title">当前: {{ currentFile }}</div>
          <pre>{{ currentContent }}</pre>
        </div>
      </div>
      <ElEmpty v-else description="请选择左右两侧文件进行对比" />
    </ElCard>
  </div>
</template>

<script setup lang="ts">
import { qlConfigApi } from '@/api/modules/qinglong'
import { ElMessage } from 'element-plus'

defineOptions({ name: 'QlDiff' })

const samples = ref<string[]>([])
const files = ref<string[]>([])
const sampleFile = ref('')
const currentFile = ref('')
const sampleContent = ref('')
const currentContent = ref('')

const refresh = async () => {
  const [s, f] = await Promise.all([qlConfigApi.samples(), qlConfigApi.files()])
  samples.value = s || []
  files.value = f || []
}

const loadSample = async (f: string) => {
  if (!f) return
  const res = await qlConfigApi.detail(f)
  sampleContent.value = res?.content || res || ''
}

const loadCurrent = async (f: string) => {
  if (!f) return
  const res = await qlConfigApi.detail(f)
  currentContent.value = res?.content || res || ''
}

onMounted(refresh)
</script>

<style scoped>
.diff-container {
  display: flex;
  gap: 12px;
}
.diff-pane {
  flex: 1;
  min-width: 0;
}
.diff-title {
  font-weight: 600;
  margin-bottom: 8px;
  padding: 6px 12px;
  background: #f5f5f5;
  border-radius: 4px;
}
.diff-pane pre {
  background: #1e1e1e;
  color: #d4d4d4;
  padding: 12px;
  border-radius: 6px;
  font-size: 13px;
  font-family: monospace;
  white-space: pre-wrap;
  max-height: 600px;
  overflow: auto;
}
</style>
