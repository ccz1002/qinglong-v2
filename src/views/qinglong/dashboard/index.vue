<template>
  <div class="ql-dashboard">
    <!-- 统计卡片行 -->
    <ElRow :gutter="16">
      <ElCol v-for="card in statCards" :key="card.key" :xs="12" :sm="12" :md="6">
        <ArtStatsCard
          :title="card.label"
          :count="card.value"
          :icon="card.icon"
          :icon-style="card.iconBg"
          :decimals="0"
          box-style="mb-4"
        />
      </ElCol>
    </ElRow>

    <ElRow :gutter="16">
      <!-- 任务状态分布 -->
      <ElCol :xs="24" :md="8">
        <ArtDonutChartCard
          title="任务状态"
          :value="cronStats.running + cronStats.idle"
          :percentage="cronStats.runningPercent"
          percentage-label="运行率"
          current-value="运行中"
          previous-value="空闲/禁用"
          :height="12.5"
        />
      </ElCol>

      <!-- 脚本类型分布 -->
      <ElCol :xs="24" :md="8">
        <ArtDonutChartCard
          title="脚本类型"
          :value="scriptTotal"
          :percentage="scriptStats.jsPercent"
          percentage-label="JS/TS占比"
          current-value="JS/TS"
          previous-value="Py/Sh/其他"
          :height="12.5"
        />
      </ElCol>

      <!-- 系统健康度 -->
      <ElCol :xs="24" :md="8">
        <div class="art-card p-5" style="height:12.5rem">
          <p class="m-0 text-xl font-medium text-g-900">系统健康</p>
          <div class="mt-4 space-y-3">
            <div v-for="item in healthChecks" :key="item.key" class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <div class="size-2 rounded-full" :class="item.ok ? 'bg-success' : 'bg-danger'"></div>
                <span class="text-sm text-g-600">{{ item.label }}</span>
              </div>
              <span class="text-sm" :class="item.ok ? 'text-success' : 'text-danger'">{{ item.ok ? '正常' : item.errMsg || '异常' }}</span>
            </div>
          </div>
        </div>
      </ElCol>
    </ElRow>

    <ElRow :gutter="16" class="mt-4">
      <!-- 系统信息 -->
      <ElCol :xs="24" :lg="14">
        <div class="art-card">
          <div class="flex items-center justify-between px-5 py-3 border-b border-g-200">
            <span class="font-medium"><ArtSvgIcon icon="ri:computer-line" class="mr-2" />系统信息</span>
            <ElButton size="small" text @click="loadSystemInfo" :loading="sysLoading">
              <ArtSvgIcon icon="ri:refresh-line" class="text-base" />
            </ElButton>
          </div>
          <div class="p-4">
            <ElRow :gutter="16">
              <ElCol :span="12" v-for="item in sysInfoItems" :key="item.key">
                <div class="flex items-center justify-between py-2 border-b border-g-100 last:border-0">
                  <span class="text-sm text-g-500">{{ item.label }}</span>
                  <span class="text-sm font-medium">{{ item.value }}</span>
                </div>
              </ElCol>
            </ElRow>
          </div>
        </div>
      </ElCol>

      <!-- 快捷入口 + 资源 -->
      <ElCol :xs="24" :lg="10">
        <div class="art-card p-4 mb-4">
          <p class="m-0 mb-3 text-sm font-medium text-g-600"><ArtSvgIcon icon="ri:links-line" class="mr-1.5" />快捷入口</p>
          <div class="flex flex-wrap gap-2">
            <ElButton v-for="link in quickLinks" :key="link.path" size="small" @click="goPage(link.path)">
              <ArtSvgIcon :icon="link.icon" class="mr-1" />{{ link.label }}
            </ElButton>
          </div>
        </div>

        <div class="art-card p-4">
          <p class="m-0 mb-3 text-sm font-medium text-g-600"><ArtSvgIcon icon="ri:dashboard-3-line" class="mr-1.5" />资源使用</p>
          <div v-for="res in resources" :key="res.key" class="mb-3 last:mb-0">
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs text-g-500">{{ res.label }}</span>
              <span class="text-xs font-medium" :class="res.used > 80 ? 'text-danger' : res.used > 60 ? 'text-warning' : 'text-success'">{{ res.display }}</span>
            </div>
            <ElProgress :percentage="Math.min(res.used, 100)" :color="res.used > 80 ? '#f56c6c' : res.used > 60 ? '#e6a23c' : '#409eff'" :stroke-width="6" :show-text="false" />
          </div>
        </div>
      </ElCol>
    </ElRow>

    <!-- 最近任务 -->
    <div class="art-card mt-4">
      <div class="flex items-center justify-between px-5 py-3 border-b border-g-200">
        <span class="font-medium"><ArtSvgIcon icon="ri:history-line" class="mr-2" />最近任务执行</span>
        <ElButton size="small" text @click="loadRecentTasks" :loading="taskLoading">
          <ArtSvgIcon icon="ri:refresh-line" class="text-base" />
        </ElButton>
      </div>
      <ElTable :data="recentTasks" v-loading="taskLoading" size="small" empty-text="暂无执行记录" class="dashboard-table">
        <ElTableColumn label="时间" width="170">
          <template #default="{ row }">
            <span class="text-sm text-g-600">{{ row.timestamp ? new Date(row.timestamp).toLocaleString() : '-' }}</span>
          </template>
        </ElTableColumn>
        <ElTableColumn label="任务" min-width="150">
          <template #default="{ row }"><span class="text-sm font-medium">{{ row.taskName }}</span></template>
        </ElTableColumn>
        <ElTableColumn label="命令" min-width="140" show-overflow-tooltip>
          <template #default="{ row }"><code class="text-xs text-g-500">{{ row.command }}</code></template>
        </ElTableColumn>
        <ElTableColumn label="状态" width="80" align="center">
          <template #default="{ row }">
            <ElTag :type="row.status === 0 ? 'success' : row.status === 1 ? 'danger' : 'warning'" size="small" effect="plain">
              {{ ['成功','失败','运行中'][row.status] || '-' }}
            </ElTag>
          </template>
        </ElTableColumn>
        <ElTableColumn label="耗时" width="80" align="right">
          <template #default="{ row }"><span class="text-sm text-g-500">{{ row.duration ? row.duration + 's' : '-' }}</span></template>
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
  { key: 'tasks', label: '定时任务', value: 0, icon: 'ri:timer-line', iconBg: '!bg-[#409eff] !text-white' },
  { key: 'running', label: '运行中', value: 0, icon: 'ri:play-circle-line', iconBg: '!bg-[#67c23a] !text-white' },
  { key: 'scripts', label: '脚本文件', value: 0, icon: 'ri:code-box-line', iconBg: '!bg-[#e6a23c] !text-white' },
  { key: 'envs', label: '环境变量', value: 0, icon: 'ri:settings-3-line', iconBg: '!bg-[#8b5cf6] !text-white' },
])

