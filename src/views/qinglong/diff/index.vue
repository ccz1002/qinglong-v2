<template>
  <div class="ql-page">
    <div class="art-card">
      <div class="ql-card-header">
        <span class="font-medium"><ArtSvgIcon icon="ri:sparkling-line" class="mr-2" />对比工具</span>
        <ElButton @click="refresh"><ArtSvgIcon icon="ri:refresh-line" class="mr-1" />刷新</ElButton>
      </div>
      <div class="flex items-center gap-4 p-4 border-b border-g-200 flex-wrap">
        <div class="flex items-center gap-2">
          <span class="text-sm text-g-500 whitespace-nowrap">示例文件</span>
          <ElSelect v-model="sampleFile" placeholder="选择示例" style="width:200px" @change="loadSample">
            <ElOption v-for="s in samples" :key="s.value || s" :label="s.title || s" :value="s.value || s" />
          </ElSelect>
        </div>
        <div class="flex items-center gap-2">
          <span class="text-sm text-g-500 whitespace-nowrap">当前文件</span>
          <ElSelect v-model="currentFile" placeholder="选择当前" style="width:200px" @change="loadCurrent">
            <ElOption v-for="f in files" :key="f.value || f" :label="f.title || f" :value="f.value || f" />
          </ElSelect>
        </div>
      </div>

      <div v-if="sampleFile && currentFile" class="ql-diff-container">
        <div class="ql-diff-pane">
          <div class="ql-diff-title"><ArtSvgIcon icon="ri:file-copy-line" class="mr-1" />示例: {{ sampleFile }}</div>
          <pre>{{ sampleContent }}</pre>
        </div>
        <div class="ql-diff-pane">
          <div class="ql-diff-title"><ArtSvgIcon icon="ri:file-edit-line" class="mr-1" />当前: {{ currentFile }}</div>
          <pre>{{ currentContent }}</pre>
        </div>
      </div>
      <ElEmpty v-else description="请选择左右两侧文件进行对比" :image-size="80" class="py-12" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { qlConfigApi } from '@/api/modules/qinglong'
import { ElMessage } from 'element-plus'
defineOptions({ name: 'QlDiff' })

const samples = ref<string[]>([]); const files = ref<string[]>([])
const sampleFile = ref(''); const currentFile = ref('')
const sampleContent = ref(''); const currentContent = ref('')

const refresh = async () => {
  const [s, f] = await Promise.all([qlConfigApi.samples(), qlConfigApi.files()])
  samples.value = s || []; files.value = f || []
}

const loadSample = async (f: string) => { if (!f) return; const res = await qlConfigApi.detail(f); sampleContent.value = res?.content || res || '' }
const loadCurrent = async (f: string) => { if (!f) return; const res = await qlConfigApi.detail(f); currentContent.value = res?.content || res || '' }

onMounted(refresh)
</script>

<style scoped>
.ql-page { display: flex; flex-direction: column; gap: 10px; }
.ql-card-header { display: flex; align-items: center; justify-content: space-between; padding: 14px 18px; border-bottom: 1px solid var(--art-card-border, #eee); }
.ql-diff-container { display: flex; gap: 0; flex: 1; min-height: 400px; }
.ql-diff-pane { flex: 1; min-width: 0; }
.ql-diff-pane:first-child { border-right: 1px solid var(--art-card-border, #eee); }
.ql-diff-title {
  font-weight: 600; font-size: 13px; padding: 8px 14px;
  background: var(--art-gray-100, #f5f5f5); display: flex; align-items: center;
}
.ql-diff-pane pre {
  margin: 0; background: #1e1e1e; color: #d4d4d4; padding: 14px; font-size: 13px;
  font-family: 'Consolas', 'Courier New', monospace; white-space: pre-wrap;
  max-height: 600px; overflow: auto; min-height: 300px;
}
@media (max-width: 768px) {
  .ql-diff-container { flex-direction: column; }
  .ql-diff-pane:first-child { border-right: none; border-bottom: 1px solid var(--art-card-border, #eee); }
}
</style>
