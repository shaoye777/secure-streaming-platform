<template>
  <el-dialog
    v-model="visible"
    title="预加载配置"
    width="500px"
    :before-close="handleClose"
  >
    <el-form :model="form" label-width="100px" :rules="rules" ref="formRef">
      <el-form-item label="频道">
        <el-input :value="channelName" disabled />
      </el-form-item>
      
      <el-form-item label="预加载开关" prop="enabled">
        <el-switch
          v-model="form.enabled"
          active-text="启用"
          inactive-text="禁用"
        />
      </el-form-item>
      
      <el-form-item label="开始时间" prop="startTime">
        <el-time-picker
          v-model="form.startTime"
          format="HH:mm"
          value-format="HH:mm"
          placeholder="选择开始时间"
          :disabled="!form.enabled"
        />
      </el-form-item>
      
      <el-form-item label="结束时间" prop="endTime">
        <el-time-picker
          v-model="form.endTime"
          format="HH:mm"
          value-format="HH:mm"
          placeholder="选择结束时间"
          :disabled="!form.enabled"
        />
      </el-form-item>
      
      <!-- 🆕 工作日限制开关 -->
      <el-form-item label="仅工作日" prop="workdaysOnly">
        <div style="display: flex; align-items: center; gap: 10px;">
          <el-switch
            v-model="form.workdaysOnly"
            active-text="启用"
            inactive-text="禁用"
            :disabled="!form.enabled"
            @change="handleWorkdayToggle"
          />
          <el-tag
            v-if="form.workdaysOnly && workdayStatus.text"
            :type="workdayStatus.type"
            size="small"
          >
            {{ workdayStatus.text }}
          </el-tag>
        </div>
        <div style="margin-top: 5px; font-size: 12px; color: #909399;">
          启用后仅在工作日进行预加载（自动识别法定节假日和调休）
        </div>
      </el-form-item>
      
      <!-- 🆕 工作日状态详情 -->
      <el-alert
        v-if="form.workdaysOnly && workdayDetails.title"
        :title="workdayDetails.title"
        :type="workdayDetails.alertType"
        :closable="false"
        style="margin-bottom: 15px"
      >
        <template v-if="workdayDetails.failedMonths && workdayDetails.failedMonths.length > 0">
          <p>待重试月份: {{ workdayDetails.failedMonths.join(', ') }}</p>
          <p style="margin-top: 5px;">将在每天凌晨1点自动重试</p>
        </template>
      </el-alert>
      
      <el-alert
        v-if="form.enabled"
        :title="preloadInfo"
        type="info"
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
  enabled: false,
  startTime: '07:00',
  endTime: '17:30',
  workdaysOnly: false  // 🆕 工作日限制
});

// 🆕 工作日状态
const workdayStatus = ref({
  type: 'info',
  text: ''
});

// 🆕 工作日详细信息
const workdayDetails = ref({
  alertType: 'success',
  title: '',
  failedMonths: []
});

const rules = {
  startTime: [
    { required: true, message: '请选择开始时间', trigger: 'change' }
  ],
  endTime: [
    { required: true, message: '请选择结束时间', trigger: 'change' }
  ]
};

// 计算预加载信息
const preloadInfo = computed(() => {
  if (!form.value.enabled) return '';
  
  const start = form.value.startTime;
  const end = form.value.endTime;
  
  // 🆕 根据工作日设置选择时段描述
  const timePrefix = form.value.workdaysOnly ? '工作日' : '每天';
  
  // 判断是否跨天
  const isCrossDay = end < start;
  
  if (isCrossDay) {
    return `预加载时段：${timePrefix} ${start} - 次日 ${end} (跨天)`;
  } else {
    return `预加载时段：${timePrefix} ${start} - ${end}`;
  }
});

// 监听对话框打开，加载配置
watch(() => props.modelValue, async (val) => {
  if (val) {
    await loadConfig();
  }
});

// 加载预加载配置
async function loadConfig() {
  try {
    const response = await axios.get(`/api/preload/config/${props.channelId}`);
    
    if (response.data.status === 'success') {
      const config = response.data.data;
      form.value = {
        enabled: config.enabled || false,
        startTime: config.startTime || '07:00',
        endTime: config.endTime || '17:30',
        workdaysOnly: config.workdaysOnly || false  // 🆕 加载工作日设置
      };
      
      // 🆕 如果工作日开关已启用，获取状态
      if (form.value.workdaysOnly) {
        await fetchWorkdayStatus();
      }
    }
  } catch (error) {
    console.error('加载预加载配置失败:', error);
    ElMessage.error('加载配置失败');
  }
}

// 🆕 工作日开关切换处理
async function handleWorkdayToggle(value) {
  if (value) {
    // 开启时获取工作日状态
    workdayStatus.value = {
      type: 'info',
      text: '🔄 正在加载数据...'
    };
    await fetchWorkdayStatus();
  } else {
    // 关闭时清除状态
    workdayStatus.value = { type: 'info', text: '' };
    workdayDetails.value = { alertType: 'success', title: '', failedMonths: [] };
  }
}

// 🆕 获取工作日状态
async function fetchWorkdayStatus() {
  try {
    const response = await axios.get('/api/preload/workday-status');
    
    if (response.data.status === 'success') {
      const { dataReady, failedMonths, message } = response.data.data;
      
      if (dataReady && (!failedMonths || failedMonths.length === 0)) {
        // 数据完全就绪
        workdayStatus.value = {
          type: 'success',
          text: '✅ 数据已加载'
        };
        workdayDetails.value = {
          alertType: 'success',
          title: '当前月和下月工作日数据已准备就绪',
          failedMonths: []
        };
      } else if (failedMonths && failedMonths.length > 0) {
        // 部分月份失败
        workdayStatus.value = {
          type: 'warning',
          text: `⚠️ ${failedMonths.length}个月份待重试`
        };
        workdayDetails.value = {
          alertType: 'warning',
          title: '部分月份数据获取失败',
          failedMonths: failedMonths
        };
      }
    } else {
      throw new Error(response.data.message);
    }
  } catch (error) {
    console.error('获取工作日状态失败:', error);
    workdayStatus.value = {
      type: 'danger',
      text: '❌ 获取状态失败'
    };
    workdayDetails.value = {
      alertType: 'warning',
      title: '无法连接到工作日服务',
      failedMonths: []
    };
  }
}

// 保存配置
async function handleSave() {
  try {
    await formRef.value.validate();
    
    saving.value = true;
    
    const response = await axios.put(`/api/preload/config/${props.channelId}`, {
      enabled: form.value.enabled,
      startTime: form.value.startTime,
      endTime: form.value.endTime,
      workdaysOnly: form.value.workdaysOnly  // 🆕 保存工作日设置
    });
    
    if (response.data.status === 'success') {
      ElMessage.success('预加载配置已保存');
      emit('saved');
      handleClose();
    } else {
      throw new Error(response.data.message || '保存失败');
    }
  } catch (error) {
    console.error('保存预加载配置失败:', error);
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
