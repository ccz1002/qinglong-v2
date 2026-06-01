/**
 * 版本检测 & 在线更新工具
 */
declare const __APP_VERSION__: string
declare const __GIT_HASH__: string
declare const __BUILD_TIME__: string

export interface VersionInfo {
  version: string
  gitHash: string
  buildTime: string
  fullVersion: string
}

/** 获取当前运行的版本信息 */
export function getVersion(): VersionInfo {
  const gitHash = typeof __GIT_HASH__ !== 'undefined' ? __GIT_HASH__ : 'dev'
  const buildTime = typeof __BUILD_TIME__ !== 'undefined' ? __BUILD_TIME__ : new Date().toISOString()
  const version = typeof __APP_VERSION__ !== 'undefined' ? __APP_VERSION__ : '0.0.0'
  return {
    version,
    gitHash,
    buildTime,
    fullVersion: `v${version}-${gitHash}`
  }
}

/** 检查Gitee最新版本 */
export async function checkLatestVersion(): Promise<{ latestHash: string; hasUpdate: boolean }> {
  try {
    const resp = await fetch('https://gitee.com/api/v5/repos/ncuon/qinglong-v2/commits?per_page=1')
    const data = await resp.json()
    const latestHash = (data[0]?.sha || '').substring(0, 7)
    const current = getVersion().gitHash
    return { latestHash, hasUpdate: latestHash && current !== 'dev' && latestHash !== current }
  } catch {
    return { latestHash: '未知', hasUpdate: false }
  }
}
