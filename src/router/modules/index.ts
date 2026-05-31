import { AppRouteRecord } from '@/types/router'
import { qinglongRoutes } from './qinglong'

/**
 * 导出青龙面板路由模块
 */
export const routeModules: AppRouteRecord[] = [
  ...qinglongRoutes
]
