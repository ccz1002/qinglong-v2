<template>
  <div class="ql-setting">
    <ElTabs v-model="activeTab" type="border-card">
      <!-- 安全设置 -->
      <ElTabPane name="security"><template #label><ArtSvgIcon icon="ri:shield-check-line" class="mr-1.5" />安全设置</template>
        <ElCard header="修改密码">
          <ElForm ref="secFormRef" :model="secForm" :rules="secRules" label-width="100px" style="max-width:400px">
            <ElFormItem label="用户名" prop="username"><ElInput v-model="secForm.username" /></ElFormItem>
            <ElFormItem label="新密码" prop="password"><ElInput v-model="secForm.password" type="password" show-password /></ElFormItem>
            <ElFormItem><ElButton type="primary" @click="changePassword" :loading="secLoading">保存</ElButton></ElFormItem>
          </ElForm>
        </ElCard>

        <ElCard header="两步验证 (2FA)" style="margin-top:16px">
          <div v-if="!twoFactorActivated">
            <p class="text-gray-500 mb-3">开启两步验证后，登录时需要输入6位动态验证码</p>
            <ElButton @click="init2FA" :loading="init2FALoading">初始化两步验证</ElButton>
            <div v-if="twoFactorSecret" class="mt-4">
              <p>密钥: <code>{{ twoFactorSecret }}</code></p>
              <p class="text-sm text-gray-400">请使用 Google Authenticator 或类似应用扫描</p>
              <ElForm ref="twoFAFormRef" class="mt-3" style="max-width:300px" :model="{ code: twoFactorCode }" :rules="{ code: [{ required: true, message: '请输入验证码', trigger: 'blur' }, { min: 6, max: 6, message: '验证码为6位数字', trigger: 'blur' }] }">
                <ElFormItem label="验证码" prop="code">
                  <ElInput v-model="twoFactorCode" placeholder="输入6位验证码" maxlength="6" />
                </ElFormItem>
                <ElButton type="primary" @click="activate2FA" :loading="activate2FALoading">激活</ElButton>
              </ElForm>
            </div>
          </div>
          <div v-else>
            <ElAlert title="两步验证已开启" type="success" :closable="false" />
            <ElButton class="mt-3" type="danger" @click="deactivate2FA">关闭两步验证</ElButton>
          </div>
        </ElCard>
      </ElTabPane>

      <!-- 应用设置 -->
      <ElTabPane name="apps"><template #label><ArtSvgIcon icon="ri:apps-2-line" class="mr-1.5" />应用设置</template>
        <div class="flex justify-between mb-3">
          <span>Open API 应用管理</span>
          <ElButton type="primary" size="small" @click="showAppDialog(null)">+ 添加应用</ElButton>
        </div>
        <ElTable :data="appList" v-loading="appLoading" stripe>
          <ElTableColumn prop="name" label="名称" />
          <ElTableColumn prop="client_id" label="Client ID" min-width="150" />
          <ElTableColumn prop="client_secret" label="Client Secret" min-width="150">
            <template #default="{ row }"><code>{{ row.client_secret?.substring(0, 12) }}...</code></template>
          </ElTableColumn>
          <ElTableColumn label="权限范围" width="200">
            <template #default="{ row }">
              <ElTag v-for="s in (row.scopes || [])" :key="s" size="small" style="margin:2px">{{ s }}</ElTag>
            </template>
          </ElTableColumn>
          <ElTableColumn label="操作" width="200">
            <template #default="{ row }">
              <ElButton size="small" @click="showAppDialog(row)">编辑</ElButton>
              <ElButton size="small" @click="resetAppSecret(row)">重置密钥</ElButton>
              <ElButton size="small" type="danger" @click="deleteApp(row)">删除</ElButton>
            </template>
          </ElTableColumn>
        </ElTable>

        <ElDialog v-model="appDialogVisible" :title="editingApp?.id ? '编辑应用' : '新增应用'" width="450px">
          <ElForm ref="appFormRef" :model="appForm" :rules="appRules" label-width="80px">
            <ElFormItem label="名称" prop="name"><ElInput v-model="appForm.name" /></ElFormItem>
            <ElFormItem label="权限范围" prop="scopes">
              <ElCheckboxGroup v-model="appForm.scopes">
                <ElCheckbox v-for="s in allScopes" :key="s" :label="s" :value="s">{{ s }}</ElCheckbox>
              </ElCheckboxGroup>
            </ElFormItem>
          </ElForm>
          <template #footer><ElButton @click="appDialogVisible=false">取消</ElButton><ElButton type="primary" @click="submitApp" :loading="appSaving">保存</ElButton></template>
        </ElDialog>
      </ElTabPane>

      <!-- 通知设置 -->
      <ElTabPane name="notify"><template #label><ArtSvgIcon icon="ri:notification-3-line" class="mr-1.5" />通知设置</template>
        <ElForm :model="notifyForm" label-width="140px" style="max-width:700px">
          <template v-for="(cfg, mode) in notifyModes" :key="mode">
            <ElDivider content-position="left">{{ modeNames[mode] || mode }}</ElDivider>
            <ElFormItem v-for="(field, key) in cfg" :key="key" :label="field.label || key">
              <ElInput v-model="notifyForm[`${mode}_${key}`]" :placeholder="field.placeholder || ''" />
            </ElFormItem>
          </template>
          <ElFormItem><ElButton type="primary" @click="saveNotify" :loading="notifySaving">保存通知设置</ElButton></ElFormItem>
        </ElForm>
      </ElTabPane>

      <!-- 系统日志 -->
      <ElTabPane name="syslog"><template #label><ArtSvgIcon icon="ri:file-search-line" class="mr-1.5" />系统日志</template>
        <div class="flex gap-2 mb-3">
          <ElDatePicker v-model="syslogDateRange" type="datetimerange" range-separator="至" start-placeholder="开始" end-placeholder="结束" />
          <ElButton @click="loadSyslog">查询</ElButton>
          <ElButton type="danger" @click="clearSyslog">清空日志</ElButton>
        </div>
        <pre class="syslog-content" v-if="syslogText">{{ syslogText }}</pre>
        <ElEmpty v-else description="选择时间范围查看系统日志" />
      </ElTabPane>

      <!-- 登录日志 -->
      <ElTabPane name="loginlog"><template #label><ArtSvgIcon icon="ri:login-box-line" class="mr-1.5" />登录日志</template>
        <ElTable :data="loginLogs" v-loading="loginLogLoading" stripe>
          <ElTableColumn label="时间" width="170">
            <template #default="{ row }">{{ row.timestamp ? new Date(row.timestamp).toLocaleString() : '-' }}</template>
          </ElTableColumn>
          <ElTableColumn prop="address" label="地点" />
          <ElTableColumn prop="ip" label="IP" width="140" />
          <ElTableColumn prop="platform" label="设备" width="100" />
          <ElTableColumn label="状态" width="80">
            <template #default="{ row }"><ElTag :type="row.status===0?'success':'danger'">{{ row.status===0?'成功':'失败' }}</ElTag></template>
          </ElTableColumn>
        </ElTable>
      </ElTabPane>

      <!-- 依赖设置 -->
      <ElTabPane name="depconfig"><template #label><ArtSvgIcon icon="ri:archive-line" class="mr-1.5" />依赖设置</template>
        <ElForm :model="depConfig" label-width="140px" style="max-width:500px">
          <ElFormItem label="Node 镜像源"><ElInput v-model="depConfig.nodeMirror" placeholder="https://registry.npmmirror.com" /></ElFormItem>
          <ElFormItem label="Python 镜像源"><ElInput v-model="depConfig.pythonMirror" placeholder="https://pypi.tuna.tsinghua.edu.cn/simple" /></ElFormItem>
          <ElFormItem label="Linux 镜像源"><ElInput v-model="depConfig.linuxMirror" /></ElFormItem>
          <ElFormItem label="依赖代理"><ElInput v-model="depConfig.dependenceProxy" placeholder="http://proxy:8080" /></ElFormItem>
          <ElFormItem><ElButton type="primary" @click="saveDepConfig" :loading="depConfigSaving">保存</ElButton></ElFormItem>
        </ElForm>
      </ElTabPane>

      <!-- 其他设置 -->
      <ElTabPane name="other"><template #label><ArtSvgIcon icon="ri:settings-3-line" class="mr-1.5" />其他设置</template>
        <ElForm :model="otherForm" label-width="160px" style="max-width:600px">
          <ElFormItem label="日志删除频率(天)">
            <ElInputNumber v-model="otherForm.logRemoveFrequency" :min="1" :max="365" />
          </ElFormItem>
          <ElFormItem label="定时任务并发数">
            <ElInputNumber v-model="otherForm.cronConcurrency" :min="1" :max="50" />
          </ElFormItem>
          <ElFormItem label="时区">
            <ElSelect v-model="otherForm.timezone" filterable>
              <ElOption v-for="tz in timezones" :key="tz" :label="tz" :value="tz" />
            </ElSelect>
          </ElFormItem>
          <ElFormItem label="全局SSH密钥">
            <ElInput v-model="otherForm.globalSshKey" type="textarea" :rows="4" placeholder="粘贴SSH私钥内容" />
          </ElFormItem>
          <ElFormItem><ElButton type="primary" @click="saveOtherConfig" :loading="otherSaving">保存设置</ElButton></ElFormItem>
        </ElForm>

        <ElDivider>数据备份与恢复</ElDivider>
        <div class="flex gap-2">
          <ElButton @click="exportData" :loading="exporting">导出数据备份</ElButton>
          <ElButton @click="checkUpdate" :loading="checking">检查更新</ElButton>
          <ElButton type="warning" @click="doUpdate" :loading="updating">更新系统</ElButton>
        </div>
      </ElTabPane>
    </ElTabs>
  </div>
