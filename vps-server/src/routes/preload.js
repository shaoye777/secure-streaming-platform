const express = require('express');
const router = express.Router();
const logger = require('../utils/logger');
const authMiddleware = require('../middleware/auth');

/**
 * 预加载路由
 * 提供工作日状态查询等功能
 */

// 🔐 添加API认证中间件到所有预加载路由
router.use(authMiddleware);

/**
 * GET /api/preload/workday-status
 * 获取工作日检测器状态
 */
router.get('/workday-status', (req, res) => {
  try {
    // 从app获取workdayChecker实例
    const workdayChecker = req.app.get('workdayChecker');
    
    if (!workdayChecker) {
      return res.status(503).json({
        status: 'error',
        message: 'WorkdayChecker not initialized'
      });
    }
    
    // 获取当前状态
    const failedMonths = Array.from(workdayChecker.failedMonths);
    const dataReady = failedMonths.length === 0;
    
    // 获取下个月信息
    const next = workdayChecker.getNextMonth();
    const nextMonthKey = workdayChecker.getNextMonthKey();
    
    res.json({
      status: 'success',
      data: {
        dataReady,
        failedMonths,
        currentMonth: new Date().toISOString().substring(0, 7),
        nextMonth: nextMonthKey,
        message: dataReady 
          ? '当前月和下月工作日数据已准备就绪' 
          : `${failedMonths.length}个月份数据获取失败`
      }
    });
    
  } catch (error) {
    logger.error('Failed to get workday status', { error: error.message });
    res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
});

module.exports = router;
