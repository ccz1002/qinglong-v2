<!-- 青龙面板 - 登录页面 -->
<template>
  <div class="ql-login-container">
    <div class="ql-login-card">
      <h2 class="ql-login-title">青龙面板</h2>
      <p class="ql-login-subtitle">QingLong Panel</p>

      <ElForm
        ref="formRef"
        :model="formData"
        :rules="rules"
        @keyup.enter="handleLogin"
        class="ql-login-form"
      >
        <!-- 用户名 -->
        <ElFormItem prop="username">
          <ElInput
            size="large"
            placeholder="用户名"
            v-model="formData.username"
            :prefix-icon="User"
          />
        </ElFormItem>

        <!-- 密码 -->
        <ElFormItem prop="password">
          <ElInput
            size="large"
            placeholder="密码"
            v-model="formData.password"
            type="password"
            show-password
            :prefix-icon="Lock"
          />
        </ElFormItem>

        <!-- 双因素验证码 (2FA) -->
        <ElFormItem v-if="show2FA" prop="twoFactorCode">
          <ElInput
            size="large"
            placeholder="请输入6位验证码"
            v-model="formData.twoFactorCode"
            maxlength="6"
          />
        </ElFormItem>

        <!-- 错误提示 -->
        <ElAlert
          v-if="errorMsg"
          :title="errorMsg"
          type="error"
          show-icon
          :closable="true"
          @close="errorMsg = ''"
          style="margin-bottom: 16px"
        />

        <!-- 倒计时提示 -->
        <div v-if="retrySeconds > 0" class="ql-retry-tip">
          登录过于频繁，请 {{ retrySeconds }} 秒后重试
        </div>

        <!-- 登录按钮 -->
        <ElButton
          type="primary"
          size="large"
          class="ql-login-btn"
          :loading="loading"
          :disabled="retrySeconds > 0"
          @click="handleLogin"
        >
          {{ show2FA ? '验证并登录' : '登 录' }}
        </ElButton>
      </ElForm>
    </div>
  </div>
</template>

<script setup lang="ts">
import { User, Lock } from '@element-plus/icons-vue'
import { useUserStore } from '@/store/modules/user'
import { HttpError } from '@/utils/http/error'
import { qlAuthApi } from '@/api/modules/qinglong'
import type { FormInstance, FormRules } from 'element-plus'

defineOptions({ name: 'QingLongLogin' })

const userStore = useUserStore()
const router = useRouter()
const route = useRoute()

const formRef = ref<FormInstance>()
const loading = ref(false)
const show2FA = ref(false)
const errorMsg = ref('')
const retrySeconds = ref(0)
let retryTimer: ReturnType<typeof setInterval> | null = null
let twoFactorToken = '' // 存储 2FA 中间 token

const formData = reactive({
  username: '',
  password: '',
  twoFactorCode: ''
})

const rules: FormRules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }],
  twoFactorCode: [
    {
      validator: (_rule, value, callback) => {
        if (show2FA.value && !value) {
          callback(new Error('请输入6位验证码'))
        } else {
          callback()
        }
      },
      trigger: 'blur'
    }
  ]
}

// 登录处理
const handleLogin = async () => {
  if (!formRef.value) return

  try {
    const valid = await formRef.value.validate()
    if (!valid) return

    loading.value = true
    errorMsg.value = ''

    if (show2FA.value) {
      // 双因素验证
      await qlAuthApi.twoFactorLogin({
        code: formData.twoFactorCode,
        token: twoFactorToken
      })
    } else {
      // 常规登录
      const res = await qlAuthApi.login(formData.username, formData.password)
      if (res && res.token) {
        // 登录成功
        handleLoginSuccess(res.token)
        return
      }
    }
  } catch (error: any) {
    handleLoginError(error)
  } finally {
    loading.value = false
  }
}

// 处理登录成功
const handleLoginSuccess = async (token: string) => {
  // 青龙面板的 token 以 "Bearer " 前缀存储
  userStore.setToken(`Bearer ${token}`)
  userStore.setLoginStatus(true)

  try {
    // 获取用户信息
    const userInfo = await qlAuthApi.getUserInfo()
    userStore.setUserInfo({
      userName: userInfo.username,
      avatar: userInfo.avatar || '',
      userId: userInfo.username
    } as any)
  } catch {
    // 用户信息获取失败不影响登录
  }

  // 跳转到目标页面
  const redirect = route.query.redirect as string
  router.push(redirect || '/')
}

// 处理登录错误
const handleLoginError = (error: any) => {
  if (error instanceof HttpError) {
    const code = error.code

    switch (code) {
      case 420:
        // 需要双因素验证 - 420 返回 data 中包含 token
        // 从原始响应中获取临时 token
        twoFactorToken = formData.password // 暂存
        show2FA.value = true
        errorMsg.value = '需要双因素验证，请输入验证码'
        break

      case 410:
        // 登录频率限制
        startRetryCountdown(60)
        errorMsg.value = error.message || '登录过于频繁，请60秒后重试'
        break

      case 400:
        errorMsg.value = error.message || '用户名或密码错误'
        break

      default:
        errorMsg.value = error.message || '登录失败，请重试'
    }
  } else {
    errorMsg.value = '网络错误，请检查连接'
  }
}

// 重试倒计时
const startRetryCountdown = (seconds: number) => {
  retrySeconds.value = seconds
  if (retryTimer) clearInterval(retryTimer)
  retryTimer = setInterval(() => {
    retrySeconds.value--
    if (retrySeconds.value <= 0) {
      if (retryTimer) clearInterval(retryTimer)
      retryTimer = null
    }
  }, 1000)
}

onUnmounted(() => {
  if (retryTimer) clearInterval(retryTimer)
})
</script>

<style scoped>
.ql-login-container {
  width: 100%;
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.ql-login-card {
  width: 400px;
  padding: 40px;
  background: var(--art-bg-color, #fff);
  border-radius: 12px;
  box-shadow: 0 8px 40px rgba(0, 0, 0, 0.15);
}

.ql-login-title {
  text-align: center;
  font-size: 24px;
  font-weight: 600;
  color: var(--art-text-color, #333);
  margin-bottom: 4px;
}

.ql-login-subtitle {
  text-align: center;
  font-size: 14px;
  color: var(--art-text-color-secondary, #999);
  margin-bottom: 30px;
}

.ql-login-form {
  width: 100%;
}

.ql-login-btn {
  width: 100%;
  height: 44px;
}

.ql-retry-tip {
  text-align: center;
  color: #e6a23c;
  font-size: 13px;
  margin-bottom: 10px;
}
</style>
