extends GPUParticles2D

func _ready():
	# 初始状态不发射粒子
	emitting = false
	
	# 设置粒子属性 - 更加优雅的水流效果
	var particle_material = ParticleProcessMaterial.new()
	process_material = particle_material
	
	# 基本设置 - 使用更窄的发射区域
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(30, 2, 1)
	
	# 水流向上流动 - 更集中的流向
	process_material.direction = Vector3(0, -1, 0)
	process_material.spread = 1.5  # 更集中的流向
	process_material.initial_velocity_min = 55.0
	process_material.initial_velocity_max = 65.0
	
	# 重力设置 - 使水流更加均匀上升
	process_material.gravity = Vector3(0, -12, 0)
	
	# 水流粒子大小 - 更加细致的粒子
	process_material.scale_min = 0.7
	process_material.scale_max = 1.5
	
	# 水流生命周期
	lifetime = 1.2
	
	# 轻微扭曲水流路径 - 减少湍流使其更加优雅
	process_material.turbulence_enabled = true
	process_material.turbulence_noise_strength = 1.5  # 减少湍流强度
	process_material.turbulence_noise_scale = 1.2
	
	# 使粒子更加流畅，添加阻尼效果替代吸引力
	process_material.damping_min = 0.04
	process_material.damping_max = 0.08
	
	# 设置粒子颜色渐变 - 清晰明亮的蓝色水流
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.6, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.4, 0.8, 1.0, 0.4),  # 淡蓝色开始，更透明
		Color(0.2, 0.6, 0.95, 0.9), # 蓝色主体，更加不透明
		Color(0.4, 0.7, 1.0, 0.6),  # 较亮蓝色，适中透明度
		Color(0.5, 0.85, 1.0, 1.0)  # 淡出
	])
	
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	process_material.color_ramp = gradient_texture

# 在指定位置开始水流效果
func start_water_flow(position_y):
	# 设置粒子系统位置
	position.y = position_y
	
	# 设置粒子数量 - 保持连续但不过密
	amount = 120
	
	# 重置粒子系统
	restart()
	emitting = true

# 停止水流
func stop_water_flow():
	emitting = false 