</template>

<script setup lang="ts">
import { useRoute } from 'vue-router'
import request from '@/utils/http'
import { ElMessage, ElMessageBox } from 'element-plus'

defineOptions({ name: 'QlSetting' })

const route = useRoute()
const activeTab = ref((route.query.tab as string) || 'security')
watch(() => route.query.tab, (tab) => { if (tab) activeTab.value = tab as string })

// ==================== 安全设置 ====================
const secFormRef = ref()
const secForm = reactive({ username: '', password: '' })
const secRules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }]
}
const secLoading = ref(false)
const twoFactorActivated = ref(false)
const twoFactorSecret = ref('')
const twoFactorCode = ref('')
const init2FALoading = ref(false)
const activate2FALoading = ref(false)

const loadUserInfo = async () => {
  try {
    const res = await request.get<any>({ url: '/api/user' })
    secForm.username = res?.username || ''
    twoFactorActivated.value = res?.twoFactorActivated || false
  } catch {}
}

const changePassword = async () => {
  if (!secFormRef.value) return
  try { await secFormRef.value.validate() } catch { return }
  secLoading.value = true
  try { await request.put({ url: '/api/user', data: secForm }); ElMessage.success('密码已更新') }
  catch (e: any) { ElMessage.error(e?.message || '修改失败') }
  finally { secLoading.value = false }
}

