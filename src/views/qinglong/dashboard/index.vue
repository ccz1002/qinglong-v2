<template>
  <div class="ql-dashboard">
    <!-- 统计卡片 -->
    <ElRow :gutter="16">
      <ElCol v-for="card in statCards" :key="card.key" :xs="12" :sm="12" :md="6">
        <div class="art-card stat-card flex items-center justify-between px-5 py-4 mb-4 transition-all duration-200 hover:-translate-y-0.5">
          <div>
            <p class="m-0 text-sm text-g-500">{{ card.label }}</p>
            <ArtCountTo class="text-[26px] font-semibold mt-1" :target="card.value" :duration="1000" />
          </div>
          <div class="size-11 flex-cc rounded-lg text-xl text-white" :style="{ background: card.color }">
            <ArtSvgIcon :icon="card.icon" />
          </div>
        </div>
      </ElCol>
    </ElRow>

    <ElRow :gutter="16">
      <!-- 系统信息 -->
      <ElCol :xs="24" :lg="12">
        <div class="art-card mb-4">
          <div class="flex items-center justify-between px-5 py-3 border-b border-g-200">
            <span class="font-medium">系统信息</span>
            <ElButton size="small" text @click="loadSystemInfo" :loading="sysLoading">
              <ArtSvgIcon icon="ri:refresh-line" class="text-base" />
            </ElButton>
          </div>
          <div class="p-4">
            <ElDescriptions :column="2" border size="small">
              <ElDescriptionsItem label="青龙版本">{{ sysInfo.version || '-' }}</ElDescriptionsItem>
              <ElDescriptionsItem label="运行环境">{{ sysInfo.os || '-' }}</ElDescriptionsItem>
              <ElDescriptionsItem label="Node.js">{{ sysInfo.nodeVersion || '-' }}</ElDescriptionsItem>
              <ElDescriptionsItem label="CPU架构">{{ sysInfo.arch || '-' }}</ElDescriptionsItem>
              <ElDescriptionsItem label="运行时长">{{ sysInfo.uptime || '-' }}</ElDescriptionsItem>
              <ElDescriptionsItem label="PID">{{ sysInfo.pid || '-' }}</ElDescriptionsItem>
              <ElDescriptionsItem label="数据库">{{ sysInfo.dbType || 'SQLite' }}</ElDescriptionsItem>
              <ElDescriptionsItem label="调度器">{{ sysInfo.scheduler || '-' }}</ElDescriptionsItem>
            </ElDescriptions>
          </div>
        </div>
      </ElCol>

      <!-- 资源 + 快捷入口 -->
      <ElCol :xs="24" :lg="12">
        <div class="art-card mb-4">
          <div class="px-5 py-3 border-b border-g-200">
            <span class="font-medium">资源使用</span>
          </div>
          <div class="p-4">
            <div v-for="res in resources" :key="res.key" class="mb-4 last:mb-0">
              <div class="flex items-center justify-between mb-1">
                <span class="text-sm text-g-600">{{ res.label }}</span>
                <span class="text-sm font-medium" :class="res.used > 80 ? 'text-danger' : 'text-success'">
                  {{ res.display }}
                </span>
              </div>
              <ElProgress
                :percentage="Math.min(res.used, 100)"
                :color="res.used > 80 ? '#f56c6c' : res.used > 60 ? '#e6a23c' : '#409eff'"
                :stroke-width="8"
                :show-text="false"
              />
            </div>
          </div>
        </div>

        <div class="art-card p-4">
          <p class="m-0 mb-3 text-sm font-medium text-g-600">快捷入口</p>
          <div class="flex flex-wrap gap-2">
            <ElButton
              v-for="link in quickLinks"
              :key="link.path"
              size="small"
              @click="goPage(link.path)"
            >
              <ArtSvgIcon :icon="link.icon" class="mr-1" />
              {{ link.label }}
            </ElButton>
          </div>
        </div>
      </ElCol>
    </ElRow>

    <!-- 最近执行 -->
    <div class="art-card mt-4">
      <div class="flex items-center justify-between px-5 py-3 border-b border-g-200">
        <span class="font-medium">最近任务执行</span>
        <ElButton size="small" text @click="loadRecentTasks" :loading="taskLoading">
          <ArtSvgIcon icon="ri:refresh-line" class="text-base" />
        </ElButton>
      </div>
      <ElTable
        :data="recentTasks"
        v-loading="taskLoading"
        size="small"
        empty-text="暂无执行记录"
        class="dashboard-table"
      >
        <ElTableColumn label="时间" width="170">
          <template #default="{ row }">
            <span class="text-sm text-g-600">{{ row.timestamp ? new Date(row.timestamp).toLocaleString() : '-' }}</span>
          </template>
        </ElTableColumn>
        <ElTableColumn label="任务名称" min-width="160">
          <template #default="{ row }">
            <span class="text-sm">{{ row.taskName }}</span>
          </template>
        </ElTableColumn>
        <ElTableColumn label="命令" min-width="140" show-overflow-tooltip>
          <template #default="{ row }">
            <code class="text-xs text-g-500">{{ row.command }}</code>
          </template>
        </ElTableColumn>
        <ElTableColumn label="状态" width="80" align="center">
          <template #default="{ row }">
            <ElTag
              :type="row.status === 0 ? 'success' : row.status === 1 ? 'danger' : 'warning'"
              size="small"
              effect="plain"
            >
              {{ ['成功','失败','运行中'][row.status] || '-' }}
            </ElTag>
          </template>
        </ElTableColumn>
        <ElTableColumn label="耗时" width="80" align="right">
          <template #default="{ row }">
            <span class="text-sm text-g-500">{{ row.duration ? row.duration + 's' : '-' }}</span>
          </template>
        </ElTableColumn>
      </ElTable>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import request from '@/utils/http'

