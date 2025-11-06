/**
 * 预加载配置管理处理器
 * 管理频道预加载时间配置
 */

/**
 * 获取单个频道的预加载配置
 * 🆕 从频道配置中读取preloadConfig
 */
async function getPreloadConfig(env, channelId) {
  try {
    // 🆕 从频道配置中读取
    const channelKey = `channel:${channelId}`;
    const channelData = await env.YOYO_USER_DB.get(channelKey, { type: 'json' });
    
    if (channelData?.preloadConfig) {
      return {
        status: 'success',
        data: {
          channelId,
          ...channelData.preloadConfig
        }
      };
    }
    
    // 返回默认配置
    return {
      status: 'success',
      data: {
        channelId,
        enabled: false,
        startTime: '07:00',
        endTime: '17:30',
        workdaysOnly: false
      }
    };
  } catch (error) {
    console.error('Failed to get preload config:', error);
    return {
      status: 'error',
      message: error.message
    };
  }
}

/**
 * 获取所有频道的预加载配置（批量）
 * 🔥 使用频道索引避免list()操作超限
 */
async function getAllPreloadConfigs(env) {
  try {
    // 1. 从频道索引读取所有频道ID
    const channelIndexData = await env.YOYO_USER_DB.get('system:channel_index');
    let channelIds = [];
    
    if (channelIndexData) {
      try {
        const indexObj = JSON.parse(channelIndexData);
        channelIds = indexObj.channelIds || [];
      } catch (e) {
        console.error('解析频道索引失败:', e);
      }
    }
    
    // 2. 如果索引为空，尝试降级方案（list操作，仅首次）
    if (channelIds.length === 0) {
      console.warn('频道索引为空，尝试使用list降级方案');
      try {
        const listResult = await env.YOYO_USER_DB.list({ prefix: 'channel:' });
        channelIds = listResult.keys.map(key => key.name.replace('channel:', ''));
        
        // 自动重建索引
        if (channelIds.length > 0) {
          await env.YOYO_USER_DB.put('system:channel_index', JSON.stringify({
            channelIds,
            lastUpdated: new Date().toISOString(),
            totalChannels: channelIds.length
          }));
          console.log(`频道索引已自动重建，包含${channelIds.length}个频道`);
        }
      } catch (listError) {
        console.error('List操作失败:', listError);
        return {
          status: 'success',
          data: [],
          message: '频道索引为空且list操作失败，请手动重建频道索引'
        };
      }
    }
    
    // 3. 根据索引逐个读取频道配置
    const configs = [];
    for (const channelId of channelIds) {
      const channelData = await env.YOYO_USER_DB.get(`channel:${channelId}`, { type: 'json' });
      if (channelData?.preloadConfig?.enabled) {
        configs.push({
          channelId: channelData.id,
          ...channelData.preloadConfig
        });
      }
    }
    
    console.log(`getAllPreloadConfigs: Found ${configs.length} enabled configs from ${channelIds.length} channels`);
    
    return {
      status: 'success',
      data: configs
    };
  } catch (error) {
    console.error('Failed to get all preload configs:', error);
    return {
      status: 'error',
      message: error.message
    };
  }
}

/**
 * 更新频道的预加载配置
 * 🆕 整合策略：将预加载配置嵌入到频道配置中
 */
