import os
import re
import shutil
from pathlib import Path

####################替换正确的文件路径#################################
def update_resource_paths(base_dir, game_name):
    """统一处理资源路径转换"""
    if not game_name:
        game_name = get_parent_last_directory()

    # 资源类型映射
    RESOURCE_MAP = {
        'image': ['png', 'jpg', 'jpeg', 'svg', 'webp', 'bmp', 'tga'],
        'sound': ['ogg', 'wav', 'mp3', 'flac'],
        'font': ['ttf', 'otf', 'woff']
    }
    
    # 特殊文件类型映射
    SPECIAL_TYPES = {
        'gd': 'scripts',
        'tscn': 'scenes',
        'tres': 'themes'
    }

     # 增强正则表达式（精确匹配带引号的路径）
    pattern = re.compile(
        r'(["\'])(res://)((?!game/'+re.escape(game_name)+r'/)([^/"\']+/)*([^/"\']+\.(\w+)))(["\'])',
        re.IGNORECASE
    )

    def replace_path(match):
        quote_start = match.group(1)  # 起始引号
        path = match.group(2)  # res://
        full_path = match.group(3)  # 完整路径（如assets/fonts/Kaph-Regular.ttf）
        suffix = match.group(6).lower()  # 文件后缀
        quote_end = match.group(7)  # 结束引号

        # 排除已处理路径
        if f'game/{game_name}' in full_path:
            return match.group(0)

        # 分解路径
        path_parts = full_path.split('/')
        base_dir = path_parts[0]  # 基础目录（如assets）
        middle_dirs = '/'.join(path_parts[1:-1])  # 中间目录（如fonts）
        filename = path_parts[-1]  # 带后缀的文件名

        # 处理特殊文件类型
        if suffix in SPECIAL_TYPES:
            target_dir = SPECIAL_TYPES[suffix]
            new_path = f'{path}{target_dir}/game/{game_name}'
            if middle_dirs:
                new_path += f'/{middle_dirs}'
            return f'{quote_start}{new_path}/{filename}{quote_end}'

        # 处理常规资源类型
        for res_type, suffixes in RESOURCE_MAP.items():
            if suffix in suffixes:
                new_path = f'{path}{base_dir}/game/{game_name}/{res_type}'
                if middle_dirs:
                    new_path += f'/{middle_dirs}'
                return f'{quote_start}{new_path}/{filename}{quote_end}'

        # 其他类型处理
        new_path = f'{path}{base_dir}/game/{game_name}'
        if middle_dirs:
            new_path += f'/{middle_dirs}'
        return f'{quote_start}{new_path}/{filename}{quote_end}'

    for root, dirs, files in os.walk(base_dir):
        for file in files:
            if not file.endswith(('tscn', 'gd', 'tres', 'godot')):
                continue

            file_path = os.path.join(root, file)
            try:
                with open(file_path, 'r+', encoding='utf-8') as f:
                    content = f.read()
                    new_content = pattern.sub(replace_path, content)

                    if new_content != content:
                        f.seek(0)
                        f.write(new_content)
                        f.truncate()
                        print(f"更新路径: {file_path}","新内容:",new_content)

            except Exception as e:
                print(f"处理文件 {file_path} 出错: {e}")
###################整理分类游戏文件##################################
def get_parent_last_directory():
    current_path = os.getcwd()
    print('当前路径:',current_path)
    last_dir_name = os.path.basename(current_path)
    return last_dir_name


def remove_common_substring(s1, s2):
    # 寻找最长公共子串
    m = len(s1)
    n = len(s2)
    max_len = 0
    end_pos = 0
    dp = [[0]*(n+1) for _ in range(m+1)]
    
    for i in range(1, m+1):
        for j in range(1, n+1):
            if s1[i-1] == s2[j-1]:
                dp[i][j] = dp[i-1][j-1] + 1
                if dp[i][j] > max_len:
                    max_len = dp[i][j]
                    end_pos = j
    
    # 提取最长公共子串
    common_sub = s2[end_pos - max_len : end_pos] if max_len > 0 else ''
    
    # 从第二个字符串中移除公共子串（仅移除第一个出现的）
    return s2.replace(common_sub, '', 1) if common_sub else s2



def delete_empty_dirs(base_dir):
    """删除所有空目录"""
    for root, dirs, files in os.walk(base_dir, topdown=False):
        for dir_name in dirs:
            dir_path = os.path.join(root, dir_name)
            try:
                # 尝试删除空目录（包括只包含空目录的父目录）
                os.rmdir(dir_path)
            except OSError:
                pass  # 非空目录会抛出异常，这里忽略即可

