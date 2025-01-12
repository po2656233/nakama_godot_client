shader_type canvas_item;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float thickness : hint_range(0, 1) = 0.1;
uniform float progress : hint_range(0, 1) = 0.0;
uniform float glow_strength : hint_range(0, 1) = 0.5;

void fragment() {
    // 将UV坐标转换为中心为原点的坐标系
    vec2 uv = UV * 2.0 - 1.0;
    float dist = length(uv);

    // 创建主圆环
    float circle = smoothstep(1.0, 1.0 - thickness, dist);

    // 添加发光效果
    float glow = smoothstep(1.2, 0.8, dist) * glow_strength;

    // 计算角度用于进度显示
    float angle = atan(uv.y, uv.x);
    angle = angle + 3.14159; // 将角度范围从[-pi,pi]转换为[0,2pi]
    float normalized_angle = angle / (2.0 * 3.14159);

    // 创建进度遮罩
    float progress_mask = step(normalized_angle, progress);

    // 组合所有效果
    COLOR = color;
    COLOR.a *= (circle + glow) * progress_mask;

    // 添加边缘抗锯齿
    float edge_smoothing = fwidth(dist);
    COLOR.a *= smoothstep(1.0 + edge_smoothing, 1.0 - edge_smoothing, dist);
}