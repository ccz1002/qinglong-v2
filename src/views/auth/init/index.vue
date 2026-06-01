<template>
  <div class="flex w-full h-screen">
    <LoginLeftView />
    <div class="relative flex-1">
      <AuthTopBar />
      <div class="auth-right-wrap">
        <div class="form">
          <h3 class="title">青龙面板</h3>
          <p class="sub-title">首次使用，请设置管理员账号</p>

          <ElForm ref="formRef" :model="form" :rules="rules" style="margin-top:25px">
            <ElFormItem prop="username">
              <ElInput class="custom-height" placeholder="用户名" v-model.trim="form.username" />
            </ElFormItem>
            <ElFormItem prop="password">
              <ElInput class="custom-height" placeholder="密码" v-model.trim="form.password" type="password" show-password autocomplete="new-password" />
            </ElFormItem>
            <ElFormItem prop="confirm">
              <ElInput class="custom-height" placeholder="确认密码" v-model.trim="form.confirm" type="password" show-password autocomplete="new-password" />
            </ElFormItem>
            <div v-if="errorMsg" style="margin-bottom:12px">
              <ElAlert :title="errorMsg" type="error" show-icon :closable="true" @close="errorMsg=''" />
            </div>
            <div style="margin-top:30px">
              <ElButton class="w-full custom-height" type="primary" @click="handleInit" :loading="loading">初始化</ElButton>
            </div>
          </ElForm>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import request from '@/utils/http'
import type { FormInstance, FormRules } from 'element-plus'

defineOptions({ name: 'Init' })

const router = useRouter()
const formRef = ref<FormInstance>()
const loading = ref(false)
const errorMsg = ref('')

const form = reactive({ username: '', password: '', confirm: '' })
const validateConfirm = (_rule: any, value: string, callback: any) => {
  if (value !== form.password) callback(new Error('两次密码不一致'))
  else callback()
}
const rules: FormRules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }],
  confirm: [
    { required: true, message: '请确认密码', trigger: 'blur' },
    { validator: validateConfirm, trigger: 'blur' }
  ]
}

const handleInit = async () => {
  if (!formRef.value) return
  try { await formRef.value.validate() } catch { return }
  loading.value = true; errorMsg.value = ''
  try {
    await request.put({ url: '/api/user/init', data: { username: form.username, password: form.password } })
    ElMessage.success('初始化成功，请登录')
    router.push({ name: 'Login' })
  } catch (e: any) { errorMsg.value = e?.message || '初始化失败' }
  finally { loading.value = false }
}

// 如果已初始化，跳登录页
onMounted(async () => {
  try {
    const res = await request.get<any>({ url: '/api/system' })
    if (res?.isInitialized) router.replace({ name: 'Login' })
  } catch {}
})
</script>

<style scoped>
@import '../login/style.css';
</style>
