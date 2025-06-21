shader_type canvas_item;

// 可配置参数
uniform float radius = 8.0;
uniform float shadow_size = 2.0;
uniform vec2 shadow_offset = vec2(0, 1);
uniform vec4 shadow_color : source_color;
uniform vec4 normal_color : source_color;
uniform vec4 selected_color : source_color;
uniform bool is_selected = false;
uniform vec2 rect_size = vec2(200.0, 80.0); // 必须通过代码设置

void fragment() {
    // 获取当前片段在矩形内的位置 (0.0-1.0)
    vec2 uv = UV;
    
    // 计算阴影区域
    vec2 shadow_uv = uv;
    vec2 shadow_dist = min(shadow_uv, 1.0 - shadow_uv) * rect_size;
    float shadow_corner_dist = min(shadow_dist.x, shadow_dist.y);
    float shadow_alpha = smoothstep(radius + shadow_size + 0.5, radius + shadow_size - 0.5, shadow_corner_dist);
    
    // 计算内容区域（考虑阴影偏移）
    vec2 content_uv = uv - shadow_offset / rect_size;
    
    // 确保内容 UV 在有效范围内
    if (content_uv.x < 0.0 || content_uv.x > 1.0 || content_uv.y < 0.0 || content_uv.y > 1.0) {
        // 超出内容区域的部分只显示阴影
		COLOR = vec4(shadow_color.rgb, shadow_color.a * shadow_alpha);
    }else{
		 // 计算内容区域的圆角
    vec2 content_dist = min(content_uv, 1.0 - content_uv) * rect_size;
    float content_corner_dist = min(content_dist.x, content_dist.y);
    float content_alpha = smoothstep(radius + 0.5, radius - 0.5, content_corner_dist);
    
    // 应用颜色
    vec4 bg_color = is_selected ? selected_color : normal_color;
    vec4 final_color = mix(shadow_color, bg_color, content_alpha);
    final_color.a *= shadow_alpha;
    
    COLOR = final_color;
	}
    
   
}