<template>
  <div class="ql-dashboard">
    <!-- 顶部统计卡片 -->
    <ElRow :gutter="16" class="stats-row">
      <ElCol :xs="24" :sm="12" :md="6" v-for="card in statCards" :key="card.key">
        <ElCard shadow="hover" class="stat-card">
          <div class="flex items-center justify-between">
            <div>
              <p class="stat-label">{{ card.label }}</p>
              <p class="stat-value" :style="{ color: card.color }">{{ card.value }}</p>
            </div>
            <div class="stat-icon" :style="{ background: card.bg }">
              <ArtSvgIcon :icon="card.icon" class="text-2xl" :style="{ color: card.color }" />
            </div>
          </div>
        </ElCard>
      </ElCol>
    </ElRow>

    <ElRow :gutter="16" class="mt-4">
      <!-- 系统信息 -->
      <ElCol :xs="24" :lg="12">
        <ElCard header="系统信息" shadow="hover">
          <template #header>
            <div class="flex items-center justify-between">
              <span>系统信息</span>
              <ElButton size="small" @click="loadSystemInfo" :loading="sysLoading">刷新</ElButton>
            </div>
          </template>
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
        </ElCard>
      </ElCol>

      <!-- 资源使用 -->
      <ElCol :xs="24" :lg="12">
        <ElCard header="资源使用" shadow="hover">
          <div class="resource-item" v-for="res in resources" :key="res.key">
            <div class="flex items-center justify-between mb-1">
              <span class="text-sm">{{ res.label }}</span>
              <span class="text-sm font-medium" :style="{ color: res.used > 80 ? '#f56c6c' : '#67c23a' }">{{ res.display }}</span>
            </div>
            <ElProgress :percentage="Math.min(res.used, 100)" :color="res.used > 80 ? '#f56c6c' : '#409eff'" :stroke-width="10" />
          </div>
        </ElCard>

        <!-- 快捷入口 -->
        <ElCard header="快捷入口" shadow="hover" class="mt-4">
          <div class="quick-links">
            <ElButton v-for="link in quickLinks" :key="link.path" @click="goPage(link.path)" :icon="link.icon" class="mr-3 mb-3">
              {{ link.label }}
            </ElButton>
          </div>
        </ElCard>
      </ElCol>
    </ElRow>

    <ElRow :gutter="16" class="mt-4">
      <!-- 最近执行 -->
      <ElCol :span="24">
        <ElCard header="最近任务执行" shadow="hover">
          <ElTable :data="recentTasks" v-loading="taskLoading" stripe size="small" empty-text="暂无执行记录">
            <ElTableColumn label="时间" width="160">
              <template #default="{ row }">{{ row.timestamp ? new Date(row.timestamp).toLocaleString() : '-' }}</template>
            </ElTableColumn>
            <ElTableColumn prop="taskName" label="任务名称" min-width="160" />
            <ElTableColumn prop="command" label="命令" min-width="120" show-overflow-tooltip />
            <ElTableColumn label="状态" width="80">
              <template #default="{ row }">
                <ElTag :type="row.status === 0 ? 'success' : row.status === 1 ? 'danger' : 'warning'" size="small">
                  {{ ['成功','失败','运行中'][row.status] || '-' }}
                </ElTag>
              </template>
            </ElTableColumn>
            <ElTableColumn label="耗时" width="100">
              <template #default="{ row }">{{ row.duration ? row.duration + 's' : '-' }}</template>
            </ElTableColumn>
          </ElTable>
        </ElCard>
      </ElCol>
    </ElRow>
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
  { key: 'tasks', label: '定时任务', value: 0, icon: 'ri:timer-line', color: '#409eff', bg: '#ecf5ff' },
  { key: 'running', label: '运行中', value: 0, icon: 'ri:play-circle-line', color: '#67c23a', bg: '#f0f9eb' },
  { key: 'scripts', label: '脚本文件', value: 0, icon: 'ri:code-box-line', color: '#e6a23c', bg: '#fdf6ec' },
  { key: 'envs', label: '环境变量', value: 0, icon: 'ri:settings-3-line', color: '#909399', bg: '#f4f4f5' },
])

// ── 系统信息 ──
const sysInfo = reactive<Record<string, any>>({})
const loadSystemInfo = async () => {
  sysLoading.value = true
  try {
    const res = await request.get<any>({ url: '/api/system' })
    Object.assign(sysInfo, res || {})
    // 格式化运行时长
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
  { key: 'cpu', label: 'CPU', used: 0, display: '0%' },
  { key: 'memory', label: '内存', used: 0, display: '0%' },
  { key: 'disk', label: '磁盘', used: 0, display: '0%' },
])

// ── 统计加载 ──
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

    // 资源使用 (简单估算)
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
.ql-dashboard {
  padding: 0;
}

.stats-row {
  margin-bottom: 0;
}

.stat-card {
  border-radius: 8px;
  transition: transform 0.2s;
}
.stat-card:hover {
  transform: translateY(-2px);
}

.stat-label {
  margin: 0 0 8px 0;
  font-size: 13px;
  color: #909399;
}

.stat-value {
  margin: 0;
  font-size: 28px;
  font-weight: 700;
}

.stat-icon {
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 10px;
}

.resource-item {
  margin-bottom: 16px;
}
.resource-item:last-child {
  margin-bottom: 0;
}

.quick-links {
  display: flex;
  flex-wrap: wrap;
}

:deep(.el-descriptions__label) {
  font-weight: 500;
}
</style>
