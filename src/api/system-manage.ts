import request from '@/utils/http'
import { AppRouteRecord } from '@/types/router'

// 获取用户列表
export function fetchGetUserList(params: Api.SystemManage.UserSearchParams) {
  return request.get<Api.SystemManage.UserList>({
    url: '/api/user/list',
    params
  })
}

// 获取角色列表
export function fetchGetRoleList(params: Api.SystemManage.RoleSearchParams) {
  return request.get<Api.SystemManage.RoleList>({
    url: '/api/role/list',
    params
  })
}

// 获取菜单列表 (青龙面板后端 API)
export function fetchGetMenuList() {
  return request.get<AppRouteRecord[]>({
    url: '/api/menus'
  })
}

// 创建菜单
export function fetchCreateMenu(data: any) {
  return request.post({
    url: '/api/menus',
    data
  })
}

// 更新菜单
export function fetchUpdateMenu(id: number, data: any) {
  return request.put({
    url: `/api/menus/${id}`,
    data
  })
}

// 删除菜单
export function fetchDeleteMenu(id: number) {
  return request.del({
    url: `/api/menus/${id}`
  })
}
