<!-- 登录页面 - 已适配青龙面板 API -->
<template>
  <div class="flex w-full h-screen">
    <LoginLeftView />

    <div class="relative flex-1">
      <AuthTopBar />

      <div class="auth-right-wrap">
        <div class="form">
          <h3 class="title">青龙面板</h3>
          <p class="sub-title">QingLong Panel</p>

          <ElForm
            ref="formRef"
            :model="formData"
            :rules="rules"
            :key="formKey"
            @keyup.enter="handleSubmit"
            style="margin-top: 25px"
          >
            <ElFormItem prop="username">
              <ElInput
                class="custom-height"
                placeholder="用户名"
                v-model.trim="formData.username"
              />
            </ElFormItem>
            <ElFormItem prop="password">
              <ElInput
                class="custom-height"
                placeholder="密码"
                v-model.trim="formData.password"
                type="password"
                autocomplete="off"
                show-password
              />
            </ElFormItem>

            <!-- 双因素验证码 -->
            <ElFormItem v-if="show2FA" prop="twoFactorCode">
              <ElInput
                class="custom-height"
                placeholder="请输入6位验证码"
                v-model.trim="formData.twoFactorCode"
                maxlength="6"
              />
            </ElFormItem>

            <!-- 错误提示 -->
            <div v-if="errorMsg" style="margin-bottom: 12px">
              <ElAlert :title="errorMsg" type="error" show-icon :closable="true" @close="errorMsg = ''" />
            </div>

            <!-- 重试倒计时 -->
            <div v-if="retrySeconds > 0" style="text-align: center; color: #e6a23c; font-size: 13px; margin-bottom: 10px">
              登录过于频繁，请 {{ retrySeconds }} 秒后重试
            </div>

            <div style="margin-top: 30px">
              <ElButton
                class="w-full custom-height"
                type="primary"
                @click="handleSubmit"
                :loading="loading"
                :disabled="retrySeconds > 0"
                v-ripple
              >
                {{ show2FA ? '验证并登录' : '登 录' }}
              </ElButton>
            </div>
          </ElForm>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useUserStore } from '@/store/modules/user'
import { useI18n } from 'vue-i18n'
import { HttpError } from '@/utils/http/error'
import { fetchLogin } from '@/api/auth'
import type { FormInstance, FormRules } from 'element-plus'

defineOptions({ name: 'Login' })

const { locale } = useI18n()
const formKey = ref(0)

// 监听语言切换，重置表单
watch(locale, () => {
  formKey.value++
})

const userStore = useUserStore()
const router = useRouter()
const route = useRoute()

const formRef = ref<FormInstance>()
const loading = ref(false)
const show2FA = ref(false)
const errorMsg = ref('')
const retrySeconds = ref(0)
let retryTimer: ReturnType<typeof setInterval> | null = null

const formData = reactive({
  username: '',
  password: '',
  twoFactorCode: ''
})

const rules = computed<FormRules>(() => ({
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }]
}))

// 暂存登录信息用于 2FA
const loginInfo = ref<{ username: string; password: string } | null>(null)

// 登录
const handleSubmit = async () => {
  if (!formRef.value) return

  // 表单校验 (校验失败 Element Plus 自动显示字段错误, 不需要额外处理)
  try {
    await formRef.value.validate()
  } catch {
    // 表单校验不通过, 字段上已有红色提示, 直接返回
    return
  }

  loading.value = true
  errorMsg.value = ''

  try {
    if (show2FA.value) {
      // 双因素验证：发送原始凭证 + 验证码
      const { token, refreshToken } = await fetchLogin({
        userName: loginInfo.value!.username,
        password: loginInfo.value!.password,
        twoFactorCode: formData.twoFactorCode
      })
      if (token) {
        handleLoginSuccess(token, refreshToken)
        return
      }
    }

    // 常规登录
    const { token, refreshToken } = await fetchLogin({
      userName: formData.username,
      password: formData.password
    })

    if (token) {
      handleLoginSuccess(token, refreshToken)
    }
  } catch (error: any) {
    handleLoginError(error)
  } finally {
    loading.value = false
  }
}

// 登录成功
const handleLoginSuccess = (token: string, refreshToken?: string) => {
  userStore.setToken(`Bearer ${token}`, refreshToken)
  userStore.setLoginStatus(true)
  const redirect = route.query.redirect as string
  router.push(redirect || '/')
}

// 处理登录错误
const handleLoginError = (error: any) => {
  if (error instanceof HttpError) {
    const code = error.code

    switch (code) {
      case 420:
        // 需要双因素验证 - 保存原始凭证
        loginInfo.value = {
          username: formData.username,
          password: formData.password
        }
        show2FA.value = true
        errorMsg.value = '需要双因素验证，请输入验证码'
        break

      case 410: {
        // 登录频率限制
        startRetryCountdown(60)
        errorMsg.value = error.message || '登录过于频繁，请60秒后重试'
        break
      }

      case 400:
        errorMsg.value = error.message || '用户名或密码错误'
        break

      default:
        errorMsg.value = error.message || '登录失败，请重试'
    }
  } else {
    errorMsg.value = '网络错误，请检查后端连接'
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
@import './style.css';
</style>

<style lang="scss" scoped>
:deep(.el-select__wrapper) {
  height: 40px !important;
}
</style>
