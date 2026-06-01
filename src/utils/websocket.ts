/**
 * WebSocket 管理器 (基于 SockJS)
 * - 单例模式
 * - 自动重连 (最多5次)
 * - 心跳 30s
 * - 发布/订阅模式
 */
import { useUserStore } from '@/store/modules/user'

let SockJS: any = null
// 动态加载 sockjs-client，避免阻塞页面
import('sockjs-client').then(m => { SockJS = m.default || m }).catch(() => {})

type MessageHandler = (payload: any) => void

class WebSocketManager {
  private sock: any = null
  private url = ''
  private handlers: Map<string, Set<MessageHandler>> = new Map()
  private reconnectCount = 0
  private maxReconnect = 5
  private heartbeatTimer: any = null
  private intentionalClose = false

  private static instance: WebSocketManager
  static getInstance(): WebSocketManager {
    if (!this.instance) this.instance = new WebSocketManager()
    return this.instance
  }

  /** 连接 WebSocket */
  async connect() {
    if (this.sock) return
    if (!SockJS) {
      const mod = await import('sockjs-client')
      SockJS = mod.default || mod
    }

    const store = useUserStore()
    const token = store.accessToken?.replace('Bearer ', '') || ''
    const base = window.location.origin
    this.url = `${base}/api/ws?token=${token}`
    this.intentionalClose = false

    this.sock = new SockJS(this.url, null, { timeout: 15000 })

    this.sock.onopen = () => {
      console.log('[WS] connected')
      this.reconnectCount = 0
      this.startHeartbeat()
      // 重新订阅
      this.handlers.forEach((_, topic) => {
        this.sock.send(JSON.stringify({ type: 'subscribe', topic }))
      })
    }

    this.sock.onmessage = (e: any) => {
      try {
        const msg = JSON.parse(e.data)
        if (msg.type === 'ping' || msg.type === 'heartbeat') return
        const handlers = this.handlers.get(msg.type)
        if (handlers) handlers.forEach(fn => fn(msg))
      } catch {}
    }

    this.sock.onclose = () => {
      console.log('[WS] closed')
      this.stopHeartbeat()
      if (!this.intentionalClose) this.reconnect()
    }

    this.sock.onerror = () => {
      this.stopHeartbeat()
      if (!this.intentionalClose) this.reconnect()
    }
  }

  /** 断开连接 */
  disconnect() {
    this.intentionalClose = true
    this.stopHeartbeat()
    this.handlers.clear()
    if (this.sock) { this.sock.close(); this.sock = null }
  }

  /** 订阅消息 */
  subscribe(topic: string, handler: MessageHandler) {
    if (!this.handlers.has(topic)) this.handlers.set(topic, new Set())
    this.handlers.get(topic)!.add(handler)
    if (this.sock?.readyState === SockJS.OPEN) {
      this.sock.send(JSON.stringify({ type: 'subscribe', topic }))
    }
  }

  /** 取消订阅 */
  unsubscribe(topic: string, handler: MessageHandler) {
    this.handlers.get(topic)?.delete(handler)
  }

  /** 发送消息 */
  send(data: any) {
    if (this.sock?.readyState === SockJS.OPEN) {
      this.sock.send(JSON.stringify(data))
    }
  }

  /** 心跳 */
  private startHeartbeat() {
    this.stopHeartbeat()
    this.heartbeatTimer = setInterval(() => {
      this.send({ type: 'heartbeat' })
    }, 30000)
  }

  private stopHeartbeat() {
    if (this.heartbeatTimer) { clearInterval(this.heartbeatTimer); this.heartbeatTimer = null }
  }

  /** 自动重连 */
  private reconnect() {
    if (this.reconnectCount >= this.maxReconnect) return
    this.reconnectCount++
    this.sock = null
    setTimeout(() => this.connect(), 3000 * this.reconnectCount)
  }
}

export default WebSocketManager
