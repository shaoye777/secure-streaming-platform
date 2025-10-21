import { TUNNEL_CONFIG } from '../config/tunnel-config.js';

export class TunnelRouter {
  /**
   * 智能路由策略 - 考虑隧道、代理和地理位置
   */
  static async getOptimalEndpoints(env, request = null) {
    // 检查用户地理位置
    const country = request?.cf?.country;
    const isChina = country === 'CN';
    
    // 1. 首先检查隧道配置
    const tunnelEnabled = await TUNNEL_CONFIG.getTunnelEnabled(env);
    
    if (tunnelEnabled) {
      return {
        type: 'tunnel',
        endpoints: TUNNEL_CONFIG.TUNNEL_ENDPOINTS,
        reason: `隧道已启用 (${country || 'unknown'})`
      };
    }
    
    // 2. 隧道禁用时，检查代理状态
    try {
      const proxyConfig = await env.YOYO_USER_DB.get('proxy_config', 'json');
      if (proxyConfig && proxyConfig.enabled && proxyConfig.activeProxyId) {
        // 代理已启用，使用Workers代理模式（通过直连端点但走代理路径）
        return {
          type: 'proxy',
          endpoints: TUNNEL_CONFIG.DIRECT_ENDPOINTS, // 使用直连端点
          reason: `代理已启用 - 透明代理模式 (${country || 'unknown'})`
        };
      }
    } catch (error) {
      console.warn('Failed to check proxy config:', error);
    }
    
    // 3. 隧道和代理都禁用，使用直连
    return {
      type: 'direct',
      endpoints: TUNNEL_CONFIG.DIRECT_ENDPOINTS,
      reason: `直连模式 - 隧道和代理均禁用 (${country || 'unknown'})`
    };
  }
  
  /**
   * 构造URL - 异步操作，支持地理路由
   */
  static async buildVPSUrl(env, path = '', service = 'API', request = null) {
    const routing = await this.getOptimalEndpoints(env, request);
    const baseUrl = routing.endpoints[service];
    const cleanPath = path.startsWith('/') ? path : `/${path}`;
    
    return {
      url: `${baseUrl}${cleanPath}`,
      routing: routing
    };
  }
  
  /**
   * 故障转移到直连
   */
  static getDirectEndpoints() {
    return {
      type: 'direct',
      endpoints: TUNNEL_CONFIG.DIRECT_ENDPOINTS,
      reason: '隧道故障，切换到直连模式'
    };
  }
  
  /**
   * 健康检查
   */
  static async checkTunnelHealth() {
    try {
      const start = Date.now();
      const response = await fetch(`${TUNNEL_CONFIG.TUNNEL_ENDPOINTS.HEALTH}/health`);
      return {
        status: response.ok ? 'healthy' : 'unhealthy',
        latency: Date.now() - start,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      return {
        status: 'error',
        error: error.message,
        timestamp: new Date().toISOString()
      };
    }
  }
}