const init2FA = async () => {
  init2FALoading.value = true
  try {
    const res = await request.get<any>({ url: '/api/user/two-factor/init' })
    twoFactorSecret.value = res?.secret || ''
  } catch (e: any) { ElMessage.error(e?.message || '初始化失败') }
  finally { init2FALoading.value = false }
}

const twoFAFormRef = ref()
const activate2FA = async () => {
  if (!twoFAFormRef.value) return
  try { await twoFAFormRef.value.validate() } catch { return }
  activate2FALoading.value = true
  try {
    await request.put({ url: '/api/user/two-factor/active', data: { code: twoFactorCode.value } })
    twoFactorActivated.value = true; ElMessage.success('两步验证已激活')
  } catch (e: any) { ElMessage.error(e?.message || '激活失败') }
  finally { activate2FALoading.value = false }
}

const deactivate2FA = async () => {
  try {
    await ElMessageBox.confirm('确定关闭两步验证？', '警告', { type: 'warning' })
    await request.put({ url: '/api/user/two-factor/deactive' })
    twoFactorActivated.value = false; ElMessage.success('已关闭')
  } catch {}
}

// ==================== 应用设置 ====================
const appList = ref<any[]>([])
const appLoading = ref(false)
const appDialogVisible = ref(false)
const appSaving = ref(false)
const appFormRef = ref()
const editingApp = ref<any>(null)
const appForm = reactive({ name: '', scopes: [] as string[] })
const appRules = { name: [{ required: true, message: '请输入应用名称', trigger: 'blur' }] }
const allScopes = ['crons', 'envs', 'configs', 'scripts', 'logs', 'system']

