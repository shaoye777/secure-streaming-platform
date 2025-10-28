/**
 * 录制配置管理处理器
 * 管理频道定时录制配置
 */

/**
 * 获取单个频道的录制配置
 */
async function getRecordConfig(env, channelId) {
  try {
    const channelKey = `channel:${channelId}`;
    const channelData = await env.YOYO_USER_DB.get(channelKey, { type: 'json' });
    
    if (channelData?.recordConfig) {
      return {
        status: 'success',
        data: {
          channelId,
          channelName: channelData.name,
          ...channelData.recordConfig
        }
      };
    }
    
    // 返回默认配置
    return {
      status: 'success',
      data: {
        channelId,
        channelName: channelData?.name || '',
        enabled: false,
        startTime: '07:40',
        endTime: '17:25',
        workdaysOnly: false,
        storagePath: '/var/www/recordings'
      }
    };
  } catch (error) {
    console.error('Failed to get record config:', error);
    return {
      status: 'error',
      message: error.message
    };
  }
}

/**
 * 获取所有启用录制的频道配置（供VPS调度器调用）
 */
async function getAllRecordConfigs(env) {
  try {
    const listResult = await env.YOYO_USER_DB.list({ prefix: 'channel:' });
    
    const configs = [];
    for (const key of listResult.keys) {
      const channelData = await env.YOYO_USER_DB.get(key.name, { type: 'json' });
      if (channelData?.recordConfig?.enabled) {
        configs.push({
          channelId: channelData.id,
          channelName: channelData.name,  // 从顶层name获取
          rtmpUrl: channelData.rtmpUrl,   // 提供RTMP URL
          ...channelData.recordConfig
        });
      }
    }
    
    return {
      status: 'success',
      data: configs
    };
  } catch (error) {
    console.error('Failed to get all record configs:', error);
    return {
      status: 'error',
      message: error.message
    };
  }
}

/**
 * 更新频道的录制配置
 */
async function updateRecordConfig(env, channelId, data, username) {
  try {
    const channelKey = `channel:${channelId}`;
    let channelData = await env.YOYO_USER_DB.get(channelKey, { type: 'json' });
    
    if (!channelData) {
      throw new Error('Channel not found');
    }
    
    // 更新recordConfig字段
    channelData.recordConfig = {
      enabled: data.enabled === true,
      startTime: data.startTime,
      endTime: data.endTime,
      workdaysOnly: data.workdaysOnly === true,
      storagePath: data.storagePath || '/var/www/recordings',
      updatedAt: new Date().toISOString(),
      updatedBy: username
    };
    
    await env.YOYO_USER_DB.put(channelKey, JSON.stringify(channelData));
    
    // 通知VPS重载调度
    await notifyVpsReload(env, channelId);
    
    return {
      status: 'success',
      message: 'Record config updated successfully',
      data: channelData.recordConfig
    };
  } catch (error) {
    console.error('Failed to update record config:', error);
    return {
      status: 'error',
      message: error.message
    };
  }
}

/**
 * 通知VPS重新加载录制调度
 */
async function notifyVpsReload(env, channelId) {
  try {
    const response = await fetch(`${env.VPS_API_URL}/api/record/reload-schedule`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': env.VPS_API_KEY
      },
      body: JSON.stringify({ channelId })
    });
    
    if (!response.ok) {
      console.warn('Failed to notify VPS reload:', response.statusText);
    }
  } catch (error) {
    console.error('Failed to notify VPS:', error);
    // 不抛出错误，避免影响配置保存
  }
}

/**
 * 录制配置API处理器
 */
async function handleRecordAPI(request, env) {
  const url = new URL(request.url);
  const path = url.pathname;
  const method = request.method;
  
  try {
    // 验证API密钥（VPS调用）或用户会话
    const apiKey = request.headers.get('X-API-Key');
    const isVPSRequest = apiKey === env.VPS_API_KEY;
    
    // VPS请求：直接验证API密钥
    if (path === '/api/record/configs' && method === 'GET') {
      if (!isVPSRequest) {
        return new Response(JSON.stringify({
          status: 'error',
          message: 'Invalid API key'
        }), {
          status: 401,
          headers: { 'Content-Type': 'application/json' }
        });
      }
      
      const result = await getAllRecordConfigs(env);
      return new Response(JSON.stringify(result), {
        headers: { 'Content-Type': 'application/json' }
      });
    }
    
    // 管理员请求：需要验证会话
    const sessionToken = request.headers.get('Authorization')?.replace('Bearer ', '');
    if (!sessionToken && !isVPSRequest) {
      return new Response(JSON.stringify({
        status: 'error',
        message: 'Unauthorized'
      }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      });
    }
    
    let username = 'vps';
    if (sessionToken) {
      const sessionData = await env.YOYO_USER_DB.get(`session:${sessionToken}`, { type: 'json' });
      if (!sessionData) {
        return new Response(JSON.stringify({
          status: 'error',
          message: 'Invalid session'
        }), {
          status: 401,
          headers: { 'Content-Type': 'application/json' }
        });
      }
      username = sessionData.username;
    }
    
    // GET /api/record/config/:channelId - 获取单个频道录制配置
    if (path.match(/^\/api\/record\/config\/[^\/]+$/) && method === 'GET') {
      const channelId = path.split('/').pop();
      const result = await getRecordConfig(env, channelId);
      return new Response(JSON.stringify(result), {
        headers: { 'Content-Type': 'application/json' }
      });
    }
    
    // PUT /api/record/config/:channelId - 更新频道录制配置
    if (path.match(/^\/api\/record\/config\/[^\/]+$/) && method === 'PUT') {
      const channelId = path.split('/').pop();
      const data = await request.json();
      const result = await updateRecordConfig(env, channelId, data, username);
      return new Response(JSON.stringify(result), {
        headers: { 'Content-Type': 'application/json' }
      });
    }
    
    // 未匹配的路由
    return new Response(JSON.stringify({
      status: 'error',
      message: 'API endpoint not found'
    }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' }
    });
    
  } catch (error) {
    console.error('Record API error:', error);
    return new Response(JSON.stringify({
      status: 'error',
      message: error.message
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}

export { handleRecordAPI };