// ── 任务状态分布 ──
const cronStats = reactive({ running: 0, idle: 0, disabled: 0, runningPercent: 0 })

// ── 脚本统计 ──
const scriptTotal = ref(0)
const scriptStats = reactive({ jsPercent: 0 })

// ── 系统健康 ──
const healthChecks = reactive([
  { key: 'api', label: 'API 服务', ok: true, errMsg: '' },
  { key: 'db', label: '数据库连接', ok: true, errMsg: '' },
  { key: 'ws', label: 'WebSocket', ok: true, errMsg: '' },
])

// ── 系统信息 ──
const sysInfo = reactive<Record<string, any>>({})
const sysInfoItems = computed(() => [
  { key: 'version', label: '青龙版本', value: sysInfo.version || '-' },
  { key: 'os', label: '运行环境', value: sysInfo.os || '-' },
  { key: 'node', label: 'Node.js', value: sysInfo.nodeVersion || '-' },
  { key: 'arch', label: 'CPU架构', value: sysInfo.arch || '-' },
  { key: 'uptime', label: '运行时长', value: sysInfo.uptime || '-' },
  { key: 'pid', label: 'PID', value: sysInfo.pid || '-' },
  { key: 'db', label: '数据库', value: sysInfo.dbType || 'SQLite' },
  { key: 'scheduler', label: '调度器', value: sysInfo.scheduler || '-' },
])