const loadApps = async () => {
  appLoading.value = true
  try { appList.value = await request.get<any>({ url: '/api/apps' }) || [] }
  catch {}
  finally { appLoading.value = false }
}

const showAppDialog = (row: any | null) => {
  editingApp.value = row
  appForm.name = row?.name || ''
  appForm.scopes = Array.isArray(row?.scopes) ? row.scopes : (typeof row?.scopes === 'string' ? JSON.parse(row.scopes) : [])
  appFormRef.value?.clearValidate()
  appDialogVisible.value = true
}

const submitApp = async () => {
  if (!appFormRef.value) return
  try { await appFormRef.value.validate() } catch { return }
  appSaving.value = true
  try {
    if (editingApp.value?.id) {
      await request.put({ url: '/api/apps', data: { id: editingApp.value.id, name: appForm.name, scopes: appForm.scopes } })
    } else {
      await request.post({ url: '/api/apps', data: appForm })
    }
    ElMessage.success('保存成功'); appDialogVisible.value = false; loadApps()
  } catch (e: any) { ElMessage.error(e?.message || '保存失败') }
  finally { appSaving.value = false }
}

const resetAppSecret = async (row: any) => {
  try {
    await request.put({ url: `/api/apps/${row.id}/reset-secret` })
    ElMessage.success('密钥已重置'); loadApps()
  } catch (e: any) { ElMessage.error(e?.message || '重置失败') }
}

const deleteApp = async (row: any) => {
  try {
    await ElMessageBox.confirm(`删除应用 "${row.name}"？`, '警告', { type: 'warning' })
    await request.del({ url: '/api/apps', data: [row.id] })
    ElMessage.success('已删除'); loadApps()
  } catch {}
}

// ==================== 通知设置 ====================
const notifyForm = reactive<Record<string, string>>({})
const notifySaving = ref(false)
const notifyModes: Record<string, Record<string, any>> = {
  serverChan: { SendKey: { label: 'SendKey' } },
  bark: { deviceKey: { label: 'Device Key' }, server: { label: '服务器地址' } },
  telegramBot: { apiToken: { label: 'Bot Token' }, chatId: { label: 'Chat ID' } },
  dingtalkBot: { token: { label: 'Access Token' }, secret: { label: 'Secret' } },
  weWorkBot: { key: { label: 'Webhook Key' } },
  weWorkApp: { agentId: { label: 'Agent ID' }, corpId: { label: 'Corp ID' }, corpSecret: { label: 'Corp Secret' } },
  feishu: { webhook: { label: 'Webhook URL' } },
  email: { host: { label: 'SMTP服务器' }, port: { label: '端口' }, user: { label: '用户名' }, pass: { label: '密码' } },
  gotify: { server: { label: '服务器地址' }, token: { label: 'Token' } },
  pushPlus: { token: { label: 'Token' } },
  pushDeer: { key: { label: 'Key' } },
  webhook: { url: { label: 'URL' }, method: { label: '方法' }, headers: { label: 'Headers' }, body: { label: 'Body' } },
}
const modeNames: Record<string, string> = {
  serverChan: 'Server酱', bark: 'Bark', telegramBot: 'Telegram', dingtalkBot: '钉钉机器人',
  weWorkBot: '企业微信机器人', weWorkApp: '企业微信应用', feishu: '飞书', email: '邮件',
  gotify: 'Gotify', pushPlus: 'PushPlus', pushDeer: 'PushDeer', webhook: '自定义Webhook'
}