defineOptions({ name: 'QlDashboard' })

const router = useRouter()
const sysLoading = ref(false)

// ── 统计卡片 ──
const statCards = reactive([
  { key: 'tasks', label: '定时任务', value: 0, icon: 'ri:timer-line', color: '#409eff' },
  { key: 'running', label: '运行中', value: 0, icon: 'ri:play-circle-line', color: '#67c23a' },
  { key: 'scripts', label: '脚本文件', value: 0, icon: 'ri:code-box-line', color: '#e6a23c' },
  { key: 'envs', label: '环境变量', value: 0, icon: 'ri:settings-3-line', color: '#8b5cf6' },
])

// ── 系统信息 ──
const sysInfo = reactive<Record<string, any>>({})
const loadSystemInfo = async () => {
  sysLoading.value = true
  try {
    const res = await request.get<any>({ url: '/api/system' })
    Object.assign(sysInfo, res || {})
    if (sysInfo.uptime && typeof sysInfo.uptime === 'number') {
      const d = Math.floor(sysInfo.uptime / 86400)
      const h = Math.floor((sysInfo.uptime % 86400) / 3600)
      const m = Math.floor((sysInfo.uptime % 3600) / 60)
      sysInfo.uptime = `${d}d ${h}h ${m}m`
    }
  } catch {}
  finally { sysLoading.value = false }
}

// ── 资源使用 ──
const resources = reactive([
  { key: 'cpu', label: 'CPU 使用率', used: 0, display: '0%' },
  { key: 'memory', label: '内存使用率', used: 0, display: '0%' },
  { key: 'disk', label: '磁盘使用率', used: 0, display: '0%' },
])

// ── 统计数据 ──
const loadStats = async () => {
  try {
    const [cronsRes, scriptsRes, envsRes] = await Promise.all([
      request.get<any>({ url: '/api/crons', params: { searchValue: '' } }).catch(() => [] as any),
      request.get<any>({ url: '/api/scripts' }).catch(() => [] as any),
      request.get<any>({ url: '/api/envs' }).catch(() => [] as any),
    ])
    const crons = Array.isArray(cronsRes) ? cronsRes : (cronsRes?.data || [])
    const scripts = Array.isArray(scriptsRes) ? scriptsRes : (scriptsRes?.data || [])
    const envs = Array.isArray(envsRes) ? envsRes : (envsRes?.data || [])

    statCards[0].value = crons.length
    statCards[1].value = crons.filter((c: any) => c.status === 0).length
    statCards[2].value = Array.isArray(scripts) ? scripts.length : 0
    statCards[3].value = envs.length

    if (sysInfo.memory) {
      const mem = sysInfo.memory as any
      if (mem.total && mem.used) {
        resources[1].used = Math.round((mem.used / mem.total) * 100)
        resources[1].display = `${resources[1].used}%`
      }
    }
    if (sysInfo.disk) {
      const disk = sysInfo.disk as any
      if (disk.total && disk.used) {
        resources[2].used = Math.round((disk.used / disk.total) * 100)
        resources[2].display = `${resources[2].used}%`
      }
    }
  } catch {}
}

// ── 最近任务 ──
const recentTasks = ref<any[]>([])
const taskLoading = ref(false)
const loadRecentTasks = async () => {
  taskLoading.value = true
  try {
    const res = await request.get<any>({ url: '/api/crons', params: { searchValue: '' } })
    const list = Array.isArray(res) ? res : (res?.data || [])
    recentTasks.value = list
      .sort((a: any, b: any) => (b.last_execution_time || 0) - (a.last_execution_time || 0))
      .slice(0, 10)
      .map((c: any) => ({
        taskName: c.name || c.command?.split('/').pop() || '-',
        command: c.command || '-',
        timestamp: c.last_execution_time || null,
        status: c.last_execution_status ?? -1,
        duration: c.last_execution_duration || null,
      }))
  } catch {}
  finally { taskLoading.value = false }
}

// ── 快捷入口 ──
const quickLinks = [
  { label: '定时任务', path: '/crontab', icon: 'ri:timer-line' },
  { label: '脚本管理', path: '/script', icon: 'ri:code-box-line' },
  { label: '环境变量', path: '/env', icon: 'ri:settings-3-line' },
  { label: '日志管理', path: '/log', icon: 'ri:file-text-line' },
  { label: '系统设置', path: '/setting', icon: 'ri:settings-2-line' },
]

const goPage = (path: string) => router.push(path)

onMounted(() => {
  loadSystemInfo()
  loadStats()
  loadRecentTasks()
})
</script>

<style scoped>
.stat-card .art-svg-icon {
  font-size: 22px;
}

.dashboard-table :deep(.el-table__row:last-child td) {
  border-bottom: none;
}
</style>