async function updatePreloadConfig(env, channelId, data, username) {
  try {
    const { enabled, startTime, endTime, workdaysOnly } = data;
    
    // 验证时间格式
    if (!isValidTimeFormat(startTime) || !isValidTimeFormat(endTime)) {
      return {
        status: 'error',
        message: '时间格式错误，应为 HH:MM 格式'
      };
    }
    
    // 🆕 读取现有频道配置
    const channelKey = `channel:${channelId}`;
    let channelData = null;
    
    try {
      const existingData = await env.YOYO_USER_DB.get(channelKey);
      if (existingData) {
        channelData = JSON.parse(existingData);
      }
    } catch (error) {
      console.error('读取频道配置失败:', error);
    }
    
    // 如果频道不存在，创建基础配置
    if (!channelData) {
      channelData = {
        id: channelId,
        name: channelId,
        rtmpUrl: '',
        sortOrder: 999,
        updatedAt: new Date().toISOString()
      };
    }
    
    // 🔧 重新读取最新数据，避免并发写入冲突
    console.log('🔄 [updatePreloadConfig] Re-reading latest data to avoid race condition...');
    try {
      const latestData = await env.YOYO_USER_DB.get(channelKey);
      if (latestData) {
        channelData = JSON.parse(latestData);
      }
    } catch (error) {
      console.error('重新读取失败:', error);
    }
    
    // 🆕 构建预加载配置
    const preloadConfig = {
      enabled: enabled === true,
      startTime,
      endTime,
      workdaysOnly: workdaysOnly === true,
      updatedAt: new Date().toISOString(),
      updatedBy: username || 'unknown'
    };
    
    // 🆕 嵌入到频道配置（只写这里，不再写旧键）
    channelData.preloadConfig = preloadConfig;
    channelData.updatedAt = new Date().toISOString();
    
    // 🆕 保存更新后的频道配置
    await env.YOYO_USER_DB.put(channelKey, JSON.stringify(channelData));
    
    // 🔧 同步通知VPS重载调度，直接传递最新配置（复用录制功能的成功模式）
    let vpsNotifyResult = null;
    try {
      // 构造完整配置对象传递给VPS
      const fullConfig = {
        channelId,
        channelName: channelData.name || channelId,
        rtmpUrl: channelData.rtmpUrl || '',
        ...preloadConfig
      };
      console.log('📞 [updatePreloadConfig] Notifying VPS...', { fullConfig });
      vpsNotifyResult = await notifyVpsReload(env, channelId, fullConfig);
      console.log('✅ [updatePreloadConfig] VPS notification successful', { result: vpsNotifyResult });
    } catch (error) {
      console.error('⚠️ [updatePreloadConfig] VPS notification failed (config saved)', { 
        channelId, 
        error: error.message,
        stack: error.stack
      });
      vpsNotifyResult = { error: error.message };
      // 即使通知失败，配置也已保存，VPS定时重载会生效
    }
    
    return {
      status: 'success',
      data: {
        channelId,
        ...preloadConfig
      },
      debug: {
        vpsNotified: vpsNotifyResult?.success || false,
        vpsError: vpsNotifyResult?.error || null
      }
    };
  } catch (error) {
    console.error('Failed to update preload config:', error);
    return {
      status: 'error',
      message: error.message
    };
  }
}

/**
 * 获取预加载状态（从VPS）
 */
async function getPreloadStatus(env) {
  try {
    const vpsUrl = `${env.VPS_API_URL}/api/simple-stream/preload/vps-status`;
    const response = await fetch(vpsUrl, {
      headers: {
        'X-API-Key': env.VPS_API_KEY
      }
    });
    
    if (!response.ok) {
      throw new Error(`VPS API responded with status ${response.status}`);
    }
    
    const result = await response.json();
    return result;
  } catch (error) {
    console.error('Failed to get preload status from VPS:', error);
    return {
      status: 'error',
      message: 'Failed to connect to VPS: ' + error.message
    };
  }
}

/**
 * 🆕 获取工作日状态（从VPS）
 */
async function getWorkdayStatus(env) {
  try {
    const vpsUrl = `${env.VPS_API_URL}/api/preload/workday-status`;
    const response = await fetch(vpsUrl, {
      headers: {
        'X-API-Key': env.VPS_API_KEY
      }
    });
    
    if (!response.ok) {
      throw new Error(`VPS API responded with status ${response.status}`);
    }
    
    const result = await response.json();
    return result;
  } catch (error) {
    console.error('Failed to get workday status from VPS:', error);
    return {
      status: 'error',
      message: 'Failed to connect to VPS: ' + error.message
    };
  }
}

