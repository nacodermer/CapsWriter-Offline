#!/usr/bin/env bash

# GitHub 下载器脚本
# 可下载仓库源码或特定文件,支持版本指定,分支指定或提交哈希指定

# 构造下载 URL
construct_download_url() {
    # 参数：
    # $1: GitHub 用户名
    # $2: GitHub 仓库名
    # $3: 版本号（或 "latest" 表示最新版本，或 "branch:分支名"，或 "commit:提交哈希"）
    # $4: 文件名（或 "source" 表示源码）
    # $5: 输出格式（"zip" 或 "tar.gz"，默认为 "tar.gz"）

    local user_name="$1"
    local repo_name="$2"
    local version="$3"
    local file_name="$4"
    local format="${5:-tar.gz}"
    local download_url=""

    # 处理版本信息
    if [[ "$version" == "latest" ]]; then
        # 获取最新版本号
        local latest_release_info
        latest_release_info=$(curl -s "https://api.github.com/repos/${user_name}/${repo_name}/releases/latest")

        if [ -z "$latest_release_info" ]; then
            echo "错误：无法获取版本信息。请检查网络连接或仓库名称。" >&2
            return 1
        fi

        local latest_tag
        latest_tag=$(echo "$latest_release_info" | jq -r '.tag_name')

        if [ "$latest_tag" == "null" ] || [ -z "$latest_tag" ]; then
            echo "错误：无法从 API 响应中解析最新版本标签。" >&2
            echo "API 响应内容：" >&2
            echo "$latest_release_info" >&2
            return 1
        fi

        version="$latest_tag"
        echo "检测到最新版本: ${version}" >&2
    fi

    # 构建下载链接
    if [[ "$file_name" == "source" ]]; then
        # 下载源码
        if [[ "$version" == branch:* ]]; then
            # 处理分支下载
            local branch_name="${version#branch:}"
            if [[ "$format" == "zip" ]]; then
                download_url="https://github.com/${user_name}/${repo_name}/archive/refs/heads/${branch_name}.zip"
            else
                download_url="https://github.com/${user_name}/${repo_name}/archive/refs/heads/${branch_name}.tar.gz"
            fi
            echo "指定下载分支: ${branch_name}" >&2
        elif [[ "$version" == commit:* ]]; then
            # 处理提交哈希下载
            local commit_hash="${version#commit:}"
            if [[ "$format" == "zip" ]]; then
                download_url="https://github.com/${user_name}/${repo_name}/archive/${commit_hash}.zip"
            else
                download_url="https://github.com/${user_name}/${repo_name}/archive/${commit_hash}.tar.gz"
            fi
            echo "指定下载提交: ${commit_hash}" >&2
        else
            # 默认按标签下载
            if [[ "$format" == "zip" ]]; then
                download_url="https://github.com/${user_name}/${repo_name}/archive/refs/tags/${version}.zip"
            else
                download_url="https://github.com/${user_name}/${repo_name}/archive/refs/tags/${version}.tar.gz"
            fi
        fi
        echo "$download_url"
        return 0
    else
        # 下载特定文件
        download_url="https://github.com/${user_name}/${repo_name}/releases/download/${version}/${file_name}"
        echo "$download_url"
        return 0
    fi
}

