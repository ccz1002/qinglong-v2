<template>
  <div class="update-page">
    <div class="art-card max-w-3xl mx-auto">
      <!-- 头部 -->
      <div class="p-6 text-center border-b border-g-200">
        <ArtSvgIcon icon="ri:rocket-2-line" class="text-5xl text-primary mb-3" />
        <h2 class="text-xl font-semibold m-0">系统更新</h2>
        <p class="text-sm text-g-400 mt-1">全量更新前端+后端，数据库自动保留</p>
      </div>

      <!-- 版本对比 -->
      <div class="p-6">
        <ElRow :gutter="16">
          <ElCol :span="12">
            <div class="version-box current">
              <p class="text-xs text-g-400 mb-1">当前版本</p>
              <p class="text-lg font-bold m-0">{{ currentVersion }}</p>
              <p class="text-xs text-g-400 mt-1">{{ currentTime }}</p>
            </div>
          </ElCol>
          <ElCol :span="12">
            <div class="version-box latest" :class="{ 'has-update': hasUpdate }">
              <p class="text-xs text-g-400 mb-1">最新版本</p>
              <p class="text-lg font-bold m-0">{{ latestVersion || '检测中...' }}</p>
              <p class="text-xs mt-1" :class="hasUpdate ? 'text-warning' : 'text-success'">
                {{ hasUpdate ? '有新版本可用!' : latestVersion ? '已是最新' : '' }}
              </p>
            </div>
          </ElCol>
        </ElRow>
      </div>

      <!-- 更新按钮 -->
      <div class="px-6 pb-2 text-center">
        <ElButton
          type="primary"
          size="large"
          @click="startUpdate"
          :loading="updating"
          :disabled="updating || updateDone"
          class="!px-10 !py-3 !text-base"
        >
          <ArtSvgIcon icon="ri:rocket-2-line" class="mr-2" />
          {{ updating ? '更新中...' : updateDone ? '更新完成' : '开始全量更新' }}
        </ElButton>
        <p class="text-xs text-g-400 mt-2">更新将替换前端和后端所有代码，保留数据库和配置文件</p>
      </div>

      <!-- 进度日志 -->
      <div v-if="updateLog || updating" class="px-6 pb-6">
        <div class="update-log mt-4" ref="logRef">
          <pre>{{ updateLog || '正在连接...' }}</pre>
        </div>
        <div v-if="updating" class="flex items-center gap-2 mt-3 text-sm text-g-400">
          <ElIcon class="is-loading"><Loading /></ElIcon>
          <span>{{ progressText }}</span>
        </div>
        <div v-if="updateDone" class="mt-3 text-center">
          <ElTag type="success" size="large">更新完成! 页面即将刷新...</ElTag>
        </div>
        <div v-if="updateError" class="mt-3 text-center">
          <ElTag type="danger" size="large">更新失败，查看上方日志详情</ElTag>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Loading } from '@element-plus/icons-vue'
import request from '@/utils/http'
import { getVersion, checkLatestVersion } from '@/utils/sys/version'

defineOptions({ name: 'QlUpdate' })

const v = getVersion()
const currentVersion = ref(v.fullVersion)
const currentTime = ref(v.buildTime.substring(0, 19).replace('T', ' '))
const latestVersion = ref('')
const hasUpdate = ref(false)
const updating = ref(false)
const updateDone = ref(false)
const updateError = ref(false)
const updateLog = ref('')
const progressText = ref('')
const logRef = ref<HTMLElement>()
let pollTimer: any = null

const progressSteps = ['下载发布包...', '解压中...', '停止服务...', '替换代码...', '重启服务...']
let stepIndex = 0

onMounted(async () => {
  const result = await checkLatestVersion()
  latestVersion.value = result.latestHash
  hasUpdate.value = result.hasUpdate
})

onUnmounted(() => { if (pollTimer) clearInterval(pollTimer) })

const startUpdate = async () => {
  updating.value = true
  updateDone.value = false
  updateError.value = false
  updateLog.value = ''
  stepIndex = 0

  try {
    // 1. 触发更新
    progressText.value = '正在启动更新...'
    await request.post({ url: '/api/update-v2/start', showErrorMessage: false })

    // 2. 轮询进度
    progressText.value = progressSteps[0]
    pollTimer = setInterval(async () => {
      try {
        const res = await request.get<any>({ url: '/api/update-v2/progress', showErrorMessage: false })
        if (res) {
          updateLog.value = res.log || ''
          if (res.log) {
            // 根据日志内容更新步骤
            if (res.log.includes('[2/5]')) progressText.value = progressSteps[1]
            if (res.log.includes('[3/5]')) progressText.value = progressSteps[2]
            if (res.log.includes('[4/5]')) progressText.value = progressSteps[3]
            if (res.log.includes('[5/5]')) progressText.value = progressSteps[4]
            // 自动滚动到底部
            nextTick(() => { if (logRef.value) logRef.value.scrollTop = logRef.value.scrollHeight })
          }
          if (res.done) {
            clearInterval(pollTimer!)
            updating.value = false
            updateDone.value = true
            progressText.value = '更新完成!'
            setTimeout(() => { location.reload() }, 3000)
          }
          if (res.error) {
            clearInterval(pollTimer!)
            updating.value = false
            updateError.value = true
            progressText.value = '更新失败'
          }
        }
      } catch { /* 继续轮询 */ }
    }, 1500)
  } catch (e: any) {
    updating.value = false
    updateError.value = true
    updateLog.value = '启动更新失败: ' + (e?.message || '后端API不可用')
  }
}
</script>

<style scoped>
.update-page { padding: 20px 0; }
.version-box {
  padding: 20px; border-radius: 10px; text-align: center;
  background: var(--art-gray-100, #f8f9fa); border: 2px solid transparent; transition: all 0.3s;
}
.version-box.current { border-color: var(--el-color-primary-light-7); }
.version-box.latest { border-color: var(--art-gray-300); }
.version-box.has-update { border-color: var(--el-color-warning-light-5); background: #fef8e8; }
.update-log {
  background: #1e1e1e; color: #d4d4d4; border-radius: 10px; padding: 16px;
  max-height: 300px; overflow: auto; font-family: 'Consolas', monospace; font-size: 13px; line-height: 1.6;
}
.update-log pre { margin: 0; white-space: pre-wrap; }
</style>
