import request from '@/utils/http'

/** QingLong 登录响应 */
interface LoginResponse {
  token: string
  lastlogon?: string
  lastaddr?: string
  lastip?: string
  retries?: number
}

/** QingLong 用户信息 */
export interface QLUserInfo {
  username: string
  avatar?: string
  twoFactorActivated?: boolean
  twoFactorSecret?: string
}

/** 双因素登录 */
interface TwoFactorLoginParams {
  code: string
  token: string
}

/**
 * 青龙面板认证 API
 */
export const qlAuthApi = {
  /** 登录 */
  login(username: string, password: string) {
    return request.post<LoginResponse>({
      url: '/api/user/login',
      data: { username, password },
      showErrorMessage: false
    })
  },

  /** 双因素验证登录 */
  twoFactorLogin(params: TwoFactorLoginParams) {
    return request.put<LoginResponse>({
      url: '/api/user/two-factor/login',
      data: params
    })
  },

  /** 获取当前用户信息 */
  getUserInfo() {
    return request.get<QLUserInfo>({
      url: '/api/user'
    })
  },

  /** 修改密码 */
  changePassword(data: { username: string; password: string }) {
    return request.put({
      url: '/api/user',
      data
    })
  },

  /** 获取系统信息 */
  getSystemInfo() {
    return request.get<any>({
      url: '/api/system'
    })
  }
}

/** 配置文件 API */
export const qlConfigApi = {
  files() { return request.get<any>({ url: '/api/configs/files' }) },
  detail(path: string) { return request.get<any>({ url: '/api/configs/detail', params: { path } }) },
  save(data: any) { return request.post({ url: '/api/configs/save', data }) },
  samples() { return request.get<any>({ url: '/api/configs/samples' }) },
}

/** 日志 API */
export const qlLogApi = {
  list() { return request.get<any>({ url: '/api/logs' }) },
  detail(file: string, path: string) { return request.get<any>({ url: '/api/logs/detail', params: { file, path } }) },
  remove(file: string, path: string) { return request.del({ url: '/api/logs', data: { filename: file, path } }) },
}

/** 脚本 API */
export const qlScriptApi = {
  list() { return request.get<any>({ url: '/api/scripts' }) },
  detail(file: string) { return request.get<any>({ url: '/api/scripts/detail', params: { file } }) },
  update(data: any) { return request.put({ url: '/api/scripts', data }) },
  run(file: string) { return request.put({ url: '/api/scripts/run', data: { file } }) },
  stop(file: string) { return request.put({ url: '/api/scripts/stop', data: { file } }) },
  rename(data: any) { return request.put({ url: '/api/scripts/rename', data }) },
  remove(file: string) { return request.del({ url: '/api/scripts', data: { file } }) },
}