/**
 * 通知VPS重新加载调度器
 * @param {Object} env - 环境变量
 * @param {string} channelId - 频道ID
 * @param {Object} config - 可选：直接传递最新配置，避免KV延迟
 * @returns {Promise<{success: boolean, error?: string}>}
 */
async function notifyVpsReload(env, channelId, config = null) {
  try {
    console.log('🔔 正在通知VPS重载预加载调度...', { 
      url: env.VPS_API_URL, 
      channelId,
      hasConfig: !!config,
      configEnabled: config?.enabled
    });
    
    // 🔧 传递配置到VPS，避免KV最终一致性问题
    const response = await fetch(`${env.VPS_API_URL}/api/simple-stream/preload/reload-schedule`, {
      method: 'POST',
      headers: {
        'X-API-Key': env.VPS_API_KEY,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        channelId,
        config  // 🆕 传递配置
      })
    });
    
    if (!response.ok) {
      const errorText = await response.text();
      console.error('VPS response failed:', {
        status: response.status,
        errorText
      });
      throw new Error(`VPS responded with ${response.status}`);
    }
    
    return { success: true };
  } catch (error) {
    console.error('VPS notification error:', error);
    throw error;
  }
}

/**
 * 验证时间格式 (HH:MM)
 */
function isValidTimeFormat(time) {
  if (typeof time !== 'string') return false;
  const regex = /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/;
  return regex.test(time);
}

/**
 * 主处理函数
 */
export async function handlePreloadRequest(request, env) {
  const url = new URL(request.url);
  const method = request.method;
  const pathname = url.pathname;
  
  // 从cookie获取用户信息（用于记录操作者）
  const cookieHeader = request.headers.get('Cookie') || '';
  const cookies = Object.fromEntries(
    cookieHeader.split(';').map(c => c.trim().split('='))
  );
  const sessionToken = cookies.session_token;
  let username = 'unknown';
  
  if (sessionToken) {
    try {
      const sessionKey = `SESSION:${sessionToken}`;
      const session = await env.YOYO_USER_DB.get(sessionKey, { type: 'json' });
      if (session && session.username) {
        username = session.username;
      }
    } catch (error) {
      console.error('Failed to get session:', error);
    }
  }
  
  // GET /api/preload/config/:channelId - 获取单个配置
  if (method === 'GET' && pathname.match(/^\/api\/preload\/config\/[\w-]+$/)) {
    const channelId = pathname.split('/').pop();
    const result = await getPreloadConfig(env, channelId);
    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json' }
    });
  }
  
  // GET /api/preload/configs - 获取所有配置（批量）
  if (method === 'GET' && pathname === '/api/preload/configs') {
    const result = await getAllPreloadConfigs(env);
    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json' }
    });
  }
  
  // PUT /api/preload/config/:channelId - 更新配置
  if (method === 'PUT' && pathname.match(/^\/api\/preload\/config\/[\w-]+$/)) {
    const channelId = pathname.split('/').pop();
    const data = await request.json();
    const result = await updatePreloadConfig(env, channelId, data, username);
    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json' }
    });
  }
  
  // GET /api/preload/status - 获取预加载状态
  if (method === 'GET' && pathname === '/api/preload/status') {
    const result = await getPreloadStatus(env);
    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json' }
    });
  }
  
  // 🆕 GET /api/preload/workday-status - 获取工作日状态
  if (method === 'GET' && pathname === '/api/preload/workday-status') {
    const result = await getWorkdayStatus(env);
    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json' }
    });
  }
  
  // 404
  return new Response(JSON.stringify({
    status: 'error',
    message: 'Not found'
  }), {
    status: 404,
    headers: { 'Content-Type': 'application/json' }
  });
}