const loadNotifyConfig = async () => {
  try {
    const res = await request.get<any>({ url: '/api/user/notification' })
    if (res && typeof res === 'object') {
      Object.entries(res).forEach(([k, v]) => { notifyForm[k] = String(v || '') })
    }
  } catch {}
}

const saveNotify = async () => {
  notifySaving.value = true
  try { await request.put({ url: '/api/user/notification', data: notifyForm }); ElMessage.success('已保存') }
  catch (e: any) { ElMessage.error(e?.message || '保存失败') }
  finally { notifySaving.value = false }
}

// ==================== 系统日志 ====================
const syslogDateRange = ref<[Date, Date] | null>(null)
const syslogText = ref('')

const loadSyslog = async () => {
  if (!syslogDateRange.value) return
  const [start, end] = syslogDateRange.value
  try {
    const res = await request.get<any>({ url: '/api/system/log', params: { startTime: start.getTime(), endTime: end.getTime() } })
    syslogText.value = typeof res === 'string' ? res : res?.data || JSON.stringify(res)
  } catch {}
}

const clearSyslog = async () => {
  try {
    await ElMessageBox.confirm('确定清空系统日志？', '警告', { type: 'warning' })
    await request.del({ url: '/api/system/log' })
    syslogText.value = ''; ElMessage.success('已清空')
  } catch {}
}

// ==================== 登录日志 ====================
const loginLogs = ref<any[]>([])
const loginLogLoading = ref(false)
const loadLoginLogs = async () => {
  loginLogLoading.value = true
  try { loginLogs.value = await request.get<any>({ url: '/api/user/login-log' }) || [] }
  catch {}
  finally { loginLogLoading.value = false }
}

// ==================== 依赖设置 ====================
const depConfig = reactive({ nodeMirror: '', pythonMirror: '', linuxMirror: '', dependenceProxy: '' })
const depConfigSaving = ref(false)

const loadDepConfig = async () => {
  try {
    const res = await request.get<any>({ url: '/api/system/config' })
    if (res) Object.assign(depConfig, {
      nodeMirror: res.nodeMirror || '', pythonMirror: res.pythonMirror || '',
      linuxMirror: res.linuxMirror || '', dependenceProxy: res.dependenceProxy || ''
    })
  } catch {}
}

const saveDepConfig = async () => {
  depConfigSaving.value = true
  try {
    const tasks = []
    if (depConfig.nodeMirror) tasks.push(request.put({ url: '/api/system/config/node-mirror', data: { nodeMirror: depConfig.nodeMirror } }))
    if (depConfig.pythonMirror) tasks.push(request.put({ url: '/api/system/config/python-mirror', data: { pythonMirror: depConfig.pythonMirror } }))
    if (depConfig.linuxMirror) tasks.push(request.put({ url: '/api/system/config/linux-mirror', data: { linuxMirror: depConfig.linuxMirror } }))
    if (depConfig.dependenceProxy) tasks.push(request.put({ url: '/api/system/config/dependence-proxy', data: { dependenceProxy: depConfig.dependenceProxy } }))
    if (tasks.length === 0) { ElMessage.warning('没有需要保存的修改'); return }
    await Promise.all(tasks)
    ElMessage.success('已保存')
  } catch (e: any) { ElMessage.error(e?.message || '保存失败') }
  finally { depConfigSaving.value = false }
}

