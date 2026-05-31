import request from '@/utils/http'

/**
 * 登录
 * @param params 登录参数
 * @returns 登录响应
 */
export function fetchLogin(params: Api.Auth.LoginParams) {
  // 双因素验证: 发送原始凭证 + 验证码
  if (params.twoFactorCode) {
    return request.post<Api.Auth.LoginResponse>({
      url: '/api/user/two-factor/login',
      data: { username: params.userName, password: params.password, code: params.twoFactorCode },
      showErrorMessage: false
    })
  }
  // 常规登录
  return request.post<Api.Auth.LoginResponse>({
    url: '/api/user/login',
    data: { username: params.userName, password: params.password },
    showErrorMessage: false
  })
}

/**
 * 获取用户信息 (青龙面板)
 * @returns 用户信息
 */
export function fetchGetUserInfo() {
  return request.get<any>({
    url: '/api/user'
  }).then(res => ({
    userId: res?.username || 'admin',
    userName: res?.username || 'admin',
    avatar: res?.avatar || '',
    roles: ['R_ADMIN'],
    permissions: ['*']
  } as Api.Auth.UserInfo))
}

/**
 * 获取系统信息 (青龙面板)
 */
export function fetchSystemInfo() {
  return request.get<any>({
    url: '/api/system'
  })
}
