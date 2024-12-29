shader_type canvas_item;

uniform float rotation;

void vertex() {
    float width = 350.0;
    // 计算顶点相对于中心轴的位置
    vec2 center_axis = vec2(0.5, 0.0);
    vec2 vertex = VERTEX / vec2(width, 1.0); // 归一化坐标
    
    // 计算顶点到中心轴的距离
    float dist = vertex.x - center_axis.x;
    
    // 应用3D旋转变换
    float cos_rot = cos(rotation);
    float sin_rot = sin(rotation);
    
    // 围绕Y轴旋转的3D变换
    vec3 pos = vec3(dist, vertex.y, 0.0);
    vec3 rotated = vec3(
        pos.x * cos_rot + pos.z * sin_rot,
        pos.y,
        -pos.x * sin_rot + pos.z * cos_rot
    );
    
    // 应用更柔和的透视投影
    float perspective = 3.0;  // 增加透视强度
    float z_offset = 3.0;    // 增加Z轴偏移
    float scale = perspective / (perspective + rotated.z + z_offset);
    
    // 更新顶点位置，添加平滑过渡
    VERTEX.x = (rotated.x * scale + center_axis.x) * width;
    
    // // 使用更平滑的透明度过渡
    // float alpha_scale = smoothstep(0.3, 1.0, scale);
    // COLOR.a *= alpha_scale;
}
