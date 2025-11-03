const logger = require('../utils/logger');

/**
 * 预加载健康检查服务（轻量级）
 * 
 * 注：核心健康检查已集成在PreloadScheduler和SimpleStreamManager中：
 * - PreloadScheduler: 定时任务精确触发、服务启动检测
 * - SimpleStreamManager: RTMP变更检测、进程管理、自动重启
 * 
 * 此服务提供额外的监控和日志记录
 */
class PreloadHealthCheck {
  constructor(streamManager, preloadScheduler) {
    this.streamManager = streamManager;
    this.preloadScheduler = preloadScheduler;
    
    // 检查间隔：5分钟
    this.CHECK_INTERVAL = 5 * 60 * 1000;
    this.checkTimer = null;
  }

  /**
   * 启动健康检查
   */
  start() {
    logger.info('PreloadHealthCheck started');
    
    // 定期检查
    this.checkTimer = setInterval(() => {
      this.performHealthCheck();
    }, this.CHECK_INTERVAL);
  }

  /**
   * 执行健康检查
   */
  async performHealthCheck() {
    try {
      // 获取预加载状态
      const schedulerStatus = this.preloadScheduler.getStatus();
      const streamManagerStatus = this.streamManager.getPreloadStatus();
      
      // 记录健康状态
      logger.info('Preload health check', {
        schedulerRunning: schedulerStatus.isRunning,
        scheduledChannels: schedulerStatus.totalScheduledChannels,
        activePreloadChannels: streamManagerStatus.activePreloadChannels,
        totalPreloadChannels: streamManagerStatus.totalPreloadChannels
      });
      
      // 检查异常情况
      if (streamManagerStatus.totalPreloadChannels > 0 && 
          streamManagerStatus.activePreloadChannels === 0) {
        logger.warn('预加载频道已配置但无活跃进程（可能不在预加载时段）');
      }
      
    } catch (error) {
      logger.error('Health check failed', { error: error.message });
    }
  }

  /**
   * 停止健康检查
   */
  stop() {
    if (this.checkTimer) {
      clearInterval(this.checkTimer);
      this.checkTimer = null;
      logger.info('PreloadHealthCheck stopped');
    }
  }
}

module.exports = PreloadHealthCheck;