# 根据文件类型解压文件到目标目录
extract_archive() {
    # 参数：
    # $1: 压缩文件路径
    # $2: 解压目标目录
    # $3: (可选) 是否删除顶层目录(适用于tar.gz和zip,默认0)

    local archive_path="$1"
    local target_dir="$2"
    local strip_components="${3:-0}"

    # 确保目标目录存在
    mkdir -p "${target_dir}"

    # 根据文件扩展名选择解压方法
    if [[ "${archive_path}" =~ \.tar\.gz$ ]]; then
        # 处理 tar.gz 文件
        if [ "$strip_components" -gt 0 ]; then
            # 使用 --strip-components 选项去除顶层目录
            tar -xzf "${archive_path}" -C "${target_dir}" --strip-components=${strip_components}
        else
            # 普通解压,保留目录结构
            tar -xzf "${archive_path}" -C "${target_dir}"
        fi
        return $?
    elif [[ "${archive_path}" =~ \.zip$ ]]; then
        # 处理 zip 文件
        if [ "$strip_components" -gt 0 ]; then
            # 为zip文件去除顶层目录的处理
            # 1. 创建临时目录
            local temp_dir=$(mktemp -d)

            # 2. 先将zip解压到临时目录
            unzip -o "${archive_path}" -d "${temp_dir}"
            if [ $? -ne 0 ]; then
                echo "错误：解压zip文件到临时目录失败。"
                rm -rf "${temp_dir}"
                return 1
            fi

            # 3. 检查是否有单一顶层目录
            local top_level_items=()
            while IFS= read -r -d $'\0' item; do
                top_level_items+=("$item")
            done < <(find "${temp_dir}" -mindepth 1 -maxdepth 1 -print0)

            # 如果只有单一顶层目录，则将其内容移动到目标目录
            if [ ${#top_level_items[@]} -eq 1 ] && [ -d "${top_level_items[0]}" ]; then
                # 将顶层目录中的所有内容复制到目标目录
                cp -r "${top_level_items[0]}"/* "${target_dir}" 2>/dev/null
                cp -r "${top_level_items[0]}"/.* "${target_dir}" 2>/dev/null || true

                # 清理临时目录
                rm -rf "${temp_dir}"
            else
                # 如果没有单一顶层目录，则直接将所有内容移动到目标目录
                cp -r "${temp_dir}"/* "${target_dir}" 2>/dev/null
                cp -r "${temp_dir}"/.* "${target_dir}" 2>/dev/null || true
                rm -rf "${temp_dir}"
            fi
        else
            # 普通解压,保留目录结构
            unzip -o "${archive_path}" -d "${target_dir}"
        fi
        return $?
    else
        echo "错误：不支持的文件格式。当前仅支持 .tar.gz 和 .zip 格式。"
        return 1
    fi
}

# 下载 GitHub 仓库发布内容
download_github_release() {
    # 参数：
    # $1: GitHub 用户名
    # $2: GitHub 仓库名
    # $3: 版本号（或 "latest" 表示最新版本，或 "branch:分支名"，或 "commit:提交哈希"）
    # $4: 文件名（或 "source" 表示源码）
    # $5: 解压的目标目录
    # $6: 是否删除压缩文件（0-保留,1-删除）
    # $7: 是否解压文件（0-不解压,1-解压）
    # $8: 输出格式（"zip" 或 "tar.gz"，默认为 "tar.gz"）

    local user_name="$1"
    local repo_name="$2"
    local version="$3"
    local file_name="$4"
    local target_dir="$5"
    local delete_after_extract="$6"
    local extract_files="${7:-0}"      # 是否解压文件，默认为0（不解压）
    local format="${8:-tar.gz}"        # 输出格式，默认为tar.gz
    local download_dir="data/download" # 固定下载目录

    # 生成实际解压路径
    if [ "${target_dir}" = "PROJROOT" ]; then
        # 解压到当前目录
        local extract_dir="."
    elif [ "${target_dir}" = "MODELS" ]; then
        # 解压到 data/models 目录
        local extract_dir="data/models"
    else
        # 默认解压到 data/extract 下对应子目录
        local extract_dir="data/extract/${target_dir}"
    fi

    echo "正在处理 ${user_name}/${repo_name} 的下载请求..."

    # 获取下载链接
    local download_url
    download_url=$(construct_download_url "$user_name" "$repo_name" "$version" "$file_name" "$format")
    if [ $? -ne 0 ]; then
        echo "$download_url" # 显示错误信息
        return 1
    fi

    # 确定实际版本号和文件后缀
    local file_suffix="tar.gz"
    if [[ "$download_url" == *".zip" ]]; then
        file_suffix="zip"
    fi

    # 根据下载类型生成合适的文件名
    local output_filename
    if [[ "$version" == "latest" ]]; then
        version=$(echo "$download_url" | grep -oP '(?<=tags/)[^/]+(?=\.(tar\.gz|zip))' || echo "latest")
    fi

    # 确定输出文件名
    if [[ "$file_name" == "source" ]]; then
        if [[ "$version" == branch:* ]]; then
            local branch_name="${version#branch:}"
            output_filename="${repo_name}-${branch_name}.${file_suffix}"
        elif [[ "$version" == commit:* ]]; then
            local commit_hash="${version#commit:}"
            output_filename="${repo_name}-${commit_hash}.${file_suffix}"
        else
            output_filename="${repo_name}-${version}.${file_suffix}"
        fi
    else
        output_filename="${file_name}"
    fi

    echo "下载链接: ${download_url}"

    # 创建下载目录 (如果不存在)
    mkdir -p "${download_dir}"
    if [ $? -ne 0 ]; then
        echo "错误：无法创建下载目录 ${download_dir}"
        return 1
    fi

    # 创建解压目标目录 (如果不存在)
    mkdir -p "${extract_dir}"
    if [ $? -ne 0 ]; then
        echo "错误：无法创建目标目录 ${extract_dir}"
        return 1
    fi

    # 检查文件是否已存在
    local file_exists=0
    if [[ -f "${download_dir}/${output_filename}" ]]; then
        file_exists=1
        echo "文件已存在: ${download_dir}/${output_filename}"
    fi

    # 如果文件已存在且需要解压，优先尝试解压
    if [[ $extract_files -eq 1 && $file_exists -eq 1 && ("$file_name" == "source" || "${file_name}" =~ \.(tar\.gz|zip)$) ]]; then
        echo "正在尝试解压已存在的文件 ${output_filename} 到 ${extract_dir}..."

        local strip_option=1 # 始终使用 strip-components=1
        local extract_success=0
        # 所有压缩文件都去除顶层目录
        extract_archive "${download_dir}/${output_filename}" "${extract_dir}" "${strip_option}"
        extract_success=$?

        # 如果解压成功，跳过下载
        if [ $extract_success -eq 0 ]; then
            echo "已有文件解压成功，无需重新下载。文件已解压到 ${extract_dir}"
            if [ "$extract_files" -eq 0 ]; then
                echo "注意：--extract 参数未设置，但由于文件已存在且解压成功，因此仍然解压"
            fi
        else
            echo "已有文件解压失败，尝试重新下载..."
            file_exists=0 # 重置标志，执行下载
        fi
    fi

    # 如果文件不存在或解压失败，则进行下载
    if [ $file_exists -eq 0 ]; then
        # 使用 curl 断点续传功能下载文件
        echo "正在下载 ${output_filename} 到 ${download_dir} ..."
        echo "（支持断点续传，如果文件已部分下载将从断点处继续）"
        curl -L -C - "${download_url}" -o "${download_dir}/${output_filename}"
        if [ $? -ne 0 ]; then
            echo "错误：下载文件失败。"
            return 1
        fi
        echo "下载完成: ${download_dir}/${output_filename}"
    fi

    # 如果是源代码或压缩文件,且文件不存在或刚刚下载,且需要解压,则进行解压
    if [[ $extract_files -eq 1 && ("$file_name" == "source" || "${file_name}" =~ \.(tar\.gz|zip)$) && $file_exists -eq 0 ]]; then
        echo "正在解压 ${output_filename} 到 ${extract_dir}..."

        local strip_option=1 # 始终使用 strip-components=1
        # 所有压缩文件都去除顶层目录
        extract_archive "${download_dir}/${output_filename}" "${extract_dir}" "${strip_option}"

        if [ $? -ne 0 ]; then
            echo "错误：解压文件失败。"
            return 1
        fi

        echo "解压完成。"
        echo "文件 ${output_filename} 已解压到 ${extract_dir} (已去除顶层目录)"

        # 删除下载的压缩包（如果需要）
        if [ "$delete_after_extract" -eq 1 ]; then
            echo "正在删除下载的压缩包 ${download_dir}/${output_filename}..."
            rm "${download_dir}/${output_filename}"
            echo "已删除压缩包。"
        fi
    else
        if [[ ("$file_name" == "source" || "${file_name}" =~ \.(tar\.gz|zip)$) && $extract_files -eq 0 ]]; then
            echo "已下载文件: ${download_dir}/${output_filename} (未解压，因为未指定 --extract 参数)"
        else
            echo "已下载文件: ${download_dir}/${output_filename}"
        fi
    fi

    echo "操作成功完成。"
}

# 打印帮助信息
print_help() {
    echo "用法: $0 [选项...]"
    echo ""
    echo "选项:"
    echo "  -u, --user USER        GitHub 用户名 (必需)"
    echo "  -r, --repo REPO        GitHub 仓库名 (必需)"
    echo "  -v, --version VERSION  版本号 如 v1.0 (默认: latest)"
    echo "                         特殊格式:"
    echo "                         - latest: 最新发布版本"
    echo "                         - branch:名称: 指定分支 (例如 branch:main)"
    echo "                         - commit:哈希: 指定提交 (例如 commit:a1b2c3d)"
    echo "  -f, --file FILE        文件名 (默认: source, 表示下载源码)"
    echo "  -t, --target TARGET    解压的目标目录 (-e, --extract 时必须指定， 将位于 extract 目录下)"
    echo "                         注意：目标目录不能以 . ./ / 等开头"
    echo "  -z, --zip              使用ZIP格式下载 (默认: tar.gz)"
    echo "  -e, --extract          解压下载的文件 (默认: 不解压，仅下载)"
    echo "  -d, --delete           解压后删除压缩文件 (默认: 不删除)"
    echo "  -h, --help             显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 --user HaujetZhao --repo CapsWriter-Offline"                                 # 基本用法：下载最新release版本源码
    echo "  $0 -u HaujetZhao -r CapsWriter-Offline -v v1.0 -t app -e -d"                    # 下载指定版本源码，解压到app目录并删除压缩包
    echo "  $0 -u HaujetZhao -r CapsWriter-Offline -v branch:main -z -t main-branch -e"     # 下载main分支的head提交的ZIP格式源码并解压
    echo "  $0 -u HaujetZhao -r CapsWriter-Offline -v commit:a1b2c3d -t specific-commit -e" # 下载特定提交哈希的源码并解压
    echo "  $0 -u HaujetZhao -r CapsWriter-Offline -f models.zip -t models -e"              # 下载最新release版本的特定文件并解压
}

# 主函数
main() {
    # 默认参数值
    local user_name=""
    local repo_name=""
    local version="latest"
    local file_name="source"
    local target_dir=""
    local delete_after_extract=0
    local extract_files=0
    local use_zip=0

    # 参数解析
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -u | --user)
            user_name="$2"
            shift 2
            ;;
        -r | --repo)
            repo_name="$2"
            shift 2
            ;;
        -v | --version)
            version="$2"
            shift 2
            ;;
        -f | --file)
            file_name="$2"
            shift 2
            ;;
        -t | --target)
            # 检查target_dir是否以 . ./ / 等开头
            if [[ "$2" =~ ^\.|\.\/ ]] || [[ "$2" == /* ]]; then
                echo "错误：目标目录 '$2' 不能以 . ./ / 等开头，因为所有文件都将解压到 extract 目录下"
                return 1
            fi
            target_dir="$2"
            shift 2
            ;;
        -z | --zip)
            use_zip=1
            shift
            ;;
        -e | --extract)
            extract_files=1
            shift
            ;;
        -d | --delete)
            delete_after_extract=1
            shift
            ;;
        -h | --help)
            print_help
            return 0
            ;;
        *)
            echo "错误: 未知选项 $1"
            print_help
            return 1
            ;;
        esac
    done

    # 验证必需参数
    if [[ -z "$user_name" || -z "$repo_name" ]]; then
        echo "错误: 必须指定 GitHub 用户名和仓库名"
        print_help
        return 1
    fi

    # 验证使用 extract 选项时必须指定 target_dir
    if [[ $extract_files -eq 1 && -z "$target_dir" ]]; then
        echo "错误: 使用 --extract 选项时，必须明确指定目标目录 (--target)"
        print_help
        return 1
    fi

    # 设置输出格式
    local format="tar.gz"
    if [ "$use_zip" -eq 1 ]; then
        format="zip"
    fi

    # 调用下载函数
    download_github_release "$user_name" "$repo_name" "$version" "$file_name" "$target_dir" "$delete_after_extract" "$extract_files" "$format"
    return $?
}

# 如果脚本是直接运行的（而不是被导入的）,则执行 main 函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
