<template>
  <el-dialog
    v-model="visible"
    title="频道配置"
    width="600px"
    :before-close="handleClose"
  >
    <el-form :model="form" label-width="100px" :rules="rules" ref="formRef">
      <el-form-item label="频道">
        <el-input :value="channelName" disabled />
      </el-form-item>
      
      <!-- ========== 上半部分：预加载配置 ========== -->
      <el-divider content-position="left">
        <span style="font-weight: bold;">预加载配置</span>
      </el-divider>
      
      <el-form-item label="预加载开关" prop="preloadConfig.enabled">
        <el-switch
          v-model="form.preloadConfig.enabled"
          active-text="启用"
          inactive-text="禁用"
        />
      </el-form-item>
      
      <el-form-item label="开始时间" prop="preloadConfig.startTime">
        <el-time-picker
          v-model="form.preloadConfig.startTime"
          format="HH:mm"
          value-format="HH:mm"
          placeholder="选择开始时间"
          :disabled="!form.preloadConfig.enabled"
        />
      </el-form-item>
      
      <el-form-item label="结束时间" prop="preloadConfig.endTime">
        <el-time-picker
          v-model="form.preloadConfig.endTime"
          format="HH:mm"
          value-format="HH:mm"
          placeholder="选择结束时间"
          :disabled="!form.preloadConfig.enabled"
        />
      </el-form-item>
      
      <el-form-item label="仅工作日" prop="preloadConfig.workdaysOnly">
        <el-switch
          v-model="form.preloadConfig.workdaysOnly"
          active-text="启用"
          inactive-text="禁用"
          :disabled="!form.preloadConfig.enabled"
        />
        <div style="margin-top: 5px; font-size: 12px; color: #909399;">
          启用后仅在工作日进行预加载（自动识别法定节假日和调休）
        </div>
      </el-form-item>
      
      <el-alert
        v-if="form.preloadConfig.enabled"
        :title="preloadInfo"
        type="info"
        :closable="false"
        style="margin-bottom: 15px"
      />
      
      <!-- ========== 下半部分：录制配置 ========== -->
      <el-divider content-position="left">
        <span style="font-weight: bold;">录制配置</span>
      </el-divider>
      
      <el-form-item label="录制开关" prop="recordConfig.enabled">
        <el-switch
          v-model="form.recordConfig.enabled"
          active-text="启用"
          inactive-text="禁用"
        />
      </el-form-item>
      
      <el-form-item label="开始时间" prop="recordConfig.startTime">
        <el-time-picker
          v-model="form.recordConfig.startTime"
          format="HH:mm"
          value-format="HH:mm"
          placeholder="选择开始时间"
          :disabled="!form.recordConfig.enabled"
        />
      </el-form-item>
      
      <el-form-item label="结束时间" prop="recordConfig.endTime">
        <el-time-picker
          v-model="form.recordConfig.endTime"
          format="HH:mm"
          value-format="HH:mm"
          placeholder="选择结束时间"
          :disabled="!form.recordConfig.enabled"
        />
      </el-form-item>
      
      <el-form-item label="仅工作日" prop="recordConfig.workdaysOnly">
        <el-switch
          v-model="form.recordConfig.workdaysOnly"
          active-text="启用"
          inactive-text="禁用"
          :disabled="!form.recordConfig.enabled"
        />
        <div style="margin-top: 5px; font-size: 12px; color: #909399;">
          启用后仅在工作日进行录制（自动识别法定节假日和调休）
        </div>
      </el-form-item>
      
      <el-form-item label="存储路径" prop="recordConfig.storagePath">
        <el-input
          v-model="form.recordConfig.storagePath"
          placeholder="/var/www/recordings"
          :disabled="!form.recordConfig.enabled"
        />
        <div style="margin-top: 5px; font-size: 12px; color: #909399;">
          录制文件保存路径（如需通过FileBrowser访问，请使用 /srv/filebrowser/yoyo-k）
        </div>
      </el-form-item>
      
      <el-alert
        v-if="form.recordConfig.enabled"
        :title="recordInfo"
        type="success"
        :closable="false"
        style="margin-bottom: 15px"
      />
    </el-form>
    
    <template #footer>
      <span class="dialog-footer">
        <el-button @click="handleClose">取消</el-button>
        <el-button type="primary" @click="handleSave" :loading="saving">
          保存
        </el-button>
      </span>
    </template>
  </el-dialog>
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import { ElMessage } from 'element-plus';
import axios from '@/utils/axios';

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false
  },
  channelId: {
    type: String,
    required: true
  },
  channelName: {
    type: String,
    required: true
  }
});

const emit = defineEmits(['update:modelValue', 'saved']);

const visible = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
});

const formRef = ref(null);
const saving = ref(false);

