// 环境变量配置 - 零KV消耗
export const TUNNEL_CONFIG = {
  // 隧道端点 (主要)
  TUNNEL_ENDPOINTS: {
    API: 'https://tunnel-api.yoyo-vps.5202021.xyz',
    HLS: 'https://tunnel-hls.yoyo-vps.5202021.xyz',
    HEALTH: 'https://tunnel-health.yoyo-vps.5202021.xyz'
  },
  // 直连端点 (备用)
  DIRECT_ENDPOINTS: {
    API: 'https://yoyo-vps.5202021.xyz',
    HLS: 'https://yoyo-vps.5202021.xyz',
    HEALTH: 'https://yoyo-vps.5202021.xyz'
  },
  // 统一从管理后台配置读取 (KV存储)
  getTunnelEnabled: async (env) => {
    try {
      const runtimeConfig = await env.YOYO_USER_DB.get('RUNTIME_TUNNEL_ENABLED');
      if (runtimeConfig !== null) {
        return runtimeConfig === 'true';
      }
      
      // 如果KV中没有配置，默认禁用隧道
      // 管理员可以通过管理后台启用
      return false;
    } catch (error) {
      console.warn('Failed to read tunnel config from KV:', error);
      // KV读取失败时，默认禁用隧道
      return false;
    }
  },
  // 默认配置描述
  DESCRIPTION: '隧道优化功能 - 改善中国大陆用户体验'
};
