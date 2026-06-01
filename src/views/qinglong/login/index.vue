<!-- 青龙面板 - 登录页面 -->
<template>
  <div class="ql-login-container">
    <div class="ql-login-card">
      <div class="ql-login-brand">
        <ArtSvgIcon icon="ri:terminal-box-line" class="text-4xl text-white mb-2" />
        <h2 class="ql-login-title">青龙面板</h2>
        <p class="ql-login-subtitle">QingLong Panel</p>
      </div>

      <ElForm ref="formRef" :model="formData" :rules="rules" @keyup.enter="handleLogin" class="ql-login-form">
        <ElFormItem prop="username">
          <ElInput size="large" placeholder="用户名" v-model="formData.username">
            <template #prefix><ArtSvgIcon icon="ri:user-3-line" class="text-g-400" /></template>
          </ElInput>
        </ElFormItem>

        <ElFormItem prop="password">
          <ElInput size="large" placeholder="密码" v-model="formData.password" type="password" show-password>
            <template #prefix><ArtSvgIcon icon="ri:lock-line" class="text-g-400" /></template>
          </ElInput>
        </ElFormItem>

        <ElFormItem v-if="show2FA" prop="twoFactorCode">
          <ElInput size="large" placeholder="6位验证码" v-model="formData.twoFactorCode" maxlength="6">
            <template #prefix><ArtSvgIcon icon="ri:shield-keyhole-line" class="text-g-400" /></template>
          </ElInput>
        </ElFormItem>

        <ElAlert v-if="errorMsg" :title="errorMsg" type="error" show-icon :closable="true" @close="errorMsg = ''" class="mb-4" />

        <div v-if="retrySeconds > 0" class="ql-retry-tip">
          <ArtSvgIcon icon="ri:timer-line" class="mr-1" />登录过于频繁，请 {{ retrySeconds }} 秒后重试
        </div>

        <ElButton type="primary" size="large" class="ql-login-btn" :loading="loading" :disabled="retrySeconds > 0" @click="handleLogin">
          {{ show2FA ? '验证并登录' : '登 录' }}
        </ElButton>
      </ElForm>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useUserStore } from '@/store/modules/user'
import { HttpError } from '@/utils/http/error'
import { qlAuthApi } from '@/api/modules/qinglong'
import type { FormInstance, FormRules } from 'element-plus'

defineOptions({ name: 'QingLongLogin' })

const userStore = useUserStore()
const router = useRouter()
const route = useRoute()

const formRef = ref<FormInstance>()
const loading = ref(false); const show2FA = ref(false)
const errorMsg = ref(''); const retrySeconds = ref(0)
let retryTimer: ReturnType<typeof setInterval> | null = null
let twoFactorToken = ''

const formData = reactive({ username: '', password: '', twoFactorCode: '' })

const rules: FormRules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }],
  twoFactorCode: [{ validator: (_rule, value, callback) => { if (show2FA.value && !value) callback(new Error('请输入6位验证码')); else callback() }, trigger: 'blur' }]
}

const handleLogin = async () => {
  if (!formRef.value) return
  try { const valid = await formRef.value.validate(); if (!valid) return; loading.value = true; errorMsg.value = ''
    if (show2FA.value) { await qlAuthApi.twoFactorLogin({ code: formData.twoFactorCode, token: twoFactorToken }) }
    else { const res = await qlAuthApi.login(formData.username, formData.password); if (res && res.token) { handleLoginSuccess(res.token); return } }
  } catch (error: any) { handleLoginError(error) } finally { loading.value = false }
}

const handleLoginSuccess = async (token: string) => {
  userStore.setToken(`Bearer ${token}`); userStore.setLoginStatus(true)
  try { const userInfo = await qlAuthApi.getUserInfo(); userStore.setUserInfo({ userName: userInfo.username, avatar: userInfo.avatar || '', userId: userInfo.username } as any) } catch { }
  const redirect = route.query.redirect as string; router.push(redirect || '/')
}

const handleLoginError = (error: any) => {
  if (error instanceof HttpError) {
    const code = error.code
    switch (code) {
      case 420: twoFactorToken = formData.password; show2FA.value = true; errorMsg.value = '需要双因素验证，请输入验证码'; break
      case 410: startRetryCountdown(60); errorMsg.value = error.message || '登录过于频繁，请60秒后重试'; break
      case 400: errorMsg.value = error.message || '用户名或密码错误'; break
      default: errorMsg.value = error.message || '登录失败，请重试'
    }
  } else { errorMsg.value = '网络错误，请检查连接' }
}

const startRetryCountdown = (seconds: number) => {
  retrySeconds.value = seconds
  if (retryTimer) clearInterval(retryTimer)
  retryTimer = setInterval(() => { retrySeconds.value--; if (retrySeconds.value <= 0) { if (retryTimer) clearInterval(retryTimer); retryTimer = null } }, 1000)
}

onUnmounted(() => { if (retryTimer) clearInterval(retryTimer) })
</script>

<style scoped>
.ql-login-container {
  width: 100%; height: 100vh; display: flex; align-items: center; justify-content: center;
  background: linear-gradient(135deg, #1a1a2e 0%, #16213e 40%, #0f3460 100%);
}
.ql-login-card {
  width: 400px; padding: 40px 36px; background: rgba(255, 255, 255, 0.97);
  border-radius: 16px; box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  backdrop-filter: blur(10px);
}
.ql-login-brand { text-align: center; margin-bottom: 32px; }
.ql-login-brand .art-svg-icon { color: #409eff; }
.ql-login-title { font-size: 22px; font-weight: 700; color: #1a1a2e; margin: 0 0 2px; }
.ql-login-subtitle { font-size: 13px; color: #909399; margin: 0; }
.ql-login-btn { width: 100%; height: 44px; font-size: 15px; letter-spacing: 4px; }
.ql-retry-tip { display: flex; align-items: center; justify-content: center; color: #e6a23c; font-size: 13px; margin-bottom: 10px; }
</style>