const form = ref({
  preloadConfig: {
    enabled: false,
    startTime: '07:00',
    endTime: '17:30',
    workdaysOnly: false
  },
  recordConfig: {
    enabled: false,
    startTime: '07:40',
    endTime: '17:25',
    workdaysOnly: false,
    storagePath: '/var/www/recordings'
  }
});

const rules = {
  'preloadConfig.startTime': [
    { required: true, message: '请选择预加载开始时间', trigger: 'change' }
  ],
  'preloadConfig.endTime': [
    { required: true, message: '请选择预加载结束时间', trigger: 'change' }
  ],
  'recordConfig.startTime': [
    { required: true, message: '请选择录制开始时间', trigger: 'change' }
  ],
  'recordConfig.endTime': [
    { required: true, message: '请选择录制结束时间', trigger: 'change' }
  ],
  'recordConfig.storagePath': [
    { required: true, message: '请输入存储路径', trigger: 'blur' }
  ]
};

// 计算预加载信息
const preloadInfo = computed(() => {
  if (!form.value.preloadConfig.enabled) return '';
  
  const start = form.value.preloadConfig.startTime;
  const end = form.value.preloadConfig.endTime;
  const timePrefix = form.value.preloadConfig.workdaysOnly ? '工作日' : '每天';
  const isCrossDay = end < start;
  
  if (isCrossDay) {
    return `预加载时段：${timePrefix} ${start} - 次日 ${end} (跨天)`;
  } else {
    return `预加载时段：${timePrefix} ${start} - ${end}`;
  }
});

// 计算录制信息
const recordInfo = computed(() => {
  if (!form.value.recordConfig.enabled) return '';
  
  const start = form.value.recordConfig.startTime;
  const end = form.value.recordConfig.endTime;
  const timePrefix = form.value.recordConfig.workdaysOnly ? '工作日' : '每天';
  const isCrossDay = end < start;
  
  if (isCrossDay) {
    return `录制时段：${timePrefix} ${start} - 次日 ${end} (跨天)`;
  } else {
    return `录制时段：${timePrefix} ${start} - ${end}`;
  }
});

// 监听对话框打开，加载配置
watch(() => props.modelValue, async (val) => {
  if (val) {
    await loadConfig();
  }
});

// 加载配置
async function loadConfig() {
  try {
    // 并行加载预加载和录制配置
    const [preloadResponse, recordResponse] = await Promise.all([
      axios.get(`/api/preload/config/${props.channelId}`),
      axios.get(`/api/record/config/${props.channelId}`)
    ]);
    
    // 加载预加载配置
    if (preloadResponse.data.status === 'success') {
      const config = preloadResponse.data.data;
      form.value.preloadConfig = {
        enabled: config.enabled || false,
        startTime: config.startTime || '07:00',
        endTime: config.endTime || '17:30',
        workdaysOnly: config.workdaysOnly || false
      };
    }
    
    // 加载录制配置
    if (recordResponse.data.status === 'success') {
      const config = recordResponse.data.data;
      form.value.recordConfig = {
        enabled: config.enabled || false,
        startTime: config.startTime || '07:40',
        endTime: config.endTime || '17:25',
        workdaysOnly: config.workdaysOnly || false,
        storagePath: config.storagePath || '/var/www/recordings'
      };
    }
  } catch (error) {
    console.error('加载配置失败:', error);
    ElMessage.error('加载配置失败');
  }
}

// 保存配置
async function handleSave() {
  try {
    await formRef.value.validate();
    
    saving.value = true;
    
    // 并行保存预加载和录制配置
    const promises = [];
    
    promises.push(
      axios.put(`/api/preload/config/${props.channelId}`, {
        enabled: form.value.preloadConfig.enabled,
        startTime: form.value.preloadConfig.startTime,
        endTime: form.value.preloadConfig.endTime,
        workdaysOnly: form.value.preloadConfig.workdaysOnly
      })
    );
    
    promises.push(
      axios.put(`/api/record/config/${props.channelId}`, {
        enabled: form.value.recordConfig.enabled,
        startTime: form.value.recordConfig.startTime,
        endTime: form.value.recordConfig.endTime,
        workdaysOnly: form.value.recordConfig.workdaysOnly,
        storagePath: form.value.recordConfig.storagePath
      })
    );
    
    const results = await Promise.all(promises);
    
    // 检查所有结果
    const allSuccess = results.every(res => res.data.status === 'success');
    
    if (allSuccess) {
      ElMessage.success('频道配置已保存');
      emit('saved');
      handleClose();
    } else {
      throw new Error('部分配置保存失败');
    }
  } catch (error) {
    console.error('保存配置失败:', error);
    if (error.message) {
      ElMessage.error(error.message);
    } else {
      ElMessage.error('保存配置失败');
    }
  } finally {
    saving.value = false;
  }
}

// 关闭对话框
function handleClose() {
  visible.value = false;
}
</script>

<style scoped>
.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}
</style>
