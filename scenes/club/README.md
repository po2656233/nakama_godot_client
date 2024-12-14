# 社交群组管理应用

基于Godot 4开发的社交群组管理界面，支持群组列表展示、成员管理等功能。

## 功能特性

- 群组列表展示
- 群组搜索功能
- 群组排序（按名称/成员数）
- 成员列表展示
- 成员搜索功能
- 成员状态显示
- 响应式界面设计

## 项目结构

- `group_list.tscn/gd`: 主场景，展示群组列表
- `group_item.tscn/gd`: 群组项目模板
- `member_list.tscn/gd`: 成员列表场景
- `member_item.tscn/gd`: 成员项目模板
- `default_theme.tres`: 统一界面主题

## 使用说明

1. 使用Godot 4打开项目
2. 运行主场景 `group_list.tscn`
3. 可以通过搜索框搜索群组或成员
4. 点击排序按钮可以切换排序方式
5. 点击群组可以查看成员列表

## 开发环境

- Godot 4.0+
- GDScript