def reorganize_files(base_dir, game_name):
    if game_name == '':# 默认使用当前目录名称
        game_name = get_parent_last_directory()
    processed_entries = set()  # 新增：记录已处理的目录
    # Step 1: 添加 game/游戏名 层级
    for entry in os.listdir(base_dir):
        entry_path = os.path.join(base_dir, entry)
        if os.path.isdir(entry_path) and entry not in ['scenes', 'scripts', 'assets']:
           # 新增：预生成目标目录路径
            dest_dir = os.path.join(entry_path, 'game', game_name)
            
            # 新增：检查是否会导致循环移动
            if os.path.abspath(entry_path) == os.path.abspath(dest_dir):
                continue
           
            # 遍历一级子目录（如 assets、other、scripts）
            for root, dirs, files in os.walk(entry_path, topdown=False):
                # 跳过已处理过的目录
                if root in processed_entries:
                    dirs[:] = []
                    continue
                
                for name in dirs + files:
                    src = os.path.join(root, name)
                    # 新增：路径冲突检查
                    if os.path.commonpath([src, dest_dir]) == os.path.normpath(src):
                        print(f"跳过循环移动: {src} -> {dest_dir}")
                        continue

                    # 移动文件
                    if os.path.dirname(src) == entry_path:
                        # 构建新路径：一级子目录/game/游戏名/原内容
                        processed_entries.add(src)  # 记录已移动项
                        dest_dir = os.path.join(entry_path, 'game', game_name)
                        dest = os.path.join(dest_dir, name)
                        os.makedirs(dest_dir, exist_ok=True)
                        shutil.move(src, dest)

    # Step 2: 分类文件到目标目录
    for root, dirs, files in os.walk(base_dir):
        for file in files:
            src_path = os.path.join(root, file)
            suffix = file.split('.')[-1].lower()

            # 跳过已在目标目录的文件
            if 'scenes/game' in src_path or 'scripts/game' in src_path:
                continue
            if 'assets/game/{}/image'.format(game_name) in src_path:
                continue
            if 'assets/game/{}/sound'.format(game_name) in src_path:
                continue

            # 分类逻辑
            res_sub_dir = ''
            if suffix == 'tscn':
                dest_root = os.path.join(base_dir, 'scenes', 'game', game_name)
            elif suffix == 'gd':
                dest_root = os.path.join(base_dir, 'scripts', 'game', game_name)
            elif suffix in ['tres']:
                dest_root = os.path.join(base_dir, 'themes', 'game', game_name)
            elif suffix in ['gdshader']:
                dest_root = os.path.join(base_dir, 'shaders', 'game', game_name)
            elif suffix in ['gdshader']:
                dest_root = os.path.join(base_dir, 'shaders', 'game', game_name)
            # 图片、音频、字体等资源
            elif suffix in ['png', 'svg', 'jpge', 'jpg', 'bmp', 'gif', 'webp', 'tga', 'tiff', 'psd', 'hdr', 'pic', 'pnm', 'ico', 'icns', 'cur', 'ani']:
                res_sub_dir = 'image'
                dest_root = os.path.join(base_dir, 'assets', 'game', game_name, res_sub_dir)
            elif suffix in ['ogg', 'wav', 'mp3', 'flac', 'aiff', 'wma', 'm4a', 'mp4', 'wmv', 'avi', 'mov', 'mkv', 'webm', 'flv', 'f4v',  'ogv', 'ogx', 'ogm', ]:
                res_sub_dir = 'sound'
                dest_root = os.path.join(base_dir, 'assets', 'game', game_name, res_sub_dir)
            elif suffix in ['ttf', 'otf', 'eot', 'woff', 'woff2']:
                res_sub_dir = 'font'
                dest_root = os.path.join(base_dir, 'assets', 'game', game_name, res_sub_dir)
            # 删除无用文件
            elif suffix in ['import', 'uid',"tmp"]: 
                try:
                    os.remove(src_path)
                except FileNotFoundError:
                    print(f"文件 {file} 不存在")
                except PermissionError:
                    print(f"没有权限删除文件 {file}")
                except Exception as e:
                    print(f"删除文件 {file} 时发生错误: {e}")
                continue
            else:
                continue  # 其他类型不处理

            # 保留原相对路径结构（排除一级目录）
            rel_path = os.path.relpath(root, base_dir)
            parts = rel_path.split(os.sep)
            if len(parts) > 1:
                preserved_subpath = os.path.join(*parts[1:])  # 跳过一级目录
            else:
                preserved_subpath = ''
            if preserved_subpath != '' and preserved_subpath in dest_root:
                preserved_subpath = ''
            if preserved_subpath != '':
                old_1 = 'game\\'+game_name+'\\'
                if res_sub_dir != '':
                    old_1 += res_sub_dir+'\\'
                preserved_subpath = preserved_subpath.replace(old_1,'' )
            
            dest_dir = os.path.join(dest_root, preserved_subpath)
            dest_path = os.path.join(dest_dir, file)
            print('目标路径:',dest_root,' 排除一级目录:',preserved_subpath,'文件名:',dest_path)
            try:
                os.makedirs(dest_dir, exist_ok=True)
                shutil.move(src_path, dest_path)
            except shutil.Error as e:
                print(f"文件 {file} 移动失败: {e}")
            pass
    delete_empty_dirs(base_dir)   
    update_resource_paths(base_dir, game_name)  # <-- 添加这行

if __name__ == '__main__':
    base_dir = '.'  # 当前目录为 supergame
    game_name = ''     # 替换为实际游戏名称
    reorganize_files(base_dir, game_name)
