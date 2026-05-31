import { AppRouteRecord } from '@/types/router'

/** 青龙面板 - 侧边栏菜单路由 */
export const qinglongRoutes: AppRouteRecord[] = [
  {
    name: 'Crontab',
    path: '/crontab',
    component: '/qinglong/crontab/index',
    meta: {
      title: '定时任务',
      icon: 'ri:timer-line',
      keepAlive: true
    }
  },
  {
    name: 'Subscription',
    path: '/subscription',
    component: '/qinglong/subscription/index',
    meta: {
      title: '订阅管理',
      icon: 'ri:git-repository-line',
      keepAlive: true
    }
  },
  {
    name: 'Env',
    path: '/env',
    component: '/qinglong/env/index',
    meta: {
      title: '环境变量',
      icon: 'ri:settings-3-line',
      keepAlive: true
    }
  },
  {
    name: 'Config',
    path: '/config',
    component: '/qinglong/config/index',
    meta: {
      title: '配置文件',
      icon: 'ri:file-list-3-line',
      keepAlive: true
    }
  },
  {
    name: 'Script',
    path: '/script',
    component: '/qinglong/script/index',
    meta: {
      title: '脚本管理',
      icon: 'ri:code-box-line',
      keepAlive: true
    }
  },
  {
    name: 'Dependence',
    path: '/dependence',
    component: '/qinglong/dependence/index',
    meta: {
      title: '依赖管理',
      icon: 'ri:archive-line',
      keepAlive: true
    }
  },
  {
    name: 'Log',
    path: '/log',
    component: '/qinglong/log/index',
    meta: {
      title: '日志管理',
      icon: 'ri:file-text-line',
      keepAlive: true
    }
  },
  {
    name: 'Diff',
    path: '/diff',
    component: '/qinglong/diff/index',
    meta: {
      title: '对比工具',
      icon: 'ri:file-diff-line',
      keepAlive: true
    }
  },
  {
    name: 'Setting',
    path: '/setting',
    component: '/qinglong/setting/index',
    meta: {
      title: '系统设置',
      icon: 'ri:settings-2-line',
      keepAlive: true
    }
  }
]