// ── 资源使用 ──
const resources = reactive([
  { key: 'cpu', label: 'CPU 使用率', used: 0, display: '0%' },
  { key: 'memory', label: '内存使用率', used: 0, display: '0%' },
  { key: 'disk', label: '磁盘使用率', used: 0, display: '0%' },
])

const loadSystemInfo = async () => {
  sysLoading.value = true
  try {
    const res = await request.get<any>({ url: '/api/system' })
    Object.assign(sysInfo, res || {})
    if (sysInfo.uptime && typeof sysInfo.uptime === 'number') {
      const d = Math.floor(sysInfo.uptime / 86400), h = Math.floor((sysInfo.uptime % 86400) / 3600), m = Math.floor((sysInfo.uptime % 3600) / 60)
      sysInfo.uptime = `${d}d ${h}h ${m}m`
    }
    if (sysInfo.memory) {
      const mem = sysInfo.memory as any
      if (mem.total && mem.used) { resources[1].used = Math.round((mem.used / mem.total) * 100); resources[1].display = `${resources[1].used}%` }
    }
    if (sysInfo.disk) {
      const disk = sysInfo.disk as any
      if (disk.total && disk.used) { resources[2].used = Math.round((disk.used / disk.total) * 100); resources[2].display = `${resources[2].used}%` }
    }
    healthChecks[0].ok = true
  } catch { healthChecks[0].ok = false; healthChecks[0].errMsg = 'API异常' }
  finally { sysLoading.value = false }
}

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

    // 任务状态分布
    cronStats.running = crons.filter((c: any) => c.status === 0 && !c.isDisabled).length
    cronStats.idle = crons.filter((c: any) => c.status !== 0 && !c.isDisabled).length
    cronStats.disabled = crons.filter((c: any) => c.isDisabled).length
    cronStats.runningPercent = crons.length > 0 ? Math.round((cronStats.running / crons.length) * 100) : 0

    // 脚本类型统计
    if (Array.isArray(scripts)) {
      scriptTotal.value = scripts.length
      const jsCount = scripts.filter((s: any) => {
        const name = (s.title || s.name || '').toLowerCase()
        return name.endsWith('.js') || name.endsWith('.ts') || name.endsWith('.mjs')
      }).length
      scriptStats.jsPercent = scripts.length > 0 ? Math.round((jsCount / scripts.length) * 100) : 0
    }
  } catch {}
}

const recentTasks = ref<any[]>([])
const taskLoading = ref(false)
const loadRecentTasks = async () => {
  taskLoading.value = true
  try {
    const res = await request.get<any>({ url: '/api/crons', params: { searchValue: '' } })
    const list = Array.isArray(res) ? res : (res?.data || [])
    recentTasks.value = list
      .filter((c: any) => c.last_execution_time)
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

const quickLinks = [
  { label: '定时任务', path: '/crontab', icon: 'ri:timer-line' },
  { label: '脚本管理', path: '/script', icon: 'ri:code-box-line' },
  { label: '环境变量', path: '/env', icon: 'ri:settings-3-line' },
  { label: '日志管理', path: '/log', icon: 'ri:file-text-line' },
  { label: '系统设置', path: '/setting', icon: 'ri:settings-2-line' },
]
const goPage = (path: string) => router.push(path)

onMounted(() => { loadSystemInfo(); loadStats(); loadRecentTasks() })
</script>

<style scoped>
.dashboard-table :deep(.el-table__row:last-child td) { border-bottom: none; }
.space-y-3 > * + * { margin-top: 12px; }
</style>