// ==================== 其他设置 ====================
const otherForm = reactive({ logRemoveFrequency: 7, cronConcurrency: 5, timezone: 'Asia/Shanghai', globalSshKey: '' })
const otherSaving = ref(false)
const exporting = ref(false)
const checking = ref(false)
const updating = ref(false)
const timezones = ['Asia/Shanghai', 'Asia/Tokyo', 'America/New_York', 'America/Los_Angeles', 'Europe/London', 'Europe/Berlin', 'UTC']

const loadOtherConfig = async () => {
  try {
    const res = await request.get<any>({ url: '/api/system/config' })
    if (res) Object.assign(otherForm, {
      logRemoveFrequency: res.logRemoveFrequency || 7, cronConcurrency: res.cronConcurrency || 5,
      timezone: res.timezone || 'Asia/Shanghai', globalSshKey: res.globalSshKey || ''
    })
  } catch {}
}

const saveOtherConfig = async () => {
  otherSaving.value = true
  try {
    const tasks = []
    if (otherForm.logRemoveFrequency) tasks.push(request.put({ url: '/api/system/config/log-remove-frequency', data: { logRemoveFrequency: otherForm.logRemoveFrequency } }))
    if (otherForm.cronConcurrency) tasks.push(request.put({ url: '/api/system/config/cron-concurrency', data: { cronConcurrency: otherForm.cronConcurrency } }))
    if (otherForm.timezone) tasks.push(
      request.put({ url: '/api/system/config/timezone', data: { timezone: otherForm.timezone } }).catch(() => {
        ElMessage.warning('时区设置需要 Linux 环境，当前 Windows 不支持')
      })
    )
    if (otherForm.globalSshKey) tasks.push(request.put({ url: '/api/system/config/global-ssh-key', data: { key: otherForm.globalSshKey } }))
    if (tasks.length === 0) { ElMessage.warning('没有需要保存的修改'); return }
    await Promise.all(tasks)
    ElMessage.success('已保存（时区除外，Windows 不支持）')
  } catch (e: any) { ElMessage.error(e?.message || '保存失败') }
  finally { otherSaving.value = false }
}

const exportData = async () => {
  exporting.value = true
  try {
    await request.put({ url: '/api/system/data/export', data: {} })
    ElMessage.success('备份已开始')
  } catch (e: any) {
    ElMessage.warning('数据备份需要 Docker/Linux 环境，当前 Windows 下不可用。可手动复制 data/ 目录备份。')
  }
  finally { exporting.value = false }
}

const checkUpdate = async () => {
  checking.value = true
  try { await request.put({ url: '/api/system/update-check' }); ElMessage.success('检查完成') }
  catch (e: any) { ElMessage.error(e?.message || '检查失败') }
  finally { checking.value = false }
}

const doUpdate = async () => {
  try {
    await ElMessageBox.confirm('确定更新系统？更新期间面板可能暂时不可用', '警告', { type: 'warning' })
    updating.value = true
    await request.put({ url: '/api/system/update' })
    ElMessage.success('更新已触发')
  } catch (e: any) {
    if (e !== 'cancel') ElMessage.error(e?.message || '更新失败')
  }
  finally { updating.value = false }
}

// 初始化所有数据
onMounted(() => {
  loadUserInfo()
  loadApps()
  loadNotifyConfig()
  loadLoginLogs()
  loadDepConfig()
  loadOtherConfig()
})
</script>

<style scoped>
.ql-setting { padding: 0; }
.syslog-content {
  background: #1e1e1e; color: #d4d4d4; padding: 16px;
  border-radius: 6px; font-family: monospace; font-size: 13px;
  max-height: 500px; overflow: auto; white-space: pre-wrap;
}
</style>
@media (max-width: 768px) {
  .el-tabs__nav { flex-wrap: wrap; }
  .el-form { max-width: 100% !important; }
  .el-descriptions { font-size: 12px; }
}
